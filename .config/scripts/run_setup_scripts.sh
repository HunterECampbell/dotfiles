#!/bin/bash

# This script executes other executable setup scripts found in the
# ~/.config/scripts/ directory based on a specified
# setup type (home, work, or all).
# It first sets up essential dotfile directories and symlinks,
# then runs the package installation script, and finally executes
# other specific setup scripts.
# It ensures scripts are executable, captures their exit status, and logs failures.
#
# Usage: ~/.config/scripts/run_setup_scripts.sh [home|work|all]
#   If no argument is provided, or an invalid argument is provided,
#   the script will prompt the user to choose.
#
# IMPORTANT:
# - This master script (run_setup_scripts.sh) itself needs to be made executable
#   manually once after creation: chmod +x ~/.config/scripts/run_setup_scripts.sh
# - This script now handles its own sudo elevation (see "Sudo Elevation Check" below).
# - Any setup script executed by this master script that requires sudo privileges
#   for its commands should *still* handle sudo internally (e.g., by calling 'sudo'
#   for specific commands within that setup script), particularly for commands that
#   need to run as the *target user* (e.g., yay, flatpak).

# --- Sudo Elevation Check ---
# Check if the script is running with root privileges (EUID 0).
# If not, re-execute itself with sudo.
if [[ "$EUID" -ne 0 ]]; then
  echo "This script requires elevated privileges. Attempting to re-run with sudo..."
  # Preserve arguments when re-running with sudo
  exec sudo bash "$0" "$@"
  # The 'exec' command replaces the current shell process with the new one.
  # If sudo fails (e.g., user cancels password prompt), this script will exit.
fi


echo "Starting execution of setup scripts..."
echo "---------------------------------------------------"

# Determine the target user and their home directory.
# SUDO_USER is set by 'sudo' to the original user who invoked sudo.
# If not running via sudo, it defaults to the current user.
# IMPORTANT: When the script re-runs itself with sudo, SUDO_USER will be set
# to the user who initially ran the script (the one whose home directory we want).
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME="/home/$TARGET_USER" # Assuming /home/user for non-root user

echo "Target user for script execution: $TARGET_USER (Home: $TARGET_HOME)"

# Define the directory containing your setup scripts
SCRIPTS_DIR="$TARGET_HOME/.config/scripts" # Pointing to the top-level scripts directory
SETUP_SCRIPTS_DIR="$SCRIPTS_DIR/setup_scripts"
# Define the path to the sibling scripts. The other scripts are now in SETUP_SCRIPTS_DIR
DOWNLOAD_PACKAGES_SCRIPT="$SCRIPTS_DIR/download_packages.sh"

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
LOG_DIR=$(mktemp -d "/tmp/run_setup_scripts_logs.XXXXXX")
echo -e "${YELLOW}Temporary logs for failed scripts will be stored in: ${LOG_DIR}${NC}"

# Function to clean up temporary logs on exit
cleanup_logs() {
  echo -e "${YELLOW}Cleaning up temporary logs from ${LOG_DIR}...${NC}"
  rm -rf "$LOG_DIR"
}
# Register the cleanup function to be called on script exit or interruption
trap cleanup_logs EXIT

echo "---------------------------------------------------"

# --- Setup Type Logic (reused from download_packages.sh) ---
SETUP_TYPE="$1"

# Function to prompt user for setup type
prompt_for_setup_type() {
  local choice=""
  while true; do
    echo "No setup type provided as argument. Please choose an option for script execution:"
    echo "  1) Home"
    echo "  2) Work"
    echo "3) All (Home + Work)"
    echo "  4) EXIT (Do not run any setup scripts)"
    read -p "Enter your choice (1, 2, 3, or 4): " choice

    case "$choice" in
      1) SETUP_TYPE="home"; break ;;
      2) SETUP_TYPE="work"; break ;;
      3) SETUP_TYPE="all"; break ;;
      4) echo "Exiting script as requested."; exit 0 ;;
      *) echo "Invalid choice. Please enter 1, 2, 3, or 4." ;;
    esac
  done
}

# Check if the initial SETUP_TYPE is valid. If not, prompt.
if [[ -z "$SETUP_TYPE" ]] || [[ "$SETUP_TYPE" != "home" && "$SETUP_TYPE" != "work" && "$SETUP_TYPE" != "all" ]]; then
  if [[ -n "$SETUP_TYPE" ]]; then # If an invalid argument was given (not just empty)
    echo "Invalid setup type '$SETUP_TYPE' provided as argument. Falling back to interactive choice."
  fi
  prompt_for_setup_type
fi

echo "Selected setup type: $(echo "$SETUP_TYPE" | tr '[:lower:]' '[:upper:]')"
echo "---------------------------------------------------"

# --- Script Categorization Arrays ---
# These arrays list scripts that are EXCLUSIVE to a setup type.
# Any script not listed here will be considered "common" and run for "home" or "work" if applicable.
# Note: download_packages.sh is a foundational script that will be executed regardless of the selected setup type.

declare -a HOME_ONLY_SCRIPTS=(
  "setup_gaming_ssd.sh"
  "setup_steam.sh"
)
declare -a WORK_ONLY_SCRIPTS=()

