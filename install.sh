#!/bin/bash
set -e

REPO="Ale8045/xboard-node-manager"
URL="https://raw.githubusercontent.com/${REPO}/main/xboard-node.sh"
PATH_FILE="/usr/local/bin/xboard-node"

apt update -y
apt install -y curl wget unzip tar nano lsof ca-certificates cron

curl -fsSL "$URL" -o "$PATH_FILE"
chmod +x "$PATH_FILE"
ln -sf "$PATH_FILE" /usr/bin/xnode

echo "安装完成，以后输入 xnode 打开菜单"
xnode
