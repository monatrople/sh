#!/bin/bash

# 检测并禁用 resolvconf 和 openresolv
if systemctl is-active --quiet resolvconf; then
  systemctl stop resolvconf
  systemctl disable resolvconf
  echo "resolvconf 已停止并禁用。"
fi

if systemctl is-active --quiet openresolv; then
  systemctl stop openresolv
  systemctl disable openresolv
  echo "openresolv 已停止并禁用。"
fi

# 删除 resolvconf 和 openresolv 包（如果它们存在）
if command -v apt-get &> /dev/null; then
  apt-get remove --purge -y resolvconf openresolv
elif command -v yum &> /dev/null; then
  yum remove -y resolvconf openresolv
elif command -v dnf &> /dev/null; then
  dnf remove -y resolvconf openresolv
elif command -v zypper &> /dev/null; then
  zypper remove -y resolvconf openresolv
else
  echo "无法确定包管理器。请手动删除 resolvconf 和 openresolv。"
fi
# 配置 systemd-resolved
cat <<EOF > /etc/systemd/resolved.conf
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=8.8.4.4 1.0.0.1
Domains=example.com
LLMNR=no
MulticastDNS=no
DNSSEC=no
Cache=yes
DNSStubListener=yes
EOF
# 启用并启动 systemd-resolved
systemctl enable systemd-resolved
systemctl start systemd-resolved

# 配置 /etc/resolv.conf 指向 systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 验证配置
if systemctl is-active --quiet systemd-resolved; then
  echo "systemd-resolved 已成功启动并配置。"
  echo "当前 DNS 配置："
  resolvectl status
else
  echo "systemd-resolved 启动失败。请检查日志。"
fi
