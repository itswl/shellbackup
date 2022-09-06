#!/bin/bash

ceph_common_log="/tmp/ceph_common_install.log"

getSystime(){
  echo "`date "+%Y-%m-%d %H:%M:%S"`"
}

install_ceph_common(){
  echo "<<<===================================" >> ${ceph_common_log}
  if [ -f "/usr/bin/ceph" ];then  
    echo "[INFO]: File /usr/bin/ceph already exists.---$(getSystime)" >> ${ceph_common_log}
    exit 0
  else
    echo "[INFO]: Run 'yum install ceph-common -y' command.---$(getSystime)" >> ${ceph_common_log}
    /bin/yum install ceph-common ceph-fuse -y >> ${ceph_common_log} 2>&1
    if [ $? -ne 0 ];then
      echo "[ERROR]: Failure to install ceph-common!---$(getSystime)" >> ${ceph_common_log}
      exit 2
    else
      echo "[INFO]: Installation ceph-common completed.---$(getSystime)" >> ${ceph_common_log}
      exit 0
    fi
  fi
}

install_ceph_common
