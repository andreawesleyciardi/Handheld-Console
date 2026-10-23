#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <driver/spi_master.h>
#include <driver/gpio.h>
#include <driver/ledc.h>
#include <esp_heap_caps.h>

#if defined(RG_SCREEN_ROTATE) && RG_SCREEN_ROTATE != 0
#error "RG_SCREEN_ROTATE doesn't do anything on this driver, use the 0x36 command during init!"
#endif

static spi_device_handle_t spi_dev;
static QueueHandle_t spi_buffers;
static uint8_t spi_command_buffer[16] __attribute__((aligned(4)));

#define SPI_TRANSACTION_COUNT (10)
#define SPI_BUFFER_COUNT      (5)
#define SPI_BUFFER_LENGTH     (LCD_BUFFER_LENGTH * 3)

static inline uint16_t *spi_take_buffer(void)
{
    uint16_t *buffer;
    if (xQueueReceive(spi_buffers, &buffer, pdMS_TO_TICKS(2500)) != pdTRUE)
        RG_PANIC("display");
    return buffer;
}

static inline void spi_give_buffer(uint16_t *buffer)
{
    xQueueSend(spi_buffers, &buffer, portMAX_DELAY);
}

static inline void spi_transmit_transaction(const void *data, size_t length, uint32_t type)
{
    if (!data || !length)
        return;

    const void *tx_data = data;
    if (!(type & 2))
    {
        RG_ASSERT(length <= sizeof(spi_command_buffer), "ILI9488 command too long");
        memcpy(spi_command_buffer, data, length);
        tx_data = spi_command_buffer;
    }

    spi_transaction_t transaction = {
        .tx_buffer = tx_data,
        .length = length * 8, // In bits
    };
    gpio_set_level(RG_GPIO_LCD_DC, type & 1);
    RG_ASSERT(spi_device_transmit(spi_dev, &transaction) == ESP_OK, "display transfer failed");
}

static inline void ili9488_write_direct(const uint8_t *data, size_t length, int dc)
{
    const uint8_t *tx_data = data;
    if (length <= sizeof(spi_command_buffer))
    {
        memcpy(spi_command_buffer, data, length);
        tx_data = spi_command_buffer;
    }
    spi_transaction_t transaction = {
        .tx_buffer = tx_data,
        .length = length * 8,
    };
    gpio_set_level(RG_GPIO_LCD_DC, dc);
    RG_ASSERT(spi_device_transmit(spi_dev, &transaction) == ESP_OK, "direct display transfer failed");
}

static inline void ili9488_command(uint8_t command, const uint8_t *data, size_t length)
{
    gpio_set_level(RG_GPIO_LCD_CS, 0);
    ili9488_write_direct(&command, 1, 0);
    if (length)
        ili9488_write_direct(data, length, 1);
    gpio_set_level(RG_GPIO_LCD_CS, 1);
}

static inline void spi_queue_transaction(const void *data, size_t length, uint32_t type, uint32_t flags)
{
    gpio_set_level(RG_GPIO_LCD_CS, 0);
    spi_transmit_transaction(data, length, type);
    gpio_set_level(RG_GPIO_LCD_CS, 1);
    if (type & 2)
        spi_give_buffer((uint16_t *)data);
}

IRAM_ATTR
static void spi_pre_transfer_cb(spi_transaction_t *t)
{
    // Set the data/command line accordingly
    gpio_set_level(RG_GPIO_LCD_DC, (int)t->user & 1);
}

