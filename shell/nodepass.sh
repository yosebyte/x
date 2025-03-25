#!/usr/bin/env bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Base variables
NODEPASS_PATH="/usr/local/bin/nodepass"
SERVICE_PATH="/etc/systemd/system/nodepass.service"
CONFIG_PATH="/etc/nodepass/config"

# Required dependencies
DEPENDENCIES=("curl" "tar" "grep" "sed")

# Display the logo
show_logo() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
 ███╗   ██╗ ██████╗ ██████╗ ███████╗██████╗  █████╗ ███████╗███████╗
 ████╗  ██║██╔═══██╗██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝
 ██╔██╗ ██║██║   ██║██║  ██║█████╗  ██████╔╝███████║███████╗███████╗
 ██║╚██╗██║██║   ██║██║  ██║██╔══╝  ██╔═══╝ ██╔══██║╚════██║╚════██║
 ██║ ╚████║╚██████╔╝██████╔╝███████╗██║     ██║  ██║███████║███████║
 ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}Efficient TCP/UDP Tunneling Solution${NC}"
    echo -e "${YELLOW}Version: $(get_version_info) | Author: Yosebyte${NC}"
    echo -e "${GREEN}https://github.com/yosebyte/nodepass${NC}"
    echo
}

# Check for dependencies
check_dependencies() {
    local missing_deps=()
    
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}${MSG_MISSING_DEPENDENCIES}${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - ${RED}$dep${NC}"
        done
        
        echo
        echo -e "${CYAN}${MSG_INSTALL_DEPENDENCIES_PROMPT}${NC}"
        echo -e "1. ${GREEN}${MSG_INSTALL_DEPENDENCIES_YES}${NC}"
        echo -e "2. ${GREEN}${MSG_INSTALL_DEPENDENCIES_NO}${NC}"
        read -p "$(echo -e ${YELLOW}"Option [1/2]: "${NC})" install_deps_option
        
        case $install_deps_option in
            1)
                install_dependencies "${missing_deps[@]}"
                ;;
            2|*)
                echo -e "${RED}${MSG_DEPENDENCIES_REQUIRED}${NC}"
                exit 1
                ;;
        esac
    fi
}

# Install dependencies
install_dependencies() {
    local deps=("$@")
    echo -e "${CYAN}${MSG_INSTALLING_DEPENDENCIES}${NC}"
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y "${deps[@]}"
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL/CentOS
        dnf install -y "${deps[@]}"
    elif command -v yum &> /dev/null; then
        # Older RHEL/CentOS
        yum install -y "${deps[@]}"
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        pacman -Sy --noconfirm "${deps[@]}"
    elif command -v zypper &> /dev/null; then
        # openSUSE
        zypper install -y "${deps[@]}"
    elif command -v apk &> /dev/null; then
        # Alpine Linux
        apk add --no-cache "${deps[@]}"
    else
        echo -e "${RED}${MSG_PACKAGE_MANAGER_NOT_FOUND}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}${MSG_DEPENDENCIES_INSTALLED}${NC}"
}

# Get version info (for logo display)
get_version_info() {
    if [ -f "$NODEPASS_PATH" ]; then
        if [ -f "$CONFIG_PATH" ]; then
            source $CONFIG_PATH
            echo "$VERSION"
        else
            echo "Unknown"
        fi
    else
        echo "Not Installed"
    fi
}

# Language Selection
select_language() {
    echo -e "${CYAN}请选择语言 / Please select language:${NC}"
    echo -e "1. ${GREEN}中文${NC}"
    echo -e "2. ${GREEN}English${NC}"
    read -p "$(echo -e ${YELLOW}"请输入选项 / Please enter option [1/2]: "${NC})" lang_option

    case $lang_option in
        1)
            LANG="zh"
            echo -e "${GREEN}已选择中文${NC}\n"
            ;;
        2|*)
            LANG="en"
            echo -e "${GREEN}English selected${NC}\n"
            ;;
    esac
}

