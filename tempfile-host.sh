#!/usr/bin/env bash
#===============================================================================
#
#          FILE: tempfile-host.sh
#
#         USAGE: ./tempfile-host.sh <path_to_file>
#                echo "some text" | ./tempfile-host.sh
#
#   DESCRIPTION: A command-line utility to quickly upload files or piped data
#                to the 0x0.st file hosting service. It provides user-friendly
#                output, clipboard integration, and a history log.
#
#       OPTIONS: n/a
#  REQUIREMENTS: bash, curl
#                Optional: xclip (X11), wl-copy (Wayland), notify-send
#          BUGS: n/a
#         NOTES: 0x0.st is a public, ephemeral file hosting service. Files may
#                be deleted after a period of inactivity (e.g., 30-365 days).
#        AUTHOR: User-provided script (Refactored and commented by AI)
#       CREATED: 2024-05-27
#       VERSION: 1.0
#      REVISION: Removed all original comments and generated new, comprehensive
#                English comments and a standardized header.
#
#===============================================================================

# --- Strict Mode ---
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last
#              command to exit with a non-zero status, or zero if no
#              command exited with a non-zero status.
set -euo pipefail

#===============================================================================
# CONSTANTS AND CONFIGURATION
#===============================================================================

# The URL of the file hosting service.
readonly SERVICE_URL="https://0x0.st"
# The User-Agent string to be sent with the HTTP request.
readonly USER_AGENT="tempfile-host-script/2.2"
# The maximum allowed file size in Megabytes.
readonly MAX_SIZE_MB=512
# The maximum allowed file size converted to bytes for comparison.
readonly MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
# The directory for storing configuration and history.
readonly CONFIG_DIR="${HOME}/.config/tempfile-host"
# The file to log all successful uploads.
readonly HISTORY_FILE="${CONFIG_DIR}/history.log"

# Global variables that will be modified during script execution.
INPUT_FILE_PATH="" # Path to the file to be uploaded (can be a temp file).
DISPLAY_NAME=""    # Name of the file/source shown to the user (e.g., "myfile.txt" or "(stdin)").
TEMP_FILE=""       # Path to a temporary file, used only when reading from stdin.

#===============================================================================
# COLORS AND FORMATTING
#===============================================================================

# Check if the terminal supports colors. If so, define color codes.
# Otherwise, use empty strings for graceful degradation.
if tput setaf 1 &>/dev/null; then
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    GREEN=""
    RED=""
    YELLOW=""
    CYAN=""
    BOLD=""
    RESET=""
fi
# Make color variables read-only to prevent accidental modification.
readonly GREEN RED YELLOW CYAN BOLD RESET


#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Prints a formatted error message to stderr and exits the script.
# Globals:
#   RED, BOLD, RESET
# Arguments:
#   $1: The error message to display.
function die() {
    echo "${RED}${BOLD}ERROR:${RESET} ${1}" >&2
    exit 1
}

# Checks for the presence of required external commands.
# Calls `die` if a dependency is not found.
function check_dependencies() {
    if ! command -v curl &>/dev/null; then
        die "'curl' not found. Please install it to continue."
    fi
}

# Displays the correct usage syntax for the script.
function print_usage() {
    echo "${BOLD}Usage:${RESET}"
    echo "  $0 <file_path>"
    echo "  or"
    echo "  echo \"text\" | $0"
}

