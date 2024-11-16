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
  apt update && apt upgrade -y && apt autoremove -y && apt install -y bc gpg curl wget dnsutils net-tools bash-completion systemd-resolved vim nftables
}

# 更新系统并安装必要的软件包（Arch 系统）
install_packages_arch() {
  pacman -Syu --noconfirm && pacman -S --noconfirm bc curl wget dnsutils net-tools bash-completion vim nftables
}

# 配置 DNS 设置
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

# 配置 sysctl 参数
configure_sysctl() {
  rm -rf /etc/sysctl.conf
  rm -rf /etc/sysctl.d/*
  ln -s /etc/sysctl.d/99-custom.conf /etc/sysctl.conf

  # 创建 /etc/sysctl.d/99-custom.conf 并写入配置
  cat <<EOF >/etc/sysctl.d/99-custom.conf
kernel.msgmnb=65536
kernel.msgmax=65536
kernel.shmmax=68719476736
kernel.shmall=4294967296
vm.swappiness=1
vm.dirty_background_bytes=52428800
vm.dirty_bytes=52428800
vm.dirty_ratio=0
vm.dirty_background_ratio=0

net.core.rps_sock_flow_entries=65536 #rfs 设置此文件至同时活跃连接数的最大预期值
#net.ipv4.icmp_echo_ignore_all=1 #禁止ping
#net.ipv4.icmp_echo_ignore_broadcasts=1

fs.file-max=1000000
fs.inotify.max_user_instances=131072
#开启路由转发
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1

# AWS这种dhcp的貌似是不能开ipv6转发的
# 开了转发 需要开 accept_ra=2 才能正常使用SPAAC SLAAC
# 注意开了转发会导致dhcp的v6获取失败
net.ipv6.conf.all.forwarding=0
net.ipv6.conf.default.forwarding=0
net.ipv6.conf.lo.forwarding=0
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.lo.disable_ipv6=0

net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2

net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.all.rp_filter=0

net.ipv4.tcp_syncookies=1
net.ipv4.tcp_retries1=3
net.ipv4.tcp_retries2=5
net.ipv4.tcp_orphan_retries=1
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_max_tw_buckets=262144
net.ipv4.tcp_max_syn_backlog=4194304
net.core.netdev_max_backlog=4194304
net.core.somaxconn=65536
net.ipv4.tcp_notsent_lowat=16384
# net.tcp_timestamps=0
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=60

# TCP窗口
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=16384 131072 67108864
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_mem=262144 1048576 4194304
net.ipv4.udp_mem=262144 1048576 4194304
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
net.ipv4.ip_local_port_range=10000 65535
net.ipv4.ping_group_range=0 2147483647
EOF
  chmod 644 /etc/sysctl.d/99-custom.conf
  sysctl --system
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

setup_rps_optimization() {
    SCRIPT_PATH="/usr/local/bin/rps.sh"
    wget https://raw.githubusercontent.com/monatrople/sh/refs/heads/main/rps.sh -O $SCRIPT_PATH
    chmod +x $SCRIPT_PATH
    SERVICE_PATH="/etc/systemd/system/rps.service"
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
    install_packages_arch
  else
    echo "不支持的操作系统。脚本中止。"
    exit 1
  fi
  configure_dns
  configure_sysctl
  configure_limits
  configure_systemd
}

# 调用主函数
main
