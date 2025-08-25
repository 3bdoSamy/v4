#!/bin/bash



set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
IP_ADDRESS=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
SERVER_TYPE="nodejs"
DOCKER_IMAGE="o11-v4"
CONTAINER_NAME="o11"

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root or use sudo"
fi

# Update system and install dependencies
log "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y docker.io docker-compose unzip curl wget

# Start and enable Docker
log "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Download and extract o11-v4
log "Downloading o11-v4..."
wget -q https://senator.pages.dev/v4.zip -O v4.zip
if [ ! -f v4.zip ]; then
    error "Failed to download v4.zip"
fi

log "Extracting files..."
unzip -q v4.zip -d o11-v4-install
cd o11-v4-install/o11-v4-main

# Create fixed start.sh file
log "Creating fixed start.sh..."
cat > start.sh << 'EOF'
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
EOF

chmod +x start.sh

# Create fixed Dockerfile
log "Creating fixed Dockerfile..."
cat > Dockerfile << 'EOF'
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
EOF

# Build Docker image
log "Building Docker image..."
docker build -t $DOCKER_IMAGE .

# Configure firewall
log "Configuring firewall..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 5454/tcp
ufw allow 8484/tcp
ufw --force enable

# Remove existing container if any
log "Removing existing container if any..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Run Docker container
log "Starting o11-v4 container..."
docker run -d \
  -p 80:80 \
  -p 443:443 \
  -p 5454:5454 \
  -p 8484:8484 \
  -e IP_ADDRESS=$IP_ADDRESS \
  -e SERVER_TYPE=$SERVER_TYPE \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  $DOCKER_IMAGE

# Wait for container to start
sleep 10

# Check if container is running
if docker ps | grep -q $CONTAINER_NAME; then
    log "Container is running successfully!"
else
    warning "Container might have issues starting. Checking logs..."
    docker logs $CONTAINER_NAME
fi

# Display installation summary
log "Installation completed!"
echo "================================================"
echo "IP Address: $IP_ADDRESS"
echo "Web Panel: http://$IP_ADDRESS:8484"
echo "Username: admin"
echo "Password: admin"
echo "Main Service: http://$IP_ADDRESS"
echo "License Server: http://$IP_ADDRESS:5454"
echo "================================================"
echo ""
echo "To check logs: docker logs $CONTAINER_NAME"
echo "To restart: docker restart $CONTAINER_NAME"
echo "To stop: docker stop $CONTAINER_NAME"
echo "To update: Re-run this script"

# Cleanup
cd ../..
rm -rf v4.zip o11-v4-install

log "Cleanup completed. Installation finished!"
