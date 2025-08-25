#!/bin/bash

# o11-v4 Uninstaller
# Script by: 3BdALLaH

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}"
echo "================================================"
echo "         o11-v4 Uninstaller"
echo "           Script by: 3BdALLaH"
echo "================================================"
echo -e "${NC}"

CONTAINER_NAME="o11"
DOCKER_IMAGE="o11-v4"

read -p "Are you sure you want to uninstall o11-v4? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo "Stopping and removing container..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

echo "Removing Docker image..."
docker rmi $DOCKER_IMAGE 2>/dev/null || true

echo "Cleaning up files..."
rm -rf /home/o11 /tmp/o11-v4-install 2>/dev/null || true

echo -e "${GREEN}"
echo "================================================"
echo "       o11-v4 successfully uninstalled"
echo "           Script by: 3BdALLaH"
echo "================================================"
echo -e "${NC}"
