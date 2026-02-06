#!/bin/bash

################################################################################
# Valheim Dedicated Server - Systemd Service Setup
#
# This script creates and configures the valheim.service systemd unit file
# for automatic server startup, updates, and management.
#
# This script:
# 1. Creates /etc/systemd/system/valheim.service with proper configuration
# 2. Runs update-server.sh before starting the server (ExecStartPre)
# 3. Starts the server with the custom startup script
# 4. Configures automatic restart on failure
# 5. Reloads the systemd daemon
# 6. Enables the service to auto-start on boot
# 7. Creates convenient aliases for service management
#
# Deployment: Copy this script to ~/ on the Linux box
# Execution: Run from ~/ with elevated permissions (sudo)
# Example: sudo ~/setup-service.sh
#
# Service aliases created (add to ~/.bashrc or /root/.bashrc):
#   val_start='systemctl start valheim.service'
#   val_restart='systemctl restart valheim.service'
#   val_stop='systemctl stop valheim.service'
#   val_log='journalctl -u valheim.service -f'
#
################################################################################

set -e  # Exit on error

# Source shared configuration
source "$(dirname "$0")/valheim-config.sh"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Valheim Service Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo "Creating systemd service file..."
echo "Service file: ${SERVICE_FILE}"
echo ""

# Ensure scripts have execute permissions
echo "Setting execute permissions on scripts..."
chmod +x "${HOME}/update-server.sh" 2>/dev/null || log_warning "Warning: Could not set permissions on update-server.sh"
echo -e "${GREEN}✓ Script permissions set${NC}"
echo ""

# Create the systemd service file
cat > "${SERVICE_FILE}" << 'SYSTEMD_EOF'
[Unit]
Description=God's Kitchen - Valheim Dedicated Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/valheim-server
Restart=on-failure
RestartSec=30
TimeoutStartSec=10min

# Run update script before starting server
# This handles: steamcmd updates, Valheim updates, BepInEx updates, and mod updates
ExecStartPre=/root/update-server.sh

# Start the Valheim server with custom configuration
ExecStart=/opt/valheim-server/start_server_bepinex_gods_kitchen.sh

# Graceful shutdown timeout (30 seconds)
TimeoutStopSec=30
KillMode=process

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

echo -e "${GREEN}✓ Service file created${NC}"
echo ""

# Verify the custom server script will have execute permissions
echo "Verifying script permissions..."
if [ -f "/opt/valheim-server/${CUSTOM_SERVER_SCRIPT}" ]; then
    chmod +x "/opt/valheim-server/${CUSTOM_SERVER_SCRIPT}"
    echo -e "${GREEN}✓ Server script permissions verified${NC}"
else
    echo -e "${YELLOW}⚠ Note: Server script will be created on first update-server.sh run${NC}"
fi
echo ""

# Reload systemd daemon to recognize new service
echo "Reloading systemd daemon..."
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd daemon reloaded${NC}"
echo ""

# Enable the service so it starts on boot
echo "Enabling service to start on boot..."
systemctl enable ${SERVICE_NAME}.service
echo -e "${GREEN}✓ Service enabled${NC}"
echo ""

# Add convenient aliases to bashrc
echo "Adding service management aliases (overwriting if they exist)..."

ALIASES_BLOCK=$(cat << 'ALIASES_EOF'

# Valheim service management aliases
alias val_start='systemctl start valheim.service'
alias val_restart='systemctl restart valheim.service'
alias val_stop='systemctl stop valheim.service'
alias val_status='systemctl status valheim.service'
alias val_log='journalctl -u valheim.service -f'
ALIASES_EOF
)

# Remove old aliases if they exist
if grep -q "val_start=" "${BASHRC_FILE}"; then
    echo "Removing old aliases..."
    sed -i '/# Valheim service management aliases/,/alias val_log=/d' "${BASHRC_FILE}"
fi

# Add the new aliases
echo "${ALIASES_BLOCK}" >> "${BASHRC_FILE}"
echo -e "${GREEN}✓ Aliases added to ${BASHRC_FILE}${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Available service management commands:"
echo -e "  ${YELLOW}val_start${NC}     - Start the Valheim server"
echo -e "  ${YELLOW}val_stop${NC}      - Stop the Valheim server"
echo -e "  ${YELLOW}val_restart${NC}   - Restart the Valheim server"
echo -e "  ${YELLOW}val_status${NC}    - Show service status"
echo -e "  ${YELLOW}val_log${NC}       - View live service logs"
echo ""
echo "Manual commands (if aliases not loaded):"
echo -e "  ${YELLOW}systemctl start valheim.service${NC}"
echo -e "  ${YELLOW}systemctl stop valheim.service${NC}"
echo -e "  ${YELLOW}systemctl restart valheim.service${NC}"
echo -e "  ${YELLOW}systemctl status valheim.service${NC}"
echo -e "  ${YELLOW}journalctl -u valheim.service -f${NC}"
echo ""
echo "Checking if service is already running..."
if systemctl is-active --quiet ${SERVICE_NAME}.service; then
    echo -e "${YELLOW}✓ Service is running. Restarting to apply new configuration...${NC}"
    systemctl restart ${SERVICE_NAME}.service
    echo -e "${GREEN}✓ Service restarted${NC}"
    echo ""
    echo "Waiting for service to stabilize (5 seconds)..."
    sleep 5
    systemctl status ${SERVICE_NAME}.service --no-pager
else
    echo -e "${YELLOW}✓ Service is not currently running${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the service configuration: systemctl cat valheim.service"
    echo "2. Start the server: val_start"
    echo "3. Check logs: val_log"
fi
echo ""
