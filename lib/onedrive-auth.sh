#!/bin/bash

# OneDrive Detection and Authentication Module
# Handles OneDrive installation, authentication, and tenant validation

# Function to check if target tenant is already authenticated
check_target_tenant_authenticated() {
    local target_domain="$1"
    local log_prefix="[OneDrive Auth]"
    
    # Check for Mosaik Berlin OneDrive folder
    local mosaik_folders=(
        "$HOME/OneDrive - Mosaikkirche Berlin e.V."
        "$HOME/OneDrive/OneDrive - Mosaikkirche Berlin e.V."
        "$HOME/OneDrive - $target_domain"
        "$HOME/Library/CloudStorage/OneDrive-MosaikkircheBerline.V."
    )
    
    for folder in "${mosaik_folders[@]}"; do
        if [[ -d "$folder" ]]; then
            echo "$log_prefix Found target tenant folder: $folder" >> "$LOG_FILE"
            return 0
        fi
    done
    
    return 1
}

# Function to list existing OneDrive accounts
list_onedrive_accounts() {
    local accounts=""
    
    # Check for OneDrive folders which indicate connected accounts
    for onedrive_dir in "$HOME"/OneDrive*; do
        if [[ -d "$onedrive_dir" ]]; then
            local account_name=$(basename "$onedrive_dir")
            if [[ "$account_name" != "OneDrive" ]]; then
                accounts+="  - $account_name"$'\n'
            fi
        fi
    done
    
    # Check CloudStorage directory for additional accounts
    if [[ -d "$HOME/Library/CloudStorage" ]]; then
        for cloud_dir in "$HOME/Library/CloudStorage"/OneDrive-*; do
            if [[ -d "$cloud_dir" ]]; then
                local account_name=$(basename "$cloud_dir" | sed 's/OneDrive-//')
                accounts+="  - $account_name"$'\n'
            fi
        done
    fi
    
    echo "$accounts"
}

