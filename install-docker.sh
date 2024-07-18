ARCH=$(uname -m)
DOCKER_VER=27.0.3
DOCKER_COMPOSE_VER=v2.29.0
REGISTRY_MIRROR=US
BASE=/opt/installpackage

mkdir -p $BASE/down $BASE/bin /opt/kube/bin

function download_docker() {
  if [[ "$REGISTRY_MIRROR" == CN ]];then
    DOCKER_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/${ARCH}/docker-${DOCKER_VER}.tgz"
  else
    DOCKER_URL="https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VER}.tgz"
  fi

  if [[ -f "$BASE/down/docker-${DOCKER_VER}.tgz" ]];then
    logger warn "docker binaries already existed"
  else
    logger info "downloading docker binaries, arch:$ARCH, version:$DOCKER_VER"
    if [[ -e /usr/bin/wget ]];then
      wget -c --no-check-certificate "$DOCKER_URL" || { logger error "downloading docker failed"; exit 1; }
    else
      curl -k -C- -O --retry 3 "$DOCKER_URL" || { logger error "downloading docker failed"; exit 1; }
    fi
    mv -f "./docker-$DOCKER_VER.tgz" "$BASE/down"
  fi

  tar zxf "$BASE/down/docker-$DOCKER_VER.tgz" -C "$BASE/down" && \
  mkdir -p "$BASE/bin/docker-bin" && \
  cp -f "$BASE"/down/docker/* "$BASE/bin/docker-bin" && \
  mv -f "$BASE"/down/docker/* /opt/kube/bin && \
  ln -sf /opt/kube/bin/docker /bin/docker 
  cat > /etc/profile.d/docker-env.sh << EOF
export PATH=\$PATH:/opt/kube/bin
EOF

  echo
}

function download_docker_compose() {
  if [[ "$REGISTRY_MIRROR" == CN ]];then
    DOCKER_COMPOSE_URL="https://get.daocloud.io/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-linux-${ARCH}"
    DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-linux-${ARCH}"
  else
    DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-linux-${ARCH}"
  fi

  if [[ -f "$BASE/down/docker-compose-linux-${ARCH}" ]];then
    logger warn "docker-compose binaries already existed"
  else
    logger info "downloading docker-compose binaries, arch:$ARCH, version:$DOCKER_VER"
    if [[ -e /usr/bin/wget ]];then
      wget -c --no-check-certificate "$DOCKER_COMPOSE_URL" || { logger error "downloading docker-compose failed"; exit 1; }
    else
      curl -L --retry 3 "$DOCKER_COMPOSE_URL" > "./docker-compose-linux-${ARCH}"  || { logger error "downloading docker-compose failed"; exit 1; }
    fi
    mv -f "./docker-compose-linux-${ARCH}" "$BASE/down"
  fi
  cp -f  "$BASE/down/docker-compose-linux-${ARCH}"  "$BASE/bin/docker-compose" && \
  cp -f  "$BASE/bin/docker-compose"  "/opt/kube/bin/docker-compose" && \
  ln -sf /opt/kube/bin/docker-compose /bin/docker-compose
}

function install_docker() {
  # check if a container runtime is already installed
  systemctl status docker|grep Active|grep -q running && { logger warn "docker is already running."; return 0; }
 
  logger debug "generate docker service file"
  cat > /etc/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
[Service]
Environment="PATH=/opt/kube/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/opt/kube/bin/dockerd
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

  # configuration for dockerd
  mkdir -p /etc/docker
  DOCKER_VER_MAIN=$(echo "$DOCKER_VER"|cut -d. -f1)
  CGROUP_DRIVER="cgroupfs"
  ((DOCKER_VER_MAIN>=20)) && CGROUP_DRIVER="systemd"
  logger debug "generate docker config: /etc/docker/daemon.json"
  if [[ "$REGISTRY_MIRROR" == CN ]];then
    logger debug "prepare register mirror for $REGISTRY_MIRROR"
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=$CGROUP_DRIVER"],
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://kuamavit.mirror.aliyuncs.com"
  ],
  "insecure-registries": ["http://registry.bap.datacanvas.com:5000"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    },
  "data-root": "/var/lib/docker"
}
EOF
  else
    logger debug "standard config without registry mirrors"
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=$CGROUP_DRIVER"],
  "insecure-registries": ["http://registry.bap.datacanvas.com:5000"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    },
  "data-root": "/var/lib/docker"
}
EOF
  fi

  if [[ -f /etc/selinux/config ]]; then
    logger debug "turn off selinux"
    getenforce|grep Disabled || setenforce 0
    sed -i 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config
  fi

  logger debug "enable and start docker"
  systemctl enable docker
  systemctl daemon-reload && systemctl restart docker && sleep 3
}

download_docker_compose
download_docker
chmod 777 -R /opt/kube/bin
install_docker
