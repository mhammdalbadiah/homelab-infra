#!/bin/bash

set -e  # exit immediately if any command fails





# ============================================================
#                 Nextcloud Deployment Script
#         Automates TurnKey Nextcloud LXC setup on Proxmox VE
#          Run this on the Proxmox HOST as "root" :
#
#
#   chmod +x deploy.sh  " To make the file executeable !  " 
#   ./deploy.sh
# ============================================================



# -------------------- PARSE CONFIG --------------------
# Reads values from config.yaml in the same directory
# Uses grep + awk so we don't need a yaml parser installed
# Only works with flat "key: value" pairs (no nested objects)

CONFIG="$(dirname "$0")/config.yaml"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: config.yaml not found in $(dirname "$0")"
    echo "Make sure config.yaml is in the same directory as deploy.sh"
    exit 1
fi

# parse_yaml pulls a value from config.yaml by key name
# example: parse_yaml "hostname" returns "nextcloud"
parse_yaml() {
    grep -E "^\s+$1:" "$CONFIG" | head -1 | awk -F': ' '{print $2}' | sed 's/#.*//' | xargs
}

CTID=$(parse_yaml "id")
HOSTNAME=$(parse_yaml "hostname")
PASSWORD=$(parse_yaml "password")
CORES=$(parse_yaml "cores")
RAM=$(parse_yaml "ram")
SWAP=$(parse_yaml "swap")
DISK_SIZE=$(parse_yaml "disk_size")
STORAGE=$(parse_yaml "lvm")
TEMPLATE_STORAGE=$(parse_yaml "templates")
HOST_DATA_DIR=$(parse_yaml "host_data")
CONTAINER_DATA_DIR=$(parse_yaml "container_data")
BRIDGE=$(parse_yaml "bridge")
IP=$(parse_yaml "ip")
GATEWAY=$(parse_yaml "gateway")

# -------------------------------------------------------



echo "========================================="
echo "  Nextcloud LXC Deployment"
echo "========================================="
echo ""
echo "  Config loaded from: $CONFIG"
echo "  CTID: $CTID | Host: $HOSTNAME | IP: $IP"
echo ""





# --- Step 1: Download the TurnKey template ---
echo ""
echo " [1/7] Updating template list..."
pveam update




echo ""
echo " [2/7] Finding Nextcloud template ..."

# grab the latest turnkey-nextcloud template name from the available list
TEMPLATE=$(pveam available --section turnkeylinux | grep nextcloud | awk '{print $2}' | tail -1)





if [ -z "$TEMPLATE" ]; then
    echo "ERROR: Could not find a TurnKey Nextcloud template."
    echo "Run 'pveam available --section turnkeylinux' to check manually."
    exit 1
fi

echo "Found template: $TEMPLATE"




# check if already downloaded
if pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
    echo "Template already downloaded, skipping."
else
    echo "Downloading..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi





# --- Step 2: Create the host data directory ---
echo ""
echo "[3/7] Preparing host data directory..."
if [ ! -d "$HOST_DATA_DIR" ]; then
    mkdir -p "$HOST_DATA_DIR"
    echo "Created $HOST_DATA_DIR"
else
    echo "$HOST_DATA_DIR already exists, skipping."
fi





# --- Step 3: Create the LXC container ---
echo ""
echo "[4/7] Creating LXC container (CTID: $CTID)..."


# check if container already exists
if pct status "$CTID" &>/dev/null; then
    echo "ERROR: Container $CTID already exists."
    echo "Either change the CTID or remove the existing container first."
    exit 1
fi


# set up network string
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
    --onboot 1 \
    --startup order=3

echo "Container created."





# --- Step 4: Add the data drive mount point ---
echo ""
echo "[5/7] Mounting data drive into container..."
pct set "$CTID" -mp0 "$HOST_DATA_DIR,mp=$CONTAINER_DATA_DIR"
echo "Mounted $HOST_DATA_DIR → $CONTAINER_DATA_DIR"







# --- Step 5: Start the container ---
echo ""
echo "[6/7] Starting container..."
pct start "$CTID"



# wait for the container to fully boot
echo "Waiting for container to boot..."
sleep 15







# --- Step 6: Run post-boot setup inside the container ---
echo ""
echo "[7/7] Running post-boot configuration..."



# fix ownership on the mounted data directory
pct exec "$CTID" -- bash -c "chown -R www-data:www-data $CONTAINER_DATA_DIR"
echo "Set ownership on $CONTAINER_DATA_DIR"


# install tailscale
pct exec "$CTID" -- bash -c "curl -fsSL https://tailscale.com/install.sh | sh"
echo "Tailscale installed."





echo ""
echo "========================================="
echo "  Deployment Complete"
echo "========================================="
echo ""
echo "  Container ID:   $CTID"
echo "  Hostname:       $HOSTNAME"
echo "  IP:             $IP"
echo "  Data Mount:     $HOST_DATA_DIR → $CONTAINER_DATA_DIR"
echo ""
echo "  NEXT STEPS:"
echo "  1. Open the Proxmox console for CT $CTID"
echo "     and complete the TurnKey first-boot wizard"
echo "     (set Nextcloud admin password, etc.)"
echo ""
echo "  2. Run 'tailscale up' inside the container"
echo "     to authenticate with your Tailscale account"
echo ""
echo "  3. Add the Tailscale IP to trusted_domains in:"
echo "     /var/www/nextcloud/config/config.php"
echo ""
echo "========================================="




