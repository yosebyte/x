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
SERVICE_DIR="/etc/systemd/system"
CONFIG_DIR="/etc/nodepass"
CONFIG_FILE="${CONFIG_DIR}/config.json"

# Required dependencies
DEPENDENCIES=("curl" "tar" "grep" "sed" "jq")

# Display the logo
show_logo() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╭───────────────────────────────────────╮
│  ░░█▀█░█▀█░░▀█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░░  │
│  ░░█░█░█░█░█▀█░█▀▀░█▀▀░█▀█░▀▀█░▀▀█░░  │
│  ░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░  │
├───────────────────────────────────────┤
│      Universal TCP/UDP Tunneling      │
│ @https://github.com/yosebyte/nodepass │
╰───────────────────────────────────────╯
EOF
    echo -e "${NC}"
    
    # Language-specific version display
    if [ "$LANG" == "zh" ]; then
        echo -e "${YELLOW}版本: $(get_version_info)${NC}"
    else
        echo -e "${YELLOW}Version: $(get_version_info)${NC}"
    fi
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
        read -p "$(echo -e ${YELLOW}"[1/2]: "${NC})" install_deps_option
        
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
        if [ -f "$CONFIG_FILE" ]; then
            VERSION=$(jq -r '.global.version' "$CONFIG_FILE" 2>/dev/null)
            if [[ "$VERSION" == "null" || -z "$VERSION" ]]; then
                if [ "$LANG" == "zh" ]; then
                    echo "未知"
                else
                    echo "Unknown"
                fi
            else
                echo "$VERSION"
            fi
        else
            if [ "$LANG" == "zh" ]; then
                echo "未知"
            else
                echo "Unknown"
            fi
        fi
    else
        if [ "$LANG" == "zh" ]; then
            echo "未安装"
        else
            echo "Not Installed"
        fi
    fi
}

