#!/bin/bash

# Symlink Creation and Path Normalization Module
# Creates standardized folder structure using symbolic links

# =============================================================================
# Global Variables
# =============================================================================

SYMLINK_LOG_PREFIX="[Symlink Creation]"
SYMLINK_TARGET_BASE="$HOME/ProPresenter-Sync"

# Target folder structure mapping (source_folder:target_folder)
FOLDER_MAPPINGS=(
    "Application Directory:Application-Directory"
    "Long-living Assets:Long-living-Assets"
    "Short-living Assets:Short-living-Assets"
)

# Helper function to get target folder name from source folder name
get_target_folder() {
    local source_folder="$1"
    for mapping in "${FOLDER_MAPPINGS[@]}"; do
        local source="${mapping%%:*}"
        local target="${mapping##*:}"
        if [[ "$source" == "$source_folder" ]]; then
            echo "$target"
            return 0
        fi
    done
    echo ""
    return 1
}

# =============================================================================
# OneDrive Path Detection
# =============================================================================

# Function to detect OneDrive sync locations
detect_onedrive_paths() {
    echo_info "Detecting OneDrive sync locations..."
    echo "$(date): $SYMLINK_LOG_PREFIX Starting OneDrive path detection" >> "$LOG_FILE"
    
    local found_paths=()
    
    # Search in OneDrive CloudStorage locations
    for location in "$HOME/Library/CloudStorage"/*; do
        if [[ -d "$location" ]]; then
            # Look for OneDrive SharePoint libraries (German: "Freigegebene Bibliotheken" or English: "Shared Libraries")
            if [[ "$location" == *"OneDrive"* && ( "$location" == *"Freigegebene"* || "$location" == *"Shared"* || "$location" == *"Libraries"* || "$location" == *"Bibliotheken"* ) ]]; then
                echo_info "Found OneDrive SharePoint location: $location"
                found_paths+=("$location")
            fi
        fi
    done
    
    if [[ ${#found_paths[@]} -eq 0 ]]; then
        echo_error "No OneDrive SharePoint locations found"
        echo "$(date): $SYMLINK_LOG_PREFIX No OneDrive paths detected" >> "$LOG_FILE"
        return 1
    fi
    
    # Export the first found path (primary OneDrive location)
    export ONEDRIVE_BASE_PATH="${found_paths[0]}"
    echo_success "Primary OneDrive path detected: $ONEDRIVE_BASE_PATH"
    echo "$(date): $SYMLINK_LOG_PREFIX Primary OneDrive path: $ONEDRIVE_BASE_PATH" >> "$LOG_FILE"
    
    return 0
}

# Function to normalize folder paths and handle naming variations
normalize_folder_paths() {
    local base_path="$1"
    
    echo_info "Normalizing folder paths from base: $base_path"
    echo "$(date): $SYMLINK_LOG_PREFIX Normalizing folder paths from: $base_path" >> "$LOG_FILE"
    
    # Look for ProPresenter-related folders
    local propresenter_folders
    propresenter_folders=$(find "$base_path" -type d -name "*ProPresenter*" -o -name "*Visuals*Team*" 2>/dev/null | head -5)
    
    if [[ -z "$propresenter_folders" ]]; then
        echo_error "No ProPresenter folders found in OneDrive path"
        return 1
    fi
    
    # Use the first found ProPresenter folder as the source
    local source_folder
    source_folder=$(echo "$propresenter_folders" | head -1)
    
    if [[ ! -d "$source_folder" ]]; then
        echo_error "ProPresenter source folder not accessible: $source_folder"
        return 1
    fi
    
    echo_success "Normalized source folder: $source_folder"
    echo "$(date): $SYMLINK_LOG_PREFIX Normalized source folder: $source_folder" >> "$LOG_FILE"
    
    # Export the normalized source path
    export PROPRESENTER_SOURCE_PATH="$source_folder"
    return 0
}

# =============================================================================
# Symlink Conflict Resolution
# =============================================================================

# Function to resolve symlink conflicts
resolve_symlink_conflicts() {
    local target_path="$1"
    
    if [[ ! -e "$target_path" ]]; then
        # Path doesn't exist, no conflict
        return 0
    fi
    
    echo_info "Resolving conflict at: $target_path"
    echo "$(date): $SYMLINK_LOG_PREFIX Resolving conflict at: $target_path" >> "$LOG_FILE"
    
    if [[ -L "$target_path" ]]; then
        # It's a symlink - check if it's broken or pointing to wrong location
        if [[ ! -e "$target_path" ]]; then
            echo_info "Removing broken symlink: $target_path"
            rm "$target_path"
            return 0
        else
            local current_target
            current_target=$(readlink "$target_path")
            echo_info "Existing symlink points to: $current_target"
            
            # Ask user if they want to replace the existing symlink
            local dialog_message="Symlink Conflict Resolution

A symlink already exists at:
$target_path

Current target: $current_target

This symlink needs to be updated to point to the correct OneDrive SharePoint location for ProPresenter compatibility.

Replace the existing symlink?"

            if show_confirmation_dialog "Symlink Conflict" "$dialog_message"; then
                echo_info "User confirmed symlink replacement"
                rm "$target_path"
                return 0
            else
                echo_warning "User cancelled symlink replacement"
                return 1
            fi
        fi
    elif [[ -d "$target_path" ]]; then
        # It's a directory - ask user about replacement
        local dialog_message="Directory Conflict Resolution

A directory already exists at:
$target_path

This location needs to be a symlink pointing to your OneDrive SharePoint folder for ProPresenter compatibility.

Replace the existing directory with a symlink?"

        if show_confirmation_dialog "Directory Conflict" "$dialog_message"; then
            echo_info "User confirmed directory replacement"
            # Create backup of existing directory
            local backup_path="${target_path}_backup_$(date +%Y%m%d_%H%M%S)"
            mv "$target_path" "$backup_path"
            echo_info "Existing directory backed up to: $backup_path"
            echo "$(date): $SYMLINK_LOG_PREFIX Directory backed up to: $backup_path" >> "$LOG_FILE"
            return 0
        else
            echo_warning "User cancelled directory replacement"
            return 1
        fi
    else
        # It's a file - ask user about replacement
        local dialog_message="File Conflict Resolution

A file already exists at:
$target_path

This location needs to be a symlink pointing to your OneDrive SharePoint folder for ProPresenter compatibility.

Replace the existing file with a symlink?"

        if show_confirmation_dialog "File Conflict" "$dialog_message"; then
            echo_info "User confirmed file replacement"
            # Create backup of existing file
            local backup_path="${target_path}_backup_$(date +%Y%m%d_%H%M%S)"
            mv "$target_path" "$backup_path"
            echo_info "Existing file backed up to: $backup_path"
            echo "$(date): $SYMLINK_LOG_PREFIX File backed up to: $backup_path" >> "$LOG_FILE"
            return 0
        else
            echo_warning "User cancelled file replacement"
            return 1
        fi
    fi
}

# =============================================================================
# Symlink Structure Creation
# =============================================================================

# Function to create standardized symlink structure
create_symlink_structure() {
    local source_base="$1"
    
    if [[ -z "$source_base" || ! -d "$source_base" ]]; then
        echo_error "Invalid source base path: $source_base"
        return 1
    fi
    
    echo_info "Creating standardized symlink structure..."
    echo_info "Source: $source_base"
    echo_info "Target: $SYMLINK_TARGET_BASE"
    echo "$(date): $SYMLINK_LOG_PREFIX Creating symlink structure from $source_base to $SYMLINK_TARGET_BASE" >> "$LOG_FILE"
    
    # Create target base directory if it doesn't exist
    if [[ ! -d "$SYMLINK_TARGET_BASE" ]]; then
        echo_info "Creating target base directory: $SYMLINK_TARGET_BASE"
        mkdir -p "$SYMLINK_TARGET_BASE"
        if [[ $? -ne 0 ]]; then
            echo_error "Failed to create target base directory"
            return 1
        fi
    fi
    
    # Create symlinks for each mapped folder
    local created_symlinks=0
    local failed_symlinks=0
    
    for mapping in "${FOLDER_MAPPINGS[@]}"; do
        local source_folder="${mapping%%:*}"
        local target_folder="${mapping##*:}"
        local source_path="$source_base/$source_folder"
        local target_path="$SYMLINK_TARGET_BASE/$target_folder"
        
        echo_info "Processing: $source_folder → $target_folder"
        
        # Check if source folder exists
        if [[ ! -d "$source_path" ]]; then
            echo_warning "Source folder not found: $source_path"
            echo_info "Skipping symlink creation for: $target_folder"
            continue
        fi
        
        # Resolve any conflicts at target path
        if ! resolve_symlink_conflicts "$target_path"; then
            echo_error "Failed to resolve conflicts for: $target_path"
            ((failed_symlinks++))
            continue
        fi
        
        # Create the symlink
        echo_info "Creating symlink: $target_path → $source_path"
        if ln -s "$source_path" "$target_path"; then
            echo_success "Created symlink: $target_folder"
            echo "$(date): $SYMLINK_LOG_PREFIX Created symlink: $target_path → $source_path" >> "$LOG_FILE"
            ((created_symlinks++))
        else
            echo_error "Failed to create symlink: $target_path"
            echo "$(date): $SYMLINK_LOG_PREFIX Failed to create symlink: $target_path" >> "$LOG_FILE"
            ((failed_symlinks++))
        fi
    done
    
    # Report results
    echo ""
    echo_info "Symlink creation results:"
    echo_info "Created: $created_symlinks symlinks"
    if [[ $failed_symlinks -gt 0 ]]; then
        echo_warning "Failed: $failed_symlinks symlinks"
    fi
    
    if [[ $created_symlinks -gt 0 && $failed_symlinks -eq 0 ]]; then
        echo_success "All symlinks created successfully"
        return 0
    elif [[ $created_symlinks -gt 0 ]]; then
        echo_warning "Some symlinks created with failures"
        return 1
    else
        echo_error "No symlinks were created"
        return 1
    fi
}

# =============================================================================
# Symlink Verification
# =============================================================================

# Function to verify symlink integrity
verify_symlink_integrity() {
    echo_info "Verifying symlink integrity..."
    echo "$(date): $SYMLINK_LOG_PREFIX Starting symlink integrity verification" >> "$LOG_FILE"
    
    if [[ ! -d "$SYMLINK_TARGET_BASE" ]]; then
        echo_error "Target base directory does not exist: $SYMLINK_TARGET_BASE"
        return 1
    fi
    
    local verified_symlinks=0
    local broken_symlinks=0
    local missing_symlinks=0
    
    # Check each expected symlink
    for mapping in "${FOLDER_MAPPINGS[@]}"; do
        local source_folder="${mapping%%:*}"
        local target_folder="${mapping##*:}"
        local target_path="$SYMLINK_TARGET_BASE/$target_folder"
        
        echo_info "Verifying: $target_folder"
        
        if [[ ! -e "$target_path" ]]; then
            echo_warning "Missing symlink: $target_path"
            ((missing_symlinks++))
            continue
        fi
        
        if [[ ! -L "$target_path" ]]; then
            echo_warning "Not a symlink: $target_path"
            continue
        fi
        
        # Check if symlink target exists and is accessible
        if [[ ! -e "$target_path" ]]; then
            echo_error "Broken symlink: $target_path"
            ((broken_symlinks++))
            continue
        fi
        
        # Verify symlink points to correct location
        local link_target
        link_target=$(readlink "$target_path")
        if [[ -d "$link_target" ]]; then
            echo_success "Valid symlink: $target_folder → $link_target"
            echo "$(date): $SYMLINK_LOG_PREFIX Verified symlink: $target_path → $link_target" >> "$LOG_FILE"
            ((verified_symlinks++))
        else
            echo_error "Symlink target not accessible: $link_target"
            ((broken_symlinks++))
        fi
    done
    
    # Report verification results
    echo ""
    echo_info "Symlink verification results:"
    echo_info "Verified: $verified_symlinks symlinks"
    if [[ $missing_symlinks -gt 0 ]]; then
        echo_warning "Missing: $missing_symlinks symlinks"
    fi
    if [[ $broken_symlinks -gt 0 ]]; then
        echo_error "Broken: $broken_symlinks symlinks"
    fi
    
    if [[ $verified_symlinks -gt 0 && $broken_symlinks -eq 0 && $missing_symlinks -eq 0 ]]; then
        echo_success "All symlinks verified successfully"
        return 0
    else
        echo_warning "Symlink verification completed with issues"
        return 1
    fi
}

# Function to cleanup broken or outdated symlinks
cleanup_broken_symlinks() {
    echo_info "Cleaning up broken symlinks..."
    echo "$(date): $SYMLINK_LOG_PREFIX Starting broken symlink cleanup" >> "$LOG_FILE"
    
    if [[ ! -d "$SYMLINK_TARGET_BASE" ]]; then
        echo_info "Target base directory does not exist, nothing to clean"
        return 0
    fi
    
    local cleaned_count=0
    
    # Find and remove broken symlinks in target directory
    while IFS= read -r -d '' symlink; do
        if [[ -L "$symlink" && ! -e "$symlink" ]]; then
            echo_info "Removing broken symlink: $symlink"
            rm "$symlink"
            if [[ $? -eq 0 ]]; then
                ((cleaned_count++))
                echo "$(date): $SYMLINK_LOG_PREFIX Removed broken symlink: $symlink" >> "$LOG_FILE"
            fi
        fi
    done < <(find "$SYMLINK_TARGET_BASE" -type l -print0 2>/dev/null)
    
    if [[ $cleaned_count -gt 0 ]]; then
        echo_success "Cleaned up $cleaned_count broken symlinks"
    else
        echo_info "No broken symlinks found"
    fi
    
    return 0
}

# =============================================================================
# Main Symlink Management
# =============================================================================

# Main function to manage symlink creation and path normalization
manage_symlink_creation() {
    echo_header "Symlink Creation and Path Normalization"
    echo "$(date): $SYMLINK_LOG_PREFIX Starting symlink creation and path normalization" >> "$LOG_FILE"
    
    # Step 1: Detect OneDrive paths
    echo_step "Detecting OneDrive sync locations"
    if ! detect_onedrive_paths; then
        echo_error "Failed to detect OneDrive paths"
        return 1
    fi
    
    echo ""
    
    # Step 2: Normalize folder paths
    echo_step "Normalizing folder paths"
    if ! normalize_folder_paths "$ONEDRIVE_BASE_PATH"; then
        echo_error "Failed to normalize folder paths"
        return 1
    fi
    
    echo ""
    
    # Step 3: Clean up any existing broken symlinks
    echo_step "Cleaning up broken symlinks"
    cleanup_broken_symlinks
    
    echo ""
    
    # Step 4: Create standardized symlink structure
    echo_step "Creating standardized symlink structure"
    if ! create_symlink_structure "$PROPRESENTER_SOURCE_PATH"; then
        echo_error "Failed to create symlink structure"
        return 1
    fi
    
    echo ""
    
    # Step 5: Verify symlink integrity
    echo_step "Verifying symlink integrity"
    if ! verify_symlink_integrity; then
        echo_warning "Symlink verification completed with issues"
        # Continue anyway - some symlinks may still work
    fi
    
    echo ""
    echo_success "Symlink creation and path normalization completed"
    echo_info "Standardized folder structure: $SYMLINK_TARGET_BASE"
    echo_info "Source folder: $PROPRESENTER_SOURCE_PATH"
    echo_info "ProPresenter can now use consistent paths across all machines"
    echo "$(date): $SYMLINK_LOG_PREFIX Symlink creation and path normalization completed successfully" >> "$LOG_FILE"
    
    return 0
}