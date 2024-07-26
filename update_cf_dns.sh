#!/bin/sh

# Function to check if a command exists
command_exists() {
    command -v $1 >/dev/null 2>&1
}

# Function to install jq
install_jq() {
    if command_exists apt-get; then
        apt-get update && apt-get install -y jq
    elif command_exists yum; then
        yum install -y jq
    elif command_exists dnf; then
        dnf install -y jq
    elif command_exists zypper; then
        zypper install -y jq
    elif command_exists brew; then
        brew install jq
    else
        echo "Unable to automatically install jq, please install jq manually."
        exit 1
    fi
}

# Function to perform API calls to Cloudflare
cloudflare_api_call() {
    method=$1
    url=$2
    data=$3

    curl -s -X $method "$url" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" $data
}

# Function to update DNS records
update_dns_record() {
    record_type=$1
    record_name=$2
    content=$3
    record_id=$4
    method="POST"

    if [ -n "$record_id" ]; then
        method="PUT"
    fi

    response=$(cloudflare_api_call $method "$CF_API_BASE/zones/$ZONE_ID/dns_records/$record_id" \
    --data-binary "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$content\",\"ttl\":120,\"proxied\":false}")

    echo "Response:"
    echo "$response"

    if echo "$response" | grep -q '"success":true'; then
        echo "DNS record $method successful!"
    else
        echo "DNS record $method failed."
    fi
}

# Main function
main() {
    if [ "$#" -ne 4 ]; then
        echo "Usage: $0 API_KEY ZONE SUBDOMAIN IP"
        exit 1
    fi

    API_KEY=$1
    ZONE=$2
    SUBDOMAIN=$3
    NEW_IP=$4

    # Check and install jq if necessary
    if ! command_exists jq; then
        echo "jq is not installed, attempting to install jq..."
        install_jq
    fi

    CF_API_BASE="https://api.cloudflare.com/client/v4"

    # Get Zone ID
    ZONE_ID=$(cloudflare_api_call "GET" "$CF_API_BASE/zones?name=$ZONE" "" | jq -r '.result[0].id')

    if [ -z "$ZONE_ID" ]; then
        echo "Could not find Zone ID. Please check your configuration."
        exit 1
    fi

    # Get DNS Record ID
    DNS_RECORD_ID=$(cloudflare_api_call "GET" "$CF_API_BASE/zones/$ZONE_ID/dns_records?name=$SUBDOMAIN.$ZONE" "" | jq -r '.result[0].id')

    if [ -z "$DNS_RECORD_ID" ]; then
        update_dns_record "A" "$SUBDOMAIN.$ZONE" "$NEW_IP" ""
    else
        update_dns_record "A" "$SUBDOMAIN.$ZONE" "$NEW_IP" "$DNS_RECORD_ID"
    fi
}

# Start the script
main "$@"
