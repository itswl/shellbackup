#!/bin/bash
#
# 简洁高效的Docker安装/卸载脚本
# 支持amd64/arm64架构，自动检测系统环境

set -e

# 基本配置
DOCKER_VER="28.0.4"
DOCKER_COMPOSE_VER="v2.34.0"
BUILDX_VER="v0.22.0"
REGISTRY_MIRROR="US"  # 可选: CN
TEMP_DIR="/tmp/docker-install"
DOCKER_BIN_DIR="/opt/docker/bin"
PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"
USER="imwl"
data_root="/data/docker"


# 检测系统架构
ARCH=$(uname -m)
OS=$(uname | tr '[:upper:]' '[:lower:]')
case "$ARCH" in
  x86_64)  ARCH_DOCKER="amd64" ;;
  aarch64|arm64) ARCH_DOCKER="arm64" ;;
  *) log ERROR "不支持的架构: $ARCH"; exit 1 ;;
esac


# 颜色和样式
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[36m"
C_RESET="\033[0m"
B_BOLD="\033[1m"

# 日志函数
log() {
  local level="$1"
  local msg="$2"
  local color=""
  
  case "$level" in
    INFO)  color="$C_GREEN" ;;
    WARN)  color="$C_YELLOW" ;;
    ERROR) color="$C_RED" ;;
    DEBUG) color="$C_BLUE" ;;
  esac
  
  echo -e "${color}[${level}]${C_RESET} ${msg}"
}
# 查看提供版本
# https://download.docker.com/linux/static/stable/x86_64/
# https://github.com/docker/compose/releases
# https://github.com/docker/buildx/releases

# 显示帮助
show_help() {
  echo -e "${B_BOLD}Docker安装/卸载脚本${C_RESET}"
  echo "用法: $0 [选项]"
  echo
  echo "选项:"
  echo "  --download    仅下载Docker组件"
  echo "  --install     安装已下载的Docker组件"
  echo "  --all         下载并安装Docker (相当于--download + --install)"
  echo "  --uninstall   卸载Docker"
  echo "  --help        显示此帮助"
  echo
  echo "示例:"
  echo "  $0 --download   # 仅下载Docker组件"
  echo "  $0 --install    # 安装已下载的Docker组件"
  echo "  $0 --all        # 下载并安装Docker"
  echo "  $0 --uninstall  # 卸载Docker"
  echo
}

# 检查依赖
check_requirements() {
  log INFO "检查系统环境..."
  
  # 检查root权限
  if [[ $EUID -ne 0 ]]; then
    log ERROR "此脚本需要root权限运行"
    echo "请使用 sudo $0 [选项] 运行此脚本"
    exit 1
  fi
  
  # 检查iptables
  if ! command -v iptables &>/dev/null; then
    log WARN "未检测到iptables，Docker的网络功能可能受限"
    log WARN "建议安装iptables后再继续"
    read -p "继续安装Docker? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
  fi
}

# 下载文件
download_file() {
  local url="$1"
  local output="$2"
  local name="$3"
  
  if [[ -f "$output" ]]; then
    log WARN "$name文件已存在"
    return 0
  fi
  
  log INFO "下载$name..."
  if command -v wget &>/dev/null; then
    wget -q --show-progress --progress=bar:force:noscroll -O "$output" "$url" || { 
      log ERROR "下载$name失败"; 
      return 1; 
    }
  else
    curl -L --progress-bar -o "$output" "$url" || { 
      log ERROR "下载$name失败"; 
      return 1; 
    }
  fi
  
  return 0
}

