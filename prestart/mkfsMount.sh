#!/bin/bash
## 格式化挂载脚本

set -e # 遇到错误直接退出
# 不需要修改的变量
script_abs=$(readlink -f "$0") # 获取当前脚本绝对路径
script_dir=$(dirname $script_abs) # 获取当前脚本所在的绝对目录
script_name=${script_abs##*/} # 获取当前脚本文件名
cd ${script_dir} # 全局切换到脚本所在目录
USER=$(whoami)   # 获取执行用户名


# 需要每个节点都修改的变量
etcd_data_DISKTPYE='/dev/vdb' 
etcd_data_mount_abs='/mnt/etcd_data' # 挂载的绝对路径 ，此路径 clean 是 有 rm -rf 操作，确保有值

docker_DISKTPYE='/dev/vdc' # etcd_data 磁盘默认路径
docker_mount_abs='/mnt/docker'

ceph_DISKTPYE='/dev/vdd'
ceph_mount_abs='/mnt/ceph'

quant_data_DISKTPYE='/dev/vde'
quant_data_mount_abs='/data'

# 挂载的操作 ,可以根据 以上变量 相对应的 注释

# quant节点
mkfsMountMain () {    
    mkfsMountEtcd
    mkfsMountDocker
    mkfsMountCeph
    mkfsMountQuantdata
}

# 其他节点
mkfsMountOther () {    
    mkfsMountEtcd
    mkfsMountDocker
    mkfsMountCeph
    ## 下行仅在 quant 节点操作
    # mkfsMountQuantdata
}



# 恢复操作

# quant节点
undomkfsMountMain () {
    undomkfsMountfiles  # 恢复文件
    # 以下 根据变量相对应的注释    
    undomkfsMountEtcd
    undomkfsMountCeph
    undomkfsMountDocker
    uodomkfsMountQuantdata
}

# 其他节点
undomkfsMountOther () {
    undomkfsMountfiles  # 恢复文件
    # 以下 根据变量相对应的注释    
    undomkfsMountEtcd
    undomkfsMountCeph
    undomkfsMountDocker
    ## 下行仅在 quant 节点操作
    # uodomkfsMountQuantdata
}


undomkfsMountfiles (){
    echo
    echo "恢复 /etc/fstab.backByPreStart 到 /etc/fstab"
    echo "执行的命令示例：    cp /etc/fstab.backByPreStart /etc/fstab"
    cp /etc/fstab.backByPreStart /etc/fstab && echo  'recovery  /etc/fstab in'  $IP 'completed'
}


# 格式化 mkfs -t ext4 并挂载，然后写入 /etc/fstab

mkfsMountQuantdata () {
    echo 
    echo "仅 quant 节点执行"
    echo "创建 $quant_data_mount_abs ,并挂载 $quant_data_DISKTPYE"
    echo "执行的命令示例： "
    echo "mkdir $quant_data_mount_abs && mkfs -t ext4 $quant_data_DISKTPYE"
    echo "mount $quant_data_DISKTPYE $quant_data_mount_abs"
    echo "echo $quant_data_DISKTPYE $quant_data_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab"
    echo ""
    mkdir $quant_data_mount_abs && mkfs -t ext4 $quant_data_DISKTPYE &&\
    mount $quant_data_DISKTPYE $quant_data_mount_abs && echo $quant_data_DISKTPYE $quant_data_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab\
    && echo mkfsMount  $quant_data_DISKTPYE $quant_data_mount_abs in $local_ip completed && echo ''
}

uodomkfsMountQuantdata () {
    echo 
    echo "仅quant 节点执行"
    echo "删除 $quant_data_mount_abs ,并取消挂载 $quant_data_DISKTPYE"
    echo "执行的命令示例： "
    echo "umount $quant_data_mount_abs;rm -rf $quant_data_mount_abs;"
    echo ""
    umount $quant_data_mount_abs;rm -rf $quant_data_mount_abs;echo undomkfsMount $quant_data_mount_abs in  $local_ip completed
}

mkfsMountDocker () {
    echo 
    echo "创建 $docker_mount_abs ,并挂载 $docker_DISKTPYE"
    echo "执行的命令示例： "
    echo "mkdir $docker_mount_abs && mkfs -t ext4 $docker_DISKTPYE"
    echo "mount $docker_DISKTPYE $docker_mount_abs"
    echo "echo $docker_DISKTPYE $docker_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab"
    echo ""
    mkdir $docker_mount_abs && mkfs -t ext4 $docker_DISKTPYE &&\
    mount $docker_DISKTPYE $docker_mount_abs && echo $docker_DISKTPYE $docker_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab\
    && echo mkfsMount  $docker_DISKTPYE $docker_mount_abs in  $IP completed && echo ''
}

undomkfsMountDocker () {
    echo 
    echo "删除 $docker_mount_abs ,并取消挂载 $docker_mount_abs"
    echo "执行的命令示例： "
    echo "umount $docker_mount_abs;rm -rf $docker_mount_abs;"
    echo ""
	umount $docker_mount_abs;rm -rf $docker_mount_abs;echo undomkfsMount $docker_mount_abs in  $IP completed
}

# 格式化 mkfs -t ext4 并挂载，然后写入 /etc/fstab
mkfsMountEtcd () {
    echo 
    echo "创建 $etcd_data_mount_abs ,并挂载 $etcd_data_DISKTPYE"
    echo "执行的命令示例： "
    echo "mkdir $etcd_data_mount_abs && mkfs -t ext4 $etcd_data_DISKTPYE"
    echo "mount $etcd_data_DISKTPYE $etcd_data_mount_abs"
    echo "echo $etcd_data_DISKTPYE $etcd_data_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab"
    echo ""
    mkdir $etcd_data_mount_abs && mkfs -t ext4 $etcd_data_DISKTPYE &&\
    mount $etcd_data_DISKTPYE $etcd_data_mount_abs && echo $etcd_data_DISKTPYE $etcd_data_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab\
    && echo mkfsMount  $etcd_data_DISKTPYE $etcd_data_mount_abs in  $IP completed && echo ''
}

undomkfsMountEtcd () {
    echo 
    echo "删除 $etcd_data_mount_abs ,并取消挂载 $etcd_data_mount_abs"
    echo "执行的命令示例： "
    echo "umount $etcd_data_mount_abs;rm -rf $etcd_data_mount_abs;"
    echo ""
	umount $etcd_data_mount_abs;rm -rf $etcd_data_mount_abs;echo undomkfsMount $etcd_data_mount_abs in  $IP completed
}

# 格式化 mkfs -t ext4 并挂载，然后写入 /etc/fstab
mkfsMountCeph () {
    echo 
    echo "创建 $ceph_mount_abs ,并挂载 $ceph_DISKTPYE"
    echo "执行的命令示例： "
    echo "mkdir $ceph_mount_abs && mkfs -t ext4 $ceph_DISKTPYE"
    echo "mount $ceph_DISKTPYE $ceph_mount_abs"
    echo "echo $ceph_DISKTPYE $ceph_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab"
    echo ""
    mkdir $ceph_mount_abs && mkfs -t ext4 $ceph_DISKTPYE &&\
    mount $ceph_DISKTPYE $ceph_mount_abs && echo $ceph_DISKTPYE $ceph_mount_abs '                    ext4    defaults        0 0' >> /etc/fstab\
    && echo mkfsMount $ceph_DISKTPYE $ceph_mount_abs in   $IP completed && echo ''
}

undomkfsMountCeph () {
    echo 
    echo "删除 $ceph_mount_abs ,并取消挂载 $ceph_DISKTPYE"
    echo "执行的命令示例： "
    echo "umount $ceph_mount_abs;rm -rf $ceph_mount_abs;"
    echo ""
    umount $ceph_mount_abs;rm -rf $ceph_mount_abs;echo undomkfsMount $ceph_mount_abs in  $IP completed
}



if [ $USER != "root" ];then
    echo "use root run "
    exit 1
fi

if [ ! $1 ]  || [ ! $2 ];then
    echo "mount_abs  路径 在clean 是 有umount 和 rm -rf 操作,请备份文件，请确保有值或者按要求注释" 
    echo ''
    echo '---------start work----------'
    echo ''
    echo "bash $script_abs main    install         在quant节点格式化并挂载"
    echo "bash $script_abs main   uninstall        在quant节点取消挂载并删除目录"    
    echo "bash $script_abs other   install         在其他节点格式化并挂载"
    echo "bash $script_abs other  uninstall        在其他节点节点取消挂载并删除目录"
    exit 1
fi
if [ $1 == "main" ];then
    if [ $2 == "install" ];then
        mkfsMountMain
    else
        if [ $2 == "uninstall" ];then
            undomkfsMountMain
        fi
    fi
fi
if [ $1 == "other" ];then
    if [ $2 == "install" ];then
        mkfsMountOther
    else
        if [ $2 == "uninstall" ];then
            undomkfsMountOther
        fi
    fi
fi
