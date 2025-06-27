# ProPresenter OneDrive Setup Assistant - Implementation Plan

This document provides step-by-step implementation instructions for AI developers building the ProPresenter OneDrive Setup Assistant.

## Overview

Build a self-updating, double-clickable macOS script that automates ProPresenter configuration with OneDrive sync. Each step represents a complete, functional component that can be implemented and verified independently.

## Implementation Steps

### Step 1: Create Core Script Infrastructure

**Objective**: Establish the foundation script with enhanced terminal UI and basic structure.

**Implementation Details**:

- Create main script file `ProPresenter-Setup-Assistant.command` with executable permissions
- Implement colored terminal output using bash color codes (RED, GREEN, YELLOW, BLUE, CYAN, NC)
- Create UI helper functions: `echo_header()`, `echo_step()`, `echo_status()`, `echo_success()`, `echo_error()`, `echo_warning()`, `echo_progress()`
- Build basic script structure with welcome screen and user confirmation dialog
- Implement script metadata variables for version tracking
- Add graceful exit handling with cleanup functions
- Create `lib/` directory structure for modular components
- Source environment configuration from `docs/app-design/environment.md` file parsing

**Key Functions to Implement**:

- Terminal clearing and header display
- User confirmation prompts using native macOS `osascript` dialogs
- Progress tracking with step counters
- Error logging to both terminal and log files

**Verification**: Script launches, displays colored welcome screen, handles user interaction, and exits gracefully.

---

### Step 2: Set Up GitHub Release Automation

**Objective**: Establish automated GitHub release creation to enable testing of the self-updating architecture.

**Implementation Details**:

- Create GitHub Actions workflow for automated release creation on version tags
- Set up automatic ZIP packaging of script and supporting files
- Implement semantic versioning validation and release notes generation
- Configure workflow to trigger on git tags matching version pattern (v*.*.*)
- Create release template with standardized naming and asset organization
- Add workflow for validating script functionality before release
- Document the release process and tagging conventions
- Test workflow with initial v1.0.0 tag creation

**Key Actions to Implement**:

- Create `.github/workflows/release.yml` with automated release workflow
- Set up ZIP packaging that includes script, lib/, docs/ directories
- Configure automatic release notes generation from commits
- Add workflow validation steps (syntax check, basic functionality test)
- Create release naming convention: "ProPresenter Setup Assistant v{version}"
- Document tagging process for triggering releases
- Test workflow by creating v1.0.0 git tag

**Environment Integration**: Use GitHub repository configuration from environment.md for workflow setup.

**Verification**: GitHub Actions workflow successfully creates release with ZIP asset when git tag is pushed, and the release is accessible via GitHub Releases API.

---

### Step 3: Implement Self-Updating Architecture

**Objective**: Build automatic version checking and update mechanism using GitHub Releases API.

**Implementation Details**:

- Create version comparison logic using semantic versioning
- Implement GitHub API integration to fetch latest release information
- Build download mechanism for ZIP packages from GitHub releases
- Create backup and restore functionality for script updates
- Implement seamless script restart after successful update
- Add network connectivity checks before attempting updates
- Create fallback mechanisms when updates fail
- Handle GitHub API rate limiting and error responses

**Key Functions to Implement**:

- `check_for_updates()` - Query GitHub API and compare versions
- `download_and_restart_with_latest()` - Download, extract, and restart
- `parse_version()` - Semantic version comparison logic
- `verify_update_integrity()` - Validate downloaded updates

**Environment Integration**: Read GitHub repository URL and API endpoints from environment configuration.

**Verification**: Script checks for updates, downloads newer versions when available, and restarts with updated script.

---

### Step 4: Build ProPresenter Version Management Module

**Objective**: Implement ProPresenter installation and version consistency using Homebrew.

**Implementation Details**:

- Create Homebrew installation check and setup if missing
- Implement ProPresenter version detection from application bundle Info.plist
- Build version comparison against target version from environment configuration
- Create Homebrew-based ProPresenter installation workflow
- Implement fallback to direct download from Renewed Vision if Homebrew unavailable
- Add existing ProPresenter configuration backup before version changes
- Create user prompts for version mismatch scenarios
- Handle multiple ProPresenter installations and cleanup

**Key Functions to Implement**:

