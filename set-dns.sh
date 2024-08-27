#!/bin/bash

  # 检查 systemd-resolved 是否已安装，如果未安装则尝试自动安装
  if ! command -v systemctl > /dev/null 2>&1 || ! systemctl list-unit-files | grep -q systemd-resolved; then
    echo "systemd-resolved 未安装。正在尝试自动安装..."
    
    if command -v apt-get &> /dev/null; then
      apt-get update > /dev/null 2>&1
      apt-get install -y systemd > /dev/null 2>&1
    elif command -v yum &> /dev/null; then
      yum install -y systemd > /dev/null 2>&1
    elif command -v dnf &> /dev/null; then
      dnf install -y systemd > /dev/null 2>&1
    elif command -v zypper &> /dev/null; then
      zypper install -y systemd > /dev/null 2>&1
    else
      echo "无法确定包管理器。请手动安装 systemd-resolved。"
      return 1
    fi

    # 再次检查 systemd-resolved 是否成功安装
    if ! systemctl list-unit-files | grep -q systemd-resolved; then
      echo "systemd-resolved 安装失败。请手动安装并重试。"
      return 1
    fi

    echo "systemd-resolved 安装成功。"
  fi

# 检测并禁用 resolvconf 和 openresolv
if systemctl is-active --quiet resolvconf; then
  systemctl stop resolvconf > /dev/null
  systemctl disable resolvconf > /dev/null
  echo "resolvconf 已停止并禁用。"
fi

if systemctl is-active --quiet openresolv; then
  systemctl stop openresolv > /dev/null
  systemctl disable openresolv > /dev/null
  echo "openresolv 已停止并禁用。"
fi

# 删除 resolvconf 和 openresolv 包（如果它们存在）
if command -v apt-get &> /dev/null; then
  apt-get remove --purge -y resolvconf openresolv > /dev/null
elif command -v yum &> /dev/null; then
  yum remove -y resolvconf openresolv > /dev/null
elif command -v dnf &> /dev/null; then
  dnf remove -y resolvconf openresolv > /dev/null
elif command -v zypper &> /dev/null; then
  zypper remove -y resolvconf openresolv > /dev/null
else
  echo "无法确定包管理器。请手动删除 resolvconf 和 openresolv。"
fi
# 配置 systemd-resolved
cat <<EOF > /etc/systemd/resolved.conf
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=8.8.4.4 1.0.0.1
EOF
# 启用并启动 systemd-resolved
systemctl enable systemd-resolved > /dev/null
systemctl start systemd-resolved > /dev/null

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
