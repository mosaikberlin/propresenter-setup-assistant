# ProPresenter OneDrive Setup Assistant - Design Document

## 1. Project Overview & Problem Statement

### Project Overview

This project creates a foolproof automated setup tool for configuring ProPresenter with OneDrive sync across multiple Mac computers. Designed for worship teams and presentation environments where consistent configuration is critical.

### Problem Statement

- **Multiple Mac computers** used for worship service presentation and slide preparation
- **ProPresenter** requires strict folder references that break when synced across machines
- **OneDrive SharePoint libraries** need to be synced and kept permanently on device
- **Different users** have different OneDrive folder naming (language-dependent)
- **Non-technical users** need a simple setup process
- **Version consistency** required across team to prevent compatibility issues

## 2. Solution Architecture

### Core Approach

Create a self-updating, double-clickable script that automates the entire setup process using symbolic links to create consistent folder references across all machines.

### Key Design Principles

- **Zero User Expertise Required**: Non-technical users can complete setup in under 5 minutes
- **Consistent Results**: Identical ProPresenter configuration across all team machines
- **Self-Maintaining**: Automatic updates and version management
- **Robust Error Handling**: Graceful failure recovery with rollback capabilities
- **Offline Capable**: Ensures critical content is available without internet connection

### Solution Components

1. **ProPresenter Version Management**: Ensures team uses consistent software version
2. **OneDrive Automation**: Handles installation, authentication, and library sync
3. **Standardized Structure**: Creates consistent folder paths via symbolic links
4. **Configuration Management**: Updates ProPresenter settings programmatically
5. **Self-Updating Distribution**: Always delivers latest script version to users

## 3. Core Components & Workflow

### User Experience Flow

```text
1. Script Version Check & Auto-Update
   ↓
2. Welcome Screen with Enhanced UI
   ↓
3. ProPresenter Version Validation & Installation
   ↓
4. OneDrive Installation & Authentication
   ↓
5. Tenant Validation & User Type Detection
   ↓
6. SharePoint Library Discovery & Sync
   ↓
7. Programmatic "Always Keep on Device" Setting
   ↓
8. Standardized Symlink Creation
   ↓
9. ProPresenter Configuration Update
   ↓
10. Comprehensive Verification & Success Report
```

### Main Script Components

1. **Main Script** - Self-updating orchestrator with enhanced terminal UI
2. **Version Management Module** - ProPresenter version detection and Homebrew integration
3. **OneDrive Detection Module** - Installation status and M365 authentication verification
4. **Library Discovery Module** - Microsoft Graph API integration for SharePoint library discovery
5. **Sync Automation Module** - ODOpen protocol implementation for automated sync
6. **Pin Management Module** - Programmatic "Always keep on device" functionality
7. **Symlink Creation Module** - Standardized folder structure creation
8. **Configuration Update Module** - ProPresenter preference file modifications
9. **Verification Module** - Comprehensive setup validation and testing

### Target Folder Structure

Creates a standardized three-tier organization:

```text
~/ProPresenter-Sync/
├── Application-Directory/           # ProPresenter Application Directory
│   ├── Configuration/              # ProPresenter configuration files
│   ├── Downloads/                  # Downloaded content
│   ├── Libraries/                  # ProPresenter libraries
│   ├── Media/                      # Media assets
│   ├── Playlists/                  # ProPresenter playlists
│   ├── Presets/                    # ProPresenter presets
│   └── Themes/                     # ProPresenter themes
├── Long-living-Assets/             # Content with longer lifecycle
│   ├── Audience-Information/       # Contact cards and similar materials
│   └── Pre-Post-Service-Roll/      # Pre/post service content
└── Short-living-Assets/            # Content that changes frequently
    ├── Announcements/              # Weekly/event announcements
    └── Sermons/                    # Sermon-specific content
```

### Key Automation Features

1. **Self-Updating Script** - Automatic version checking and updating from repository releases
2. **ProPresenter Version Management** - Consistent version installation via Homebrew
3. **Enhanced Terminal Experience** - Colored output and native macOS dialogs
4. **Auto-detect OneDrive paths** regardless of user/language
5. **Microsoft 365 Integration** - Automatic account detection and authentication verification
6. **Programmatic SharePoint Sync** - ODOpen protocol for automatic library sync without manual navigation
7. **Teams Channel Discovery** - Leverage Teams memberships to identify accessible SharePoint libraries
8. **Automated "Always keep on device"** - Programmatic pinning using OneDrive command-line tools
9. **Graph API Integration** - Resolve Site/Web/List IDs for ODOpen protocol automation
10. **Standardized symlink structure** across all machines
11. **ProPresenter config updates** to use symlinks
12. **Comprehensive verification checks** to ensure everything works

