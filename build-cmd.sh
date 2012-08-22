#!/bin/sh

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

# Check autobuild is around or fail
if [ -z "$AUTOBUILD" ] ; then
    fail
fi
if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# Load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

# Form the official fmod archive URL to fetch
# Note: fmod is provided in 3 flavors (one per platform) of precompiled binaries. We do not have access to source code.
FMOD_ROOT_NAME="fmodapi"
FMOD_VERSION="44201"
FMOD_VERSION_PRETTY="4.42.01"
case "$AUTOBUILD_PLATFORM" in
    "windows")
    FMOD_PLATFORM="win-installer"
    FMOD_FILEEXTENSION=".exe"
    FMOD_MD5="8e30e4159c68b96ab630454af4c5e606"
    ;;
    "darwin")
    FMOD_PLATFORM="mac-installer"
    FMOD_FILEEXTENSION=".dmg"
    FMOD_MD5="69011586de5725de08c10611b1a0289a"
    ;;
    "linux")
    FMOD_PLATFORM="linux"
    FMOD_FILEEXTENSION=".tar.gz"
    FMOD_MD5="561e03bf245660d71f7963689d833bfa"
    ;;
    "linux64")
    FMOD_PLATFORM="linux64"
    FMOD_FILEEXTENSION=".tar.gz"
    FMOD_MD5="63faae1c6c60c6146b9a54426079c314"
    ;;
esac
FMOD_SOURCE_DIR="$FMOD_ROOT_NAME$FMOD_VERSION$FMOD_PLATFORM"
FMOD_ARCHIVE="$FMOD_SOURCE_DIR$FMOD_FILEEXTENSION"
FMOD_URL="http://www.fmod.org/index.php/release/version/$FMOD_ARCHIVE"

# Fetch and extract the official fmod files
fetch_archive "$FMOD_URL" "$FMOD_ARCHIVE" "$FMOD_MD5"
# Workaround as extract does not handle .zip files (yet)
# TODO: move that logic to the appropriate autobuild script
case "$FMOD_ARCHIVE" in
    *.exe)
        7z x "$FMOD_ARCHIVE" -o"$FMOD_SOURCE_DIR"
	;;
    *.zip)
        # unzip locally, redirect the output to a local log file
        unzip -n "$FMOD_ARCHIVE" >> "$FMOD_ARCHIVE".unzip-log 2>&1
    ;;
    *.tar.gz)
        extract "$FMOD_ARCHIVE"
    ;;
esac

stage="$(pwd)/stage"
stage_release="$stage/lib/release"
stage_debug="$stage/lib/debug"

# Create the staging license folder
mkdir -p "$stage/LICENSES"

# Create the staging include folders
mkdir -p "$stage/include/fmodex"

#Create the staging debug and release folders
mkdir -p "$stage_debug"
mkdir -p "$stage_release"

# Rename to avoid the platform name in the root dir, easier to match autobuild.xml
mv "$FMOD_SOURCE_DIR" "$FMOD_ROOT_NAME$FMOD_VERSION"

pushd "$FMOD_ROOT_NAME$FMOD_VERSION"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            # Copy relevant stuff around: renaming the import lib to make it easier on cmake
            cp "api/lib/fmodexL_vc.lib" "$stage_debug"
            cp "api/lib/fmodex_vc.lib" "$stage_release"
            cp "api/fmodexL.dll" "$stage_debug"
            cp "api/fmodex.dll" "$stage_release"
        ;;
        "darwin")
            # Create a universal version of the lib for the Mac
            # Note : we do *not* support PPC anymore since Viewer 2 but we leave that here
            # in case we might still need to create universal binaries with fmod in some other project
            lipo -create "api/lib/libfmod.a" "api/lib/libfmodx86.a" -output "api/lib/libfmod.a"
            touch -r "api/lib/libfmodx86.a" "api/lib/libfmod.a"
            # Create a staging folder
            mkdir -p "$stage/lib/release"
            # Copy relevant stuff around
            cp "api/lib/libfmod.a" "$stage/lib/release/libfmod.a"
        ;;
        "linux")
            # Copy the relevant stuff around
            cp -a "api/lib/libfmodexL-$FMOD_VERSION_PRETTY.so" "$stage_debug"
            cp -a "api/lib/libfmodex-$FMOD_VERSION_PRETTY.so" "$stage_release"
            cp -a "api/lib/libfmodexL.so" "$stage_debug"
            cp -a "api/lib/libfmodex.so" "$stage_release"
        ;;    
        "linux64")
            # Copy the relevant stuff around
            cp -a "api/lib/libfmodexL64-$FMOD_VERSION_PRETTY.so" "$stage_debug"
            cp -a "api/lib/libfmodex64-$FMOD_VERSION_PRETTY.so" "$stage_release"
            cp -a "api/lib/libfmodexL64.so" "$stage_debug"
            cp -a "api/lib/libfmodex64.so" "$stage_release"
        ;;
    esac

    # Copy the headers
    cp -a api/inc/* "$stage/include/fmodex"

    # Copy License (extracted from the readme)
    cp "documentation/LICENSE.TXT" "$stage/LICENSES/fmodex.txt"
popd
pass