- `check_homebrew_installation()` - Verify and install Homebrew
- `get_propresenter_version()` - Extract version from app bundle
- `install_propresenter_via_homebrew()` - Homebrew installation process
- `backup_propresenter_config()` - Save existing configuration
- `verify_propresenter_installation()` - Post-installation validation

**Environment Integration**: Read target ProPresenter version and installation method from environment configuration.

**Verification**: Script detects ProPresenter version, installs correct version via Homebrew, and maintains configuration backups.

---

### Step 5: Develop OneDrive Detection and Authentication Module

**Objective**: Handle OneDrive installation, authentication, and tenant validation.

**Implementation Details**:

- Create OneDrive installation detection by checking `/Applications/OneDrive.app`
- Implement OneDrive package download and installation with admin privilege handling
- Build authentication status monitoring using macOS system logs
- Create tenant validation using organization-specific identifiers from environment
- Implement support for both organizational and guest user authentication
- Add retry mechanisms for authentication failures
- Create user guidance for Microsoft 365 credential usage
- Handle multiple OneDrive account scenarios

**Key Functions to Implement**:

- `check_onedrive_installation()` - Verify OneDrive presence
- `install_onedrive()` - Download and install OneDrive package
- `launch_onedrive_authentication()` - Start authentication process
- `verify_tenant_authentication()` - Validate correct tenant access
- `handle_authentication_retry()` - Retry logic for auth failures

**Environment Integration**: Read tenant ID, domain, and authentication requirements from environment configuration.

**Verification**: Script installs OneDrive if missing, guides user through authentication, and validates correct tenant access.

---

### Step 6: Create SharePoint Library Discovery and Sync Module

**Objective**: Implement automated SharePoint library discovery and ODOpen protocol sync.

**Implementation Details**:

- Build Microsoft Graph API integration for SharePoint site discovery
- Create SharePoint library access validation using user permissions
- Implement Site/Web/List ID resolution from SharePoint URLs
- Build ODOpen URL generation for automatic library synchronization
- Create sync progress monitoring and verification
- Add Teams channel membership detection for library access
- Implement retry logic for network-dependent operations
- Handle SharePoint permission errors and user guidance

**Key Functions to Implement**:

- `discover_sharepoint_libraries()` - Find accessible libraries via Graph API
- `resolve_sharepoint_ids()` - Extract Site/Web/List IDs from URLs
- `generate_odopen_urls()` - Create ODOpen protocol URLs
- `trigger_sharepoint_sync()` - Execute ODOpen commands
- `verify_sync_completion()` - Monitor and confirm sync success

**Environment Integration**: Read SharePoint site paths, library paths, and Teams configuration from environment.

**Verification**: Script discovers SharePoint libraries, generates ODOpen URLs, and successfully triggers automatic synchronization.

---

### Step 7: Implement Programmatic Pin Management Module

**Objective**: Build "Always keep on device" functionality using OneDrive command-line tools.

**Implementation Details**:

- Create OneDrive process lifecycle management (quit/restart)
- Implement OneDrive `/setpin` command execution with proper error handling
- Build recursive pinning for entire folder structures
- Add verification of pin status after operations
- Create graceful OneDrive restart after pinning operations
- Handle process conflicts and timing issues
- Implement rollback mechanisms for failed pin operations
- Add user feedback for offline availability confirmation

**Key Functions to Implement**:

- `quit_onedrive_safely()` - Terminate OneDrive process gracefully
- `pin_folders_for_offline()` - Execute setpin commands recursively
- `restart_onedrive()` - Launch OneDrive after pin operations
- `verify_pin_status()` - Confirm offline availability
- `handle_pin_failures()` - Error recovery for pin operations

**Verification**: Script successfully pins SharePoint library content for offline access and verifies availability.

---

### Step 8: Build Symlink Creation and Path Normalization Module

**Objective**: Create standardized folder structure using symbolic links.

**Implementation Details**:

- Create OneDrive path detection logic handling various user account types
- Build path normalization to handle different OneDrive naming conventions
- Implement symlink creation for three-tier folder structure
- Add conflict detection and resolution for existing symlinks
- Create relative path maintenance between folder hierarchies
- Implement cleanup of broken or outdated symlinks
- Add verification that symlinks point to correct OneDrive locations
- Handle permission issues and provide user guidance

**Key Functions to Implement**:

