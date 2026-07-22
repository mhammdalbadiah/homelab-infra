#!/bin/bash

set -e  # exit immediately if any command fails





# ============================================================
#                 LocalStack Deployment Script
#        Automates LocalStack LXC + Docker setup on Proxmox VE
#          Run this on the Proxmox HOST as "root" :
#
#
#   chmod +x deploy.sh  " To make the file executeable !  " 
#   ./deploy.sh
# ============================================================



# -------------------- PARSE CONFIG --------------------
# Reads values from config.yaml in the same directory

CONFIG="$(dirname "$0")/config.yaml"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: config.yaml not found in $(dirname "$0")"
    echo "Make sure config.yaml is in the same directory as deploy.sh"
    exit 1
fi

parse_yaml() {
    grep -E "^\s+$1:" "$CONFIG" | head -1 | awk -F': ' '{print $2}' | sed 's/#.*//' | xargs
}

CTID=$(parse_yaml "id")
HOSTNAME=$(parse_yaml "hostname")
CORES=$(parse_yaml "cores")
RAM=$(parse_yaml "ram")
SWAP=$(parse_yaml "swap")
DISK_SIZE=$(parse_yaml "disk_size")
STORAGE=$(parse_yaml "lvm")
TEMPLATE_STORAGE=$(parse_yaml "templates")
BRIDGE=$(parse_yaml "bridge")
IP=$(parse_yaml "ip")
GATEWAY=$(parse_yaml "gateway")
LS_VERSION=$(parse_yaml "version")
LS_SERVICES=$(parse_yaml "services")

# password is prompted at runtime — never stored in files
echo ""
read -s -p "Enter root password for container: " PASSWORD
echo ""
read -s -p "Confirm password: " PASSWORD_CONFIRM
echo ""

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "ERROR: Passwords do not match."
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    echo "ERROR: Password cannot be empty."
    exit 1
fi

# -------------------------------------------------------



echo "========================================="
echo "  LocalStack LXC Deployment"
echo "========================================="
echo ""
echo "  Config loaded from: $CONFIG"
echo "  CTID: $CTID | Host: $HOSTNAME | IP: $IP"
echo "  LocalStack: v$LS_VERSION"
echo "  Services: $LS_SERVICES"
echo ""





# --- Step 1: Download the Debian template ---
echo ""
echo " [1/8] Updating template list..."
pveam update




echo ""
echo " [2/8] Finding Debian 12 template..."

TEMPLATE=$(pveam available --section system | grep "debian-12-standard" | awk '{print $2}' | tail -1)

if [ -z "$TEMPLATE" ]; then
    echo "ERROR: Could not find a Debian 12 template."
    echo "Run 'pveam available --section system' to check manually."
    exit 1
fi

echo "Found template: $TEMPLATE"


if pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
    echo "Template already downloaded, skipping."
else
    echo "Downloading..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi





# --- Step 2: Create the LXC container ---
echo ""
echo "[3/8] Creating LXC container (CTID: $CTID)..."


if pct status "$CTID" &>/dev/null; then
    echo "ERROR: Container $CTID already exists."
    echo "Either change the CTID or remove the existing container first."
    exit 1
fi


if [ "$IP" = "dhcp" ]; then
    NET_CONFIG="name=eth0,bridge=$BRIDGE,firewall=1,ip=dhcp,type=veth"
else
    NET_CONFIG="name=eth0,bridge=$BRIDGE,firewall=1,ip=$IP,gw=$GATEWAY,type=veth"
fi

pct create "$CTID" \
    "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
    --hostname "$HOSTNAME" \
    --storage "$STORAGE" \
    --rootfs "${STORAGE}:${DISK_SIZE}" \
    --cores "$CORES" \
    --memory "$RAM" \
    --swap "$SWAP" \
    --net0 "$NET_CONFIG" \
    --unprivileged 1 \
    --features nesting=1 \
    --password "$PASSWORD" \
    --onboot 1

echo "Container created."





# --- Step 3: Start the container ---
echo ""
echo "[4/8] Starting container..."
pct start "$CTID"

echo "Waiting for container to boot..."
sleep 15





# --- Step 4: Install Docker ---
echo ""
echo "[5/8] Installing Docker inside container..."

pct exec "$CTID" -- bash -c "
    apt update && apt upgrade -y
    apt install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \$(. /etc/os-release && echo \$VERSION_CODENAME) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
"

echo "Docker installed."





# --- Step 5: Run LocalStack ---
echo ""
echo "[6/8] Starting LocalStack v$LS_VERSION..."

pct exec "$CTID" -- bash -c "
    docker pull localstack/localstack:$LS_VERSION

    docker run -d \
        --name localstack \
        -p 4566:4566 \
        -p 4510-4559:4510-4559 \
        -e SERVICES=$LS_SERVICES \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --restart unless-stopped \
        localstack/localstack:$LS_VERSION
"

echo "LocalStack running."





# --- Step 6: Install AWS CLI ---
echo ""
echo "[7/8] Installing AWS CLI..."

pct exec "$CTID" -- bash -c "
    apt install -y unzip
    curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip

    # configure dummy credentials (LocalStack accepts anything)
    mkdir -p ~/.aws
    echo '[default]' > ~/.aws/credentials
    echo 'aws_access_key_id = test' >> ~/.aws/credentials
    echo 'aws_secret_access_key = test' >> ~/.aws/credentials

    echo '[default]' > ~/.aws/config
    echo 'region = us-east-1' >> ~/.aws/config
    echo 'output = json' >> ~/.aws/config

    # add awslocal alias
    echo 'alias awslocal=\"aws --endpoint-url=http://localhost:4566\"' >> ~/.bashrc
"

echo "AWS CLI installed and configured."





# --- Step 7: Verify ---
echo ""
echo "[8/8] Verifying LocalStack..."

# give LocalStack a moment to finish starting up
sleep 10

pct exec "$CTID" -- bash -c "curl -s http://localhost:4566/_localstack/health | python3 -m json.tool"





echo ""
echo "========================================="
echo "  Deployment Complete"
echo "========================================="
echo ""
echo "  Container ID:   $CTID"
echo "  Hostname:       $HOSTNAME"
echo "  IP:             $IP"
echo "  LocalStack:     v$LS_VERSION"
echo "  Services:       $LS_SERVICES"
echo "  Endpoint:       http://<container-ip>:4566"
echo ""
echo "  QUICK TEST:"
echo "  pct enter $CTID"
echo "  source ~/.bashrc"
echo "  awslocal s3 mb s3://test-bucket"
echo "  awslocal s3 ls"
echo ""
echo "========================================="




