#!/usr/bin/env bash
#===============================================================================
#
#          FILE: tempfile-host-gui.sh
#
#         USAGE: ./tempfile-host-gui.sh
#
#   DESCRIPTION: A graphical user interface (GUI) using Zenity for the
#                tempfile-host script. It allows users to select a file
#                via a dialog and upload it to the 0x0.st service.
#
#       OPTIONS: n/a
#  REQUIREMENTS: bash, curl, zenity
#          BUGS: n/a
#         NOTES: 0x0.st is a public, ephemeral file hosting service. Files may
#                be deleted after a period of inactivity.
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
#              command to exit with a non-zero status.
set -euo pipefail

#===============================================================================
# CONSTANTS AND CONFIGURATION
#===============================================================================

# The URL of the file hosting service.
readonly SERVICE_URL="https://0x0.st"
# The User-Agent string to be sent with the HTTP request.
readonly USER_AGENT="tempfile-host-gui/2.0"
# The maximum allowed file size in Megabytes.
readonly MAX_SIZE_MB=512
# The maximum allowed file size converted to bytes for comparison.
readonly MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
# The directory for storing configuration and history.
readonly CONFIG_DIR="${HOME}/.config/tempfile-host"
# The file to log all successful uploads.
readonly HISTORY_FILE="${CONFIG_DIR}/history.log"

# Global state variable for the progress window's Process ID (PID).
# This must be global so that the `cleanup` function, which is called via
# `trap`, can access it to kill the process from any scope upon script exit.
ZENITY_PID=""


#===============================================================================
# UTILITY AND LOGIC FUNCTIONS
#===============================================================================

# Checks if all required command-line dependencies (curl, zenity) are installed.
# Exits with an error if any dependency is missing.
function check_dependencies() {
    local missing_dep=""
    if ! command -v curl &>/dev/null; then missing_dep="curl"; fi
    if ! command -v zenity &>/dev/null; then missing_dep="zenity"; fi

    if [[ -n "$missing_dep" ]]; then
        # If zenity is available, use it to show the error. Otherwise, fall back
        # to printing the error to the console.
        if command -v zenity &>/dev/null; then
            zenity --error --text="Dependency '${missing_dep}' not found.\nPlease install it to continue." --width=300
        else
            echo "ERROR: Dependency '${missing_dep}' not found." >&2
        fi
        exit 1
    fi
}

# Appends a record of the upload to the history file.
# Arguments:
#   $1: The name of the source file.
#   $2: The URL of the uploaded file.
function log_to_history() {
    local source_name="$1"
    local upload_url="$2"
    # Create the config directory if it does not already exist.
    mkdir -p "$CONFIG_DIR"
    # Append the log entry, marking it as a GUI upload.
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] (GUI) ${source_name} -> ${upload_url}" >>"$HISTORY_FILE"
}

# Copies the provided text to the system clipboard.
# It automatically detects whether to use the Wayland (wl-copy) or X11 (xclip) tool.
# Arguments:
#   $1: The text to be copied to the clipboard.
function copy_to_clipboard() {
    local text_to_copy="$1"
    if command -v wl-copy &>/dev/null; then
        echo -n "$text_to_copy" | wl-copy
    elif command -v xclip &>/dev/null; then
        echo -n "$text_to_copy" | xclip -selection clipboard
    fi
}

# Cleanup function called by `trap` to ensure the Zenity progress window is
# closed under all exit scenarios (success, error, or user interrupt).
# Globals:
#   ZENITY_PID
function cleanup() {
    # Only attempt to kill the process if the ZENITY_PID variable is not empty.
    if [[ -n "$ZENITY_PID" ]]; then
        # The `|| true` prevents the script from exiting with an error if the
        # process with the given PID no longer exists.
        kill "$ZENITY_PID" 2>/dev/null || true
    fi
}


#===============================================================================
# GUI INTERACTION FUNCTIONS (ZENITY)
#===============================================================================

