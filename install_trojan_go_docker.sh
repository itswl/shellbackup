#!/bin/bash

trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
random_path=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
cdn_true_or_false=false

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
function first_run(){
if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
fi

CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
if [ "$CHECK" == "SELINUX=enforcing" ]; then
    red "======================================================================="
    red "检测到SELinux为开启状态,正在关闭"
    red "======================================================================="
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi

if [ "$CHECK" == "SELINUX=permissive" ]; then
    red "======================================================================="
    red "检测到SELinux为宽容状态"
    red "======================================================================="
    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
if [ "$release" == "centos" ]; then
    if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    systemctl stop firewalld
    systemctl disable firewalld
elif [ "$release" == "ubuntu" ]; then
    if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
#Oracle自带的Ubuntu镜像默认设置了Iptable规则，关闭它
    apt-get purge netfilter-persistent -y
    systemctl stop ufw
    systemctl disable ufw
elif [ "$release" == "debian" ]; then
    echo ''
fi
#systemctl stop oracle-cloud-agent
#systemctl disable oracle-cloud-agent
#systemctl stop oracle-cloud-agent-updater
#systemctl disable oracle-cloud-agent-updater
#systemctl stop rpcbind
#systemctl stop rpcbind.socket
#systemctl disable rpcbind
#systemctl disable rpcbind.socket

$systemPackage -y update
$systemPackage -y install net-tools curl unzip tar wget vim 
}
function check_domain(){
green "======================="
blue "请输入绑定到本VPS的域名"
green "======================="
read your_domain
real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
local_addr=`curl ipv4.icanhazip.com`
if [ $real_addr == $local_addr ] ; then
        green "=========================================="
        green "       域名解析正常"
        green "=========================================="
        sleep 1s
else
    red "================================"
    red "域名解析地址与本VPS IP地址不一致"
    red "请确保 ip 域名一致，安装可能失败"
    red "================================"
    # exit 1
    sleep 10s
fi	
}