# Function to check if a script should be executed based on SETUP_TYPE
should_execute_script() {
  local script_name="$1"
  local execute=true

  # Check if it's a HOME-only script
  for h_script in "${HOME_ONLY_SCRIPTS[@]}"; do
    if [[ "$script_name" == "$h_script" ]]; then
      if [[ "$SETUP_TYPE" != "home" && "$SETUP_TYPE" != "all" ]]; then
        execute=false
      fi
      break # Found it, no need to check further
    fi
  done

  # If already determined not to execute, or if it's a HOME-only script and should execute, no need to check WORK_ONLY
  if [[ "$execute" == "false" ]]; then
    echo -e "${YELLOW}  Skipping $script_name (specific to Home setup, not selected or applicable to 'All').${NC}"
    return 1 # Should not execute
  fi

  # Check if it's a WORK-only script
  for w_script in "${WORK_ONLY_SCRIPTS[@]}"; do
    if [[ "$script_name" == "$w_script" ]]; then
      if [[ "$SETUP_TYPE" != "work" && "$SETUP_TYPE" != "all" ]]; then
        execute=false
      fi
      break # Found it, no need to check further
    fi
  done

  if [[ "$execute" == "false" ]]; then
    echo -e "${YELLOW}  Skipping $script_name (specific to Work setup, not selected or applicable to 'All').${NC}"
    return 1 # Should not execute
  fi

  return 0 # Should execute
}

# --- Set executable permissions recursively ---
echo -e "${YELLOW}Ensuring all scripts in '$SCRIPTS_DIR' are executable recursively...${NC}"
if sudo -u "$TARGET_USER" find "$SCRIPTS_DIR" -type f -print0 | xargs -0 chmod +x; then
    echo -e "${GREEN}Permissions updated successfully.${NC}"
else
    echo -e "${RED}Error setting executable permissions. Subsequent scripts may fail.${NC}"
fi
echo "---------------------------------------------------"

# Function to execute a foundational script and check its status
execute_foundational_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    local script_type="$2" # E.g., "dotfile setup", "package installation"

    echo -e "${YELLOW}Executing foundational script: $script_name for $script_type...${NC}"

    if [ ! -f "$script_path" ] || [ ! -x "$script_path" ]; then
        echo -e "${RED}  ERROR: '$script_path' not found or not executable. Exiting.${NC}"
        FAILED_SCRIPTS+=("$script_name (Error: Not found or not executable)")
        exit 1
    else
        LOG_FILE="$LOG_DIR/$(basename "$script_name" .sh).log"
        echo -e "${YELLOW}  Real-time output and full log for this script: ${LOG_FILE}${NC}"

        # Execute the script as the TARGET_USER. It will handle its own sudo calls.
        sudo -u "$TARGET_USER" "$script_path" 2>&1 | tee "$LOG_FILE"
        exit_status=${PIPESTATUS[0]}

        if [ "$exit_status" -ne 0 ]; then
            echo -e "${RED}  FAILURE: $script_name exited with status $exit_status${NC}"
            local_output=$(cat "$LOG_FILE")
            FAILED_SCRIPTS+=("$script_name (Exit Status: $exit_status)\n${YELLOW}--- Output/Error ---${NC}\n$local_output")
            echo -e "${RED}Critical Error: $script_type failed. Exiting.${NC}"
            echo "---------------------------------------------------"
            exit 1
        else
            echo -e "${GREEN}  SUCCESS: $script_name completed successfully.${NC}"
        fi
    fi
    echo "---------------------------------------------------"
}

# --- Execute Foundational Scripts in Order ---
execute_foundational_script "$DOWNLOAD_PACKAGES_SCRIPT" "package installation" "$SETUP_TYPE" # Pass setup_type to the script


# --- Loop through other setup scripts ---
# The find command now looks in the SETUP_SCRIPTS_DIR and its subdirectories
while read -r script_path; do
    script_name=$(basename "$script_path")

    # Skip this master script itself if it happens to be in the same directory
    if [[ "$script_name" == "run_setup_scripts.sh" ]]; then
        continue
    fi
    # The download_packages.sh script is handled separately as a foundational script.
    if [[ "$script_name" == "download_packages.sh" ]]; then
        continue
    fi

    # Determine if the script should be executed based on the chosen setup type
    if should_execute_script "$script_name"; then
        echo -e "${YELLOW}Executing: $script_name...${NC}"

        LOG_FILE="$LOG_DIR/$(basename "$script_name" .sh).log"
        echo -e "${YELLOW}  Real-time output and full log for this script: ${LOG_FILE}${NC}"

        # Execute the script as the TARGET_USER
        # Each child script is expected to handle its own sudo calls internally
        sudo -u "$TARGET_USER" "$script_path" 2>&1 | tee "$LOG_FILE"
        exit_status=${PIPESTATUS[0]} # Get exit status of the script, not tee

        if [ "$exit_status" -ne 0 ]; then
            echo -e "${RED}  FAILURE: $script_name exited with status $exit_status${NC}"
            local_output=$(cat "$LOG_FILE")
            FAILED_SCRIPTS+=("$script_name (Exit Status: $exit_status)\n${YELLOW}--- Output/Error ---${NC}\n$local_output")
        else
            echo -e "${GREEN}  SUCCESS: $script_name completed successfully.${NC}"
        fi
        echo "---------------------------------------------------"
    fi
done < <(find "$SETUP_SCRIPTS_DIR" -type f -executable | sort)

# Summary of failed scripts
echo -e "\n${GREEN}--- Script Execution Summary ---${NC}"
if [ ${#FAILED_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${GREEN}All applicable scripts executed successfully!${NC}"
else
    echo -e "${RED}The following scripts failed:${NC}"
    for failed_script in "${FAILED_SCRIPTS[@]}"; do
        echo -e "${RED}- $failed_script${NC}"
        echo "---------------------------------------------------" # Separator for each failed script's log
    done
    echo -e "${RED}Please review the full output above for details on why they failed.${NC}"
    exit 1 # Exit with a non-zero status if any script failed
fi

echo -e "${GREEN}Script execution finished.${NC}"
