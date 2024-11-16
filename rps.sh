#!/bin/sh

# 安装 bc 如果没有安装
bc -v > /dev/null || yum install bc -y || apt install bc -y

# 设置 RPS 流量条目数
sysctl -w net.core.rps_sock_flow_entries=65536

# 获取 CPU 核心数
cc=$(grep -c processor /proc/cpuinfo)

# 检查 CPU 核心数是否为零
if [ "$cc" -eq 0 ]; then
    echo "无法获取 CPU 核心数。"
    exit 1
fi

rfc=$(echo 65536/$cc | bc)

# 设置 RPS 流量条目数
for fileRfc in $(ls /sys/class/net/e*/queues/rx-*/rps_flow_cnt); do
    echo $rfc > $fileRfc
done

# 计算 RPS 相关的 CPU 核心配置
c=$(bc -l << EOF
a1=l($cc)
a2=l(2)
scale=0
a1/a2
EOF
)

# 检查 c 计算结果是否有效
if [ -z "$c" ]; then
    echo "RPS 计算结果为空，无法继续执行。"
    exit 1
fi

# 根据计算结果生成 CPU 核心分配
cpus=$(echo $c | awk '{for(i=1;i<$1-1;i++){printf "f"}}')
cpuss=$(echo $c | awk '{for(i=1;i<$1;i++){printf "f"}}')
cpusss=$(echo $c | awk '{for(i=1;i<=$1;i++){printf "f"}}')
cpussss=$(echo $c | awk '{for(i=1;i<=$1+1;i++){printf "f"}}')

# 打印调试信息，检查变量是否正常
echo "计算结果：c=$c"
echo "cpus=$cpus"
echo "cpuss=$cpuss"
echo "cpusss=$cpusss"
echo "cpussss=$cpussss"

# 为每个网卡接口设置 RPS CPU 核心
for fileRps in $(ls /sys/class/net/e*/queues/rx-*/rps_cpus); do
    # 限制字符数量，避免过多的输出导致错误
    echo $cpus | head -c 1024 > $fileRps
    echo $cpuss | head -c 1024 > $fileRps
    echo $cpusss | head -c 1024 > $fileRps
    echo $cpussss | head -c 1024 > $fileRps
done
