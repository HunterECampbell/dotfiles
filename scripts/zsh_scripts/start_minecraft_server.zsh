# Function to start a Minecraft modded server
# Usage: start_minecraft_server "MyAwesomeServer" [script_name]
#   - First argument: name of your Minecraft server folder
#   - Second argument (optional): name of the script to run (e.g., "run.sh", "start.sh", "custom.sh")
#     If not provided, defaults to checking "run.sh" then "start.sh"
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

    # Determine which script to run
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

    # Start the server
    echo "Found and executing $script_to_run..."
    (cd "$server_dir" && ./"$script_to_run")
}

# Optional: Create a shorter alias for convenience
# alias mcserver="start_minecraft_server"
