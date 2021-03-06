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
# a418b29f95884dbd6a576117a759319c *fmodapi44464win-installer.exe
# b6b1cb5f87a375e7a647916c10330c1c *fmodapi44464mac-installer.dmg
# 092faf696a90fb9bfa3c4333d6ec8e62 *fmodapi44464linux.tar.gz
FMOD_ROOT_NAME="fmodapi"
FMOD_VERSION="44464"

case "$AUTOBUILD_PLATFORM" in
    "windows")
    FMOD_OS="win"
    FMOD_PLATFORM="win-installer"
    FMOD_FILEEXTENSION=".exe"
    FMOD_MD5="a418b29f95884dbd6a576117a759319c"
    ;;
    "windows64")
    FMOD_OS="win"
    FMOD_PLATFORM="win-installer"
    FMOD_FILEEXTENSION=".exe"
    FMOD_MD5="a418b29f95884dbd6a576117a759319c"
    ;;    
    "darwin")
    FMOD_OS="mac"
    FMOD_PLATFORM="mac-installer"
    FMOD_FILEEXTENSION=".dmg"
    FMOD_MD5="b6b1cb5f87a375e7a647916c10330c1c"
    ;;
    "darwin64")
    FMOD_OS="mac"
    FMOD_PLATFORM="mac-installer"
    FMOD_FILEEXTENSION=".dmg"
    FMOD_MD5="b6b1cb5f87a375e7a647916c10330c1c"
    ;;
    "linux")
    FMOD_OS="linux"
    FMOD_PLATFORM="linux"
    FMOD_FILEEXTENSION=".tar.gz"
    FMOD_MD5="092faf696a90fb9bfa3c4333d6ec8e62"
    ;;
    "linux64")
    FMOD_OS="linux"
    FMOD_PLATFORM="linux"
    FMOD_FILEEXTENSION=".tar.gz"
    FMOD_MD5="092faf696a90fb9bfa3c4333d6ec8e62"
    ;;
esac
FMOD_SOURCE_DIR="/cygdrive/c/Users/Bill/P64/P64_3p-fmodex/"$FMOD_ROOT_NAME$FMOD_VERSION$FMOD_PLATFORM$FMOD_EXTENSION
FMOD_ARCHIVE="$FMOD_SOURCE_DIR$FMOD_FILEEXTENSION"
FMOD_URL="$FMOD_SOURCE_DIR$FMOD_ARCHIVE"
FMOD_VERSION_PRETTY="4.44.64"
# Fetch and extract the official fmod files
#fetch_archive "$FMOD_URL" "$FMOD_ARCHIVE" "$FMOD_MD5"
#wget "$FMOD_URL" 

# Workaround as extract does not handle .zip files (yet)
# TODO: move that logic to the appropriate autobuild script
case "$FMOD_ARCHIVE" in
    *.exe)
        chmod +x "$FMOD_ARCHIVE"
        mkdir -p "$FMOD_SOURCE_DIR"
        pushd "$FMOD_SOURCE_DIR"
        7z x "$FMOD_ARCHIVE" -aoa
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
echo "${FMOD_VERSION_PRETTY}" > "${stage}/VERSION.txt"
pushd "$FMOD_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            # Copy relevant stuff around: renaming the import lib to make it easier on cmake
            cp "api/lib/fmodexL_vc.lib" "$stage_debug"
            cp "api/lib/fmodex_vc.lib" "$stage_release"
            cp "api/fmodexL.dll" "$stage_debug"
            cp "api/fmodex.dll" "$stage_release"
        ;;
        "windows64")
            cp -dR --preserve=mode,timestamps "api/lib/fmodexL64_vc.lib" "$stage_debug"
            cp -dR --preserve=mode,timestamps "api/lib/fmodex64_vc.lib" "$stage_release"
            cp -dR --preserve=mode,timestamps "api/fmodexL64.dll" "$stage_debug"
            cp -dR --preserve=mode,timestamps "api/fmodex64.dll" "$stage_release"
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
         "darwin64")
            cp "api/lib/libfmodexL64.dylib" "$stage_debug"
            cp "api/lib/libfmodex.dylib64" "$stage_release"
            pushd "$stage_debug"
              fix_dylib_id libfmodexL64.dylib
            popd
            pushd "$stage_release"
              fix_dylib_id libfmodex64.dylib
            popd
        ;;       
        "linux")
            # Copy the relevant stuff around
            cp -a api/lib/libfmodexL-*.so "$stage_debug"
            cp -a api/lib/libfmodex-*.so "$stage_release"
            cp -a api/lib/libfmodexL.so "$stage_debug"
            cp -a api/lib/libfmodex.so "$stage_release"
        ;; 
        "linux64")
            # Copy the relevant stuff around
            cp -a api/lib/libfmodexL64-*.so "$stage_debug"
            cp -a api/lib/libfmodex64-*.so "$stage_release"
            cp -a api/lib/libfmodexL64.so "$stage_debug"
            cp -a api/lib/libfmodex64.so "$stage_release"
        ;;       
    esac

    # Copy the headers
    cp -a api/inc/* "$stage/include/fmodex"

    # Copy License (extracted from the readme)
    cp "documentation/LICENSE.TXT" "$stage/LICENSES/fmodex.txt"
popd
wait

