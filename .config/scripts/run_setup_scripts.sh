#!/usr/bin/env bash

# This script executes other executable setup scripts found in the
# ~/.config/scripts/ directory based on a specified
# setup type (home, work, or all).
# It first sets up essential dotfile directories and symlinks,
# then runs the package installation script, and finally executes
# other specific setup scripts.
# It ensures scripts are executable, captures their exit status, and logs failures.
#
# Usage: sudo ~/.config/scripts/run_setup_scripts.sh [home|work|all]
#   If no argument is provided, or an invalid argument is provided,
#   the script will prompt the user to choose.
#
# IMPORTANT:
# - This master script (run_setup_scripts.sh) handles its own sudo elevation at the start.
# - You must run this script with sudo (e.g., `sudo ./run_setup_scripts.sh`).
# - All child scripts will now run with root privileges.
# --- Sudo Elevation Check ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script requires root privileges. Attempting to elevate using sudo...${NC}"
    # Use -E to preserve environment, and pass all arguments ($@)
    exec sudo -E "$0" "$@" # Re-execute the script with sudo, preserving environment and arguments
    # The 'exec' command replaces the current shell process, so this script will restart as root.
fi


echo -e "${YELLOW}--- Starting setup script execution ---${NC}"
echo "---------------------------------------------------"

# Determine the target user and their home directory.
# SUDO_USER is set by 'sudo' to the original user who invoked sudo.
# This ensures we configure files and permissions for the correct user.
TARGET_USER="${SUDO_USER}"
TARGET_HOME="/home/$TARGET_USER"

# A sanity check to ensure we have a valid target user
if [[ -z "$TARGET_USER" ]]; then
    echo -e "${RED}ERROR: Could not determine the user who invoked sudo. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}Target user for script execution: $TARGET_USER (Home: $TARGET_HOME)${NC}"

# Define the directory containing your setup scripts
DOTFILES_SCRIPT_REPO_DIR="$TARGET_HOME/Development/repos/dotfiles/.config/scripts"
SCRIPTS_DIR="$TARGET_HOME/.config/scripts"
SETUP_SCRIPTS_DIR="$SCRIPTS_DIR/setup_scripts"
DOWNLOAD_PACKAGES_SCRIPT="$SCRIPTS_DIR/download_packages.sh"
POST_SETUP_SCRIPT="$SETUP_SCRIPTS_DIR/post_setup.sh"
SETUP_SYMLINKS_SCRIPT="$SETUP_SCRIPTS_DIR/setup_symlinks.sh"

declare -a FAILED_SCRIPTS=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

LOG_DIR=$(mktemp -d "/tmp/run_setup_scripts_logs.XXXXXX")
echo -e "${YELLOW}Temporary logs for failed scripts will be stored in: ${LOG_DIR}${NC}"

cleanup_logs() {
  echo -e "${YELLOW}Cleaning up temporary logs from ${LOG_DIR}...${NC}"
  rm -rf "$LOG_DIR"
}
trap cleanup_logs EXIT

echo "---------------------------------------------------"

# --- Setup Type Logic ---
SETUP_TYPE="$1"

prompt_for_setup_type() {
  local choice=""
  while true; do
    echo "No setup type provided as argument. Please choose an option for script execution:"
    echo "  1) Home"
    echo "  2) Work"
    echo "3) All (Home + Work)"
    echo "  4) EXIT (Do not run any setup scripts)"
    # Redirect input from the current terminal, not the script's piped stdin
    read -p "Enter your choice (1, 2, 3, or 4): " choice < /dev/tty

    case "$choice" in
      1) SETUP_TYPE="home"; break ;;
      2) SETUP_TYPE="work"; break ;;
      3) SETUP_TYPE="all"; break ;;
      4) echo "Exiting script as requested."; exit 0 ;;
      *) echo "Invalid choice. Please enter 1, 2, 3, or 4." ;;
    esac
  done
}

if [[ -z "$SETUP_TYPE" ]] || [[ "$SETUP_TYPE" != "home" && "$SETUP_TYPE" != "work" && "$SETUP_TYPE" != "all" ]]; then
  if [[ -n "$SETUP_TYPE" ]]; then
    echo "Invalid setup type '$SETUP_TYPE' provided as argument. Falling back to interactive choice."
  fi
  prompt_for_setup_type
fi

echo "Selected setup type: $(echo "$SETUP_TYPE" | tr '[:lower:]' '[:upper:]')"
echo "---------------------------------------------------"

declare -a HOME_ONLY_SCRIPTS=(
  "setup_gaming_ssd.sh"
  "setup_steam.sh"
)
declare -a WORK_ONLY_SCRIPTS=()