static void spi_init(void)
{
    RG_LOGI("ILI9488 SPI: allocating buffers\n");
    spi_buffers = xQueueCreate(SPI_BUFFER_COUNT, sizeof(uint16_t *));

    while (uxQueueSpacesAvailable(spi_buffers))
    {
        void *buffer = rg_alloc(SPI_BUFFER_LENGTH, MEM_DMA);
        xQueueSend(spi_buffers, &buffer, portMAX_DELAY);
    }
    RG_LOGI("ILI9488 SPI: buffers ready\n");

    const spi_bus_config_t buscfg = {
        .miso_io_num = RG_GPIO_LCD_MISO,
        .mosi_io_num = RG_GPIO_LCD_MOSI,
        .sclk_io_num = RG_GPIO_LCD_CLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = SPI_BUFFER_LENGTH,
    };

    const spi_device_interface_config_t devcfg = {
        .clock_speed_hz = RG_SCREEN_SPEED,   // Typically SPI_MASTER_FREQ_40M or SPI_MASTER_FREQ_80M
        .mode = 0,                           // SPI mode 0
        .spics_io_num = -1,                  // CS is driven explicitly
        .queue_size = 1,
        .pre_cb = NULL,
        .flags = SPI_DEVICE_NO_DUMMY,
    };

    esp_err_t ret;

    // Initialize the SPI bus
    RG_LOGI("ILI9488 SPI: initializing bus\n");
    ret = spi_bus_initialize(RG_SCREEN_HOST, &buscfg, SPI_DMA_CH_AUTO);
    RG_LOGI("ILI9488 SPI: bus result=%d\n", (int)ret);
    RG_ASSERT(ret == ESP_OK || ret == ESP_ERR_INVALID_STATE, "spi_bus_initialize failed.");

    RG_LOGI("ILI9488 SPI: adding device\n");
    ret = spi_bus_add_device(RG_SCREEN_HOST, &devcfg, &spi_dev);
    RG_LOGI("ILI9488 SPI: device result=%d\n", (int)ret);
    RG_ASSERT(ret == ESP_OK, "spi_bus_add_device failed.");
    RG_LOGI("ILI9488 SPI: ready\n");

}

static void spi_deinit(void)
{
    // When transactions are still in flight, spi_bus_remove_device fails and spi_bus_free then crashes.
    // The real solution would be to wait for transactions to be done, but this is simpler for now...
    if (spi_bus_remove_device(spi_dev) == ESP_OK)
        spi_bus_free(RG_SCREEN_HOST);
    else
        RG_LOGE("Failed to properly terminate SPI driver!");
}

#define ILI9488_CMD(cmd, data...) \
    do { const uint8_t x[] = {data}; ili9488_command(cmd, x, sizeof(x)); } while (0)

#define ILI9488_CMD0(cmd) \
    do { ili9488_command(cmd, NULL, 0); } while (0)

static void lcd_set_backlight(float percent)
{
    float level = RG_MIN(RG_MAX(percent / 100.f, 0), 1.f);
    int error_code = 0;

#if defined(RG_GPIO_LCD_BCKL)
    error_code = ledc_set_fade_time_and_start(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, 0x1FFF * level, 50, 0);
#elif defined(RG_TARGET_QTPY_GAMER)
    rg_i2c_gpio_set_direction(AW_TFT_BACKLIGHT, RG_GPIO_ANALOG_OUTPUT);
    rg_i2c_gpio_set_level(AW_TFT_BACKLIGHT, level * 255);
#endif

    if (error_code)
        RG_LOGE("failed setting backlight to %d%% (0x%02X)\n", (int)(100 * level), error_code);
    else
        RG_LOGI("backlight set to %d%%\n", (int)(100 * level));
}

static void lcd_set_window(int left, int top, int width, int height)
{
    int right = left + width - 1;
    int bottom = top + height - 1;

    if (left < 0 || top < 0 || right >= display.screen.real_width || bottom >= display.screen.real_height)
        RG_LOGW("Bad lcd window (x0=%d, y0=%d, x1=%d, y1=%d)\n", left, top, right, bottom);

    ILI9488_CMD(0x2A, left >> 8, left & 0xff, right >> 8, right & 0xff); // Horiz
    ILI9488_CMD(0x2B, top >> 8, top & 0xff, bottom >> 8, bottom & 0xff); // Vert
    ILI9488_CMD(0x2C);                                                   // Memory write
}

static inline uint16_t *lcd_get_buffer(size_t length)
{
    return spi_take_buffer();
}

static inline void lcd_send_buffer(uint16_t *buffer, size_t length)
{
    if (length > 0)
    {
        uint8_t *pixels = (uint8_t *)buffer;
        for (size_t index = length; index-- > 0;)
        {
            uint16_t pixel = buffer[index];
            pixels[index * 3 + 0] = ((((pixel >> 11) & 0x1F) << 1) | ((pixel >> 15) & 1)) << 2;
            pixels[index * 3 + 1] = ((pixel >> 5) & 0x3F) << 2;
            pixels[index * 3 + 2] = ((((pixel & 0x1F) << 1) | ((pixel >> 4) & 1)) << 2);
        }
        spi_queue_transaction(buffer, length * 3, 3, 0);
    }
    else
        spi_give_buffer(buffer);
}

