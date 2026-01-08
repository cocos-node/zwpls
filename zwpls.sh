#!/bin/bash

# zwpls - 跨平台快捷命令管理器

# 配置目录和文件
CONFIG_DIR="${HOME}/.config/zwpls"
COMMANDS_FILE="${CONFIG_DIR}/commands.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查依赖
check_dependencies() {
    local missing=()
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        echo "请安装依赖:"
        echo "  macOS:   brew install jq"
        echo "  Ubuntu:  sudo apt-get install jq"
        echo "  CentOS:  sudo yum install jq"
        echo "  Arch:    sudo pacman -S jq"
        return 1
    fi
    
    return 0
}

# 确保命令文件存在
ensure_commands_file() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
    
    if [ ! -f "$COMMANDS_FILE" ] || [ ! -s "$COMMANDS_FILE" ]; then
        echo '[]' > "$COMMANDS_FILE"
    fi
}

# 添加命令
add_command() {
    local name cmd
    
    if [ $# -ge 2 ]; then
        # 直接从参数获取
        name="$1"
        shift
        cmd="$*"
    else
        # 交互式输入
        read -rp "请输入命令名称: " name
        [ -z "$name" ] && { log_error "名称不能为空"; return 1; }
        
        read -rp "请输入命令: " cmd
        [ -z "$cmd" ] && { log_error "命令不能为空"; return 1; }
    fi
    
    ensure_commands_file
    
    # 检查是否已存在
    if jq -e --arg name "$name" '.[] | select(.name == $name)' "$COMMANDS_FILE" >/dev/null 2>&1; then
        log_error "命令 '$name' 已存在"
        return 1
    fi
    
    # 添加命令
    local temp_file
    temp_file=$(mktemp 2>/dev/null || mktemp -t zwpls)
    
    if jq --arg name "$name" --arg cmd "$cmd" \
         '. + [{"name": $name, "command": $cmd}]' \
         "$COMMANDS_FILE" > "$temp_file"; then
        mv "$temp_file" "$COMMANDS_FILE"
        log_success "已添加命令: $name"
    else
        log_error "添加失败"
        [ -f "$temp_file" ] && rm -f "$temp_file"
        return 1
    fi
}

# 执行命令
execute_command() {
    [ $# -eq 0 ] && { list_commands; return; }
    
    local name="$1"
    shift
    local extra_args="$*"
    
    ensure_commands_file
    
    # 查找命令
    local cmd
    cmd=$(jq -r --arg name "$name" '.[] | select(.name == $name) | .command' "$COMMANDS_FILE" 2>/dev/null)
    
    if [ -z "$cmd" ] || [ "$cmd" = "null" ]; then
        log_error "未找到命令: $name"
        
        # 显示相似命令
        local similar
        similar=$(jq -r --arg name "$name" '.[] | select(.name | contains($name)) | .name' "$COMMANDS_FILE" 2>/dev/null | head -5)
        
        [ -n "$similar" ] && echo -e "${CYAN}相似命令:${NC}\n$similar"
        
        return 1
    fi
    
    # 构建完整命令
    local full_cmd="$cmd"
    [ -n "$extra_args" ] && full_cmd="$cmd $extra_args"
    
    echo -e "${GREEN}执行: $name${NC}"
    echo -e "${CYAN}命令: $full_cmd${NC}"
    echo -e "${MAGENTA}------------------${NC}"
    
    # 确认执行
    if [ -t 0 ]; then
        read -rp "是否执行? [Y/n]: " -n 1 confirm
        echo
        [[ "$confirm" =~ ^[Nn]$ ]] && { log_warn "已取消"; return; }
    fi
    
    # 执行命令
    eval "$full_cmd"
}

# 列出命令
list_commands() {
    ensure_commands_file
    
    local count
    count=$(jq 'length' "$COMMANDS_FILE" 2>/dev/null || echo "0")
    
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}没有存储的命令${NC}"
        echo "使用: zwpls add \"名称\" \"命令\" 添加命令"
        return
    fi
    
    echo -e "${GREEN}存储的命令 ($count 个):${NC}"
    echo "=========================="
    
    # 显示命令列表
    jq -r 'to_entries[] | "\(.key+1). \(.value.name)\n   命令: \(.value.command)"' "$COMMANDS_FILE"
    
    # 如果是在终端中，提供选择功能
    if [ -t 0 ]; then
        echo "=========================="
        read -rp "输入编号执行命令 (直接回车退出): " choice
        
        if [[ -n "$choice" && "$choice" =~ ^[0-9]+$ && "$choice" -le "$count" && "$choice" -gt 0 ]]; then
            local name cmd
            name=$(jq -r ".[$((choice-1))].name" "$COMMANDS_FILE")
            cmd=$(jq -r ".[$((choice-1))].command" "$COMMANDS_FILE")
            
            read -rp "额外参数: " extra_args
            
            local full_cmd="$cmd"
            [ -n "$extra_args" ] && full_cmd="$cmd $extra_args"
            
            echo -e "${GREEN}执行: $name${NC}"
            echo -e "${CYAN}命令: $full_cmd${NC}"
            echo
            
            read -rp "确认执行? [Y/n]: " -n 1 confirm
            echo
            [[ ! "$confirm" =~ ^[Nn]$ ]] && eval "$full_cmd"
        fi
    fi
}

# 删除命令
delete_command() {
    [ $# -eq 0 ] && { log_error "需要指定命令名称"; return 1; }
    
    local name="$1"
    ensure_commands_file
    
    if ! jq -e --arg name "$name" '.[] | select(.name == $name)' "$COMMANDS_FILE" >/dev/null 2>&1; then
        log_error "未找到命令: $name"
        return 1
    fi
    
    # 确认删除
    read -rp "确认删除命令 '$name'? [y/N]: " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { log_warn "已取消"; return; }
    
    # 删除命令
    local temp_file
    temp_file=$(mktemp 2>/dev/null || mktemp -t zwpls)
    
    if jq --arg name "$name" 'del(.[] | select(.name == $name))' "$COMMANDS_FILE" > "$temp_file"; then
        mv "$temp_file" "$COMMANDS_FILE"
        log_success "已删除: $name"
    else
        log_error "删除失败"
        [ -f "$temp_file" ] && rm -f "$temp_file"
    fi
}

# 搜索命令
search_commands() {
    [ $# -eq 0 ] && { log_error "需要搜索关键词"; return 1; }
    
    local keyword="$1"
    ensure_commands_file
    
    echo -e "${CYAN}搜索结果:${NC}"
    echo "=========================="
    
    local results
    results=$(jq -r --arg keyword "$keyword" '.[] | 
        select(.name | contains($keyword) or .command | contains($keyword)) | 
        "\(.name) - \(.command)"' "$COMMANDS_FILE" 2>/dev/null)
    
    if [ -n "$results" ]; then
        echo "$results"
    else
        echo -e "${YELLOW}未找到相关命令${NC}"
    fi
}

# 编辑命令
edit_command() {
    [ $# -eq 0 ] && { log_error "需要指定命令名称"; return 1; }
    
    local name="$1"
    ensure_commands_file
    
    # 获取当前命令
    local current_cmd
    current_cmd=$(jq -r --arg name "$name" '.[] | select(.name == $name) | .command' "$COMMANDS_FILE" 2>/dev/null)
    
    if [ -z "$current_cmd" ] || [ "$current_cmd" = "null" ]; then
        log_error "未找到命令: $name"
        return 1
    fi
    
    echo -e "${CYAN}当前命令: $current_cmd${NC}"
    read -rp "新命令: " new_cmd
    
    [ -z "$new_cmd" ] && { log_error "命令不能为空"; return 1; }
    
    # 更新命令
    local temp_file
    temp_file=$(mktemp 2>/dev/null || mktemp -t zwpls)
    
    if jq --arg name "$name" --arg new_cmd "$new_cmd" \
         'map(if .name == $name then .command = $new_cmd else . end)' \
         "$COMMANDS_FILE" > "$temp_file"; then
        mv "$temp_file" "$COMMANDS_FILE"
        log_success "已更新: $name"
    else
        log_error "更新失败"
        [ -f "$temp_file" ] && rm -f "$temp_file"
    fi
}

# 备份命令
backup_commands() {
    local backup_file="${CONFIG_DIR}/commands_$(date +%Y%m%d_%H%M%S).json"
    ensure_commands_file
    
    cp "$COMMANDS_FILE" "$backup_file"
    log_success "备份已保存到: $backup_file"
}

# 恢复命令
restore_commands() {
    [ $# -eq 0 ] && { log_error "需要指定备份文件"; return 1; }
    
    local backup_file="$1"
    [ ! -f "$backup_file" ] && { log_error "文件不存在: $backup_file"; return 1; }
    
    # 验证JSON
    if ! jq empty "$backup_file" 2>/dev/null; then
        log_error "无效的JSON文件"
        return 1
    fi
    
    # 备份当前文件
    local current_backup="${CONFIG_DIR}/commands_backup_$(date +%Y%m%d_%H%M%S).json"
    [ -f "$COMMANDS_FILE" ] && cp "$COMMANDS_FILE" "$current_backup"
    
    # 恢复
    cp "$backup_file" "$COMMANDS_FILE"
    log_success "已从备份恢复"
    [ -f "$current_backup" ] && echo "原配置已备份到: $current_backup"
}

# 卸载命令
cmd_uninstall() {
    echo -e "${RED}⚠️  警告: 这将卸载 zwpls${NC}"
    echo ""
    echo -e "将删除:"
    echo -e "  • 主程序: $(which zwpls 2>/dev/null || echo "/usr/local/bin/zwpls")"
    echo -e "  • 配置目录: $CONFIG_DIR"
    echo -e "  • 自动补全文件"
    echo ""
    
    read -rp "确认卸载? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        return
    fi
    
    echo -e "\n${YELLOW}正在卸载...${NC}"
    
    # 在线卸载
    if command -v curl &> /dev/null; then
        curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/uninstall.sh | bash -s -- -y
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/cocos-node/zwpls/main/uninstall.sh | bash -s -- -y
    else
        echo -e "${RED}需要 curl 或 wget 来执行在线卸载${NC}"
        echo "请手动运行:"
        echo "  curl -sSL https://raw.githubusercontent.com/cocos-node/zwpls/main/uninstall.sh | bash"
    fi
}


# 显示帮助
show_help() {
    cat << EOF
${GREEN}zwpls - 快捷命令管理器${NC}
${CYAN}===============================${NC}

${YELLOW}使用方法:${NC}
  zwpls [命令] [参数...]

${YELLOW}命令:${NC}
  add [名称] [命令]    添加命令
  del <名称>           删除命令
  edit <名称>          编辑命令
  list                 列出所有命令
  search <关键词>      搜索命令
  backup               备份命令
  restore <文件>       从备份恢复
  uninstall        卸载
  help                 显示帮助

${YELLOW}示例:${NC}
  zwpls                        # 交互式选择执行命令
  zwpls sshserver              # 直接执行命令
  zwpls sshserver -p 22        # 带参数执行
  zwpls add "ll" "ls -la"     # 添加命令
  zwpls del "ll"              # 删除命令
  zwpls edit "ll"             # 编辑命令
  zwpls search "ssh"          # 搜索命令
  zwpls backup                 # 备份
  zwpls restore backup.json   # 恢复
  zwpls uninstall             # 卸载

${YELLOW}提示:${NC}
  - 不带参数运行可交互式选择命令
  - 命令名称支持中文
  - 支持命令后追加参数
EOF
}

# 主函数
main() {
    # 检查依赖
    check_dependencies || return 1
    
    # 子命令处理
    case "${1:-}" in
        "add")
            shift
            add_command "$@"
            ;;
        "del"|"rm"|"remove")
            shift
            delete_command "$@"
            ;;
        "edit"|"update")
            shift
            edit_command "$@"
            ;;
        "list"|"ls"|"l")
            list_commands
            ;;
        "search"|"find"|"grep")
            shift
            search_commands "$@"
            ;;
        "backup"|"export")
            backup_commands
            ;;
        "restore"|"import")
            shift
            restore_commands "$@"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        uninstall)
            cmd_uninstall
            ;;
        *)
            # 没有子命令，尝试执行
            execute_command "$@"
            ;;
    esac
}

# 运行主函数
main "$@"