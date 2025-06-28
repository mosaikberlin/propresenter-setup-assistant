# OneDrive Shortcut Strategy - Implementation Plan

## Overview

This document outlines the revised implementation plan for ensuring consistent ProPresenter configuration paths across all team machines using OneDrive shortcuts instead of complex symlink and path replacement strategies.

## Problem Statement

ProPresenter binary configuration files contain embedded file paths that reference OneDrive CloudStorage locations directly:

- `Configuration/Workspace` - Contains theme file references
- `Playlists/Media` - Contains media asset references
- Paths include user-specific OneDrive directory names
- Different OneDrive path structures across team members

## Revised Solution: OneDrive Shortcut Strategy

### Key Insight

When users create a **shortcut** to the SharePoint library in OneDrive (instead of syncing directly), the folder is added to their personal OneDrive with a consistent naming pattern and is immediately synced locally. This eliminates the complexity of:

- Multiple OneDrive path variants
- User-specific directory structures
- Complex symlink management
- Binary file path replacement

### Benefits of Shortcut Approach

1. **Consistent Paths**: All users get same folder structure in personal OneDrive
2. **Automatic Sync**: Immediate local availability without complex sync waiting
3. **Simplified Configuration**: Only need to update ProPresenter's main application directory setting
4. **Reduced Complexity**: No need for symlinks or binary file path replacement
5. **Better Reliability**: Native OneDrive functionality instead of custom workarounds

## Current State Analysis

### Existing Infrastructure (Still Valid)

- ✅ Main `applicationShowDirectory` plist setting handled
- ✅ Backup/rollback system in place
- ✅ ProPresenter process management working
- ✅ File pinning capability for local storage

### Simplified Requirements

- ~~Binary config files contain hardcoded CloudStorage paths~~ → Not needed with shortcuts
- ~~Mixed user references~~ → Consistent with personal OneDrive
- ~~Different OneDrive path variants~~ → Standardized with shortcuts
- ~~URL encoding complexity~~ → Simplified paths

## Implementation Strategy

### Phase 1: Update SharePoint Sync Instructions

**Goal**: Modify user instructions to use OneDrive shortcuts instead of direct sync

**Changes Required**:

1. **Update SharePoint Library Sync Instructions**:

   - Change from "Sync" to "Add shortcut to OneDrive"
   - Update user guidance in SharePoint sync module
   - Modify dialog messages and instructions

2. **Update OneDrive Path Detection**:

   - Detect shortcut-based OneDrive folders
   - Look for consistent naming pattern in personal OneDrive
   - Update path discovery logic

3. **Update Folder Pinning Logic**:
   - Pin folders in personal OneDrive location
   - Maintain existing pinning functionality for local storage

### Phase 2: Simplify Configuration Management

**Goal**: Remove complex symlink and path replacement logic

**Simplifications**:

1. **Remove Symlink Creation**:

   - ~~Symlink creation module~~ → Not needed
   - ~~Complex path mapping~~ → Direct OneDrive paths
   - ~~Path normalization~~ → Native OneDrive structure

2. **Simplify ProPresenter Configuration**:

   - Keep existing `applicationShowDirectory` update
   - Point directly to OneDrive shortcut location
   - Remove binary file path replacement logic

3. **Update Path Detection**:
   - Detect OneDrive personal folder structure
   - Look for shortcut-created folders
   - Standard path: `~/OneDrive/ProPresenter` (or similar)

### Phase 3: Update User Experience

**Goal**: Streamline setup process with shortcut approach

**User Flow Changes**:

1. **SharePoint Access**:

   - Open SharePoint library
   - Click "Add shortcut to OneDrive" instead of "Sync"
   - Wait for shortcut to appear in personal OneDrive

2. **Automatic Detection**:

   - Script detects shortcut in personal OneDrive
   - Pin folder for local availability
   - Configure ProPresenter to use direct path

3. **Simplified Validation**:
   - Verify folder exists in personal OneDrive
   - Test ProPresenter configuration
   - No complex path replacement needed

### Phase 4: Testing and Validation

**Goal**: Ensure simplified approach works reliably

**Test Scenarios**:

1. **Fresh OneDrive account**: Creating first shortcut
2. **Existing shortcuts**: Multiple shortcuts in OneDrive
3. **Path consistency**: Same paths across different users
4. **ProPresenter compatibility**: Direct path configuration

**Validation Criteria**:

- Shortcut appears quickly in personal OneDrive
- Folder syncs immediately without waiting
- ProPresenter loads content correctly
- Consistent behavior across team members
- No complex troubleshooting needed

## Detailed Implementation Steps

### Step 1: Update SharePoint Sync Module

```bash
# Update lib/sharepoint-sync.sh
# Change user instructions from "Sync" to "Add shortcut to OneDrive"

show_sharepoint_sync_dialog() {
    local dialog_message="SharePoint Library Setup - Shortcut Method

To access the ProPresenter content library:

1. The SharePoint site will open in your browser
2. Click 'Add shortcut to OneDrive' (NOT 'Sync')
3. The folder will appear in your personal OneDrive
4. Wait for the shortcut to sync completely

This method ensures consistent paths across all team machines.

Click 'Continue' to open SharePoint."

    # Rest of implementation...
}
```

### Step 2: Update OneDrive Path Detection

