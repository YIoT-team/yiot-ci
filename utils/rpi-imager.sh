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
  echo "$(basename ${0}) < resize | shell | mount | umount | install > <parameters>"

  echo
  echo "Usage:"
  echo "- Resize image:"
  echo "  $(basename ${0}) resize -s <increase size in Mb"  

  echo
  echo "- Run shell:"  
  echo "  $(basename ${0}) shell -i <RPI image path>" 
  
  echo
  echo "- Exec command:"  
  echo "  $(basename ${0}) exec -c <command>" 
  
  echo
  echo "- Mounting image fs:"  
  echo "  $(basename ${0}) mount -i <RPI image path>"   

  echo
  echo "- Unmounting image fs:"  
  echo "  $(basename ${0}) umount"
  
  echo
  echo "- Install packages:"  
  echo "  $(basename ${0}) install -i <RPI image path> -p <custom DEB package path> -a <Additional stantart packages list> -e"    

  echo
  echo "- Print help:"  
  echo "  $(basename ${0}) help"
  exit 0
}
############################################################################################
#
#  Script parameters
#
############################################################################################
GLOB_LODEVICE=""
GLOB_PARTNAME=""
#ARG_RPIIMAGE="2020-08-20-raspios-buster-armhf-lite.img"
IGNORE_ERR="0"
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
     -c) ARG_COMMAND="$2"
         shift
         ;;         
     -e) IGNORE_ERR="1"
         ;;                  
   esac
   shift
done

############################################################################################
find_tool() {
    local PARAM_CMD="${1}"
    RES_TMP="$(which ${PARAM_CMD} 2>&1)"
    if [ "${?}" != "0" ]; then
	echo "Tools [${PARAM_CMD}] NOT FOUND (Please install first)"
	return 127
    fi
    return 0
}

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
    print_message "Mounting FS (${GLOB_PARTNAME}) ${SCRIPT_DIRECTORY}/mnt"
    umount_fs
    rm -rf ${SCRIPT_DIRECTORY}/mnt
    mkdir -p ${SCRIPT_DIRECTORY}/mnt
    mount ${GLOB_PARTNAME} ${SCRIPT_DIRECTORY}/mnt
    RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then
	print_error "${RET_RES}" "Error mounting ${PARAM_PART}"
	umount_image
	return "${RET_RES}"
    fi
}

############################################################################################
umount_fs() {
    RES_TMP=$(umount  "${SCRIPT_DIRECTORY}/mnt" 2>&1 >>/dev/null)
    if [ "${?}" != "0" ]; then
	RES_TMP=$(umount -l "${SCRIPT_DIRECTORY}/mnt" 2>&1 >>/dev/null)
    fi    
}

############################################################################################
umount_image() {
    PARAM_RETURN=""
    print_message "Unmounting"
    print_message "Unmounting FS"    
    umount_fs    

    print_message "Unmounting image"
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
    
    systemd-nspawn -D "${SCRIPT_DIRECTORY}/mnt" /bin/bash -i -c "${PARAM_CMD}"

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
}

############################################################################################
cmd_mount() {
    print_title "Mounting image to ${SCRIPT_DIRECTORY}/mnt"
    mount_image 
    [ "${?}" != "0" ] && exit 127
    mount_fs
    [ "${?}" != "0" ] && exit 127
}

############################################################################################
cmd_umount() {
    print_title "Unmounting ${SCRIPT_DIRECTORY}/mnt"
    TMP_RES=$(umount "${SCRIPT_DIRECTORY}/mnt" 2>&1)
    RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then
        print_error "${TMP_RES}" "Error unmounting"
        exit 127
    fi  
    losetup -D
}

############################################################################################
cmd_shell() {
    print_title "Executing shell"
    cmd_mount
    bash -i -c "systemd-nspawn -M RPI -D ${SCRIPT_DIRECTORY}/mnt"
    cmd_umount
}

############################################################################################
cmd_install() {
    print_title "Installing packages"
    if [ -z "${ARG_PACKAGE}" ] && [ -z "${ARG_ADDPACKAGES}" ]; then
      print_message "ERROR: packages not specified"
      exit 127
    fi

    cmd_mount
    
    if [ ! -z "${ARG_ADDPACKAGES}" ]; then
	print_message "Installing: [${ARG_ADDPACKAGES}]"
	exec_nspawn "apt-get -y update && apt-get -y install ${ARG_ADDPACKAGES}"	
	local RET_RES="${?}"
	if [ "${RET_RES}" != "0" ] && [ "${IGNORE_ERR}" != "1" ]; then 
	    cmd_umount	
	    exit 127
	fi    	
    fi

    if [ ! -z "${ARG_PACKAGE}" ]; then
	print_message "Installing: [${ARG_PACKAGE}]"
	mkdir -p "${SCRIPT_DIRECTORY}/mnt/root/pkg"
	cp -f "${ARG_PACKAGE}" "${SCRIPT_DIRECTORY}/mnt/root/pkg"
	PACKAGE_NAME="$(basename ${ARG_PACKAGE})"
	exec_nspawn "apt-get -y update && dpkg -i /root/pkg/${PACKAGE_NAME} && apt-get install -f"	
	local RET_RES="${?}"
	rm -rf "${SCRIPT_DIRECTORY}/mnt/root/pkg"
	if [ "${RET_RES}" != "0" ] && [ "${IGNORE_ERR}" != "1" ]; then 
	    cmd_umount	
	    exit 127
	fi    
    fi
    cmd_umount
}

############################################################################################
cmd_exec() {
    print_title "Execute command"
    if [ -z "${ARG_COMMAND}" ]; then
      print_message "ERROR: command not specified"
      exit 127
    fi

    cmd_mount
    exec_nspawn "${ARG_COMMAND}"	
    RET_RES="${?}"
    if [ "${RET_RES}" != "0" ]; then
        cmd_umount
        exit 127
    fi      
    cmd_umount
}



############################################################################################
print_title "Detecting tools"
find_tool losetup || FIND_RES=1
find_tool parted || FIND_RES=1
find_tool mount || FIND_RES=1
find_tool resize2fs || FIND_RES=1
find_tool dd || FIND_RES=1
find_tool losetup || FIND_RES=1
find_tool partprobe || FIND_RES=1
find_tool qemu-arm-static || FIND_RES=1
find_tool basename || FIND_RES=1
find_tool systemd-nspawn || FIND_RES=1
if [ "${FIND_RES}" == "1" ]; then
 print_message "Please install required tools"
 exit 127
else
 print_message "OK" 
fi

case "${MAIN_COMMAND}" in
     resize) 	cmd_increase_image
        	;;
     shell) 	cmd_shell
    		;;
     exec) 	cmd_exec
    		;;    		
     mount) 	cmd_mount
    		;;
     umount) 	cmd_umount
    		;;    		
     install)   cmd_install
    		;;    	     
     *) 	print_usage
    		;;
esac

print_message "Process finish"
exit 0
