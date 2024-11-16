#!/bin/sh  # 使用 sh

# 检查是否是 Debian 系统
check_debian() {
  if grep -qi "debian" /etc/os-release; then
    echo "当前系统是 Debian 系统。"
  else
    echo "当前系统不是 Debian 系统。脚本中止。"
    exit 1
  fi
}

# 检查是否是 Arch 系统
check_arch() {
  if grep -qi "arch" /etc/os-release; then
    echo "当前系统是 Arch Linux 系统。"
  else
    echo "当前系统不是 Arch Linux 系统。脚本中止。"
    exit 1
  fi
}

# 更新系统并安装必要的软件包（Debian 系统）
install_packages_debian() {
  apt update && apt upgrade -y && apt autoremove -y && apt install -y bc gpg curl wget dnsutils net-tools bash-completion systemd-resolved htpdate vim nftables
}

# 更新系统并安装必要的软件包（Arch 系统）
install_packages_arch() {
  pacman -Syu --noconfirm && pacman -S --noconfirm bc curl wget dnsutils net-tools bash-completion htpdate vim nftables
}

# 配置 DNS 设置
configure_dns() {
    if command -v resolvconf >/dev/null 2>&1; then
        echo "检测到 resolvconf，正在卸载..."
        apt remove -y resolvconf
    fi
    if command -v openresolv >/dev/null 2>&1; then
        echo "检测到 openresolv，正在卸载..."
        apt remove -y openresolv
    fi
    rm -f /etc/resolv.conf
    cat << EOF > /etc/systemd/resolved.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1
FallbackDNS=8.8.8.8 8.8.4.4
EOF
    systemctl unmask systemd-resolved
    systemctl enable systemd-resolved
    systemctl restart systemd-resolved
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

# 配置 htpdate 服务
configure_htpdate() {
  cat << EOF > /etc/default/htpdate
HTP_SERVERS="www.google.com"
HTP_OPTIONS="-D -s"
EOF
  systemctl restart htpdate
}

# 配置 sysctl 参数
configure_sysctl() {
  rm -rf /etc/sysctl.conf
  rm -rf /etc/sysctl.d/*
  ln -s /etc/sysctl.d/99-custom.conf /etc/sysctl.conf

  # 创建 /etc/sysctl.d/99-custom.conf 并写入配置
  cat <<EOF >/etc/sysctl.d/99-custom.conf
fs.file-max=1000000
fs.inotify.max_user_instances=131072
kernel.msgmnb=65536
kernel.msgmax=65536
kernel.shmall=4294967296
kernel.shmmax=68719476736
net.core.default_qdisc=fq_pie
net.core.netdev_max_backlog=4194304
net.core.rmem_max=33554432
net.core.rps_sock_flow_entries=65536
net.core.somaxconn=65536
net.core.wmem_max=33554432
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.ip_forward=1
net.ipv4.icmp_echo_ignore_all=0
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_ecn=0
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_fack=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_frto=0
net.ipv4.tcp_keepalive_intvl=60
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_max_syn_backlog=4194304
net.ipv4.tcp_max_tw_buckets=262144
net.ipv4.tcp_mem=786432 1048576 3145728
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_orphan_retries=1
net.ipv4.tcp_rmem=16384 131072 67108864
net.ipv4.tcp_sack=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_syn_retries=1
net.ipv4.tcp_synack_retries=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_tw_reuse=0
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.ping_group_range=0 2147483647
net.ipv4.ip_local_port_range=10000 49999
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.all.autoconf=1
vm.dirty_background_bytes=52428800
vm.dirty_background_ratio=0
vm.dirty_bytes=52428800
vm.dirty_ratio=40
vm.swappiness=20
EOF

  chmod 644 /etc/sysctl.d/99-custom.conf
  adjust_tcp_mem
  sysctl --system
}

# 根据内存调整 tcp_mem 参数
adjust_tcp_mem() {
  total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  total_memory_gb=$(echo "$total_memory / 1024 / 1024" | bc)

  if [ "$total_memory_gb" -lt 4 ]; then    
      sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=262144 786432 2097152#g" /etc/sysctl.d/99-custom.conf
  elif [ "$total_memory_gb" -ge 4 ] && [ "$total_memory_gb" -lt 7 ]; then
      sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=524288 1048576 2097152#g" /etc/sysctl.d/99-custom.conf
  elif [ "$total_memory_gb" -ge 7 ] && [ "$total_memory_gb" -lt 11 ]; then    
      sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=786432 1048576 3145728#g" /etc/sysctl.d/99-custom.conf
  elif [ "$total_memory_gb" -ge 11 ] && [ "$total_memory_gb" -lt 15 ]; then    
      sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=1048576 1572864 3145728#g" /etc/sysctl.d/99-custom.conf
  elif [ "$total_memory_gb" -ge 15 ]; then
      sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=1048576 2097152 3145728#g" /etc/sysctl.d/99-custom.conf
  fi
}

# 配置文件最大限制
configure_limits() {
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
}

# 配置 systemd 参数
configure_systemd() {
  cat <<EOF >/etc/systemd/system.conf
[Manager]
DefaultTimeoutStopSec=30s
DefaultLimitCORE=infinity
DefaultLimitNOFILE=20480000
DefaultLimitNPROC=20480000
EOF

  mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
  echo -e "[Service]\nTimeoutStartSec=1sec" > /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
  systemctl daemon-reload
  systemctl daemon-reexec

  cat <<EOF >/etc/systemd/journald.conf
[Journal]
SystemMaxUse=512M
EOF
}

# 添加 Arch Linux CN 源
add_archlinuxcn_repo() {
    local mirror="https://repo.archlinuxcn.org/\$arch"
    # 检查是否已经添加过 Arch Linux CN 源
    if grep -q "^\[archlinuxcn\]" /etc/pacman.conf; then
        echo "Arch Linux CN 源已经存在，跳过添加。"
    else
        echo -e "\n[archlinuxcn]\nSigLevel = Never\nServer = ${mirror}" | tee -a /etc/pacman.conf > /dev/null
    fi
    pacman -Sy --noconfirm
    echo "正在安装 archlinuxcn-keyring..."
    pacman -S --noconfirm archlinuxcn-keyring
}

setup_rps_optimization() {
    # 1. 创建 RPS 优化脚本
    SCRIPT_PATH="/usr/local/bin/rps.sh"
    
    echo "正在创建 RPS 优化脚本..."

    cat << 'EOF' > $SCRIPT_PATH
#!/bin/bash

# 安装 bc 如果没有安装
bc -v > /dev/null || yum install bc -y || apt install bc -y

# 设置 RPS 流量条目数
sysctl -w net.core.rps_sock_flow_entries=65536

# 获取 CPU 核心数
cc=$(grep -c processor /proc/cpuinfo)
rfc=$(echo 65536/$cc | bc)

# 设置 RPS 流量条目数
for fileRfc in $(ls /sys/class/net/e*/queues/rx-*/rps_flow_cnt); do
    echo $rfc > $fileRfc
done

# 计算 RPS 相关的 CPU 核心配置
c=$(bc -l -q << EOF
a1=l($cc)
a2=l(2)
scale=0
a1/a2
EOF
)

cpus=$(echo $c | awk '{for(i=1;i<$1-1;i++){printf "f"}}')
cpuss=$(echo $c | awk '{for(i=1;i<$1;i++){printf "f"}}')
cpusss=$(echo $c | awk '{for(i=1;i<=$1;i++){printf "f"}}')
cpussss=$(echo $c | awk '{for(i=1;i<=$1+1;i++){printf "f"}}')

# 为每个网卡接口设置 RPS CPU 核心
for fileRps in $(ls /sys/class/net/e*/queues/rx-*/rps_cpus); do
    echo $cpus > $fileRps
    echo $cpuss > $fileRps
    echo $cpusss > $fileRps
    echo $cpussss > $fileRps
done
EOF

    # 给脚本文件添加执行权限
    chmod +x $SCRIPT_PATH
    echo "RPS 优化脚本创建并设置执行权限完成。"

    # 2. 创建 systemd 服务文件
    SERVICE_PATH="/etc/systemd/system/rps.service"
    
    echo "正在创建 systemd 服务文件..."

    cat << EOF > $SERVICE_PATH
[Unit]
Description=RPS Optimization Script
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # 3. 重新加载 systemd 配置并启用服务
    echo "重新加载 systemd 配置并启用服务..."

    systemctl daemon-reload
    systemctl enable rps.service
    systemctl start rps.service

    echo "RPS 优化服务已启用并启动。"

    # 4. 检查服务状态
    systemctl status rps.service --no-pager
}

# 主函数
main() {
  echo "">/etc/motd
  if grep -qi "debian" /etc/os-release; then
    check_debian
    install_packages_debian
  elif grep -qi "arch" /etc/os-release; then
    check_arch
    add_archlinuxcn_repo
    install_packages_arch
  else
    echo "不支持的操作系统。脚本中止。"
    exit 1
  fi
  configure_dns
  configure_htpdate
  configure_sysctl
  configure_limits
  configure_systemd
  setup_rps_optimization
}

# 调用主函数
main
