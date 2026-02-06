#!/bin/bash

################################################################################
# Valheim Dedicated Server - Install/Update Script
#
# This script automates the complete setup and maintenance of a Valheim
# dedicated server with BepInEx and mod support.
#
# This script:
# 1. Installs or updates SteamCMD for downloading game files
# 2. Installs or updates the Valheim dedicated server via SteamCMD
# 3. Installs or updates BepInEx (mod framework) from Thunderstore
# 4. Creates a customized server startup script with configured parameters
# 5. Reads mod manifest from mods.json and processes all mods:
#    - Checks Thunderstore API for latest versions
#    - Downloads and installs new/updated mods
#    - Handles deprecated mods (backs up and removes)
#    - Updates version history in mods.json
#    - Maintains old versions in mod-backup directory
#    - Removes mods no longer listed in mods.json
#
# Command line options:
#   -clearLogs, -c          Clear the log file before starting
#   -updateBepInEx, -udb    Force re-download and reinstall BepInEx
#
# Deployment: Copy this script to ~/ on the Linux box
# Execution: Run from ~/ on the Linux box (requires elevated permissions)
# Example: ~/update-server.sh
# Example with options: ~/update-server.sh -c -updateBepInEx
#
# Dependencies:
#   - curl: For downloading files
#   - unzip: For extracting mod and BepInEx archives
#   - jq: For parsing JSON (mods.json and Thunderstore API)
#   - steamcmd: Installed automatically if not present
#
# Configuration Files:
#   - ~/mods.json: Manifest of mods to install with versions and history
#   - /opt/valheim-server/: Installation directory for server and mods
#   - /var/log/valheim-update.log: Detailed execution log
#
################################################################################

set -e  # Exit on error

# Source shared configuration
source "$(dirname "$0")/valheim-config.sh"

# Parse command line arguments
CLEAR_LOGS=false
UPDATE_BEPINEX=false
for arg in "$@"; do
    case $arg in
        -clearLogs|-c)
            CLEAR_LOGS=true
            shift
            ;;
        -updateBepInEx|-udb)
            UPDATE_BEPINEX=true
            shift
            ;;
    esac
done


# Clear logs if requested
if [ "$CLEAR_LOGS" = true ]; then
    echo "Clearing log file..."
    > "${LOG_FILE}"
    echo "Log file cleared at $(date '+%Y-%m-%d %H:%M:%S')" >> "${LOG_FILE}"
fi

# Create directories
mkdir -p "${VALHEIM_SERVER_DIR}"

################################################################################
# Logging
################################################################################
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $@" | tee -a "${LOG_FILE}"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[${timestamp}] $@${NC}" | tee -a "${LOG_FILE}"
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[${timestamp}] $@${NC}" | tee -a "${LOG_FILE}"
}

log_section() {
    echo "" >> "${LOG_FILE}"
    log "============================================"
    log "$@"
    log "============================================"
}

################################################################################
# Install/Update SteamCMD
################################################################################
install_steamcmd() {
    log_section "Installing/Updating SteamCMD"

    # Update package list
    log "Updating package list..."
    apt update

    # Add i386 architecture if not present (required for steamcmd)
    if ! dpkg --print-foreign-architectures | grep -q i386; then
        log "Adding i386 architecture..."
        dpkg --add-architecture i386
        apt update
    fi

    # Install steamcmd
    log "Installing steamcmd package..."
    DEBIAN_FRONTEND=noninteractive apt install -y steamcmd

    # Create symlink if needed
    if [ ! -f "${STEAMCMD_DIR}/steamcmd" ] && [ -f "/usr/games/steamcmd" ]; then
        ln -sf /usr/games/steamcmd "${STEAMCMD_DIR}/steamcmd"
    fi

    log "SteamCMD installation completed"
}

