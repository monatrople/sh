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

if [ -z "$name" ] || [ -z "$webapi_url" ] || [ -z "$webapi_key" ] || [ -z "$server_type" ]|| [ -z "$soga_key" ] || [ -z "$node_id" ]
then
    echo "Usage: \$0 name=<name> webapi_url=<webapi_url> webapi_key=<webapi_key> server_type=<server_type> soga_key=<soga_key> node_id=<node_id>"
    exit 1
fi

InstallDocker(){

cat <<EOF >/etc/apt/preferences.d/docker
Package: docker docker.io docker-compose 
Pin: release *
Pin-Priority: -1
EOF

if command -v docker &> /dev/null; then
    docker_version=$(docker --version | awk '{print $3}')
    echo -e "${green}Docker已安装,版本号：$docker_version"
else
    echo -e "${green} 开始安装 Docker"
    if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
      export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
    fi
    sh <(curl -k 'https://get.docker.com') &> /dev/null
    rm -rf /opt/containerd
    echo -e "${green} Docker 安装完成"
fi

sed -i '/alias dc/d' ~/.bashrc
if command -v docker-compose &> /dev/null; then
    if ! grep -q "alias dc" ~/.bashrc; then
      echo "alias dc='docker-compose'" >>~/.bashrc
    fi
    
else
    if ! grep -q "alias dc" ~/.bashrc; then
      echo "alias dc='docker compose'" >>~/.bashrc
    fi
fi
source ~/.bashrc
}

SysOptimize(){
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

total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_memory_bytes=$((total_memory * 1024))
total_memory_gb=$(awk "BEGIN {printf \"%.2f\", $total_memory / 1024 / 1024}")
nf_conntrack_max=$((total_memory_bytes / 16384 ))
nf_conntrack_buckets=$((nf_conntrack_max / 4))
sed -i "s#.*net.netfilter.nf_conntrack_max = .*#net.netfilter.nf_conntrack_max = ${nf_conntrack_max}#g" /etc/sysctl.conf
sed -i "s#.*net.netfilter.nf_conntrack_buckets = .*#net.netfilter.nf_conntrack_buckets = ${nf_conntrack_buckets}#g" /etc/sysctl.conf
#<4GB 1G_3G_8G
if [[ ${total_memory_gb//.*/} -lt 4 ]]; then    
    sed -i "s#.*net.ipv4.tcp_mem =.*#net.ipv4.tcp_mem =262144 786432 2097152#g" /etc/sysctl.conf
#6GB 2G_4G_8G
elif [[ ${total_memory_gb//.*/} -ge 4 && ${total_memory_gb//.*/} -lt 7 ]]; then
    sed -i "s#.*net.ipv4.tcp_mem =.*#net.ipv4.tcp_mem =524288 1048576 2097152#g" /etc/sysctl.conf
#8GB 3G_4G_12G
elif [[ ${total_memory_gb//.*/} -ge 7 && ${total_memory_gb//.*/} -lt 11 ]]; then    
    sed -i "s#.*net.ipv4.tcp_mem =.*#net.ipv4.tcp_mem =786432 1048576 3145728#g" /etc/sysctl.conf
#12GB 4G_6G_12G
elif [[ ${total_memory_gb//.*/} -ge 11 && ${total_memory_gb//.*/} -lt 15 ]]; then    
    sed -i "s#.*net.ipv4.tcp_mem =.*#net.ipv4.tcp_mem =1048576 1572864 3145728#g" /etc/sysctl.conf
#>16GB 4G_8G_12G
elif [[ ${total_memory_gb//.*/} -ge 15 ]]; then
    sed -i "s#.*net.ipv4.tcp_mem =.*#net.ipv4.tcp_mem =1048576 2097152 3145728#g" /etc/sysctl.conf
fi
sysctl -p &> /dev/null
  
echo "1000000" > /proc/sys/fs/file-max
sed -i '/ulimit -SHn/d' /etc/profile
echo "ulimit -SHn 1000000" >>/etc/profile
ulimit -SHn 1000000 && ulimit -c unlimited

cat <<EOF >/etc/security/limits.conf
*     soft   nofile    1048576
*     hard   nofile    1048576
*     soft   nproc     1048576
*     hard   nproc     1048576
*     soft   core      1048576
*     hard   core      1048576
*     hard   memlock   unlimited
*     soft   memlock   unlimited
EOF

cat <<EOF >/etc/systemd/system.conf
[Manager]
DefaultTimeoutStopSec=30s
DefaultLimitCORE=infinity
DefaultLimitNOFILE=20480000
DefaultLimitNPROC=20480000
EOF

systemctl daemon-reload
systemctl daemon-reexec

cat <<EOF >/etc/systemd/journald.conf
[Journal]
SystemMaxUse=512M
EOF
echo -e "${green}系统优化完成"
}

DeplaySoga(){
apt install -y wget;
mkdir -p /opt/$name
mkdir -p /opt/$name/config
cd /opt/$name

wget -q https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat -O config/geoip.dat
wget -q https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat -O config/geosite.dat

cat << EOF > docker-compose.yaml
---
services:
  $name:
    image: vaxilu/soga:latest
    container_name: $name
    restart: always
    network_mode: host
    environment:
      log_level: info
      type: v2board
      api: webapi
      webapi_url: $webapi_url
      webapi_key: $webapi_key
      soga_key: $soga_key
      server_type: $server_type
      node_id: $node_id
      sniff_redirect: 'true'
      proxy_protocol: 'true'
      udp_proxy_protocol: 'true'
      detect_packet: 'true'
      ban_private_ip: 'true'
      forbidden_bit_torrent: 'true'
      force_vmess_aead: 'true'
      ss_invalid_access_enable: 'true'
      ss_invalid_access_forbidden_time: 180
      vmess_aead_invalid_access_enable: 'true'
      vmess_aead_invalid_access_forbidden_time: '180'
      geo_update_enable: 'true'
      block_list_url: 'https://raw.githubusercontent.com/monatrople/rulelist/refs/heads/main/blockList'
    volumes:
      - "./config:/etc/soga/"
EOF
if command -v docker-compose &> /dev/null; then
  docker-compose up -d
else
  docker compose up -d
fi
}

InstallDocker
SysOptimize
DeplaySoga
