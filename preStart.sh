#!/bin/bash


# 不需要修改的变量
script_abs=$(readlink -f "$0") # 获取当前脚本绝对路径
script_dir=$(dirname $script_abs) # 获取当前脚本所在的绝对目录
script_name=${script_abs##*/} # 获取当前脚本文件名
cd ${script_dir} # 全局切换到脚本所在目录

USER=$(whoami)   # 获取执行用户名

## 主要变量
DISKTPYE='/dev/vdb'  # 磁盘默认路径
mount_abs='/mnt/etcd_data' # 挂载的路径 ，此路径 clean 是 有 rm -rf 操作，确保有值
PORT=22  # ssh 端口


if [ ! -n $mount_abs ]; then  
    echo "mount_abs can't be null "  
    exit 1
fi

if [ "$mount_abs" == '/' ]; then  
    echo "mount_abs can't be / "  
    exit 1
fi    

if [ "$mount_abs" == '' ]; then  
    echo "mount_abs can't be / "  
    exit 1
fi

## 可选

#ROOTPASSWORD=1234
#MYUSER=aps
#MYUSERPASSWORD=abcd

# 获取地址列表
gainAddress(){
    if [ ! -f "./address.txt" ];then
        read -p $'input ADDRESS : \n' ADDRESS  
        echo $ADDRESS >  address.txt
    fi
    ADDRESS=`cat address.txt`  # 获取 ip 地址
}

# 格式化 mkfs -t ext4 并挂载，然后写入 /etc/fstab
mkfsMount () {
    echo ""
    echo "执行的命令示例： "
    echo "mkdir $mount_abs && mkfs -t ext4 $DISKTPYE"
    echo "mount $DISKTPYE $mount_abs"
    echo "echo $DISKTPYE $mount_abs '                    ext4    defaults        0 0' >> /etc/fstab"
    echo ""
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
            echo "$IP 无法ping通请检查网络"
            continue
        fi
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "mkdir $mount_abs && mkfs -t ext4 $DISKTPYE &&\
        mount $DISKTPYE $mount_abs && echo $DISKTPYE $mount_abs '                    ext4    defaults        0 0' >> /etc/fstab\
        && echo mkfsMount  $IP completed && echo ''"
    done
}

undomkfsMount () {
    echo ""
    echo "执行的命令示例： "
    echo "cp /etc/fstab.backByPreStart /etc/fstab;umount $mount_abs;rm -rf $mount_abs;"
    echo ""
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "cp /etc/fstab.backByPreStart /etc/fstab;umount $mount_abs;rm -rf $mount_abs;echo undomkfsMount  $IP completed"
    done
}

# 创建用户 $MYUSER 改密 并写入文件  /etc/sudoers
createUserAndWirteSudoers () {
    echo ""
    echo "执行的命令示例： "
    echo "useradd -m $MYUSER -u 3000 && echo "$MYUSER:$MYUSERPASSWORD"|chpasswd"
    echo "mkdir -p /home/$MYUSER  && chown $MYUSER:$MYUSER -R /home/$MYUSER"
    echo "echo $MYUSER    'ALL=(ALL)    NOPASSWD:ALL'  >>   /etc/sudoers "
    echo ""
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "useradd -m $MYUSER -u 3000 && echo "$MYUSER:$MYUSERPASSWORD"|chpasswd \
        && mkdir -p /home/$MYUSER  && chown $MYUSER:$MYUSER -R /home/$MYUSER  \
        && echo $MYUSER    'ALL=(ALL)    NOPASSWD:ALL'  >>   /etc/sudoers && echo create user $MYUSER  in   $IP completed "
    done
} 

undocreateUserAndWirteSudoers () {
    echo ""
    echo "执行的命令示例： "
    echo "userdel -r $MYUSER;cp /etc/sudoers.backByPreStart /etc/sudoers"
    echo ""
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "userdel -r $MYUSER;cp /etc/sudoers.backByPreStart /etc/sudoers;echo undocreateUserAndWirteSudoers  $IP completed"
    done
} 

 
# 所有节点备份 /etc/sudoers  /etc/fstab
backupFiles () {
    echo ""
    echo "执行的命令示例： "
    echo "cp /etc/sudoers /etc/sudoers.backByPreStart &&  cp /etc/fstab /etc/fstab.backByPreStart"
    echo ""
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
    if [ ! $ROOTPASSWORD ];then
        read -s -p $'input root password : \n' ROOTPASSWORD
    fi
    export SSHPASS=$ROOTPASSWORD
    sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "cp /etc/sudoers /etc/sudoers.backByPreStart &&  cp /etc/fstab /etc/fstab.backByPreStart && echo backupfiles  in   $IP completed "
    done
}

# 重命名 节点
renameNode () {
    echo ""
    echo "执行的命令示例： "
    echo "hostnamectl set-hostname aps*"
    echo ""
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        NODENAME=${IP##*.}  # 取 aps 和 ip的最后一段作为 节点名
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "hostnamectl set-hostname aps$NODENAME && echo -n rename  $IP '   '  && hostname "

    done
} 


# 获取 内核版本
kernel_info () {
	main=`uname -r | awk -F . '{print $1}'`
	minor=`uname -r | awk -F . '{print $2}'`
	KERNEL=$(expr $main \* 100 + $minor)

	if [ "$KERNEL" -ge 310 ]  # 内核版本需要 大于 主版本*100 + 此版本 
		then 
			echo "main version is :$main  minor version is :$minor"
	else
		echo "main version is :$main  minor version is :$minor"
		echo "The kernel may need to be upgraded"
		exit 1
	fi
}


# 远程执行上面的 kernel_info 在这一段
remote_kernel_info (){
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        echo -n "$IP kernel_info      "
    	sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP  -C /bin/bash -s kernel_info <  $script_abs
    done
}



# 拷贝 address.txt 和 当前文件 到 $MYUSER 目录下
COPYSH (){
    cp $script_name /home/$MYUSER
    cp address.txt /home/$MYUSER
}

# 生成密钥文件
SSHKEYGEN() {

    rm -rf ~/.ssh
    ssh-keygen -f ~/.ssh/id_rsa -N '' -t rsa -q -b 2048
}


# 连接所有节点 执行 ssh-copy-id
COPYID () {
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e ssh-copy-id -p $PORT -o StrictHostKeyChecking=no $USER@$IP 
    done
} 

# 拷贝 $USER 目录下的 ~/.ssh 到其他节点
COPYSSH () {
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e scp -P $PORT -r ~/.ssh $USER@$IP:~/
    done
} 

# 互信主要的操作
MutualTrust (){
    SSHKEYGEN
    COPYID
    COPYSSH
}


# root 用户执行的操作
rootUserRun () {
    renameNode   # 不是第一次运行时 也可以注销
    createUserAndWirteSudoers
    mkfsMount  # 不是第一次运行时 也可以注销
    COPYSH
} 

# 普通用户执行的操作
normalUserRun (){
    MutualTrust
}

# 开头的提醒事项
TIPS(){
    gainAddress
    echo '当前 地址列表:'
    echo ''
    for IP in $ADDRESS;do
    echo $IP
    done
    echo '如果地址不对，请删除同目录下的 addresss.txt'
    echo ''
    echo "首次运行请先执行   bash $script_name backup 在所有节点备份以下文件"
    echo ' /etc/fstab'
    echo ' /etc/sudoers'
    echo ''
    echo "当前默认 磁盘 $DISKTPYE  挂载路径 $mount_abs 端口 $PORT "
    echo "mount_abs  此路径 在clean 是 有 rm -rf 操作，请确保有值上一行挂载路径后有值且正确" 
    echo ''
    echo "清除安装 可执行 bash $script_name clean"
    echo ''
    echo "如果需要 root 用户互信 执行 bash $script_name trust  "
    echo "建立互信 仅在当前主机的 互信用户 目录下 拷贝 $script_name 和 address.txt 文件"
    echo "然后使用 互信的用户 执行 bash $script_name trust 如不需要保留，则手动删除"
    echo ''
    echo ''
    echo 'if have problems press ctrl + c quit '
    echo ''
}


if [[ $1 == "clean" ]]; then
    gainAddress
    echo "当前默认 磁盘 $DISKTPYE  挂载路径 $mount_abs 端口 $PORT "
    echo "mount_abs  此路径 在clean 是 有 rm -rf 操作，请确保有值上一行挂载路径后有值且正确" 
    if [ ! $ROOTPASSWORD ];then
        read -s -p $'input root password : \n' ROOTPASSWORD
    fi
    MYUSER=$(cat /etc/passwd |grep 3000 | awk  -F ':'  '{print $1}')
    if [ ! $MYUSER ];then
    read -p $'input create User : \n' MYUSER
    fi
    export SSHPASS=$ROOTPASSWORD
    undomkfsMount
    undocreateUserAndWirteSudoers
    echo ''
    echo 'clean finished'
    exit 0
fi

if [[ $1 == "kernel_info" ]];then
    kernel_info
fi

if [[ $1 == "backup" ]];then
    gainAddress
    backupFiles
fi

if [[ $1 == "trust" ]];then
    gainAddress
    MYUSERPASSWORD=$2
    if [[ $2 == "" ]];then
        read -s -p $'input  User password : \n' MYUSERPASSWORD  # 获取密码 
    fi
    export SSHPASS=$MYUSERPASSWORD
    normalUserRun
    echo '---------finished work----------'
fi


if [[ $1 == "" ]];then
    if [ $USER = "root" ];then
        TIPS
        if [ ! $ROOTPASSWORD ];then
            read -s -p $'input root password : \n' ROOTPASSWORD
        fi
        export SSHPASS=$ROOTPASSWORD
        if [ ! $MYUSER ];then
            read -p $'input create User : \n' MYUSER
        fi
        if [ ! $MYUSERPASSWORD ];then       
            read -s -p $'input create User password : \n' MYUSERPASSWORD
        fi
        echo ''
		echo '---------start work----------'
        echo ''
        remote_kernel_info
        echo ''
        echo "创建用户 $MYUSER 并初始化密码"
        rootUserRun
        echo "正在切换到创建的用户 $MYUSER 建立互信"
        su - $MYUSER -c "bash ~/$script_name trust $MYUSERPASSWORD "
    else
        echo "try bash $script_name trust"
    fi
fi
