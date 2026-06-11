#!/bin/bash

set -e

SCRIPT_URL="https://raw.githubusercontent.com/Ale8045/xboard-node-manager/main/xboard-node.sh"
INSTALL_PATH="/usr/local/bin/xboard-node"

echo "正在安装 Xboard Node Manager..."

apt update -y
apt install -y curl wget unzip socat cron tar

curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

ln -sf "$INSTALL_PATH" /usr/bin/xnode

echo
echo "安装完成！"
echo "启动命令：xnode"
echo

xnode