# Language Selection
select_language() {
    echo -e "${CYAN}请选择语言 / Please select language:${NC}"
    echo -e "1. ${GREEN}中文${NC}"
    echo -e "2. ${GREEN}English${NC}"
    read -p "$(echo -e ${YELLOW}"请输入选项 / Please enter option [1/2]: "${NC})" lang_option

    case $lang_option in
        2)
            LANG="en"
            echo -e "${GREEN}English selected${NC}\n"
            ;;
        *)
            LANG="zh"
            echo -e "${GREEN}已选择中文${NC}\n"
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
        MSG_VERSION_ERROR="无法获取最新版本，请手动输入版本号（格式: v0.0.0）："
        MSG_MIRROR="是否使用 GitHub 镜像？(gh-proxy.com)"
        MSG_MIRROR_YES="是，使用镜像"
        MSG_MIRROR_NO="否，使用原站"
        MSG_SELECT_MODE="请选择安装模式："
        MSG_MODE_CLIENT="客户端模式"
        MSG_MODE_SERVER="服务端模式"
        MSG_INPUT_TUNNEL="请输入隧道地址 (格式: IP地址:端口号)："
        MSG_INPUT_TARGET="请输入目标地址 (格式: IP地址:端口号)："
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
        MSG_COMPLETE="安装完成！可前往服务管理菜单添加服务。"
        MSG_USAGE="使用方法："
        MSG_CLIENT_USAGE="客户端模式："
        MSG_SERVER_USAGE="服务端模式："
        MSG_SERVICE_USAGE="systemd 服务管理："
        MSG_START_SERVICE="启动服务..."
        MSG_STOP_SERVICE="停止服务..."
        MSG_RESTART_SERVICE="重启服务..."
        MSG_SERVICE_STARTED="服务已启动。"
        MSG_SERVICE_STOPPED="服务已停止。"
        MSG_SERVICE_RESTARTED="服务已重启。"
        MSG_UNINSTALL="卸载 NodePass"
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
        MSG_MENU_UPDATE="更新 NodePass"
        MSG_MENU_MANAGE="管理 NodePass"
        MSG_MENU_EXIT="退出"
        MSG_MISSING_DEPENDENCIES="缺少必需的依赖项："
        MSG_INSTALL_DEPENDENCIES_PROMPT="是否安装缺少的依赖项？"
        MSG_INSTALL_DEPENDENCIES_YES="是，安装依赖项"
        MSG_INSTALL_DEPENDENCIES_NO="否，退出脚本"
        MSG_DEPENDENCIES_REQUIRED="依赖项是必需的，无法继续安装。"
        MSG_INSTALLING_DEPENDENCIES="正在安装依赖项..."
        MSG_DEPENDENCIES_INSTALLED="依赖项安装成功！"
        MSG_PACKAGE_MANAGER_NOT_FOUND="无法确定包管理器，请手动安装依赖项。"
        MSG_SERVICE_NAME="请为此服务设置一个名称（不含空格，例如：ssh、dns）："
        MSG_SERVICE_EXISTS="服务名称已存在，请重新输入。"
        MSG_MANAGE_MENU="NodePass 服务管理"
        MSG_NO_SERVICES="未找到任何服务。请先安装服务。"
        MSG_ADD_SERVICE="添加新服务"
        MSG_BACK="返回上一级菜单"
        MSG_SERVICE_MENU="服务操作"
        MSG_SERVICE_START="启动服务"
        MSG_SERVICE_STOP="停止服务"
        MSG_SERVICE_RESTART="重启服务"
        MSG_SERVICE_DELETE="删除服务"
        MSG_CONFIRM_DELETE="确定吗？"
        MSG_CONFIRM_YES="是"
        MSG_CONFIRM_NO="否"
        MSG_SERVICE_DELETED="服务已删除。"
        MSG_TUNNEL_EXPLANATION="隧道地址是NodePass用于建立TLS控制通道的地址。\n服务端模式下：这是服务端监听的地址，例如 0.0.0.0:10101\n客户端模式下：这是连接服务端的地址，例如 server:10101"
        MSG_TARGET_EXPLANATION="目标地址是NodePass用于接收转发业务数据的地址。\n服务端模式下：这是目标业务外部地址，例如 0.0.0.0:10022\n客户端模式下：这是目标业务内部地址，例如 127.0.0.1:22"
        MSG_SERVICE_NAME_EXPLANATION="服务名称用于标识不同的NodePass服务实例，将作为systemd服务名的一部分（np-服务名）"
        MSG_DEBUG_EXPLANATION="调试模式将显示详细的日志信息，有助于排查问题，但会产生较多日志"
        MSG_CUSTOM_MIRROR_PROMPT="是否使用自定义GitHub镜像？"
        MSG_CUSTOM_MIRROR_YES="是，使用自定义镜像"
        MSG_CUSTOM_MIRROR_NO="否，取消安装"
        MSG_CUSTOM_MIRROR_URL="请输入自定义GitHub镜像URL (如 https://gh-proxy.com/ )："
        MSG_RETRY_DOWNLOAD="正在使用自定义镜像重新下载..."
        MSG_PRESS_ENTER="按回车键继续..."
        MSG_EXIT="STAR并关注项目以获取更新：https://github.com/yosebyte/nodepass"
        MSG_INVALID_CHOICE="无效选择，请重试。"
        MSG_MENU_CHOICE="请选择一个选项："
        MSG_AVAILABLE_SERVICES="可用服务，选中管理："
        MSG_URL="运行命令:"
        MSG_DEBUG="调试模式:"
        MSG_RUNNING="运行中"
        MSG_STOPPED="已停止"
        MSG_UNKNOWN="未知"
        MSG_INPUT_REQUIRED="输入不能为空，请重试。"
        MSG_EXAMPLE="示例："
    else
        MSG_WELCOME="Welcome to NodePass Management Script!"
        MSG_ROOT="Root privileges are required to complete this operation."
        MSG_CHECKING_ARCH="Detecting system architecture..."
        MSG_ARCH_DETECTED="System architecture detected:"
        MSG_ARCH_UNSUPPORTED="Unsupported architecture! NodePass only supports amd64 and arm64 architectures."
        MSG_CHECKING_VERSION="Getting latest version..."
        MSG_VERSION_DETECTED="Latest version detected:"
        MSG_VERSION_ERROR="Unable to get latest version. Please enter version manually (format: v0.0.0):"
        MSG_MIRROR="Use GitHub mirror? (gh-proxy.com)"
        MSG_MIRROR_YES="Yes, use mirror"
        MSG_MIRROR_NO="No, use direct connection"
        MSG_SELECT_MODE="Please select installation mode:"
        MSG_MODE_CLIENT="Client mode"
        MSG_MODE_SERVER="Server mode"
        MSG_INPUT_TUNNEL="Please enter tunnel address (format: IP:port):"
        MSG_INPUT_TARGET="Please enter target address (format: IP:port):"
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
        MSG_COMPLETE="Installation complete! Proceed to service management menu to add services."
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
        MSG_UNINSTALL="Remove NodePass"
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
        MSG_MENU_UPDATE="Update NodePass"
        MSG_MENU_MANAGE="Manage NodePass"
        MSG_MENU_EXIT="Exit"
        MSG_MISSING_DEPENDENCIES="Missing required dependencies:"
        MSG_INSTALL_DEPENDENCIES_PROMPT="Install missing dependencies?"
        MSG_INSTALL_DEPENDENCIES_YES="Yes, install dependencies"
        MSG_INSTALL_DEPENDENCIES_NO="No, exit script"
        MSG_DEPENDENCIES_REQUIRED="Dependencies are required, cannot continue."
        MSG_INSTALLING_DEPENDENCIES="Installing dependencies..."
        MSG_DEPENDENCIES_INSTALLED="Dependencies installed successfully!"
        MSG_PACKAGE_MANAGER_NOT_FOUND="Unable to determine package manager, please install dependencies manually."
        MSG_SERVICE_NAME="Please set a name for this service (without spaces, e.g.: ssh, dns):"
        MSG_SERVICE_EXISTS="Service name already exists, please enter another one."
        MSG_MANAGE_MENU="NodePass Service Management"
        MSG_NO_SERVICES="No services found. Please install a service first."
        MSG_ADD_SERVICE="Add new service"
        MSG_BACK="Back to previous menu"
        MSG_SERVICE_MENU="Service Operations"
        MSG_SERVICE_START="Start service"
        MSG_SERVICE_STOP="Stop service"
        MSG_SERVICE_RESTART="Restart service"
        MSG_SERVICE_DELETE="Delete service"
        MSG_CONFIRM_DELETE="Are you sure?"
        MSG_CONFIRM_YES="Yes"
        MSG_CONFIRM_NO="No"
        MSG_SERVICE_DELETED="Service has been deleted."
        MSG_TUNNEL_EXPLANATION="Tunnel address is used by NodePass to establish a TLS control channel.\nServer mode: This is where the server listens, e.g., 0.0.0.0:10101\nClient mode: This is where to connect to the server, e.g., server:10101"
        MSG_TARGET_EXPLANATION="Target address is where NodePass forwards target service data.\nServer mode: This is the external address for target service, e.g., 0.0.0.0:10022\nClient mode: This is the target service address accessible from client, e.g., 127.0.0.1:22"
        MSG_SERVICE_NAME_EXPLANATION="Service name is used to identify different NodePass service instances and will be part of the systemd service name (np-servicename)"
        MSG_DEBUG_EXPLANATION="Debug mode shows detailed log information which helps troubleshooting but generates more logs"
        MSG_CUSTOM_MIRROR_PROMPT="Would you like to use a custom GitHub mirror?"
        MSG_CUSTOM_MIRROR_YES="Yes, use a custom mirror"
        MSG_CUSTOM_MIRROR_NO="No, cancel installation"
        MSG_CUSTOM_MIRROR_URL="Please enter custom GitHub mirror URL (e.g. https://gh-proxy.com/ ):"
        MSG_RETRY_DOWNLOAD="Retrying download with custom mirror..."
        MSG_PRESS_ENTER="Press Enter to continue..."
        MSG_EXIT="STAR and watch the project for updates. https://github.com/yosebyte/nodepass"
        MSG_INVALID_CHOICE="Invalid choice, please try again."
        MSG_MENU_CHOICE="Please select an option:"
        MSG_AVAILABLE_SERVICES="Available services, select to manage:"
        MSG_URL="Command:"
        MSG_DEBUG="Debug:"
        MSG_RUNNING="Running"
        MSG_STOPPED="Stopped"
        MSG_UNKNOWN="Unknown"
        MSG_INPUT_REQUIRED="Input required, please try again."
        MSG_EXAMPLE="Example:"
    fi
}

