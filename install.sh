#!/bin/bash
# install.sh - 类似宝塔面板的一键安装脚本
# 自动安装版本，无需用户交互

set -e

# 配置
REPO="cocos-node/zwpls"
RAW_URL="https://raw.githubusercontent.com/$REPO/main"
VERSION="1.0.0"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 调试模式
DEBUG=${DEBUG:-0}
[ "$DEBUG" = "1" ] && set -x

# 强制刷新输出
if [ -t 1 ]; then
    # 如果是终端，正常输出
    INTERACTIVE=1
else
    # 如果是管道，强制行缓冲
    INTERACTIVE=0
    # 使用 stdbuf 强制行缓冲
    if command -v stdbuf >/dev/null 2>&1; then
        # 如果系统有 stdbuf
        alias echo='stdbuf -oL echo'
        alias printf='stdbuf -oL printf'
    else
        # 如果没有 stdbuf，设置 LD_PRELOAD
        if [ -f /usr/lib/x86_64-linux-gnu/libc.so.6 ]; then
            export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libc.so.6
        fi
    fi
fi

# 安全的输出函数
safe_echo() {
    if [ $INTERACTIVE -eq 1 ]; then
        echo -e "$@"
    else
        echo -e "$@" | while IFS= read -r line; do
            printf '%s\n' "$line"
        done
    fi
}

# 显示头部
show_header() {
    safe_echo "${BLUE}"
    safe_echo "╔══════════════════════════════════════════╗"
    safe_echo "║         zwpls 一键安装脚本              ║"
    safe_echo "║       快速命令管理器 v$VERSION           ║"
    safe_echo "║     https://github.com/cocos-node/zwpls ║"
    safe_echo "╚══════════════════════════════════════════╝"
    safe_echo "${NC}"
    safe_echo ""
}

# 检查并安装
install_zwpls() {
    safe_echo "${YELLOW}[1/4] 检查系统...${NC}"
    
    # 检查系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    safe_echo "系统: $OS $VER"
    safe_echo "用户: $(whoami)"
    safe_echo -n "时间: "
    date '+%Y-%m-%d %H:%M:%S'
    
    safe_echo "${GREEN}✓ 系统检查完成${NC}"
    safe_echo ""
    
    # 安装依赖
    safe_echo "${YELLOW}[2/4] 安装依赖...${NC}"
    install_dependencies
    safe_echo "${GREEN}✓ 依赖安装完成${NC}"
    safe_echo ""
    
    # 下载主程序
    safe_echo "${YELLOW}[3/4] 下载程序...${NC}"
    download_program
    safe_echo "${GREEN}✓ 程序下载完成${NC}"
    safe_echo ""
    
    # 配置
    safe_echo "${YELLOW}[4/4] 完成配置...${NC}"
    setup_config
    safe_echo "${GREEN}✓ 配置完成${NC}"
    safe_echo ""
    
    # 完成
    show_success
}

# 安装依赖
install_dependencies() {
    safe_echo -n "检查依赖: "
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        safe_echo -n "安装curl..."
        if command -v apt-get &> /dev/null; then
            apt-get update > /dev/null 2>&1
            apt-get install -y curl > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            yum install -y curl > /dev/null 2>&1
        elif command -v dnf &> /dev/null; then
            dnf install -y curl > /dev/null 2>&1
        elif command -v pacman &> /dev/null; then
            pacman -Sy --noconfirm curl > /dev/null 2>&1
        elif command -v apk &> /dev/null; then
            apk add curl > /dev/null 2>&1
        fi
    fi
    safe_echo -n "curl ✓ "
    
    # 检查 jq
    if ! command -v jq &> /dev/null; then
        safe_echo -n "安装jq..."
        if command -v apt-get &> /dev/null; then
            apt-get install -y jq > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            yum install -y jq > /dev/null 2>&1
        elif command -v dnf &> /dev/null; then
            dnf install -y jq > /dev/null 2>&1
        elif command -v pacman &> /dev/null; then
            pacman -Sy --noconfirm jq > /dev/null 2>&1
        elif command -v apk &> /dev/null; then
            apk add jq > /dev/null 2>&1
        elif command -v brew &> /dev/null; then
            brew install jq > /dev/null 2>&1
        fi
    fi
    safe_echo -n "jq ✓ "
    
    safe_echo ""
}

