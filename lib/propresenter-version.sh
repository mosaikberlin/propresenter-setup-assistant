#!/bin/bash

# ProPresenter Version Management Module
# Handles ProPresenter installation, version detection, and configuration management

# Function to check if Homebrew is installed and install if missing
check_homebrew_installation() {
    local log_prefix="[ProPresenter Version]"
    
    echo_step "Checking Homebrew installation..."
    
    # Check if brew command exists
    if command -v brew >/dev/null 2>&1; then
        local brew_version=$(brew --version | head -n1)
        echo_success "Homebrew is installed: $brew_version"
        echo "$log_prefix Homebrew found: $brew_version" >> "$LOG_FILE"
        return 0
    fi
    
    echo_warning "Homebrew not found. Installing Homebrew..."
    echo "$log_prefix Homebrew not found, initiating installation" >> "$LOG_FILE"
    
    # Install Homebrew using the official installation script
    echo_status "Downloading and installing Homebrew (this may take a few minutes)..."
    
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        echo_success "Homebrew installed successfully"
        echo "$log_prefix Homebrew installation completed successfully" >> "$LOG_FILE"
        
        # Add Homebrew to PATH for current session
        case "$(uname -m)" in
            "arm64")
                export PATH="/opt/homebrew/bin:$PATH"
                echo "$log_prefix Added /opt/homebrew/bin to PATH for Apple Silicon" >> "$LOG_FILE"
                ;;
            "x86_64")
                export PATH="/usr/local/bin:$PATH"
                echo "$log_prefix Added /usr/local/bin to PATH for Intel" >> "$LOG_FILE"
                ;;
        esac
        
        # Verify installation
        if command -v brew >/dev/null 2>&1; then
            local new_brew_version=$(brew --version | head -n1)
            echo_success "Homebrew verification successful: $new_brew_version"
            echo "$log_prefix Homebrew verification completed: $new_brew_version" >> "$LOG_FILE"
            return 0
        else
            echo_error "Homebrew installation verification failed"
            echo "$log_prefix ERROR: Homebrew installation verification failed" >> "$LOG_FILE"
            return 1
        fi
    else
        echo_error "Failed to install Homebrew"
        echo "$log_prefix ERROR: Homebrew installation failed" >> "$LOG_FILE"
        return 1
    fi
}

# Function to get ProPresenter version silently (for internal use)
get_propresenter_version_silent() {
    local log_prefix="[ProPresenter Version]"
    local app_path="/Applications/ProPresenter.app"
    local info_plist="$app_path/Contents/Info.plist"
    
    # Check if ProPresenter is installed
    if [[ ! -d "$app_path" ]]; then
        echo "$log_prefix ProPresenter not installed at $app_path" >> "$LOG_FILE"
        return 1
    fi
    
    # Check if Info.plist exists
    if [[ ! -f "$info_plist" ]]; then
        echo "$log_prefix ERROR: Info.plist not found at $info_plist" >> "$LOG_FILE"
        return 1
    fi
    
    # Extract version using defaults command (more reliable than plutil) - output only the version
    local version
    if version=$(defaults read "$app_path/Contents/Info" CFBundleShortVersionString 2>/dev/null); then
        echo "$log_prefix ProPresenter version detected: $version" >> "$LOG_FILE"
        echo "$version"
        return 0
    else
        echo "$log_prefix ERROR: Failed to read version from Info.plist" >> "$LOG_FILE"
        return 1
    fi
}

# Function to get ProPresenter version from application bundle (with UI)
get_propresenter_version() {
    local log_prefix="[ProPresenter Version]"
    
    echo_step "Detecting ProPresenter version..."
    
    local version
    if version=$(get_propresenter_version_silent); then
        echo_success "ProPresenter version detected: $version"
        echo "$version"
        return 0
    else
        echo_error "Failed to detect ProPresenter version"
        return 1
    fi
}

