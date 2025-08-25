cat > /tmp/quick-uninstall.sh << 'EOF'
#!/bin/bash
echo "================================================"
echo "         o11-v4 Quick Uninstaller"
echo "           Script by: 3BdALLaH"
echo "================================================"

read -p "Are you sure you want to uninstall o11-v4? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo "Stopping and removing container..."
docker stop o11 2>/dev/null || true
docker rm o11 2>/dev/null || true

echo "Removing Docker image..."
docker rmi o11-v4 2>/dev/null || true

echo "Cleaning up files..."
rm -rf /home/o11 2>/dev/null || true
rm -rf /tmp/o11-v4-install 2>/dev/null || true
rm -f /tmp/v4.zip 2>/dev/null || true

echo "================================================"
echo "       o11-v4 successfully uninstalled"
echo "           Script by: 3BdALLaH"
echo "================================================"
EOF

# Run the temporary uninstaller
sudo bash /tmp/quick-uninstall.sh
