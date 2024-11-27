#!/bin/bash

name=""
webapi_url=""
webapi_key=""
server_type=""
node_id=""
soga_key=""

for arg in "$@"
do
    case $arg in
        name=*)
            name="${arg#*=}"
            ;;
        webapi_url=*)
            webapi_url="${arg#*=}"
            ;;
        webapi_key=*)
            webapi_key="${arg#*=}"
            ;;
        server_type=*)
            server_type="${arg#*=}"
            ;;
        node_id=*)
            node_id="${arg#*=}"
            ;;
        soga_key=*)
            soga_key="${arg#*=}"
            ;;
    esac
done

if [ -z "$name" ] || [ -z "$webapi_url" ] || [ -z "$webapi_key" ] || [ -z "$server_type" ] || [ -z "$soga_key" ] || [ -z "$node_id" ]; then
    echo "Usage: \$0 name=<name> webapi_url=<webapi_url> webapi_key=<webapi_key> server_type=<server_type> soga_key=<soga_key> node_id=<node_id>"
    exit 1
fi

# 安装 Docker
InstallDocker() {
    if [ -f /etc/arch-release ]; then
        echo "检测到 Arch Linux 系统，使用 pacman 安装 Docker。"
        pacman -S --noconfirm docker docker-compose
    else
        # 为 Ubuntu/Debian 系列添加 Docker 配置
        cat <<EOF >/etc/apt/preferences.d/docker
Package: docker docker.io docker-compose
Pin: release *
Pin-Priority: -1
EOF

        if command -v docker &>/dev/null; then
            docker_version=$(docker --version | awk '{print $3}')
            echo -e "Docker 已安装，版本：$docker_version"
        else
            echo -e "开始安装 Docker..."
            curl -fsSL https://get.docker.com | sh
            rm -rf /opt/containerd
            echo -e "Docker 安装完成。"
        fi
    fi
}

# 系统优化
SysOptimize() {
    rm -rf /etc/sysctl.d/*
    cat <<EOF >/etc/sysctl.conf
fs.file-max = 1000000
fs.inotify.max_user_instances = 131072
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmall = 4294967296
kernel.shmmax = 68719476736
net.core.default_qdisc = fq
net.core.netdev_max_backlog = 4194304
net.core.rmem_max = 33554432
net.core.rps_sock_flow_entries = 65536
net.core.somaxconn = 65536
net.core.wmem_max = 33554432
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.all.route_localnet = 1
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.ip_forward = 1
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fack = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_frto = 0
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_max_syn_backlog = 4194304
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_mem = 786432 1048576 3145728
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_orphan_retries = 1
net.ipv4.tcp_rmem = 16384 131072 67108864
net.ipv4.tcp_sack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.ping_group_range = 0 2147483647
net.ipv4.ip_local_port_range = 10000 49999
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.all.autoconf=1
net.netfilter.nf_conntrack_max = 65535
net.netfilter.nf_conntrack_buckets = 16384
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15
net.netfilter.nf_conntrack_tcp_timeout_established = 300
vm.dirty_background_bytes = 52428800
vm.dirty_background_ratio = 0
vm.dirty_bytes = 52428800
vm.dirty_ratio = 40
vm.swappiness = 20
EOF

    sysctl -p &>/dev/null
    echo -e "系统优化完成。"
}

# 部署 Soga 服务
DeplaySoga() {
    pacman -S --noconfirm wget
    mkdir -p /opt/$name
    mkdir -p /opt/$name/config
    cd /opt/$name
    cat <<EOF > .env
log_level=debug
type=v2board
api=webapi
webapi_url=$webapi_url
webapi_key=$webapi_key
soga_key=$soga_key
server_type=$server_type
node_id=$node_id
proxy_protocol=true
udp_proxy_protocol=true
detect_packet=true
forbidden_bit_torrent=true
force_vmess_aead=true
ss_invalid_access_enable=true
ss_invalid_access_forbidden_time=180
vmess_aead_invalid_access_enable=true
vmess_aead_invalid_access_forbidden_time=180
geo_update_enable=true
block_list_url=https://raw.githubusercontent.com/monatrople/rulelist/refs/heads/main/blockList
EOF

    # 下载必要的规则文件
    wget -q https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat -O config/geoip.dat
    wget -q https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat -O config/geosite.dat

    # 创建 docker-compose.yaml 文件
    cat <<EOF > docker-compose.yaml
---
services:
  ${name}:
    image: vaxilu/soga:latest
    container_name: ${name}
    restart: always
    network_mode: host
    env_file:
      - .env
    volumes:
      - "./config:/etc/soga/"
EOF

    # 使用 docker-compose 启动容器
    if command -v docker-compose &>/dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
}

# 执行安装、优化和部署函数
InstallDocker
SysOptimize
DeplaySoga