# Messages
load_messages() {
    if [ "$LANG" == "zh" ]; then
        MSG_WELCOME="欢迎使用 NodePass 管理脚本！"
        MSG_ROOT="需要 root 权限来完成操作。"
        MSG_CHECKING_ARCH="检测系统架构..."
        MSG_ARCH_DETECTED="检测到系统架构："
        MSG_ARCH_UNSUPPORTED="不支持的系统架构！NodePass 仅支持 amd64 和 arm64 架构。"
        MSG_CHECKING_VERSION="获取最新版本..."
        MSG_VERSION_DETECTED="检测到最新版本："
        MSG_VERSION_ERROR="无法获取最新版本，请检查网络连接。"
        MSG_MIRROR="是否使用 GitHub 镜像？(中国大陆用户推荐使用)"
        MSG_MIRROR_YES="是，使用镜像"
        MSG_MIRROR_NO="否，使用 GitHub 原站"
        MSG_SELECT_MODE="请选择安装模式："
        MSG_MODE_CLIENT="客户端模式"
        MSG_MODE_SERVER="服务器模式"
        MSG_INPUT_TUNNEL="请输入隧道地址 (例如: 10.1.0.1:10101)："
        MSG_INPUT_TARGET="请输入目标地址 (例如: 127.0.0.1:8080)："
        MSG_DEBUG_MODE="是否启用调试模式？"
        MSG_DEBUG_YES="是，启用调试模式"
        MSG_DEBUG_NO="否，使用默认日志级别"
        MSG_DOWNLOADING="正在下载 NodePass..."
        MSG_DOWNLOAD_SUCCESS="下载成功！"
        MSG_DOWNLOAD_ERROR="下载失败，请检查网络连接或尝试使用镜像。"
        MSG_INSTALLING="正在安装 NodePass..."
        MSG_INSTALL_SUCCESS="安装成功！"
        MSG_SYSTEMD="是否设置为系统服务(使用 systemd)？"
        MSG_SYSTEMD_YES="是，设置为系统服务"
        MSG_SYSTEMD_NO="否，仅安装可执行文件"
        MSG_SYSTEMD_SETUP="设置 systemd 服务..."
        MSG_SYSTEMD_SUCCESS="systemd 服务设置成功！"
        MSG_SYSTEMD_ERROR="设置 systemd 失败，请检查系统是否支持 systemd。"
        MSG_SYSTEMD_NOT_FOUND="未检测到 systemd，将仅安装可执行文件。"
        MSG_COMPLETE="安装完成！"
        MSG_USAGE="使用方法："
        MSG_CLIENT_USAGE="客户端模式："
        MSG_SERVER_USAGE="服务器模式："
        MSG_SERVICE_USAGE="systemd 服务管理："
        MSG_START_SERVICE="启动服务..."
        MSG_STOP_SERVICE="停止服务..."
        MSG_RESTART_SERVICE="重启服务..."
        MSG_SERVICE_STARTED="服务已启动。"
        MSG_SERVICE_STOPPED="服务已停止。"
        MSG_SERVICE_RESTARTED="服务已重启。"
        MSG_UNINSTALL="卸载 NodePass..."
        MSG_UNINSTALL_SUCCESS="卸载成功！"
        MSG_UPDATE="更新 NodePass..."
        MSG_UPDATE_CHECK="检查更新..."
        MSG_UPDATE_AVAILABLE="发现新版本："
        MSG_UPDATE_LATEST="已是最新版本。"
        MSG_UPDATE_SUCCESS="更新成功！"
        MSG_UPDATE_ERROR="更新失败！"
        MSG_NOT_INSTALLED="NodePass 未安装，请先安装。"
        MSG_MAIN_MENU="NodePass 管理菜单"
        MSG_MENU_INSTALL="安装 NodePass"
        MSG_MENU_START="启动 NodePass 服务"
        MSG_MENU_STOP="停止 NodePass 服务"
        MSG_MENU_RESTART="重启 NodePass 服务"
        MSG_MENU_UPDATE="更新 NodePass"
        MSG_MENU_UNINSTALL="卸载 NodePass"
        MSG_MENU_EXIT="退出脚本"
        MSG_MENU_CHOICE="请选择操作："
        MSG_PRESS_ENTER="按回车键继续..."
        MSG_INVALID_CHOICE="无效选择，请重试。"
        MSG_EXIT="感谢使用 NodePass 管理脚本！"
        MSG_MISSING_DEPENDENCIES="缺少必需的依赖项："
        MSG_INSTALL_DEPENDENCIES_PROMPT="是否安装缺少的依赖项？"
        MSG_INSTALL_DEPENDENCIES_YES="是，安装依赖项"
        MSG_INSTALL_DEPENDENCIES_NO="否，退出脚本"
        MSG_DEPENDENCIES_REQUIRED="依赖项是必需的，无法继续安装。"
        MSG_INSTALLING_DEPENDENCIES="正在安装依赖项..."
        MSG_DEPENDENCIES_INSTALLED="依赖项安装成功！"
        MSG_PACKAGE_MANAGER_NOT_FOUND="无法确定包管理器，请手动安装依赖项。"
    else
        MSG_WELCOME="Welcome to NodePass Management Script!"
        MSG_ROOT="Root privileges are required to complete this operation."
        MSG_CHECKING_ARCH="Detecting system architecture..."
        MSG_ARCH_DETECTED="System architecture detected:"
        MSG_ARCH_UNSUPPORTED="Unsupported architecture! NodePass only supports amd64 and arm64 architectures."
        MSG_CHECKING_VERSION="Getting latest version..."
        MSG_VERSION_DETECTED="Latest version detected:"
        MSG_VERSION_ERROR="Unable to get latest version, please check your network connection."
        MSG_MIRROR="Use GitHub mirror? (Recommended for users in mainland China)"
        MSG_MIRROR_YES="Yes, use mirror"
        MSG_MIRROR_NO="No, use GitHub directly"
        MSG_SELECT_MODE="Please select installation mode:"
        MSG_MODE_CLIENT="Client mode"
        MSG_MODE_SERVER="Server mode"
        MSG_INPUT_TUNNEL="Please enter tunnel address (e.g., 10.1.0.1:10101):"
        MSG_INPUT_TARGET="Please enter target address (e.g., 127.0.0.1:8080):"
        MSG_DEBUG_MODE="Enable debug mode?"
        MSG_DEBUG_YES="Yes, enable debug mode"
        MSG_DEBUG_NO="No, use default log level"
        MSG_DOWNLOADING="Downloading NodePass..."
        MSG_DOWNLOAD_SUCCESS="Download successful!"
        MSG_DOWNLOAD_ERROR="Download failed, please check your network connection or try using mirror."
        MSG_INSTALLING="Installing NodePass..."
        MSG_INSTALL_SUCCESS="Installation successful!"
        MSG_SYSTEMD="Set up as system service (using systemd)?"
        MSG_SYSTEMD_YES="Yes, setup as system service"
        MSG_SYSTEMD_NO="No, just install executable"
        MSG_SYSTEMD_SETUP="Setting up systemd service..."
        MSG_SYSTEMD_SUCCESS="systemd service setup successful!"
        MSG_SYSTEMD_ERROR="Failed to setup systemd, please check if your system supports systemd."
        MSG_SYSTEMD_NOT_FOUND="systemd not detected, will only install executable."
        MSG_COMPLETE="Installation complete!"
        MSG_USAGE="Usage:"
        MSG_CLIENT_USAGE="Client mode:"
        MSG_SERVER_USAGE="Server mode:"
        MSG_SERVICE_USAGE="systemd service management:"
        MSG_START_SERVICE="Starting service..."
        MSG_STOP_SERVICE="Stopping service..."
        MSG_RESTART_SERVICE="Restarting service..."
        MSG_SERVICE_STARTED="Service started."
        MSG_SERVICE_STOPPED="Service stopped."
        MSG_SERVICE_RESTARTED="Service restarted."
        MSG_UNINSTALL="Uninstalling NodePass..."
        MSG_UNINSTALL_SUCCESS="Uninstallation successful!"
        MSG_UPDATE="Updating NodePass..."
        MSG_UPDATE_CHECK="Checking for updates..."
        MSG_UPDATE_AVAILABLE="New version available:"
        MSG_UPDATE_LATEST="Already at the latest version."
        MSG_UPDATE_SUCCESS="Update successful!"
        MSG_UPDATE_ERROR="Update failed!"
        MSG_NOT_INSTALLED="NodePass is not installed. Please install first."
        MSG_MAIN_MENU="NodePass Management Menu"
        MSG_MENU_INSTALL="Install NodePass"
        MSG_MENU_START="Start NodePass Service"
        MSG_MENU_STOP="Stop NodePass Service"
        MSG_MENU_RESTART="Restart NodePass Service"
        MSG_MENU_UPDATE="Update NodePass"
        MSG_MENU_UNINSTALL="Uninstall NodePass"
        MSG_MENU_EXIT="Exit Script"
        MSG_MENU_CHOICE="Please select an operation:"
        MSG_PRESS_ENTER="Press Enter to continue..."
        MSG_INVALID_CHOICE="Invalid choice, please try again."
        MSG_EXIT="Thank you for using the NodePass Management Script!"
        MSG_MISSING_DEPENDENCIES="Missing required dependencies:"
        MSG_INSTALL_DEPENDENCIES_PROMPT="Install missing dependencies?"
        MSG_INSTALL_DEPENDENCIES_YES="Yes, install dependencies"
        MSG_INSTALL_DEPENDENCIES_NO="No, exit script"
        MSG_DEPENDENCIES_REQUIRED="Dependencies are required, cannot continue."
        MSG_INSTALLING_DEPENDENCIES="Installing dependencies..."
        MSG_DEPENDENCIES_INSTALLED="Dependencies installed successfully!"
        MSG_PACKAGE_MANAGER_NOT_FOUND="Unable to determine package manager, please install dependencies manually."
    fi
}

