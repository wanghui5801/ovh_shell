#!/bin/bash

# Define colors
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
CYAN='\e[36m'
RESET='\e[0m'  # Reset color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Please run this script as root or using sudo.${RESET}"
    exit 1
fi

# Check if running with bash
if [ -z "$BASH_VERSION" ]; then
    echo -e "${RED}Please run this script with bash${RESET}"
    exit 1
fi

# Detect package manager
if [ -x "$(command -v apt-get)" ]; then
    PACKAGE_MANAGER="apt-get"
    UPDATE_CMD="apt-get update"
    INSTALL_CMD="apt-get install -y"
    PYTHON_PKG="python3 python3-pip python3-venv"
elif [ -x "$(command -v yum)" ]; then
    PACKAGE_MANAGER="yum"
    UPDATE_CMD="yum makecache"
    INSTALL_CMD="yum install -y"
    PYTHON_PKG="python3 python3-pip python3-virtualenv"
elif [ -x "$(command -v dnf)" ]; then
    PACKAGE_MANAGER="dnf"
    UPDATE_CMD="dnf makecache"
    INSTALL_CMD="dnf install -y"
    PYTHON_PKG="python3 python3-pip python3-virtualenv"
elif [ -x "$(command -v zypper)" ]; then
    PACKAGE_MANAGER="zypper"
    UPDATE_CMD="zypper refresh"
    INSTALL_CMD="zypper install -y"
    PYTHON_PKG="python3 python3-pip python3-virtualenv"
elif [ -x "$(command -v pacman)" ]; then
    PACKAGE_MANAGER="pacman"
    UPDATE_CMD="pacman -Sy"
    INSTALL_CMD="pacman -S --noconfirm"
    PYTHON_PKG="python python-pip python-virtualenv"
else
    echo -e "${RED}Unsupported package manager. Please manually install Python 3, pip and virtualenv.${RESET}"
    exit 1
fi

# Update package list and install required packages
echo -e "${CYAN}Updating package list...${RESET}"
$UPDATE_CMD

echo -e "${CYAN}Installing required packages...${RESET}"
$INSTALL_CMD $PYTHON_PKG

# Check if pip is installed successfully
if ! command -v pip3 &> /dev/null; then
    echo -e "${YELLOW}pip3 installation failed, trying pip.${RESET}"
    if ! command -v pip &> /dev/null; then
        echo -e "${RED}pip is not installed. Please check your package manager and network connection, or install pip manually.${RESET}"
        exit 1
    else
        PIP_CMD="pip"
    fi
else
    PIP_CMD="pip3"
fi

# Create and activate virtual environment
echo -e "${CYAN}Creating Python virtual environment...${RESET}"
python3 -m venv venv

source venv/bin/activate

# Upgrade pip (optional but recommended)
echo -e "${CYAN}Upgrading pip...${RESET}"
pip install --upgrade pip

# Install required Python modules
echo -e "${CYAN}Installing required Python modules...${RESET}"
pip install ovh requests

# Prompt user for credentials
echo -e "${GREEN}Please enter your Telegram and OVH API credentials:${RESET}"
echo -e "${YELLOW}----------------------------------------${RESET}"

read -p "$(echo -e ${MAGENTA}Please enter your Telegram BOT_TOKEN:${RESET} )" BOT_TOKEN </dev/tty
read -p "$(echo -e ${MAGENTA}Please enter your Telegram CHAT_ID:${RESET} )" CHAT_ID </dev/tty

read -p "$(echo -e ${MAGENTA}Please enter your OVH_ENDPOINT [default: ovh-eu]:${RESET} )" OVH_ENDPOINT </dev/tty
OVH_ENDPOINT=${OVH_ENDPOINT:-ovh-eu}

read -p "$(echo -e ${MAGENTA}Please enter your OVH_APPLICATION_KEY:${RESET} )" OVH_APPLICATION_KEY </dev/tty
read -p "$(echo -e ${MAGENTA}Please enter your OVH_APPLICATION_SECRET:${RESET} )" OVH_APPLICATION_SECRET </dev/tty
read -p "$(echo -e ${MAGENTA}Please enter your OVH_CONSUMER_KEY:${RESET} )" OVH_CONSUMER_KEY </dev/tty
echo -e "${YELLOW}----------------------------------------${RESET}"

# Export environment variables
export BOT_TOKEN
export CHAT_ID
export OVH_ENDPOINT
export OVH_APPLICATION_KEY
export OVH_APPLICATION_SECRET
export OVH_CONSUMER_KEY

# Check if required environment variables are set
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ -z "$OVH_APPLICATION_KEY" ] || [ -z "$OVH_APPLICATION_SECRET" ] || [ -z "$OVH_CONSUMER_KEY" ]; then
    echo -e "${RED}Error: All inputs are required. Please make sure to fill in everything.${RESET}"
    deactivate
    exit 1
fi

# Download Python script
echo -e "${CYAN}Downloading Python script...${RESET}"
curl -sSL https://raw.githubusercontent.com/wanghui5801/ovh_shell/main/ovh-ksa.py -o ovh-ksa.py

# Run your Python script
echo -e "${CYAN}Running your Python script...${RESET}"
python ovh-ksa.py

# Exit virtual environment
deactivate
