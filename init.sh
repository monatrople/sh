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
  apt update && apt upgrade -y && apt autoremove -y && apt install -y bc gpg curl wget dnsutils net-tools bash-completion systemd-resolved systemd-timesyncd vim nftables vnstat
}

# 更新系统并安装必要的软件包（Arch 系统）
install_packages_arch() {
  pacman -Syu --noconfirm && pacman -S --noconfirm bc curl wget dnsutils net-tools bash-completion vim nftables vnstat
}

configure_dns() {
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

configure_timesync() {
    rm -f /etc/systemd/timesyncd.conf
    cat << EOF > /etc/systemd/timesyncd.conf
[Time]
NTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=ntp.ubuntu.com time.apple.com
EOF
    systemctl unmask systemd-timesyncd
    systemctl enable systemd-timesyncd
    systemctl restart systemd-timesyncd
}

configure_sysctl() {
rm -rf /etc/sysctl.conf
rm -rf /etc/sysctl.d/*
ln -s /etc/sysctl.d/99-custom.conf /etc/sysctl.conf
cat <<EOF >/etc/sysctl.d/99-custom.conf
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
}

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

enable_vnstat() {
  systemctl enable vnstat.service --now
}

main() {
  echo "">/etc/motd
  if grep -qi "debian" /etc/os-release; then
    check_debian
    install_packages_debian
  elif grep -qi "arch" /etc/os-release; then
    check_arch
    install_packages_arch
  else
    echo "不支持的操作系统。脚本中止。"
    exit 1
  fi
  configure_dns
  configure_timesync
  configure_sysctl
  configure_limits
  configure_systemd
  enable_vnstat
}

# 调用主函数
main
