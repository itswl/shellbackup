#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIRNAME="$(dirname "$SCRIPT_PATH")"

CONFIG_FILE="$SCRIPT_DIRNAME/iptables_config.conf"
LOG_FILE="/var/log/iptables-operator.txt"
CONFIG_MD5_FILE="$SCRIPT_DIRNAME/iptables-config.md5"

# 默认使用的iptables表名，可以根据需要修改
DEFAULT_TABLE="mangle"

CRON_REBOOT="@reboot /bin/bash $SCRIPT_PATH -m whitelist -a setup"
CRON_MINUTE="* * * * * /bin/bash $SCRIPT_PATH  -m whitelist -a setup"

CRONTAB_CONTENT="$(crontab -l 2>/dev/null || true)"
NEED_UPDATE=false

echo "$CRONTAB_CONTENT" | grep -Fxq "$CRON_REBOOT" || {
    echo "[INFO] 添加 @reboot"
    CRONTAB_CONTENT="$CRONTAB_CONTENT"$'\n'"$CRON_REBOOT"
    NEED_UPDATE=true
}
echo "$CRONTAB_CONTENT" | grep -Fxq "$CRON_MINUTE" || {
    echo "[INFO] 添加每分钟任务"
    CRONTAB_CONTENT="$CRONTAB_CONTENT"$'\n'"$CRON_MINUTE"
    NEED_UPDATE=true
}
[ "$NEED_UPDATE" = true ] && echo "$CRONTAB_CONTENT" | crontab - && echo "[INFO] crontab 已更新"

# 开启输出到日志文件
# log() {
#     echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
# }

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

handle_error() {
    log "错误: $1"
    [ "$2" = "exit" ] && exit 1
}

check_prerequisites() {
    command -v iptables >/dev/null || handle_error "iptables 命令不存在" "exit"
    [ -f "$CONFIG_FILE" ] || handle_error "配置文件不存在: $CONFIG_FILE" "exit"
}

rule_exists() {
    local table="$1"; shift
    local chain="$1"; shift
    local match="$*"
    # 使用更精确的匹配方式，确保完整规则匹配
    # 将规则格式化为标准格式，然后进行完整匹配
    local rule_pattern="-A $chain $match"
    iptables -t "$table" -S "$chain" | grep -Fx -- "$rule_pattern" >/dev/null 2>&1
}

chain_linked() {
    local table="$1"; local chain="$2"
    iptables -t "$table" -S PREROUTING | grep -q "\-j $chain"
}

# 检查配置文件是否有变化
config_changed() {
    
    # 计算当前配置文件的MD5值
    local current_md5=$(md5 -q "$CONFIG_FILE" 2>/dev/null || md5sum "$CONFIG_FILE" 2>/dev/null | awk '{print $1}')
    local stored_md5=$(cat "$CONFIG_MD5_FILE" 2>/dev/null || echo '')
    
    # 比较MD5值
    if [ "$current_md5" != "$stored_md5" ]; then
        # 更新MD5文件
        echo "$current_md5" > "$CONFIG_MD5_FILE"
        return 0  # 返回true，表示配置已变化
    else
        return 1  # 返回false，表示配置未变化
    fi
}

setup_chain() {
    local chain="$1"
    local table="$2"
    local mode=""
    
    # 根据链名确定模式
    [ "$chain" = "whitelist" ] && mode="whitelist"
    [ "$chain" = "restricted_ports" ] && mode="restricted"

    # 检查链是否存在
    if iptables -t "$table" -L "$chain" -n &>/dev/null; then
        # 如果链存在，检查是否已经是第一个规则
        if iptables -t "$table" -S PREROUTING | awk 'NR==2 {print}' | grep -q -- "-j $chain"; then
            # 即使链已存在并位置正确，也需要检查配置是否变化
            if [ -n "$mode" ] && config_changed; then
                # 配置已变化，删除现有链
                delete_rules "$mode"
                # 重新创建链
                iptables -t "$table" -N "$chain" 2>/dev/null || true
                iptables -t "$table" -I PREROUTING 1 -j "$chain"
                echo "[INFO] $chain 链已重新创建并添加为 PREROUTING 链的第一个规则"
            else
                echo "[INFO] $chain 链已存在并已是 PREROUTING 链的第一个规则，配置未变化，跳过"
            fi
        else
            # 如果链存在但不是第一个规则
            if [ -n "$mode" ] ; then
                # 配置已变化，删除现有链
                delete_rules "$mode"
                # 重新创建链
                iptables -t "$table" -N "$chain" 2>/dev/null || true
                iptables -t "$table" -I PREROUTING 1 -j "$chain"
                echo "[INFO] $chain 链已重新创建并添加为 PREROUTING 链的第一个规则"
            else
                # 配置未变化或无法确定模式，直接尝试将链添加为第一个规则
                iptables -t "$table" -D PREROUTING -j "$chain" 2>/dev/null || true
                iptables -t "$table" -I PREROUTING 1 -j "$chain"
                echo "[INFO] $chain 链已添加为 PREROUTING 链的第一个规则"
            fi
        fi
    else
        # 如果链不存在，则创建链并添加为第一个规则
        iptables -t "$table" -N "$chain"
        iptables -t "$table" -I PREROUTING 1 -j "$chain"
        echo "[INFO] $chain 链已创建并添加为 PREROUTING 链的第一个规则"
    fi
}

