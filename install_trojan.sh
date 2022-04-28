#!/bin/bash
osis='linux-amd64'
echo "$osis"
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

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

function install_trojan(){
green "======================="
blue "请输入绑定到本VPS的域名"
green "======================="
read your_domain
systemctl stop nginx
$systemPackage -y install net-tools socat curl
real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
local_addr=`curl ipv4.icanhazip.com`
if [ $real_addr == $local_addr ] ; then
	green "=========================================="
	green "       域名解析正常，开始安装trojan"
	green "=========================================="
	sleep 1s
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
CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
if [ "$CHECK" == "SELINUX=enforcing" ]; then
    red "======================================================================="
    red "检测到SELinux为开启状态，为防止申请证书失败，请先重启VPS后，再执行本脚本"
    red "======================================================================="
    read -p "是否现在重启 ?请输入 [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
	    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
	    echo -e "VPS 重启中..."
	    reboot
	fi
    exit
fi
if [ "$CHECK" == "SELINUX=permissive" ]; then
    red "======================================================================="
    red "检测到SELinux为宽容状态，为防止申请证书失败，请先重启VPS后，再执行本脚本"
    red "======================================================================="
    read -p "是否现在重启 ?请输入 [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
	    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
	    echo -e "VPS 重启中..."
	    reboot
	fi
    exit
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
    rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
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
    apt-get purge netfilter-persistent
    systemctl stop ufw
    systemctl disable ufw
    apt-get update
elif [ "$release" == "debian" ]; then
    apt-get update
fi
$systemPackage -y install  nginx unzip zip tar >/dev/null 2>&1
systemctl enable nginx
systemctl stop nginx
cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  auto;
error_log  /var/log/nginx/error.log warn;
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
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF
	#设置伪装站
	rm -rf /usr/share/nginx/html/*
	cd /usr/share/nginx/html/
	wget https://github.com/itswl/itswl.github.io/archive/master.zip > /dev/null 2>&1 
    unzip master.zip  > /dev/null 2>&1 
	mv itswl*/* ./ && rm -rf itswl*  master.zip 
	wget -N --no-check-certificate "https://raw.githubusercontent.com/itswl/shellbackup/master/myclashrule.yml"  > /dev/null 2>&1
	systemctl stop nginx
	sleep 5
	#申请https证书
	if [ -f "/usr/src/trojan/trojan-cert/fullchain.cer" ];then

		green "证书文件存在"

	else
		red "证书文件不存在"
		mkdir -p /usr/src/trojan/trojan-cert 
	    curl https://get.acme.sh | sh
	    ~/.acme.sh/acme.sh --register-account -m imwl@live.com
	    ~/.acme.sh/acme.sh  --issue  -d $your_domain  --standalone
    	~/.acme.sh/acme.sh  --installcert  -d  $your_domain \
        --key-file   /usr/src/trojan/trojan-cert/private.key \
        --fullchain-file /usr/src/trojan/trojan-cert/fullchain.cer
	fi
	if test -s /usr/src/trojan/trojan-cert/fullchain.cer; then
	systemctl start nginx

    cd /usr/src/trojan/
	#wget https://github.com/trojan-gfw/trojan/releases/download/v1.13.0/trojan-1.13.0-linux-amd64.tar.xz
	wget https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest -O latest-trojan > /dev/null 2>&1
	latest_version=`grep tag_name latest-trojan| awk -F '[:,"v]' '{print $6}'`
	echo "trojan-go-v${latest_version}" > /usr/src/trojan_version
	wget https://github.com/p4gefau1t/trojan-go/releases/download/v${latest_version}/trojan-go-$osis.zip  > /dev/null 2>&1
	unzip trojan-go-$osis.zip  > /dev/null 2>&1  && rm -rf latest-trojan trojan_version trojan-go-$osis.zip
	trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
	cat > /usr/src/trojan/cli-config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": 443,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.cer",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": true,
        "fast_open_qlen": 40
    }
}
EOF
rm -rf /usr/src/trojan/server.json
cat > /usr/src/trojan/server.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/usr/src/trojan/trojan-cert/fullchain.cer",
        "key": "/usr/src/trojan/trojan-cert/private.key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 81
        },

        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": true,
        "reuse_port": true,
        "fast_open_qlen": 40
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    },
	"mux": {
    "enabled": true,
    "concurrency": 8,
    "idle_timeout": 60
    },
	"router": {
    "enabled": true,
    "block": ["geosite:category-ads", "cidr:192.168.0.0/16"]
  }
}
EOF


green "增加启动脚本	"

cat > ${systempwd}trojan-go.service <<-EOF
[Unit]  
Description=trojan-go 
After=network.target  
   