# Get user input with validation
get_user_input() {
    local prompt="$1"
    local variable_name="$2"
    local explanation="$3"
    local example="$4"
    
    if [ -n "$explanation" ]; then
        echo -e "${CYAN}${explanation}${NC}"
    fi
    
    if [ -n "$example" ]; then
        echo -e "${YELLOW}${MSG_EXAMPLE} ${example}${NC}"
    fi
    
    while true; do
        read -p "$(echo -e ${YELLOW}${prompt}" "${NC})" input
        if [ -n "$input" ]; then
            eval "$variable_name='$input'"
            break
        fi
        echo -e "${RED}${MSG_INPUT_REQUIRED}${NC}"
    done
}

# Get user choice with validation
get_user_choice() {
    local prompt="$1"
    local options=("${@:2}")
    local valid=false
    local choice
    
    while [ "$valid" = false ]; do
        echo -e "${CYAN}${prompt}${NC}"
        
        # Display options
        for i in "${!options[@]}"; do
            echo -e "$((i+1)). ${GREEN}${options[$i]}${NC}"
        done
        
        # Get user input
        read -p "$(echo -e ${YELLOW}"[1-${#options[@]}]: "${NC})" choice
        
        # Validate input
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            valid=true
        else
            echo -e "${RED}${MSG_INVALID_CHOICE}${NC}"
        fi
    done
    
    return "$choice"
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
        echo -e "${YELLOW}${MSG_VERSION_ERROR}${NC}"
        get_user_input "${MSG_VERSION_ERROR}" VERSION
    else
        echo -e "${GREEN}${MSG_VERSION_DETECTED} ${VERSION}${NC}"
    fi
}

# Ask user whether to use mirror
ask_mirror() {
    get_user_choice "${MSG_MIRROR}" "${MSG_MIRROR_YES}" "${MSG_MIRROR_NO}"
    local mirror_option=$?
    
    case $mirror_option in
        1)
            USE_MIRROR=true
            MIRROR_URL="https://gh-proxy.com/"
            ;;
        2)
            USE_MIRROR=false
            MIRROR_URL=""
            ;;
    esac
}

