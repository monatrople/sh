#!/bin/sh

echo "检查当前系统的初始化系统..."

# 检测初始化系统是否为 systemd
INIT_SYSTEM=$(ps -p 1 -o comm=)
if [ "$INIT_SYSTEM" != "systemd" ]; then
  echo "当前系统不是使用 systemd。脚本只支持 systemd，正在退出..."
  exit 1
fi

echo "系统使用 systemd，继续执行脚本..."

# 确保systemd-resolved 已安装
if ! command -v systemctl > /dev/null 2>&1 || ! systemctl list-unit-files | grep -q 'systemd-resolved.service'; then
  echo "systemd-resolved 未安装。正在尝试自动安装..."
  manage_packages "install" "systemd" "systemd-resolved 安装成功。" "systemd-resolved 安装失败。请手动安装并重试。" || exit 1
fi

# 禁用和删除 resolvconf 和 openresolv
SERVICES="resolvconf openresolv"
for svc in $SERVICES; do
  if systemctl is-active --quiet "$svc"; then
    systemctl stop "$svc" > /dev/null
    systemctl disable "$svc" > /dev/null
    echo "$svc 已停止并禁用。"
  fi
done

# 删除 resolvconf 和 openresolv 包
manage_packages() {
  local operation=$1
  local package_action=$2
  local success_message=$3
  local fail_message=$4

  if command -v apt-get > /dev/null 2>&1; then
    apt-get update > /dev/null
    apt-get "$operation" -y $package_action > /dev/null
  elif command -v yum > /dev/null 2>&1; then
    yum "$operation" -y $package_action > /dev/null
  elif command -v dnf > /dev/null 2>&1; then
    dnf "$operation" -y $package_action > /dev/null
  elif command -v zypper > /dev/null 2>&1; then
    zypper "$operation" -y $package_action > /dev/null
  else
    echo "无法确定包管理器。请手动执行操作。"
    return 1
  fi

  if [ $? -eq 0 ]; then
    echo "$success_message"
  else
    echo "$fail_message"
    return 1
  fi
}
manage_packages "remove --purge" "resolvconf openresolv" "resolvconf 和 openresolv 已移除。" "无法删除 resolvconf 和 openresolv。"

# 配置 systemd-resolved
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=8.8.4.4 1.0.0.1
EOF

echo "systemd-resolved 配置文件已更新。"

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