# 下载Docker组件
download_docker_files() {
  log INFO "下载路径: $TEMP_DIR"
  log INFO "开始下载Docker ${DOCKER_VER}组件..."

  # 创建必要目录
  mkdir -p "$TEMP_DIR" "$PLUGIN_DIR"
  # 设置下载URL
  DOCKER_URL="https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VER}.tgz"
  GITHUB_PROXY=""
  COMPOSE_FILENAME="docker-compose-linux-${ARCH}"
  BUILDX_FILENAME="buildx-${BUILDX_VER}.${OS}-${ARCH_DOCKER}"
  
  if [[ "$REGISTRY_MIRROR" == "CN" ]]; then
    DOCKER_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/${ARCH}/docker-${DOCKER_VER}.tgz"
    GITHUB_PROXY="https://ghfast.top/"
  fi
  
  # 下载Docker二进制文件
  DOCKER_PKG="$TEMP_DIR/docker-${DOCKER_VER}.tgz"
  download_file "$DOCKER_URL" "$DOCKER_PKG" "Docker二进制包" || exit 1
  
  # 下载Docker Compose
  COMPOSE_URL="${GITHUB_PROXY}https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/${COMPOSE_FILENAME}"
  download_file "$COMPOSE_URL" "$TEMP_DIR/$COMPOSE_FILENAME-${DOCKER_COMPOSE_VER}" "Docker Compose" || exit 1
  
  # 下载Docker Buildx
  BUILDX_URL="${GITHUB_PROXY}https://github.com/docker/buildx/releases/download/${BUILDX_VER}/${BUILDX_FILENAME}"
  download_file "$BUILDX_URL" "$TEMP_DIR/$BUILDX_FILENAME" "Docker Buildx" || exit 1
  
  log INFO "✅ Docker组件下载完成，文件保存在 $TEMP_DIR"
  log INFO "可以使用 'bash $0 --install' 命令安装Docker"
}

