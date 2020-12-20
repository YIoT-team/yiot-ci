#!/bin/bash
set -o errtrace

SCRIPT_FOLDER="$(cd $(dirname "$0") && pwd)"
SRC_FILES="${1}"
DST_DIR="${2}"

############################################################################################
echo "### Upload zip to bintray"
rsync -avrlz --password-file=${HOME}/.rsync ${SRC_FILES} rsync://ftp@harbor.localnet/ftp/${DST_DIR}/
RET_RES="${?}"
if [ "${RET_RES}" == "0" ]; then
    echo "### ALL OPERATION DONE"
else
    echo "### ERROR RES:[${RET_RES}]"
fi

############################################################################################

