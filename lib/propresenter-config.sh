#!/bin/bash

# ProPresenter Configuration Update Module
# Programmatically updates ProPresenter preferences to use symlink paths

# =============================================================================
# Global Variables
# =============================================================================

CONFIG_LOG_PREFIX="[ProPresenter Config]"
PROPRESENTER_APP_NAME="ProPresenter"
PROPRESENTER_BUNDLE_ID="com.renewedvision.ProPresenter"
PROPRESENTER_PLIST_PATH="$HOME/Library/Preferences/${PROPRESENTER_BUNDLE_ID}.plist"

# Target configuration values (will be set from SharePoint sync module)
SHAREPOINT_SYNC_FOLDER=""

# =============================================================================
# ProPresenter Process Management
# =============================================================================

# Function to check if ProPresenter is running
is_propresenter_running() {
    if pgrep -f "$PROPRESENTER_APP_NAME" >/dev/null 2>&1; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

# Function to safely terminate ProPresenter
terminate_propresenter_safely() {
    echo_info "Checking ProPresenter application status..."
    echo "$(date): $CONFIG_LOG_PREFIX Checking ProPresenter process status" >> "$LOG_FILE"
    
    if ! is_propresenter_running; then
        echo_info "ProPresenter is not currently running"
        return 0
    fi
    
    echo_info "ProPresenter is running - requesting safe termination..."
    echo "$(date): $CONFIG_LOG_PREFIX ProPresenter is running, requesting termination" >> "$LOG_FILE"
    
    # Show user dialog explaining the need to close ProPresenter
    local dialog_message="ProPresenter Configuration Update

ProPresenter is currently running and needs to be closed to safely update its configuration.

The setup will:
1. Close ProPresenter temporarily
2. Update configuration to use standardized folder paths
3. Verify the changes were applied correctly

Click 'Continue' to proceed with closing ProPresenter."

    if ! show_confirmation_dialog "ProPresenter Configuration" "$dialog_message"; then
        echo_warning "User cancelled ProPresenter configuration update"
        return 1
    fi
    
    # Try graceful quit first using AppleScript
    echo_info "Requesting graceful ProPresenter shutdown..."
    if osascript -e "tell application \"$PROPRESENTER_APP_NAME\" to quit" 2>/dev/null; then
        echo_info "Sent quit command to ProPresenter"
    else
        echo_info "AppleScript quit failed, trying alternative method"
    fi
    
    # Wait for graceful shutdown
    local wait_count=0
    local max_wait=30  # 30 seconds
    
    while is_propresenter_running && [[ $wait_count -lt $max_wait ]]; do
        echo_info "Waiting for ProPresenter to close... ($wait_count/$max_wait)"
        sleep 2
        ((wait_count += 2))
    done
    
    if is_propresenter_running; then
        echo_warning "ProPresenter did not close gracefully, forcing termination..."
        pkill -f "$PROPRESENTER_APP_NAME" 2>/dev/null
        
        # Wait a bit more for forced termination
        sleep 3
        
        if is_propresenter_running; then
            echo_error "Failed to terminate ProPresenter"
            echo "$(date): $CONFIG_LOG_PREFIX Failed to terminate ProPresenter process" >> "$LOG_FILE"
            return 1
        fi
    fi
    
    echo_success "ProPresenter terminated successfully"
    echo "$(date): $CONFIG_LOG_PREFIX ProPresenter terminated successfully" >> "$LOG_FILE"
    return 0
}

# =============================================================================
# Configuration Backup and Restore
# =============================================================================

# Function to backup ProPresenter preferences
backup_propresenter_preferences() {
    echo_info "Creating backup of ProPresenter preferences..."
    echo "$(date): $CONFIG_LOG_PREFIX Starting ProPresenter preferences backup" >> "$LOG_FILE"
    
    if [[ ! -f "$PROPRESENTER_PLIST_PATH" ]]; then
        echo_warning "ProPresenter preferences file not found: $PROPRESENTER_PLIST_PATH"
        echo_info "This may be a fresh ProPresenter installation"
        return 0
    fi
    
    # Create backup directory
    local backup_dir="$HOME/ProPresenter-Config-Backup/preferences"
    mkdir -p "$backup_dir"
    
    # Create timestamped backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/ProPresenter_preferences_backup_$timestamp.plist"
    
    if cp "$PROPRESENTER_PLIST_PATH" "$backup_file"; then
        echo_success "Preferences backed up to: $backup_file"
        echo "$(date): $CONFIG_LOG_PREFIX Preferences backed up to: $backup_file" >> "$LOG_FILE"
        
        # Export backup path for potential rollback
        export PROPRESENTER_BACKUP_FILE="$backup_file"
        return 0
    else
        echo_error "Failed to backup ProPresenter preferences"
        echo "$(date): $CONFIG_LOG_PREFIX Failed to backup preferences" >> "$LOG_FILE"
        return 1
    fi
}

# Function to rollback configuration from backup
rollback_configuration() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        backup_file="$PROPRESENTER_BACKUP_FILE"
    fi
    
    if [[ -z "$backup_file" || ! -f "$backup_file" ]]; then
        echo_error "No backup file available for rollback"
        return 1
    fi
    
    echo_warning "Rolling back ProPresenter configuration..."
    echo "$(date): $CONFIG_LOG_PREFIX Rolling back configuration from: $backup_file" >> "$LOG_FILE"
    
    if cp "$backup_file" "$PROPRESENTER_PLIST_PATH"; then
        echo_success "Configuration rolled back successfully"
        echo "$(date): $CONFIG_LOG_PREFIX Configuration rollback successful" >> "$LOG_FILE"
        return 0
    else
        echo_error "Failed to rollback configuration"
        echo "$(date): $CONFIG_LOG_PREFIX Configuration rollback failed" >> "$LOG_FILE"
        return 1
    fi
}