################################################################################
# Install/Update Valheim Server
################################################################################
install_valheim_server() {
    log_section "Installing/Updating Valheim Dedicated Server"

    # Verify steamcmd is available
    local STEAMCMD_PATH=""
    if command -v steamcmd &> /dev/null; then
        STEAMCMD_PATH="steamcmd"
    elif [ -f "/usr/games/steamcmd" ]; then
        STEAMCMD_PATH="/usr/games/steamcmd"
    else
        log_error "ERROR: steamcmd not found"
        return 1
    fi

    log "Using steamcmd at: ${STEAMCMD_PATH}"
    log "Target directory: ${VALHEIM_SERVER_DIR}"
    log "App ID: ${VALHEIM_APP_ID}"

    # Run steamcmd to install/update Valheim
    ${STEAMCMD_PATH} +@sSteamCmdForcePlatformType linux \
             +force_install_dir "${VALHEIM_SERVER_DIR}" \
             +login anonymous \
             +app_update ${VALHEIM_APP_ID} validate \
             +quit

    if [ $? -eq 0 ]; then
        log "Valheim server installation/update completed successfully"

        # Make server executable
        if [ -f "${VALHEIM_SERVER_DIR}/valheim_server.x86_64" ]; then
            chmod +x "${VALHEIM_SERVER_DIR}/valheim_server.x86_64"
            log "Set executable permissions on valheim_server.x86_64"
        fi

        # Get build ID from the local manifest
        if [ -f "${VALHEIM_SERVER_DIR}/steamapps/appmanifest_${VALHEIM_APP_ID}.acf" ]; then
            local installed_build=$(grep '"buildid"' "${VALHEIM_SERVER_DIR}/steamapps/appmanifest_${VALHEIM_APP_ID}.acf" | \
                                   grep -o '"[0-9]*"' | tr -d '"')
            if [ -n "${installed_build}" ]; then
                log "Valheim server build ID: ${installed_build}"
            fi
        fi

        return 0
    else
        log_error "ERROR: Valheim server installation/update failed"
        return 1
    fi
}

