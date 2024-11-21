#!/bin/bash

# 定义颜色
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
CYAN='\e[36m'
RESET='\e[0m'  # 重置颜色

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}请以 root 用户或使用 sudo 运行此脚本。${RESET}"
    exit 1
fi

# 检查是否使用 bash 运行
if [ -z "$BASH_VERSION" ]; then
    echo -e "${RED}请使用 bash 运行此脚本${RESET}"
    exit 1
fi

# 检测包管理器
if [ -x "$(command -v apt-get)" ]; then
    PACKAGE_MANAGER="apt-get"
    UPDATE_CMD="apt-get update"
    INSTALL_CMD="apt-get install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v yum)" ]; then
    PACKAGE_MANAGER="yum"
    UPDATE_CMD="yum makecache"
    INSTALL_CMD="yum install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v dnf)" ]; then
    PACKAGE_MANAGER="dnf"
    UPDATE_CMD="dnf makecache"
    INSTALL_CMD="dnf install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v zypper)" ]; then
    PACKAGE_MANAGER="zypper"
    UPDATE_CMD="zypper refresh"
    INSTALL_CMD="zypper install -y"
    PYTHON_PKG="python3 python3-pip"
elif [ -x "$(command -v pacman)" ]; then
    PACKAGE_MANAGER="pacman"
    UPDATE_CMD="pacman -Sy"
    INSTALL_CMD="pacman -S --noconfirm"
    PYTHON_PKG="python python-pip"
else
    echo -e "${RED}不支持的包管理器。请手动安装 Python 3 和 pip。${RESET}"
    exit 1
fi

# 更新软件包列表并安装必要的包
echo -e "${CYAN}正在更新软件包列表...${RESET}"
$UPDATE_CMD

echo -e "${CYAN}正在安装必要的包...${RESET}"
$INSTALL_CMD $PYTHON_PKG

# 检查 pip 是否安装成功
if ! command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}pip3 未成功安装，尝试使用 pip。${RESET}"
    if ! command -v pip &> /dev/null; then
        echo -e "${RED}pip 未安装，请检查您的包管理器和网络连接，或手动安装 pip。${RESET}"
        exit 1
    else
        PIP_CMD="pip"
    fi
else
    PIP_CMD="pip3"
fi

# 安装所需的 Python 模块
echo -e "${CYAN}正在安装所需的 Python 模块...${RESET}"
$PIP_CMD install ovh requests

# 提示用户输入凭据
echo -e "${GREEN}请按照提示输入您的 Telegram 和 OVH API 凭据：${RESET}"
echo -e "${YELLOW}----------------------------------------${RESET}"
read -p "$(echo -e ${MAGENTA}请输入您的 Telegram BOT_TOKEN:${RESET} )" BOT_TOKEN
read -p "$(echo -e ${MAGENTA}请输入您的 Telegram CHAT_ID:${RESET} )" CHAT_ID

read -p "$(echo -e ${MAGENTA}请输入您的 OVH_ENDPOINT [默认: ovh-eu]:${RESET} )" OVH_ENDPOINT
OVH_ENDPOINT=${OVH_ENDPOINT:-ovh-eu}

read -p "$(echo -e ${MAGENTA}请输入您的 OVH_APPLICATION_KEY:${RESET} )" OVH_APPLICATION_KEY
read -s -p "$(echo -e ${MAGENTA}请输入您的 OVH_APPLICATION_SECRET:${RESET} )" OVH_APPLICATION_SECRET
echo
read -p "$(echo -e ${MAGENTA}请输入您的 OVH_CONSUMER_KEY:${RESET} )" OVH_CONSUMER_KEY
echo -e "${YELLOW}----------------------------------------${RESET}"

# 导出环境变量
export BOT_TOKEN
export CHAT_ID
export OVH_ENDPOINT
export OVH_APPLICATION_KEY
export OVH_APPLICATION_SECRET
export OVH_CONSUMER_KEY

# 检查必要的环境变量是否已设置
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ -z "$OVH_APPLICATION_KEY" ] || [ -z "$OVH_APPLICATION_SECRET" ] || [ -z "$OVH_CONSUMER_KEY" ]; then
    echo -e "${RED}错误：所有输入都是必填项，请确保填写完整。${RESET}"
    exit 1
fi

# 下载 Python 脚本
echo -e "${CYAN}正在下载 Python 脚本...${RESET}"
curl -sSL https://raw.githubusercontent.com/wanghui5801/ovh_shell/main/ovh-ksa.py -o ovh-ksa.py

# 运行您的 Python 脚本
echo -e "${CYAN}正在运行您的 Python 脚本...${RESET}"
python3 ovh-ksa.py