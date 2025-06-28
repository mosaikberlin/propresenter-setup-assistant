# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS-specific automation tool for configuring ProPresenter with OneDrive sync for worship teams. The main script is a Bash-based command-line tool that automates the setup of ProPresenter, OneDrive authentication, SharePoint sync, and standardized folder structures.

## Architecture

### Main Components

- **Main Script**: `ProPresenter-Setup-Assistant.command` - Entry point with UI, step orchestration, and error handling
- **Modular Libraries**: `lib/` directory contains specialized modules for different setup phases:
  - `onedrive-*.sh` - OneDrive detection, installation, authentication, and setup
  - `propresenter-*.sh` - ProPresenter version management and configuration
  - `sharepoint-sync.sh` - SharePoint library synchronization
  - `symlink-creation.sh` - Standardized folder structure creation
  - `self-update.sh` - Automatic script updates via GitHub releases

### Configuration Management

- **Environment Config**: `docs/app-design/environment.md` contains tenant IDs, SharePoint URLs, and system paths
- **Version Control**: `VERSION` file contains current script version (read dynamically by main script)
- **Logging**: All operations logged to `logs/setup-assistant.log`

### Key Design Patterns

- **State-based Authentication**: OneDrive auth handles multiple account scenarios
- **Modular Architecture**: Each major function isolated in separate lib files
- **Graceful Error Handling**: Comprehensive backup/rollback capabilities
- **User Dialog Integration**: Native macOS dialogs using `osascript`
- **Symlink-based Sync**: Creates standardized paths pointing to OneDrive locations

## Development Commands

This is a Bash script project without traditional build tools. Key development operations:

### Testing and Validation

```bash
# Syntax check main script
bash -n ProPresenter-Setup-Assistant.command

# Check all library modules
for file in lib/*.sh; do bash -n "$file"; done

# Test script execution (requires macOS)
./ProPresenter-Setup-Assistant.command
```

### Release Management

```bash
# Update version for release
echo "1.4.0" > VERSION

# Create release documentation
touch docs/releases/v1.4.0.md

# Push to trigger automated release (see docs/RELEASE_PROCESS.md)
git add . && git commit -m "Release v1.4.0" && git push origin main
```

### Log Analysis

```bash
# View current session logs
tail -f logs/setup-assistant.log

# Search for errors
grep "ERROR" logs/setup-assistant.log
```

## Important Implementation Details

### OneDrive Integration

- Supports multiple Microsoft 365 accounts per user
- Handles both `@mosaikberlin.com` and guest accounts
- Uses folder monitoring to detect sync completion
- Implements retry logic for authentication failures

### ProPresenter Configuration

- Modifies `~/Library/Preferences/com.renewedvision.ProPresenter.plist`
- Updates `applicationShowDirectory` to use symlink paths
- Creates automatic backups before configuration changes
- Includes rollback capability on failures

### Symlink Strategy

- Creates `~/ProPresenter-Sync/` as standardized root
- Maps OneDrive SharePoint paths to consistent local paths
- Enables identical configurations across all team machines
- Handles path changes without ProPresenter reconfiguration

### Security Considerations

- No API keys or credentials stored in code
- Uses native macOS authentication dialogs
- All external URLs sourced from environment.md
- Tenant-specific configuration isolated to environment file

## Testing

- Manual testing required on macOS systems
- Test with fresh user accounts to verify clean setup
- Validate with existing OneDrive configurations
- Test rollback scenarios when configuration fails
- Verify symlink creation across different OneDrive sync states

When making changes, always test the complete setup flow as the script is designed for end-user execution in production environments.
