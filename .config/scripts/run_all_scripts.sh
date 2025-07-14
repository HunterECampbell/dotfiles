#!/bin/bash

# This script executes all other executable scripts found in the
# ~/.config/scripts/child_scripts/ directory. It ensures these scripts
# are executable, captures their exit status, and, if a script fails
# (exits with a non-zero status), it logs the failure along with a
# basic error message. At the end, it provides a summary of all scripts
# that failed.
#
# IMPORTANT:
# - This master script (run_all_scripts.sh) itself needs to be made executable
#   manually once after creation: chmod +x ~/.config/scripts/run_all_scripts.sh
# - Any child script executed by this master script that requires sudo privileges
#   for its commands should handle sudo internally (e.g., by calling 'sudo'
#   for specific commands within that child script).
# - This master script is designed to be run as a normal user. For scripts
#   like setup_ufw.sh that perform system-wide changes, it's generally
#   recommended to run them directly with 'sudo' (e.g., sudo ~/.config/scripts/child_scripts/setup_ufw.sh)
#   rather than relying on this script to elevate privileges for them.

# Define the directory containing your child scripts
SCRIPTS_DIR="$HOME/.config/scripts/child_scripts"

# Define the path to the sibling download_packages.sh script
# $(dirname "$0") gets the directory where the current script is located
DOWNLOAD_PACKAGES_SCRIPT="$(dirname "$0")/download_packages.sh"

# Array to store failed scripts and their error messages
declare -a FAILED_SCRIPTS=()

echo "Starting execution of scripts in $SCRIPTS_DIR..."
echo "---------------------------------------------------"

# Check if the scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "Error: Script directory '$SCRIPTS_DIR' not found."
    echo "Please create the directory and place your scripts there."
    exit 1
fi

# Make all files in the child_scripts directory executable
echo "Ensuring all scripts in '$SCRIPTS_DIR' are executable..."
chmod +x "$SCRIPTS_DIR"/* 2>/dev/null || true # Ignore errors if there are no files or permissions issues
echo "Permissions updated."
echo "---------------------------------------------------"

# --- Execute download_packages.sh first ---
echo "Executing: $(basename "$DOWNLOAD_PACKAGES_SCRIPT")..."

# Ensure download_packages.sh is executable
echo "Ensuring '$DOWNLOAD_PACKAGES_SCRIPT' is executable..."
chmod +x "$DOWNLOAD_PACKAGES_SCRIPT" 2>/dev/null || true # Ignore errors if file doesn't exist yet or permissions issues
echo "Permissions updated for '$DOWNLOAD_PACKAGES_SCRIPT'."

# Check if download_packages.sh exists and is executable
if [ ! -f "$DOWNLOAD_PACKAGES_SCRIPT" ] || [ ! -x "$DOWNLOAD_PACKAGES_SCRIPT" ]; then
    echo "  ERROR: '$DOWNLOAD_PACKAGES_SCRIPT' not found or not executable. Subsequent scripts will fail. Exiting."
    FAILED_SCRIPTS+=("$(basename "$DOWNLOAD_PACKAGES_SCRIPT") (Error: Not found or not executable)")
    exit 1
else
    output=$("$DOWNLOAD_PACKAGES_SCRIPT" 2>&1)
    exit_status=$?

    if [ "$exit_status" -ne 0 ]; then
        echo "  FAILURE: $(basename "$DOWNLOAD_PACKAGES_SCRIPT") exited with status $exit_status"
        echo "  Output/Error:"
        echo "$output" | sed 's/^/    /' # Indent output for readability
        FAILED_SCRIPTS+=("$(basename "$DOWNLOAD_PACKAGES_SCRIPT") (Exit Status: $exit_status)")
        echo -e "${RED}Critical Error: download_packages.sh failed. Subsequent scripts will fail. Exiting.${NC}"
        echo "---------------------------------------------------"
        exit 1 # Exit immediately if download_packages.sh fails
    else
        echo "  SUCCESS: $(basename "$DOWNLOAD_PACKAGES_SCRIPT") completed successfully."
    fi
fi
echo "---------------------------------------------------"

# Loop through all other executable files in the child_scripts directory
# Using 'find' to ensure we only execute regular files and they are executable
find "$SCRIPTS_DIR" -maxdepth 1 -type f -executable | sort | while read -r script; do
    # Skip this master script itself if it happens to be in the same directory
    # (though it should be in a parent directory)
    if [[ "$(basename "$script")" == "run_all_scripts.sh" ]]; then
        continue
    fi

    echo "Executing: $(basename "$script")..."
    # Execute the script and capture its output and exit status
    # Redirect stderr to stdout so it's captured by the pipe
    output=$("$script" 2>&1)
    exit_status=$?

    if [ "$exit_status" -ne 0 ]; then
        echo "  FAILURE: $(basename "$script") exited with status $exit_status"
        echo "  Output/Error:"
        echo "$output" | sed 's/^/    /' # Indent output for readability
        FAILED_SCRIPTS+=("$(basename "$script") (Exit Status: $exit_status)")
    else
        echo "  SUCCESS: $(basename "$script") completed successfully."
    fi
    echo "---------------------------------------------------"
done

# Summary of failed scripts
echo -e "\n--- Script Execution Summary ---"
if [ ${#FAILED_SCRIPTS[@]} -eq 0 ]; then
    echo "All scripts executed successfully!"
else
    echo "The following scripts failed:"
    for failed_script in "${FAILED_SCRIPTS[@]}"; do
        echo "  - $failed_script"
    done
    echo "Please review the output above for details on why they failed."
    exit 1 # Exit with a non-zero status if any script failed
fi

echo "Script execution finished."
