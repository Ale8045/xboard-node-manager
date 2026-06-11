#!/bin/bash

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"

XRAYR_DIR="/etc/XrayR"
XRAYR_BIN="/usr/local/bin/XrayR"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${Red}请使用 root 用户运行${Font}"
        exit 1
    fi
}

install_base() {
    apt update -y
    apt install -y curl wget unzip tar cron lsof socat ca-certificates
}

install_xrayr() {
    clear
    echo -e "${Blue}==============================${Font}"
    echo -e "${Blue} 安装 XrayR 对接 Xboard 节点${Font}"
    echo -e "${Blue}==============================${Font}"

    read -p "请输入 Xboard 面板地址，例如 https://xxx.com: " PANEL_URL
    read -p "请输入节点 ID: " NODE_ID
    read -p "请输入通讯密钥 ApiKey: " API_KEY

    echo
    echo "请选择节点类型："
    echo "1. V2ray"
    echo "2. Trojan"
    echo "3. Shadowsocks"
    read -p "请选择 [1-3]: " NODE_TYPE_ID

    case "$NODE_TYPE_ID" in
        1) NODE_TYPE="V2ray" ;;
        2) NODE_TYPE="Trojan" ;;
        3) NODE_TYPE="Shadowsocks" ;;
        *) echo -e "${Red}选择错误${Font}"; exit 1 ;;
    esac

    if [ -z "$PANEL_URL" ] || [ -z "$NODE_ID" ] || [ -z "$API_KEY" ]; then
        echo -e "${Red}参数不能为空${Font}"
        exit 1
    fi

    install_base

    echo -e "${Yellow}正在安装 XrayR...${Font}"
    bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)

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
      EnableVless: false
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
    echo -e "${Green}XrayR 节点安装完成！${Font}"
    echo -e "${Yellow}面板地址：${PANEL_URL}${Font}"
    echo -e "${Yellow}节点 ID：${NODE_ID}${Font}"
    echo -e "${Yellow}节点类型：${NODE_TYPE}${Font}"
    echo
}

status_xrayr() {
    systemctl status XrayR --no-pager
}

restart_xrayr() {
    systemctl restart XrayR
    echo -e "${Green}XrayR 已重启${Font}"
}

logs_xrayr() {
    journalctl -u XrayR -f --no-pager
}

edit_config() {
    nano "$XRAYR_DIR/config.yml"
    systemctl restart XrayR
}

uninstall_xrayr() {
    echo -e "${Red}确认卸载 XrayR？${Font}"
    read -p "输入 y 确认: " confirm

    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        systemctl stop XrayR 2>/dev/null
        systemctl disable XrayR 2>/dev/null
        rm -f /etc/systemd/system/XrayR.service
        rm -rf /etc/XrayR
        rm -f /usr/local/bin/XrayR
        systemctl daemon-reload
        echo -e "${Green}卸载完成${Font}"
    else
        echo -e "${Yellow}已取消${Font}"
    fi
}

show_config() {
    cat "$XRAYR_DIR/config.yml"
}

menu() {
    clear
    echo -e "${Blue}==============================${Font}"
    echo -e "${Blue} Xboard Node Manager v1.0${Font}"
    echo -e "${Blue}==============================${Font}"
    echo "1. 安装 XrayR 对接节点"
    echo "2. 查看节点状态"
    echo "3. 查看节点日志"
    echo "4. 重启节点"
    echo "5. 修改节点配置"
    echo "6. 查看当前配置"
    echo "7. 卸载 XrayR"
    echo "0. 退出"
    echo -e "${Blue}==============================${Font}"
    read -p "请选择: " num

    case "$num" in
        1) install_xrayr ;;
        2) status_xrayr ;;
        3) logs_xrayr ;;
        4) restart_xrayr ;;
        5) edit_config ;;
        6) show_config ;;
        7) uninstall_xrayr ;;
        0) exit 0 ;;
        *) echo -e "${Red}输入错误${Font}" ;;
    esac
}

check_root
menu
