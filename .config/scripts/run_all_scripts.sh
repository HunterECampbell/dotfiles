#!/bin/bash

# This script executes all other executable scripts found in the
# ~/.config/scripts/child_scripts/ directory. It ensures these scripts
# are executable, captures their exit status, and, if a script fails
# (exits with a non-zero status), it logs the failure along with a
# basic error message. At the end, it provides a summary of all scripts
# that failed, including their captured output.
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
DOWNLOAD_PACKAGES_SCRIPT="$(dirname "$0")/download_packages.sh"

# Array to store failed scripts and their error messages/captured output
# Each element will be formatted as: "Script Name (Exit Status: X)\n--- Output/Error ---\nCaptured Output"
declare -a FAILED_SCRIPTS=()

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Create a temporary directory for script logs
# The XXXX ensures a unique directory is created
LOG_DIR=$(mktemp -d "/tmp/run_all_scripts_logs.XXXXXX")
# Using echo -e here to interpret the color codes
echo -e "${YELLOW}Temporary logs for failed scripts will be stored in: ${LOG_DIR}${NC}"

# Function to clean up temporary logs on exit
cleanup_logs() {
    # Using echo -e here to interpret the color codes
    echo -e "${YELLOW}Cleaning up temporary logs from ${LOG_DIR}...${NC}"
    rm -rf "$LOG_DIR"
}
# Register the cleanup function to be called on script exit or interruption
trap cleanup_logs EXIT

# Using echo -e here to interpret the color codes
echo -e "${GREEN}Starting execution of scripts in $SCRIPTS_DIR...${NC}"
echo "---------------------------------------------------"

# Check if the scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    # Using echo -e here to interpret the color codes
    echo -e "${RED}Error: Script directory '$SCRIPTS_DIR' not found.${NC}"
    echo "Please create the directory and place your scripts there."
    exit 1
fi

