#!/bin/bash
# uninstall.sh - zwpls 卸载脚本
# GitHub: https://github.com/cocos-node/zwpls

set -e

# 配置
VERSION="1.0.0"
SCRIPT_NAME="zwpls"
CONFIG_DIR="$HOME/.config/zwpls"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { [ "${DEBUG}" = "1" ] && echo -e "${CYAN}[DEBUG]${NC} $1"; }

# 显示标题
show_title() {
    echo -e "${BOLD}${RED}"
    echo "╔══════════════════════════════════════════╗"
    echo "║         zwpls 卸载程序                  ║"
    echo "║              v$VERSION                   ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查是否安装
check_installation() {
    log_info "检查 zwpls 安装状态..."
    
    local installed=0
    
    # 检查主程序
    if command -v zwpls &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} 主程序: $(which zwpls)"
        installed=1
    else
        echo -e "  ${YELLOW}✗${NC} 主程序: 未找到"
    fi
    
    # 检查配置目录
    if [ -d "$CONFIG_DIR" ]; then
        echo -e "  ${GREEN}✓${NC} 配置目录: $CONFIG_DIR"
        installed=1
    else
        echo -e "  ${YELLOW}✗${NC} 配置目录: 未找到"
    fi
    
    # 检查服务
    if [ -f "/etc/systemd/system/zwpls.service" ] || [ -f "$HOME/Library/LaunchAgents/com.github.cocos-node.zwpls.plist" ]; then
        echo -e "  ${GREEN}✓${NC} 系统服务: 已安装"
        installed=1
    fi
    
    # 检查自动补全
    if [ -f "/etc/bash_completion.d/zwpls" ] || [ -f "$HOME/.bash_completion.d/zwpls" ] || [ -f "$HOME/.zsh/completion/_zwpls" ]; then
        echo -e "  ${GREEN}✓${NC} 自动补全: 已安装"
        installed=1
    fi
    
    if [ $installed -eq 0 ]; then
        log_warn "未检测到 zwpls 安装"
        return 1
    fi
    
    return 0
}

# 确认卸载
confirm_uninstall() {
    echo ""
    echo -e "${RED}${BOLD}⚠️  警告: 这将永久删除 zwpls 及其配置${NC}"
    echo ""
    echo -e "将删除以下内容:"
    echo -e "  ${YELLOW}•${NC} 主程序: /usr/local/bin/zwpls"
    echo -e "  ${YELLOW}•${NC} 配置目录: $CONFIG_DIR"
    echo -e "  ${YELLOW}•${NC} 自动补全文件"
    echo -e "  ${YELLOW}•${NC} 系统服务"
    echo ""
    
    if [ "${FORCE}" = "1" ]; then
        log_warn "强制模式，跳过确认"
        return
    fi
    
    read -rp "$(echo -e "${RED}确认卸载? [y/N]: ${NC}")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "卸载已取消"
        exit 0
    fi
    
    echo ""
}

# 备份配置
backup_config() {
    if [ ! -d "$CONFIG_DIR" ]; then
        return
    fi
    
    if [ "${BACKUP}" = "1" ]; then
        local backup_file="$HOME/zwpls_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        log_info "备份配置到: $backup_file"
        
        if tar -czf "$backup_file" -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")" 2>/dev/null; then
            log_success "配置备份完成"
            echo -e "  备份文件: ${BOLD}$backup_file${NC}"
            echo -e "  文件大小: ${BOLD}$(du -h "$backup_file" | cut -f1)${NC}"
        else
            log_error "配置备份失败"
        fi
    else
        log_warn "未备份配置 (使用 -b 选项启用备份)"
    fi
}