function check_ports(){
        Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
        Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
        if [ -n "$Port80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
    red "==========================================================="
    red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
    red "==========================================================="
         exit 1
        fi
if [ -n "$Port443" ]; then
    process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
    red "============================================================="
    red "检测到443端口被占用，占用进程为：${process443}，本次安装结束"
    red "============================================================="
    exit 1
fi

}

function html(){
   
	#设置伪装站
    rm -rf  /opt/nginx/html/blog/*
    rm -rf  /opt/nginx/html/blog/*
    wget -q -P /opt/nginx/html/blog https://github.com/ursocute/ursocute.github.io/archive/refs/heads/master.zip >/dev/null 
    unzip -o  /opt/nginx/html/blog/master.zip -d  /opt/nginx/html/blog/ >/dev/null 
    mv  /opt/nginx/html/blog/ursocute*/*  /opt/nginx/html/blog/
    rm -rf  /opt/nginx/html/blog/master.zip   /opt/nginx/html/blog/ursocute*

}

function install_nginx(){
docker rm -f nginx
mkdir -p /opt/nginx/html/blog
mkdir -p /opt/nginx/conf.d
html

cat > /opt/nginx/nginx.conf <<-EOF
user  nginx;
worker_processes  auto;
error_log  off;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;


    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
					  
    access_log  off;
    client_max_body_size 1024m;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    #gzip  on;
    include /opt/nginx/conf.d/*.conf;
}

EOF

cat > /opt/nginx/conf.d/blog.conf <<-EOF
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;
    location / {
        root   /opt/nginx/html/blog;
        index  index.html index.htm;
    }
    location ~* \\.(css|js|png|jpg|jpeg|gif|gz|svg|mp4|ogg|ogv|webm|htc|xml|woff)$ {
    access_log off;
    root /opt/nginx/html/blog;
    add_header    Cache-Control  max-age=720000;
  }
}
EOF

cat > /opt/nginx/conf.d/error.conf <<-EOF
server {
    listen       1234;
    listen  [::]:1234;
    server_name  localhost;
    location / {
        return 400;
    }
}
EOF

    docker run -d  --network=host --name nginx --restart=always  -v /opt/nginx/nginx.conf:/etc/nginx/nginx.conf -v /opt/nginx:/opt/nginx nginx
    (crontab -l|grep -v "nginx";echo "3 1  * * 2 docker restart nginx")| crontab
}
	
function install_trojan_go(){
docker rm -f trojan-go
mkdir -p /opt/across/trojan-go
cat > /opt/across/trojan-go/config.json <<-EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": [
    "$trojan_passwd"
  ],
  "log_level": 5,
  "ssl": {
    "cert": "/etc/across/server.crt",
    "key": "/etc/across/server.key",
    "alpn": [
      "http/1.1"
    ],
    "alpn_port_override": {
      "h2": 81
    },
    "fallback_port": 1234,
    "reuse_session": true,
    "session_ticket": true,
    "session_timeout": 600
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "fast_open": true,
    "reuse_port": true,
    "fast_open_qlen": 40
  },
  "mux": {
    "enabled": true,
    "concurrency": 8,
    "idle_timeout": 60
  },
  "router": {
    "enabled": true,
    "block": [
      "geosite:category-ads",
      "geoip:private"
    ]
  },
  "websocket": {
    "enabled": $cdn_true_or_false,
    "path": "/$random_path"
  },
  "shadowsocks": {
    "method": "CHACHA20-IETF-POLY1305",
    "enabled": $cdn_true_or_false,
    "password": "$trojan_passwd"
  }
}
    
EOF


docker run -d  --network=host --name trojan-go --restart=always \
    -v /opt/across/trojan-go/config.json:/etc/trojan-go/config.json \
    -v  /opt/.acme.sh/out:/etc/across \
    teddysun/trojan-go
    
 (crontab -l|grep -v "trojan-go"|echo "10 1  * * 2 docker restart trojan-go")| crontab
}

function repair_cert(){
    red "============================================================="
    red "      如果修改了域名，先执行 rm -rf /opt/.acme.sh/             " 
    red "============================================================="
sleep 10
mkdir -p /opt/.acme.sh
docker stop nginx
docker stop trojan-go
docker rm -f acme.sh
docker run --restart=always -itd  -v /opt/.acme.sh/out:/acme.sh   --net=host  --name=acme.sh neilpang/acme.sh daemon
    if test -s /opt/.acme.sh/out/server.crt; then
	    
        green "证书申请成功"
    else
    	red "申请证书失败"
    docker exec acme.sh  --register-account -m imwl@live.com
    docker exec acme.sh    --issue  -d $your_domain  --standalone 
    docker exec acme.sh acme.sh  --installcert  -d  $your_domain  \
        --key-file   /acme.sh/server.key \
        --fullchain-file /acme.sh/server.crt
      fi
    if test -s /opt/.acme.sh/out/server.crt; then
	    
        green "证书申请成功"
    else
    	red "申请证书失败"
		red "使用 nginx 方式"
		docker start nginx 
		docker exec acme.sh   --issue  -d $your_domain   --nginx
		docker exec acme.sh acme.sh    --installcert  -d  $your_domain  \
        --key-file   /acme.sh/server.key \
        --fullchain-file /acme.sh/server.crt
	fi
    if test -s /opt/.acme.sh/out/server.crt; then
        green "证书申请成功"
	else
	    red "申请证书失败"
		red "使用 http 方式"
		docker exec acme.sh   --issue  -d $your_domain --webroot /opt/trojan-go/html/
		docker exec acme.sh acme.sh   --installcert  -d  $your_domain  \
        --key-file /acme.sh/server.key \
        --fullchain-file /acme.sh/server.crt
	fi
    if test -s /opt/.acme.sh/out/server.crt; then
        green "证书申请成功"	
	else
	    red "申请证书失败"
	    exit 1
    fi
docker restart nginx
docker restart trojan-go
}


function install_docker(){
  curl https://get.docker.com > /tmp/install.sh
  chmod +x /tmp/install.sh
  /tmp/install.sh


# curl -sSL https://get.daocloud.io/docker | sh   # 国内可以这样安装
}
function start_docker(){
  sudo usermod -aG docker $USER  # 避免每次都输入 sudo,将用户加入 docker 用户组
  service docker restart
  systemctl enable docker
  newgrp docker 
 }

function stop(){
    red "按需删除"
    red "docker rm -f trojan-go ;  rm -rf /opt/across/trojan-go"
    red "docker rm -f nginx     ;  rm -rf /opt/nginx"
    red "docker rm -f acme.sh   ;  rm -rf /opt/.acme.sh"
}

function bbr_boost_sh(){
    wget -N --no-check-certificate "https://raw.githubusercontent.com/itswl/shellbackup/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

start_menu(){
    clear
    echo
    green "0. 初次运行" 
    green "d. 安装 docker" 
    green " 1. 安装"
    red " 2. 删除"
    green " 3. 修复证书，并重启服务"
    green " 4. 安装BBR-PLUS加速4合一脚本"
    blue " q. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    0)
    first_run
    ;;
    d)
    install_docker
    start_docker
    ;;
    1)
    check_domain
    check_ports
    install_nginx
    install_trojan_go
    repair_cert
    ;;
    2)
    stop
    ;;
    3)
    docker stop nginx
    docker stop trojan-go
    check_domain
    check_ports
    repair_cert 
    ;;
    4)
    bbr_boost_sh 
    ;;
    q)
    exit 1
    ;;
    *)
    clear
    red "请输入正确数字"
    sleep 1s
    start_menu
    ;;
    esac
}
start_menu