# Cleans up temporary files. Designed to be called by `trap` on exit.
# Globals:
#   TEMP_FILE
function cleanup() {
    # If the TEMP_FILE variable was set, remove the corresponding file.
    if [[ -n "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
    fi
}


#===============================================================================
# CORE LOGIC FUNCTIONS
#===============================================================================

# Determines the source of the input (file argument or stdin) and sets globals.
# Globals:
#   INPUT_FILE_PATH, DISPLAY_NAME, TEMP_FILE
# Arguments:
#   $@: The script's command-line arguments.
function parse_input() {
    if [ $# -gt 0 ]; then
        # Case 1: A command-line argument is provided. Assume it's a file path.
        INPUT_FILE_PATH="$1"
        DISPLAY_NAME="$1"
        # Verify that the file actually exists and is a regular file.
        [ -f "$INPUT_FILE_PATH" ] || die "File '$INPUT_FILE_PATH' not found."
    elif ! [ -t 0 ]; then
        # Case 2: No arguments, and stdin is not a terminal (i.e., data is being piped).
        DISPLAY_NAME="(stdin)"
        # Create a temporary file to store the piped data.
        TEMP_FILE=$(mktemp)
        INPUT_FILE_PATH="$TEMP_FILE"
        # Read all data from stdin and write it to the temporary file.
        cat >"$INPUT_FILE_PATH"
    else
        # Case 3: No arguments and no piped data. Show usage and exit.
        print_usage
        exit 1
    fi
}

# Validates that the input file does not exceed the maximum allowed size.
# Note: This check is currently only performed for direct file arguments,
# not for data piped from stdin, due to the `[[ -z "$TEMP_FILE" ]]` condition.
# Globals:
#   INPUT_FILE_PATH, MAX_SIZE_BYTES, MAX_SIZE_MB, TEMP_FILE
function validate_file_size() {
    if [[ -z "$TEMP_FILE" ]]; then
        local file_size
        file_size=$(stat -c%s "$INPUT_FILE_PATH")
        if (( file_size > MAX_SIZE_BYTES )); then
            local file_size_mb=$((file_size / 1024 / 1024))
            die "File is too large (${file_size_mb} MiB). The limit is ${MAX_SIZE_MB} MiB."
        fi
    fi
}

# Performs the file upload using curl and returns the resulting URL.
# This function is designed to be silent on success, outputting only the URL.
# Globals:
#   USER_AGENT, INPUT_FILE_PATH, SERVICE_URL
# Returns:
#   The URL of the uploaded file on stdout if successful.
function perform_upload() {
    local server_response
    # -sS: Be silent, but show errors.
    # -A: Set the User-Agent header.
    # -F: Submit multipart/form-data, sending the file.
    server_response=$(curl -sS -A "$USER_AGENT" -F "file=@${INPUT_FILE_PATH}" "${SERVICE_URL}")

    # Check if the server response is a valid-looking URL.
    if [[ "$server_response" =~ ^https?:// ]]; then
        echo "$server_response" # The only output is the URL for command substitution.
    else
        die "Upload failed. Server response: ${server_response}"
    fi
}

# Handles all post-upload tasks for a successful upload.
# Arguments:
#   $1: The URL of the uploaded file.
#   $2: The display name of the source (file or stdin).
function process_successful_upload() {
    local upload_url="$1"
    local source_name="$2"

    # Print success messages to the user.
    echo
    echo "${GREEN}${BOLD}✔ Upload complete!${RESET}"
    echo "  ${BOLD}Link:${RESET} ${GREEN}${upload_url}${RESET}"
    echo
    echo "${CYAN}ℹ️  Note: Files on 0x0.st may be removed at any time (typically after 30-365 days of no access).${RESET}"

    # Attempt to copy the URL to the system clipboard.
    if command -v wl-copy &>/dev/null; then
        echo -n "$upload_url" | wl-copy
        echo "${YELLOW}📋 Link copied to clipboard (Wayland).${RESET}"
    elif command -v xclip &>/dev/null; then
        echo -n "$upload_url" | xclip -selection clipboard
        echo "${YELLOW}📋 Link copied to clipboard (X11).${RESET}"
    fi

    # If available, send a desktop notification.
    if command -v notify-send &>/dev/null; then
        notify-send "Upload Complete" "The link has been copied:\n${upload_url}" -i "network-transmit-receive"
    fi

    # Log the successful upload to the history file.
    log_to_history "$source_name" "$upload_url"
}

# Appends a record of the upload to the history file.
# Globals:
#   CONFIG_DIR, HISTORY_FILE
# Arguments:
#   $1: The display name of the source.
#   $2: The URL of the uploaded file.
function log_to_history() {
    local source_name="$1"
    local upload_url="$2"
    local timestamp

    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    # Create the config directory if it doesn't exist.
    mkdir -p "$CONFIG_DIR"
    # Append the log entry to the history file.
    echo "[$timestamp] ${source_name} -> ${upload_url}" >>"$HISTORY_FILE"
    echo "${YELLOW}📜 Link saved to:${RESET} ${HISTORY_FILE}"
}


#===============================================================================
# MAIN FUNCTION (ORCHESTRATOR)
#===============================================================================

# The main function that controls the script's execution flow.
# Arguments:
#   $@: The script's command-line arguments, which are passed on.
function main() {
    # Register the cleanup function to run on any script exit.
    trap cleanup EXIT

    # --- Execution Flow ---
    check_dependencies
    parse_input "$@"
    validate_file_size
    
    # Display status messages to the user.
    echo "${YELLOW}▶ Sending ${DISPLAY_NAME}...${RESET}"
    echo "${YELLOW}📤 Uploading to ${SERVICE_URL}...${RESET}"

    # Capture the output of perform_upload (the URL) into a variable.
    local upload_url
    upload_url=$(perform_upload)
    
    # Process the result of the successful upload.
    process_successful_upload "$upload_url" "$DISPLAY_NAME"
}

# Execute the main function, passing all script arguments to it.
main "$@"