# 停止并删除服务
remove_service() {
    log_info "移除系统服务..."
    
    # systemd (Linux)
    if [ -f "/etc/systemd/system/zwpls.service" ]; then
        echo -e "  ${YELLOW}停止 systemd 服务...${NC}"
        sudo systemctl stop zwpls 2>/dev/null || true
        sudo systemctl disable zwpls 2>/dev/null || true
        
        echo -e "  ${YELLOW}删除服务文件...${NC}"
        sudo rm -f "/etc/systemd/system/zwpls.service"
        sudo systemctl daemon-reload 2>/dev/null || true
        
        log_success "systemd 服务已移除"
    fi
    
    # launchd (macOS)
    if [ -f "$HOME/Library/LaunchAgents/com.github.cocos-node.zwpls.plist" ]; then
        echo -e "  ${YELLOW}停止 launchd 服务...${NC}"
        launchctl unload "$HOME/Library/LaunchAgents/com.github.cocos-node.zwpls.plist" 2>/dev/null || true
        
        echo -e "  ${YELLOW}删除服务文件...${NC}"
        rm -f "$HOME/Library/LaunchAgents/com.github.cocos-node.zwpls.plist"
        
        log_success "launchd 服务已移除"
    fi
}

# 删除自动补全
remove_completion() {
    log_info "移除自动补全..."
    
    # Bash
    if [ -f "/etc/bash_completion.d/zwpls" ]; then
        echo -e "  ${YELLOW}删除系统自动补全...${NC}"
        sudo rm -f "/etc/bash_completion.d/zwpls"
    fi
    
    if [ -f "$HOME/.bash_completion.d/zwpls" ]; then
        echo -e "  ${YELLOW}删除用户自动补全...${NC}"
        rm -f "$HOME/.bash_completion.d/zwpls"
    fi
    
    # Zsh
    if [ -f "$HOME/.zsh/completion/_zwpls" ]; then
        echo -e "  ${YELLOW}删除 Zsh 自动补全...${NC}"
        rm -f "$HOME/.zsh/completion/_zwpls"
        
        # 清理 zshrc
        if [ -f "$HOME/.zshrc" ]; then
            sed -i.bak '/zwpls/d' "$HOME/.zshrc" 2>/dev/null || true
        fi
    fi
    
    # 清理 bashrc
    for rc_file in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        if [ -f "$rc_file" ]; then
            sed -i.bak '/zwpls/d' "$rc_file" 2>/dev/null || true
        fi
    done
    
    # 删除备份文件
    rm -f "$HOME/.bashrc.bak" "$HOME/.bash_profile.bak" \
          "$HOME/.profile.bak" "$HOME/.zshrc.bak" 2>/dev/null || true
    
    log_success "自动补全已移除"
}

# 删除主程序
remove_program() {
    log_info "移除主程序..."
    
    # 查找所有可能的安装位置
    local locations=(
        "/usr/local/bin/zwpls"
        "/usr/bin/zwpls"
        "$HOME/.local/bin/zwpls"
        "/opt/zwpls/zwpls"
    )
    
    for location in "${locations[@]}"; do
        if [ -f "$location" ]; then
            echo -e "  ${YELLOW}删除: $location${NC}"
            sudo rm -f "$location" 2>/dev/null || rm -f "$location"
        fi
    done
    
    # 检查是否真的删除了
    if command -v zwpls &> /dev/null; then
        log_error "无法删除主程序，请手动删除: $(which zwpls)"
    else
        log_success "主程序已移除"
    fi
}

# 删除配置目录
remove_config() {
    if [ ! -d "$CONFIG_DIR" ]; then
        return
    fi
    
    log_info "移除配置目录..."
    
    if [ "${KEEP_CONFIG}" = "1" ]; then
        log_warn "保留配置目录: $CONFIG_DIR"
        echo -e "  ${YELLOW}配置保留在:${NC} ${BOLD}$CONFIG_DIR${NC}"
        return
    fi
    
    echo -e "  ${YELLOW}删除目录: $CONFIG_DIR${NC}"
    
    # 显示目录内容
    if [ "${DEBUG}" = "1" ]; then
        echo "目录内容:"
        ls -la "$CONFIG_DIR" 2>/dev/null || true
    fi
    
    # 删除目录
    if rm -rf "$CONFIG_DIR" 2>/dev/null; then
        log_success "配置目录已移除"
    else
        # 尝试强制删除
        echo -e "  ${YELLOW}尝试强制删除...${NC}"
        sudo rm -rf "$CONFIG_DIR" 2>/dev/null || {
            log_error "无法删除配置目录，请手动删除: $CONFIG_DIR"
        }
    fi
}

