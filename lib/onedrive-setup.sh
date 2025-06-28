#!/bin/bash

# OneDrive Setup Module
# Handles OneDrive authentication setup, user guidance, and state changes

#=============================================================================
# CONFIRMATION DIALOG FUNCTIONS
#=============================================================================

# Function to show confirmation dialog for already configured OneDrive
show_onedrive_already_configured_dialog() {
    local log_prefix="[OneDrive Setup]"
    
    echo_success "OneDrive is already authenticated with the correct tenant"
    echo "$log_prefix Target tenant already authenticated" >> "$LOG_FILE"
    
    local confirmed_message="OneDrive Setup Confirmation:
    
✅ OneDrive is already installed and configured correctly!

Your OneDrive is already synced with the Mosaik Berlin tenant. We found your OneDrive folder with Mosaik Berlin data.

✅ Current Status:
• OneDrive is installed
• Authenticated with Mosaik Berlin tenant
• Sync is active and working

No additional setup is required for OneDrive.

Click Continue to proceed to the next step."
    
    if ! show_step_dialog "2" "Validating OneDrive Installation and Authorization" "$confirmed_message"; then
        echo_warning "OneDrive confirmation cancelled by user"
        echo "$log_prefix OneDrive confirmation cancelled by user" >> "$LOG_FILE"
        cleanup_and_exit 0 "cancelled"
    fi
    
    echo_success "OneDrive setup confirmed as already complete"
    echo "$log_prefix User confirmed OneDrive is already properly set up" >> "$LOG_FILE"
    return 0
}

#=============================================================================
# USER GUIDANCE FUNCTIONS
#=============================================================================

# Function to guide user through OneDrive account setup for multiple accounts
guide_onedrive_multiple_account_setup() {
    local log_prefix="[OneDrive Setup]"
    local existing_accounts="$1"
    
    echo_status "Found existing OneDrive accounts:"
    echo "$existing_accounts"
    echo_info ""
    echo_important "Multiple OneDrive accounts detected"
    echo_info "OneDrive supports multiple accounts. To add your Mosaik Berlin account:"
    echo_info "1. Right-click the OneDrive icon in the menu bar"
    echo_info "2. Select 'Add an account'"
    echo_info "3. Sign in with your Mosaik Berlin credentials:"
    echo_info "   - Email: your-email@mosaikberlin.com"
    echo_info "   - Or use your guest account if you have Teams access"
    echo_info "4. Complete the authentication process"
    echo_info ""
    echo_info "Guiding OneDrive account setup..."
    
    guide_onedrive_account_setup
}

# Function to guide user through OneDrive account setup
guide_onedrive_account_setup() {
    local log_prefix="[OneDrive Setup]"
    
    echo_info "Guiding user through OneDrive account setup..."
    echo "$log_prefix Starting OneDrive account setup guidance" >> "$LOG_FILE"
    
    # Show step dialog with clear instructions
    local onedrive_message="OneDrive Setup Instructions:

You already have OneDrive running with another account. Now you need to add your Mosaik Berlin account as a second account.

STEPS TO FOLLOW:
1. Look for the OneDrive icon in your menu bar (must be left from date & time)
2. Click the OneDrive icon
3. Click the gear icon on the top-right and click settings
4. In the settings dialog click on 'Accounts' in the icon bar
5. Click on 'Add an account'
6. Sign in with your Mosaik Berlin credentials:
   • Email: your-email@mosaikberlin.com or your private Email
   • Use your Microsoft 365 password
7. Complete any authentication steps (MFA if required)
8. OneDrive will begin syncing your Mosaik Berlin files

Click Continue when you have successfully added the account."
    
    if ! show_step_dialog "2" "Validating OneDrive Installation and Authorization" "$onedrive_message"; then
        echo_warning "OneDrive setup cancelled by user"
        echo "$log_prefix OneDrive setup cancelled by user" >> "$LOG_FILE"
        cleanup_and_exit 0 "cancelled"
    fi
    
    echo_success "OneDrive account setup confirmed by user"
    echo "$log_prefix User confirmed OneDrive account setup completion" >> "$LOG_FILE"
    return 0
}

