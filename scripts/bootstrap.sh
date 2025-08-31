#!/bin/bash
#
# bootstrap.sh
# This script serves as the single-command entry point to set up a new
# Pop!_OS machine using a self-contained Ansible playbook.
#
# Usage:
#   ./scripts/bootstrap.sh 1|2|3
#   ./scripts/bootstrap.sh home|work|all
#   ./scripts/bootstrap.sh            # prompts: 1) Home; 2) Work; 3) All; 4) Exit;
#
# It performs the following steps:
# 1. Updates the system's package list.
# 2. Installs Python's package manager (pip) and venv module if not present.
# 3. Creates a Python virtual environment within the repository to isolate Ansible.
# 4. Installs Ansible, required collections and Python libs.
# 5. Executes the main Ansible playbook with a selected install profile.

set -e

# Root of the repo (one level up from this script)
REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Map CLI arg or prompt choice to profile (case-insensitive)
map_profile() {
  local arg="${1:-}"
  case "${arg,,}" in
    1|home) echo "home" ;;
    2|work) echo "work" ;;
    3|all)  echo "all"  ;;
    4|exit|quit) echo "exit" ;;
    *) echo "" ;;
  esac
}

PROFILE="$(map_profile "${1:-}")"
if [[ -z "$PROFILE" ]]; then
  while :; do
    echo "Choose setup:"
    echo "  1) Home"
    echo "  2) Work"
    echo "  3) All"
    echo "  4) Exit"
    read -rp "Enter choice [1-4 | home|work|all|exit]: " choice
    PROFILE="$(map_profile "$choice")"
    [[ "$PROFILE" == "exit" ]] && exit 0
    [[ -n "$PROFILE" ]] && break
    echo "Invalid choice. Try again."
  done
fi
[[ "$PROFILE" == "exit" ]] && exit 0

echo "Starting automated Pop!_OS setup (profile: ${PROFILE})..."

# Step 1: Update and upgrade the system packages
echo "Updating and upgrading system packages..."
sudo apt update && sudo apt upgrade -y

# Step 2: Install Python dependencies
echo "Installing Python3 and pip for Ansible..."
sudo apt install -y python3-pip python3-venv

# Step 3: Create a Python virtual environment inside the repository
if [[ ! -d "${REPO_ROOT_DIR}/.venv" ]]; then
  echo "Creating a Python virtual environment to contain Ansible..."
  python3 -m venv "${REPO_ROOT_DIR}/.venv"
fi

# Step 4: Activate the virtual environment
echo "Activating the virtual environment..."
# shellcheck disable=SC1091
source "${REPO_ROOT_DIR}/.venv/bin/activate"

# Step 5: Install Ansible and required collections and Python libraries
echo "Installing Ansible and community collections..."
pip install --upgrade pip
pip install ansible
ansible-galaxy collection install community.general

echo "Installing required Python libraries for Ansible modules..."
pip install github3.py requests

# Step 6: Execute the main Ansible playbook with selected profile
echo "Running the main Ansible playbook..."
cd "${REPO_ROOT_DIR}/ansible"
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook playbook.yml \
  --inventory inventory.ini \
  --ask-become-pass \
  --diff \
  --extra-vars "install_profile=${PROFILE}"

echo "Setup script finished successfully. Your system should now be fully configured."
