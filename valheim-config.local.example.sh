#!/bin/bash

################################################################################
# Valheim Dedicated Server - Local Configuration Override
#
# This file overrides the default values in valheim-config.sh for your
# specific deployment. Copy this file to valheim-config.local.sh and
# customize the values below.
#
# Usage:
#   cp valheim-config.local.example.sh valheim-config.local.sh
#   Edit valheim-config.local.sh with your server settings
#   DO NOT commit valheim-config.local.sh to git
#
# The local config is automatically loaded and overrides defaults if it exists.
#
################################################################################

# === Server Configuration (deployment-specific) ===
# These settings override the defaults in valheim-config.sh

SERVER_NAME="Your Server Name Here"
SERVER_PORT="2456"
SERVER_WORLD="Your_Map_Name"
SERVER_PASSWORD="Your_Server_Password_Here"
SERVER_PUBLIC="0"

# === Optional: Mod download wait time (seconds) ===
# This controls the delay between downloading mods to avoid overwhelming Thunderstore.
# Be respectful of the service - do NOT set this to 0 or very low values.
# Default of 4-5 seconds is reasonable. Minimum recommended: 2 seconds
# Uncomment and change only if you have a good reason
# MOD_DOWNLOAD_WAIT_SECONDS=4

# === Optional: API request wait time (seconds) ===
# This controls the delay between Thunderstore API requests.
# Default of 1 seconds is reasonable and respectful. Minimum recommended: 1 second
# Uncomment and change only if you have a good reason
# MOD_API_WAIT_SECONDS=1

# === Optional: Custom paths (uncomment to override) ===
# Uncomment these only if you need different paths than the defaults
# VALHEIM_SERVER_DIR="/opt/valheim-server"
# MODS_JSON_FILE="${HOME}/mods.json"
# LOG_FILE="/var/log/valheim-update.log"

################################################################################
# End of local configuration
################################################################################
