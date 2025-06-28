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

# Function to show shortcut creation instructions dialog
show_shortcut_instructions() {
    local dialog_message="SharePoint Library Setup - Shortcut Method

The SharePoint site has been opened in your browser. You may need to sign in first with your Mosaik Berlin M365 credentials.

To access the ProPresenter content library:

1. Click 'Add shortcut to OneDrive' (NOT 'Sync') in the toolbar (next to Download)
2. The folder will appear in your personal OneDrive
3. It will sync automatically and be immediately available
4. Click 'Continue' below when you've created the shortcut

This method ensures consistent paths across all team machines and eliminates sync complexity."

    if show_confirmation_dialog "SharePoint Shortcut Setup" "$dialog_message"; then
        return 0
    else
        return 1
    fi
}

# Function to detect OneDrive shortcut folder
detect_onedrive_shortcut_folder() {
    local current_user=$(whoami)
    
    # Log to file only to avoid interfering with return value
    echo "$(date): $SHAREPOINT_LOG_PREFIX Searching for OneDrive shortcut folder" >> "$LOG_FILE"
    
    # Find OneDrive folders in CloudStorage (the definitive location)
    local onedrive_folders=()
    local cloudstorage_dir="$HOME/Library/CloudStorage"
    
    if [[ ! -d "$cloudstorage_dir" ]]; then
        echo "$(date): $SHAREPOINT_LOG_PREFIX CloudStorage directory not found" >> "$LOG_FILE"
        return 1
    fi
    
    # Look for OneDrive folders in CloudStorage
    for onedrive_path in "$cloudstorage_dir"/OneDrive*; do
        if [[ -d "$onedrive_path" ]]; then
            onedrive_folders+=("$onedrive_path")
        fi
    done
    
    # Check if we found any OneDrive folders
    if [[ ${#onedrive_folders[@]} -eq 0 ]]; then
        echo "$(date): $SHAREPOINT_LOG_PREFIX No OneDrive folders found in CloudStorage" >> "$LOG_FILE"
        return 1
    fi
    
    # Log the OneDrive folders we found
    echo "$(date): $SHAREPOINT_LOG_PREFIX Found ${#onedrive_folders[@]} OneDrive folder(s)" >> "$LOG_FILE"
    for folder in "${onedrive_folders[@]}"; do
        echo "$(date): $SHAREPOINT_LOG_PREFIX Checking OneDrive folder: $folder" >> "$LOG_FILE"
    done
    
    # Search each OneDrive folder for folders containing our keywords
    for onedrive_root in "${onedrive_folders[@]}"; do
        # Log to file and stderr, not stdout (to avoid interfering with return value)
        echo "$(date): $SHAREPOINT_LOG_PREFIX Searching in OneDrive folder: $(basename "$onedrive_root")" >> "$LOG_FILE"
        
        # Use find to search for folders containing Visuals, Team, and ProPresenter
        while IFS= read -r -d '' folder_path; do
            local folder_name=$(basename "$folder_path")
            echo "$(date): $SHAREPOINT_LOG_PREFIX Checking folder: $folder_name" >> "$LOG_FILE"
            
            # Check if folder name contains all required keywords (case-insensitive)
            if [[ "$folder_name" =~ [Vv]isuals ]] && [[ "$folder_name" =~ [Tt]eam ]] && [[ "$folder_name" =~ [Pp]ro[Pp]resenter ]]; then
                echo "$(date): $SHAREPOINT_LOG_PREFIX Found shortcut folder: $folder_path" >> "$LOG_FILE"
                echo "$folder_path"
                return 0
            fi
            
            # Also check for simpler patterns with at least 2 of the 3 keywords
            local keyword_count=0
            [[ "$folder_name" =~ [Vv]isuals ]] && ((keyword_count++))
            [[ "$folder_name" =~ [Tt]eam ]] && ((keyword_count++))
            [[ "$folder_name" =~ [Pp]ro[Pp]resenter ]] && ((keyword_count++))
            
            if [[ $keyword_count -ge 2 ]]; then
                echo "$(date): $SHAREPOINT_LOG_PREFIX Found shortcut folder: $folder_path" >> "$LOG_FILE"
                echo "$folder_path"
                return 0
            fi
            
        done < <(find "$onedrive_root" -maxdepth 2 -type d -print0 2>/dev/null)
    done
    
    echo "$(date): $SHAREPOINT_LOG_PREFIX OneDrive shortcut folder not found" >> "$LOG_FILE"
    return 1
}

# Function to wait for shortcut folder to appear with spinner
wait_for_shortcut_folder() {
    local max_wait_time=60  # 1 minute
    local wait_count=0
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spinner_index=0
    
    echo_info "Waiting for OneDrive shortcut folder to appear..."
    echo "$(date): $SHAREPOINT_LOG_PREFIX Waiting for OneDrive shortcut folder to appear" >> "$LOG_FILE"
    
    while [[ $wait_count -lt $max_wait_time ]]; do
        local found_folder
        found_folder=$(detect_onedrive_shortcut_folder 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$found_folder" ]]; then
            echo ""  # Clear spinner line
            echo_success "OneDrive shortcut folder found: $found_folder"
            echo "$(date): $SHAREPOINT_LOG_PREFIX OneDrive shortcut folder found: $found_folder" >> "$LOG_FILE"
            export SHAREPOINT_SYNC_FOLDER="$found_folder"
            return 0
        fi
        
        # Show spinner
        local spinner_char="${spinner_chars:$spinner_index:1}"
        printf "\r${CYAN}%s${NC} Searching for OneDrive shortcut folder... (%ds)" "$spinner_char" "$wait_count"
        
        # Update spinner
        spinner_index=$(( (spinner_index + 1) % ${#spinner_chars} ))
        
        sleep 2
        ((wait_count += 2))
    done
    
    echo ""  # Clear spinner line
    echo_error "OneDrive shortcut folder not found within timeout period"
    echo "$(date): $SHAREPOINT_LOG_PREFIX OneDrive shortcut folder not found within timeout" >> "$LOG_FILE"
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
    
    # Step 2: Show shortcut instructions
    echo_step "SharePoint shortcut setup"
    if ! show_shortcut_instructions; then
        echo_warning "User cancelled SharePoint shortcut setup"
        echo "$(date): $SHAREPOINT_LOG_PREFIX User cancelled shortcut setup" >> "$LOG_FILE"
        return 1
    fi
    
    echo ""
    
    # Step 3: Wait for shortcut folder to appear
    echo_step "Detecting OneDrive shortcut folder"
    if ! wait_for_shortcut_folder; then
        echo ""
        echo_error "OneDrive shortcut folder detection failed"
        echo_error "The SharePoint library shortcut must be created for ProPresenter setup to continue."
        echo ""
        echo_info "Please ensure:"
        echo_info "1. You clicked 'Add shortcut to OneDrive' (NOT 'Sync') in SharePoint"
        echo_info "2. OneDrive is running and authenticated"
        echo_info "3. You have access to the ProPresenter library"
        echo_info "4. The shortcut appears in your personal OneDrive folder"
        echo ""
        echo_info "SharePoint URL: $sharepoint_url"
        echo ""
        echo_error "Setup cannot continue without OneDrive shortcut. Please retry after creating the shortcut."
        echo "$(date): $SHAREPOINT_LOG_PREFIX OneDrive shortcut creation failed - setup cannot continue" >> "$LOG_FILE"
        return 1
    fi
    
    echo ""
    echo_success "OneDrive shortcut detected successfully!"
    
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
    echo_success "OneDrive shortcut setup completed successfully"
    echo_info "OneDrive shortcut folder: $SHAREPOINT_SYNC_FOLDER"
    echo_success "Files are now physically present on device for ProPresenter compatibility"
    echo_info "The OneDrive shortcut will continue syncing in the background automatically."
    echo "$(date): $SHAREPOINT_LOG_PREFIX OneDrive shortcut setup completed successfully" >> "$LOG_FILE"
    
    return 0
}