#!/bin/bash

# 检查是否使用 bash 运行
if [ -z "$BASH_VERSION" ]; then
    echo "请使用 bash 运行此脚本"
    exit 1
fi

# 更新软件包列表并安装必要的包
echo "正在更新软件包列表..."
sudo apt-get update

echo "正在安装必要的包..."
sudo apt-get install -y python3 python3-pip

# 安装所需的 Python 模块
echo "正在安装所需的 Python 模块..."
pip3 install --user ovh requests

# 提示用户输入 BOT_TOKEN 和 CHAT_ID
read -p "请输入您的 Telegram BOT_TOKEN: " BOT_TOKEN
read -p "请输入您的 Telegram CHAT_ID: " CHAT_ID

# 提示用户输入 OVH API 凭据
read -p "请输入您的 OVH_ENDPOINT (默认: ovh-eu): " OVH_ENDPOINT
OVH_ENDPOINT=${OVH_ENDPOINT:-ovh-eu}

read -p "请输入您的 OVH_APPLICATION_KEY: " OVH_APPLICATION_KEY
read -s -p "请输入您的 OVH_APPLICATION_SECRET: " OVH_APPLICATION_SECRET
echo
read -p "请输入您的 OVH_CONSUMER_KEY: " OVH_CONSUMER_KEY

# 导出环境变量
export BOT_TOKEN
export CHAT_ID
export OVH_ENDPOINT
export OVH_APPLICATION_KEY
export OVH_APPLICATION_SECRET
export OVH_CONSUMER_KEY

# 运行您的 Python 脚本
echo "正在运行您的 Python 脚本..."
python3 ovh-ksa.py
