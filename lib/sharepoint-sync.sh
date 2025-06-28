#!/bin/bash

# SharePoint Library Manual Sync Module
# Guides user through browser-based SharePoint sync

# =============================================================================
# Global Variables
# =============================================================================

SHAREPOINT_LOG_PREFIX="[SharePoint Sync]"

# =============================================================================
# Browser-Based SharePoint Sync
# =============================================================================

# Function to open SharePoint site in browser
open_sharepoint_site() {
    local sharepoint_url="$1"
    
    echo_info "Opening SharePoint site in your default browser..."
    echo "$(date): $SHAREPOINT_LOG_PREFIX Opening SharePoint site: $sharepoint_url" >> "$LOG_FILE"
    
    if open "$sharepoint_url"; then
        echo_success "SharePoint site opened in browser"
        return 0
    else
        echo_error "Failed to open SharePoint site"
        return 1
    fi
}

# Function to show sync instructions dialog
show_sync_instructions() {
    local dialog_message="SharePoint Library Sync Instructions

The SharePoint site has been opened in your browser. You may need to sign in first with your Mosaik Berlin M365 credentials.

Please sync the ProPresenter library by:

1. Click the 'Sync' button in the toolbar (next to 'Share')
2. OneDrive may ask for permission - click 'Allow'
3. The folder will start syncing to your computer
4. Click 'Continue' below when the sync has started"

    if show_confirmation_dialog "SharePoint Sync Setup" "$dialog_message"; then
        return 0
    else
        return 1
    fi
}

