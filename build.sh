#!/bin/sh
# Build Quake for the MiSTer in the toolchain container: static SDL2 with the
# hybrid core drivers first (once), then the game.
# usage: ./build.sh [mister|host] [Release|RelWithDebInfo|Debug]
#   mister  ARM binary for the MiSTer     -> build/mister/chocolatequake
#   host    same code for this PC, to run against hybrid/tools/fakecore
set -e
cd "$(dirname "$0")"
TARGET=${1:-mister}
TYPE=${2:-Release}
ROOT=$PWD
PREFIX=$ROOT/build/sdl/$TARGET/prefix

hybrid/docker.sh hybrid/sdl2/build.sh "$TARGET" build/sdl

CROSS=
if [ "$TARGET" = mister ]; then
    CROSS="-DCMAKE_TOOLCHAIN_FILE=$ROOT/hybrid/toolchain/mister.cmake -DCMAKE_FIND_ROOT_PATH=$PREFIX"
    # ARM instructions, not Thumb: a few percent faster (the Xash3D core).
    # Replaces the toolchain file's flags, so they are repeated.
    CROSS="$CROSS -DCMAKE_C_FLAGS='-mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard -fno-pie -marm'"
    # the compiler's runtime is linked in, the binary only needs the MiSTer's glibc
    CROSS="$CROSS -DCMAKE_EXE_LINKER_FLAGS='-no-pie -static-libstdc++ -static-libgcc'"
fi

# GAME: Chocolate Quake with MISTER_HYBRID: the music decoders of SDL2_mixer's
# source (stb_vorbis, dr_flac, minimp3) in place of libvorbis, libFLAC, libmad
CODECS=$(ls -d build/sdl/src/SDL2_mixer-*/src/codecs | head -1)
hybrid/docker.sh sh -c "
  cmake -S chocolatequake -B build/$TARGET/cmake -DCMAKE_BUILD_TYPE=$TYPE $CROSS \
    -DCMAKE_PREFIX_PATH=$PREFIX -DMISTER_HYBRID=ON -DMISTER_CODECS=$ROOT/$CODECS \
    > build/$TARGET-configure.log &&
  cmake --build build/$TARGET/cmake -j\$(nproc)"
cp "build/$TARGET/cmake/src/chocolate-quake" "build/$TARGET/chocolatequake"
ls -la "build/$TARGET/chocolatequake"

# The launch script's messages on the core's picture (hybrid/tools/mh_message.c)
if [ "$TARGET" = mister ]; then
    hybrid/docker.sh arm-linux-gnueabihf-gcc -O2 -static -Ihybrid/hps -o build/mister/mh_message \
        hybrid/tools/mh_message.c hybrid/hps/*.c -lpthread -lm
fi
