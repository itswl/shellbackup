#!/bin/bash
# 使用当前用户配置互信
USER=$(whoami)   # 获取当前用户
read -s -p $'input password : \n' PASSWORD  # 获取密码
export SSHPASS=$PASSWORD
read -p $'input ADDRESS : \n' ADDRESS   # 或者读取文件 ADDRESS=`cat address.txt`



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
        sshpass -e ssh-copy-id -p 22 -o StrictHostKeyChecking=no $USER@$IP  # 端口 默认 22
    done
} 

COPYSSH () {
    for IP in $ADDRESS;do
        ping $IP -c1 &>/dev/null
        if [ $? -gt 0 ];then
                echo "$IP 无法ping通请检查网络"
                continue
        fi
        sshpass -e scp -P 22 -r ~/.ssh $USER@$IP:~/
    done
} 


SSHKEYGEN
COPYID
COPYSSH

