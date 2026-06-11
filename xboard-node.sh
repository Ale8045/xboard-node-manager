#!/bin/bash

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"

XRAYR_DIR="/etc/XrayR"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${Red}请使用 root 运行${Font}"
        exit 1
    fi
}

install_base() {
    apt update -y
    apt install -y curl wget unzip tar cron lsof nano ca-certificates
}

install_xrayr_core() {
    if ! command -v XrayR >/dev/null 2>&1; then
        echo -e "${Yellow}正在安装 XrayR...${Font}"
        bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)
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
        1) NODE_TYPE="V2ray"; ENABLE_VLESS="false" ;;
        2) NODE_TYPE="V2ray"; ENABLE_VLESS="true" ;;
        3) NODE_TYPE="Trojan"; ENABLE_VLESS="false" ;;
        4) NODE_TYPE="Shadowsocks"; ENABLE_VLESS="false" ;;
        5)
            echo -e "${Yellow}Hysteria2 后续需要 sing-box 版本，目前先不写入 XrayR。${Font}"
            exit 0
            ;;
        6)
            echo -e "${Yellow}AnyTLS 后续需要单独后端版本，目前先不写入 XrayR。${Font}"
            exit 0
            ;;
        *) echo -e "${Red}选择错误${Font}"; exit 1 ;;
    esac
}

install_node() {
    clear
    echo -e "${Blue}==============================${Font}"
    echo -e "${Blue} Xboard 后端节点安装${Font}"
    echo -e "${Blue}==============================${Font}"

    select_protocol

    read -p "请输入 Xboard 面板地址，例如 https://xxx.com: " PANEL_URL
    read -p "请输入 NodeID: " NODE_ID
    read -p "请输入 ApiKey: " API_KEY

    if [ -z "$PANEL_URL" ] || [ -z "$NODE_ID" ] || [ -z "$API_KEY" ]; then
        echo -e "${Red}参数不能为空${Font}"
        exit 1
    fi

    install_base
    install_xrayr_core

    mkdir -p "$XRAYR_DIR"

    cat > "$XRAYR_DIR/config.yml" <<EOF
Log:
  Level: warning
  AccessPath: ''
  ErrorPath: ''

DnsConfigPath: ''
RouteConfigPath: ''
InboundConfigPath: ''
OutboundConfigPath: ''

ConnetionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64

Nodes:
  - PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "$PANEL_URL"
      ApiKey: "$API_KEY"
      NodeID: $NODE_ID
      NodeType: $NODE_TYPE
      Timeout: 30
      EnableVless: $ENABLE_VLESS
      EnableXTLS: false
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath: ''
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      DNSType: AsIs
      DisableUploadTraffic: false
      DisableGetRule: false
      DisableIVCheck: false
      EnableProxyProtocol: false
      AutoSpeedLimitConfig:
        Limit: 0
        WarnTimes: 0
        LimitSpeed: 0
        LimitDuration: 0
      GlobalDeviceLimitConfig:
        Enable: false
        RedisAddr: 127.0.0.1:6379
        RedisPassword: ''
        RedisDB: 0
        Timeout: 5
        Expiry: 60
      EnableFallback: false
      FallBackConfigs: []
EOF

    systemctl enable XrayR
    systemctl restart XrayR

    echo
    echo -e "${Green}节点安装完成！${Font}"
    echo -e "协议：${Yellow}${NODE_TYPE}${Font}"
    echo -e "面板：${Yellow}${PANEL_URL}${Font}"
    echo -e "NodeID：${Yellow}${NODE_ID}${Font}"
    echo
    echo "可输入 xnode 查看菜单"
}

status_node() {
    systemctl status XrayR --no-pager
}

logs_node() {
    journalctl -u XrayR -f --no-pager
}

restart_node() {
    systemctl restart XrayR
    echo -e "${Green}节点已重启${Font}"
}

edit_config() {
    nano "$XRAYR_DIR/config.yml"
    systemctl restart XrayR
    echo -e "${Green}配置已保存并重启${Font}"
}

show_config() {
    cat "$XRAYR_DIR/config.yml"
}

uninstall_node() {
    read -p "确认卸载 XrayR？输入 y 确认: " c
    if [ "$c" = "y" ] || [ "$c" = "Y" ]; then
        systemctl stop XrayR 2>/dev/null
        systemctl disable XrayR 2>/dev/null
        rm -rf /etc/XrayR
        rm -f /usr/local/bin/XrayR
        rm -f /etc/systemd/system/XrayR.service
        systemctl daemon-reload
        echo -e "${Green}卸载完成${Font}"
    fi
}

menu() {
    clear
    echo -e "${Blue}==============================${Font}"
    echo -e "${Blue} Xboard Node Manager v1.0${Font}"
    echo -e "${Blue}==============================${Font}"
    echo "1. 新建节点"
    echo "2. 查看状态"
    echo "3. 查看日志"
    echo "4. 重启节点"
    echo "5. 修改配置"
    echo "6. 查看配置"
    echo "7. 卸载节点"
    echo "0. 退出"
    echo -e "${Blue}==============================${Font}"
    read -p "请选择: " num

    case "$num" in
        1) install_node ;;
        2) status_node ;;
        3) logs_node ;;
        4) restart_node ;;
        5) edit_config ;;
        6) show_config ;;
        7) uninstall_node ;;
        0) exit 0 ;;
        *) echo -e "${Red}输入错误${Font}" ;;
    esac
}

check_root
menu
