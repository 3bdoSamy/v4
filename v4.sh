#!/bin/bash

# o11-v4 Professional Installer
# Version: 2.0.4
# Script by: 3BdALLaH

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
IP_ADDRESS=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
SERVER_TYPE="nodejs"
DOCKER_IMAGE="o11-v4"
CONTAINER_NAME="o11"

# Default ports
WEB_PORT="80"
SSL_PORT="443"
LICENSE_PORT="5454"
PANEL_PORT="8484"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root or use sudo"
fi

# Display header
echo -e "${CYAN}"
echo "================================================"
echo "       o11-v4 Professional Installer"
echo "           Script by: 3BdALLaH"
echo "================================================"
echo -e "${NC}"

# Port selection function
select_ports() {
    echo -e "${CYAN}"
    echo "           PORT CONFIGURATION"
    echo "================================================"
    echo -e "${NC}"
    
    echo "Enter port numbers or press Enter for defaults:"
    read -rp "Web HTTP port [80]: " input_web
    read -rp "Web HTTPS port [443]: " input_ssl
    read -rp "License server port [5454]: " input_license
    read -rp "Admin Panel port [8484]: " input_panel
    
    # Set ports or use defaults
    WEB_PORT=${input_web:-80}
    SSL_PORT=${input_ssl:-443}
    LICENSE_PORT=${input_license:-5454}
    PANEL_PORT=${input_panel:-8484}
    
    # Validate ports
    if ! [[ "$WEB_PORT" =~ ^[0-9]+$ ]] || [ "$WEB_PORT" -lt 1 ] || [ "$WEB_PORT" -gt 65535 ]; then
        error "Invalid HTTP port: $WEB_PORT. Must be between 1-65535"
    fi
    if ! [[ "$SSL_PORT" =~ ^[0-9]+$ ]] || [ "$SSL_PORT" -lt 1 ] || [ "$SSL_PORT" -gt 65535 ]; then
        error "Invalid HTTPS port: $SSL_PORT. Must be between 1-65535"
    fi
    if ! [[ "$LICENSE_PORT" =~ ^[0-9]+$ ]] || [ "$LICENSE_PORT" -lt 1 ] || [ "$LICENSE_PORT" -gt 65535 ]; then
        error "Invalid License port: $LICENSE_PORT. Must be between 1-65535"
    fi
    if ! [[ "$PANEL_PORT" =~ ^[0-9]+$ ]] || [ "$PANEL_PORT" -lt 1 ] || [ "$PANEL_PORT" -gt 65535 ]; then
        error "Invalid Panel port: $PANEL_PORT. Must be between 1-65535"
    fi
    
    success "Ports configured: HTTP=$WEB_PORT, HTTPS=$SSL_PORT, License=$LICENSE_PORT, Panel=$PANEL_PORT"
}

# Check port availability
check_port_availability() {
    local port=$1
    local service=$2
    
    if command -v ss >/dev/null 2>&1 && ss -tulpn 2>/dev/null | grep -q ":$port "; then
        warning "Port $port ($service) is already in use!"
        read -rp "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Installation cancelled by user"
        fi
    fi
}

# Main installation
step "Starting port configuration..."
select_ports

step "Checking port availability..."
check_port_availability "$WEB_PORT" "HTTP"
check_port_availability "$SSL_PORT" "HTTPS"
check_port_availability "$LICENSE_PORT" "License"
check_port_availability "$PANEL_PORT" "Admin Panel"

step "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y docker.io docker-compose unzip curl wget

step "Starting Docker service..."
systemctl start docker
systemctl enable docker

step "Downloading o11-v4..."
wget -q https://senator.pages.dev/v4.zip -O v4.zip
if [ ! -f v4.zip ]; then
    error "Failed to download v4.zip"
fi

step "Extracting files..."
unzip -q v4.zip -d o11-v4-install
cd o11-v4-install/o11-v4-main

step "Creating fixed start.sh..."
cat > start.sh << 'EOSTART'
#!/bin/bash
# Check if IP_ADDRESS is provided
if [ -z "$IP_ADDRESS" ]; then
    echo "Error: IP_ADDRESS environment variable is not set"
    exit 1
fi

