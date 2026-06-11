#!/bin/bash
set -e

REPO="Ale8045/xboard-node-manager"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/main/xboard-node.sh"
INSTALL_PATH="/usr/local/bin/xboard-node"

apt update -y
apt install -y curl wget unzip tar cron lsof nano ca-certificates

curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

ln -sf "$INSTALL_PATH" /usr/bin/xnode

echo "安装完成！"
echo "以后输入 xnode 即可打开菜单"
xnode