# Check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}${MSG_ROOT}${NC}"
        exit 1
    fi
}

# Detect architecture
detect_arch() {
    echo -e "${CYAN}${MSG_CHECKING_ARCH}${NC}"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            echo -e "${RED}${MSG_ARCH_UNSUPPORTED}${NC}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}${MSG_ARCH_DETECTED} ${ARCH}${NC}"
}

# Get latest version
get_latest_version() {
    echo -e "${CYAN}${MSG_CHECKING_VERSION}${NC}"
    VERSION=$(curl -s https://api.github.com/repos/yosebyte/nodepass/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$VERSION" ]; then
        echo -e "${RED}${MSG_VERSION_ERROR}${NC}"
        VERSION="v1.0.2" # Fallback to a known version
    fi
    
    echo -e "${GREEN}${MSG_VERSION_DETECTED} ${VERSION}${NC}"
}

# Ask user whether to use mirror
ask_mirror() {
    echo -e "${CYAN}${MSG_MIRROR}${NC}"
    echo -e "1. ${GREEN}${MSG_MIRROR_YES}${NC}"
    echo -e "2. ${GREEN}${MSG_MIRROR_NO}${NC}"
    read -p "$(echo -e ${YELLOW}"Option [1/2]: "${NC})" mirror_option
    
    case $mirror_option in
        1)
            USE_MIRROR=true
            MIRROR_URL="https://gh-proxy.com/"
            ;;
        2|*)
            USE_MIRROR=false
            MIRROR_URL=""
            ;;
    esac
}