# Function to compare version numbers (semantic versioning)
compare_versions() {
    local version1="$1"
    local version2="$2"
    local log_prefix="[ProPresenter Version]"
    
    # Remove any non-numeric prefixes and suffixes
    version1=$(echo "$version1" | sed 's/^[^0-9]*//; s/[^0-9.]*$//')
    version2=$(echo "$version2" | sed 's/^[^0-9]*//; s/[^0-9.]*$//')
    
    echo "$log_prefix Comparing versions: $version1 vs $version2" >> "$LOG_FILE"
    
    # Convert versions to arrays manually to avoid IFS issues
    local v1_major v1_minor v1_patch
    local v2_major v2_minor v2_patch
    
    # Parse first version
    v1_major=$(echo "$version1" | cut -d. -f1)
    v1_minor=$(echo "$version1" | cut -d. -f2 2>/dev/null || echo "0")
    v1_patch=$(echo "$version1" | cut -d. -f3 2>/dev/null || echo "0")
    
    # Parse second version
    v2_major=$(echo "$version2" | cut -d. -f1)
    v2_minor=$(echo "$version2" | cut -d. -f2 2>/dev/null || echo "0")
    v2_patch=$(echo "$version2" | cut -d. -f3 2>/dev/null || echo "0")
    
    # Remove leading zeros to avoid octal interpretation
    v1_major=$((10#$v1_major))
    v1_minor=$((10#$v1_minor))
    v1_patch=$((10#$v1_patch))
    v2_major=$((10#$v2_major))
    v2_minor=$((10#$v2_minor))
    v2_patch=$((10#$v2_patch))
    
    echo "$log_prefix Parsed v1: $v1_major.$v1_minor.$v1_patch, v2: $v2_major.$v2_minor.$v2_patch" >> "$LOG_FILE"
    
    # Compare major version
    if ((v1_major > v2_major)); then
        echo "$log_prefix Result: v1 > v2 (major)" >> "$LOG_FILE"
        echo "1"
        return 0
    elif ((v1_major < v2_major)); then
        echo "$log_prefix Result: v1 < v2 (major)" >> "$LOG_FILE"
        echo "-1"
        return 0
    fi
    
    # Compare minor version
    if ((v1_minor > v2_minor)); then
        echo "$log_prefix Result: v1 > v2 (minor)" >> "$LOG_FILE"
        echo "1"
        return 0
    elif ((v1_minor < v2_minor)); then
        echo "$log_prefix Result: v1 < v2 (minor)" >> "$LOG_FILE"
        echo "-1"
        return 0
    fi
    
    # Compare patch version
    if ((v1_patch > v2_patch)); then
        echo "$log_prefix Result: v1 > v2 (patch)" >> "$LOG_FILE"
        echo "1"
        return 0
    elif ((v1_patch < v2_patch)); then
        echo "$log_prefix Result: v1 < v2 (patch)" >> "$LOG_FILE"
        echo "-1"
        return 0
    fi
    
    echo "$log_prefix Result: v1 == v2 (equal)" >> "$LOG_FILE"
    echo "0"
}

# Function to install ProPresenter via Homebrew
install_propresenter_via_homebrew() {
    local log_prefix="[ProPresenter Version]"
    local target_version="$1"
    
    echo_step "Installing ProPresenter via Homebrew..."
    echo "$log_prefix Starting ProPresenter installation via Homebrew, target version: $target_version" >> "$LOG_FILE"
    
    # Update Homebrew first
    echo_status "Updating Homebrew..."
    if brew update >/dev/null 2>&1; then
        echo_success "Homebrew updated successfully"
        echo "$log_prefix Homebrew update completed" >> "$LOG_FILE"
    else
        echo_warning "Homebrew update had issues, continuing with installation..."
        echo "$log_prefix Homebrew update had issues, continuing" >> "$LOG_FILE"
    fi
    
    # Check if ProPresenter is available via Homebrew cask
    echo_status "Searching for ProPresenter in Homebrew cask..."
    if brew search --cask propresenter >/dev/null 2>&1; then
        echo_success "ProPresenter found in Homebrew cask"
        echo "$log_prefix ProPresenter found in Homebrew cask" >> "$LOG_FILE"
        
        # Check if ProPresenter app exists at /Applications/ProPresenter.app
        local app_exists=false
        if [[ -d "/Applications/ProPresenter.app" ]]; then
            app_exists=true
            echo_warning "ProPresenter app already exists at /Applications/ProPresenter.app"
            echo "$log_prefix ProPresenter app already exists at /Applications/ProPresenter.app" >> "$LOG_FILE"
        fi
        
        # Check if ProPresenter is managed by Homebrew
        local homebrew_managed=false
        if brew list --cask propresenter >/dev/null 2>&1; then
            homebrew_managed=true
            echo_status "ProPresenter is managed by Homebrew"
            echo "$log_prefix ProPresenter is managed by Homebrew" >> "$LOG_FILE"
        fi
        
        # Handle different scenarios
        if [[ "$homebrew_managed" == "true" ]]; then
            # If managed by Homebrew, use reinstall with force
            echo_status "Reinstalling ProPresenter via Homebrew with force..."
            if brew reinstall --cask --force propresenter; then
                echo_success "ProPresenter reinstalled successfully via Homebrew"
                echo "$log_prefix ProPresenter reinstallation via Homebrew completed successfully" >> "$LOG_FILE"
                return 0
            else
                echo_error "Failed to reinstall ProPresenter via Homebrew"
                echo "$log_prefix ERROR: ProPresenter reinstallation via Homebrew failed" >> "$LOG_FILE"
                return 1
            fi
        elif [[ "$app_exists" == "true" ]]; then
            # If app exists but not managed by Homebrew, use install with force
            echo_status "Installing ProPresenter via Homebrew with force (overwriting existing app)..."
            echo "$log_prefix Installing ProPresenter with force to overwrite existing app" >> "$LOG_FILE"
            
            if brew install --cask --force propresenter; then
                echo_success "ProPresenter installed successfully via Homebrew (existing app overwritten)"
                echo "$log_prefix ProPresenter installation via Homebrew completed successfully" >> "$LOG_FILE"
                return 0
            else
                echo_error "Failed to install ProPresenter via Homebrew with force"
                echo "$log_prefix ERROR: ProPresenter installation via Homebrew with force failed" >> "$LOG_FILE"
                return 1
            fi
        else
            # Fresh installation
            echo_status "Installing ProPresenter via Homebrew..."
            if brew install --cask propresenter; then
                echo_success "ProPresenter installed successfully via Homebrew"
                echo "$log_prefix ProPresenter installation via Homebrew completed successfully" >> "$LOG_FILE"
                return 0
            else
                echo_error "Failed to install ProPresenter via Homebrew"
                echo "$log_prefix ERROR: ProPresenter installation via Homebrew failed" >> "$LOG_FILE"
                return 1
            fi
        fi
    else
        echo_warning "ProPresenter not available in Homebrew cask"
        echo "$log_prefix ProPresenter not available in Homebrew cask, will try alternative" >> "$LOG_FILE"
        return 2  # Special return code for fallback needed
    fi
}

# Function to install ProPresenter via direct download (for specific versions)
install_propresenter_direct() {
    local log_prefix="[ProPresenter Version]"
    local target_version="$1"
    
    echo_step "Installing ProPresenter version $target_version via direct download..."
    echo "$log_prefix Starting ProPresenter direct download installation for version $target_version" >> "$LOG_FILE"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    echo "$log_prefix Created temporary directory: $temp_dir" >> "$LOG_FILE"
    
    # ProPresenter version-specific download URLs
    local download_url=""
    local dmg_name=""
    
    # Map target versions to known download URLs (with correct build numbers)
    case "$target_version" in
        "7.12")
            download_url="https://renewedvision.com/downloads/propresenter/mac/ProPresenter_7.12_118226960.zip"
            dmg_name="ProPresenter_7.12_118226960.zip"
            ;;
        *)
            echo_warning "Direct download for ProPresenter version $target_version is not yet implemented."
            echo_warning "Currently only version 7.12 is supported for direct download."
            echo_status "For other versions, please visit https://renewedvision.com/propresenter/download"
            echo_status "Download the desired version manually and run this script again."
            echo "$log_prefix Direct download not implemented for version $target_version" >> "$LOG_FILE"
            rm -rf "$temp_dir"
            return 3  # Manual intervention needed
            ;;
    esac
    
    echo_status "Downloading ProPresenter $target_version..."
    echo "$log_prefix Downloading from: $download_url" >> "$LOG_FILE"
    
    # Download the installer
    if curl -L -o "$temp_dir/$dmg_name" "$download_url"; then
        echo_success "ProPresenter $target_version downloaded successfully"
        echo "$log_prefix Download completed successfully" >> "$LOG_FILE"
        
        # Backup existing ProPresenter if it exists
        if [[ -d "/Applications/ProPresenter.app" ]]; then
            echo_status "Backing up existing ProPresenter application..."
            
            # Create backup directory structure
            local app_backup_dir="$HOME/ProPresenter-Config-Backup/applications"
            mkdir -p "$app_backup_dir"
            
            # Get current version for backup naming
            local current_version_for_backup
            if current_version_for_backup=$(get_propresenter_version_silent 2>/dev/null); then
                local backup_app_name="ProPresenter_v${current_version_for_backup}_$(date +"%Y%m%d_%H%M%S").app"
            else
                local backup_app_name="ProPresenter_unknown_version_$(date +"%Y%m%d_%H%M%S").app"
            fi
            
            local backup_app_path="$app_backup_dir/$backup_app_name"
            
            # Inform user about upcoming sudo operation
            echo_important "Administrator permission needed to backup current ProPresenter installation"
            echo_info "You will be prompted for your password to safely backup the existing ProPresenter app."
            echo_info "This ensures we can restore it if needed."
            echo_info ""
            
            if sudo cp -R "/Applications/ProPresenter.app" "$backup_app_path"; then
                echo_success "Existing ProPresenter backed up to: $backup_app_path"
                echo "$log_prefix Existing ProPresenter backed up to: $backup_app_path" >> "$LOG_FILE"
                
                # Now remove the original (no additional sudo prompt needed)
                if sudo rm -rf "/Applications/ProPresenter.app"; then
                    echo_info "Original ProPresenter removed after backup"
                    echo "$log_prefix Original ProPresenter removed after backup" >> "$LOG_FILE"
                else
                    echo_error "Failed to remove original ProPresenter after backup"
                    echo "$log_prefix ERROR: Failed to remove original ProPresenter after backup" >> "$LOG_FILE"
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                echo_error "Failed to backup existing ProPresenter"
                echo "$log_prefix ERROR: Failed to backup existing ProPresenter" >> "$LOG_FILE"
                rm -rf "$temp_dir"
                return 1
            fi
        fi
        
        # Extract and install
        echo_status "Installing ProPresenter $target_version..."
        cd "$temp_dir"
        
        if unzip -q "$dmg_name"; then
            echo_info "ProPresenter archive extracted"
            echo "$log_prefix Archive extracted successfully" >> "$LOG_FILE"
            
            # Find the app bundle in the extracted files
            local app_bundle=$(find . -name "ProPresenter.app" -type d | head -n1)
            if [[ -n "$app_bundle" ]]; then
                # Copy to Applications
                echo_important "Installing ProPresenter $target_version to /Applications (administrator permission required)"
                if sudo cp -R "$app_bundle" "/Applications/"; then
                    echo_success "ProPresenter $target_version installed successfully"
                    echo "$log_prefix ProPresenter installed to /Applications/" >> "$LOG_FILE"
                    
                    # Clean up
                    cd /
                    rm -rf "$temp_dir"
                    return 0
                else
                    echo_error "Failed to copy ProPresenter to Applications folder"
                    echo "$log_prefix ERROR: Failed to copy to Applications" >> "$LOG_FILE"
                    cd /
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                echo_error "ProPresenter.app not found in downloaded archive"
                echo "$log_prefix ERROR: ProPresenter.app not found in archive" >> "$LOG_FILE"
                cd /
                rm -rf "$temp_dir"
                return 1
            fi
        else
            echo_error "Failed to extract ProPresenter archive"
            echo "$log_prefix ERROR: Failed to extract archive" >> "$LOG_FILE"
            cd /
            rm -rf "$temp_dir"
            return 1
        fi
    else
        echo_error "Failed to download ProPresenter $target_version"
        echo "$log_prefix ERROR: Download failed from $download_url" >> "$LOG_FILE"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Function to backup ProPresenter configuration
backup_propresenter_config() {
    local log_prefix="[ProPresenter Version]"
    local backup_dir="$HOME/ProPresenter-Config-Backup"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$backup_dir/propresenter_config_$timestamp"
    
    echo_step "Backing up ProPresenter configuration..."
    echo "$log_prefix Starting ProPresenter configuration backup" >> "$LOG_FILE"
    
    # Create backup directory
    mkdir -p "$backup_path"
    echo "$log_prefix Created backup directory: $backup_path" >> "$LOG_FILE"
    
    # Backup preferences file
    local prefs_file="$HOME/Library/Preferences/com.renewedvision.propresenter.plist"
    if [[ -f "$prefs_file" ]]; then
        if cp "$prefs_file" "$backup_path/"; then
            echo_success "ProPresenter preferences backed up"
            echo "$log_prefix Preferences file backed up successfully" >> "$LOG_FILE"
        else
            echo_error "Failed to backup ProPresenter preferences"
            echo "$log_prefix ERROR: Failed to backup preferences file" >> "$LOG_FILE"
            return 1
        fi
    else
        echo_status "No existing ProPresenter preferences found"
        echo "$log_prefix No existing preferences file found" >> "$LOG_FILE"
    fi
    
    # Backup ProPresenter data directory if it exists
    local data_dir="$HOME/Documents/ProPresenter"
    if [[ -d "$data_dir" ]]; then
        echo_status "Backing up ProPresenter data directory..."
        if cp -R "$data_dir" "$backup_path/ProPresenter_Documents"; then
            echo_success "ProPresenter data directory backed up"
            echo "$log_prefix Data directory backed up successfully" >> "$LOG_FILE"
        else
            echo_warning "Failed to backup ProPresenter data directory"
            echo "$log_prefix WARNING: Failed to backup data directory" >> "$LOG_FILE"
        fi
    else
        echo_status "No existing ProPresenter data directory found"
        echo "$log_prefix No existing data directory found" >> "$LOG_FILE"
    fi
    
    # Create backup info file
    cat > "$backup_path/backup_info.txt" << EOF
ProPresenter Configuration Backup
Created: $(date)
Backup Location: $backup_path
Original Preferences: $prefs_file
Original Data Directory: $data_dir

Note: ProPresenter application backups are stored separately in:
$HOME/ProPresenter-Config-Backup/applications/
EOF
    
    echo_success "Configuration backup completed: $backup_path"
    echo "$log_prefix Configuration backup completed successfully at $backup_path" >> "$LOG_FILE"
    
    # Store backup path for potential restore
    echo "$backup_path" > "$backup_dir/latest_backup_path.txt"
    
    return 0
}

# Function to verify ProPresenter installation
verify_propresenter_installation() {
    local log_prefix="[ProPresenter Version]"
    local target_version="$1"
    local app_path="/Applications/ProPresenter.app"
    
    echo_step "Verifying ProPresenter installation..."
    echo "$log_prefix Starting ProPresenter installation verification" >> "$LOG_FILE"
    
    # Check if application exists
    if [[ ! -d "$app_path" ]]; then
        echo_error "ProPresenter not found at $app_path"
        echo "$log_prefix ERROR: ProPresenter not found at expected location" >> "$LOG_FILE"
        return 1
    fi
    
    # Check if application is executable
    if [[ ! -x "$app_path/Contents/MacOS/ProPresenter" ]]; then
        echo_error "ProPresenter executable not found or not executable"
        echo "$log_prefix ERROR: ProPresenter executable issues" >> "$LOG_FILE"
        return 1
    fi
    
    # Get installed version
    local installed_version
    if installed_version=$(get_propresenter_version_silent); then
        echo_success "ProPresenter installation verified"
        echo "$log_prefix Installation verification successful" >> "$LOG_FILE"
        
        # Compare with target version
        local version_comparison=$(compare_versions "$installed_version" "$target_version")
        
        if [[ "$version_comparison" == "0" ]]; then
            echo_success "ProPresenter version matches target: $installed_version"
            echo "$log_prefix Version matches target perfectly: $installed_version" >> "$LOG_FILE"
            return 0
        elif [[ "$version_comparison" == "1" ]]; then
            echo_warning "ProPresenter version is newer than target: $installed_version > $target_version"
            echo "$log_prefix Version is newer than target: $installed_version > $target_version" >> "$LOG_FILE"
            return 0  # Newer version is acceptable
        else
            echo_warning "ProPresenter version is older than target: $installed_version < $target_version"
            echo "$log_prefix Version is older than target: $installed_version < $target_version" >> "$LOG_FILE"
            return 2  # Older version might need upgrade
        fi
    else
        echo_error "Failed to verify ProPresenter version"
        echo "$log_prefix ERROR: Failed to verify ProPresenter version" >> "$LOG_FILE"
        return 1
    fi
}

# Main function to handle ProPresenter version management
manage_propresenter_version() {
    local log_prefix="[ProPresenter Version]"
    local target_version="$1"
    
    if [[ -z "$target_version" ]]; then
        echo_error "Target ProPresenter version not specified"
        echo "$log_prefix ERROR: No target version provided" >> "$LOG_FILE"
        return 1
    fi
    
    echo_header "ProPresenter Version Management"
    echo "$log_prefix Starting ProPresenter version management for target version: $target_version" >> "$LOG_FILE"
    
    # Step 1: Check current ProPresenter installation
    local current_version
    if current_version=$(get_propresenter_version_silent); then
        echo_step "Detected ProPresenter version: $current_version"
        local version_comparison=$(compare_versions "$current_version" "$target_version")
        
        if [[ "$version_comparison" == "0" ]]; then
            echo_success "ProPresenter version matches target: $current_version"
            echo "$log_prefix ProPresenter version already matches target: $current_version" >> "$LOG_FILE"
            return 0
        elif [[ "$version_comparison" == "1" ]]; then
            echo_warning "ProPresenter version is newer than target: $current_version > $target_version"
            echo_warning "Installing target version $target_version (will backup current version)"
            echo "$log_prefix ProPresenter version is newer than target, proceeding with target installation: $current_version > $target_version" >> "$LOG_FILE"
            # Continue with installation below
        else
            echo_status "ProPresenter needs to be updated: $current_version < $target_version"
            echo "$log_prefix ProPresenter needs update: $current_version < $target_version" >> "$LOG_FILE"
            # Continue with installation below
        fi
        
        # Backup current configuration before proceeding
        if ! backup_propresenter_config; then
            echo_error "Failed to backup ProPresenter configuration"
            return 1
        fi
    else
        echo_status "ProPresenter not installed, proceeding with installation"
        echo "$log_prefix ProPresenter not installed, proceeding with fresh installation" >> "$LOG_FILE"
    fi
    
    # Step 2: Ensure Homebrew is available
    if ! check_homebrew_installation; then
        echo_error "Failed to ensure Homebrew is available"
        return 1
    fi
    
    # Step 3: Install ProPresenter
    # For specific version requirements, prefer direct download over Homebrew
    # since Homebrew casks always install the latest version
    
    local install_exit_code
    local current_latest_version
    
    # Check what the latest version would be from Homebrew
    echo_status "Checking if Homebrew would install the correct version..."
    if command -v brew >/dev/null 2>&1 && brew search --cask propresenter >/dev/null 2>&1; then
        echo_warning "Homebrew casks only install the latest version, not specific versions like $target_version"
        echo_status "Using direct download to install specific version $target_version"
        echo "$log_prefix Using direct download for version-specific installation" >> "$LOG_FILE"
        
        install_propresenter_direct "$target_version"
        install_exit_code=$?
        
        if [[ $install_exit_code -eq 0 ]]; then
            echo_success "ProPresenter $target_version installed successfully via direct download"
        elif [[ $install_exit_code -eq 3 ]]; then
            echo_error "Manual installation required. Please install ProPresenter $target_version manually and run this script again."
            return 3
        else
            echo_error "Direct download installation failed"
            return 1
        fi
    else
        echo_warning "Homebrew not available, attempting direct download"
        install_propresenter_direct "$target_version"
        install_exit_code=$?
        
        if [[ $install_exit_code -eq 0 ]]; then
            echo_success "ProPresenter $target_version installed successfully via direct download"
        elif [[ $install_exit_code -eq 3 ]]; then
            echo_error "Manual installation required. Please install ProPresenter $target_version manually and run this script again."
            return 3
        else
            echo_error "Direct download installation failed"
            return 1
        fi
    fi
    
    # Step 4: Verify installation
    if verify_propresenter_installation "$target_version"; then
        echo_success "ProPresenter version management completed successfully"
        echo "$log_prefix ProPresenter version management completed successfully" >> "$LOG_FILE"
        return 0
    else
        echo_error "ProPresenter installation verification failed"
        echo "$log_prefix ERROR: ProPresenter installation verification failed" >> "$LOG_FILE"
        return 1
    fi
}