# Make all files in the child_scripts directory executable
# Using echo -e here to interpret the color codes
echo -e "${YELLOW}Ensuring all scripts in '$SCRIPTS_DIR' are executable...${NC}"
chmod +x "$SCRIPTS_DIR"/* 2>/dev/null || true # Ignore errors if there are no files or permissions issues
# Using echo -e here to interpret the color codes
echo -e "${GREEN}Permissions updated.${NC}"
echo "---------------------------------------------------"

# --- Execute download_packages.sh first ---
# Using echo -e here to interpret the color codes
echo -e "${YELLOW}Executing: $(basename "$DOWNLOAD_PACKAGES_SCRIPT")...${NC}"

# Ensure download_packages.sh is executable
# Using echo -e here to interpret the color codes
echo -e "${YELLOW}Ensuring '$DOWNLOAD_PACKAGES_SCRIPT' is executable...${NC}"
chmod +x "$DOWNLOAD_PACKAGES_SCRIPT" 2>/dev/null || true # Ignore errors if file doesn't exist yet or permissions issues
# Using echo -e here to interpret the color codes
echo -e "${GREEN}Permissions updated for '$DOWNLOAD_PACKAGES_SCRIPT'.${NC}"

# Check if download_packages.sh exists and is executable
if [ ! -f "$DOWNLOAD_PACKAGES_SCRIPT" ] || [ ! -x "$DOWNLOAD_PACKAGES_SCRIPT" ]; then
    # Using echo -e here to interpret the color codes
    echo -e "${RED}  ERROR: '$DOWNLOAD_PACKAGES_SCRIPT' not found or not executable. Subsequent scripts will fail. Exiting.${NC}"
    FAILED_SCRIPTS+=("$(basename "$DOWNLOAD_PACKAGES_SCRIPT") (Error: Not found or not executable)")
    exit 1
else
    # Define a specific log file for this script's output
    LOG_FILE="$LOG_DIR/$(basename "$DOWNLOAD_PACKAGES_SCRIPT" .sh).log"
    # Using echo -e here to interpret the color codes
    echo -e "${YELLOW}  Real-time output and full log for this script: ${LOG_FILE}${NC}"

    # Execute the script, pipe its stdout and stderr to tee.
    # tee will send it to both stdout (your console) and the LOG_FILE.
    # PIPESTATUS[0] gets the exit status of the first command in the pipe (the script itself).
    "$DOWNLOAD_PACKAGES_SCRIPT" 2>&1 | tee "$LOG_FILE"
    exit_status=${PIPESTATUS[0]}

    if [ "$exit_status" -ne 0 ]; then
        # Using echo -e here to interpret the color codes
        echo -e "${RED}  FAILURE: $(basename "$DOWNLOAD_PACKAGES_SCRIPT") exited with status $exit_status${NC}"
        # Read the full content of the log file for the summary
        local_output=$(cat "$LOG_FILE")
        FAILED_SCRIPTS+=("$(basename "$DOWNLOAD_PACKAGES_SCRIPT") (Exit Status: $exit_status)\n${YELLOW}--- Output/Error ---${NC}\n$local_output")
        # Using echo -e here to interpret the color codes
        echo -e "${RED}Critical Error: download_packages.sh failed. Subsequent scripts will likely fail. Exiting.${NC}"
        echo "---------------------------------------------------"
        exit 1 # Exit immediately if download_packages.sh fails
    else
        # Using echo -e here to interpret the color codes
        echo -e "${GREEN}  SUCCESS: $(basename "$DOWNLOAD_PACKAGES_SCRIPT") completed successfully.${NC}"
    fi
fi
echo "---------------------------------------------------"

# Loop through all other executable files in the child_scripts directory
while read -r script; do
    # Skip this master script itself if it happens to be in the same directory
    # (though it should be in a parent directory)
    if [[ "$(basename "$script")" == "run_all_scripts.sh" ]]; then
        continue
    fi

    # Using echo -e here to interpret the color codes
    echo -e "${YELLOW}Executing: $(basename "$script")...${NC}"

    # Define a specific log file for this script's output
    LOG_FILE="$LOG_DIR/$(basename "$script" .sh).log"
    # Using echo -e here to interpret the color codes
    echo -e "${YELLOW}  Real-time output and full log for this script: ${LOG_FILE}${NC}"

    # Execute the script, pipe its stdout and stderr to tee.
    "$script" 2>&1 | tee "$LOG_FILE"
    exit_status=${PIPESTATUS[0]} # Get exit status of the script, not tee

    if [ "$exit_status" -ne 0 ]; then
        # Using echo -e here to interpret the color codes
        echo -e "${RED}  FAILURE: $(basename "$script") exited with status $exit_status${NC}"
        # Read the full content of the log file for the summary
        local_output=$(cat "$LOG_FILE")
        FAILED_SCRIPTS+=("$(basename "$script") (Exit Status: $exit_status)\n${YELLOW}--- Output/Error ---${NC}\n$local_output")
    else
        # Using echo -e here to interpret the color codes
        echo -e "${GREEN}  SUCCESS: $(basename "$script") completed successfully.${NC}"
    fi
    echo "---------------------------------------------------"
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -executable | sort)

# Summary of failed scripts
# Using echo -e here to interpret the color codes
echo -e "\n${GREEN}--- Script Execution Summary ---${NC}"
if [ ${#FAILED_SCRIPTS[@]} -eq 0 ]; then
    # Using echo -e here to interpret the color codes
    echo -e "${GREEN}All scripts executed successfully!${NC}"
else
    # Using echo -e here to interpret the color codes
    echo -e "${RED}The following scripts failed:${NC}"
    for failed_script in "${FAILED_SCRIPTS[@]}"; do
        # This line was already correct with echo -e for the array content
        echo -e "${RED}- $failed_script${NC}"
        echo "---------------------------------------------------" # Separator for each failed script's log
    done
    # Using echo -e here to interpret the color codes
    echo -e "${RED}Please review the full output above for details on why they failed.${NC}"
    exit 1 # Exit with a non-zero status if any script failed
fi

# Using echo -e here to interpret the color codes
echo -e "${GREEN}Script execution finished.${NC}"