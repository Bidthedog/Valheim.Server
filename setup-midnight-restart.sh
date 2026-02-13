#!/bin/bash

# Script to set up Valheim server to restart at midnight every night
# This script creates systemctl timer units to automatically restart the service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up Valheim server midnight restart...${NC}"

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run with sudo${NC}"
   exit 1
fi

# Create the timer unit
echo -e "${YELLOW}Creating systemctl timer unit...${NC}"

tee /etc/systemd/system/valheim-midnight-restart.timer > /dev/null << 'EOF'
[Unit]
Description=Valheim Server Midnight Restart Timer
Requires=valheim-midnight-restart.service

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Create the service unit
echo -e "${YELLOW}Creating systemctl service unit...${NC}"

tee /etc/systemd/system/valheim-midnight-restart.service > /dev/null << 'EOF'
[Unit]
Description=Restart Valheim Server at Midnight
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart valheim.service
User=root

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
echo -e "${YELLOW}Reloading systemd daemon...${NC}"
systemctl daemon-reload

# Enable the timer
echo -e "${YELLOW}Enabling the timer...${NC}"
systemctl enable valheim-midnight-restart.timer

# Start the timer
echo -e "${YELLOW}Starting the timer...${NC}"
systemctl start valheim-midnight-restart.timer

# Display status
echo -e "${GREEN}✓ Valheim midnight restart timer has been set up successfully!${NC}"
echo ""
echo -e "${YELLOW}Timer Status:${NC}"
systemctl status valheim-midnight-restart.timer --no-pager
echo ""
echo -e "${YELLOW}Next scheduled restart:${NC}"
systemctl list-timers valheim-midnight-restart.timer --no-pager
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  Check timer status:    systemctl status valheim-midnight-restart.timer"
echo "  View timer logs:       journalctl -u valheim-midnight-restart.service -f"
echo "  Disable timer:         systemctl disable valheim-midnight-restart.timer"
echo "  Disable and stop:      systemctl disable --now valheim-midnight-restart.timer"
echo "  Re-enable:             systemctl enable --now valheim-midnight-restart.timer"
