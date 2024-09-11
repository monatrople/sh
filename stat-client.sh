#!/bin/sh

WORKSPACE=/opt/stat_client

# 默认参数值
a_value=""
g_value=""
p_value=""
w_value=""
alias_value=""
n_flag=0
location_value=""

# 清空工作目录
clear_workspace() {
    echo "Clearing workspace: ${WORKSPACE}"
    if [ -d "$WORKSPACE" ]; then
        rm -rf "${WORKSPACE:?}/*"
    fi
    mkdir -p "$WORKSPACE"
    cd "$WORKSPACE" || exit
}

# 打印帮助信息
usage() {
    echo "Usage: $0 -a <url> -g <group> -p <password> --alias <alias> [--location <location>] [-w <w_value>] [-n]"
    exit 1
}

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root."
        exit 1
    fi
}

# 检查是否是systemd系统
check_systemd() {
    if ! pidof systemd > /dev/null; then
        echo "Error: This system does not use systemd."
        exit 1
    fi
}

# 检查并安装指定的软件包
check_and_install_package() {
    package=$1
    if ! command -v "$package" > /dev/null; then
        echo "$package is not installed. Installing $package..."
        if command -v apt-get > /dev/null; then
            apt-get update && apt-get install -y "$package"
        elif command -v yum > /dev/null; then
            yum install -y "$package"
        else
            echo "Unsupported package manager. Please install $package manually."
            exit 1
        fi
    else
        echo "$package is already installed."
    fi
}

# 检查并安装 wget 和 unzip
check_wget_unzip() {
    check_and_install_package wget
    check_and_install_package unzip
}

# 检查并安装 vnstat
check_and_install_vnstat() {
    check_and_install_package vnstat
}

# 解析命令行参数的函数
parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -a)
            a_value="$2"
            shift 2
            ;;
        -g)
            g_value="$2"
            shift 2
            ;;
        -p)
            p_value="$2"
            shift 2
            ;;
        -w)
            w_value="$2"
            shift 2
            ;;
        --alias)
            alias_value="$2"
            shift 2
            ;;
        --location)
            location_value="$2"
            shift 2
            ;;
        -n)
            n_flag=1
            shift 1
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
        esac
    done

    # 检查必需的参数是否已指定
    if [ -z "$a_value" ]; then
        echo "Error: -a <url> is required."
        usage
    fi

    if [ -z "$g_value" ]; then
        echo "Error: -g <group> is required."
        usage
    fi

    if [ -z "$p_value" ]; then
        echo "Error: -p <password> is required."
        usage
    fi

    if [ -z "$alias_value" ]; then
        echo "Error: --alias <alias> is required."
        usage
    fi
}

# 生成命令的函数
build_cmd() {
    cmd="$WORKSPACE/stat_client -a \"$a_value\" -g \"$g_value\" -p \"$p_value\" --alias \"$alias_value\""

    if [ -n "$w_value" ]; then
        cmd="$cmd -w $w_value"
    fi

    if [ "$n_flag" -eq 1 ]; then
        cmd="$cmd -n"
    fi

    if [ -n "$location_value" ]; then
        cmd="$cmd --location \"$location_value\""
    fi

    echo "$cmd"
}

# 下载并安装客户端的函数
install_client() {
    OS_ARCH="x86_64"
    latest_version=$(curl -m 10 -sL "https://api.github.com/repos/zdz/ServerStatus-Rust/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

    if [ -z "$latest_version" ]; then
        echo "Error: Unable to fetch the latest version."
        exit 1
    fi

    wget --no-check-certificate -qO "client-${OS_ARCH}-unknown-linux-musl.zip" "https://github.com/zdz/ServerStatus-Rust/releases/download/${latest_version}/client-${OS_ARCH}-unknown-linux-musl.zip"
    unzip -o "client-${OS_ARCH}-unknown-linux-musl.zip"
    rm *.zip
}

# 配置 systemd 服务的函数
configure_service() {
    cmd=$(build_cmd)
    echo "cmd:$cmd"
    rm -r stat_client.service
    cat << EOF > /etc/systemd/system/stat_client.service
[Unit]
Description=Stat Client
After=network.target

[Service]
User=root
Group=root
Environment="RUST_BACKTRACE=1"
WorkingDirectory=$WORKSPACE
ExecStart=$cmd
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable stat_client
    systemctl restart stat_client
    systemctl status stat_client
}

# 主函数
main() {
    # 检查是否为root用户和是否是systemd系统
    check_root
    check_systemd
    clear_workspace

    # 解析参数
    parse_args "$@"

    # 检查并安装 wget 和 unzip
    check_wget_unzip

    # 如果指定了-n参数，检查并安装vnStat
    if [ "$n_flag" -eq 1 ]; then
        check_and_install_vnstat
    fi

    # 安装客户端
    install_client

    # 配置systemd服务
    configure_service
}

# 调用主函数
main "$@"
