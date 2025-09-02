#!/bin/bash

# o11-v4 Professional Installer
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
echo "       o11-v4 Professional Installer"
echo "           Script by: 3BdALLaH"
echo "================================================"
echo -e "${NC}"

# Use DEFAULT ports only - no user input to avoid issues
WEB_PORT="80"
SSL_PORT="443"
LICENSE_PORT="5454"
PANEL_PORT="8484"

IP_ADDRESS=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
DOCKER_IMAGE="o11-v4"
CONTAINER_NAME="o11"

# Ask for installation type
echo -e "${YELLOW}"
echo "Select installation type:"
echo "1) Node.js (Default)"
echo "2) Python"
read -p "Enter your choice [1-2]: " -r INSTALL_CHOICE
echo -e "${NC}"

# Set default if empty
if [ -z "$INSTALL_CHOICE" ]; then
    INSTALL_CHOICE="1"
fi

case $INSTALL_CHOICE in
    1)
        SERVER_TYPE="nodejs"
        step "Selected Node.js installation"
        ;;
    2)
        SERVER_TYPE="python"
        step "Selected Python installation"
        ;;
    *)
        SERVER_TYPE="nodejs"
        warning "Invalid choice, defaulting to Node.js"
        ;;
esac

step "Using default ports: HTTP=80, HTTPS=443, License=5454, Panel=8484"

step "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y docker.io docker-compose unzip curl wget

step "Starting Docker service..."
systemctl start docker
systemctl enable docker

step "Downloading o11-v4..."
wget -q https://senator.pages.dev/v4.zip -O v4.zip
if [ ! -f v4.zip ]; then error "Failed to download v4.zip"; fi

step "Extracting files..."
unzip -q v4.zip -d o11-v4-install
cd o11-v4-install/o11-v4-main

step "Creating fixed start.sh..."
cat > start.sh << 'EOSTART'
#!/bin/bash
if [ -z "$IP_ADDRESS" ]; then
    echo "Error: IP_ADDRESS environment variable is not set"
    exit 1
fi

# Update configuration based on server type
if [ "$SERVER_TYPE" = "nodejs" ]; then
    sed -i "s/const ipAddress = ''/const ipAddress = '$IP_ADDRESS'/g" /home/o11/server.js
    mkdir -p /home/o11/hls /home/o11/dl
    pm2 start server.js --name licserver --silent
    pm2 save
elif [ "$SERVER_TYPE" = "python" ]; then
    sed -i "s/IP_ADDRESS = \"\"/IP_ADDRESS = \"$IP_ADDRESS\"/g" /home/o11/server.py
    mkdir -p /home/o11/hls /home/o11/dl
    pm2 start server.py --name licserver --interpreter python3 --silent
    pm2 save
fi

nohup ./run.sh > /dev/null 2>&1 &
pm2 logs
EOSTART

chmod +x start.sh

step "Creating fixed Dockerfile..."
cat > Dockerfile << 'EODOCKER'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl sudo openssl python3 python3-pip ffmpeg dos2unix && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /home/o11
WORKDIR /home/o11
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs && npm install -g pm2 && npm install express
RUN pip3 install flask
COPY server.js server.py run.sh o11.cfg o11v4 lic.cr /home/o11/
COPY start.sh /home/o11/start.sh
RUN chmod +x /home/o11/run.sh /home/o11/o11v4 /home/o11/lic.cr /home/o11/start.sh
RUN dos2unix /home/o11/start.sh /home/o11/run.sh
RUN mkdir -p /home/o11/certs && openssl req -x509 -newkey rsa:2048 -keyout /home/o11/certs/key.pem -out /home/o11/certs/cert.pem -days 365 -nodes -subj "/CN=localhost"
EXPOSE 80 443 5454 8484
ENV SERVER_TYPE=nodejs
ENV IP_ADDRESS=""
CMD ["/home/o11/start.sh"]
EODOCKER

step "Building Docker image..."
docker build -t $DOCKER_IMAGE .

step "Removing existing container if any..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

step "Starting o11-v4 container with $SERVER_TYPE..."
docker run -d -p 80:80 -p 443:443 -p 5454:5454 -p 8484:8484 -e IP_ADDRESS="$IP_ADDRESS" -e SERVER_TYPE="$SERVER_TYPE" --name "$CONTAINER_NAME" --restart unless-stopped "$DOCKER_IMAGE"

step "Waiting for container to start..."
sleep 10

if docker ps | grep -q $CONTAINER_NAME; then
    success "Container is running successfully with $SERVER_TYPE!"
else
    warning "Container might have issues starting. Checking logs..."
    docker logs $CONTAINER_NAME
    error "Container failed to start. Please check the logs above."
fi

echo -e "${GREEN}"
echo "================================================"
echo "          o11-v4 INSTALLATION COMPLETE         "
echo "================================================"
echo -e "${NC}"
echo "IP Address: $IP_ADDRESS"
echo "Server Type: $SERVER_TYPE"
echo "Web HTTP: http://$IP_ADDRESS:80"
echo "Web HTTPS: https://$IP_ADDRESS:443"
echo "Admin Panel: http://$IP_ADDRESS:8484"
echo "License Server: http://$IP_ADDRESS:5454"
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