# 下载主程序
download_program() {
    # 创建安装目录
    mkdir -p /usr/local/bin
    
    # 下载主脚本
    safe_echo -n "下载主程序..."
    if curl -fsSL -o /tmp/zwpls.sh "$RAW_URL/zwpls.sh" 2>/dev/null; then
        if [ -s /tmp/zwpls.sh ]; then
            sudo mv /tmp/zwpls.sh /usr/local/bin/zwpls
            sudo chmod +x /usr/local/bin/zwpls
            safe_echo " ${GREEN}完成${NC}"
        else
            safe_echo " ${RED}失败: 文件为空${NC}"
            exit 1
        fi
    else
        safe_echo " ${RED}失败: 下载错误${NC}"
        exit 1
    fi
    
    # 下载自动补全
    if [ -d "/etc/bash_completion.d" ]; then
        safe_echo -n "安装自动补全..."
        if curl -fsSL -o /tmp/zwpls.bash "$RAW_URL/completion/bash" 2>/dev/null; then
            sudo mv /tmp/zwpls.bash /etc/bash_completion.d/zwpls
            safe_echo " ${GREEN}完成${NC}"
        else
            safe_echo " ${YELLOW}跳过${NC}"
        fi
    fi
}

# 配置
setup_config() {
    # 创建配置目录
    mkdir -p ~/.config/zwpls
    
    # 创建示例配置
    if [ ! -f ~/.config/zwpls/commands.json ]; then
        safe_echo -n "创建示例配置..."
        if curl -fsSL -o /tmp/commands.json "$RAW_URL/examples/commands.json" 2>/dev/null; then
            mv /tmp/commands.json ~/.config/zwpls/commands.json
            safe_echo " ${GREEN}完成${NC}"
        else
            echo '[]' > ~/.config/zwpls/commands.json
            safe_echo " ${YELLOW}创建空配置${NC}"
        fi
    fi
    
    # 设置权限
    chmod 700 ~/.config/zwpls
    chmod 600 ~/.config/zwpls/commands.json
}

# 显示成功信息
show_success() {
    safe_echo "${GREEN}"
    safe_echo "╔══════════════════════════════════════════╗"
    safe_echo "║        安装成功！🎉                    ║"
    safe_echo "╚══════════════════════════════════════════╝"
    safe_echo "${NC}"
    safe_echo ""
    safe_echo "${BLUE}使用方法:${NC}"
    safe_echo "  ${YELLOW}zwpls${NC}                       # 交互式使用"
    safe_echo "  ${YELLOW}zwpls add \"名称\" \"命令\"${NC}  # 添加命令"
    safe_echo "  ${YELLOW}zwpls help${NC}                 # 查看帮助"
    safe_echo ""
    safe_echo "${BLUE}示例:${NC}"
    safe_echo "  ${YELLOW}zwpls add 清屏 clear${NC}"
    safe_echo "  ${YELLOW}zwpls 清屏${NC}"
    safe_echo ""
    safe_echo "${BLUE}项目地址:${NC}"
    safe_echo "  ${CYAN}https://github.com/cocos-node/zwpls${NC}"
    safe_echo ""
    safe_echo "${GREEN}输入 'zwpls' 开始使用！${NC}"
}

# 处理参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                AUTO_CONFIRM=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -v|--version)
                safe_echo "zwpls 安装脚本 v$VERSION"
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

# 显示帮助
show_help() {
    safe_echo "${GREEN}zwpls 安装脚本${NC}"
    safe_echo ""
    safe_echo "使用方法:"
    safe_echo "  ${YELLOW}bash <(curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/install.sh)${NC}"
    safe_echo ""
    safe_echo "参数:"
    safe_echo "  ${YELLOW}-y, --yes${NC}   自动确认，无需交互"
    safe_echo "  ${YELLOW}-q, --quiet${NC} 静默模式"
    safe_echo "  ${YELLOW}-v, --version${NC} 显示版本"
    safe_echo "  ${YELLOW}-h, --help${NC}   显示帮助"
    safe_echo ""
    safe_echo "示例:"
    safe_echo "  ${CYAN}一键安装:${NC}"
    safe_echo "  curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/install.sh | bash"
    safe_echo ""
    safe_echo "  ${CYAN}自动确认安装:${NC}"
    safe_echo "  curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/install.sh | bash -s -- -y"
    safe_echo ""
    exit 0
}

# 主函数
main() {
    # 解析参数
    parse_args "$@"
    
    # 显示头部
    if [ "${QUIET:-0}" -ne 1 ]; then
        show_header
    fi
    
    # 如果是管道输入，自动确认
    if [ ! -t 0 ] || [ "${AUTO_CONFIRM:-0}" -eq 1 ]; then
        safe_echo "${YELLOW}开始自动安装...${NC}"
        safe_echo ""
    else
        # 交互式确认
        safe_echo "${YELLOW}是否安装 zwpls? [Y/n]:${NC} "
        read -r confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            safe_echo "安装已取消"
            exit 0
        fi
        safe_echo ""
    fi
    
    # 安装
    install_zwpls
}

# 捕获信号
trap 'safe_echo "${RED}安装被中断${NC}"; exit 1' INT TERM

# 运行主函数
main "$@"