#!/bin/bash

# Self-Update Module for ProPresenter Setup Assistant
# Implements automatic version checking and update mechanism using GitHub Releases API

# Compare two semantic versions directly without formatting issues
# Returns: 0 if equal, 1 if version1 > version2, 2 if version1 < version2
compare_versions() {
    local version1=$1
    local version2=$2
    
    # Remove 'v' prefix if present
    version1=${version1#v}
    version2=${version2#v}
    
    # Split versions into parts
    local v1_major v1_minor v1_patch
    local v2_major v2_minor v2_patch
    
    IFS='.' read -r v1_major v1_minor v1_patch <<< "$version1"
    IFS='.' read -r v2_major v2_minor v2_patch <<< "$version2"
    
    # Handle versions with additional identifiers (like 1.0.0-beta)
    v1_patch=${v1_patch%%-*}
    v2_patch=${v2_patch%%-*}
    
    # Ensure all parts are numeric (remove leading zeros and default to 0)
    v1_major=$((10#${v1_major:-0}))
    v1_minor=$((10#${v1_minor:-0}))
    v1_patch=$((10#${v1_patch:-0}))
    v2_major=$((10#${v2_major:-0}))
    v2_minor=$((10#${v2_minor:-0}))
    v2_patch=$((10#${v2_patch:-0}))
    
    # Compare major version
    if (( v1_major > v2_major )); then
        return 1  # version1 is newer
    elif (( v1_major < v2_major )); then
        return 2  # version2 is newer
    fi
    
    # Major versions equal, compare minor
    if (( v1_minor > v2_minor )); then
        return 1  # version1 is newer
    elif (( v1_minor < v2_minor )); then
        return 2  # version2 is newer
    fi
    
    # Major and minor equal, compare patch
    if (( v1_patch > v2_patch )); then
        return 1  # version1 is newer
    elif (( v1_patch < v2_patch )); then
        return 2  # version2 is newer
    fi
    
    # All parts equal
    return 0
}

# Check network connectivity
check_network_connectivity() {
    if ! ping -c 1 -W 5000 github.com >/dev/null 2>&1; then
        echo_warning "Network connectivity check failed"
        return 1
    fi
    return 0
}

# Fetch latest release information from GitHub API
fetch_latest_release() {
    local api_url=$1
    local response
    
    # Check network connectivity first
    if ! check_network_connectivity; then
        echo_error "No network connectivity available for update check"
        return 1
    fi
    
    echo_status "Checking for updates from GitHub API..."
    
    # Fetch release information with timeout and user agent
    response=$(curl -s \
        --max-time 30 \
        --connect-timeout 10 \
        --user-agent "ProPresenter-Setup-Assistant/${SCRIPT_VERSION}" \
        --header "Accept: application/vnd.github.v3+json" \
        "$api_url" 2>/dev/null)
    
    local curl_exit_code=$?
    
    if [[ $curl_exit_code -ne 0 ]]; then
        echo_error "Failed to fetch release information (curl exit code: $curl_exit_code)"
        return 1
    fi
    
    # Validate JSON response
    if ! echo "$response" | python3 -m json.tool >/dev/null 2>&1; then
        echo_error "Invalid JSON response from GitHub API"
        return 1
    fi
    
    # Check for API rate limiting or access issues
    if echo "$response" | grep -q "rate limit exceeded"; then
        echo_warning "GitHub API rate limit exceeded, skipping update check"
        return 1
    fi
    
    # Check for private repository or not found
    if echo "$response" | grep -q '"message":"Not Found"'; then
        echo_status "Repository not found or private - skipping update check"
        return 1
    fi
    
    echo "$response"
    return 0
}

# Extract version and download URL from release JSON
parse_release_info() {
    local json_response=$1
    local version download_url
    
    # Extract version using python3 json module for reliable parsing
    version=$(echo "$json_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tag_name', ''))
except:
    pass
")
    
    # Extract download URL for ZIP asset
    download_url=$(echo "$json_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    assets = data.get('assets', [])
    for asset in assets:
        if asset.get('name', '').endswith('.zip'):
            print(asset.get('browser_download_url', ''))
            break
except:
    pass
")
    
    if [[ -z "$version" || -z "$download_url" ]]; then
        echo_error "Failed to parse release information"
        return 1
    fi
    
    echo "$version|$download_url"
    return 0
}

# Check if an update is available
check_for_updates() {
    local current_version=$1
    local api_url=$2
    
    echo_status "Current version: $current_version"
    
    # Fetch latest release
    local release_json
    release_json=$(fetch_latest_release "$api_url")
    
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Parse release information
    local release_info
    release_info=$(parse_release_info "$release_json")
    
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Extract version and download URL
    local latest_version download_url
    IFS='|' read -r latest_version download_url <<< "$release_info"
    
    echo_status "Latest version: $latest_version"
    
    # Compare versions
    compare_versions "$current_version" "$latest_version"
    local comparison_result=$?
    
    case $comparison_result in
        0)
            echo_success "You are running the latest version"
            return 1  # No update needed
            ;;
        1)
            echo_warning "You are running a newer version than available ($current_version > $latest_version)"
            return 1  # No update needed
            ;;
        2)
            echo_success "Update available: $current_version → $latest_version"
            # Store download URL for later use
            export UPDATE_DOWNLOAD_URL="$download_url"
            export UPDATE_VERSION="$latest_version"
            return 0  # Update available
            ;;
    esac
}

# Create backup of current script
backup_current_script() {
    local script_path=$1
    local backup_dir="${SCRIPT_DIR}/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="${backup_dir}/ProPresenter-Setup-Assistant_v${SCRIPT_VERSION}_${timestamp}.command"
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Create backup
    if cp "$script_path" "$backup_path"; then
        echo_success "Created backup: $backup_path"
        export BACKUP_PATH="$backup_path"
        return 0
    else
        echo_error "Failed to create backup"
        return 1
    fi
}

# Download and extract update
download_and_extract_update() {
    local download_url=$1
    local version=$2
    local temp_dir="${SCRIPT_DIR}/temp_update"
    local zip_file="${temp_dir}/update.zip"
    
    echo_step "Downloading update v${version}..."
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    
    # Download with progress and retry logic
    local retry_count=0
    local max_retries=3
    
    while [[ $retry_count -lt $max_retries ]]; do
        if curl -L \
            --progress-bar \
            --max-time 300 \
            --connect-timeout 30 \
            --user-agent "ProPresenter-Setup-Assistant/${SCRIPT_VERSION}" \
            --output "$zip_file" \
            "$download_url"; then
            break
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                echo_warning "Download failed, retrying... ($retry_count/$max_retries)"
                sleep $((retry_count * 2))  # Exponential backoff
            else
                echo_error "Download failed after $max_retries attempts"
                rm -rf "$temp_dir"
                return 1
            fi
        fi
    done
    
    # Verify download
    if [[ ! -f "$zip_file" ]] || [[ ! -s "$zip_file" ]]; then
        echo_error "Downloaded file is missing or empty"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo_status "Extracting update..."
    
    # Extract ZIP file
    if unzip -q "$zip_file" -d "$temp_dir"; then
        echo_success "Update extracted successfully"
        export UPDATE_TEMP_DIR="$temp_dir"
        return 0
    else
        echo_error "Failed to extract update"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Verify update integrity
verify_update_integrity() {
    local temp_dir=$1
    local main_script="${temp_dir}/ProPresenter-Setup-Assistant.command"
    
    echo_status "Verifying update integrity..."
    
    # Check if main script exists
    if [[ ! -f "$main_script" ]]; then
        echo_error "Main script not found in update package"
        return 1
    fi
    
    # Check if script is executable
    if [[ ! -x "$main_script" ]]; then
        echo_warning "Making script executable..."
        chmod +x "$main_script"
    fi
    
    # Verify script syntax
    if bash -n "$main_script"; then
        echo_success "Update integrity verified"
        return 0
    else
        echo_error "Update script has syntax errors"
        return 1
    fi
}

# Apply update by replacing current files
apply_update() {
    local temp_dir=$1
    local current_script_path=$2
    
    echo_step "Applying update..."
    
    # Stop any running processes that might interfere
    # (This is a placeholder for future implementation)
    
    # Apply update files
    if rsync -av --exclude="logs" --exclude="backups" --exclude="temp_update" "$temp_dir/" "$SCRIPT_DIR/"; then
        echo_success "Update applied successfully"
        
        # Ensure main script is executable
        chmod +x "$current_script_path"
        
        # Clean up temporary files
        rm -rf "$temp_dir"
        
        return 0
    else
        echo_error "Failed to apply update"
        return 1
    fi
}

# Restore from backup in case of failure
restore_from_backup() {
    local backup_path=$1
    local current_script_path=$2
    
    if [[ -n "$backup_path" ]] && [[ -f "$backup_path" ]]; then
        echo_warning "Restoring from backup..."
        if cp "$backup_path" "$current_script_path"; then
            chmod +x "$current_script_path"
            echo_success "Restored from backup successfully"
            return 0
        fi
    fi
    
    echo_error "Failed to restore from backup"
    return 1
}

# Main update function that orchestrates the entire process
download_and_restart_with_latest() {
    local current_script_path="${BASH_SOURCE[0]}"
    
    # Get the main script path (not this library file)
    if [[ "$current_script_path" == *"/lib/"* ]]; then
        current_script_path="${SCRIPT_DIR}/ProPresenter-Setup-Assistant.command"
    fi
    
    echo_step "Starting self-update process..."
    
    # Check if we have update information
    if [[ -z "$UPDATE_DOWNLOAD_URL" ]] || [[ -z "$UPDATE_VERSION" ]]; then
        echo_error "No update information available"
        return 1
    fi
    
    # Create backup
    if ! backup_current_script "$current_script_path"; then
        echo_error "Failed to create backup, aborting update"
        return 1
    fi
    
    # Download and extract update
    if ! download_and_extract_update "$UPDATE_DOWNLOAD_URL" "$UPDATE_VERSION"; then
        echo_error "Failed to download update"
        return 1
    fi
    
    # Verify update integrity
    if ! verify_update_integrity "$UPDATE_TEMP_DIR"; then
        echo_error "Update verification failed"
        rm -rf "$UPDATE_TEMP_DIR"
        return 1
    fi
    
    # Apply update
    if ! apply_update "$UPDATE_TEMP_DIR" "$current_script_path"; then
        echo_error "Failed to apply update, attempting to restore backup"
        restore_from_backup "$BACKUP_PATH" "$current_script_path"
        return 1
    fi
    
    echo_success "Update completed successfully!"
    echo_status "Restarting with updated script..."
    
    # Restart with updated script
    exec "$current_script_path" "$@"
}

# Initialize update check at script startup
initialize_update_check() {
    # Only check for updates if we're not already in an update process
    if [[ -z "$SKIP_UPDATE_CHECK" ]] && [[ -n "$GITHUB_API_URL" ]]; then
        echo_step "Checking for script updates..."
        
        if check_for_updates "$SCRIPT_VERSION" "$GITHUB_API_URL"; then
            # Ask user if they want to update
            if show_confirmation_dialog "Update Available" "A new version (${UPDATE_VERSION}) is available. Would you like to update now?"; then
                download_and_restart_with_latest "$@"
            else
                echo_warning "Update skipped by user"
            fi
        fi
    fi
}