## 4. Distribution Strategy

### Double-Clickable Script Distribution

**Enhanced Terminal Experience:**

- Use `.command` file extension for native Terminal execution
- Implement colored terminal output for improved readability
- Progress indicators with status messages and icons
- Native macOS dialogs using `osascript` for user interaction

**Self-Updating Mechanism:**

- Automatic version checking against repository releases
- Download and install latest script version when available
- Seamless restart with updated script after download
- Fallback to current version if update fails

**GitHub Release Distribution:**

- Host script releases on GitHub repository
- Downloadable packages with complete script suite
- Version-controlled releases with changelog documentation
- Simple download and double-click execution for end users

### Distribution Package Structure

```text
ProPresenter-Setup-Assistant/
├── ProPresenter-Setup-Assistant.command    # Double-clickable main script
├── lib/                                     # Supporting modules
│   ├── version-management.sh               # ProPresenter version handling
│   ├── onedrive-detection.sh              # OneDrive detection and auth
│   ├── library-discovery.sh               # SharePoint library discovery
│   ├── sync-automation.sh                 # ODOpen protocol automation
│   ├── pin-management.sh                  # "Always keep on device" functionality
│   ├── symlink-creation.sh                # Standardized folder structure
│   └── configuration-update.sh            # ProPresenter preference updates
├── docs/
│   ├── environment.md                      # Environment-specific configuration
│   ├── troubleshooting.md                 # Common issues and solutions
│   └── user-guide.md                      # End-user documentation
└── README.md                               # Overview and quick start
```

## 5. Technical Implementation

### Self-Updating Architecture

**Version Management:**

- Check GitHub repository for latest release version
- Compare current script version with available updates
- Download and install updates automatically when available
- Restart script with updated version seamlessly

### ProPresenter Version Control

**Homebrew Integration:**

- Leverage Homebrew package manager for consistent installations
- Verify installed ProPresenter version against team requirements
- Automatic installation or update when version mismatch detected
- Maintain compatibility across all team machines

**Version Validation Process:**

- Check for existing ProPresenter installation
- Compare installed version against required team version
- Prompt user for installation/update when version mismatch detected
- Backup existing configuration before version changes

### OneDrive Automation

**Installation & Authentication:**

- Detect if OneDrive is already installed
- Download and install OneDrive package if missing
- Handle admin privilege requirements
- Launch OneDrive for user authentication
- Monitor system logs for authentication status
- Verify tenant authentication using organization-specific identifiers
- Support both primary organizational users and guest users

**Detection Tasks:**

- Verify OneDrive installation and process status
- Check Microsoft 365 authentication via Web Account Manager API
- Validate user belongs to organization tenant
- Verify access to required SharePoint libraries
- Locate existing OneDrive shared library locations
- Detect current user's OneDrive folder naming convention
- Query accessible SharePoint libraries via Graph API
- Map user permissions to available SharePoint sites

### ODOpen Protocol Implementation

**Automated SharePoint Sync:**

- Generate ODOpen URLs with resolved SharePoint identifiers
- Trigger automatic library synchronization without user navigation
- Monitor sync progress and verify successful completion

**Site ID Resolution:**

- Query Microsoft Graph API to resolve Site/Web/List IDs from URLs
- Detect Teams channel memberships and associated libraries
- Verify user permissions before attempting sync operations

### Programmatic Pin Management

**Local Availability Assurance:**

- Use OneDrive command-line tools for "Always keep on device" functionality
- Manage OneDrive process lifecycle during pin operations
- Ensure offline accessibility of critical content

### Symlink Management

**Path Normalization Strategy:**

- Create consistent folder structure across all machines
- Use symbolic links to map OneDrive folders to standardized paths
- Ensure ProPresenter finds identical folder structure regardless of OneDrive path variations
- Convert variable OneDrive paths to consistent symlink targets
- Handle different user accounts and OneDrive naming conventions
- Maintain relative path relationships between folder hierarchies

### ProPresenter Configuration

**Preference File Management:**

