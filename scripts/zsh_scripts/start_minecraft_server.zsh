# Helper function to convert server name to screen session name
function _server_name_to_screen_name() {
    local server_name="$1"
    echo "minecraft-${server_name// /-}"
}

# Function to start a Minecraft modded server
# Usage: start_minecraft_server "MyAwesomeServer" [script_name]
#   - First argument: name of your Minecraft server folder
#   - Second argument (optional): name of the script to run (e.g., "run.sh", "start.sh", "custom.sh")
#     If not provided, defaults to checking "run.sh" then "start.sh"
# Note: Server runs in a screen session for persistence and uses systemd-inhibit to prevent
#       system suspend/hibernate while the server is running
function start_minecraft_server() {
    # Check if a directory path was provided
    if [ -z "$1" ]; then
        echo "Error: Please provide the name of your Minecraft server folder."
        return 1
    fi

    local server_dir="~/'Minecraft Servers'/$1"
    local script_name="$2"

    # Resolve the full path, expanding ~ and handling relative paths
    server_dir=$(eval echo "$server_dir")

    # Check if the provided directory exists
    if [ ! -d "$server_dir" ]; then
        echo "Error: Directory '$server_dir' not found."
        return 1
    fi

    echo "Attempting to start Minecraft server in: $server_dir"

    # Determine which script to run (preserving all existing validation and error messages)
    local script_to_run=""

    # If a script name was provided, use it
    if [ -n "$script_name" ]; then
        if [ -f "$server_dir/$script_name" ] && [ -x "$server_dir/$script_name" ]; then
            script_to_run="$script_name"
        else
            echo "Error: Script '$script_name' not found or not executable in '$server_dir'."
            echo "Please ensure the script exists and has execute permissions (e.g., chmod +x $script_name)."
            return 1
        fi
    # Otherwise, check for run.sh first, then start.sh
    elif [ -f "$server_dir/run.sh" ] && [ -x "$server_dir/run.sh" ]; then
        script_to_run="run.sh"
    # If run.sh doesn't exist or isn't executable, check for start.sh
    elif [ -f "$server_dir/start.sh" ] && [ -x "$server_dir/start.sh" ]; then
        script_to_run="start.sh"
    else
        echo "Error: Neither 'run.sh' nor 'start.sh' found or executable in '$server_dir'."
        echo "Please ensure one of these scripts exists and has execute permissions (e.g., chmod +x run.sh)."
        return 1
    fi

    # Generate screen session name
    local screen_name=$(_server_name_to_screen_name "$1")

    # Check if screen session already exists
    if screen -list | grep -q "$screen_name"; then
        echo "Found and executing $script_to_run..."
        echo "Attaching to existing screen session..."
        screen -r "$screen_name"
        return 0
    fi

    # Verify systemd-inhibit is available
    if ! command -v systemd-inhibit >/dev/null 2>&1; then
        echo "Error: systemd-inhibit command not found. Please ensure systemd is properly installed."
        return 1
    fi

    # Verify screen is available
    if ! command -v screen >/dev/null 2>&1; then
        echo "Error: screen command not found. Please install screen package (e.g., sudo apt install screen)."
        return 1
    fi

    # Start server in screen session
    echo "Found and executing $script_to_run..."

    # Start server in detached screen session with systemd-inhibit wrapper
    # The trap ensures clean exit on Ctrl+C
    # systemd-inhibit prevents suspend/hibernate while server is running
    # After the server script exits, we monitor for the Java process to keep the inhibitor active
    # The inhibitor stays active as long as the Java server process is running
    screen -dmS "$screen_name" bash -c "cd '$server_dir' && trap 'exit' INT TERM && systemd-inhibit --what=sleep --who='Minecraft Server: $1' --why='Server is running' -- bash -c './$script_to_run; while pgrep -f \"java.*server.jar\" > /dev/null 2>&1; do sleep 5; done'"

    # Give screen a moment to start
    sleep 0.5

    # Verify screen session was created
    if ! screen -list | grep -q "$screen_name"; then
        echo "Error: Failed to create screen session."
        return 1
    fi

    # Immediately attach to screen session so user sees output
    screen -r "$screen_name"

    # After screen session ends (user pressed Ctrl+C), verify cleanup
    if screen -list | grep -q "$screen_name"; then
        screen -S "$screen_name" -X quit 2>/dev/null
    fi
}

# Optional: Create a shorter alias for convenience
# alias mcserver="start_minecraft_server"
