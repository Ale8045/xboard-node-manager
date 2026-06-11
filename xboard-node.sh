#!/bin/bash

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"

V2BX_DIR="/etc/V2bX"
DATA_DIR="/etc/xboard-node-manager"
NODE_DB="$DATA_DIR/nodes.db"
CONFIG_FILE="$V2BX_DIR/config.yml"

check_root() {
    [ "$EUID" -ne 0 ] && echo -e "${Red}请使用 root 运行${Font}" && exit 1
}

install_base() {
    apt update -y
    apt install -y curl wget unzip tar nano lsof ca-certificates cron
}

install_v2bx() {
    if ! command -v V2bX >/dev/null 2>&1; then
        echo -e "${Yellow}正在安装 V2bX...${Font}"
        bash <(curl -Ls https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh)
    fi
}

select_protocol() {
    echo
    echo "请选择协议："
    echo "1. VMess"
    echo "2. VLESS"
    echo "3. Trojan"
    echo "4. Shadowsocks"
    echo "5. Hysteria2"
    echo "6. AnyTLS"
    echo
    read -p "请选择 [1-6]: " p

    case "$p" in
        1) PROTOCOL="VMess"; CORE="xray"; NODE_TYPE="V2ray"; ENABLE_VLESS="false" ;;
        2) PROTOCOL="VLESS"; CORE="xray"; NODE_TYPE="V2ray"; ENABLE_VLESS="true" ;;
        3) PROTOCOL="Trojan"; CORE="xray"; NODE_TYPE="Trojan"; ENABLE_VLESS="false" ;;
        4) PROTOCOL="Shadowsocks"; CORE="sing"; NODE_TYPE="Shadowsocks"; ENABLE_VLESS="false" ;;
        5) PROTOCOL="Hysteria2"; CORE="sing"; NODE_TYPE="Hysteria2"; ENABLE_VLESS="false" ;;
        6) PROTOCOL="AnyTLS"; CORE="sing"; NODE_TYPE="AnyTLS"; ENABLE_VLESS="false" ;;
        *) echo -e "${Red}选择错误${Font}"; exit 1 ;;
    esac
}

render_config() {
    mkdir -p "$V2BX_DIR"

    cat > "$CONFIG_FILE" <<EOF
Log:
  Level: warning
  AccessPath: ''
  ErrorPath: ''

Cores:
  - Type: xray
    Log:
      Level: warning
      AccessPath: ''
      ErrorPath: ''
  - Type: sing
    Log:
      Level: warning
      Timestamp: true

Nodes:
EOF

    while IFS='|' read -r PROTOCOL CORE NODE_TYPE PANEL_URL NODE_ID API_KEY ENABLE_VLESS; do
        [ -z "$PROTOCOL" ] && continue

        cat >> "$CONFIG_FILE" <<EOF
  - Core: $CORE
    ApiHost: "$PANEL_URL"
    ApiKey: "$API_KEY"
    NodeID: $NODE_ID
    NodeType: $NODE_TYPE
    Timeout: 30
    SpeedLimit: 0
    DeviceLimit: 0
    EnableVless: $ENABLE_VLESS
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      DisableUploadTraffic: false
      DisableGetRule: false
      EnableProxyProtocol: false
      EnableFallback: false
      FallBackConfigs: []
EOF
    done < "$NODE_DB"
}

add_node() {
    clear
    echo -e "${Blue}==============================${Font}"
    echo -e "${Blue} Xboard 新建后端节点${Font}"
    echo -e "${Blue}==============================${Font}"

    select_protocol

    read -p "请输入 Xboard 面板地址，例如 https://xxx.com: " PANEL_URL
    read -p "请输入 NodeID: " NODE_ID
    read -p "请输入 ApiKey: " API_KEY

    [ -z "$PANEL_URL" ] && echo -e "${Red}面板地址不能为空${Font}" && exit 1
    [ -z "$NODE_ID" ] && echo -e "${Red}NodeID 不能为空${Font}" && exit 1
    [ -z "$API_KEY" ] && echo -e "${Red}ApiKey 不能为空${Font}" && exit 1

    install_base
    install_v2bx

    mkdir -p "$DATA_DIR"
    touch "$NODE_DB"

    echo "${PROTOCOL}|${CORE}|${NODE_TYPE}|${PANEL_URL}|${NODE_ID}|${API_KEY}|${ENABLE_VLESS}" >> "$NODE_DB"

    render_config

    systemctl enable V2bX
    systemctl restart V2bX

    echo
    echo -e "${Green}节点添加完成！${Font}"
    echo -e "协议：${Yellow}${PROTOCOL}${Font}"
    echo -e "面板：${Yellow}${PANEL_URL}${Font}"
    echo -e "NodeID：${Yellow}${NODE_ID}${Font}"
    echo
}

list_nodes() {
    echo -e "${Blue}当前节点：${Font}"
    echo

    if [ ! -s "$NODE_DB" ]; then
        echo "暂无节点"
        return
    fi

    i=1
    while IFS='|' read -r PROTOCOL CORE NODE_TYPE PANEL_URL NODE_ID API_KEY ENABLE_VLESS; do
        echo "$i. $PROTOCOL | NodeID: $NODE_ID | Core: $CORE | Panel: $PANEL_URL"
        i=$((i+1))
    done < "$NODE_DB"
}

delete_node() {
    list_nodes
    echo
    read -p "请输入要删除的序号: " num

    [ -z "$num" ] && exit 1

    tmp="/tmp/xnode_nodes.tmp"
    awk -v n="$num" 'NR!=n' "$NODE_DB" > "$tmp"
    mv "$tmp" "$NODE_DB"

    render_config
    systemctl restart V2bX

    echo -e "${Green}删除完成${Font}"
}

status_node() {
    systemctl status V2bX --no-pager
}

logs_node() {
    journalctl -u V2bX -f --no-pager
}

restart_node() {
    systemctl restart V2bX
    echo -e "${Green}已重启${Font}"
}

edit_config() {
    nano "$CONFIG_FILE"
    systemctl restart V2bX
}

uninstall_all() {
    read -p "确认卸载全部节点和 V2bX？输入 y 确认: " c

    if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
        systemctl stop V2bX 2>/dev/null
        systemctl disable V2bX 2>/dev/null
        rm -rf "$V2BX_DIR"
        rm -rf "$DATA_DIR"
        rm -f /usr/local/bin/V2bX
        rm -f /etc/systemd/system/V2bX.service
        systemctl daemon-reload
        echo -e "${Green}卸载完成${Font}"
    fi
}

menu() {
    clear
    echo -e "${Blue}==============================${Font}"
    echo -e "${Blue} Xboard Node Manager v2.0${Font}"
    echo -e "${Blue}==============================${Font}"
    echo "1. 新建节点"
    echo "2. 查看节点"
    echo "3. 删除节点"
    echo "4. 查看状态"
    echo "5. 查看日志"
    echo "6. 重启节点"
    echo "7. 修改配置"
    echo "8. 卸载全部"
    echo "0. 退出"
    echo -e "${Blue}==============================${Font}"
    read -p "请选择: " num

    case "$num" in
        1) add_node ;;
        2) list_nodes ;;
        3) delete_node ;;
        4) status_node ;;
        5) logs_node ;;
        6) restart_node ;;
        7) edit_config ;;
        8) uninstall_all ;;
        0) exit 0 ;;
        *) echo -e "${Red}输入错误${Font}" ;;
    esac
}

check_root
menu