# Function to guide user through fresh OneDrive setup
guide_onedrive_fresh_setup() {
    local log_prefix="[OneDrive Setup]"
    
    echo_status "OneDrive main application is not running"
    echo "$log_prefix OneDrive main process not detected - will launch fresh setup" >> "$LOG_FILE"
    echo_status "Starting OneDrive application..."
    echo "$log_prefix Launching OneDrive application" >> "$LOG_FILE"
    
    # Show dialog for fresh OneDrive setup
    local fresh_onedrive_message="OneDrive First Setup:

OneDrive will be launched when you click Continue. Since no account is configured yet, OneDrive will show the initial setup screen.

STEPS TO FOLLOW:
1. Click Continue to launch OneDrive
2. OneDrive will open and show a sign-in screen
3. Sign in with your Mosaik Berlin Microsoft 365 credentials:
   • Email: your-email@mosaikberlin.com
   • Use your Microsoft 365 password
4. Complete any authentication steps (MFA if required)
5. Choose sync settings when prompted
6. OneDrive will begin syncing your files

Click Continue to launch OneDrive."
    
    if ! show_step_dialog "2" "Validating OneDrive Installation and Authorization" "$fresh_onedrive_message"; then
        echo_warning "OneDrive setup cancelled by user"
        echo "$log_prefix OneDrive setup cancelled by user" >> "$LOG_FILE"
        cleanup_and_exit 0 "cancelled"
    fi
    
    launch_onedrive_application
}

#=============================================================================
# APPLICATION LAUNCH FUNCTIONS
#=============================================================================

# Function to launch OneDrive application
launch_onedrive_application() {
    local log_prefix="[OneDrive Setup]"
    local onedrive_path="/Applications/OneDrive.app"
    
    # Launch OneDrive in the background
    echo_status "Launching OneDrive application..."
    if open "$onedrive_path"; then
        echo_success "OneDrive launch command executed"
        echo "$log_prefix OneDrive launch command executed successfully" >> "$LOG_FILE"
        
        # Wait a moment for OneDrive to start
        sleep 3
        
        # Verify OneDrive actually started
        if is_onedrive_process_running; then
            echo_success "OneDrive application is now running"
            echo "$log_prefix OneDrive application verified running" >> "$LOG_FILE"
        else
            echo_warning "OneDrive may not have started properly with 'open' command"
            echo "$log_prefix WARNING: OneDrive process not detected after 'open' launch" >> "$LOG_FILE"
            
            # Try alternative launch method
            try_alternative_onedrive_launch
        fi
    else
        echo_error "Failed to launch OneDrive application"
        echo "$log_prefix ERROR: Failed to launch OneDrive application" >> "$LOG_FILE"
        return 1
    fi
    
    echo_info ""
    echo_info "This script will wait and monitor the authentication process..."
    return 0
}

# Function to try alternative OneDrive launch method
try_alternative_onedrive_launch() {
    local log_prefix="[OneDrive Setup]"
    
    echo_status "Trying alternative launch method..."
    echo "$log_prefix Attempting direct executable launch" >> "$LOG_FILE"
    
    if "/Applications/OneDrive.app/Contents/MacOS/OneDrive" & then
        sleep 3
        if is_onedrive_process_running; then
            echo_success "OneDrive launched successfully with direct method"
            echo "$log_prefix OneDrive launched successfully with direct executable" >> "$LOG_FILE"
        else
            echo_warning "OneDrive still not running - it may require user interaction"
            echo "$log_prefix WARNING: OneDrive not running after direct launch attempt" >> "$LOG_FILE"
            echo_info "OneDrive should appear shortly. If not, please open it manually from Applications."
        fi
    else
        echo_warning "Alternative launch method also failed"
        echo "$log_prefix WARNING: Direct executable launch also failed" >> "$LOG_FILE"
        echo_info "Please try opening OneDrive manually from the Applications folder"
    fi
}

#=============================================================================
# ERROR RECOVERY FUNCTIONS
#=============================================================================

