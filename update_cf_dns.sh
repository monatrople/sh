#!/bin/bash

# 检查参数数量
if [ "$#" -ne 4 ]; then
    echo "用法: $0 API_KEY ZONE SUBDOMAIN IP"
    exit 1
fi

# 从参数中读取配置
API_KEY=$1
ZONE=$2
SUBDOMAIN=$3
NEW_IP=$4

# 检查是否已安装 jq
if ! command -v jq &> /dev/null; then
    echo "jq 未安装，正在尝试安装 jq..."
    
    # 尝试自动安装 jq
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y jq
    elif command -v yum &> /dev/null; then
        yum install -y jq
    elif command -v dnf &> /dev/null; then
        dnf install -y jq
    elif command -v zypper &> /dev/null; then
        zypper install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        echo "无法自动安装 jq，请手动安装 jq。"
        exit 1
    fi
fi

# Cloudflare API URL
CF_API_BASE="https://api.cloudflare.com/client/v4"

# 获取 Zone ID
ZONE_ID=$(curl -s -X GET "$CF_API_BASE/zones?name=$ZONE" \
-H "Authorization: Bearer $API_KEY" \
-H "Content-Type: application/json" | jq -r '.result[0].id')

# 检查是否成功获取 Zone ID
if [ -z "$ZONE_ID" ]; then
    echo "无法找到 Zone ID。请检查配置。"
    exit 1
fi

# 获取 DNS 记录 ID
DNS_RECORD_ID=$(curl -s -X GET "$CF_API_BASE/zones/$ZONE_ID/dns_records?name=$SUBDOMAIN.$ZONE" \
-H "Authorization: Bearer $API_KEY" \
-H "Content-Type: application/json" | jq -r '.result[0].id')

if [ -z "$DNS_RECORD_ID" ]; then
    # DNS 记录不存在，创建新的记录
    response=$(curl -s -X POST "$CF_API_BASE/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary "{\"type\":\"A\",\"name\":\"$SUBDOMAIN.$ZONE\",\"content\":\"$NEW_IP\",\"ttl\":120,\"proxied\":false}")

    # 输出响应结果
    echo "响应结果:"
    echo "$response"

    # 检查是否创建成功
    if echo "$response" | grep -q '"success":true'; then
        echo "DNS 记录创建成功！"
    else
        echo "DNS 记录创建失败。"
    fi
else
    # DNS 记录存在，更新记录
    response=$(curl -s -X PUT "$CF_API_BASE/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary "{\"type\":\"A\",\"name\":\"$SUBDOMAIN.$ZONE\",\"content\":\"$NEW_IP\",\"ttl\":120,\"proxied\":false}")

    # 输出响应结果
    echo "响应结果:"
    echo "$response"

    # 检查是否更新成功
    if echo "$response" | grep -q '"success":true'; then
        echo "DNS 记录更新成功！"
    else
        echo "DNS 记录更新失败。"
    fi
fi