[Service]  
Type=simple  
PIDFile=/usr/src/trojan/trojan/trojan-go.pid
ExecStart=/usr/src/trojan/trojan-go -config /usr/src/trojan/server.json
ExecReload=  
ExecStop=/usr/src/trojan/trojan  
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target
EOF
green "增加启动脚本完成"

	chmod +x ${systempwd}trojan-go.service
	systemctl start trojan-go.service  > /dev/null 2>&1 
	systemctl enable trojan-go.service
	systemctl restart trojan-go.service
	green "======================================================================"
	green "Trojan-go已安装完成，请使用以下链接下载trojan-go客户端"
	green "Trojan推荐使用 clash 工具代理（WIN/MAC通用）下载地址如下："
	green "https://github.com/Fndroid/clash_for_windows_pkg/releases  (exe为Win客户端,dmg为Mac客户端)"
	green "http://${your_domain}/myclashrule.yml  (clash分流配置)"
	green "vi /usr/src/trojan/server.json    systemctl restart trojan"
	green "======================================================================"
	else
        red "==================================="
	red "https证书没有申请成果，自动安装失败"
	green "不要担心，你可以手动修复证书申请"
	green "1. 重启VPS"
	green "2. 重新执行脚本，使用修复证书功能"
	red "==================================="
	rm -rf 1
	fi
	
else
	red "================================"
	red "域名解析地址与本VPS IP地址不一致"
	red "本次安装失败，请确保域名解析正常"
	red "================================"
fi
}

function repair_cert(){
systemctl stop nginx
Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
if [ -n "$Port80" ]; then
    process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
    red "==========================================================="
    red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
    red "==========================================================="
    exit 1
fi
green "======================="
blue "请输入绑定到本VPS的域名"
blue "务必与之前失败使用的域名一致"
green "======================="
read your_domain
real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
local_addr=`curl ipv4.icanhazip.com`
if [ $real_addr == $local_addr ] ; then
    ~/.acme.sh/acme.sh --register-account -m imwl@live.com
    ~/.acme.sh/acme.sh  --issue  -d $your_domain  --standalone 
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain  \
        --key-file   /usr/src/trojan/trojan-cert/private.key \
        --fullchain-file /usr/src/trojan/trojan-cert/fullchain.cer
    if test -s /usr/src/trojan-cert/fullchain.cer; then
        green "证书申请成功"
	systemctl restart trojan
	systemctl start nginx
    else
    	red "申请证书失败"
		red "使用 nginx 方式"
		~/.acme.sh/acme.sh --issue  -d $your_domain   --nginx
		~/.acme.sh/acme.sh  --installcert  -d  $your_domain  \
        --key-file   /usr/src/trojan/trojan-cert/private.key \
        --fullchain-file /usr/src/trojan/trojan-cert/fullchain.cer
	fi
    if test -s /usr/src/trojan-cert/fullchain.cer; then
        green "证书申请成功"
	systemctl restart trojan
	systemctl restart nginx
	else
	    red "申请证书失败"
		red "使用 http 方式"
		~/.acme.sh/acme.sh  --issue  -d $your_domain --webroot /usr/share/nginx/html/
		~/.acme.sh/acme.sh  --installcert  -d  $your_domain  \
        --key-file   /usr/src/trojan/trojan-cert/private.key \
        --fullchain-file /usr/src/trojan/trojan-cert/fullchain.cer
	fi
    if test -s /usr/src/trojan-cert/fullchain.cer; then
        green "证书申请成功"		
	else
	    red "申请证书失败"
    fi
else
    red "================================"
    red "域名解析地址与本VPS IP地址不一致"
    red "本次安装失败，请确保域名解析正常"
    red "================================"
fi	
}


function remove_trojan(){
    red "================================"
    red "即将卸载trojan"
    red "同时卸载安装的nginx"
    red "================================"
    systemctl stop trojan-go
    systemctl disable trojan-go
    rm -f ${systempwd}trojan-go.service
    if [ "$release" == "centos" ]; then
        yum remove -y nginx
    else
        apt autoremove -y nginx
    fi
    rm -rf /usr/src/trojan*
    rm -rf /usr/share/nginx/html/*
    green "=============="
    green "trojan删除完毕"
    green "=============="
}

function bbr_boost_sh(){
    wget -N --no-check-certificate "https://raw.githubusercontent.com/itswl/shellbackup/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

start_menu(){
    clear
    echo
    green " 1. 安装trojan"
    red " 2. 卸载trojan"
    green " 3. 修复证书"
    green " 4. 安装BBR-PLUS加速4合一脚本"
    blue " 0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    install_trojan
    ;;
    2)
    remove_trojan 
    ;;
    3)
    repair_cert 
    ;;
    4)
    bbr_boost_sh 
    ;;
    0)
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
