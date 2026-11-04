// macOS has no <malloc.h>; the functions some sources expect from it live in <stdlib.h>.
// Only used by tools/build_sdl2_macos.sh.
#pragma once
#include <stdlib.h>
