#!/bin/bash

# o11-v3 Professional Installer
# Version: 1.1.0
# Script by: 3BdALLaH

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/home/o11"
SERVICE_NAME="o11.service"
DOWNLOAD_URL="https://senator.pages.dev/v3p.zip"
DEFAULT_PORT="2086"
SELECTED_PORT=""

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root. Use sudo or switch to root user."
    fi
}

# Check internet connection
check_internet() {
    log_step "Checking internet connection..."
    if ! ping -c 1 -W 3 google.com >/dev/null 2>&1 && ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log_error "No internet connection detected. Please check your network."
    fi
    log_success "Internet connection verified"
}

# Get port from user
get_port() {
    echo -e "${CYAN}"
    echo "================================================"
    echo "           PORT SELECTION"
    echo "================================================"
    echo -e "${NC}"
    
    while true; do
        read -rp "Enter the port number for o11 service [$DEFAULT_PORT]: " input_port
        
        # Use default if empty
        if [[ -z "$input_port" ]]; then
            SELECTED_PORT="$DEFAULT_PORT"
            break
        fi
        
        # Validate port number
        if [[ "$input_port" =~ ^[0-9]+$ ]] && [ "$input_port" -ge 1024 ] && [ "$input_port" -le 65535 ]; then
            SELECTED_PORT="$input_port"
            break
        else
            echo -e "${RED}Invalid port! Please enter a number between 1024 and 65535.${NC}"
        fi
    done
    
    log_success "Selected port: $SELECTED_PORT"
}

# Check if port is available
check_port_availability() {
    if ss -tulpn | grep -q ":$SELECTED_PORT "; then
        log_warning "Port $SELECTED_PORT is already in use by another service."
        read -rp "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Installation cancelled by user."
        fi
    fi
}

# Install dependencies
install_dependencies() {
    log_step "Installing required dependencies..."
    
    if ! apt-get update; then
        log_error "Failed to update package lists."
    fi

    if ! apt-get install -y ffmpeg unzip wget; then
        log_error "Failed to install dependencies. Check your apt sources."
    fi
    
    log_success "Dependencies installed successfully."
}

# Create installation directory
create_directory() {
    log_step "Creating installation directory..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        log_warning "Directory $INSTALL_DIR already exists. Cleaning up..."
        rm -rf "${INSTALL_DIR:?}/"*
    else
        mkdir -p "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR" || log_error "Failed to change to directory: $INSTALL_DIR"
    log_success "Installation directory created: $INSTALL_DIR"
}

# Download and extract
download_and_extract() {
    log_step "Downloading v3p package..."
    
    if ! wget --progress=bar:force --timeout=30 --tries=3 "$DOWNLOAD_URL" -O v3p.zip; then
        log_error "Failed to download v3p package from $DOWNLOAD_URL"
    fi
    
    log_success "Download completed successfully."
    
    log_step "Extracting package..."
    if ! unzip -q v3p.zip; then
        log_error "Failed to extract v3p.zip. File may be corrupted."
    fi
    
    # Clean up zip file
    rm -f v3p.zip
    log_success "Package extracted successfully"
}

# Set permissions
set_permissions() {
    log_step "Setting executable permissions..."
    
    if [[ ! -f "v3p_launcher" ]]; then
        log_error "v3p_launcher not found after extraction."
    fi
    
    chmod +x v3p_launcher
    
    # Set permissions for all files in directory
    chmod -R 755 "$INSTALL_DIR"
    log_success "Permissions set successfully"
}

# Create systemd service
create_systemd_service() {
    log_step "Creating systemd service on port $SELECTED_PORT..."
    
    local service_file="/etc/systemd/system/$SERVICE_NAME"
    
    cat > "$service_file" << EOF
[Unit]
Description=o11 Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/v3p_launcher -p $SELECTED_PORT -noramfs
ExecStop=/bin/kill -TERM \$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=infinity
LimitNPROC=infinity
StandardOutput=journal
StandardError=journal

# Security
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

    if [[ ! -f "$service_file" ]]; then
        log_error "Failed to create systemd service file."
    fi
    
    log_success "Systemd service created at $service_file"
}

# Enable and start service
enable_service() {
    log_step "Configuring systemd service..."
    
    systemctl daemon-reload
    
    if ! systemctl enable "$SERVICE_NAME"; then
        log_error "Failed to enable $SERVICE_NAME"
    fi
    
    log_success "Service enabled to start on boot."
    
    log_step "Starting o11 service on port $SELECTED_PORT..."
    if systemctl restart "$SERVICE_NAME"; then
        log_success "Service started successfully."
    else
        log_warning "Service failed to start. Checking status..."
        systemctl status "$SERVICE_NAME" --no-pager -l
        log_error "Service failed to start. Please check logs with: journalctl -u $SERVICE_NAME"
    fi
}

# Verify installation
verify_installation() {
    log_step "Verifying installation..."
    
    sleep 3
    
    # Check if service is running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Service is running successfully."
    else
        log_warning "Service is not running. Checking status..."
        systemctl status "$SERVICE_NAME" --no-pager -l
    fi
    
    # Check if port is listening
    if ss -tulpn | grep -q ":$SELECTED_PORT "; then
        log_success "Port $SELECTED_PORT is listening."
    else
        log_warning "Port $SELECTED_PORT is not listening yet. Service may still be starting."
    fi
}

# Display completion message
show_completion() {
    echo -e "${GREEN}"
    echo "================================================"
    echo "          o11-v3 INSTALLATION COMPLETE         "
    echo "================================================"
    echo -e "${NC}"
    echo "Installation Directory: $INSTALL_DIR"
    echo "Service Name: $SERVICE_NAME"
    echo "Service Port: $SELECTED_PORT"
    echo ""
    echo "Useful Commands:"
    echo "  Check status:    systemctl status $SERVICE_NAME"
    echo "  View logs:       journalctl -u $SERVICE_NAME -f"
    echo "  Restart service: systemctl restart $SERVICE_NAME"
    echo "  Stop service:    systemctl stop $SERVICE_NAME"
    echo ""
    echo -e "${CYAN}================================================"
    echo "This script was created by 3BdALLaH"
    echo "GitHub: https://github.com/3bdoSamy/v4"
    echo -e "================================================${NC}"
    echo ""
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Note: If you changed the default port, make sure to open"
    echo -e "the port $SELECTED_PORT in your firewall if needed.${NC}"
}

# Main execution
main() {
    echo -e "${CYAN}"
    echo "================================================"
    echo "       o11-v3 Professional Installer"
    echo "           Script by: 3BdALLaH"
    echo "================================================"
    echo -e "${NC}"
    
    check_root
    check_internet
    get_port
    check_port_availability
    install_dependencies
    create_directory
    download_and_extract
    set_permissions
    create_systemd_service
    enable_service
    verify_installation
    show_completion
}

# Handle script termination
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "Installation failed. Check the output above for errors."
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"
