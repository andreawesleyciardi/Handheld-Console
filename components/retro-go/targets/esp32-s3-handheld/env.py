# This file is injected late into rg_tool.py, you can run arbitrary python code here
# For example override python variables or set environment variables with os.putenv

# Espressif chip in the device
IDF_TARGET = "esp32s3"
# .fw file format, if supported by the device
FW_FORMAT = "none"
# Default apps to build when none is specified (comment to build all)
# DEFAULT_APPS = "launcher prboom-go"

# Theme scripts (Lua) add about 150-200 KB to every app. If an app no longer fits in its partition
# ("app partition is too small"), uncomment this to use bigger partitions (this board has 16 MB of flash).
# Changing partition sizes requires flashing a full image once (build-img, then flash), not `install`.
# PROJECT_APPS = {
#   'launcher':     [0, 16, 1572864],
#   'retro-core':   [0, 16, 1572864],
#   'prboom-go':    [0, 16, 1048576],
#   'gwenesis':     [0, 16, 1572864],
#   'fmsx':         [0, 16, 1048576],
# }
