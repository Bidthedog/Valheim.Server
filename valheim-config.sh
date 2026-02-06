#!/bin/bash

################################################################################
# Valheim Dedicated Server - Shared Configuration
#
# This file contains all shared configuration variables used by the
# Valheim server management scripts. Source this file to use these variables.
#
# Usage in other scripts:
#   source ./valheim-config.sh
#   or
#   source "$(dirname "$0")/valheim-config.sh"
#
################################################################################

# === System & Logging ===
LOG_FILE="/var/log/valheim-update.log"
STEAMCMD_DIR="/usr/games"

# === Server Installation ===
VALHEIM_SERVER_DIR="/opt/valheim-server"
VALHEIM_APP_ID="896660"

# === BepInEx Configuration ===
BEPINEX_VERSION="5.4.2333"
THUNDERSTORE_DOWNLOAD_BASE_URL="https://thunderstore.io/package/download"
BEPINEX_DOWNLOAD_URL="${THUNDERSTORE_DOWNLOAD_BASE_URL}/denikson/BepInExPack_Valheim/${BEPINEX_VERSION}/"
BEPINEX_DIR="${VALHEIM_SERVER_DIR}/BepInEx"

# === Server Configuration ===
# These values are defaults and can be overridden in valheim-config.local.sh
# DO NOT commit sensitive settings to git - use the .local file instead
SERVER_NAME="My Valheim Server"
SERVER_PORT="2456"
SERVER_WORLD="Seed"
SERVER_PASSWORD="changeme"
SERVER_PUBLIC="0"

# === Server Script Names ===
START_SERVER_SCRIPT="start_server_bepinex.sh"
CUSTOM_SERVER_SCRIPT="start_server_bepinex_gods_kitchen.sh"

# === Mods Configuration ===
MODS_JSON_FILE="${HOME}/mods.json"
PLUGINS_DIR="${BEPINEX_DIR}/plugins"
THUNDERSTORE_API_BASE_URL="https://thunderstore.io/api/experimental/package"
# MOD_API_WAIT_SECONDS: Delay between API requests in seconds (be respectful)
# Default: 1 seconds. Do not reduce below 1 second
MOD_API_WAIT_SECONDS=1
# MOD_DOWNLOAD_WAIT_SECONDS: Delay between actual mod downloads in seconds
# Only applied if a download actually occurred, not on up-to-date checks
# This is respectful to Thunderstore servers and prevents rate limiting
# Default: 4 seconds. Do not reduce below 2 seconds
MOD_DOWNLOAD_WAIT_SECONDS=4

# === Systemd Service Configuration ===
SERVICE_NAME="valheim"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
BASHRC_FILE="/root/.bashrc"

# === Color codes for terminal output ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Load local configuration overrides (not committed to git)
################################################################################
# This allows deployment-specific settings without modifying the main config
if [ -f "$(dirname "$0")/valheim-config.local.sh" ]; then
    source "$(dirname "$0")/valheim-config.local.sh"
fi

################################################################################
# End of shared configuration
################################################################################
