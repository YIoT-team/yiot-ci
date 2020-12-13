#!/bin/bash

SCRIPT_DIRECTORY="$(cd $(dirname "$0") && pwd)"

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
  echo "$(basename ${0}) < resize | shell | install > <parameters>"
  echo
  echo "  Parameters:"
  echo "  -s < Source directory >"
  echo "  -i < Image path  >"
  echo "  -p < DEB package  >"
  echo "  -a < Install additional packages  >"
  echo "  -s < Increase image size (MB)  >"
  echo "  -h"
  exit 0
}
############################################################################################
#
#  Script parameters
#
############################################################################################
GLOB_LODEVICE=""
GLOB_PARTNAME=""
ARG_RPIIMAGE="2020-08-20-raspios-buster-armhf-lite.img"
MAIN_COMMAND="${1}"
shift
if [ ! "${MAIN_COMMAND}" ] || [ "${MAIN_COMMAND}" == "help" ]; then
    print_usage
    exit 0
fi

while [ -n "$1" ]
 do
   case "$1" in
     -i) ARG_RPIIMAGE="$2"
         shift
         ;;
     -p) ARG_PACKAGE="$2"
         shift
         ;;
     -a) ARG_ADDPACKAGES="$2"
         shift
         ;;
     -s) ARG_INCRSIZE="$2"
         shift
         ;;
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
detect_part() {
 echo
}

############################################################################################
mount_image() {
    if [ -z "${ARG_RPIIMAGE}" ]; then
      print_message "Image not specified"
      return 127
    fi
    
    if [ ! -f "${ARG_RPIIMAGE}" ]; then
      print_message "Image file not found"
      return 127
    fi    

    PARAM_RETURN=""
    print_message "Mounting image"
    GLOB_LODEVICE="$(losetup --show -f -P "${ARG_RPIIMAGE}" 2>&1 )"
    local RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then 
	print_error "${RET_RES}" "Error mounting image [${LO_DEVICE}]"
	return 127
    fi
    sleep 3
    print_message "Determine linux partition"
    local LSBLK_RES="$(lsblk -fnpP ${GLOB_LODEVICE} | grep ext4)"
    RET_RES="${?}"
    if [ "${RET_RES}" == "0" ]; then
        GLOB_PARTNAME="$(parse_values "${LSBLK_RES}" "NAME")"
        local PART_FSTYPE="$(parse_values "${LSBLK_RES}" "FSTYPE")"        
        local PART_LABEL="$(parse_values "${LSBLK_RES}" "LABEL")"        
        local PART_UUID="$(parse_values "${LSBLK_RES}" "UUID")"        
	echo "NAME:     ${GLOB_PARTNAME}"
	echo "FSTYPE:   ${PART_FSTYPE}"
	echo "LABEL:    ${PART_LABEL}"
	echo "UUID:     ${PART_UUID}"	
	if [ "${GLOB_PARTNAME}" == "" ]; then
	    print_error "127" "Linux partition not found"
	    umount_image
	    return 127
	fi
    else
    	print_error "127" "Error determination partition"
	umount_image
	return 127
    fi
    return 0
}
############################################################################################
mount_fs() {
    local PARAM_PART="${1}"
    print_message "Mounting FS (${PARAM_PART})"
    TMP_RES="$(umount -l "${SCRIPT_DIRECTORY}/mnt" 2>&1 >>/dev/null)"
    rm -rf mnt
    mkdir -p mnt
    mount ${PARAM_PART} mnt
    RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then
    print_error "${RET_RES}" "Error mounting ${PARAM_PART}"
	umount_image "${LO_DEVICE}"
	return "${RET_RES}"
    fi
}

############################################################################################
umount_image() {
    PARAM_RETURN=""
    print_message "Unmounting image and fs"
    print_message "Unmounting FS"    
    RES_TMP=$(umount  "${SCRIPT_DIRECTORY}/mnt" 2>&1 >>/dev/null)
    if [ "${?}" != "0" ]; then
	RES_TMP=$(umount -l "${SCRIPT_DIRECTORY}/mnt" 2>&1 >>/dev/null)
    fi    

    print_title "Unmounting image"
    local UMOUNT_MSG="$(losetup -d "${GLOB_LODEVICE}" 2>&1 )"
    local RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then 
	print_error "${RET_RES}" "Error unmounting image [${UMOUNT_MSG}]"
	return 127
    fi

    return 0
}

############################################################################################
exec_nspawn() {
    local PARAM_CMD="${1}"
    print_title "Execute command in container"
    
    systemd-nspawn -D "${SCRIPT_DIRECTORY}/mnt" /bin/bash -c "${PARAM_CMD}"

    local RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then 
	print_error "${RET_RES}" "Error execute [${PARAM_CMD}]"
	return 127
    fi    
    return 0
}
############################################################################################
############################################################################################
############################################################################################
cmd_increase_image() {
    if [ -z "${ARG_INCRSIZE}" ]; then
	print_message "Increase size not specified"
	exit 127	
    fi 


    if [ ! -f "${ARG_RPIIMAGE}" ]; then
      print_message "Image file not found"
      return 127
    fi

    print_title "Resize image {+${ARG_INCRSIZE}Mb]"
    echo "Increase size: [${ARG_INCRSIZE}]"    
    echo "Image:         [${ARG_RPIIMAGE}]"    

    print_message "Increase image size"    
    dd if=/dev/zero of="${ARG_RPIIMAGE}" bs=1M count="${ARG_INCRSIZE}" conv=notrunc oflag=append
    RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then
        print_error "${RET_RES}" "Error resize image"
        umount_image
        exit 127
    fi
    sync

    mount_image 
    [ "${?}" != "0" ] && exit 127

    print_message "Resize partition ${GLOB_PARTNAME}"    
    RES_TMP="$(parted ${GLOB_LODEVICE} resizepart ${GLOB_PARTNAME: -1} 100% 2>&1)"
    RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then
        print_error "${RES_TMP}" "Error resize partition"
        umount_image
        exit 127
    fi    
    partprobe ${GLOB_LODEVICE}

    print_message "Resize fs ${GLOB_PARTNAME}"    
    resize2fs -f ${GLOB_PARTNAME}
    RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then
        print_error "${RET_RES}" "Error resize file system"
        umount_image
        exit 127
    fi  
    sync  
    umount_image
    exit 0
}

############################################################################################

case "${MAIN_COMMAND}" in
     resize) 	cmd_increase_image
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
exit 0


# Increase image size
if [ ! -z "${INCR_SIZE}" ]; then
    increase_image "${ARG_RPIIMAGE}" "${INCR_SIZE}"
    if [ "${?}" != "0" ]; then
        exit 127
    fi
fi

# Mounting image, fs
mount_image ${ARG_RPIIMAGE}
RET_RES="${?}"
if [ "${RET_RES}" != "0" ]; then
    print_error "${RET_RES}" "Error mounting"
    exit  127
fi

LODEVICE="${PARAM_RETURN_LODEVICE}"
PARTITION="${PARAM_RETURN_PARTITION}"


exit 0
exec_nspawn "ls /"

umount_image "${PARAM_RETURN_LODEVICE}"
echo "Retres $?"

