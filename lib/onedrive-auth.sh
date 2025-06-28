#!/bin/bash

# OneDrive Authentication Module
# Main orchestrator for OneDrive authentication management

#=============================================================================
# MAIN ORCHESTRATION FUNCTION
#=============================================================================

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
    
    # Step 1: Ensure OneDrive is installed (using installation module)
    if ! ensure_onedrive_installed; then
        echo_error "Failed to ensure OneDrive installation"
        return 1
    fi
    
    # Step 2: Launch authentication process (using setup module)
    if ! launch_onedrive_authentication "$target_domain"; then
        echo_warning "Initial authentication launch failed, attempting retry..."
        
        if ! handle_authentication_retry; then
            echo_error "OneDrive authentication failed after all retry attempts"
            return 1
        fi
    fi
    
    # Step 3: Verify tenant authentication (using detection module)
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