# Ask for installation mode
ask_mode() {
    get_user_choice "${MSG_SELECT_MODE}" "${MSG_MODE_CLIENT}" "${MSG_MODE_SERVER}"
    local mode_option=$?
    
    case $mode_option in
        1)
            MODE="client"
            ;;
        2)
            MODE="server"
            ;;
    esac
}

# Ask for debug mode
ask_debug() {
    echo -e "${CYAN}${MSG_DEBUG_EXPLANATION}${NC}"
    get_user_choice "${MSG_DEBUG_MODE}" "${MSG_DEBUG_YES}" "${MSG_DEBUG_NO}"
    local debug_option=$?
    
    case $debug_option in
        1)
            DEBUG_MODE=true
            DEBUG_PARAM="?log=debug"
            ;;
        2)
            DEBUG_MODE=false
            DEBUG_PARAM=""
            ;;
    esac
}

# Ask for tunnel and target addresses
ask_addresses() {
    echo -e "${CYAN}${MSG_TUNNEL_EXPLANATION}${NC}"
    get_user_input "${MSG_INPUT_TUNNEL}" TUNNEL_ADDR
    
    echo -e "${CYAN}${MSG_TARGET_EXPLANATION}${NC}"
    get_user_input "${MSG_INPUT_TARGET}" TARGET_ADDR
}

# Ask for service name
ask_service_name() {
    echo -e "${CYAN}${MSG_SERVICE_NAME_EXPLANATION}${NC}"
    while true; do
        get_user_input "${MSG_SERVICE_NAME}" SERVICE_NAME
        
        # Check if service already exists
        if [ -f "${CONFIG_DIR}/services/${SERVICE_NAME}.json" ]; then
            echo -e "${RED}${MSG_SERVICE_EXISTS}${NC}"
        else
            break
        fi
    done
}

