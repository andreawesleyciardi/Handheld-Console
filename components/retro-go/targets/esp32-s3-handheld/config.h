// Waveshare ESP32-S3-DEV-KIT-N16R8 handheld with a DFRobot ILI9488 display.
#define RG_TARGET_NAME             "ESP32-S3-HANDHELD"

#define RG_STORAGE_ROOT            "/sd"
#define RG_STORAGE_SDSPI_HOST      SPI3_HOST
#define RG_STORAGE_SDSPI_SPEED     1000
#define RG_STORAGE_SDSPI_SDFAT     1

// No audio hardware is installed.
#define RG_AUDIO_USE_INT_DAC       0
#define RG_AUDIO_USE_EXT_DAC       0

#define RG_SCREEN_DRIVER            2
#define RG_SCREEN_HOST             SPI2_HOST
#define RG_SCREEN_SPEED            40000000
#define RG_SCREEN_BACKLIGHT        0
#define RG_SCREEN_WIDTH             480
#define RG_SCREEN_HEIGHT            320
#define RG_SCREEN_ROTATE           0
#define RG_SCREEN_VISIBLE_AREA     {0, 0, 0, 0}
#define RG_SCREEN_SAFE_AREA        {0, 0, 0, 0}
#define RG_SCREEN_RGB_BGR          1
#define RG_SCREEN_ROTATION         0
#define RG_SCREEN_INIT() \
    ILI9488_CMD(0xC0, 0x17, 0x15); \
    ILI9488_CMD(0xC1, 0x41); \
    ILI9488_CMD(0xC5, 0x00, 0x12, 0x80); \
    ILI9488_CMD(0xB0, 0x00); \
    ILI9488_CMD(0xB1, 0xA0); \
    ILI9488_CMD(0xB4, 0x02); \
    ILI9488_CMD(0xB6, 0x02, 0x22, 0x3B); \
    ILI9488_CMD(0xB7, 0xC6); \
    ILI9488_CMD(0xF7, 0xA9, 0x51, 0x2C, 0x82);

#define RG_GAMEPAD_GPIO_MAP {\
    {RG_KEY_L,      .num = GPIO_NUM_1,  .pullup = 1, .level = 0},\
    {RG_KEY_R,      .num = GPIO_NUM_4,  .pullup = 1, .level = 0},\
    {RG_KEY_X,      .num = GPIO_NUM_5,  .pullup = 1, .level = 0},\
    {RG_KEY_Y,      .num = GPIO_NUM_6,  .pullup = 1, .level = 0},\
    {RG_KEY_A,      .num = GPIO_NUM_7,  .pullup = 1, .level = 0},\
    {RG_KEY_B,      .num = GPIO_NUM_15, .pullup = 1, .level = 0},\
    {RG_KEY_START,  .num = GPIO_NUM_12, .pullup = 1, .level = 0},\
    {RG_KEY_SELECT, .num = GPIO_NUM_11, .pullup = 1, .level = 0},\
    {RG_KEY_UP,     .num = GPIO_NUM_2,  .pullup = 1, .level = 0},\
    {RG_KEY_DOWN,   .num = GPIO_NUM_42, .pullup = 1, .level = 0},\
    {RG_KEY_RIGHT,  .num = GPIO_NUM_41, .pullup = 1, .level = 0},\
    {RG_KEY_LEFT,   .num = GPIO_NUM_40, .pullup = 1, .level = 0},\
}

#define RG_GAMEPAD_VIRT_MAP {\
    {RG_KEY_MENU,   .src = RG_KEY_START | RG_KEY_SELECT},\
}

#define RG_BATTERY_DRIVER          1
#define RG_BATTERY_ADC_UNIT        ADC_UNIT_2
#define RG_BATTERY_ADC_CHANNEL     ADC_CHANNEL_3
#define RG_BATTERY_CALC_PERCENT(raw) (((raw) * 2.f - 3200.f) / (4200.f - 3200.f) * 100.f)
#define RG_BATTERY_CALC_VOLTAGE(raw) ((raw) * 2.f * 0.001f)

#define RG_GPIO_LCD_MISO           GPIO_NUM_10
#define RG_GPIO_LCD_MOSI           GPIO_NUM_21
#define RG_GPIO_LCD_CLK            GPIO_NUM_3
#define RG_GPIO_LCD_CS             GPIO_NUM_9
#define RG_GPIO_LCD_DC             GPIO_NUM_47
#define RG_GPIO_LCD_RST            GPIO_NUM_48

#define RG_GPIO_SDSPI_MISO         GPIO_NUM_8
#define RG_GPIO_SDSPI_MOSI         GPIO_NUM_18
#define RG_GPIO_SDSPI_CLK          GPIO_NUM_17
#define RG_GPIO_SDSPI_CS           GPIO_NUM_16
