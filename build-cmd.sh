#!/bin/bash

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
# 4024a88133b00968013874b0eeaec9d0 *fmodapi44450linux.tar.gz
# 5900f269e10d38d54c989b79ccd686e7 *fmodapi44450mac-installer.dmg
# 202a1dcdeb94cbd8645268c86cb2a149 *fmodapi44450win-installer.exe
FMOD_ROOT_NAME="fmodapi"
FMOD_VERSION="44454"

case "$AUTOBUILD_PLATFORM" in
    "windows")
    FMOD_OS="win"
    FMOD_PLATFORM="win-installer"
    FMOD_FILEEXTENSION=".exe"
    FMOD_MD5="b34f05c1d88db6b83d6787aa71cb5946"
    ;;
    "darwin")
    FMOD_OS="mac"
    FMOD_PLATFORM="mac-installer"
    FMOD_FILEEXTENSION=".dmg"
    FMOD_MD5="f30fe1b27e734fbf7a649a81ec21b87d"
    ;;
    "linux")
    FMOD_OS="linux"
    FMOD_PLATFORM="linux"
    FMOD_FILEEXTENSION=".tar.gz"
    FMOD_MD5="b795ecde375a45efc9e84b98a8009266"
    ;;
esac
FMOD_SOURCE_DIR="$FMOD_ROOT_NAME$FMOD_VERSION$FMOD_PLATFORM"
FMOD_ARCHIVE="$FMOD_SOURCE_DIR$FMOD_FILEEXTENSION"
FMOD_URL="http://www.fmod.org/download/fmodex/api/$FMOD_OS/$FMOD_ARCHIVE"

# Fetch and extract the official fmod files
fetch_archive "$FMOD_URL" "$FMOD_ARCHIVE" "$FMOD_MD5"
# Workaround as extract does not handle .zip files (yet)
# TODO: move that logic to the appropriate autobuild script
case "$FMOD_ARCHIVE" in
    *.exe)
        chmod +x "$FMOD_ARCHIVE"
        mkdir -p "$FMOD_SOURCE_DIR"
        pushd "$FMOD_SOURCE_DIR"
        7z x ../"$FMOD_ARCHIVE" -aoa
        popd
    ;;
    *.tar.gz)
        extract "$FMOD_ARCHIVE"
    ;;
    *.dmg)
        hdid "$FMOD_ARCHIVE"
        mkdir -p "$(pwd)/$FMOD_SOURCE_DIR"
        cp -r /Volumes/FMOD\ Programmers\ API\ Mac/FMOD\ Programmers\ API/* "$FMOD_SOURCE_DIR"
        umount /Volumes/FMOD\ Programmers\ API\ Mac/
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

pushd "$FMOD_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            # Copy relevant stuff around: renaming the import lib to make it easier on cmake
            cp "api/lib/fmodexL_vc.lib" "$stage_debug"
            cp "api/lib/fmodex_vc.lib" "$stage_release"
            cp "api/fmodexL.dll" "$stage_debug"
            cp "api/fmodex.dll" "$stage_release"
        ;;
        "darwin")
            cp "api/lib/libfmodexL.dylib" "$stage_debug"
            cp "api/lib/libfmodex.dylib" "$stage_release"
            pushd "$stage_debug"
              fix_dylib_id libfmodexL.dylib
            popd
            pushd "$stage_release"
              fix_dylib_id libfmodex.dylib
            popd
        ;;
        "linux")
            # Copy the relevant stuff around
            cp -a api/lib/libfmodexL-*.so "$stage_debug"
            cp -a api/lib/libfmodex-*.so "$stage_release"
            cp -a api/lib/libfmodexL.so "$stage_debug"
            cp -a api/lib/libfmodex.so "$stage_release"
        ;;    
    esac

    # Copy the headers
    cp -a api/inc/* "$stage/include/fmodex"

    # Copy License (extracted from the readme)
    cp "documentation/LICENSE.TXT" "$stage/LICENSES/fmodex.txt"
popd
pass

