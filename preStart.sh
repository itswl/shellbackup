#!/bin/bash
# 主要是用到了 sshpass 这一个工具进行 非交互式密码验证  可能需要安装
#
# 例如 在 账号 aps 密码 123   ip 192.168.1.1  执行 ls 操作
# -o StrictHostKeyChecking=no  # 在首次连接服务器时，会弹出公钥确认的提示, 实现当第一次连接服务器时，自动接受新的公钥
#
#
# sshpass -p 123 ssh -p -o StrictHostKeyChecking=no aps@192.168.1.1 'ls'
#
# -e 从环境变量 SSHPASS 获取密码 export SSHPASS='123'
# sshpass -e ssh -o StrictHostKeyChecking=no aps@192.168.1.1 'ls'
#

set -e # 遇到错误直接退出
# 不需要修改的变量
script_abs=$(readlink -f "$0") # 获取当前脚本绝对路径
script_dir=$(dirname $script_abs) # 获取当前脚本所在的绝对目录
script_name=${script_abs##*/} # 获取当前脚本文件名
cd ${script_dir} # 全局切换到脚本所在目录
USER=$(whoami)   # 获取执行用户名

## 主要变量
PORT=22  # ssh 端口firewalld
local_ip=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')  # 获取本机 ip
## 可选
## 可以不进行手动交互
ROOTPASSWORD=123456
MYUSER=imwl
MYUSERPASSWORD=123456


if ! type sshpass >/dev/null 2>&1;then
    echo 'sshpass 未安装'; 
    yum install -y sshpass
else  
    echo 'sshpass 已安装';
fi

# 获取地址列表
gainAddress(){
    if [ ! -f "./address.txt" ];then
        read -p $'input ADDRESS : \n' ADDRESS  
        echo $ADDRESS >  address.txt
    fi
    ADDRESS=`cat address.txt`  # 获取 ip 地址
}

# 关闭 swap 分区
swapOff (){
    echo
    echo "所有主机执行"
    echo "关闭 swap 分区"
    echo "执行的命令示例："
    echo "swapoff -a && sed -ri 's/.*swap.*/#&/' /etc/fstab"
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "swapoff -a && sed -ri 's/.*swap.*/#&/' /etc/fstab   && echo  'swapoff -a  in'  $IP 'completed'"
    done
}

# 创建用户 $MYUSER 改密 并写入文件  /etc/sudoers
createUserAndWirteSudoers () {
    echo 
    echo "所有主机执行"
    echo "创建用户 $MYUSER, 并写入文件 /etc/sudoers"
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
    echo 
    echo "所有主机执行"
    echo "删除用户 $MYUSER, 并恢复文件 /etc/sudoers"
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

copymkfsMount (){
    echo 
    echo "分发 mkfsMount.sh 到所有节点"
    echo
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
            echo "$IP 无法ping通请检查网络"
            continue
        fi
        sshpass -e scp -P  $PORT -o StrictHostKeyChecking=no $script_dir/mkfsMount.sh $USER@$IP:~/ && echo scp mkfsMount.sh to  $USER@$IP:~/ completed

    done
}

bashmkfsMount (){
    echo 
    echo "在所有节点执行 bash mkfsMount.sh 操作"
    echo
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
            echo "$IP 无法ping通请检查网络"
            continue
        fi
        echo "当前执行 主机 $IP"
        if [ $IP == $local_ip ];then
            sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP bash ~/mkfsMount.sh main install
        else
            sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP bash ~/mkfsMount.sh other install
        fi

    done
}

bashundomkfsMount (){
    echo 
    echo "在所有节点执行 bash uodomkfsMount.sh 操作"
    echo
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
            echo "$IP 无法ping通请检查网络"
            continue
        fi
        if [ $IP == $local_ip ];then
            sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP bash ~/mkfsMount.sh main uninstall
        else
            sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP bash ~/mkfsMount.sh other uninstall
        fi

    done
}

# 所有节点备份 /etc/sudoers  /etc/fstab
backupFiles () {
    echo 
    echo "所有主机执行"
    echo "备份文件 /etc/sudoers  到 /etc/sudoers.backByPreStart"
    echo "备份文件 /etc/fstab  到 /etc/fstab.backByPreStart"
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
    echo 
    echo "所有主机执行"
    echo "重命名主机  格式 aps+主机号"
    echo "执行的命令示例： "
    echo "hostnamectl set-hostname aps*"
    echo ""
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        NODENAME=${IP##*.}  # 取 myuser 和 ip的最后一段作为 节点名
        sshpass -e ssh -p  $PORT -o StrictHostKeyChecking=no $USER@$IP "hostnamectl set-hostname $MYUSER-$NODENAME && echo -n rename  $IP '   '  && hostname "

    done
} 


# 获取 内核版本
kernel_info () {
	main=`uname -r | awk -F . '{print $1}'`   # 主版本
	minor=`uname -r | awk -F . '{print $2}'`  # 次版本
    patch=`uname -r | awk -F . '{print $3}'`  # 修订版本
    int_patch=$(echo $patch |tr -d "-")       # 修订版本转为数字
	KERNEL=$(expr $main \* 100 + $minor)      # eg: 3.10 转为 310 

    # 内核版本需要 大于 3.10.0-693.el7.x86_64
	if [ "$KERNEL" -gt 310 ];then  # 主次大于 310
    	echo "main version is :$main  minor version is :$minor   patch version is :$patch"
    fi
    if [ "$KERNEL" -eq 310 ];then  # 主次 等于 310
        if [ "$int_patch" -ge 693 ];then # patch 大于等于 693
            echo "main version is :$main  minor version is :$minor    patch version is :$patch"
        else
        	echo "current kernel is $(uname -r), less then 3.10.0-693.el7.x86_64, The kernel may need to be upgraded"
		    exit 1
        fi
    fi
    if [ "$KERNEL" -lt 310 ];then # 主次小于 310
        echo "current kernel is $(uname -r), less then 3.10.0-693.el7.x86_64, The kernel may need to be upgraded"
        exit 1           
	fi
}


# 远程执行上面的 kernel_info 在这一段
remote_kernel_info (){
    echo 
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
    echo
    echo "仅本机执行"
    echo "拷贝 address.txt 和 $script_name 到 $MYUSER 目录下"
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
    swapOff 
    renameNode   # 不是第一次运行时 也可以注销
    createUserAndWirteSudoers 
    COPYSH  
} 

# 互信用户执行的操作
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
    echo "ssh 端口 $PORT"
    echo '如果地址不对，请删除同目录下的 addresss.txt'
    echo "本机 IP : $local_ip  本机 IP 不对的话，请手动更改可变变量中的 local_ip "
    echo "如何想自动分区挂载请在 quant 节点执行此脚本，如果不是则随意"
    echo ''
    echo "首次运行请先执行   bash $script_name backup 在所有节点备份以下文件"
    echo ' /etc/fstab'
    echo ' /etc/sudoers'
    echo ''
    echo "bash $script_name copymkfsMount  分发 mkfsMount.sh 文件到 各主机"
    echo "在个主机 修改合适后   可以 执行 bash $script_name bashmkfsMount 一次性挂载,也可以去各个节点执行" 
    echo "在个主机 修改合适后 也可以 执行 bash $script_name installall    一次性安装" 
    echo ''
    echo "清除安装 可执行               bash $script_name clean              不清除挂载的目录"
    echo "在个主机 修改合适后  也可执行 bash $script_name bashundomkfsMount  单独清除挂载的目录"   
    echo "在个主机 修改合适后  也可执行 bash $script_name cleanall           一次性清除 ,也可以去各个节点执行"   
    echo ''
    echo "如果需要 root 用户互信 执行 bash $script_name trust  "
    echo "建立互信 仅在当前主机的 互信用户 目录下 拷贝 $script_name 和 address.txt 文件"
    echo "然后使用 互信的用户 执行 bash $script_name trust 如不需要保留，则手动删除"
    echo ''
    echo ''
    echo 'if have problems press ctrl + c quit '
    echo ''
}


if [[ $1 == "backup" ]];then
    gainAddress
    backupFiles
    exit 0
fi

if [[ $1 == "clean" ]]; then
    gainAddress
    echo "mount_abs  路径 在clean 是 有umount 和 rm -rf 操作,请备份文件，请确保有值或者按要求注释" 
    if [ ! $ROOTPASSWORD ];then
        read -s -p $'input root password : \n' ROOTPASSWORD
    fi
    MYUSER=$(cat /etc/passwd |grep 3000 | awk  -F ':'  '{print $1}')
    if [ ! $MYUSER ];then
    read -p $'input create User : \n' MYUSER
    fi
    export SSHPASS=$ROOTPASSWORD
    undocreateUserAndWirteSudoers
    echo ''
    echo 'clean finished'
    exit 0
fi

if [[ $1 == "cleanall" ]]; then
    gainAddress
    echo "mount_abs  路径 在clean 是 有umount 和 rm -rf 操作,请备份文件，请确保有值或者按要求注释" 
    if [ ! $ROOTPASSWORD ];then
        read -s -p $'input root password : \n' ROOTPASSWORD
    fi
    MYUSER=$(cat /etc/passwd |grep 3000 | awk  -F ':'  '{print $1}')
    if [ ! $MYUSER ];then
    read -p $'input create User : \n' MYUSER
    fi
    export SSHPASS=$ROOTPASSWORD
    undocreateUserAndWirteSudoers
    bashundomkfsMount
    echo ''
    echo 'clean finished'
    exit 0
fi

if [[ $1 == "kernel_info" ]];then
    kernel_info
    exit 0
fi

if [[ $1 == "copymkfsMount" ]];then
    gainAddress
    if [ ! $ROOTPASSWORD ];then
        read -s -p $'input root password : \n' ROOTPASSWORD
    fi
    export SSHPASS=$ROOTPASSWORD    
    copymkfsMount
    exit 0
fi

if [[ $1 == "bashmkfsMount" ]];then
    gainAddress
    if [ ! $ROOTPASSWORD ];then
        read -s -p $'input root password : \n' ROOTPASSWORD
    fi   
    export SSHPASS=$ROOTPASSWORD 
    bashmkfsMount
    exit 0
fi



if [[ $1 == "bashundomkfsMount" ]];then
    gainAddress
    if [ ! $ROOTPASSWORD ];then
        read -s -p $'input root password : \n' ROOTPASSWORD
    fi 
    export SSHPASS=$ROOTPASSWORD   
    bashundomkfsMount
    exit 0
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
    exit 0
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
        echo "获取 内核版本信息 判断是否大于 3.10.0-693.el7.x86_64"
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

if [[ $1 == "installall" ]];then
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
        echo "获取 内核版本信息 判断是否大于 3.10.0-693.el7.x86_64"
        remote_kernel_info
        echo ''
        bashmkfsMount
        echo "创建用户 $MYUSER 并初始化密码"

        rootUserRun
        echo "正在切换到创建的用户 $MYUSER 建立互信"
        su - $MYUSER -c "bash ~/$script_name trust $MYUSERPASSWORD "
    else
        echo "try bash $script_name trust"
    fi
fi

