#!/bin/bash
# install.sh - 极简一键安装脚本

set -e

echo "🚀 开始安装 zwpls..."

# 检查依赖
check_deps() {
    echo "🔍 检查依赖..."
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        echo "📦 安装 curl..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        elif command -v brew &> /dev/null; then
            brew install curl
        else
            echo "❌ 请先安装 curl"
            exit 1
        fi
    fi
    
    # 检查 jq
    if ! command -v jq &> /dev/null; then
        echo "📦 安装 jq..."
        if command -v apt-get &> /dev/null; then
            apt-get install -y jq
        elif command -v yum &> /dev/null; then
            yum install -y jq
        elif command -v brew &> /dev/null; then
            brew install jq
        else
            echo "⚠️  jq 未安装，部分功能可能受限"
        fi
    fi
}

# 下载安装
install() {
    echo "📥 下载主程序..."
    
    # 创建必要的目录
    mkdir -p /usr/local/bin
    mkdir -p ~/.config/zwpls
    
    # 下载主程序
    curl -fsSL -o /tmp/zwpls.sh \
        https://raw.githubusercontent.com/cocos-node/zwpls/main/zwpls.sh
    
    if [ ! -s /tmp/zwpls.sh ]; then
        echo "❌ 下载失败"
        exit 1
    fi
    
    # 安装
    sudo mv /tmp/zwpls.sh /usr/local/bin/zwpls
    sudo chmod +x /usr/local/bin/zwpls
    
    # 创建配置文件
    if [ ! -f ~/.config/zwpls/commands.json ]; then
        echo '[]' > ~/.config/zwpls/commands.json
    fi
    
    echo "✅ 安装完成！"
}

# 显示帮助
show_help() {
    echo "使用方法: zwpls [命令]"
    echo "示例:"
    echo "  zwpls                      # 交互式使用"
    echo "  zwpls add 名称 命令       # 添加命令"
    echo "  zwpls help                # 查看帮助"
}

# 主流程
main() {
    check_deps
    install
    
    echo ""
    echo "✨ 安装成功！"
    echo ""
    echo "使用示例:"
    echo "  zwpls                     # 启动"
    echo "  zwpls add 测试 echo test  # 添加命令"
    echo "  zwpls 测试               # 执行命令"
    echo ""
    echo "输入 'zwpls' 开始使用！"
}

main