# =============================================================================
# Configuration Updates
# =============================================================================

# Function to update ProPresenter application directory setting
update_application_directory_setting() {
    local target_directory="$1"
    
    if [[ ! -d "$target_directory" ]]; then
        echo_error "Target directory does not exist: $target_directory"
        return 1
    fi
    
    echo_info "Updating ProPresenter Application Directory setting..."
    echo_info "Target directory: $target_directory"
    echo "$(date): $CONFIG_LOG_PREFIX Updating applicationShowDirectory to: $target_directory" >> "$LOG_FILE"
    
    # Update the main application directory setting
    if defaults write "$PROPRESENTER_BUNDLE_ID" "applicationShowDirectory" "$target_directory" 2>/dev/null; then
        echo_success "Updated applicationShowDirectory setting"
        echo "$(date): $CONFIG_LOG_PREFIX Successfully updated applicationShowDirectory" >> "$LOG_FILE"
    else
        echo_error "Failed to update applicationShowDirectory setting"
        echo "$(date): $CONFIG_LOG_PREFIX Failed to update applicationShowDirectory" >> "$LOG_FILE"
        return 1
    fi
    
    # Clear dependent settings so ProPresenter regenerates them with new paths
    echo_info "Clearing dependent settings for regeneration..."
    
    # List of settings that should be cleared to force regeneration
    local dependent_settings=(
        "libraryPath"
        "mediaPath"
        "themePath"
        "playlistPath"
        "configurationPath"
        "presetPath"
    )
    
    for setting in "${dependent_settings[@]}"; do
        # Check if setting exists before trying to delete it
        if defaults read "$PROPRESENTER_BUNDLE_ID" "$setting" >/dev/null 2>&1; then
            echo_info "Clearing setting: $setting"
            defaults delete "$PROPRESENTER_BUNDLE_ID" "$setting" 2>/dev/null
        fi
    done
    
    echo_success "Configuration update completed"
    return 0
}

# =============================================================================
# Configuration Verification
# =============================================================================