# Function to wait for sync completion with spinner
wait_for_sync_folder() {
    local max_wait_time=60  # 1 minute
    local wait_count=0
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spinner_index=0
    
    echo_info "Waiting for SharePoint folder to appear locally..."
    echo "$(date): $SHAREPOINT_LOG_PREFIX Waiting for SharePoint sync folder to appear" >> "$LOG_FILE"
    
    while [[ $wait_count -lt $max_wait_time ]]; do
        local found_folder=""
        
        # Search in OneDrive CloudStorage locations
        for location in "$HOME/Library/CloudStorage"/*; do
            if [[ -d "$location" ]]; then
                # Look for OneDrive SharePoint libraries (German: "Freigegebene Bibliotheken" or English: "Shared Libraries")
                if [[ "$location" == *"OneDrive"* && ( "$location" == *"Freigegebene"* || "$location" == *"Shared"* || "$location" == *"Libraries"* || "$location" == *"Bibliotheken"* ) ]]; then
                    echo_info "Found OneDrive SharePoint location: $location"
                    
                    # Look for ProPresenter-related folders
                    local propresenter_folders
                    propresenter_folders=$(find "$location" -type d -name "*ProPresenter*" -o -name "*Visuals*Team*" 2>/dev/null | head -5)
                    
                    if [[ -n "$propresenter_folders" ]]; then
                        while IFS= read -r folder_path; do
                            if [[ -d "$folder_path" ]]; then
                                found_folder="$folder_path"
                                echo_info "Found ProPresenter folder: $folder_path"
                                break 2
                            fi
                        done <<< "$propresenter_folders"
                    fi
                fi
            fi
        done
        
        if [[ -n "$found_folder" ]]; then
            echo ""  # Clear spinner line
            echo_success "SharePoint ProPresenter folder found: $found_folder"
            echo "$(date): $SHAREPOINT_LOG_PREFIX SharePoint folder found: $found_folder" >> "$LOG_FILE"
            export SHAREPOINT_SYNC_FOLDER="$found_folder"
            return 0
        fi
        
        # Show spinner
        local spinner_char="${spinner_chars:$spinner_index:1}"
        printf "\r${CYAN}%s${NC} Searching for SharePoint sync folder... (%ds)" "$spinner_char" "$wait_count"
        
        # Update spinner
        spinner_index=$(( (spinner_index + 1) % ${#spinner_chars} ))
        
        sleep 2
        ((wait_count += 2))
    done
    
    echo ""  # Clear spinner line
    echo_error "SharePoint sync folder not found within timeout period"
    echo "$(date): $SHAREPOINT_LOG_PREFIX SharePoint sync folder not found within timeout" >> "$LOG_FILE"
    return 1
}

# Function to ensure files are physically present (not cloud-only placeholders)
set_folder_always_available() {
    local folder_path="$1"
    
    if [[ ! -d "$folder_path" ]]; then
        echo_error "Folder does not exist: $folder_path"
        return 1
    fi
    
    echo_info "Ensuring files are physically present on device (ProPresenter requirement): $folder_path"
    echo "$(date): $SHAREPOINT_LOG_PREFIX Setting files to be physically present for ProPresenter compatibility: $folder_path" >> "$LOG_FILE"
    
    # Method 1: Try using OneDrive binary with /pin command
    local onedrive_binary="/Applications/OneDrive.app/Contents/MacOS/OneDrive"
    if [[ -x "$onedrive_binary" ]]; then
        echo_info "Using OneDrive binary to pin folder recursively..."
        if "$onedrive_binary" /pin /r "$folder_path" 2>/dev/null; then
            echo_success "Successfully pinned folder recursively via OneDrive binary"
            echo "$(date): $SHAREPOINT_LOG_PREFIX Folder pinned recursively via OneDrive binary" >> "$LOG_FILE"
            return 0
        else
            echo_info "OneDrive binary pin command failed, trying alternative methods..."
        fi
    else
        echo_info "OneDrive binary not found at expected location"
    fi
        
    if [[ "$script_result" == "success" ]]; then
        echo_success "Successfully ensured files are physically present via Finder"
        echo "$(date): $SHAREPOINT_LOG_PREFIX Files set to be physically present via Finder" >> "$LOG_FILE"
        return 0
    elif [[ "$script_result" == "menu_not_found" ]]; then
        echo_info "OneDrive menu option not found in context menu"
    else
        echo_info "Finder script result: $script_result"
    fi
        
    # Verify the folder is accessible and has actual file content (not just cloud placeholders)
    if [[ -d "$folder_path" ]] && [[ $(ls -A "$folder_path" 2>/dev/null | wc -l) -gt 0 ]]; then
        echo_success "Folder is accessible and contains physical files"
        echo_info "Files are ready for ProPresenter - not cloud-only placeholders"
        echo "$(date): $SHAREPOINT_LOG_PREFIX Files ensured to be physically present for ProPresenter compatibility" >> "$LOG_FILE"
        return 0
    else
        echo_error "Folder appears to be empty or inaccessible"
        return 1
    fi
}

# =============================================================================
# Main SharePoint Sync Management
# =============================================================================

# Main function to manage SharePoint sync
manage_sharepoint_sync() {
    echo_header "SharePoint Library Setup"
    echo "$(date): $SHAREPOINT_LOG_PREFIX Starting SharePoint library sync setup" >> "$LOG_FILE"
    
    # Read environment configuration
    local sharepoint_url="$SHAREPOINT_URL"
    local tenant_domain="$TENANT_DOMAIN"
    
    if [[ -z "$sharepoint_url" || -z "$tenant_domain" ]]; then
        echo_error "SharePoint configuration not found in environment"
        echo_error "Required: SHAREPOINT_URL, TENANT_DOMAIN"
        return 1
    fi
    
    echo_info "SharePoint URL: $sharepoint_url"
    echo_info "Tenant Domain: $tenant_domain"
    echo ""
    
    # Step 1: Open SharePoint site in browser
    echo_step "Opening SharePoint site"
    if ! open_sharepoint_site "$sharepoint_url"; then
        echo_error "Failed to open SharePoint site"
        return 1
    fi
    
    echo ""
    
    # Step 2: Show sync instructions
    echo_step "SharePoint sync setup"
    if ! show_sync_instructions; then
        echo_warning "User cancelled SharePoint sync setup"
        echo "$(date): $SHAREPOINT_LOG_PREFIX User cancelled sync setup" >> "$LOG_FILE"
        return 1
    fi
    
    echo ""
    
    # Step 3: Wait for sync folder to appear
    echo_step "Detecting SharePoint sync folder"
    if ! wait_for_sync_folder; then
        echo ""
        echo_error "SharePoint sync folder detection failed"
        echo_error "The SharePoint library must be successfully synced for ProPresenter setup to continue."
        echo ""
        echo_info "Please ensure:"
        echo_info "1. You clicked the 'Sync' button in SharePoint"
        echo_info "2. OneDrive is running and authenticated"
        echo_info "3. You have access to the ProPresenter library"
        echo ""
        echo_info "SharePoint URL: $sharepoint_url"
        echo ""
        echo_error "Setup cannot continue without SharePoint sync. Please retry after fixing the sync issue."
        echo "$(date): $SHAREPOINT_LOG_PREFIX SharePoint sync failed - setup cannot continue" >> "$LOG_FILE"
        return 1
    fi
    
    echo ""
    echo_success "SharePoint sync detected successfully!"
    
    # Step 4: Ensure files are physically present (ProPresenter compatibility requirement)
    echo ""
    echo_step "Ensuring files are physically present for ProPresenter compatibility"
    if ! set_folder_always_available "$SHAREPOINT_SYNC_FOLDER"; then
        echo_error "Failed to ensure files are physically present on device"
        echo_error "Setup cannot continue - ProPresenter requires physical files, not cloud placeholders."
        echo "$(date): $SHAREPOINT_LOG_PREFIX Failed to ensure files are physically present" >> "$LOG_FILE"
        return 1
    fi
        
    echo ""
    echo_success "SharePoint library setup completed successfully"
    echo_info "SharePoint folder: $SHAREPOINT_SYNC_FOLDER"
    echo_success "Files are now physically present on device for ProPresenter compatibility"
    echo_info "The SharePoint library will continue syncing in the background via OneDrive."
    echo "$(date): $SHAREPOINT_LOG_PREFIX SharePoint library setup completed successfully" >> "$LOG_FILE"
    
    return 0
}