# Initialize config directory and file
init_config() {
    mkdir -p "${CONFIG_DIR}/services"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        # Create initial config file
        echo "{\"global\":{\"version\":\"${VERSION}\",\"use_mirror\":${USE_MIRROR},\"mirror_url\":\"${MIRROR_URL}\"},\"services\":[]}" > "$CONFIG_FILE"
    else
        # Update global config
        jq ".global.version = \"${VERSION}\" | .global.use_mirror = ${USE_MIRROR} | .global.mirror_url = \"${MIRROR_URL}\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
}

# Add service to config
add_service() {
    # Create service config file
    local SERVICE_CONFIG="${CONFIG_DIR}/services/${SERVICE_NAME}.json"
    
    echo "{
        \"name\": \"${SERVICE_NAME}\",
        \"mode\": \"${MODE}\",
        \"tunnel_addr\": \"${TUNNEL_ADDR}\",
        \"target_addr\": \"${TARGET_ADDR}\",
        \"debug_mode\": ${DEBUG_MODE},
        \"debug_param\": \"${DEBUG_PARAM}\"
    }" > "$SERVICE_CONFIG"
    
    # Update main config file
    jq ".services += [\"${SERVICE_NAME}\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

# Ask for custom mirror URL
ask_custom_mirror_url() {
    get_user_choice "${MSG_CUSTOM_MIRROR_PROMPT}" "${MSG_CUSTOM_MIRROR_YES}" "${MSG_CUSTOM_MIRROR_NO}"
    local custom_mirror_option=$?
    
    if [ "$custom_mirror_option" -eq 1 ]; then
        get_user_input "${MSG_CUSTOM_MIRROR_URL}" CUSTOM_MIRROR_URL
        USE_MIRROR=true
        MIRROR_URL="${CUSTOM_MIRROR_URL}"
        # Ensure URL ends with a trailing slash
        [[ "${MIRROR_URL}" != */ ]] && MIRROR_URL="${MIRROR_URL}/"
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
        
        # Offer to use custom mirror
        if ask_custom_mirror_url; then
            echo -e "${CYAN}${MSG_RETRY_DOWNLOAD}${NC}"
            DOWNLOAD_URL="${MIRROR_URL}https://github.com/yosebyte/nodepass/releases/download/${VERSION}/${FILENAME}"
            
            if curl -L -o "${FILENAME}" "${DOWNLOAD_URL}"; then
                echo -e "${GREEN}${MSG_DOWNLOAD_SUCCESS}${NC}"
            else
                echo -e "${RED}${MSG_DOWNLOAD_ERROR}${NC}"
                cd - > /dev/null
                rm -rf $TMP_DIR
                exit 1
            fi
        else
            cd - > /dev/null
            rm -rf $TMP_DIR
            exit 1
        fi
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
setup_systemd_service() {
    echo -e "${CYAN}${MSG_SYSTEMD_SETUP}${NC}"
    
    local SERVICE_CONFIG="${CONFIG_DIR}/services/${SERVICE_NAME}.json"
    local SERVICE_PATH="${SERVICE_DIR}/np-${SERVICE_NAME}.service"
    
    # Get service details
    local S_MODE=$(jq -r .mode "$SERVICE_CONFIG")
    local S_TUNNEL=$(jq -r .tunnel_addr "$SERVICE_CONFIG")
    local S_TARGET=$(jq -r .target_addr "$SERVICE_CONFIG")
    local S_DEBUG=$(jq -r .debug_param "$SERVICE_CONFIG")
    
    # Create service file
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=NodePass (${SERVICE_NAME}) - Universal TCP/UDP Tunneling
After=network.target

[Service]
Type=simple
ExecStart=$NODEPASS_PATH ${S_MODE}://${S_TUNNEL}/${S_TARGET}${S_DEBUG}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start the service
    systemctl daemon-reload
    systemctl enable "np-${SERVICE_NAME}"
    systemctl start "np-${SERVICE_NAME}"
    
    if systemctl is-active --quiet "np-${SERVICE_NAME}"; then
        echo -e "${GREEN}${MSG_SYSTEMD_SUCCESS}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

# Service operations
start_service() {
    local service_name="$1"
    echo -e "${CYAN}${MSG_START_SERVICE}${NC}"
    if systemctl start "np-${service_name}"; then
        echo -e "${GREEN}${MSG_SERVICE_STARTED}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

stop_service() {
    local service_name="$1"
    echo -e "${CYAN}${MSG_STOP_SERVICE}${NC}"
    if systemctl stop "np-${service_name}"; then
        echo -e "${GREEN}${MSG_SERVICE_STOPPED}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

restart_service() {
    local service_name="$1"
    echo -e "${CYAN}${MSG_RESTART_SERVICE}${NC}"
    if systemctl restart "np-${service_name}"; then
        echo -e "${GREEN}${MSG_SERVICE_RESTARTED}${NC}"
    else
        echo -e "${RED}${MSG_SYSTEMD_ERROR}${NC}"
    fi
}

delete_service() {
    local service_name="$1"
    
    # Confirm deletion
    get_user_choice "${MSG_CONFIRM_DELETE}" "${MSG_CONFIRM_YES}" "${MSG_CONFIRM_NO}"
    local confirm=$?
    
    if [ "$confirm" -eq 2 ]; then
        return
    fi
    
    # Stop and disable the service
    systemctl stop "np-${service_name}" 2>/dev/null
    systemctl disable "np-${service_name}" 2>/dev/null
    
    # Remove service files
    rm -f "${SERVICE_DIR}/np-${service_name}.service"
    rm -f "${CONFIG_DIR}/services/${service_name}.json"
    
    # Update config file
    jq ".services -= [\"${service_name}\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    systemctl daemon-reload
    
    echo -e "${GREEN}${MSG_SERVICE_DELETED}${NC}"
}

# Update NodePass executable
update_nodepass() {
    echo -e "${CYAN}${MSG_UPDATE}${NC}"
    
    # Load existing config
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}${MSG_NOT_INSTALLED}${NC}"
        pause
        return
    fi
    
    # Check current version
    local CURRENT_VERSION=$(jq -r '.global.version' "$CONFIG_FILE")
    local USE_MIRROR=$(jq -r '.global.use_mirror' "$CONFIG_FILE")
    local MIRROR_URL=$(jq -r '.global.mirror_url' "$CONFIG_FILE")
    
    # Get latest version
    echo -e "${CYAN}${MSG_UPDATE_CHECK}${NC}"
    get_latest_version
    
    # Compare versions
    if [ "$CURRENT_VERSION" == "$VERSION" ]; then
        echo -e "${GREEN}${MSG_UPDATE_LATEST}${NC}"
        pause
        return
    fi
    
    echo -e "${GREEN}${MSG_UPDATE_AVAILABLE} ${VERSION}${NC}"
    
    # Check and store running services before update
    local services=($(jq -r '.services[]' "$CONFIG_FILE"))
    local running_services=()
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "np-${service}"; then
            running_services+=("$service")
        fi
    done
    
    # Download and install
    download_and_install
    
    # Update config
    jq ".global.version = \"${VERSION}\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    # Restart only previously running services
    for service in "${running_services[@]}"; do
        restart_service "$service"
    done
    
    echo -e "${GREEN}${MSG_UPDATE_SUCCESS}${NC}"
    pause
}

# Display usage information for a service
show_service_usage() {
    local service_name="$1"
    local SERVICE_CONFIG="${CONFIG_DIR}/services/${service_name}.json"
    
    local S_MODE=$(jq -r .mode "$SERVICE_CONFIG")
    local S_TUNNEL=$(jq -r .tunnel_addr "$SERVICE_CONFIG")
    local S_TARGET=$(jq -r .target_addr "$SERVICE_CONFIG")
    local S_DEBUG=$(jq -r .debug_param "$SERVICE_CONFIG")
    
    echo -e "${CYAN}${MSG_USAGE}${NC}"
    echo
    if [ "$S_MODE" == "client" ]; then
        echo -e "${YELLOW}${MSG_CLIENT_USAGE}${NC}"
    else
        echo -e "${YELLOW}${MSG_SERVER_USAGE}${NC}"
    fi
    
    echo -e "$NODEPASS_PATH ${S_MODE}://${S_TUNNEL}/${S_TARGET}${S_DEBUG}"
    echo
}

# Install function
do_install() {
    clear
    echo -e "${PURPLE}${MSG_WELCOME}${NC}\n"
    
    detect_arch
    get_latest_version
    ask_mirror
    download_and_install
    init_config
    
    echo -e "\n${GREEN}${MSG_COMPLETE}${NC}\n"
    pause
}

# New function to determine whether to install or update
install_or_update() {
    if [ -f "$NODEPASS_PATH" ]; then
        # NodePass is installed, run update
        update_nodepass
    else
        # NodePass is not installed, run install
        do_install
    fi
}

# Service menu
show_service_menu() {
    local service_name="$1"
    local SERVICE_CONFIG="${CONFIG_DIR}/services/${service_name}.json"
    
    while true; do
        clear
        show_logo
        
        local mode=$(jq -r .mode "$SERVICE_CONFIG")
        local tunnel=$(jq -r .tunnel_addr "$SERVICE_CONFIG")
        local target=$(jq -r .target_addr "$SERVICE_CONFIG")
        local debug=$(jq -r .debug_mode "$SERVICE_CONFIG")
        
        # Show debug as Yes/No
        local debug_display="no"
        if [ "$debug" == "true" ]; then
            debug_display="yes"
        fi
        
        echo -e "${PURPLE}${MSG_SERVICE_MENU}: ${GREEN}np-${service_name}${NC}\n"
        echo -e "${CYAN}${MSG_URL} ${NC}${mode}://${tunnel}/${target}"
        echo -e "${CYAN}${MSG_DEBUG} ${NC}${debug_display}\n"
        
        get_user_choice "${MSG_MENU_CHOICE}" \
            "${MSG_SERVICE_START}" \
            "${MSG_SERVICE_STOP}" \
            "${MSG_SERVICE_RESTART}" \
            "${MSG_SERVICE_DELETE}" \
            "${MSG_BACK}"
        
        local choice=$?
        
        case $choice in
            1) 
                start_service "$service_name"
                pause
                ;;
            2)
                stop_service "$service_name"
                pause
                ;;
            3)
                restart_service "$service_name"
                pause
                ;;
            4)
                delete_service "$service_name"
                if [ $? -eq 0 ]; then
                    # Return to manage menu if service was deleted
                    break
                fi
                pause
                ;;
            5)
                # Back to manage menu
                break
                ;;
        esac
    done
}