# Displays the file selection dialog to the user.
# Returns: The full path of the selected file to stdout.
# Exits gracefully if the user cancels the dialog.
function run_file_selection_dialog() {
    local selected_file
    # Zenity returns a non-zero exit code if the user presses Cancel or closes the window.
    if ! selected_file=$(zenity --file-selection --title="Select a file to upload"); then
        exit 0 # A normal exit, as the user chose to cancel.
    fi
    echo "$selected_file"
}

# Validates the size of the selected file.
# Displays a Zenity error dialog if the file is too large.
# Arguments:
#   $1: The path to the file to validate.
function validate_file_dialog() {
    local file_path="$1"
    local file_size
    file_size=$(stat -c%s "$file_path")

    if (( file_size > MAX_SIZE_BYTES )); then
        local file_size_mb=$((file_size / 1024 / 1024))
        zenity --error \
            --title="Validation Error" \
            --text="The file <b>$(basename "$file_path")</b> is too large (${file_size_mb} MiB).\nThe service limit is ${MAX_SIZE_MB} MiB."
        exit 1
    fi
}

# Performs the upload while showing a pulsating progress bar.
# Arguments:
#   $1: The path to the file to upload.
# Returns: The server's response (either a URL or an error message) to stdout.
function run_upload_with_progress() {
    local file_path="$1"

    # Start the Zenity progress dialog in the background and store its PID
    # in the global variable so it can be killed later by `cleanup`.
    zenity --progress \
        --title="Uploading File" \
        --text="Uploading <b>$(basename "$file_path")</b>...\nPlease wait." \
        --pulsate --auto-close --no-cancel &
    ZENITY_PID=$!

    # Execute the upload. The `|| true` prevents a curl error from triggering
    # `set -e` prematurely, allowing us to capture the error response and
    # display it in a user-friendly graphical dialog.
    local server_response
    server_response=$(curl -sS -A "$USER_AGENT" -F "file=@${file_path}" "${SERVICE_URL}" || true)

    # Immediately kill the progress window once the upload is finished.
    cleanup
    # Reset the PID variable so the final trap on exit doesn't act unnecessarily.
    ZENITY_PID=""

    echo "$server_response"
}

# Displays the final result dialog, for either success or failure.
# Arguments:
#   $1: The server response from the upload attempt.
#   $2: The original filename, used for logging purposes.
function display_result_dialog() {
    local server_response="$1"
    local source_name="$2"

    # Check if the server response is a valid-looking URL.
    if [[ "$server_response" =~ ^https?:// ]]; then
        # Success Case
        local upload_url="$server_response"
        copy_to_clipboard "$upload_url"
        log_to_history "$source_name" "$upload_url"

        zenity --info \
            --title="Upload Complete!" \
            --width=500 \
            --text="File uploaded successfully!\n\n<b>Link:</b> <a href=\"${upload_url}\">${upload_url}</a>\n\nThe link has been copied to your clipboard."
    else
        # Failure Case
        zenity --error \
            --title="Upload Failed" \
            --width=400 \
            --text="An error occurred while trying to upload the file.\n\n<b>Server response:</b>\n${server_response}"
    fi
}


#===============================================================================
# MAIN FUNCTION (ORCHESTRATOR)
#===============================================================================

# The main function that controls the script's execution flow.
function main() {
    # Register the cleanup function to be executed on any script exit condition.
    trap cleanup EXIT

    # --- Execution Flow ---
    check_dependencies

    # Get the file path from the user.
    local file_path
    file_path=$(run_file_selection_dialog)

    # Validate the selected file.
    validate_file_dialog "$file_path"

    # Perform the upload and capture the response.
    local server_response
    server_response=$(run_upload_with_progress "$file_path")

    # Display the final result to the user.
    display_result_dialog "$server_response" "$(basename "$file_path")"
}

# Script entry point.
main