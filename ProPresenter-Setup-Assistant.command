#!/bin/bash

# ProPresenter OneDrive Setup Assistant
# Version: Read from VERSION file
# Description: Self-updating macOS script that automates ProPresenter configuration with OneDrive sync

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script metadata
# Read version from VERSION file
SCRIPT_VERSION=$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")
SCRIPT_NAME="ProPresenter OneDrive Setup Assistant"
SCRIPT_AUTHOR="Mosaikkirche Berlin e.V."

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/setup-assistant.log"
TOTAL_STEPS=11
CURRENT_STEP=0

# Environment configuration variables (will be loaded from environment.md)
TENANT_ID=""
TENANT_DOMAIN=""
SHAREPOINT_BASE_URL=""
GITHUB_REPO=""
GITHUB_API_URL=""
PROPRESENTER_VERSION=""

# UI Helper Functions
echo_header() {
    clear
    
    # Calculate the width needed for the longest line
    local title_line="$SCRIPT_NAME"
    local version_line="Version $SCRIPT_VERSION"
    
    # Find the longest line
    local max_length=${#title_line}
    if [[ ${#version_line} -gt $max_length ]]; then
        max_length=${#version_line}
    fi
    
    # Add padding for a nice border (minimum 4 spaces on each side)
    local total_width=$((max_length + 8))
    
    # Ensure minimum width for aesthetics
    if [[ $total_width -lt 60 ]]; then
        total_width=60
    fi
    
    # Calculate padding for centering text
    local title_padding=$(( (total_width - ${#title_line}) / 2 ))
    local version_padding=$(( (total_width - ${#version_line}) / 2 ))
    
    # Create the border characters
    local border_chars=""
    for ((i=0; i<total_width; i++)); do
        border_chars+="═"
    done
    
    # Create padding strings
    local title_spaces=""
    local version_spaces=""
    for ((i=0; i<title_padding; i++)); do
        title_spaces+=" "
    done
    for ((i=0; i<version_padding; i++)); do
        version_spaces+=" "
    done
    
    # Handle odd/even width differences for perfect centering
    local title_end_spaces="$title_spaces"
    local version_end_spaces="$version_spaces"
    if [[ $(( (total_width - ${#title_line}) % 2 )) -eq 1 ]]; then
        title_end_spaces+=" "
    fi
    if [[ $(( (total_width - ${#version_line}) % 2 )) -eq 1 ]]; then
        version_end_spaces+=" "
    fi
    
    # Display the header
    echo -e "${CYAN}╔${border_chars}╗${NC}"
    echo -e "${CYAN}║${title_spaces}${SCRIPT_NAME}${title_end_spaces}║${NC}"
    echo -e "${CYAN}║${version_spaces}Version ${SCRIPT_VERSION}${version_end_spaces}║${NC}"
    echo -e "${CYAN}╚${border_chars}╝${NC}"
    echo ""
}

echo_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BLUE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}]${NC} $1"
}

echo_status() {
    echo -e "${CYAN}ℹ${NC} $1"
}

echo_info() {
    echo "$1"
}

echo_important() {
    echo -e "${GREEN}ATTENTION:${NC} $1"
}

echo_success() {
    echo -e "✅${NC} $1"
}

echo_error() {
    echo -e "❌${NC} $1"
    echo "$(date): ERROR: $1" >> "${LOG_FILE}"
}

echo_warning() {
    echo -e "⚠️${NC} $1"
    echo "$(date): WARNING: $1" >> "${LOG_FILE}"
}

echo_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %d%% - %s${NC}" $percent "$message"
}

# Load environment configuration from docs/app-design/environment.md
load_environment_config() {
    local env_file="${SCRIPT_DIR}/docs/app-design/environment.md"
    
    if [[ ! -f "$env_file" ]]; then
        echo_error "Environment configuration file not found: $env_file"
        return 1
    fi
    
    echo_status "Loading environment configuration..."
    
    # Parse environment configuration using grep and sed
    TENANT_ID=$(grep "Tenant ID" "$env_file" | sed 's/.*`\([^`]*\)`.*/\1/')
    TENANT_DOMAIN=$(grep "Tenant Domain" "$env_file" | sed 's/.*`\([^`]*\)`.*/\1/')
    SHAREPOINT_BASE_URL=$(grep "SharePoint Base URL" "$env_file" | sed 's/.*`\([^`]*\)`.*/\1/')
    GITHUB_REPO=$(grep "Repository" "$env_file" | sed 's/.*`\([^`]*\)`.*/\1/')
    GITHUB_API_URL=$(grep "GitHub API URL" "$env_file" | sed 's/.*`\([^`]*\)`.*/\1/')
    PROPRESENTER_VERSION=$(grep "Target ProPresenter Version" "$env_file" | sed 's/.*`\([^`]*\)`.*/\1/')
    
    # Validate required configuration
    if [[ -z "$TENANT_ID" || -z "$TENANT_DOMAIN" || -z "$SHAREPOINT_BASE_URL" ]]; then
        echo_error "Missing required environment configuration"
        return 1
    fi
    
    echo_success "Environment configuration loaded successfully"
    return 0
}

# User confirmation dialog using native macOS osascript
show_confirmation_dialog() {
    local title="$1"
    local message="$2"
    
    local result
    result=$(osascript -e "display dialog \"$message\" with title \"$title\" buttons {\"Cancel\", \"Continue\"} default button \"Continue\" with icon note")
    
    if [[ $? -eq 0 ]] && [[ "$result" == *"Continue"* ]]; then
        return 0
    else
        return 1
    fi
}

# Step-specific dialog with step numbering
show_step_dialog() {
    local step_number="$1"
    local step_title="$2"
    local message="$3"
    local dialog_title="Step $step_number: $step_title"
    
    local result
    result=$(osascript -e "display dialog \"$message\" with title \"$dialog_title\" buttons {\"Cancel\", \"Continue\"} default button \"Continue\" with icon note")
    
    if [[ $? -eq 0 ]] && [[ "$result" == *"Continue"* ]]; then
        return 0
    else
        return 1
    fi
}

# Information dialog for step instructions
show_step_info_dialog() {
    local step_number="$1"
    local step_title="$2"
    local message="$3"
    local dialog_title="Step $step_number: $step_title"
    
    osascript -e "display dialog \"$message\" with title \"$dialog_title\" buttons {\"OK\"} default button \"OK\" with icon note"
}

# Graceful exit handling with cleanup
cleanup_and_exit() {
    local exit_code=$1
    local exit_reason=${2:-""}
    
    echo ""
    echo_status "Cleaning up temporary files..."
    
    # Add cleanup logic here as needed
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ "$exit_reason" == "cancelled" ]]; then
            echo_status "Setup cancelled by user"
            # Exit immediately for cancellation, no need to wait for keypress
            exit $exit_code
        else
            echo_success "Setup completed successfully!"
            echo ""
            echo_status "Press any key to exit..."
            read -n 1 -s
        fi
    else
        echo_error "Setup exited with errors. Check log file: $LOG_FILE"
        echo ""
        echo_status "Press any key to exit..."
        read -n 1 -s
    fi
    
    exit $exit_code
}

# Signal handlers for graceful exit
trap 'cleanup_and_exit 1' INT TERM

# Welcome screen and user confirmation
show_welcome_screen() {
    echo_header
    
    # Show welcome dialog with the four main steps
    local welcome_message="Welcome! This tool will help you set up ProPresenter, OneDrive, and the sync configuration in order to prepare or operate slides for Mosaik Berlin events.

SETUP PROCESS OVERVIEW:
The assistant will guide you through these four main steps:

1. Validating ProPresenter installation
   • Check if ProPresenter version 7.12 is installed
   • Install or update ProPresenter if needed

2. Validating OneDrive installation and authorization
   • Ensure OneDrive is installed and running
   • Set up authentication with Mosaik Berlin account

3. Synchronizing relevant ProPresenter libraries
   • Connect to Mosaik Berlin SharePoint folders
   • Set up local sync folders for ProPresenter assets

4. Adjusting ProPresenter settings
   • Configure ProPresenter to use synced folders
   • Set up proper file paths and preferences

Are you ready to start the setup process?"
    
    if ! show_confirmation_dialog "$SCRIPT_NAME" "$welcome_message"; then
        echo_warning "Setup cancelled by user"
        cleanup_and_exit 0 "cancelled"
    fi
    
    echo_success "Setup confirmed by user"
}

# Main script execution
main() {
    # Ensure logs directory exists
    mkdir -p "${LOG_DIR}"
    
    # Initialize log file
    echo "$(date): Starting ProPresenter Setup Assistant v${SCRIPT_VERSION}" > "${LOG_FILE}"
    
    # Load environment configuration
    if ! load_environment_config; then
        cleanup_and_exit 1
    fi
    
    # Check for updates before starting main process
    # Note: Update checking will work once repository is public and has releases
    initialize_update_check "$@"
    
    # Show welcome screen and get user confirmation
    show_welcome_screen
    
    echo ""
    echo_step "Initializing setup process..."
    echo_status "Script version: ${SCRIPT_VERSION}"
    echo_status "Log file: ${LOG_FILE}"
    echo_status "Working directory: ${SCRIPT_DIR}"
    
    # Step 4: ProPresenter Version Management
    echo ""
    echo_step "Managing ProPresenter version..."
    if ! manage_propresenter_version "$PROPRESENTER_VERSION"; then
        echo_error "ProPresenter version management failed"
        cleanup_and_exit 1
    fi
    
    # Step 5: OneDrive Detection and Authentication
    echo ""
    echo_step "Managing OneDrive authentication..."
    if ! manage_onedrive_authentication "$TENANT_ID" "$TENANT_DOMAIN"; then
        echo_error "OneDrive authentication failed"
        cleanup_and_exit 1
    fi
    
    # Placeholder for future implementation steps
    echo ""
    echo_status "OneDrive authentication completed successfully!"
    echo_warning "Additional setup steps will be implemented in future versions."
    
    # Success completion
    cleanup_and_exit 0
}

# Source self-update module
source "${SCRIPT_DIR}/lib/self-update.sh"

# Source ProPresenter version management module
source "${SCRIPT_DIR}/lib/propresenter-version.sh"

# Source OneDrive authentication module
source "${SCRIPT_DIR}/lib/onedrive-auth.sh"

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi