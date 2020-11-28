#!/bin/bash
#
#   Global variables
#

set -e
SCRIPT_FOLDER="$(cd $(dirname "$0") && pwd)"

#***************************************************************************************
function print_message() {
    echo
    echo "===================================="
    echo "=== ${1}"
    echo "===================================="
}

############################################################################################
print_usage() {
  echo
  echo "$(basename ${0})"
  echo
  echo "  -s < Source directory >"
  echo "  -t < Target OS  >"
  echo "  -h"
  exit 0
}
############################################################################################
#
#  Script parameters
#
############################################################################################

SOURCE_DIR="${SCRIPT_FOLDER}/../yiot"
TARGET_OS="linux"

while [ -n "$1" ]
 do
   case "$1" in
     -h) print_usage
         exit 0
         ;;
     -s) SOURCE_DIR="$2"
         shift
         ;;
     -t) TARGET_OS="$2"
         shift
         ;;          
     *) print_usage;;
   esac
   shift
done

############################################################################################
build_linux() {
    print_message " Remove old build directory"
    rm -rf "${SOURCE_DIR}/build" || true
    mkdir -p "${SOURCE_DIR}/build"
    export QTDIR=/opt/Qt/5.15.0/gcc_64
    pushd "${SOURCE_DIR}/build"
       cmake -DKS_PLATFORM="linux" -DGO_DISABLE=ON -DBUILD_APP_ENABLE=OFF ..
       make
    popd
}

############################################################################################

############################################################################################

case "${TARGET_OS}" in
  linux)	build_linux
    		;;
esac


