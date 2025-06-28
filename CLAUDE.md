# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS-specific automation tool for configuring ProPresenter with OneDrive shortcuts for worship teams. The main script is a Bash-based command-line tool that automates the setup of ProPresenter, OneDrive authentication, SharePoint shortcut creation, and direct path configuration.

## Architecture

### Main Components

- **Main Script**: `ProPresenter-Setup-Assistant.command` - Entry point with UI, step orchestration, and error handling
- **Modular Libraries**: `lib/` directory contains specialized modules for different setup phases:
  - `onedrive-*.sh` - OneDrive detection, installation, authentication, and setup
  - `propresenter-*.sh` - ProPresenter version management and configuration
  - `sharepoint-sync.sh` - SharePoint library shortcut creation and CloudStorage-based detection
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
- **OneDrive Shortcut Strategy**: Uses native OneDrive shortcuts for direct path configuration

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
echo "2.1.0" > VERSION

# Create release documentation
touch docs/releases/v2.1.0.md

# Push to trigger automated release (see docs/RELEASE_PROCESS.md)
git add . && git commit -m "Release v2.1.0" && git push origin main
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
- Uses OneDrive shortcuts instead of complex sync operations
- CloudStorage-based detection in `~/Library/CloudStorage`
- Flexible keyword matching for "Visuals", "Team", "ProPresenter" folders
- Implements retry logic for authentication failures

### ProPresenter Configuration

- Modifies `~/Library/Preferences/com.renewedvision.ProPresenter.plist`
- Updates `applicationShowDirectory` to use direct OneDrive shortcut paths
- Creates automatic backups before configuration changes
- Includes rollback capability on failures
- Uses `$SHAREPOINT_SYNC_FOLDER/Application Directory` for direct path configuration

### OneDrive Shortcut Strategy (v2.0.0+)

- Uses native OneDrive shortcuts instead of complex symlinks
- Direct path configuration: `~/Library/CloudStorage/OneDrive-.../Visuals Team - ProPresenter/Application Directory`
- Enables consistent configurations across all team machines
- Eliminates intermediate symlink layer for better reliability
- User creates shortcuts via "Add shortcut to OneDrive" (not "Sync")

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
- Verify OneDrive shortcut creation and detection across different account types
- Test CloudStorage-based folder detection with various naming patterns

When making changes, always test the complete setup flow as the script is designed for end-user execution in production environments.

## Version 2.0.0+ Breaking Changes

**IMPORTANT**: Version 2.0.0 introduced breaking changes that removed the symlink-based approach:

- `lib/symlink-creation.sh` module removed entirely
- `~/ProPresenter-Sync/` directory no longer created or used
- Direct OneDrive shortcut paths used instead of symlinks
- User instructions changed from "Sync" to "Add shortcut to OneDrive"
- Setup flow reduced from 11 to 10 steps

Existing installations are automatically migrated to the new direct path approach.