- `detect_onedrive_paths()` - Find OneDrive sync locations
- `normalize_folder_paths()` - Handle naming variations
- `create_symlink_structure()` - Build standardized folder hierarchy
- `resolve_symlink_conflicts()` - Handle existing symlinks
- `verify_symlink_integrity()` - Confirm symlinks work correctly

**Environment Integration**: Read folder mapping configuration and target symlink structure from environment.

**Verification**: Script creates consistent symlink structure pointing to correct OneDrive folders across different user accounts.

---

### Step 9: Develop ProPresenter Configuration Update Module

**Objective**: Programmatically update ProPresenter preferences to use symlink paths.

**Implementation Details**:

- Create ProPresenter process detection and safe termination
- Implement macOS `defaults` command integration for plist file modification
- Build configuration backup and restore mechanisms
- Create `applicationShowDirectory` preference key updates
- Implement dependent setting cleanup for automatic regeneration
- Add configuration verification and rollback capabilities
- Create ProPresenter launch verification with new paths
- Handle permission issues and plist file corruption

**Key Functions to Implement**:

- `terminate_propresenter_safely()` - Close ProPresenter before config changes
- `backup_propresenter_preferences()` - Save current plist configuration
- `update_application_directory_setting()` - Modify preferences using defaults
- `verify_configuration_changes()` - Confirm settings applied correctly
- `rollback_configuration()` - Restore from backup on failure

**Environment Integration**: Read ProPresenter configuration file paths and target settings from environment.

**Verification**: Script safely updates ProPresenter configuration to use standardized symlink paths and verifies successful application launch.

---

### Step 10: Implement Comprehensive Error Handling and Recovery

**Objective**: Add robust error handling, retry mechanisms, and recovery procedures.

**Implementation Details**:

- Create error classification system for different failure types
- Implement exponential backoff retry mechanisms for network operations
- Build comprehensive rollback procedures for each configuration step
- Add user-friendly error messages with actionable guidance
- Create support contact information integration
- Implement diagnostic data collection for troubleshooting
- Add graceful degradation when optional features fail
- Create error logging with sufficient detail for debugging

**Key Functions to Implement**:

- `classify_error_type()` - Categorize failures for appropriate handling
- `implement_retry_logic()` - Exponential backoff for network operations
- `execute_rollback_procedure()` - Restore system to previous state
- `display_error_guidance()` - Show user-friendly error messages
- `collect_diagnostic_info()` - Gather system state for troubleshooting

**Verification**: Script handles various failure scenarios gracefully, provides clear user guidance, and successfully recovers from errors.

---

### Step 11: Build Verification and Success Reporting Module

**Objective**: Implement comprehensive setup validation and user success confirmation.

**Implementation Details**:

- Create end-to-end verification of all setup components
- Implement ProPresenter launch testing with new configuration
- Build OneDrive sync status verification
- Create symlink integrity checking
- Add SharePoint library access validation
- Implement user success reporting with clear next steps
- Create diagnostic report generation for troubleshooting
- Add recommendations for user follow-up actions

**Key Functions to Implement**:

- `verify_complete_setup()` - Test all components end-to-end
- `test_propresenter_launch()` - Verify application starts with new config
- `validate_sync_status()` - Confirm OneDrive synchronization
- `check_symlink_integrity()` - Test all symbolic links
- `generate_success_report()` - Create user completion summary

**Verification**: Script performs comprehensive validation of entire setup and provides clear success confirmation to users.

---

## Implementation Notes

### Development Environment Setup

- Test on multiple macOS versions (13.0+) with different user account types
- Use different OneDrive sync states (fresh install, existing accounts, multiple tenants)
- Test with various ProPresenter installation states (missing, wrong version, existing config)

### Error Handling Strategy

- Every function should include error detection and graceful handling
- Network operations require retry logic with exponential backoff
- File operations need permission checking and backup mechanisms
- User interactions should include timeout handling and fallback options

### Environment Integration

- All environment-specific values must be read from `docs/app-design/environment.md`
- No hardcoded tenant IDs, URLs, or configuration paths in implementation
- Support for future environment configuration changes without code modifications

### Verification and Validation

- Each step should include self-verification before proceeding to next step
- Implement rollback capabilities for every system modification
- Provide clear success/failure indicators to users throughout the process
- Include diagnostic information collection for troubleshooting support