# Function to handle authentication retry
handle_authentication_retry() {
    local log_prefix="[OneDrive Setup]"
    local max_retries=3
    local retry_count=0
    
    echo_step "Handling OneDrive authentication retry..."
    echo "$log_prefix Starting authentication retry process" >> "$LOG_FILE"
    
    while [[ $retry_count -lt $max_retries ]]; do
        retry_count=$((retry_count + 1))
        echo_status "Authentication attempt $retry_count of $max_retries..."
        echo "$log_prefix Authentication retry attempt $retry_count" >> "$LOG_FILE"
        
        # Reset OneDrive state
        reset_onedrive_authentication_state
        
        # Wait a moment before retry
        sleep 3
        
        # Attempt authentication again
        if launch_onedrive_authentication; then
            echo_success "OneDrive authentication retry initiated"
            echo "$log_prefix Authentication retry $retry_count initiated successfully" >> "$LOG_FILE"
            return 0
        else
            echo_warning "Authentication retry $retry_count failed"
            echo "$log_prefix WARNING: Authentication retry $retry_count failed" >> "$LOG_FILE"
        fi
        
        # Wait before next retry
        if [[ $retry_count -lt $max_retries ]]; then
            echo_info "Waiting 10 seconds before next retry..."
            sleep 10
        fi
    done
    
    echo_error "All authentication retry attempts failed"
    echo "$log_prefix ERROR: All $max_retries authentication retry attempts failed" >> "$LOG_FILE"
    return 1
}

# Function to reset OneDrive authentication state
reset_onedrive_authentication_state() {
    local log_prefix="[OneDrive Setup]"
    
    echo_status "Resetting OneDrive authentication state..."
    
    # Quit OneDrive if running
    if is_onedrive_process_running; then
        echo_info "Stopping OneDrive..."
        pkill -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" 2>/dev/null || true
        sleep 2
    fi
    
    # Clear OneDrive authentication cache
    local onedrive_cache_dirs=(
        "$HOME/Library/Group Containers/UBF8T346G9.OneDriveStandaloneSuite"
        "$HOME/Library/Application Support/OneDrive"
        "$HOME/Library/Caches/com.microsoft.OneDrive"
    )
    
    for cache_dir in "${onedrive_cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            echo_info "Clearing OneDrive cache: $(basename "$cache_dir")"
            rm -rf "$cache_dir" 2>/dev/null || true
        fi
    done
}

#=============================================================================
# STATE-BASED AUTHENTICATION ORCHESTRATION
#=============================================================================

# Function to launch OneDrive authentication based on current state
launch_onedrive_authentication() {
    local log_prefix="[OneDrive Setup]"
    local target_domain="$1"
    
    echo_step "Launching OneDrive authentication..."
    echo "$log_prefix Starting OneDrive authentication process" >> "$LOG_FILE"
    
    # Check if OneDrive is installed
    if [[ ! -d "/Applications/OneDrive.app" ]]; then
        echo_error "OneDrive not found. Please install OneDrive first."
        echo "$log_prefix ERROR: OneDrive not found at /Applications/OneDrive.app" >> "$LOG_FILE"
        return 1
    fi
    
    # Get current OneDrive state
    local auth_state=$(get_onedrive_auth_state "$target_domain")
    echo "$log_prefix Current OneDrive state: $auth_state" >> "$LOG_FILE"
    
    # Handle authentication based on current state
    case "$auth_state" in
        "authenticated_correct_tenant")
            show_onedrive_already_configured_dialog
            return 0
            ;;
        "running_with_other_accounts")
            echo_status "OneDrive main application is running"
            echo "$log_prefix OneDrive main process detected and running" >> "$LOG_FILE"
            echo_info "Checking existing OneDrive accounts..."
            
            local existing_accounts=$(list_onedrive_accounts)
            guide_onedrive_multiple_account_setup "$existing_accounts"
            return 0
            ;;
        "running_no_accounts")
            echo_status "OneDrive main application is running"
            echo "$log_prefix OneDrive main process detected and running" >> "$LOG_FILE"
            echo_info "Guiding OneDrive account setup..."
            
            guide_onedrive_account_setup
            return 0
            ;;
        "not_running")
            guide_onedrive_fresh_setup
            return 0
            ;;
        *)
            echo_error "Unknown OneDrive state: $auth_state"
            echo "$log_prefix ERROR: Unknown OneDrive state: $auth_state" >> "$LOG_FILE"
            return 1
            ;;
    esac
}