- Safely modify ProPresenter configuration files using macOS defaults system
- Update Application Directory path to use standardized symlink location
- Backup existing configuration before making changes

**Key Configuration Updates:**

- **Primary Setting**: `applicationShowDirectory` preference key
- **Target Path**: Point to standardized symlink directory structure
- **Related Settings**: Clear dependent library paths for automatic regeneration
- **Process Safety**: Ensure ProPresenter is closed during configuration changes

**Configuration Verification:**

- Confirm settings were applied correctly
- Implement rollback mechanism if configuration fails
- Verify ProPresenter launches successfully with new paths

## 6. Error Handling & Recovery

### Common Issues to Handle

- **Script Update Failures**: Network connectivity issues, GitHub API limitations, corrupted downloads
- **ProPresenter Version Conflicts**: Incompatible versions, Homebrew installation failures, permission issues
- **OneDrive Installation Failures**: Network issues, insufficient disk space, admin privilege requirements
- **Microsoft 365 Authentication Failures**: Wrong credentials, multi-factor authentication, expired tokens
- **Tenant Mismatch**: User authenticated to wrong Microsoft 365 organization
- **Teams Channel Access**: User not member of required Teams channel
- **SharePoint Library Permissions**: Insufficient access to document libraries
- **ODOpen Protocol Failures**: Network connectivity, invalid Site/Web/List IDs
- **OneDrive Quit/Restart Issues**: Process conflicts during pin operations
- **Guest User Authentication**: External email authentication with organizational access
- **Multi-Tenant Scenarios**: Multiple OneDrive accounts, tenant switching
- **Existing Symlinks Conflict**: Previous setup conflicts, broken links
- **Configuration Backup Failures**: Insufficient permissions, disk space issues

### Error Recovery Strategies

**Graceful Failure Handling:**

- Implement retry mechanisms with exponential backoff
- Provide clear error messages with suggested solutions
- Automatic rollback to previous working state when possible
- User-friendly guidance for manual intervention when needed

**Authentication Error Recovery:**

- Multiple authentication attempts with user guidance
- Clear instructions for organizational credential usage
- Fallback to manual authentication when automated methods fail
- Support contact information for complex authentication issues

**Configuration Recovery:**

- Automatic backup before any configuration changes
- Rollback mechanism when configuration updates fail
- Verification of successful configuration application
- Preservation of user data during recovery operations

### Maintenance Tools

- **Auto-Update Mechanism** - Automatic script version checking and updating
- **Verify Script** - Check if setup is still working correctly
- **Repair Script** - Fix broken symlinks and configuration issues
- **Version Management** - ProPresenter version consistency across team
- **Uninstall Script** - Clean removal of all setup components
- **Diagnostic Tool** - Comprehensive system state analysis

## 7. Success Criteria & Benefits

### Success Criteria

- Any team member can run the setup in under 5 minutes with minimal interaction
- ProPresenter configurations work identically across all machines
- SharePoint libraries are automatically discovered and synced without manual navigation
- "Always keep on device" is set programmatically ensuring offline availability
- OneDrive sync issues are automatically resolved
- Setup survives OneDrive updates and path changes
- Teams channel access automatically enables SharePoint library sync
- Non-technical users can successfully complete setup without assistance
- Microsoft 365 authentication is verified automatically before proceeding

### Technical Advantages

**Reduced User Interaction:**

- Zero SharePoint navigation required - ODOpen protocol handles sync initiation
- Automatic library discovery - Graph API identifies accessible libraries
- Teams integration - Existing channel memberships drive library access

**Enhanced Reliability:**

- Programmatic verification at each step ensures successful completion
- Automatic retry logic for network-dependent operations
- Graceful OneDrive restart handling for pin operations

**Future-Proof Design:**

- API-based approach survives UI changes in OneDrive/SharePoint
- Authentication verification prevents setup failures due to expired tokens
- Permissions validation before attempting operations

### Multi-Tenant Environment Support

**Tenant-Specific Validation:**

- Validate user belongs to organization's Microsoft 365 tenant
- Support both organizational users and guest users with external email addresses
- Validate access to specific ProPresenter Teams channel
- Confirm permissions to required document libraries

**Multi-Tenant Challenges:**

- Users may have connections to multiple Microsoft 365 tenants
- OneDrive instances from different organizations may be synced
- Authentication context must be validated for correct tenant
- Guest users require special handling for tenant access validation

See `docs/environment.md` for detailed organization-specific configuration.
