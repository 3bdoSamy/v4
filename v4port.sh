#!/bin/bash

# o11-v4 Port Changer
# Script by: 3BdALLaH

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then error "Please run as root or use sudo"; fi

echo -e "${CYAN}"
echo "================================================"
echo "         o11-v4 Port Changer"
echo "           Script by: 3BdALLaH"
echo "================================================"
echo -e "${NC}"

CONTAINER_NAME="o11"
DOCKER_IMAGE="o11-v4"

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    error "Container '$CONTAINER_NAME' not found. Is o11-v4 installed?"
fi

# Get current ports
step "Current port mapping:"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "$CONTAINER_NAME"

echo ""
echo "Usage: curl -sSL https://raw.githubusercontent.com/3bdoSamy/v4/main/v4port.sh | sudo bash -s -- [HTTP_PORT] [HTTPS_PORT] [LICENSE_PORT] [PANEL_PORT]"
echo ""
echo "Example: curl -sSL https://raw.githubusercontent.com/3bdoSamy/v4/main/v4port.sh | sudo bash -s -- 8080 8443 6000 9000"
echo ""

# Get ports from command line arguments or use defaults
if [ $# -eq 4 ]; then
    WEB_PORT=$1
    SSL_PORT=$2
    LICENSE_PORT=$3
    PANEL_PORT=$4
else
    echo "No ports specified. Using default ports:"
    WEB_PORT="80"
    SSL_PORT="443"
    LICENSE_PORT="5454"
    PANEL_PORT="8484"
fi

# Validate ports
validate_port() {
    local port=$1
    local service=$2
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error "Invalid $service port: $port. Must be between 1-65535"
    fi
}

validate_port "$WEB_PORT" "HTTP"
validate_port "$SSL_PORT" "HTTPS"
validate_port "$LICENSE_PORT" "License"
validate_port "$PANEL_PORT" "Admin Panel"

step "Using ports: HTTP=$WEB_PORT, HTTPS=$SSL_PORT, License=$LICENSE_PORT, Panel=$PANEL_PORT"

# Get container environment variables
IP_ADDRESS=$(docker inspect $CONTAINER_NAME --format '{{range .Config.Env}}{{println .}}{{end}}' | grep IP_ADDRESS | cut -d= -f2)
SERVER_TYPE=$(docker inspect $CONTAINER_NAME --format '{{range .Config.Env}}{{println .}}{{end}}' | grep SERVER_TYPE | cut -d= -f2)

if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
fi

SERVER_TYPE=${SERVER_TYPE:-"nodejs"}

step "Stopping and removing current container..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

step "Starting new container with updated ports..."
docker run -d \
  -p $WEB_PORT:80 \
  -p $SSL_PORT:443 \
  -p $LICENSE_PORT:5454 \
  -p $PANEL_PORT:8484 \
  -e IP_ADDRESS="$IP_ADDRESS" \
  -e SERVER_TYPE="$SERVER_TYPE" \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  "$DOCKER_IMAGE"

step "Updating firewall rules..."
if command -v ufw >/dev/null 2>&1 && systemctl is-active --quiet ufw; then
    # Remove old rules (approximate)
    ufw delete allow 80/tcp 2>/dev/null || true
    ufw delete allow 443/tcp 2>/dev/null || true
    ufw delete allow 5454/tcp 2>/dev/null || true
    ufg delete allow 8484/tcp 2>/dev/null || true
    
    # Add new rules
    ufw allow $WEB_PORT/tcp >/dev/null 2>&1
    ufw allow $SSL_PORT/tcp >/dev/null 2>&1
    ufw allow $LICENSE_PORT/tcp >/dev/null 2>&1
    ufw allow $PANEL_PORT/tcp >/dev/null 2>&1
    success "Firewall updated for new ports"
fi

step "Waiting for container to start..."
sleep 5

if docker ps | grep -q $CONTAINER_NAME; then
    success "Container restarted successfully with new ports!"
    echo ""
    echo -e "${GREEN}New Port Configuration:${NC}"
    echo "Web HTTP:     http://$IP_ADDRESS:$WEB_PORT"
    echo "Web HTTPS:    https://$IP_ADDRESS:$SSL_PORT"
    echo "Admin Panel:  http://$IP_ADDRESS:$PANEL_PORT"
    echo "License:      http://$IP_ADDRESS:$LICENSE_PORT"
    echo ""
    echo -e "${YELLOW}Note: If you changed ports, update your bookmarks and applications accordingly.${NC}"
else
    error "Failed to start container with new ports. Check logs: docker logs $CONTAINER_NAME"
fi

echo ""
echo -e "${CYAN}================================================"
echo "Port change completed by 3BdALLaH"
echo -e "================================================${NC}"
