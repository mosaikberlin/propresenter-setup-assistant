#!/bin/bash

# OneDrive Detection Module
# Handles detection and verification of OneDrive tenant authentication status

#=============================================================================
# TENANT DETECTION FUNCTIONS
#=============================================================================

# Function to check if target tenant is already authenticated
check_target_tenant_authenticated() {
    local target_domain="$1"
    local log_prefix="[OneDrive Detection]"
    
    # First, search for OneDrive folders containing "OneDrive", "Mosaik", and "Berlin" (case-insensitive)
    echo "$log_prefix Searching for OneDrive folders with OneDrive+Mosaik+Berlin pattern" >> "$LOG_FILE"
    
    # Search in common OneDrive locations
    local search_locations=(
        "$HOME"
        "$HOME/Library/CloudStorage"
    )
    
    local found_folder=""
    
    for location in "${search_locations[@]}"; do
        if [[ -d "$location" ]]; then
            # Find directories that contain all three keywords (case-insensitive)
            while IFS= read -r -d '' folder; do
                local folder_name=$(basename "$folder")
                # Check if folder name contains all three keywords (case-insensitive)
                if [[ "$folder_name" =~ [Oo]ne[Dd]rive ]] && \
                   [[ "$folder_name" =~ [Mm]osaik ]] && \
                   [[ "$folder_name" =~ [Bb]erlin ]]; then
                    found_folder="$folder"
                    echo "$log_prefix Found OneDrive+Mosaik+Berlin folder: $folder" >> "$LOG_FILE"
                    break 2
                fi
            done < <(find "$location" -maxdepth 1 -type d -name "*OneDrive*" -print0 2>/dev/null)
        fi
    done
    
    # If we found a folder, verify it's actually syncing
    if [[ -n "$found_folder" ]]; then
        if verify_onedrive_sync_status "$found_folder"; then
            echo "$log_prefix Verified OneDrive sync is active for: $found_folder" >> "$LOG_FILE"
            return 0
        else
            echo "$log_prefix WARNING: Found folder but sync appears inactive: $found_folder" >> "$LOG_FILE"
            return 1
        fi
    fi
    
    echo "$log_prefix No active Mosaik Berlin OneDrive sync detected" >> "$LOG_FILE"
    return 1
}

# Function to verify OneDrive sync status
verify_onedrive_sync_status() {
    local folder_path="$1"
    local log_prefix="[OneDrive Detection]"
    
    # Check if OneDrive process is running
    if ! pgrep -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1; then
        echo "$log_prefix OneDrive process not running" >> "$LOG_FILE"
        return 1
    fi
    
    # Check if folder exists and has recent activity
    if [[ ! -d "$folder_path" ]]; then
        echo "$log_prefix Folder does not exist: $folder_path" >> "$LOG_FILE"
        return 1
    fi
    
    # Check for OneDrive sync indicators
    local sync_indicators=(
        # OneDrive creates these hidden files/folders in synced directories
        "$folder_path/.849C9593-D756-4E56-8D6E-42412F2A707B"
        "$folder_path/desktop.ini"
    )
    
    # Look for any sync indicator files
    for indicator in "${sync_indicators[@]}"; do
        if [[ -e "$indicator" ]]; then
            echo "$log_prefix Found sync indicator: $indicator" >> "$LOG_FILE"
            return 0
        fi
    done
    
    # Alternative: Check if the folder has been accessed recently (within last hour)
    # This suggests active sync
    if [[ -n "$(find "$folder_path" -type f -newermt '1 hour ago' 2>/dev/null | head -1)" ]]; then
        echo "$log_prefix Found recent file activity in OneDrive folder" >> "$LOG_FILE"
        return 0
    fi
    
    # Check OneDrive status via command line if available
    if command -v "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1; then
        # Try to get OneDrive status (this might not work on all versions)
        local onedrive_status
        onedrive_status=$(timeout 5s "/Applications/OneDrive.app/Contents/MacOS/OneDrive" /status 2>/dev/null || echo "")
        if [[ "$onedrive_status" =~ [Ss]ync ]]; then
            echo "$log_prefix OneDrive reports active sync status" >> "$LOG_FILE"
            return 0
        fi
    fi
    
    # Check if folder contains typical OneDrive/Office files
    if [[ -n "$(find "$folder_path" -type f \( -name "*.docx" -o -name "*.xlsx" -o -name "*.pptx" \) 2>/dev/null | head -1)" ]]; then
        echo "$log_prefix Found Office files suggesting active OneDrive usage" >> "$LOG_FILE"
        return 0
    fi
    
    echo "$log_prefix No clear sync indicators found for: $folder_path" >> "$LOG_FILE"
    return 1
}

#=============================================================================
# ACCOUNT DETECTION FUNCTIONS
#=============================================================================

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

# Function to check OneDrive tenant status
check_onedrive_tenant_status() {
    local target_tenant_id="$1"
    local target_domain="$2"
    local log_prefix="[OneDrive Detection]"
    
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

#=============================================================================
# PROCESS AND STATE DETECTION FUNCTIONS
#=============================================================================

# Function to check if OneDrive process is running
is_onedrive_process_running() {
    pgrep -f "/Applications/OneDrive.app/Contents/MacOS/OneDrive" >/dev/null 2>&1
}

# Function to check OneDrive configuration directories
has_onedrive_configuration() {
    local onedrive_settings_dir="$HOME/Library/Group Containers/UBF8T346G9.OneDriveStandaloneSuite"
    local onedrive_config_dir="$HOME/Library/Application Support/OneDrive"
    
    [[ -d "$onedrive_settings_dir" ]] || [[ -d "$onedrive_config_dir" ]]
}

# Function to determine OneDrive authentication state
get_onedrive_auth_state() {
    local target_domain="$1"
    local log_prefix="[OneDrive Detection]"
    
    echo "$log_prefix Determining OneDrive authentication state" >> "$LOG_FILE"
    
    # Check if OneDrive is installed
    if [[ ! -d "/Applications/OneDrive.app" ]]; then
        echo "not_installed"
        return
    fi
    
    # Check if target tenant is already authenticated
    if check_target_tenant_authenticated "$target_domain"; then
        echo "authenticated_correct_tenant"
        return
    fi
    
    # Check if OneDrive process is running
    if is_onedrive_process_running; then
        # Check if there are existing accounts
        local existing_accounts=$(list_onedrive_accounts)
        if [[ -n "$existing_accounts" ]]; then
            echo "running_with_other_accounts"
        else
            echo "running_no_accounts"
        fi
    else
        echo "not_running"
    fi
}

#=============================================================================
# VERIFICATION FUNCTIONS
#=============================================================================

# Function to verify tenant authentication
verify_tenant_authentication() {
    local log_prefix="[OneDrive Detection]"
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
        if has_onedrive_configuration; then
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
        if ! is_onedrive_process_running; then
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