################################################################################
# Install/Update BepInEx
################################################################################
install_bepinex() {
    log_section "Installing/Updating BepInEx"

    # Force re-download if requested
    if [ "$UPDATE_BEPINEX" = true ] && [ -d "${BEPINEX_DIR}" ]; then
        log "Force update requested. Removing existing BepInEx installation..."
        rm -rf "${BEPINEX_DIR}"
        # Also remove the custom script so it gets recreated
        if [ -f "${VALHEIM_SERVER_DIR}/${CUSTOM_SERVER_SCRIPT}" ]; then
            rm -f "${VALHEIM_SERVER_DIR}/${CUSTOM_SERVER_SCRIPT}"
        fi
    fi

    # Check if BepInEx is already installed
    if [ -d "${BEPINEX_DIR}" ] && [ -f "${BEPINEX_DIR}/core/BepInEx.dll" ]; then
        log "BepInEx is already installed at ${BEPINEX_DIR}"
        return 0
    fi

    log "BepInEx not found. Downloading BepInExPack_Valheim v${BEPINEX_VERSION}..."
    log "Download URL: ${BEPINEX_DOWNLOAD_URL}"

    # Create temporary directory for download
    local temp_dir=$(mktemp -d)
    local bepinex_zip="${temp_dir}/BepInExPack_Valheim.zip"

    # Download BepInExPack_Valheim from Thunderstore
    if ! curl -L -f -o "${bepinex_zip}" "${BEPINEX_DOWNLOAD_URL}" 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "ERROR: Failed to download BepInExPack_Valheim from ${BEPINEX_DOWNLOAD_URL}"
        rm -rf "${temp_dir}"
        return 1
    fi

    log "Download completed. Extracting BepInExPack_Valheim..."

    # Install unzip if not present
    if ! command -v unzip &> /dev/null; then
        log "Installing unzip..."
        DEBIAN_FRONTEND=noninteractive apt install -y unzip &>> "${LOG_FILE}"
    fi

    # Extract to temporary directory first
    local extract_dir="${temp_dir}/extract"
    mkdir -p "${extract_dir}"

    if ! unzip -q -o "${bepinex_zip}" -d "${extract_dir}" 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "ERROR: Failed to extract BepInExPack_Valheim"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Move contents of BepInExPack_Valheim folder to Valheim server directory
    if [ -d "${extract_dir}/BepInExPack_Valheim" ]; then
        log "Moving BepInExPack_Valheim contents to server directory..."
        cp -r "${extract_dir}/BepInExPack_Valheim"/* "${VALHEIM_SERVER_DIR}/"
    else
        log_error "ERROR: BepInExPack_Valheim folder not found in archive"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Create and configure custom server script
    if [ -f "${VALHEIM_SERVER_DIR}/${START_SERVER_SCRIPT}" ]; then
        log "Creating custom server script: ${CUSTOM_SERVER_SCRIPT}"
        cp "${VALHEIM_SERVER_DIR}/${START_SERVER_SCRIPT}" "${VALHEIM_SERVER_DIR}/${CUSTOM_SERVER_SCRIPT}"

        # Replace the exec line with custom server parameters
        sed -i "s|^exec ./valheim_server\.x86_64.*|exec ./valheim_server.x86_64 -nographics -batchmode -name \"${SERVER_NAME}\" -port ${SERVER_PORT} -world \"${SERVER_WORLD}\" -password \"${SERVER_PASSWORD}\" -public ${SERVER_PUBLIC}|" \
            "${VALHEIM_SERVER_DIR}/${CUSTOM_SERVER_SCRIPT}"

        chmod +x "${VALHEIM_SERVER_DIR}/${CUSTOM_SERVER_SCRIPT}"
        log "Created and configured ${CUSTOM_SERVER_SCRIPT}"
        log "  Server Name: ${SERVER_NAME}"
        log "  Port: ${SERVER_PORT}"
        log "  World: ${SERVER_WORLD}"
        log "  Public: ${SERVER_PUBLIC}"
    fi

    # Clean up
    rm -rf "${temp_dir}"

    log "BepInExPack_Valheim installation completed successfully"
    return 0
}

################################################################################
# Helper: Remove mods that don't exist in mods.json
################################################################################
cleanup_unmanaged_mods() {
    # Check if mods.json exists
    if [ ! -f "${MODS_JSON_FILE}" ]; then
        log "  MODS_JSON_FILE not found, skipping cleanup"
        return
    fi

    log "Checking for unmanaged mods..."

    # Get list of all installed mod folders
    if [ ! -d "${PLUGINS_DIR}" ] || [ -z "$(ls -A "${PLUGINS_DIR}" 2>/dev/null)" ]; then
        log "  No installed mods found"
        return
    fi

    local backup_dir="${VALHEIM_SERVER_DIR}/mod-backup"
    mkdir -p "${backup_dir}"

    # Build list of managed mod folder names from mods.json
    # Format: {namespace}-{name}-{version}
    local managed_mods=()
    while IFS='|' read -r namespace name version; do
        managed_mods+=("${namespace}-${name}-${version}")
    done < <(jq -r '.mods[] | "\(.namespace)|\(.name)|\(.version)"' "${MODS_JSON_FILE}" 2>/dev/null)

    # Check each installed mod folder
    for installed_mod_folder in "${PLUGINS_DIR}"/*; do
        # Skip if not a directory
        [ -d "${installed_mod_folder}" ] || continue

        local mod_basename=$(basename "${installed_mod_folder}")
        local is_managed=false

        # Check if this installed mod is in our managed list
        for managed_mod in "${managed_mods[@]}"; do
            if [[ "${mod_basename}" == "${managed_mod}" ]]; then
                is_managed=true
                break
            fi
        done

        if [ "${is_managed}" = false ]; then
            log_warning "  WARNING: Unmanaged mod found: ${mod_basename} (not in mods.json)"
            log "    Moving to mod-backup/"
            mv "${installed_mod_folder}" "${backup_dir}/"
        fi
    done
}

################################################################################
################################################################################
backup_and_remove_old_mod_versions() {
    local mod_namespace="$1"
    local mod_name="$2"

    local backup_dir="${VALHEIM_SERVER_DIR}/mod-backup"
    mkdir -p "${backup_dir}"

    local old_versions="${PLUGINS_DIR}/${mod_namespace}-${mod_name}-"*
    if compgen -G "${old_versions}" > /dev/null; then
        for old_mod in ${old_versions}; do
            if [ -d "${old_mod}" ]; then
                local mod_basename=$(basename "${old_mod}")
                log "    Moving ${mod_basename} to backup"
                mv "${old_mod}" "${backup_dir}/"
            fi
        done
    fi
}

################################################################################
# Helper: Update mods.json with new mod version and history
################################################################################
update_mods_json_version() {
    local mod_namespace="$1"
    local mod_name="$2"
    local latest_version="$3"

    if [ ! -f "${MODS_JSON_FILE}" ]; then
        log_warning "  WARNING: ${MODS_JSON_FILE} not found, skipping JSON update"
        return
    fi

    log "  Updating mods.json..."
    local current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_json=$(mktemp)

    jq --arg ns "${mod_namespace}" \
       --arg nm "${mod_name}" \
       --arg ver "${latest_version}" \
       --arg ts "${current_timestamp}" \
       '(.mods[] | select(.namespace == $ns and .name == $nm)) |= (
         .version = $ver |
         if (.versionHistory | map(.version) | contains([$ver])) then . else .versionHistory = [{version: $ver, installedDate: $ts}] + .versionHistory end
       )' "${MODS_JSON_FILE}" > "${temp_json}"

    mv "${temp_json}" "${MODS_JSON_FILE}"
    log "  Updated ${mod_namespace}-${mod_name} to version ${latest_version} in mods.json"
}

################################################################################
# Helper: Mark mod as deprecated in mods.json
################################################################################
mark_mod_deprecated_in_json() {
    local mod_namespace="$1"
    local mod_name="$2"

    if [ ! -f "${MODS_JSON_FILE}" ]; then
        log_warning "  WARNING: ${MODS_JSON_FILE} not found, skipping JSON update"
        return
    fi

    log "  Updating mods.json to mark as deprecated..."
    local current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_json=$(mktemp)

    jq --arg ns "${mod_namespace}" \
       --arg nm "${mod_name}" \
       --arg ts "${current_timestamp}" \
       '(.mods[] | select(.namespace == $ns and .name == $nm)) |= (
         .deprecated = true |
         .deprecatedDate = $ts
       )' "${MODS_JSON_FILE}" > "${temp_json}"

    mv "${temp_json}" "${MODS_JSON_FILE}"
    log "  Marked ${mod_namespace}-${mod_name} as deprecated in mods.json"
}

################################################################################
# Install/Update Mods
################################################################################
install_mods() {
    log_section "Installing/Updating Mods"

    # Ensure jq is installed for JSON parsing
    if ! command -v jq &> /dev/null; then
        log "Installing jq for JSON parsing..."
        DEBIAN_FRONTEND=noninteractive apt install -y jq &>> "${LOG_FILE}"
    fi

    # Ensure plugins directory exists
    mkdir -p "${PLUGINS_DIR}"

    # Clean up any mods that don't exist in mods.json
    cleanup_unmanaged_mods

    # Read mods from mods.json file
    if [ ! -f "${MODS_JSON_FILE}" ]; then
        log_error "ERROR: ${MODS_JSON_FILE} not found"
        return 1
    fi

    # Parse mods.json and create array with: namespace|name|version|deprecated
    local mods_array=()
    while IFS= read -r mod_entry; do
        [ -n "${mod_entry}" ] && mods_array+=("${mod_entry}")
    done < <(jq -r '.mods[] | "\(.namespace)|\(.name)|\(.version)|\(.deprecated)"' "${MODS_JSON_FILE}")

    if [ ${#mods_array[@]} -eq 0 ]; then
        log "No mods found in ${MODS_JSON_FILE}"
        return 0
    fi

    log "Found ${#mods_array[@]} mods in configuration"

    # Loop through each mod
    for mod_entry in "${mods_array[@]}"; do
        # Parse mod entry
        IFS='|' read -r mod_namespace mod_name mod_version mod_deprecated <<< "${mod_entry}"

        log "Processing mod: ${mod_namespace}-${mod_name} (current version: ${mod_version})"
        log "  Namespace: ${mod_namespace}"
        log "  Package: ${mod_name}"

        # API call with deprecation check happens after version extraction

        # Call Thunderstore API to get package info
        # API URL pattern: {THUNDERSTORE_API_BASE_URL}/{namespace}/{name}/
        local api_url="${THUNDERSTORE_API_BASE_URL}/${mod_namespace}/${mod_name}/"
        log "  Checking API: ${api_url}"

        local api_response=$(curl -s -f "${api_url}")
        if [ $? -ne 0 ]; then
            log_error "ERROR: Failed to fetch package info from Thunderstore API for ${mod_namespace}-${mod_name}"
            continue
        fi

        # Extract latest version and download URL from API response
        # The experimental package API returns detailed info with latest.version_number, latest.download_url, and is_deprecated
        local latest_version=$(echo "${api_response}" | jq -r '.latest.version_number')
        local api_download_url=$(echo "${api_response}" | jq -r '.latest.download_url')
        local api_is_deprecated=$(echo "${api_response}" | jq -r '.is_deprecated')

        if [ -z "${latest_version}" ] || [ "${latest_version}" == "null" ]; then
            log_error "ERROR: Could not extract version from API response for ${mod_namespace}-${mod_name}"
            continue
        fi

        # Wait before next API request to be respectful to Thunderstore
        log "  Waiting ${MOD_API_WAIT_SECONDS} seconds before next API request..."
        sleep ${MOD_API_WAIT_SECONDS}

        if [ -z "${api_download_url}" ] || [ "${api_download_url}" == "null" ]; then
            log_error "ERROR: Could not extract download URL from API response for ${mod_namespace}-${mod_name}"
            continue
        fi

        # Check if package is deprecated according to API
        if [ "${api_is_deprecated}" = "true" ]; then
            log_warning "  WARNING: Mod is deprecated on Thunderstore"
            log_warning "  Backing up and removing deprecated mod..."

            backup_and_remove_old_mod_versions "${mod_namespace}" "${mod_name}"
            mark_mod_deprecated_in_json "${mod_namespace}" "${mod_name}"

            continue
        fi

        log "  Latest version: ${latest_version}"
        log "  Installed version: ${mod_version}"

        # Check if mod is actually installed in plugins directory
        # Mods extract to folders named {namespace}-{name}-{version}
        local mod_folder="${mod_namespace}-${mod_name}-${latest_version}"
        local mod_installed=false
        if [ -d "${PLUGINS_DIR}/${mod_folder}" ]; then
            mod_installed=true
            log "  Mod folder found: ${mod_folder}"
        else
            log "  Mod folder not found: ${mod_folder}"
        fi

        # Download and install if version mismatch OR if mod files don't exist
        if [ "${latest_version}" != "${mod_version}" ] || [ "$mod_installed" = false ]; then
            if [ "${latest_version}" != "${mod_version}" ]; then
                log "  Version mismatch! Downloading update..."
            else
                log "  Mod not installed. Downloading..."
            fi

            # Backup and remove old versions before installing new version
            log "  Backing up and removing old versions..."
            backup_and_remove_old_mod_versions "${mod_namespace}" "${mod_name}"

            # Use download URL from API response
            local download_url="${api_download_url}"

            log "  Download URL: ${download_url}"

            # Create temporary directory for download
            local temp_dir=$(mktemp -d)
            local mod_zip="${temp_dir}/${mod_name}.zip"

            # Download the mod
            if ! curl -L -f -o "${mod_zip}" "${download_url}" 2>&1 | tee -a "${LOG_FILE}"; then
                log_error "ERROR: Failed to download mod from ${download_url}"
                rm -rf "${temp_dir}"
                continue
            fi

            log "  Download completed. Extracting..."

            # Extract to temporary directory first
            local extract_dir="${temp_dir}/extract"
            mkdir -p "${extract_dir}"

            if ! unzip -q -o "${mod_zip}" -d "${extract_dir}/" 2>&1 | tee -a "${LOG_FILE}"; then
                log_error "ERROR: Failed to extract mod ${mod_namespace}-${mod_name}"
                rm -rf "${temp_dir}"
                continue
            fi

            # Create target directory with proper naming: {namespace}-{name}-{version}
            local target_dir="${PLUGINS_DIR}/${mod_namespace}-${mod_name}-${latest_version}"
            mkdir -p "${target_dir}"

            # Move all extracted contents to the target directory
            mv "${extract_dir}"/* "${target_dir}/" 2>/dev/null || true

            log "  Mod installed successfully: ${mod_name} v${latest_version}"

            # Clean up
            rm -rf "${temp_dir}"

            # Update mods.json with new version
            update_mods_json_version "${mod_namespace}" "${mod_name}" "${latest_version}"

            # Wait before next download to avoid rate limiting (only if we actually downloaded)
            log "  Waiting ${MOD_DOWNLOAD_WAIT_SECONDS} seconds before next download..."
            sleep ${MOD_DOWNLOAD_WAIT_SECONDS}
        else
            log "  Mod is up to date"
        fi
    done

    return 0
}

################################################################################
# Main Execution
################################################################################
main() {
    echo "" >> "${LOG_FILE}"
    echo "################################################################################" >> "${LOG_FILE}"
    echo "################################################################################" >> "${LOG_FILE}"
    echo "###                          SERVER STARTING                                 ###" >> "${LOG_FILE}"
    echo "################################################################################" >> "${LOG_FILE}"
    echo "################################################################################" >> "${LOG_FILE}"
    echo "" >> "${LOG_FILE}"

    log_section "Valheim Server Install/Update Script Started"
    log "Valheim server directory: ${VALHEIM_SERVER_DIR}"

    # Install/update steamcmd
    if install_steamcmd; then
        log "SteamCMD ready"
    else
        log_error "ERROR: SteamCMD installation failed"
        exit 1
    fi

    # Install/update Valheim server
    if install_valheim_server; then
        log "Valheim server ready"
    else
        log_error "ERROR: Valheim server installation failed"
        exit 1
    fi

    # Install/update BepInEx
    if install_bepinex; then
        log "BepInEx ready"
    else
        log_error "ERROR: BepInEx installation failed"
        exit 1
    fi

    # Install/update mods
    if install_mods; then
        log "Mods ready"
    else
        log_error "ERROR: Mods installation failed"
        exit 1
    fi

    log_section "Script Completed Successfully"
}

# Run main function
main
exit 0