# Update IP address in server files
sed -i "s/const ipAddress = ''/const ipAddress = '$IP_ADDRESS'/g" /home/o11/server.js
sed -i "s/IP_ADDRESS = \"\"/IP_ADDRESS = \"$IP_ADDRESS\"/g" /home/o11/server.py

# Create directories needed by run.sh
mkdir -p /home/o11/hls /home/o11/dl

# Start the license server (choose one)
if [ "$SERVER_TYPE" = "python" ]; then
  pm2 start server.py --name licserver --interpreter python3
else
  pm2 start server.js --name licserver --silent
fi

pm2 save

nohup ./run.sh > /dev/null 2>&1 &

pm2 logs
EOSTART

chmod +x start.sh

step "Creating fixed Dockerfile..."
cat > Dockerfile << 'EODOCKER'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    sudo \
    openssl \
    python3 \
    python3-pip \
    ffmpeg \
    dos2unix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/o11

WORKDIR /home/o11

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pm2 \
    && npm install express

RUN pip3 install flask

COPY server.js server.py run.sh o11.cfg o11v4 lic.cr /home/o11/
COPY start.sh /home/o11/start.sh

RUN chmod +x /home/o11/run.sh
RUN chmod +x /home/o11/o11v4
RUN chmod +x /home/o11/lic.cr
RUN chmod +x /home/o11/start.sh

RUN dos2unix /home/o11/start.sh /home/o11/run.sh

RUN mkdir -p /home/o11/certs && \
    openssl req -x509 -newkey rsa:2048 -keyout /home/o11/certs/key.pem -out /home/o11/certs/cert.pem -days 365 -nodes -subj "/CN=localhost"

EXPOSE 80 443 5454 8484

ENV SERVER_TYPE=nodejs
ENV IP_ADDRESS=""

CMD ["/home/o11/start.sh"]
EODOCKER

step "Building Docker image..."
docker build -t $DOCKER_IMAGE .

step "Configuring firewall recommendations..."
if command -v ufw >/dev/null 2>&1 && systemctl is-active --quiet ufw; then
    ufw allow $WEB_PORT/tcp >/dev/null 2>&1
    ufw allow $SSL_PORT/tcp >/dev/null 2>&1
    ufw allow $LICENSE_PORT/tcp >/dev/null 2>&1
    ufw allow $PANEL_PORT/tcp >/dev/null 2>&1
    success "Firewall configured for selected ports"
else
    warning "Please ensure these ports are open in your firewall:"
    warning "HTTP: $WEB_PORT/tcp, HTTPS: $SSL_PORT/tcp, License: $LICENSE_PORT/tcp, Panel: $PANEL_PORT/tcp"
fi

step "Removing existing container if any..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

step "Starting o11-v4 container with custom ports..."
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

step "Waiting for container to start..."
sleep 10

if docker ps | grep -q $CONTAINER_NAME; then
    success "Container is running successfully!"
else
    warning "Container might have issues starting. Checking logs..."
    docker logs $CONTAINER_NAME
    error "Container failed to start. Please check the logs above."
fi

# Display installation summary
echo -e "${GREEN}"
echo "================================================"
echo "          o11-v4 INSTALLATION COMPLETE         "
echo "================================================"
echo -e "${NC}"
echo "IP Address: $IP_ADDRESS"
echo "Web HTTP: http://$IP_ADDRESS:$WEB_PORT"
echo "Web HTTPS: https://$IP_ADDRESS:$SSL_PORT"
echo "Admin Panel: http://$IP_ADDRESS:$PANEL_PORT"
echo "License Server: http://$IP_ADDRESS:$LICENSE_PORT"
echo ""
echo "Default Credentials:"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "Useful Commands:"
echo "Check logs:    docker logs $CONTAINER_NAME"
echo "Restart:       docker restart $CONTAINER_NAME"
echo "Stop:          docker stop $CONTAINER_NAME"
echo "Shell access:  docker exec -it $CONTAINER_NAME bash"
echo ""
echo -e "${CYAN}================================================"
echo "This installation was configured by 3BdALLaH"
echo -e "================================================${NC}"
echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"

step "Cleaning up temporary files..."
cd ../..
rm -rf v4.zip o11-v4-install

success "Cleanup completed. Installation finished!"
EOF