# Ask for installation mode
ask_mode() {
    echo -e "${CYAN}${MSG_SELECT_MODE}${NC}"
    echo -e "1. ${GREEN}${MSG_MODE_CLIENT}${NC}"
    echo -e "2. ${GREEN}${MSG_MODE_SERVER}${NC}"
    read -p "$(echo -e ${YELLOW}"Option [1/2]: "${NC})" mode_option
    
    case $mode_option in
        1)
            MODE="client"
            ;;
        2|*)
            MODE="server"
            ;;
    esac
}

# Ask for debug mode
ask_debug() {
    echo -e "${CYAN}${MSG_DEBUG_MODE}${NC}"
    echo -e "1. ${GREEN}${MSG_DEBUG_YES}${NC}"
    echo -e "2. ${GREEN}${MSG_DEBUG_NO}${NC}"
    read -p "$(echo -e ${YELLOW}"Option [1/2]: "${NC})" debug_option
    
    case $debug_option in
        1)
            DEBUG_MODE=true
            DEBUG_PARAM="?log=debug"
            ;;
        2|*)
            DEBUG_MODE=false
            DEBUG_PARAM=""
            ;;
    esac
}

# Ask for tunnel and target addresses
ask_addresses() {
    read -p "$(echo -e ${YELLOW}${MSG_INPUT_TUNNEL}" "${NC})" TUNNEL_ADDR
    read -p "$(echo -e ${YELLOW}${MSG_INPUT_TARGET}" "${NC})" TARGET_ADDR
}

# Save configuration
save_config() {
    mkdir -p $(dirname $CONFIG_PATH)
    cat > $CONFIG_PATH << EOF
MODE="${MODE}"
TUNNEL_ADDR="${TUNNEL_ADDR}"
TARGET_ADDR="${TARGET_ADDR}"
DEBUG_MODE=${DEBUG_MODE}
DEBUG_PARAM="${DEBUG_PARAM}"
VERSION="${VERSION}"
USE_MIRROR=${USE_MIRROR}
MIRROR_URL="${MIRROR_URL}"
EOF
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_PATH" ]; then
        source $CONFIG_PATH
        return 0
    else
        return 1
    fi
}