static void lcd_sync(void)
{
    // Unused for SPI LCD
}

static void lcd_init(void)
{
#ifdef RG_GPIO_LCD_BCKL
    // Initialize backlight at 0% to avoid the lcd reset flash
    ledc_timer_config(&(ledc_timer_config_t){
        .duty_resolution = LEDC_TIMER_13_BIT,
        .freq_hz = 5000,
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .timer_num = LEDC_TIMER_0,
    });
    ledc_channel_config(&(ledc_channel_config_t){
        .channel = LEDC_CHANNEL_0,
        .duty = 0,
        .gpio_num = RG_GPIO_LCD_BCKL,
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .timer_sel = LEDC_TIMER_0,
    });
    ledc_fade_func_install(0);
#endif

    spi_init();

    // Setup Data/Command line
    gpio_set_direction(RG_GPIO_LCD_DC, GPIO_MODE_OUTPUT);
    gpio_set_level(RG_GPIO_LCD_DC, 1);
    gpio_set_direction(RG_GPIO_LCD_CS, GPIO_MODE_OUTPUT);
    gpio_set_level(RG_GPIO_LCD_CS, 1);
    RG_LOGI("ILI9488: control GPIO ready\n");

#if defined(RG_GPIO_LCD_RST)
    gpio_set_direction(RG_GPIO_LCD_RST, GPIO_MODE_OUTPUT);
    gpio_set_level(RG_GPIO_LCD_RST, 0);
    rg_usleep(100 * 1000);
    gpio_set_level(RG_GPIO_LCD_RST, 1);
    rg_usleep(10 * 1000);
    RG_LOGI("ILI9488: hardware reset complete\n");
#elif defined(RG_TARGET_QTPY_GAMER)
    rg_i2c_gpio_set_direction(AW_TFT_RESET, RG_GPIO_OUTPUT);
    rg_i2c_gpio_set_level(AW_TFT_RESET, 0);
    rg_usleep(100 * 1000);
    rg_i2c_gpio_set_level(AW_TFT_RESET, 1);
    rg_usleep(10 * 1000);
#endif

    RG_LOGI("ILI9488: sending software reset\n");
    ILI9488_CMD0(0x01);         // Reset
    RG_LOGI("ILI9488: software reset sent\n");
    rg_usleep(10 * 1000);       // Wait after software reset
    ILI9488_CMD(0xE0, 0x00, 0x03, 0x09, 0x08, 0x16, 0x0A, 0x3F, 0x78, 0x4C, 0x09, 0x0A, 0x08, 0x16, 0x1A, 0x0F);
    ILI9488_CMD(0xE1, 0x00, 0x16, 0x19, 0x03, 0x0F, 0x05, 0x32, 0x45, 0x46, 0x04, 0x0E, 0x0D, 0x35, 0x37, 0x0F);
    ILI9488_CMD(0x3A, 0x66);     // Pixel Format Set RGB666 for SPI
    ILI9488_CMD(0x36, 0xA8);     // BGR order, landscape orientation
    ILI9488_CMD0(0x20);          // Display inversion off
    #ifdef RG_SCREEN_INIT
        RG_SCREEN_INIT();
    #else
        #warning "LCD init sequence is not defined for this device!"
    #endif
        ILI9488_CMD0(0x11);  // Exit Sleep
        rg_usleep(120 * 1000);// Wait 120ms after sleep out
        ILI9488_CMD0(0x29);  // Display on
        RG_LOGI("ILI9488: panel init complete\n");

}

static void lcd_deinit(void)
{
#ifdef RG_SCREEN_DEINIT
    RG_SCREEN_DEINIT();
#endif
    spi_deinit();
    // gpio_reset_pin(RG_GPIO_LCD_BCKL);
    // gpio_reset_pin(RG_GPIO_LCD_DC);
}

const rg_display_driver_t rg_display_driver_ili9488 = {
    .name = "ili9488",
};
