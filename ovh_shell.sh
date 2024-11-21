#!/bin/bash

# 检查是否使用 bash 运行
if [ -z "$BASH_VERSION" ]; then
    echo "请使用 bash 运行此脚本"
    exit 1
fi

# 检测包管理器
if [ -x "$(command -v apt-get)" ]; then
    PACKAGE_MANAGER="apt-get"
    UPDATE_CMD="sudo apt-get update"
    INSTALL_CMD="sudo apt-get install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v yum)" ]; then
    PACKAGE_MANAGER="yum"
    UPDATE_CMD="sudo yum makecache"
    INSTALL_CMD="sudo yum install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v dnf)" ]; then
    PACKAGE_MANAGER="dnf"
    UPDATE_CMD="sudo dnf makecache"
    INSTALL_CMD="sudo dnf install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v zypper)" ]; then
    PACKAGE_MANAGER="zypper"
    UPDATE_CMD="sudo zypper refresh"
    INSTALL_CMD="sudo zypper install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v pacman)" ]; then
    PACKAGE_MANAGER="pacman"
    UPDATE_CMD="sudo pacman -Sy"
    INSTALL_CMD="sudo pacman -S --noconfirm"
    PYTHON_PKG="python python-pip"
else
    echo "不支持的包管理器。请手动安装 Python 3 和 pip3。"
    exit 1
fi

# 更新软件包列表并安装必要的包
echo "正在更新软件包列表..."
$UPDATE_CMD

echo "正在安装必要的包..."
$INSTALL_CMD $PYTHON_PKG

# 检查 pip3 是否安装成功
if ! command -v pip3 &> /dev/null; then
    echo "pip3 未成功安装，尝试使用 pip。"
    if ! command -v pip &> /dev/null; then
        echo "pip 未安装，请检查您的包管理器和网络连接，或手动安装 pip。"
        exit 1
    else
        PIP_CMD="pip"
    fi
else
    PIP_CMD="pip3"
fi

# 安装所需的 Python 模块
echo "正在安装所需的 Python 模块..."
$PIP_CMD install --user ovh requests

# 将 ~/.local/bin 添加到 PATH，以确保可以找到安装在用户目录的模块
export PATH=$PATH:~/.local/bin

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