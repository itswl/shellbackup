```

wget -N --no-check-certificate \
"https://raw.githubusercontent.com/itswl/shellbackup/master/install_trojan_go_docker.sh" \
&& chmod +x install_trojan_go_docker.sh \
&& ./install_trojan_go_docker.sh


mkdir /etc/iptables-rule
cd /etc/iptables-rule
wget https://raw.githubusercontent.com/itswl/shellbackup/refs/heads/main/iptables-operator.sh
wget https://raw.githubusercontent.com/itswl/shellbackup/refs/heads/main/iptables_config.conf
bash iptables-operator.sh

wget https://raw.githubusercontent.com/itswl/shellbackup/refs/heads/main/install-docker-uninstall.sh
```
