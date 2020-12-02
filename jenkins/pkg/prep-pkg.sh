#!/bin/bash
set -o errtrace

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -e

[ -z ${1} ] && exit 1

######################################################################
BUILD_PATH="${SCRIPT_PATH}/build/"
SDEB_PATH="${BUILD_PATH}/deb"
PACKAGE_NAME=${PACKAGE_NAME:-"yiot-rpi"}

PROJ_DIR="${1}"

VERSION="$(cat ${PROJ_DIR}/VERSION_MESSENGER | tr -d '\n')"

MAJOR_VER="0"
MINOR_VER="1"
SUB_VER="0"
BUILD_VER="${BUILD_VER:-0}"

PKG_SRC_NAME="${PACKAGE_NAME}-${MAJOR_VER}.${MINOR_VER}.${SUB_VER}"

export MAJOR_VER MINOR_VER SUB_VER BUILD_VER

############################################################################################
echo_info() {
echo "--- Package version"
echo "MAJOR=$MAJOR_VER"
echo "MINOR=$MINOR_VER"
echo "SUB  =$SUB_VER"
echo "BUILD=$BUILD_VER"
echo "--- "
}

############################################################################################
create_dirs() {
 echo "Remove old dirs and create new"
 rm -rf ${BUILD_PATH}
 mkdir -p ${BUILD_PATH}/${PKG_SRC_NAME}
 mkdir -p ${BUILD_PATH}/linux
}

############################################################################################
prep_sources() {
   mkdir -p ${BUILD_PATH}/${PKG_SRC_NAME}/dist
   cp -rf ${PROJ_DIR}/build/device-app/main/linux/yiot-device-app-linux ${BUILD_PATH}/${PKG_SRC_NAME}/dist
   cp -rf ${PROJ_DIR}/develop/device-app/main/linux/scripts/* ${BUILD_PATH}/${PKG_SRC_NAME}/dist
}

############################################################################################
create_sdeb() {
 pushd ${BUILD_PATH}
  mkdir -p sdeb
  echo "------------- Create DEB from template ------------------------------"         
  tar xJf ../deb/${PACKAGE_NAME}.debian.tar.xz
  j2 -f env -o sdeb/${PACKAGE_NAME}_${MAJOR_VER}.${MINOR_VER}.${SUB_VER}-${BUILD_VER}.dsc ../deb/${PACKAGE_NAME}.dsc.tmpl
  j2 -f env -o debian/changelog debian/changelog
  tar cJf sdeb/${PACKAGE_NAME}_${MAJOR_VER}.${MINOR_VER}.${SUB_VER}-${BUILD_VER}.debian.tar.xz debian
  rm -rf debian
  echo "------------- Create archive for SDEB  ------------------------------"          
  tar czf sdeb/${PACKAGE_NAME}_${MAJOR_VER}.${MINOR_VER}.${SUB_VER}.orig.tar.gz ${PACKAGE_NAME}-$MAJOR_VER.$MINOR_VER.$SUB_VER
  pushd sdeb
  echo "------------- Create checksum for DEB  ------------------------------"            
  file_dsc=${PACKAGE_NAME}_${MAJOR_VER}.${MINOR_VER}.${SUB_VER}-${BUILD_VER}.dsc
  file_deb_name=${PACKAGE_NAME}_${MAJOR_VER}.${MINOR_VER}.${SUB_VER}-${BUILD_VER}.debian.tar.xz
  file_src_name=${PACKAGE_NAME}_${MAJOR_VER}.${MINOR_VER}.${SUB_VER}.orig.tar.gz

  file_deb_size=$(stat --printf="%s" "$file_deb_name")
  file_src_size=$(stat --printf="%s" "$file_src_name")

  file_sha1_src_hash=$(sha1sum "$file_src_name" | cut -f1 -d ' ')
  file_sha256_src_hash=$(sha256sum "$file_src_name" | cut -f1 -d ' ')
  file_md5_src_hash=$(md5sum "$file_src_name" | cut -f1 -d ' ')

  file_sha1_deb_hash=$(sha1sum "$file_deb_name" | cut -f1 -d ' ')
  file_sha256_deb_hash=$(sha256sum "$file_deb_name" | cut -f1 -d ' ')
  file_md5_deb_hash=$(md5sum "$file_deb_name" | cut -f1 -d ' ')

  echo "Checksums-Sha1:" >> $file_dsc
  echo " $file_sha1_src_hash $file_src_size $file_src_name"  >> $file_dsc
  echo " $file_sha1_deb_hash $file_deb_size $file_deb_name"  >> $file_dsc

  echo "Checksums-Sha256:" >> $file_dsc
  echo " $file_sha256_src_hash $file_src_size $file_src_name"  >> $file_dsc
  echo " $file_sha256_deb_hash $file_deb_size $file_deb_name"  >> $file_dsc

  echo "Files:" >> $file_dsc
  echo " $file_md5_src_hash $file_src_size $file_src_name"  >> $file_dsc
  echo " $file_md5_deb_hash $file_deb_size $file_deb_name"  >> $file_dsc
  popd
 popd
}

############################################################################################
docker_exec() {
  sudo docker exec ${DOCKER_CONTAINER} bash -c "${@}"
}

############################################################################################
docker_cp() {
  sudo docker cp ${DOCKER_CONTAINER}:"${1}" "${2}"
}

############################################################################################
build_deb() {
 pushd ${BUILD_PATH}/sdeb/
   print_message "Initialization pbuilder root"   
   pbuilder create --distribution buster

   print_message "Update pbuilder root"   
   pbuilder --update
   
   print_message "Building DEB package"      
   pbuilder --build $(ls *.dsc)
   
   print_message "Copy results fro mcontainer"
   cp -f /var/cache/pbuilder/result/*.deb ${BUILD_PATH}/linux
 popd
}

############################################################################################
echo_info
create_dirs

pushd ${BUILD_PATH} 
  prep_sources
  create_sdeb
  build_deb
popd
echo "------ END PREPARING SRPMS"
exit 0