# 清理缓存
clean_cache() {
    log_info "清理缓存文件..."
    
    local cache_files=(
        "$HOME/.cache/zwpls"
        "/tmp/zwpls_*"
        "/tmp/zwpls-*"
    )
    
    for pattern in "${cache_files[@]}"; do
        for file in $pattern; do
            if [ -e "$file" ]; then
                echo -e "  ${YELLOW}删除缓存: $file${NC}"
                rm -rf "$file" 2>/dev/null || true
            fi
        done
    done
    
    log_success "缓存已清理"
}

# 显示卸载统计
show_stats() {
    echo ""
    echo -e "${GREEN}${BOLD}✅ 卸载完成！${NC}"
    echo ""
    echo -e "${CYAN}已移除的内容:${NC}"
    
    if ! command -v zwpls &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} 主程序"
    else
        echo -e "  ${RED}✗${NC} 主程序 (可能未完全删除)"
    fi
    
    if [ ! -d "$CONFIG_DIR" ] || [ "${KEEP_CONFIG}" = "1" ]; then
        if [ "${KEEP_CONFIG}" = "1" ]; then
            echo -e "  ${YELLOW}⚠${NC} 配置目录 (已保留)"
        else
            echo -e "  ${GREEN}✓${NC} 配置目录"
        fi
    else
        echo -e "  ${RED}✗${NC} 配置目录 (可能未完全删除)"
    fi
    
    echo -e "  ${GREEN}✓${NC} 系统服务"
    echo -e "  ${GREEN}✓${NC} 自动补全"
    echo -e "  ${GREEN}✓${NC} 缓存文件"
    
    if [ "${BACKUP}" = "1" ] && [ -d "$CONFIG_DIR" ]; then
        echo ""
        echo -e "${CYAN}备份文件:${NC}"
        ls -lh "$HOME"/zwpls_backup_*.tar.gz 2>/dev/null | head -5 || true
    fi
    
    echo ""
    echo -e "${YELLOW}感谢使用 zwpls！${NC}"
    echo ""
}

# 显示帮助
show_help() {
    echo -e "${BOLD}zwpls 卸载脚本 v$VERSION${NC}"
    echo ""
    echo -e "${CYAN}使用方法:${NC}"
    echo -e "  $0 [选项]"
    echo ""
    echo -e "${CYAN}选项:${NC}"
    echo -e "  ${YELLOW}-y, --yes${NC}        自动确认，无需交互"
    echo -e "  ${YELLOW}-f, --force${NC}      强制卸载，不检查"
    echo -e "  ${YELLOW}-b, --backup${NC}     备份配置目录"
    echo -e "  ${YELLOW}-k, --keep-config${NC} 保留配置目录"
    echo -e "  ${YELLOW}-d, --debug${NC}      调试模式"
    echo -e "  ${YELLOW}-h, --help${NC}       显示此帮助"
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo -e "  ${YELLOW}$0${NC}                    交互式卸载"
    echo -e "  ${YELLOW}$0 -y${NC}                 自动卸载"
    echo -e "  ${YELLOW}$0 -y -b${NC}              自动卸载并备份"
    echo -e "  ${YELLOW}$0 --force${NC}           强制卸载"
    echo ""
    echo -e "${CYAN}在线卸载:${NC}"
    echo -e "  ${YELLOW}curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/uninstall.sh | bash${NC}"
    echo -e "  ${YELLOW}curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/uninstall.sh | bash -s -- -y${NC}"
    echo ""
    exit 0
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                FORCE=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -b|--backup)
                BACKUP=1
                shift
                ;;
            -k|--keep-config)
                KEEP_CONFIG=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                set -x
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    show_title
    
    # 解析参数
    parse_args "$@"
    
    # 检查安装
    if [ "${FORCE}" != "1" ]; then
        if ! check_installation; then
            echo ""
            read -rp "$(echo -e "${YELLOW}未检测到安装，是否继续? [y/N]: ${NC}")" confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "操作已取消"
                exit 0
            fi
        fi
    fi
    
    # 确认卸载
    confirm_uninstall
    
    # 备份配置
    backup_config
    
    # 执行卸载
    remove_service
    remove_completion
    remove_program
    remove_config
    clean_cache
    
    # 显示统计
    show_stats
}

# 错误处理
trap 'log_error "卸载被中断"; exit 1' INT TERM

# 运行主函数
main "$@"