should_execute_script() {
  local script_name="$1"
  local execute=true

  for h_script in "${HOME_ONLY_SCRIPTS[@]}"; do
    if [[ "$script_name" == "$h_script" ]]; then
      if [[ "$SETUP_TYPE" != "home" && "$SETUP_TYPE" != "all" ]]; then
        execute=false
      fi
      break
    fi
  done

  if [[ "$execute" == "false" ]]; then
    echo -e "${YELLOW}  Skipping $script_name (specific to Home setup).${NC}"
    return 1
  fi

  for w_script in "${WORK_ONLY_SCRIPTS[@]}"; do
    if [[ "$script_name" == "$w_script" ]]; then
      if [[ "$SETUP_TYPE" != "work" && "$SETUP_TYPE" != "all" ]]; then
        execute=false
      fi
      break
    fi
  done

  if [[ "$execute" == "false" ]]; then
    echo -e "${YELLOW}  Skipping $script_name (specific to Work setup).${NC}"
    return 1
  fi

  return 0
}

# This function now runs the script directly, as the parent is already root.
execute_foundational_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    local script_type="$2"
    local setup_type_arg="${3:-}"

    echo -e "${YELLOW}Executing foundational script: $script_name for $script_type...${NC}"

    if [ ! -f "$script_path" ] || [ ! -x "$script_path" ]; then
        echo -e "${RED}  ERROR: '$script_path' not found or not executable. Exiting.${NC}"
        FAILED_SCRIPTS+=("$script_name (Error: Not found or not executable)")
        exit 1
    else
        LOG_FILE="$LOG_DIR/$(basename "$script_name" .sh).log"
        echo -e "${YELLOW}  Real-time output and full log for this script: ${LOG_FILE}${NC}"

        if [[ -n "$setup_type_arg" ]]; then
          "$script_path" "$setup_type_arg" 2>&1 | tee "$LOG_FILE"
        else
          "$script_path" 2>&1 | tee "$LOG_FILE"
        fi
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


echo -e "${YELLOW}Creating top-level symlink and ensuring symlink script is executable...${NC}"
mkdir -p "$TARGET_HOME/.config"
if ln -sfn "$DOTFILES_SCRIPT_REPO_DIR" "$SCRIPTS_DIR"; then
    echo -e "${GREEN}Symlink created: $DOTFILES_SCRIPT_REPO_DIR -> $SCRIPTS_DIR${NC}"
else
    echo -e "${RED}Error creating symlink for the scripts directory. Exiting.${NC}"
    exit 1
fi
if chmod +x "$SETUP_SYMLINKS_SCRIPT"; then
    echo -e "${GREEN}Foundational symlink script ($SETUP_SYMLINKS_SCRIPT) made executable.${NC}"
else
    echo -e "${RED}Error making foundational symlink script executable. Exiting.${NC}"
    exit 1
fi
echo "---------------------------------------------------"

execute_foundational_script "$SETUP_SYMLINKS_SCRIPT" "symlink setup"

echo -e "${YELLOW}Ensuring all scripts in '$SCRIPTS_DIR' are executable recursively...${NC}"
if find "$SCRIPTS_DIR" -type f -exec chmod +x {} +; then
    echo -e "${GREEN}Permissions updated successfully.${NC}"
else
    echo -e "${RED}Error setting executable permissions. Subsequent scripts may fail.${NC}"
    exit 1
fi
echo "---------------------------------------------------"


# --- Execute Foundational Scripts in Order ---
execute_foundational_script "$DOWNLOAD_PACKAGES_SCRIPT" "package installation" "$SETUP_TYPE"


# --- Loop through other setup scripts ---
while read -r script_path; do
    script_name=$(basename "$script_path")

    if [[ "$script_name" == "run_setup_scripts.sh" ]]; then
        continue
    fi
    if [[ "$script_name" == "download_packages.sh" ]]; then
        continue
    fi
    if [[ "$script_name" == "post_setup.sh" ]]; then
        continue
    fi
    if [[ "$script_name" == "setup_symlinks.sh" ]]; then
        continue
    fi

    if should_execute_script "$script_name"; then
        echo -e "${YELLOW}Executing: $script_name...${NC}"
        LOG_FILE="$LOG_DIR/$(basename "$script_path" .sh).log"
        echo -e "${YELLOW}  Real-time output and full log for this script: ${LOG_FILE}${NC}"

        # Execute the script directly as root
        "$script_path" 2>&1 | tee "$LOG_FILE"
        exit_status=${PIPESTATUS[0]}

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


execute_foundational_script "$POST_SETUP_SCRIPT" "post-setup configuration" "$SETUP_TYPE"

echo -e "\n${GREEN}--- Script Execution Summary ---${NC}"
if [ ${#FAILED_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${GREEN}All applicable scripts executed successfully!${NC}"
else
    echo -e "${RED}The following scripts failed:${NC}"
    for failed_script in "${FAILED_SCRIPTS[@]}"; do
        echo -e "${RED}- $failed_script${NC}"
        echo "---------------------------------------------------"
    done
    echo -e "${RED}Please review the full output above for details on why they failed.${NC}"
    exit 1
fi

echo -e "${GREEN}Script execution finished.${NC}"