# Download and install
download_and_install() {
    echo -e "${CYAN}${MSG_DOWNLOADING}${NC}"
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd $TMP_DIR
    
    # Formulate download URL
    FILENAME="nodepass_${VERSION#v}_linux_${ARCH}.tar.gz"
    if [ "$USE_MIRROR" = true ]; then
        DOWNLOAD_URL="${MIRROR_URL}https://github.com/yosebyte/nodepass/releases/download/${VERSION}/${FILENAME}"
    else
        DOWNLOAD_URL="https://github.com/yosebyte/nodepass/releases/download/${VERSION}/${FILENAME}"
    fi
    
    # Download the file
    if curl -L -o "${FILENAME}" "${DOWNLOAD_URL}"; then
        echo -e "${GREEN}${MSG_DOWNLOAD_SUCCESS}${NC}"
    else
        echo -e "${RED}${MSG_DOWNLOAD_ERROR}${NC}"
        exit 1
    fi
    
    # Extract and install
    echo -e "${CYAN}${MSG_INSTALLING}${NC}"
    tar -xzf "${FILENAME}"
    chmod +x nodepass
    mv nodepass $NODEPASS_PATH
    
    echo -e "${GREEN}${MSG_INSTALL_SUCCESS}${NC}"
    
    # Clean up
    cd - > /dev/null
    rm -rf $TMP_DIR
}

# Setup systemd service
setup_systemd() {
    if ! command -v systemctl &> /dev/null; then
        echo -e "${YELLOW}${MSG_SYSTEMD_NOT_FOUND}${NC}"
        return
    fi
    
    echo -e "${CYAN}${MSG_SYSTEMD}${NC}"
    echo -e "1. ${GREEN}${MSG_SYSTEMD_YES}${NC}"
    echo -e "2. ${GREEN}${MSG_SYSTEMD_NO}${NC}"
    read -p "$(echo -e ${YELLOW}"Option [1/2]: "${NC})" systemd_option
    
    case $systemd_option in
        1)
            setup_systemd_service
            ;;
        2|*)
            # Do nothing
            ;;
    esac
}