# Function to guide user through OneDrive account setup
guide_onedrive_account_setup() {
    local log_prefix="[OneDrive Auth]"
    
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

# Function to check if OneDrive is installed
check_onedrive_installation() {
    local log_prefix="[OneDrive Auth]"
    local onedrive_path="/Applications/OneDrive.app"
    
    echo_step "Checking OneDrive installation..."
    
    # Check if OneDrive application exists
    if [[ -d "$onedrive_path" ]]; then
        # Get OneDrive version if available
        local onedrive_version=""
        if [[ -f "$onedrive_path/Contents/Info.plist" ]]; then
            onedrive_version=$(defaults read "$onedrive_path/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
            echo_success "OneDrive is installed: version $onedrive_version"
            echo "$log_prefix OneDrive found at $onedrive_path, version: $onedrive_version" >> "$LOG_FILE"
        else
            echo_success "OneDrive is installed (version unknown)"
            echo "$log_prefix OneDrive found at $onedrive_path, version unknown" >> "$LOG_FILE"
        fi
        return 0
    else
        echo_status "OneDrive not found at $onedrive_path"
        echo "$log_prefix OneDrive not installed at $onedrive_path" >> "$LOG_FILE"
        return 1
    fi
}

# Function to install OneDrive
install_onedrive() {
    local log_prefix="[OneDrive Auth]"
    
    echo_step "Installing OneDrive..."
    echo "$log_prefix Starting OneDrive installation" >> "$LOG_FILE"
    
    # Create temporary directory for download
    local temp_dir=$(mktemp -d)
    echo "$log_prefix Created temporary directory: $temp_dir" >> "$LOG_FILE"
    
    # OneDrive download URL for macOS
    local onedrive_download_url="https://go.microsoft.com/fwlink/?linkid=823060"
    local onedrive_pkg="OneDrive.pkg"
    
    echo_status "Downloading OneDrive installer..."
    echo "$log_prefix Downloading OneDrive from: $onedrive_download_url" >> "$LOG_FILE"
    
    # Download OneDrive installer
    if curl -L -o "$temp_dir/$onedrive_pkg" "$onedrive_download_url"; then
        echo_success "OneDrive installer downloaded successfully"
        echo "$log_prefix OneDrive download completed successfully" >> "$LOG_FILE"
        
        # Install OneDrive package
        echo_important "Administrator permission needed to install OneDrive"
        echo_info "You will be prompted for your password to install OneDrive system-wide."
        echo_info "This ensures OneDrive is properly integrated with macOS."
        echo_info ""
        
        if sudo installer -pkg "$temp_dir/$onedrive_pkg" -target /; then
            echo_success "OneDrive installed successfully"
            echo "$log_prefix OneDrive installation completed successfully" >> "$LOG_FILE"
            
            # Clean up
            rm -rf "$temp_dir"
            
            # Verify installation
            if [[ -d "/Applications/OneDrive.app" ]]; then
                echo_success "OneDrive installation verified"
                echo "$log_prefix OneDrive installation verification successful" >> "$LOG_FILE"
                return 0
            else
                echo_error "OneDrive installation verification failed"
                echo "$log_prefix ERROR: OneDrive installation verification failed" >> "$LOG_FILE"
                return 1
            fi
        else
            echo_error "Failed to install OneDrive package"
            echo "$log_prefix ERROR: OneDrive package installation failed" >> "$LOG_FILE"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        echo_error "Failed to download OneDrive installer"
        echo "$log_prefix ERROR: OneDrive download failed from $onedrive_download_url" >> "$LOG_FILE"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Function to launch OneDrive authentication
launch_onedrive_authentication() {
    local log_prefix="[OneDrive Auth]"
    local onedrive_path="/Applications/OneDrive.app"
    local target_domain="$1"
    
    echo_step "Launching OneDrive authentication..."
    echo "$log_prefix Starting OneDrive authentication process" >> "$LOG_FILE"
    
    # Check if OneDrive is installed
    if [[ ! -d "$onedrive_path" ]]; then
        echo_error "OneDrive not found. Please install OneDrive first."
        echo "$log_prefix ERROR: OneDrive not found at $onedrive_path" >> "$LOG_FILE"
        return 1
    fi
    
    # Check if target tenant is already authenticated
    if check_target_tenant_authenticated "$target_domain"; then
        echo_success "OneDrive is already authenticated with the correct tenant"
        echo "$log_prefix Target tenant already authenticated" >> "$LOG_FILE"
        return 0
    fi
    
    # Check if the main OneDrive application is actually running (not just background services)
    echo "$log_prefix Checking for main OneDrive process" >> "$LOG_FILE"
    if pgrep -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1; then
        echo_status "OneDrive main application is running"
        echo "$log_prefix OneDrive main process detected and running" >> "$LOG_FILE"
        
        # Check what accounts are connected
        echo_info "Checking existing OneDrive accounts..."
        local existing_accounts=$(list_onedrive_accounts)
        
        if [[ -n "$existing_accounts" ]]; then
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
        else
            echo_info "Guiding OneDrive account setup..."
            guide_onedrive_account_setup
        fi
    else
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
        
        # Launch OneDrive in the background
        echo_status "Launching OneDrive application..."
        if open "$onedrive_path"; then
            echo_success "OneDrive launch command executed"
            echo "$log_prefix OneDrive launch command executed successfully" >> "$LOG_FILE"
            
            # Wait a moment for OneDrive to start
            sleep 3
            
            # Verify OneDrive actually started
            if pgrep -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1; then
                echo_success "OneDrive application is now running"
                echo "$log_prefix OneDrive application verified running" >> "$LOG_FILE"
            else
                echo_warning "OneDrive may not have started properly with 'open' command"
                echo "$log_prefix WARNING: OneDrive process not detected after 'open' launch" >> "$LOG_FILE"
                
                # Try alternative launch method
                echo_status "Trying alternative launch method..."
                echo "$log_prefix Attempting direct executable launch" >> "$LOG_FILE"
                
                if "/Applications/OneDrive.app/Contents/MacOS/OneDrive" & then
                    sleep 3
                    if pgrep -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1; then
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
            fi
        else
            echo_error "Failed to launch OneDrive application"
            echo "$log_prefix ERROR: Failed to launch OneDrive application" >> "$LOG_FILE"
            return 1
        fi
    fi
    
    echo_info ""
    echo_info "This script will wait and monitor the authentication process..."
    
    return 0
}

# Function to verify tenant authentication
verify_tenant_authentication() {
    local log_prefix="[OneDrive Auth]"
    local target_tenant_id="$1"
    local target_domain="$2"
    local max_wait_time=300  # 5 minutes
    local check_interval=10  # 10 seconds
    local elapsed_time=0
    
    echo_step "Verifying OneDrive tenant authentication..."
    echo "$log_prefix Starting tenant authentication verification" >> "$LOG_FILE"
    echo "$log_prefix Target tenant ID: $target_tenant_id" >> "$LOG_FILE"
    echo "$log_prefix Target domain: $target_domain" >> "$LOG_FILE"
    
    # Wait for OneDrive to complete authentication
    echo_status "Monitoring OneDrive authentication progress..."
    echo_info "Waiting up to 5 minutes for OneDrive authentication to complete..."
    
    while [[ $elapsed_time -lt $max_wait_time ]]; do
        # Check if OneDrive has completed initial setup
        local onedrive_settings_dir="$HOME/Library/Group Containers/UBF8T346G9.OneDriveStandaloneSuite"
        local onedrive_config_dir="$HOME/Library/Application Support/OneDrive"
        
        # Look for signs of successful authentication
        if [[ -d "$onedrive_settings_dir" ]] || [[ -d "$onedrive_config_dir" ]]; then
            echo_status "OneDrive configuration detected, verifying tenant..."
            echo "$log_prefix OneDrive configuration directory found" >> "$LOG_FILE"
            
            # Try to determine the authenticated tenant
            local auth_status=$(check_onedrive_tenant_status "$target_tenant_id" "$target_domain")
            local auth_result=$?
            
            if [[ $auth_result -eq 0 ]]; then
                echo_success "OneDrive authenticated with correct tenant"
                echo "$log_prefix Tenant authentication verification successful" >> "$LOG_FILE"
                return 0
            elif [[ $auth_result -eq 2 ]]; then
                echo_warning "OneDrive authenticated with different tenant"
                echo "$log_prefix WARNING: OneDrive authenticated with incorrect tenant" >> "$LOG_FILE"
                return 2
            fi
        fi
        
        # Check if OneDrive process is still running
        if ! pgrep -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1; then
            echo_warning "OneDrive process not running. Authentication may have failed."
            echo "$log_prefix WARNING: OneDrive process not detected" >> "$LOG_FILE"
        fi
        
        # Update progress
        local progress_dots=$(printf "%*s" $((elapsed_time / 10)) | tr ' ' '.')
        printf "\r${CYAN}ℹ${NC} Waiting for authentication$progress_dots"
        
        sleep $check_interval
        elapsed_time=$((elapsed_time + check_interval))
    done
    
    printf "\n"
    echo_warning "Authentication verification timed out after 5 minutes"
    echo "$log_prefix WARNING: Authentication verification timed out" >> "$LOG_FILE"
    return 1
}

# Function to check OneDrive tenant status
check_onedrive_tenant_status() {
    local target_tenant_id="$1"
    local target_domain="$2"
    local log_prefix="[OneDrive Auth]"
    
    # Check OneDrive logs for tenant information
    local onedrive_log_dir="$HOME/Library/Logs"
    local tenant_found=false
    local correct_tenant=false
    
    # Look for OneDrive log files
    if [[ -d "$onedrive_log_dir" ]]; then
        # Search for tenant ID in recent OneDrive logs
        local log_files=$(find "$onedrive_log_dir" -name "*OneDrive*" -type f -mtime -1 2>/dev/null)
        
        if [[ -n "$log_files" ]]; then
            # Search for tenant ID or domain in logs
            if echo "$log_files" | xargs grep -l "$target_tenant_id" 2>/dev/null >/dev/null; then
                tenant_found=true
                correct_tenant=true
                echo "$log_prefix Found target tenant ID in OneDrive logs" >> "$LOG_FILE"
            elif echo "$log_files" | xargs grep -l "$target_domain" 2>/dev/null >/dev/null; then
                tenant_found=true
                correct_tenant=true
                echo "$log_prefix Found target domain in OneDrive logs" >> "$LOG_FILE"
            elif echo "$log_files" | xargs grep -l "mosaik" 2>/dev/null >/dev/null; then
                tenant_found=true
                correct_tenant=true
                echo "$log_prefix Found Mosaik organization in OneDrive logs" >> "$LOG_FILE"
            fi
        fi
    fi
    
    # Alternative: Check OneDrive sync folder for tenant-specific patterns
    local onedrive_folders=("$HOME/OneDrive - Mosaikkirche Berlin e.V." "$HOME/OneDrive - $target_domain" "$HOME/OneDrive")
    
    for folder in "${onedrive_folders[@]}"; do
        if [[ -d "$folder" ]]; then
            tenant_found=true
            if [[ "$folder" == *"Mosaikkirche Berlin"* ]] || [[ "$folder" == *"$target_domain"* ]]; then
                correct_tenant=true
                echo "$log_prefix Found correct tenant folder: $folder" >> "$LOG_FILE"
                break
            else
                echo "$log_prefix Found OneDrive folder but not for target tenant: $folder" >> "$LOG_FILE"
            fi
        fi
    done
    
    # Return results
    if [[ "$tenant_found" == true && "$correct_tenant" == true ]]; then
        return 0  # Correct tenant
    elif [[ "$tenant_found" == true ]]; then
        return 2  # Wrong tenant
    else
        return 1  # No tenant found/authentication incomplete
    fi
}

# Function to handle authentication retry
handle_authentication_retry() {
    local log_prefix="[OneDrive Auth]"
    local max_retries=3
    local retry_count=0
    
    echo_step "Handling OneDrive authentication retry..."
    echo "$log_prefix Starting authentication retry process" >> "$LOG_FILE"
    
    while [[ $retry_count -lt $max_retries ]]; do
        retry_count=$((retry_count + 1))
        echo_status "Authentication attempt $retry_count of $max_retries..."
        echo "$log_prefix Authentication retry attempt $retry_count" >> "$LOG_FILE"
        
        # Reset OneDrive state
        echo_status "Resetting OneDrive authentication state..."
        
        # Quit OneDrive if running
        if pgrep -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1; then
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

# Main function to manage OneDrive authentication
manage_onedrive_authentication() {
    local log_prefix="[OneDrive Auth]"
    local target_tenant_id="$1"
    local target_domain="$2"
    
    if [[ -z "$target_tenant_id" || -z "$target_domain" ]]; then
        echo_error "Target tenant ID and domain not specified"
        echo "$log_prefix ERROR: Missing tenant ID or domain parameters" >> "$LOG_FILE"
        return 1
    fi
    
    echo_header "OneDrive Detection and Authentication"
    echo "$log_prefix Starting OneDrive authentication management" >> "$LOG_FILE"
    echo "$log_prefix Target tenant: $target_tenant_id ($target_domain)" >> "$LOG_FILE"
    
    # Step 1: Check OneDrive installation
    if ! check_onedrive_installation; then
        echo_status "OneDrive not installed, proceeding with installation..."
        
        if ! install_onedrive; then
            echo_error "Failed to install OneDrive"
            return 1
        fi
    fi
    
    # Step 2: Launch authentication process
    if ! launch_onedrive_authentication "$target_domain"; then
        echo_warning "Initial authentication launch failed, attempting retry..."
        
        if ! handle_authentication_retry; then
            echo_error "OneDrive authentication failed after all retry attempts"
            return 1
        fi
    fi
    
    # Step 3: Verify tenant authentication
    echo ""
    local verification_result
    verification_result=$(verify_tenant_authentication "$target_tenant_id" "$target_domain")
    local verification_code=$?
    
    case $verification_code in
        0)
            echo_success "OneDrive authentication completed successfully"
            echo_success "Authenticated with correct tenant: $target_domain"
            echo "$log_prefix OneDrive authentication management completed successfully" >> "$LOG_FILE"
            return 0
            ;;
        2)
            echo_error "OneDrive authenticated with wrong tenant"
            echo_warning "Please sign out and authenticate with your Mosaik Berlin account"
            echo "$log_prefix ERROR: Wrong tenant authentication detected" >> "$LOG_FILE"
            return 2
            ;;
        *)
            echo_warning "Unable to verify OneDrive authentication"
            echo_info "OneDrive may still be setting up. Please check OneDrive manually."
            echo "$log_prefix WARNING: Authentication verification inconclusive" >> "$LOG_FILE"
            return 1
            ;;
    esac
}