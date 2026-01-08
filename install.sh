#!/bin/bash
# install.sh - 类似宝塔面板的一键安装脚本

set -e

# 配置
REPO="cocos-node/zwpls"
RAW_URL="https://raw.githubusercontent.com/$REPO/main"
INSTALL_SCRIPT="https://raw.githubusercontent.com/$REPO/main/install.sh"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示头部
show_header() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║         zwpls 一键安装脚本              ║"
    echo "║       快速命令管理器 v1.0.0            ║"
    echo "║     https://github.com/cocos-node/zwpls ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# 检查并安装
install_zwpls() {
    echo -e "${YELLOW}[1/4] 检查系统...${NC}"
    
    # 检查系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    echo -e "系统: $OS $VER"
    
    # 检查是否为root
    if [ "$EUID" -eq 0 ]; then
        echo -e "用户: root"
    else
        echo -e "用户: $(whoami)"
    fi
    
    echo -e "${GREEN}✓ 系统检查完成${NC}"
    echo
    
    # 安装依赖
    echo -e "${YELLOW}[2/4] 安装依赖...${NC}"
    install_dependencies
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
    echo
    
    # 下载主程序
    echo -e "${YELLOW}[3/4] 下载程序...${NC}"
    download_program
    echo -e "${GREEN}✓ 程序下载完成${NC}"
    echo
    
    # 配置
    echo -e "${YELLOW}[4/4] 完成配置...${NC}"
    setup_config
    echo -e "${GREEN}✓ 配置完成${NC}"
    echo
    
    # 完成
    show_success
}

# 安装依赖
install_dependencies() {
    echo -n "检查依赖: "
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        echo -n "安装curl..."
        if command -v apt-get &> /dev/null; then
            apt-get update > /dev/null 2>&1
            apt-get install -y curl > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            yum install -y curl > /dev/null 2>&1
        fi
    fi
    echo -n "curl ✓ "
    
    # 检查 jq
    if ! command -v jq &> /dev/null; then
        echo -n "安装jq..."
        if command -v apt-get &> /dev/null; then
            apt-get install -y jq > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            yum install -y jq > /dev/null 2>&1
        elif command -v brew &> /dev/null; then
            brew install jq > /dev/null 2>&1
        fi
    fi
    echo -n "jq ✓ "
    
    echo
}

# 下载主程序
download_program() {
    # 创建安装目录
    mkdir -p /usr/local/bin
    
    # 下载主脚本
    echo -n "下载主程序..."
    if curl -sSL -o /usr/local/bin/zwpls "$RAW_URL/zwpls.sh" 2>/dev/null; then
        chmod +x /usr/local/bin/zwpls
        echo -e " ${GREEN}完成${NC}"
    else
        echo -e " ${RED}失败${NC}"
        exit 1
    fi
    
    # 下载自动补全
    if [ -d "/etc/bash_completion.d" ]; then
        echo -n "安装自动补全..."
        curl -sSL -o /etc/bash_completion.d/zwpls "$RAW_URL/completion/bash" 2>/dev/null && \
        echo -e " ${GREEN}完成${NC}" || echo -e " ${YELLOW}跳过${NC}"
    fi
}

# 配置
setup_config() {
    # 创建配置目录
    mkdir -p ~/.config/zwpls
    
    # 创建示例配置
    if [ ! -f ~/.config/zwpls/commands.json ]; then
        echo -n "创建示例配置..."
        curl -sSL -o ~/.config/zwpls/commands.json "$RAW_URL/examples/commands.json" 2>/dev/null || \
        echo '[]' > ~/.config/zwpls/commands.json
        echo -e " ${GREEN}完成${NC}"
    fi
}

# 显示成功信息
show_success() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║        安装成功！🎉                    ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo -e "${BLUE}使用方法:${NC}"
    echo -e "  ${YELLOW}zwpls${NC}                       # 交互式使用"
    echo -e "  ${YELLOW}zwpls add \"名称\" \"命令\"${NC}  # 添加命令"
    echo -e "  ${YELLOW}zwpls help${NC}                 # 查看帮助"
    echo
    echo -e "${BLUE}示例:${NC}"
    echo -e "  ${YELLOW}zwpls add 清屏 clear${NC}"
    echo -e "  ${YELLOW}zwpls 清屏${NC}"
    echo
    echo -e "${BLUE}项目地址:${NC}"
    echo -e "  ${CYAN}https://github.com/cocos-node/zwpls${NC}"
    echo
    echo -e "${GREEN}输入 'zwpls' 开始使用！${NC}"
}

# 显示使用说明
usage() {
    echo -e "${GREEN}zwpls 安装脚本${NC}"
    echo
    echo -e "使用方法:"
    echo -e "  ${YELLOW}bash <(curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/install.sh)${NC}"
    echo
    echo -e "参数:"
    echo -e "  ${YELLOW}--help${NC}    显示帮助"
    echo -e "  ${YELLOW}--version${NC} 显示版本"
    echo
    echo -e "示例:"
    echo -e "  ${CYAN}一键安装:${NC}"
    echo -e "  curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/install.sh | bash"
    echo
    echo -e "  ${CYAN}下载后安装:${NC}"
    echo -e "  wget https://raw.githubusercontent.com/cocos-node/zwpls/main/install.sh"
    echo -e "  bash install.sh"
    echo
    exit 0
}

# 主函数
main() {
    # 检查参数
    case "$1" in
        --help|-h)
            usage
            ;;
        --version|-v)
            echo "zwpls 安装脚本 v1.0.0"
            exit 0
            ;;
    esac
    
    show_header
    
    # 询问确认
    echo -e "${YELLOW}是否安装 zwpls? [Y/n]:${NC} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
    
    echo
    install_zwpls
}

# 运行
main "$@"