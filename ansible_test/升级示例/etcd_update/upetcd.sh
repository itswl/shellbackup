#!/bin/bash
set -e # 遇到错误直接退出
# 不需要修改的变量
export ETCDCTL_API=3
script_abs=$(readlink -f "$0") # 获取当前脚本绝对路径
script_dir=$(dirname $script_abs) # 获取当前脚本所在的绝对目录
script_name=${script_abs##*/} # 获取当前脚本文件名
cd ${script_dir} # 全局切换到脚本所在目录
USER=$(whoami)   # 获取执行用户名


gainAddress(){
    if [ ! -f "ETCDIP.txt" ];then
        read -p $'input etcd_ADDRESS : \n' ADDRESS
        echo $ADDRESS >  ETCDIP.txt
    fi
    ADDRESS=`cat ETCDIP.txt`  # 获取 etcd_ip 地址
}
gainAddress

# 保证配置正确  systemctl status etcd 可以查看到相关信息
echo $ADDRESS
CLIENTPORT=2379
PEERPORT=2380
SSHPORT=22
ETCDDATADIR='/var/lib/etcd'
ETCDBIN_DIR='/usr/bin'
CACERT='/etc/kubernetes/ssl/ca.pem'
CERT='/etc/etcd/ssl/etcd.pem'
KEY='/etc/etcd/ssl/etcd-key.pem'
BACKUP_DIR='/root/backup/etcd'


etcd_back(){
    [ ! -d $BACKUP_DIR ] && mkdir -p $BACKUP_DIR
    DATE=`date +%Y%m%d-%H%M%S`
    SNAPSHOTNAME=$BACKUP_DIR/snapshot-$(date +%Y%m%d-%H%M%S).db
    for ip in  $ADDRESS;do
        echo
    done;
    echo "export ETCDCTL_API=3; $ETCDBIN_DIR/etcdctl --endpoints=$ip:$CLIENTPORT --cacert=$CACERT --cert=$CERT --key=$KEY snapshot save $SNAPSHOTNAME"
    $ETCDBIN_DIR/etcdctl --endpoints=$ip:$CLIENTPORT --cacert=$CACERT --cert=$CERT --key=$KEY snapshot save $SNAPSHOTNAME

    for ip in $ADDRESS;do
        ssh -p $SSHPORT $ip  mkdir -p $BACKUP_DIR
        ssh -p $SSHPORT $ip  cp $ETCDBIN_DIR/etcdctl $BACKUP_DIR/etcdctl.back   
	    ssh -p $SSHPORT $ip  cp $ETCDBIN_DIR/etcd $BACKUP_DIR/etcd.back
        scp -P $SSHPORT $SNAPSHOTNAME $USER@$ip:$BACKUP_DIR
    done
}



etcd_service_stop(){
    for ip in $ADDRESS;do
        ssh -p $SSHPORT root@$ip systemctl stop etcd
    done
}

etcd_service_run(){
    for ip in $ADDRESS;do
        ssh -p $SSHPORT root@$ip systemctl restart etcd
    done
}


etcd_data_rm(){
    for ip in $ADDRESS;do
        ssh -p $SSHPORT root@$ip rm -rf $ETCDDATADIR
	    ssh -p $SSHPORT root@$ip mkdir -p $ETCDDATADIR
    done
}

etcd_update_bin(){
    for ip in $ADDRESS;do
        scp -P $SSHPORT ./etcd*  root@$ip:$ETCDBIN_DIR
    done
}

etcd_restore_bin(){
    for ip in $ADDRESS;do
        ssh -p $SSHPORT root@$ip cp $ETCDBIN_DIR/etcd.back  $ETCDBIN_DIR/etcd
        ssh -p $SSHPORT root@$ip cp $ETCDBIN_DIR/etcdctl.back  $ETCDBIN_DIR/etcdctl
    done
}

etcd_data_restore(){
    echo '目前需要到各节点手动执行 恢复数据操作，然后重启服务'
    exit 1
}

TIPS(){
    echo  "确保变量等信息正确"
    echo "首次运行请先执行   bash $script_name backup 在所有节点备份以下文件"
    echo  "$ETCDBIN_DIR/etcd  > $BACKUP_DIR/etcd.back"
    echo  "$ETCDBIN_DIR/etcdctl > $BACKUP_DIR/etcdctl.bak"
    echo "数据库备份 到 当前节点 $BACKUP_DIR/snapshot-*.db 的一个文件"
    echo 
    echo "升级 bash $script_name upate"
    echo 
    echo "降级回老版本 bash $script_name restore"
    echo "降级回老版本 只恢复二进制文件，需要手动执行命令恢复数据，然后重启服务"
    read -p "if have problems press ctrl + c quit "  p
}


if [[ $1 == "" ]];then
    TIPS
    exit 0
fi

if [[ $1 == "backup" ]];then
    etcd_back
    exit 0
fi

if [[ $1 == "update" ]];then
    etcd_service_stop
    etcd_update_bin
    etcd_service_run
    exit 0
fi

if [[ $1 == "restore" ]];then
    etcd_data_rm
    etcd_service_stop
    etcd_restore_bin
    # etcd_data_restore
    # etcd_service_run
fi



# 恢复数据需要手动执行  eg
#export  ETCDCTL_API=3;
#etcdctl snapshot restore /root/backup/etcd/snapshot-20210401-165152.db \
# --name etcd1 \
# --initial-cluster etcd1=http://172.20.40.196:2380,etcd2=http://172.20.40.107:2380,etcd3=http://172.20.40.249:2380 \
# --initial-advertise-peer-urls http://172.20.40.196:2380

# systemctl restart etcd 


#export  ETCDCTL_API=3;
#etcdctl snapshot restore /root/backup/etcd/snapshot-20210401-165152.db \
# --name etcd2 \
# --initial-cluster etcd1=http://172.20.40.196:2380,etcd2=http://172.20.40.107:2380,etcd3=http://172.20.40.249:2380 \
# --initial-advertise-peer-urls http://172.20.40.196:2380

# systemctl restart etcd


#export  ETCDCTL_API=3;
#etcdctl snapshot restore /root/backup/etcd/snapshot-20210401-165152.db \
# --name etcd3 \
# --initial-cluster etcd1=http://172.20.40.196:2380,etcd2=http://172.20.40.107:2380,etcd3=http://172.20.40.249:2380 \
# --initial-advertise-peer-urls http://172.20.40.196:2380

# systemctl restart etcd