# Manage services
manage_services() {
    # Check if nodepass is installed
    if [ ! -f "$NODEPASS_PATH" ]; then
        echo -e "${RED}${MSG_NOT_INSTALLED}${NC}"
        pause
        return
    fi

    while true; do
        clear
        show_logo
        echo -e "${PURPLE}${MSG_MANAGE_MENU}${NC}\n"
        
        # Check if there are any services
        if [ ! -f "$CONFIG_FILE" ] || [ "$(jq '.services | length' "$CONFIG_FILE")" -eq 0 ]; then
            echo -e "${YELLOW}${MSG_NO_SERVICES}${NC}\n"
            get_user_choice "${MSG_MENU_CHOICE}" \
                "${MSG_ADD_SERVICE}" \
                "${MSG_BACK}"
            
            local choice=$?
            
            if [ $choice -eq 1 ]; then
                ask_service_name
                ask_mode
                ask_addresses
                ask_debug
                
                init_config
                add_service
                
                if command -v systemctl &> /dev/null; then
                    setup_systemd_service
                else
                    echo -e "${YELLOW}${MSG_SYSTEMD_NOT_FOUND}${NC}"
                fi
                
                pause
            else
                break
            fi
        else
            # List all services
            local services=($(jq -r '.services[]' "$CONFIG_FILE"))
            
            echo -e "${CYAN}${MSG_AVAILABLE_SERVICES}${NC}\n"
            
            for i in "${!services[@]}"; do
                local name="${services[$i]}"
                local CONFIG="${CONFIG_DIR}/services/${name}.json"
                local mode=$(jq -r .mode "$CONFIG")
                local tunnel=$(jq -r .tunnel_addr "$CONFIG")
                local target=$(jq -r .target_addr "$CONFIG")
                
                # Check service status
                local status="${MSG_UNKNOWN}"
                if systemctl is-active --quiet "np-${name}"; then
                    status="${GREEN}${MSG_RUNNING}${NC}"
                else
                    status="${RED}${MSG_STOPPED}${NC}"
                fi
                
                echo -e "$((i+1)). ${GREEN}np-${name}${NC} | ${CYAN}${mode}://${tunnel}/${target}${NC} | ${status}"
            done
            
            echo
            echo -e "$((${#services[@]}+1)). ${GREEN}${MSG_ADD_SERVICE}${NC}"
            echo -e "$((${#services[@]}+2)). ${GREEN}${MSG_BACK}${NC}"
            echo
            
            read -p "$(echo -e ${YELLOW}"${MSG_MENU_CHOICE} "${NC})" manage_choice
            
            if [[ ! "$manage_choice" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}${MSG_INVALID_CHOICE}${NC}"
                pause
                continue
            fi
            
            if [ "$manage_choice" -ge 1 ] && [ "$manage_choice" -le "${#services[@]}" ]; then
                # Service selected
                show_service_menu "${services[$((manage_choice-1))]}"
            elif [ "$manage_choice" -eq "$((${#services[@]}+1))" ]; then
                # Add new service
                ask_service_name
                ask_mode
                ask_addresses
                ask_debug
                
                add_service
                
                if command -v systemctl &> /dev/null; then
                    setup_systemd_service
                else
                    echo -e "${YELLOW}${MSG_SYSTEMD_NOT_FOUND}${NC}"
                fi
                
                pause
            elif [ "$manage_choice" -eq "$((${#services[@]}+2))" ]; then
                # Back to main menu
                break
            else
                echo -e "${RED}${MSG_INVALID_CHOICE}${NC}"
                pause
            fi
        fi
    done
}

# Uninstall everything
uninstall_all() {
    # Check if nodepass is installed
    if [ ! -f "$NODEPASS_PATH" ]; then
        echo -e "${RED}${MSG_NOT_INSTALLED}${NC}"
        return
    fi
    
    # Ask for confirmation
    get_user_choice "${MSG_CONFIRM_DELETE}" "${MSG_CONFIRM_YES}" "${MSG_CONFIRM_NO}"
    local confirm=$?
    if [ "$confirm" -eq 2 ]; then
        return
    fi

    # Stop and disable all services
    if [ -f "$CONFIG_FILE" ]; then
        local services=($(jq -r '.services[]' "$CONFIG_FILE"))
        for service in "${services[@]}"; do
            systemctl stop "np-${service}" 2>/dev/null
            systemctl disable "np-${service}" 2>/dev/null
            rm -f "${SERVICE_DIR}/np-${service}.service"
        done
    fi
    
    # Remove binary and config
    rm -f $NODEPASS_PATH
    rm -rf $CONFIG_DIR
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}${MSG_UNINSTALL_SUCCESS}${NC}"
}

# Wait for user input
pause() {
    echo
    read -p "$(echo -e ${YELLOW}${MSG_PRESS_ENTER}${NC})"
}

# Display menu and get user choice
show_menu() {
    clear
    show_logo
    echo -e "${PURPLE}${MSG_MAIN_MENU}${NC}\n"
    
    # Check if NodePass is installed and choose appropriate menu text
    local first_option
    if [ -f "$NODEPASS_PATH" ]; then
        first_option="${MSG_MENU_UPDATE}"
    else
        first_option="${MSG_MENU_INSTALL}"
    fi
    
    get_user_choice "${MSG_MENU_CHOICE}" \
        "$first_option" \
        "${MSG_MENU_MANAGE}" \
        "${MSG_UNINSTALL}" \
        "${MSG_MENU_EXIT}"
    
    return $?
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
            1) install_or_update ;;
            2) manage_services ;;
            3)
                uninstall_all
                pause
                ;;
            4)
                clear
                echo -e "${GREEN}${MSG_EXIT}${NC}"
                exit 0
                ;;
        esac
    done
}

# Run main function
main
