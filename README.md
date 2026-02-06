# Valheim Dedicated Server with BepInEx Mods

Automated setup and management for a Valheim dedicated server on **Debian Linux** with BepInEx modding framework, automatic updates, and systemd service management.

## Quick Start

### Prerequisites

- **Debian 12+** Linux Proxmox Container (CT)
- **6 GB RAM** (4 GB minimum), **20 GB disk** (10 GB minimum)
- **Root access** (via `sudo` if using privileged container or full Debian; unprivileged CTs run as root by default)
- Network access to Steam and Thunderstore

> **Note**: These instructions are optimized for hosting on an unprivileged Proxmox Debian container (CT). If you're using a privileged container or full Debian instance, modifications may be required (especially regarding `sudo` usage, file permissions, and systemd service definitions).

### Initial Setup

1. Copy scripts to your Linux server:
   ```bash
   scp *.sh user@server:~/
   scp mods.json user@server:~/
   ```

2. Configure your server (create from example):
   ```bash
   mv valheim-config.local.example.sh valheim-config.local.sh
   # Edit with your server name, password, world name, port etc
   nano valheim-config.local.sh
   ```

3. Run initial installation:
   ```bash
   ~/update-server.sh
   ```

4. Setup systemd service (run once; use `sudo` if in a privileged container or full Debian):
   ```bash
   ~/setup-service.sh    # Unprivileged Proxmox container (already root)
   sudo ~/setup-service.sh  # Privileged container or full Debian instance
   ```

5. Start and manage server:
   ```bash
   val_start     # Start server
   val_stop      # Stop server
   val_restart   # Restart (auto-updates first)
   val_status    # Check status
   val_log       # View live logs
   ```

## Default Directory and File Locations

| Item | Location |
|------|----------|
| Valheim Server | `/opt/valheim-server/` |
| Mods | `/opt/valheim-server/BepInEx/plugins/` |
| Custom Mod Manifest | `~/mods.json` |
| Update Log | `/var/log/valheim-update.log` |
| Service Config | `/etc/systemd/system/valheim.service` |

## Configuration

**Shared defaults** in `valheim-config.sh` - Edit only to change generic defaults or add features.

**Per-deployment settings** in `valheim-config.local.sh`:

1. Copy the example:
   ```bash
   cp valheim-config.local.example.sh valheim-config.local.sh
   ```

2. Edit with your settings:
   ```bash
   nano valheim-config.local.sh
   ```

   Set these values:
   ```bash
   SERVER_NAME="Your Server Name"
   SERVER_PORT="2456"
   SERVER_WORLD="World_Name"
   SERVER_PASSWORD="your-secret-password"
   SERVER_PUBLIC="0"
   ```

The local config contains private information and should **NOT** but pushed remotely - keeps passwords secure and allows disparate deployments.

**Important**: Set `MOD_DOWNLOAD_WAIT_SECONDS` and `MOD_API_WAIT_SECONDS` to be respectful to Thunderstore servers. Don't set below 2 seconds to avoid rate limiting.

## Mod Management

### The mods.json Format

```json
{
  "mods": [
    {
      "namespace": "Advize",
      "name": "PlantEverything",
      "version": "1.20.0",
      "deprecated": false,
      "versionHistory": [
        {
          "version": "1.20.0",
          "installedDate": "2026-02-06T10:30:00Z"
        }
      ]
    }
  ]
}
```

### How Mod Updates Work

1. Script reads `mods.json`
2. Checks Thunderstore API for each mod's latest version (uses experimental API endpoints at present)
3. If a newer version exists, downloads and installs it
4. Updates `mods.json` with new version and timestamp
5. Keeps old versions in `mod-backup/` directory
6. Removes mods no longer in `mods.json`

Note that any manually overridden mod configuration changes will need to be manually applied again after an update (the mod directory is completely replaced on each download).

### Deprecated Mods

When a mod is deprecated on Thunderstore:
1. Script detects deprecation via API
2. Backs up the mod to `mod-backup/`
3. Removes it from the plugins directory
4. Updates `mods.json` to mark as deprecated with timestamp

## Logging

All script operations are logged to `/var/log/valheim-update.log` with:
- Timestamps
- Detailed operation tracking

View logs:
```bash
# View & attach to live service logs (includes server output)
val_log

# View full log file (script output only - does not include server output)
cat /var/log/valheim-update.log

# View recent entries
tail -n 50 /var/log/valheim-update.log
```

## Dependencies

Scripts automatically install missing dependencies:
- `curl` - For downloading files
- `unzip` - For extracting archives
- `jq` - For JSON parsing
- `steamcmd` - For game server installation

## Troubleshooting

### Service won't start
```bash
# Check service status
systemctl status valheim.service

# View full errors
journalctl -u valheim.service -n 50

# View update log
cat /var/log/valheim-update.log | tail -50
```

### Mods not updating
```bash
# Check mods.json is valid JSON
jq . ~/mods.json

# Run update manually to see errors
~/update-server.sh

# Check mod folder structure
ls -la /opt/valheim-server/BepInEx/plugins/
```

### Reconfigure everything
```bash
# Update configuration and rerun setup
# Unprivileged Proxmox container (no sudo needed):
~/setup-service.sh
val_restart

# Privileged container or full Debian (with sudo):
sudo ~/setup-service.sh
val_restart
```

## Architecture Notes

- **Idempotent updates**: Scripts can be run multiple times without causing issues
- **Version tracking**: `mods.json` maintains complete history of installed versions until mods are removed from the file manually
- **Mod isolation**: Each mod installed in `{namespace}-{name}-{version}` folder
- **Backup strategy**: Old mod versions backed up before removal to retain custom settings

## Support

For issues with individual mods, visit their Thunderstore pages:
- https://thunderstore.io/c/valheim/

For Valheim-specific issues:
- https://valheim.fandom.com/wiki/Dedicated_servers

## License & References

- Valheim: https://www.valheimgame.com/
- BepInEx: https://github.com/BepInEx/BepInEx
- Thunderstore: https://thunderstore.io/c/valheim/