# Create and enable systemd service
setup_systemd_service() {
    echo -e "${CYAN}${MSG_SYSTEMD_SETUP}${NC}"
    
    # Create service file
    cat > $SERVICE_PATH << EOF
[Unit]
Description=NodePass - Efficient TCP/UDP Tunneling Solution
After=network.target

[Service]
Type=simple
ExecStart=$NODEPASS_PATH ${MODE}://${TUNNEL_ADDR}/${TARGET_ADDR}${DEBUG_PARAM}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start the service
    systemctl daemon-reload
    systemctl enable nodepass
    systemctl start nodepass
    
    if systemctl is-active --quiet nodepass; then
        echo -e "${GREEN}${MSG_SYSTEMD_SUCCESS}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

# Start service
start_service() {
    echo -e "${CYAN}${MSG_START_SERVICE}${NC}"
    if systemctl start nodepass; then
        echo -e "${GREEN}${MSG_SERVICE_STARTED}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

# Stop service
stop_service() {
    echo -e "${CYAN}${MSG_STOP_SERVICE}${NC}"
    if systemctl stop nodepass; then
        echo -e "${GREEN}${MSG_SERVICE_STOPPED}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

# Restart service
restart_service() {
    echo -e "${CYAN}${MSG_RESTART_SERVICE}${NC}"
    if systemctl restart nodepass; then
        echo -e "${GREEN}${MSG_SERVICE_RESTARTED}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

# Uninstall
uninstall() {
    echo -e "${CYAN}${MSG_UNINSTALL}${NC}"
    
    # Stop and disable service if exists
    if [ -f "$SERVICE_PATH" ]; then
        systemctl stop nodepass
        systemctl disable nodepass
        rm -f $SERVICE_PATH
        systemctl daemon-reload
    fi
    
    # Remove binary and config
    rm -f $NODEPASS_PATH
    rm -f $CONFIG_PATH
    
    echo -e "${GREEN}${MSG_UNINSTALL_SUCCESS}${NC}"
}

# Update
update() {
    echo -e "${CYAN}${MSG_UPDATE}${NC}"
    
    # Load existing config
    if ! load_config; then
        echo -e "${RED}${MSG_NOT_INSTALLED}${NC}"
        return
    fi
    
    # Check current version
    local CURRENT_VERSION=$VERSION
    
    # Get latest version
    echo -e "${CYAN}${MSG_UPDATE_CHECK}${NC}"
    get_latest_version
    
    # Compare versions
    if [ "$CURRENT_VERSION" == "$VERSION" ]; then
        echo -e "${GREEN}${MSG_UPDATE_LATEST}${NC}"
        return
    fi
    
    echo -e "${GREEN}${MSG_UPDATE_AVAILABLE} ${VERSION}${NC}"
    
    # Use existing mirror settings if available
    if [[ -z "${USE_MIRROR}" ]]; then
        ask_mirror
    else
        echo -e "${CYAN}Using previous mirror settings: ${USE_MIRROR}${NC}"
    fi
    
    # Download and install
    download_and_install
    
    # Update config
    save_config
    
    # Restart service if active
    if systemctl is-active --quiet nodepass; then
        restart_service
    fi
    
    echo -e "${GREEN}${MSG_UPDATE_SUCCESS}${NC}"
}

# Display usage information
show_usage() {
    echo -e "${CYAN}${MSG_USAGE}${NC}"
    echo
    echo -e "${YELLOW}${MSG_CLIENT_USAGE}${NC}"
    echo -e "$NODEPASS_PATH client://${TUNNEL_ADDR}/${TARGET_ADDR}${DEBUG_PARAM}"
    echo
    echo -e "${YELLOW}${MSG_SERVER_USAGE}${NC}"
    echo -e "$NODEPASS_PATH server://${TUNNEL_ADDR}/${TARGET_ADDR}${DEBUG_PARAM}"
    echo
    
    if command -v systemctl &> /dev/null; then
        echo -e "${YELLOW}${MSG_SERVICE_USAGE}${NC}"
        echo -e "systemctl start nodepass    # Start service"
        echo -e "systemctl stop nodepass     # Stop service"
        echo -e "systemctl restart nodepass  # Restart service"
        echo -e "systemctl status nodepass   # Check service status"
    fi
}

# Wait for user input
pause() {
    echo
    read -p "$(echo -e ${YELLOW}${MSG_PRESS_ENTER}${NC})"
}

# Install function
do_install() {
    clear
    echo -e "${PURPLE}${MSG_WELCOME}${NC}\n"
    
    detect_arch
    get_latest_version
    ask_mirror
    ask_mode
    ask_addresses
    ask_debug
    download_and_install
    save_config
    setup_systemd
    
    echo -e "\n${GREEN}${MSG_COMPLETE}${NC}\n"
    show_usage
    pause
}

# Display menu and get user choice
show_menu() {
    clear
    show_logo
    echo -e "${PURPLE}${MSG_MAIN_MENU}${NC}\n"
    
    echo -e "1. ${GREEN}${MSG_MENU_INSTALL}${NC}"
    echo -e "2. ${GREEN}${MSG_MENU_START}${NC}"
    echo -e "3. ${GREEN}${MSG_MENU_STOP}${NC}"
    echo -e "4. ${GREEN}${MSG_MENU_RESTART}${NC}"
    echo -e "5. ${GREEN}${MSG_MENU_UPDATE}${NC}"
    echo -e "6. ${GREEN}${MSG_MENU_UNINSTALL}${NC}"
    echo -e "7. ${GREEN}${MSG_MENU_EXIT}${NC}"
    echo
    
    read -p "$(echo -e ${YELLOW}${MSG_MENU_CHOICE}" "${NC})" choice
    
    return $choice
}

# Main function
main() {
    # Initial setup
    check_root
    select_language
    load_messages
    check_dependencies
    
    # Main loop
    while true; do
        show_menu
        choice=$?
        
        case $choice in
            1) do_install ;;
            2) 
                if load_config; then
                    start_service
                    pause
                else
                    echo -e "${RED}${MSG_NOT_INSTALLED}${NC}"
                    pause
                fi
                ;;
            3)
                if load_config; then
                    stop_service
                    pause
                else
                    echo -e "${RED}${MSG_NOT_INSTALLED}${NC}"
                    pause
                fi
                ;;
            4)
                if load_config; then
                    restart_service
                    pause
                else
                    echo -e "${RED}${MSG_NOT_INSTALLED}${NC}"
                    pause
                fi
                ;;
            5)
                update
                pause
                ;;
            6)
                uninstall
                pause
                ;;
            7)
                clear
                echo -e "${GREEN}${MSG_EXIT}${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}${MSG_INVALID_CHOICE}${NC}"
                pause
                ;;
        esac
    done
}

# Run main function
main