setup_network_rules() {
    local chain="$1"; local table="$2"
    # 创建一个关联数组来跟踪已添加的网络规则
    declare -A added_networks
    
    for net in "${ALLOWED_NETWORKS[@]}"; do
        # 处理localhost特殊情况，将其转换为127.0.0.1/32
        if [ "$net" = "localhost" ]; then
            net="127.0.0.1/32"
        fi
        
        # 检查这个网络是否已经添加过
        if [ -z "${added_networks[$net]}" ]; then
            # 标记这个网络已经被处理
            added_networks[$net]=1
            # 检查规则是否已存在
            if ! rule_exists "$table" "$chain" "-s $net -m comment --comment managed_by_iptables-operator -j RETURN"; then
                iptables -t "$table" -I "$chain" -s "$net" -j RETURN -m comment --comment "managed_by_iptables-operator"
                echo "[INFO] 添加网络规则: -s $net -j RETURN"
            else
                echo "[INFO] 网络规则已存在: -s $net -j RETURN"
            fi
        else
            echo "[INFO] 跳过重复网络: $net"
        fi
    done
}

setup_port_rules() {
    local chain="$1"; local table="$2"; local ports="$3"; local action="$4"
    # 创建一个关联数组来跟踪已添加的端口规则
    declare -A added_ports
    
    for port in $ports; do
        # 检查这个端口是否已经添加过
        if [ -z "${added_ports[$port]}" ]; then
            # 标记这个端口已经被处理
            added_ports[$port]=1
            
            # 检查TCP规则是否已存在
            if ! rule_exists "$table" "$chain" "-p tcp -m tcp --dport $port -m comment --comment managed_by_iptables-operator -j $action"; then
                iptables -t "$table" -I "$chain" -p tcp --dport "$port" -j "$action" -m comment --comment "managed_by_iptables-operator"
                echo "[INFO] 添加TCP端口规则: --dport $port -j $action"
            else
                echo "[INFO] TCP端口规则已存在: --dport $port -j $action"
            fi
            
            # 检查UDP规则是否已存在
            if ! rule_exists "$table" "$chain" "-p udp -m udp --dport $port -m comment --comment managed_by_iptables-operator -j $action"; then
                iptables -t "$table" -I "$chain" -p udp --dport "$port" -j "$action" -m comment --comment "managed_by_iptables-operator"
                echo "[INFO] 添加UDP端口规则: --dport $port -j $action"
            else
                echo "[INFO] UDP端口规则已存在: --dport $port -j $action"
            fi
        else
            echo "[INFO] 跳过重复端口: $port"
        fi
    done
}


delete_rules() {
    local mode="$1"
    local chain=""
    
    [ "$mode" = "whitelist" ] && chain="whitelist"
    [ "$mode" = "restricted" ] && chain="restricted_ports"
    log "删除 $chain 链..."
   
    iptables -t "$DEFAULT_TABLE" -D PREROUTING -j "$chain" 2>/dev/null
    iptables -t "$DEFAULT_TABLE" -F "$chain"
    iptables -t "$DEFAULT_TABLE" -X "$chain"
    log "$chain 链删除完成"
    
    echo "$(date)" >> "$LOG_FILE"
    echo "delete_iptables_${mode}_mode_success" >> "$LOG_FILE"
}

setup_whitelist_mode() {
    log "设置 whitelist 模式..."
    setup_chain "whitelist" "$DEFAULT_TABLE"
    setup_port_rules "whitelist" "$DEFAULT_TABLE" "$whitelist_ports" "RETURN"
    setup_network_rules "whitelist" "$DEFAULT_TABLE"
    
    # 添加已建立连接和相关连接的规则
    if ! rule_exists "$DEFAULT_TABLE" "whitelist" "-m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment managed_by_iptables-operator -j RETURN"; then
        iptables -t "$DEFAULT_TABLE" -I whitelist 2 -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN -m comment --comment "managed_by_iptables-operator"
        echo "[INFO] 添加已建立连接规则: -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN"
    else
        echo "[INFO] 已建立连接规则已存在，跳过添加"
    fi
    
    # 检查DROP规则是否存在，只有不存在时才添加
    if ! rule_exists "$DEFAULT_TABLE" "whitelist" "-m comment --comment managed_by_iptables-operator" "-j DROP"; then
        iptables -t "$DEFAULT_TABLE" -A whitelist -j DROP -m comment --comment "managed_by_iptables-operator"
        echo "[INFO] 添加默认DROP规则"
    else
        echo "[INFO] 默认DROP规则已存在，跳过添加"
    fi
}

setup_restricted_mode() {
    log "设置 restricted 模式..."
    setup_chain "restricted_ports" "$DEFAULT_TABLE"
    setup_port_rules "restricted_ports" "$DEFAULT_TABLE" "$restricted_ports" "DROP"
    setup_network_rules "restricted_ports" "$DEFAULT_TABLE"
}

show_usage() {
    echo "用法: $0 -m [whitelist|restricted] -a [setup|delete] [-f]"
    exit 1
}

main() {
    local MODE=""; local ACTION="setup"; local FORCE=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode) MODE="$2"; shift 2 ;;
            -a|--action) ACTION="$2"; shift 2 ;;
            -h|--help) show_usage ;;
            *) echo "未知参数: $1"; show_usage ;;
        esac
    done

    [[ "$MODE" != "whitelist" && "$MODE" != "restricted" ]] && show_usage
    [[ "$ACTION" != "setup" && "$ACTION" != "delete" ]] && show_usage

    check_prerequisites
    source "$CONFIG_FILE"

    case "$ACTION" in
        setup)
            log "开始设置 $MODE 模式 iptables"
            [ "$MODE" = "whitelist" ] && setup_whitelist_mode
            [ "$MODE" = "restricted" ] && setup_restricted_mode
            log "iptables $MODE 模式设置完成"
            echo "$(date)" >> "$LOG_FILE"
            echo "init_iptables_${MODE}_mode_success" >> "$LOG_FILE"
            ;;
        delete)
            delete_rules "$MODE"
            ;;
    esac
}

main "$@"
