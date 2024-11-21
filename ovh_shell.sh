#!/bin/bash

# 错误处理
set -e  # 遇到错误立即退出
trap 'echo "发生错误，脚本退出"; exit 1' ERR

# 设置颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 打印带颜色的信息函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 在文件开头添加日志目录设置
LOG_DIR="logs"
PYTHON_LOG="$LOG_DIR/python_output.log"
SCRIPT_LOG="$LOG_DIR/script_output.log"

# 清理函数
cleanup() {
    print_info "执行清理操作..."
    if [ -f "monitor.pid" ]; then
        local pid=$(cat monitor.pid)
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid
            print_success "已终止监控进程 (PID: $pid)"
        fi
        rm monitor.pid
    fi
    rm -f ovh-ksa_temp.py
    
    # 压缩旧日志文件
    if [ -f "$PYTHON_LOG" ]; then
        gzip -f "$PYTHON_LOG"
        mv "$PYTHON_LOG.gz" "$LOG_DIR/python_output_$(date +%Y%m%d_%H%M%S).log.gz"
    fi
}
trap cleanup EXIT

# 验证输入参数
validate_input() {
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ -z "$ENDPOINT" ] || \
       [ -z "$APP_KEY" ] || [ -z "$APP_SECRET" ] || [ -z "$CONSUMER_KEY" ]; then
        print_error "错误：所有参数都必须填写"
        exit 1
    fi

    # 验证 Telegram Bot Token 格式
    if [[ ! $BOT_TOKEN =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
        print_error "错误：Telegram Bot Token 格式不正确"
        exit 1
    fi

    # 验证 Chat ID 格式
    if [[ ! $CHAT_ID =~ ^-?[0-9]+$ ]]; then
        print_error "错误：Telegram Chat ID 格式不正确"
        exit 1
    fi

    # 验证 endpoint
    if [[ ! $ENDPOINT =~ ^(ovh-eu|ovh-us|ovh-ca)$ ]]; then
        print_error "错误：endpoint 必须是 ovh-eu, ovh-us 或 ovh-ca 之一"
        exit 1
    fi
}

# 检查必要的软件
check_requirements() {
    print_info "检查必要的软件..."
    
    local packages_to_install=()
    
    # 检查 git
    if ! command -v git &> /dev/null; then
        packages_to_install+=("git")
    fi

    # 检查 Python3
    if ! command -v python3 &> /dev/null; then
        packages_to_install+=("python3" "python3-pip")
    fi

    # 如果有需要安装的包
    if [ ${#packages_to_install[@]} -ne 0 ]; then
        print_info "正在安装必要的软件包: ${packages_to_install[*]}"
        sudo apt-get update
        sudo apt-get install -y "${packages_to_install[@]}"
    fi

    # 检查并安装 Python 依赖
    print_info "安装 Python 依赖..."
    pip3 install --upgrade pip
    pip3 install ovh requests
}

# 克隆或更新仓库
setup_repository() {
    local repo_url="https://github.com/wanghui5801/ovh_shell.git"
    if [ -d "ovh_shell" ]; then
        print_info "更新仓库..."
        cd ovh_shell
        git fetch
        local changes=$(git rev-list HEAD...origin/main --count)
        if [ "$changes" -gt 0 ]; then
            git pull
            print_success "仓库已更新到最新版本"
        else
            print_info "仓库已是最新版本"
        fi
    else
        print_info "克隆仓库..."
        git clone "$repo_url"
        cd ovh_shell
        print_success "仓库克隆完成"
    fi
}

# 配置 Python 脚本
configure_python_script() {
    print_info "配置 Python 脚本..."
    if [ ! -f "ovh-ksa.py" ]; then
        print_error "错误：源 Python 脚本不存在"
        exit 1
    fi

    sed -e "s/BOT_TOKEN = \"\"/BOT_TOKEN = \"$BOT_TOKEN\"/" \
        -e "s/CHAT_ID = \"\"/CHAT_ID = \"$CHAT_ID\"/" \
        -e "s/endpoint=''/endpoint='$ENDPOINT'/" \
        -e "s/application_key=''/application_key='$APP_KEY'/" \
        -e "s/application_secret=''/application_secret='$APP_SECRET'/" \
        -e "s/consumer_key=''/consumer_key='$CONSUMER_KEY'/" \
        ovh-ksa.py > ovh-ksa_temp.py

    if [ ! -f "ovh-ksa_temp.py" ]; then
        print_error "错误：配置文件生成失败"
        exit 1
    fi

    print_success "Python 脚本配置完成"
}

# 添加日志初始化函数
init_logging() {
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    # 创建新的日志文件
    touch "$PYTHON_LOG"
    touch "$SCRIPT_LOG"
    
    # 设置日志文件权限
    chmod 644 "$PYTHON_LOG" "$SCRIPT_LOG"
    
    print_info "日志文件已初始化"
}

# 启动监控脚本
start_monitor() {
    print_success "配置完成，开始运行监控脚本..."
    
    # 检查是否已有实例在运行
    if [ -f "monitor.pid" ]; then
        local old_pid=$(cat monitor.pid)
        if ps -p $old_pid > /dev/null 2>&1; then
            print_error "监控脚本已在运行中 (PID: $old_pid)"
            exit 1
        else
            rm monitor.pid
        fi
    fi

    # 运行脚本，同时输出到控制台和日志文件
    nohup python3 ovh-ksa_temp.py > >(tee -a "$PYTHON_LOG") 2>&1 &
    
    # 保存进程ID并验证进程是否成功启动
    local PID=$!
    sleep 2  # 等待进程启动
    
    if ps -p $PID > /dev/null; then
        echo $PID > monitor.pid
        print_success "监控脚本已在后台启动，进程ID: $PID"
        print_info "查看Python输出: tail -f $PYTHON_LOG"
        print_info "查看脚本日志: tail -f $SCRIPT_LOG"
        print_info "停止脚本请使用选项 2"
    else
        print_error "错误：脚本启动失败"
        exit 1
    fi
}

# 停止监控脚本
stop_monitor() {
    if [ -f "monitor.pid" ]; then
        local pid=$(cat monitor.pid)
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid
            rm monitor.pid
            print_success "监控脚本已停止 (PID: $pid)"
        else
            print_info "监控脚本未在运行"
            rm monitor.pid
        fi
    else
        print_info "没有找到运行中的监控脚本"
    fi
}

# 显示菜单
show_menu() {
    while true; do
        echo
        print_info "请选择操作："
        echo "1. 运行监控脚本"
        echo "2. 停止监控脚本"
        echo "3. 查看Python输出"
        echo "4. 查看历史日志"
        echo "5. 退出"
        echo
        read -p "请输入选项 (1-5): " choice

        case $choice in
            1)
                if [ -f "monitor.pid" ] && ps -p $(cat monitor.pid) > /dev/null 2>&1; then
                    print_error "监控脚本已在运行中"
                else
                    setup_script
                fi
                ;;
            2)
                stop_monitor
                ;;
            3)
                if [ -f "$PYTHON_LOG" ]; then
                    less "$PYTHON_LOG"
                else
                    print_error "Python日志文件不存在"
                fi
                ;;
            4)
                echo "可用的日志文件："
                ls -lh "$LOG_DIR"/*.log* 2>/dev/null || echo "没有找到日志文件"
                echo
                read -p "请输入要查看的日志文件名（直接回车返回）: " log_file
                if [ ! -z "$log_file" ]; then
                    if [ -f "$LOG_DIR/$log_file" ]; then
                        less "$LOG_DIR/$log_file"
                    else
                        print_error "文件不存在"
                    fi
                fi
                ;;
            5)
                print_info "退出程序"
                exit 0
                ;;
            *)
                print_error "无效的选项，请重新选择"
                ;;
        esac
    done
}

# 设置和运行脚本
setup_script() {
    print_info "开始设置环境..."
    
    # 检查依赖
    check_requirements
    
    # 设置仓库
    setup_repository
    
    # 确保脚本有执行权限
    chmod +x ovh_shell.sh
    
    # 获取用户输入
    print_info "请输入必要的参数："
    read -p "请输入 Telegram Bot Token: " BOT_TOKEN
    read -p "请输入 Telegram Chat ID: " CHAT_ID
    read -p "请输入 OVH endpoint (ovh-eu/ovh-us/ovh-ca): " ENDPOINT
    read -p "请输入 OVH Application Key: " APP_KEY
    read -p "请输入 OVH Application Secret: " APP_SECRET
    read -p "请输入 OVH Consumer Key: " CONSUMER_KEY
    
    # 验证输入
    validate_input
    
    # 配置 Python 脚本
    configure_python_script
    
    # 启动监控
    start_monitor
}

# 主函数
main() {
    # 初始化日志
    init_logging
    
    # 记录脚本启动时间
    print_info "脚本启动于 $(date)" >> "$SCRIPT_LOG"
    
    # 显示菜单
    show_menu
}

# 运行主函数，同时记录输出
main "$@" 2>&1 | tee -a "$SCRIPT_LOG"