```bash
# Update detection logic to find OneDrive shortcuts
detect_onedrive_shortcut_folder() {
    local current_user=$(whoami)
    local personal_onedrive="$HOME/OneDrive"

    # Look for ProPresenter folder in personal OneDrive
    local shortcut_folder="$personal_onedrive/ProPresenter"

    if [[ -d "$shortcut_folder" ]]; then
        echo "$shortcut_folder"
        return 0
    fi

    # Alternative naming patterns
    local alt_patterns=(
        "$personal_onedrive/Visuals Team - ProPresenter"
        "$personal_onedrive/ProPresenter - Visuals Team"
    )

    for pattern in "${alt_patterns[@]}"; do
        if [[ -d "$pattern" ]]; then
            echo "$pattern"
            return 0
        fi
    done

    return 1
}
```

### Step 3: Simplify ProPresenter Configuration

```bash
# Keep existing update_application_directory_setting() function
# Remove complex path replacement logic
# Point directly to OneDrive shortcut location

configure_propresenter_for_shortcut() {
    local shortcut_folder="$1"
    local app_directory="$shortcut_folder/Application Directory"

    # Verify the Application Directory exists
    if [[ ! -d "$app_directory" ]]; then
        echo_error "Application Directory not found in shortcut: $app_directory"
        return 1
    fi

    # Use existing function to update ProPresenter setting
    update_application_directory_setting "$app_directory"

    return $?
}
```

### Step 4: Remove Symlink Dependencies

Remove in main script:

- Symlink creation step
- Path normalization logic
- Complex configuration file path replacement

Keep simplified flow:

1. OneDrive authentication
2. SharePoint shortcut creation
3. Folder pinning
4. ProPresenter configuration (direct path)
5. Testing and validation

## Risk Assessment and Mitigation

### High Risk Items

1. **User confusion**: Users might still click "Sync" instead of "Add shortcut"

   - **Mitigation**: Clear instructions and visual guidance
   - **Mitigation**: Update dialogs to emphasize shortcut method

2. **OneDrive personal vs business confusion**: Multiple OneDrive accounts

   - **Mitigation**: Detect and guide users to correct OneDrive instance
   - **Mitigation**: Clear messaging about personal vs business OneDrive

3. **Shortcut naming inconsistency**: Different folder names across users
   - **Mitigation**: Multiple detection patterns for common variations
   - **Mitigation**: Fallback mechanisms for unusual naming

### Medium Risk Items

1. **Sync timing**: Shortcut folder may not appear immediately

   - **Mitigation**: Polling with timeout for folder detection
   - **Mitigation**: Clear progress indication during waiting

2. **Permission issues**: SharePoint access problems
   - **Mitigation**: Clear error messaging for permission failures
   - **Mitigation**: Guidance for requesting access

## Success Criteria

### Functional Requirements

- [ ] Users successfully create OneDrive shortcuts to SharePoint library
- [ ] ProPresenter launches without errors using direct OneDrive paths
- [ ] Media assets load correctly from shortcut location
- [ ] Theme files apply properly from shortcut location
- [ ] Configuration persists across restarts with direct paths

### Technical Requirements

- [ ] Shortcut detection works reliably across different naming patterns
- [ ] Folder pinning works with shortcut locations
- [ ] No complex path replacement or symlink management needed
- [ ] Comprehensive error handling for shortcut creation failures
- [ ] Performance acceptable without binary file processing

### User Experience Requirements

- [ ] Clear instructions for creating OneDrive shortcuts
- [ ] Simple setup process without complex technical steps
- [ ] Helpful error messages for common issues
- [ ] Consistent experience across all team members
- [ ] Reduced troubleshooting compared to previous approach

## Timeline and Dependencies

### Prerequisites

- OneDrive authentication system operational
- ProPresenter configuration management system operational
- SharePoint library accessible to team members

### Dependencies

- SharePoint permissions for all team members
- OneDrive application functioning correctly
- ProPresenter application for validation
- Team members for shortcut creation testing

## Post-Implementation Monitoring

### Success Metrics

- High success rate for OneDrive shortcut creation
- Consistent ProPresenter configuration across all team machines
- Reduced support requests compared to symlink approach
- Positive user feedback on simplified setup process

### Monitoring Plan

- Track shortcut creation success/failure rates
- Monitor OneDrive sync completion times
- User feedback collection on setup simplicity
- ProPresenter launch success rates

## Future Enhancements

### Potential Improvements

1. **Automated shortcut detection**: Better pattern matching for various naming conventions
2. **Fallback mechanisms**: Handle edge cases where shortcuts don't work as expected
3. **Integration validation**: Automated testing of ProPresenter with shortcut paths
4. **User guidance**: Enhanced visual instructions for shortcut creation

### Maintenance Considerations

- Monitor OneDrive shortcut behavior changes in updates
- Keep detection patterns updated for new OneDrive versions
- Regular testing with ProPresenter updates
- Documentation updates for new team members
- Simplified troubleshooting procedures

## Key Benefits of Shortcut Approach

1. **Simplicity**: No complex symlinks or path replacement needed
2. **Reliability**: Uses native OneDrive functionality
3. **Consistency**: Same folder structure for all users
4. **Performance**: No binary file processing required
5. **Maintainability**: Less custom logic to maintain
6. **User Experience**: Easier for team members to understand and use
