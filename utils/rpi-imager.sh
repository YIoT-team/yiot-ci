#!/bin/bash


############################################################################################
print_title() {
  echo "#########################################"
  echo "### ${@}"
  echo "#########################################"  
}

############################################################################################
print_message() {
  echo "=== ${@}"
}

#***************************************************************************************
print_error() {
    local PARAM_RET_RES="${1}"
    local PARAM_RET_MSG="${2}"
    echo "----------------------------------------------------------------------"
    echo "### ---= PROCESS ERROR =---"
    echo "### ERRORCODE = [${PARAM_RET_RES}]"
    echo "### ERRORMSG  = ${PARAM_RET_MSG}"        
    echo "----------------------------------------------------------------------"
}


############################################################################################
print_usage() {
  echo
  echo "$(basename ${0})"
  echo
  echo "  -s < Source directory >"
  echo "  -t < Target OS  >"
  echo "  -c < Customer  >"
  echo "  -l < notarization login  >"
  echo "  -p < notarization password  >"
  echo "  -h"
  exit 0
}
############################################################################################
#
#  Script parameters
#
############################################################################################
RPI_IMAGE="2020-08-20-raspios-buster-armhf-lite.img"
while [ -n "$1" ]
 do
   case "$1" in
     -h) print_usage
         exit 0
         ;;
     -i) RPI_IMAGE="$2"
         shift
         ;;
     -p) PACKAGE="$2"
         shift
         ;;
     -a) ADD_PACKAGES="$2"
         shift
         ;;
     -s) INCR_SIZE="$2"
         shift
         ;;
     *) print_usage;;
   esac
   shift
done
############################################################################################
parse_values() {
    local PARAM_VALUES=${1}
    local PARAM_NAME=${2}
    for VALUEPAIR in ${PARAM_VALUES}; do
      local PAIR_NAME="$(echo ${VALUEPAIR} |cut -d'=' -f1)"
      local PAIR_VALUE=$(echo ${VALUEPAIR} |cut -d'=' -f2| sed 's/"//g')
      if [ "${PARAM_NAME}" == "${PAIR_NAME}" ]; then
        echo "${PAIR_VALUE}"
      fi
    done
}

############################################################################################
mount_part() {
 echo
}

############################################################################################
umount_part() {
 echo
}

############################################################################################
mount_image() {
    local PARAM_IMAGE="${1}"
    PARAM_RETURN=""
    print_title "Mounting image"
    local LO_DEVICE="$(losetup --show -f -P "${PARAM_IMAGE}" 2>&1 )"
    local RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then 
	print_error "${RET_RES}" "Error mounting image [${LO_DEVICE}]"
	return 127
    fi
    sleep 3
    print_message "Determine linux partition"
    local LSBLK_RES="$(lsblk -fnpP ${LO_DEVICE} | grep ext4)"
    RET_RES="${?}"
    if [ "${RET_RES}" == "0" ]; then
        local PART_NAME="$(parse_values "${LSBLK_RES}" "NAME")"
        local PART_FSTYPE="$(parse_values "${LSBLK_RES}" "FSTYPE")"        
        local PART_LABEL="$(parse_values "${LSBLK_RES}" "LABEL")"        
        local PART_UUID="$(parse_values "${LSBLK_RES}" "UUID")"        
	echo "NAME:     ${PART_NAME}"
	echo "FSTYPE:   ${PART_FSTYPE}"
	echo "LABEL:    ${PART_LABEL}"
	echo "UUID:     ${PART_UUID}"	
	if [ "${PART_NAME}" == "" ]; then
	    print_error "127" "Linux partition not found"
	    return 127
	fi
    fi
    PARAM_RETURN_LODEVICE="${LO_DEVICE}"
    PARAM_RETURN_PARTITION="${PART_NAME}"    
}

############################################################################################
umount_image() {
    local PARAM_LODEVICE="${1}"
    PARAM_RETURN=""
    print_title "Unmounting image"
    local UMOUNT_MSG="$(losetup -d "${PARAM_LODEVICE}" 2>&1 )"
    local RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then 
	print_error "${RET_RES}" "Error unmounting image [${UMOUNT_MSG}]"
	return 127
    fi
    return 0
}

############################################################################################

mount_image ${RPI_IMAGE}
echo "Retres $?"

LODEVICE="${PARAM_RETURN_LODEVICE}"
PARTITION="${PARAM_RETURN_PARTITION}"

echo "RET FUNC LODEVICE = ${LODEVICE}"
echo "RET FUNC PARTITION = ${PARTITION}"

losetup -D