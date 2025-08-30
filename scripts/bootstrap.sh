#!/bin/bash
#
# bootstrap.sh
# This script serves as the single-command entry point to set up a new
# Pop!_OS machine using a self-contained Ansible playbook.
#
# It performs the following steps:
# 1. Updates the system's package list.
# 2. Installs Python's package manager (pip) and venv module if not present.
# 3. Creates a Python virtual environment within the repository to isolate
#    Ansible and its dependencies, ensuring the setup is self-contained.
# 4. Installs Ansible and necessary collections (community.general).
# 5. Executes the main Ansible playbook to configure the system.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the root directory of the repository
# This will go up one level from the 'scripts' directory to the 'DOTFILES' directory
REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Starting automated Pop!_OS setup..."

# Step 1: Update and upgrade the system packages
echo "Updating and upgrading system packages..."
sudo apt update && sudo apt upgrade -y

# Step 2: Install Python dependencies
echo "Installing Python3 and pip for Ansible..."
sudo apt install -y python3-pip python3-venv

# Step 3: Create a Python virtual environment inside the repository
echo "Creating a Python virtual environment to contain Ansible..."
python3 -m venv "${REPO_ROOT_DIR}/.venv"

# Step 4: Activate the virtual environment
echo "Activating the virtual environment..."
source "${REPO_ROOT_DIR}/.venv/bin/activate"

# Step 5: Install Ansible and required collections and Python libraries
echo "Installing Ansible and community collections..."
pip install ansible
ansible-galaxy collection install community.general

echo "Installing required Python libraries for Ansible modules..."
pip install github3.py requests

# Step 6: Execute the main Ansible playbook with a change of directory
echo "Running the main Ansible playbook..."
cd "${REPO_ROOT_DIR}/ansible"
ansible-playbook playbook.yml --inventory inventory.ini --ask-become-pass

echo "Setup script finished successfully. Your system should now be fully configured."