# Function to verify configuration changes
verify_configuration_changes() {
    local expected_directory="$1"
    
    echo_info "Verifying ProPresenter configuration changes..."
    echo "$(date): $CONFIG_LOG_PREFIX Verifying configuration changes" >> "$LOG_FILE"
    
    # Check if the plist file exists
    if [[ ! -f "$PROPRESENTER_PLIST_PATH" ]]; then
        echo_error "ProPresenter preferences file not found"
        return 1
    fi
    
    # Read the current applicationShowDirectory setting
    local current_directory
    current_directory=$(defaults read "$PROPRESENTER_BUNDLE_ID" "applicationShowDirectory" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo_error "Failed to read applicationShowDirectory setting"
        return 1
    fi
    
    # Verify the setting matches our expected value
    if [[ "$current_directory" == "$expected_directory" ]]; then
        echo_success "Configuration verified: applicationShowDirectory = $current_directory"
        echo "$(date): $CONFIG_LOG_PREFIX Configuration verified successfully" >> "$LOG_FILE"
        return 0
    else
        echo_error "Configuration verification failed"
        echo_error "Expected: $expected_directory"
        echo_error "Actual: $current_directory"
        echo "$(date): $CONFIG_LOG_PREFIX Configuration verification failed - expected: $expected_directory, actual: $current_directory" >> "$LOG_FILE"
        return 1
    fi
}

# Function to test ProPresenter launch with new configuration
test_propresenter_launch() {
    echo_info "Testing ProPresenter launch with new configuration..."
    echo "$(date): $CONFIG_LOG_PREFIX Testing ProPresenter launch" >> "$LOG_FILE"
    
    # Launch ProPresenter
    echo_info "Launching ProPresenter..."
    if open -a "$PROPRESENTER_APP_NAME"; then
        echo_info "ProPresenter launch initiated"
    else
        echo_error "Failed to launch ProPresenter"
        return 1
    fi
    
    # Wait for ProPresenter to start
    local wait_count=0
    local max_wait=30  # 30 seconds
    
    while ! is_propresenter_running && [[ $wait_count -lt $max_wait ]]; do
        echo_info "Waiting for ProPresenter to start... ($wait_count/$max_wait)"
        sleep 2
        ((wait_count += 2))
    done
    
    if is_propresenter_running; then
        echo_success "ProPresenter launched successfully with new configuration"
        echo "$(date): $CONFIG_LOG_PREFIX ProPresenter launch test successful" >> "$LOG_FILE"
        
        # Give ProPresenter a moment to fully initialize
        sleep 3
        
        # Show user verification dialog
        local verification_message="ProPresenter Launch Verification

ProPresenter has been launched with the new configuration. Please verify:

1. ProPresenter opened without errors
2. You can see your libraries and content
3. The application appears to be working normally

If everything looks correct, click 'Continue'.
If there are issues, click 'Cancel' to rollback the configuration."

        if show_confirmation_dialog "ProPresenter Verification" "$verification_message"; then
            echo_success "User confirmed ProPresenter is working correctly"
            return 0
        else
            echo_warning "User reported issues with ProPresenter"
            return 1
        fi
    else
        echo_error "ProPresenter failed to start within timeout period"
        echo "$(date): $CONFIG_LOG_PREFIX ProPresenter launch test failed - timeout" >> "$LOG_FILE"
        return 1
    fi
}

# =============================================================================
# Main Configuration Management
# =============================================================================

# Main function to manage ProPresenter configuration updates
manage_propresenter_configuration() {
    echo_header "ProPresenter Configuration Update"
    echo "$(date): $CONFIG_LOG_PREFIX Starting ProPresenter configuration update" >> "$LOG_FILE"
    
    # Get the OneDrive shortcut folder from SharePoint sync module
    if [[ -z "$SHAREPOINT_SYNC_FOLDER" ]]; then
        echo_error "OneDrive shortcut folder not available"
        echo_error "Please ensure SharePoint shortcut setup completed successfully"
        return 1
    fi
    
    # Construct the Application Directory path
    local application_directory="$SHAREPOINT_SYNC_FOLDER/Application Directory"
    
    # Verify the Application Directory exists in the OneDrive shortcut
    if [[ ! -d "$application_directory" ]]; then
        echo_error "Application Directory not found in OneDrive shortcut: $application_directory"
        echo_error "Please verify the SharePoint library contains the Application Directory folder"
        return 1
    fi
    
    echo_info "Target Application Directory: $application_directory"
    echo ""
    
    # Step 1: Safely terminate ProPresenter
    echo_step "Preparing ProPresenter for configuration update"
    if ! terminate_propresenter_safely; then
        echo_error "Failed to safely terminate ProPresenter"
        return 1
    fi
    
    echo ""
    
    # Step 2: Backup current preferences
    echo_step "Backing up current ProPresenter preferences"
    if ! backup_propresenter_preferences; then
        echo_error "Failed to backup ProPresenter preferences"
        return 1
    fi
    
    echo ""
    
    # Step 3: Update application directory setting
    echo_step "Updating ProPresenter configuration"
    if ! update_application_directory_setting "$application_directory"; then
        echo_error "Failed to update ProPresenter configuration"
        echo_info "Attempting to rollback configuration..."
        rollback_configuration
        return 1
    fi
    
    echo ""
    
    # Step 4: Verify configuration changes
    echo_step "Verifying configuration changes"
    if ! verify_configuration_changes "$application_directory"; then
        echo_error "Configuration verification failed"
        echo_info "Attempting to rollback configuration..."
        rollback_configuration
        return 1
    fi
    
    echo ""
    
    # Step 5: Test ProPresenter launch
    echo_step "Testing ProPresenter launch with new configuration"
    if ! test_propresenter_launch; then
        echo_error "ProPresenter launch test failed"
        echo_info "Attempting to rollback configuration..."
        rollback_configuration
        
        # Try to restart ProPresenter with old config
        echo_info "Restarting ProPresenter with rollback configuration..."
        sleep 2
        open -a "$PROPRESENTER_APP_NAME" 2>/dev/null
        return 1
    fi
    
    echo ""
    echo_success "ProPresenter configuration update completed successfully"
    echo_info "Application Directory: $application_directory"
    echo_success "ProPresenter is now configured to use OneDrive shortcut paths"
    echo_info "All team machines will now have consistent ProPresenter configurations"
    echo "$(date): $CONFIG_LOG_PREFIX ProPresenter configuration update completed successfully" >> "$LOG_FILE"
    
    return 0
}