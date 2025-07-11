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

# Loop through all executable files in the directory
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
