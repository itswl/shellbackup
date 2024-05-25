#!/bin/bash

BACKUP_DIR="/opt/apsbackup/etcd"
CACERT="/etc/kubernetes/ssl/ca.pem"
ETCD_KEY="/etc/etcd/ssl/etcd-key.pem"
ETCD_CERT="/etc/etcd/ssl/etcd.pem"

etcdcmd(){
    local etcdctl_param=$*
    local INITIAL_CLUSTER=$(sed -n 's/.*--initial-cluster=\(.*\)/\1/p' /etc/systemd/system/etcd.service|awk '{print $1}')
    local ENDPOINTS=$(echo ${INITIAL_CLUSTER} | sed 's/etcd[0-9]=//g;s/2380/2379/g')
    export ETCDCTL_API=3
    etcdctl --cert=${ETCD_CERT} --key=${ETCD_KEY} \
        --cacert=${CACERT} --endpoints="${ENDPOINTS}" ${etcdctl_param}
}

save_snapshot(){
    local save_dir=$1
    if [ -z ${save_dir} ];then
        [ ! -d "${BACKUP_DIR}" ] && mkdir -p ${BACKUP_DIR}
        save_file="${BACKUP_DIR}/snapshot$(date +%Y%m%d%H%M%S.%N).db"
    else
        [ ! -d "${save_dir}" ] && mkdir -p ${save_dir}
        save_file="${save_dir}/snapshot$(date +%Y%m%d%H%M%S.%N).db"
    fi
    
    local service_file="/etc/systemd/system/etcd.service"
    if [ ! -f "${service_file}" ];then
        echo "[ERROR]: File ${service_file} does not exist!"
        exit 1
    fi

    local save_cmd="snapshot save ${save_file}"
    local INITIAL_CLUSTER=$(sed -n 's/.*--initial-cluster=\(.*\)/\1/p' ${service_file}|awk '{print $1}')
    local ENDPOINTS=$(echo ${INITIAL_CLUSTER} | sed 's/etcd[0-9]=//g;s/2380/2379/g')
    
    export ETCDCTL_API=3
    etcdctl --cert=${ETCD_CERT} --key=${ETCD_KEY} \
        --cacert=${CACERT} --endpoints="${ENDPOINTS}" ${save_cmd}
    
    if [ $? -ne 0 ];then
        echo "[ERROR]: Failed to save snapshot ${save_file}!"
        exit 1
    fi
}

restore_snapshot(){
    local restore_file=$1
    if [ -z ${restore_file} ] || [ ! -f "${restore_file}" ];then
        echo "[ERROR]: File ${restore_file} was not found!"
        exit 1
    fi

    local service_file="/etc/systemd/system/etcd.service"
    if [ ! -f "${service_file}" ];then
        echo "[ERROR]: File ${service_file} does not exist!"
        exit 1
    fi

    local restore_cmd="snapshot restore ${restore_file}"
    local ETCD_NAME=$(sed -n 's/.*--name=\(.*\)/\1/p' ${service_file}|awk '{print $1}')
    local ETCD_DATA_DIR=$(sed -n 's/.*--data-dir=\(.*\)/\1/p' ${service_file}|awk '{print $1}')
    local INITIAL_CLUSTER=$(sed -n 's/.*--initial-cluster=\(.*\)/\1/p' ${service_file}|awk '{print $1}')
    local INITIAL_CLUSTER_TOKEN=$(sed -n 's/.*--initial-cluster-token=\(.*\)/\1/p' ${service_file}|awk '{print $1}')
    local INITIAL_ADVERTISE_PEER_URLS=$(sed -n 's/.*--initial-advertise-peer-urls=\(.*\)/\1/p' ${service_file}|awk '{print $1}')
    
    # 恢复条件:
    # 1,停止etcd服务; 
    # 2,备份并删除原etcd数据目录;
    # 3,恢复时etcdctl将自动创建etcd数据目录; 
    # 4,恢复成功后启动etcd服务;

    systemctl stop etcd

    if [ -d ${ETCD_DATA_DIR} ];then
        mv ${ETCD_DATA_DIR} ${ETCD_DATA_DIR}.$(date +%Y%m%d%H%M%S.%N).bak
    fi

    export ETCDCTL_API=3
    etcdctl --cert=${ETCD_CERT} --key=${ETCD_KEY} \
        --cacert=${CACERT} --name ${ETCD_NAME} --initial-cluster "${INITIAL_CLUSTER}" \
        --initial-cluster-token "${INITIAL_CLUSTER_TOKEN}" --data-dir=${ETCD_DATA_DIR} \
        --initial-advertise-peer-urls "${INITIAL_ADVERTISE_PEER_URLS}" ${restore_cmd}

    if [ $? -ne 0 ];then
        echo "[ERROR]: Failed to restore snapshot ${restore_file}!"
        exit 1
    fi
}

check_status(){
    local member_list="--write-out=table member list"
    local endpoint_status="--write-out=table endpoint status"
    etcdcmd  ${member_list}
    echo ""
    etcdcmd  ${endpoint_status}
}

etcdctl_get(){
    local param=$1
    if [[ "$param" == "keys" ]];then
        local get_param="--prefix --keys-only=true get /"
    else
        local get_param="--prefix --keys-only=false get $param"
    fi
    etcdcmd ${get_param}
}


usage(){

    echo
    echo "Script: $0" 
    echo "Version: 1.0.0"

    echo "
Description: This script is used to back up etcd data."

    echo
    echo "Usage: "
    echo "       `basename $0` [get][help][export][etcdctl][import][status]"
    echo
    echo "       help"
    echo "           Output help information"
    echo
    echo "       get <key>, keys"
    echo "           Output help information"
    echo
    echo "       status"
    echo "           Output etcd service status"
    echo
    echo "       export  <backup dir>"
    echo "           Export etcd snapshot file to backup directory"
    echo
    echo "       import  <snapshot file>"
    echo "           Import etcd snapshot from local file"
    echo 
    echo "       etcdctl <etcdctl parameters>"
    echo "           Example: etcdctl member list"
    echo 
    echo "Example1: `basename $0` export /var/lib/etcd/backup"
    echo 
    exit 0
}


case $1 in
get)
    etcdctl_get $2;;
status)
    check_status ;;
export)
    save_snapshot $2;;
import)
    restore_snapshot $2;;
etcdctl)
    etcdcmd ${*:1} ;;
*)
    usage ;;
esac
