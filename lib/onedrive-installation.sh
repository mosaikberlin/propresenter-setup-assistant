#!/bin/bash

# OneDrive Installation Module
# Handles OneDrive detection, installation, and basic setup

#=============================================================================
# DETECTION FUNCTIONS
#=============================================================================

# Function to check if OneDrive is installed
check_onedrive_installation() {
    local log_prefix="[OneDrive Install]"
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

#=============================================================================
# INSTALLATION FUNCTIONS
#=============================================================================

# Function to install OneDrive
install_onedrive() {
    local log_prefix="[OneDrive Install]"
    
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

#=============================================================================
# MAIN INSTALLATION FUNCTION
#=============================================================================

# Main function to ensure OneDrive is installed
ensure_onedrive_installed() {
    local log_prefix="[OneDrive Install]"
    
    echo "$log_prefix Starting OneDrive installation check" >> "$LOG_FILE"
    
    # Check if OneDrive is already installed
    if check_onedrive_installation; then
        echo_success "OneDrive is already installed"
        echo "$log_prefix OneDrive installation check completed - already installed" >> "$LOG_FILE"
        return 0
    else
        echo_status "OneDrive not installed, proceeding with installation..."
        echo "$log_prefix OneDrive not found, starting installation process" >> "$LOG_FILE"
        
        if install_onedrive; then
            echo_success "OneDrive installation completed successfully"
            echo "$log_prefix OneDrive installation process completed successfully" >> "$LOG_FILE"
            return 0
        else
            echo_error "Failed to install OneDrive"
            echo "$log_prefix ERROR: OneDrive installation process failed" >> "$LOG_FILE"
            return 1
        fi
    fi
}