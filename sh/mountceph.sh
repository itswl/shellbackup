#!/bin/bash

# 运行命令: 
# crontab使用flock排他锁运行脚本, 防止重复执行
# */1 * * * * flock -xn /tmp/flock_mount.lock /usr/local/aps/bin/mountceph.sh
#

SCRIPT_LOCK_FILE="/tmp/fuse.lock" 

logger(){
    local logdir="/var/log"
    [ ! -d "${logdir}" ] && mkdir -p ${logdir}
    local logfile="${logdir}/mount-cephfs.log"
    local logtype=$1; local msg=$2
    datetime=`date +'%F %H:%M:%S'`
    format1="${datetime}  [line: `caller 0 | awk '{print$1}'`]"
    format2="${logtype}: ${msg}"
    logformat="$format1  $format2"
    echo -e "${logformat}" | tee -a $logfile
}

check_lock(){
    if [ -f ${SCRIPT_LOCK_FILE} ];then
        logger WARN "Found lock file ${SCRIPT_LOCK_FILE}"
        logger ERROR "Another process is running mountceph.sh, please wait"
        exit 1
    fi
}

exclusive_lock(){
    local operation=$1 # lock or unlock
    if [ ${operation} = "lock" ];then
        logger INFO "Create lock file ${SCRIPT_LOCK_FILE}"
        touch ${SCRIPT_LOCK_FILE}
    else
        logger INFO "Remove lock file ${SCRIPT_LOCK_FILE}"
        rm -rf ${SCRIPT_LOCK_FILE}
    fi 
}

failed_exit_process(){
    exclusive_lock unlock
    exit 1
}

success_exit_process(){
    exclusive_lock unlock
    exit 0
}

check_mount_state(){
    local mount_type=$1 # ceph or fuse
    local position=$2 # pre or post
    logger INFO "Check current mount status"
    local count=$(mount |egrep "/mnt/aps type ${mount_type}"|wc -l)
    mount |egrep "/mnt/aps type fuse" 2>&1 >> /dev/null
    if [ $? -eq 0 ];then
        logger WARN "Found $count mount process"
        if [ "$position" == "pre" ];then
            logger WARN "Directory /mnt/aps is already mounted"
            success_exit_process
        fi
        logger INFO "Mount /mnt/aps successfully"
    else
        logger WARN "Not found mount process"
        if [ "$position" == "post" ];then
            logger ERROR "Failed to mount CEPH file system"
            failed_exit_process
        fi
    fi
}

check_ceph_state(){
    local cephfs_degraded="filesystem is degraded"
    local ceph_health=$(kubectl exec -it --request-timeout=5s $(kubectl get pod  -n rook-ceph -l app=rook-ceph-tools -o=jsonpath='{.items[0].metadata.name}') -n rook-ceph -- ceph  health)
    if [[ "${ceph_health}" =~ "${cephfs_degraded}" ]];then
        logger WARN "CEPH health status is ${ceph_health}"
        logger ERROR "Unable to mount CEPH file system"
        failed_exit_process
    fi
    logger INFO "CEPH health status is ${ceph_health}"
    logger INFO "Allow to mount CEPH file system"
}

kernel_mode_mount(){
    local mon_endpoints=$(kubectl exec -it $(kubectl get pod  -n rook-ceph -l app=rook-ceph-tools -o=jsonpath='{.items[0].metadata.name}') -n rook-ceph -- grep mon_host /etc/ceph/ceph.conf | awk '{print $3}'|sed -e 's/\r//g')
    local my_secret=$(kubectl exec -it $(kubectl get pod  -n rook-ceph -l app=rook-ceph-tools -o=jsonpath='{.items[0].metadata.name}') -n rook-ceph -- grep key /etc/ceph/keyring | awk '{print $3}')
    logger INFO "Start mounting CEPH file system: "
    mount -t ceph ${mon_endpoints}:/ /mnt/aps -o name=admin,secret=$my_secret
    if [ $? -ne 0 ];then
        logger ERROR "Failed to mount CEPH file system"
        failed_exit_process
    fi
}

user_mode_mount(){
    local mon_endpoints=$(kubectl exec -it $(kubectl get pod  -n rook-ceph -l app=rook-ceph-tools -o=jsonpath='{.items[0].metadata.name}') -n rook-ceph -- grep mon_host /etc/ceph/ceph.conf | awk '{print $3}'|sed -e 's/\r//g')
    logger INFO "Start mounting CEPH file system: "
    ceph-fuse -m ${mon_endpoints} -r / /mnt/aps -o nonempty
    if [ $? -ne 0 ];then
        logger ERROR "Failed to mount CEPH file system"
        failed_exit_process
    fi
}


# Check lock
check_lock

# Lock
exclusive_lock lock

# Check mount process
check_mount_state fuse pre

# Check ceph status
check_ceph_state

# Mount CEPH file system to /mnt/aps
user_mode_mount

# Confirm mount process
check_mount_state fuse post

# Unlock
exclusive_lock unlock