# 安装Docker
install_docker() {
  log INFO "开始安装Docker ${DOCKER_VER}..."
  
  # 创建必要目录
  mkdir -p "$TEMP_DIR" "$PLUGIN_DIR" "$DOCKER_BIN_DIR"

  # 检查是否已下载所需文件
  DOCKER_PKG="$TEMP_DIR/docker-${DOCKER_VER}.tgz"
  COMPOSE_FILENAME="docker-compose-linux-${ARCH}"
  BUILDX_FILENAME="buildx-${BUILDX_VER}.${OS}-${ARCH_DOCKER}"
  
  if [[ ! -f "$DOCKER_PKG" ]]; then
    log ERROR "Docker二进制包不存在: $DOCKER_PKG"
    log INFO "请先运行: bash $0 --download"
    exit 1
  fi
  
  if [[ ! -f "$TEMP_DIR/$COMPOSE_FILENAME-${DOCKER_COMPOSE_VER}" ]]; then
    log ERROR "Docker Compose不存在: $TEMP_DIR/$COMPOSE_FILENAME"
    log INFO "请先运行: bash $0 --download"
    exit 1
  fi
  
  if [[ ! -f "$TEMP_DIR/$BUILDX_FILENAME" ]]; then
    log ERROR "Docker Buildx不存在: $TEMP_DIR/$BUILDX_FILENAME"
    log INFO "请先运行: bash $0 --download"
    exit 1
  fi
  
  # 创建必要目录
  mkdir -p "$DOCKER_BIN_DIR"
  
  # 解压并安装Docker
  log INFO "安装Docker二进制文件..."
  tar -xzf "$DOCKER_PKG" -C "$TEMP_DIR" || { log ERROR "解压Docker失败"; exit 1; }
  
  # 安装Docker二进制文件
  install -m 755 "$TEMP_DIR"/docker/* "$DOCKER_BIN_DIR/"
  
  # 创建链接到/usr/bin
  if [[ "$DOCKER_BIN_DIR" != "/usr/bin" ]]; then
    if [[ -f "/usr/bin/docker" ]]; then
      log WARN "备份已存在的 /usr/bin/docker 到 /usr/bin/docker.$(date +%Y%m%d%H%M%S)"
      mv "/usr/bin/docker" "/usr/bin/docker.$(date +%Y%m%d%H%M%S)"
    fi
    log INFO "创建符号链接: $DOCKER_BIN_DIR/docker -> /usr/bin/docker"
    ln -sf "$DOCKER_BIN_DIR/docker" "/usr/bin/docker"
  fi
  
  # 安装插件
  log INFO "安装Docker CLI插件..."
  install -m 755 "$TEMP_DIR/$COMPOSE_FILENAME-${DOCKER_COMPOSE_VER}" "$PLUGIN_DIR/docker-compose"
  install -m 755 "$TEMP_DIR/$BUILDX_FILENAME" "$PLUGIN_DIR/docker-buildx"
  
  # 配置Docker服务
  log INFO "配置Docker服务..."
  
  # 创建Docker用户组
  if ! getent group docker > /dev/null; then
    groupadd docker
  fi
  usermod -aG docker "$USER"
  
  # 创建服务文件
  cat > /etc/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target
Wants=network-online.target

[Service]
Environment="PATH=${DOCKER_BIN_DIR}:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=${DOCKER_BIN_DIR}/dockerd
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutStartSec=0
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
  
  # 配置Docker
  mkdir -p /etc/docker
  CGROUP_DRIVER="systemd"
  
  # 创建配置文件
  cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=${CGROUP_DRIVER}"],
  "insecure-registries": ["http://localhost:5000"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "data-root": "${data_root}"
EOF
  # 注意：使用默认数据目录/var/lib/docker
  
  # 为中国用户添加镜像
  if [[ "$REGISTRY_MIRROR" == "CN" ]]; then
    cat >> /etc/docker/daemon.json << EOF
,
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://hub1.nat.tf",
    "https://docker.1panel.live",
    "https://proxy.1panel.live"
  ]
EOF
  fi
  
  # 关闭配置文件
  echo -e "}" >> /etc/docker/daemon.json
  
  # 禁用SELinux
  if [[ -f /etc/selinux/config ]]; then
    sed -i 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config
    if command -v setenforce &>/dev/null; then
      setenforce 0 2>/dev/null || true
    fi
  fi
  
  # 启动Docker
  log INFO "启动Docker服务..."
  systemctl daemon-reload
  systemctl enable docker
  systemctl restart docker
  
  # 等待服务启动
  for i in {1..5}; do
    if systemctl is-active --quiet docker; then
      break
    fi
    log INFO "等待Docker启动...$i/5"
    sleep 2
  done
  
  if ! systemctl is-active --quiet docker; then
    log ERROR "Docker启动失败，请检查: journalctl -u docker"
    exit 1
  fi
  
  # 显示结果
  log INFO "✅ Docker安装成功！"
  log INFO "Docker 版本: $(docker --version)"
  log INFO "Docker Compose 版本: $(docker compose version)"
  log INFO "Docker Buildx 版本: $(docker buildx version)"
  log INFO "提示: 需要重新登录或运行'newgrp docker'使用户组设置生效"
}

# 卸载Docker
uninstall_docker() {
  log INFO "开始卸载Docker..."
  
  # 停止并禁用服务
  if systemctl is-active --quiet docker; then
    log INFO "停止Docker服务"
    systemctl stop docker
  fi
  
  if systemctl is-enabled --quiet docker 2>/dev/null; then
    log INFO "禁用Docker服务"
    systemctl disable docker
  fi
  
  # 删除文件
  log INFO "删除Docker文件和配置..."
  
  # 服务文件
  rm -f /etc/systemd/system/docker.service
  systemctl daemon-reload
  
  # 二进制文件
  rm -rf $DOCKER_BIN_DIR
  rm -rf $PLUGIN_DIR
  rm -rf /usr/bin/docker
  # 配置文件
  rm -rf /etc/docker
  
  # 环境文件
  rm -f /etc/profile.d/docker-env.sh
  
  # 提示数据目录
  log WARN "数据目录(/var/lib/docker)未被删除"
  log INFO "如需删除所有Docker数据，请手动执行: rm -rf /var/lib/docker"
  log INFO "⚠️ 警告：这将永久删除所有容器、镜像和卷！"
  
  log INFO "✅ Docker卸载完成"
}

# 主函数
main() {
  # 处理命令行参数
  if [[ $# -eq 0 ]]; then
    show_help
    exit 0
  fi
  
  case "$1" in
    --download)
      check_requirements
      download_docker_files
      ;;
    --install)
      check_requirements
      install_docker
      ;;
    --all)
      check_requirements
      download_docker_files
      install_docker
      ;;
    --uninstall)
      check_requirements
      uninstall_docker
      ;;
    --help|*)
      show_help
      exit 0
      ;;
  esac
}

# 执行主程序
main "$@"
