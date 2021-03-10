#!/bin/bash


# 不需要修改的变量
script_abs=$(readlink -f "$0")
script_dir=$(dirname $script_abs)
script_name=${script_abs##*/}
cd ${script_dir}
USER=$(whoami)   # 获取当前用户

# 主要变量
#if [ ! -f "./address.txt" ];then
#    read -p $'input ADDRESS : \n' ADDRESS  
#    echo $ADDRESS >  address.txt
#fi
ADDRESS=`cat address.txt`

DISKTPYE='/dev/vdb'  # 磁盘
mount_abs='/mnt/etcd_data' # 挂载的路径
PORT=22

## 可选

#ROOTPASSWORD=1234
#MYUSER=aps
#MYUSERPASSWORD=abcd

mkfsMount () {
        for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "mkdir $mount_abs && mkfs -t ext4 $DISKTPYE &&\
         mount $DISKTPYE $mount_abs &&  echo $DISKTPYE $mount_abs '                    ext4    defaults        0 0' >> /etc/fstab"
    done
}

createUserAndWirteSudoers () {
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "useradd -m $MYUSER -u 3000 && echo "$MYUSER:$MYUSERPASSWORD"|chpasswd && echo create user $MYUSER  in   $IP completed\
        && echo $MYUSER    'ALL=(ALL)    NOPASSWD:ALL'  >>   /etc/sudoers"
    done
} 

renameNode () {
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        NODENAME=${IP##*.}
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "hostnamectl set-hostname aps$NODENAME && echo -n rename  $IP '   '  && hostname "

    done
} 



kernel_info () {
	main=`uname -r | awk -F . '{print $1}'`
	minor=`uname -r | awk -F . '{print $2}'`
	KERNEL=$(expr $main \* 100 + $minor)

	if [ "$KERNEL" -ge 310 ]
		then 
			echo "main version is :$main  minor version is :$minor"
	else
		echo "main version is :$main  minor version is :$minor"
		echo "The kernel may need to be upgraded"
		exit 1
	fi
}

remote_kernel_info (){
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
    sshpass -e scp -P  $PORT -o StrictHostKeyChecking=no  $script_name root@$IP:~/
	sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no root@$IP "bash -s < $script_name kernel_info && echo $IP kernel is ok && exit"
	done
}

COPYSH (){
    cp address.txt /home/$MYUSER
    cp $script_name /home/$MYUSER
}

SSHKEYGEN() {
    rm -rf ~/.ssh
    ssh-keygen -f ~/.ssh/id_rsa -N '' -t rsa -q -b 2048
}


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


MutualTrust (){
    SSHKEYGEN
    COPYID
    COPYSSH
}


rootUserRun () {
    renameNode   # 不是第一次运行可以注销
    createUserAndWirteSudoers
    mkfsMount  # 不是第一次运行可以注销
    COPYSH
} 

normalUserRun (){
    MutualTrust
}

TIPS(){
    echo '当前 地址列表:'
    echo ''
    for IP in $ADDRESS;do
    echo $IP
    done
    echo '如果没有地址列表，需要在脚本文件同路径下 创建并写入到文件 addresss.txt'
    echo ''
    echo '非首次安装可能需要在所有节点清理以下文件:'
    echo ''
    echo ' /etc/fstab'
    echo ' /etc/sudoers'
    echo '磁盘 默认 /dev/vdb  挂载路径默认 /mnt/etcd_data 端口默认 22 如需修改请 修改 脚本文件中的主要变量（开头地方）' 
    echo " cat /etc/passwd |grep 3000 | awk  -F ':'  '{print \$1}'  # 删除3000的用户'"
    echo ''
    echo 'if have problems press ctrl + c quit '
    echo ''
}


if [[ $1 == "kernel_info" ]];then
    kernel_info
else
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
		echo 'start work'
        remote_kernel_info
        echo "创建用户 $MYUSER 并初始化密码"
        rootUserRun
        echo "正在切换到创建的用户 $MYUSER 建立互信"
        su - $MYUSER -c "bash ~/$script_name $MYUSERPASSWORD "
        
    else
        echo "current user is not root "
        MYUSERPASSWORD=$1
        if [[ $1 == "" ]];then
            read -s -p $'input  User password : \n' MYUSERPASSWORD  # 获取密码  # 这里如果是读取保存密码的文件，或者 脚本中写入密码 则一次执行
        fi
        export SSHPASS=$MYUSERPASSWORD
        normalUserRun
    fi
fi

