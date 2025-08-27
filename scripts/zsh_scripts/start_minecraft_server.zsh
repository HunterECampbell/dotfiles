# Function to start a Minecraft modded server
# Usage: start_minecraft_server "~/Minecraft Servers/MyAwesomeServer"
function start_minecraft_server() {
    # Check if a directory path was provided
    if [ -z "$1" ]; then
        echo "Error: Please provide the name of your Minecraft server folder."
        return 1
    fi

    local server_dir="~/'Minecraft Servers'/$1"

    # Resolve the full path, expanding ~ and handling relative paths
    server_dir=$(eval echo "$server_dir")

    # Check if the provided directory exists
    if [ ! -d "$server_dir" ]; then
        echo "Error: Directory '$server_dir' not found."
        return 1
    fi

    echo "Attempting to start Minecraft server in: $server_dir"

    # Navigate to the server directory
    # Using a subshell with (cd "$server_dir" && ...) ensures we return
    # to the original directory after the command finishes.
    (
        cd "$server_dir" || { echo "Error: Could not change to directory '$server_dir'."; return 1; }

        # Check for run.sh first
        if [ -f "run.sh" ] && [ -x "run.sh" ]; then
            echo "Found and executing run.sh..."
            ./run.sh
        # If run.sh doesn't exist or isn't executable, check for start.sh
        elif [ -f "start.sh" ] && [ -x "start.sh" ]; then
            echo "Found and executing start.sh..."
            ./start.sh
        else
            echo "Error: Neither 'run.sh' nor 'start.sh' found or executable in '$server_dir'."
            echo "Please ensure one of these scripts exists and has execute permissions (e.g., chmod +x run.sh)."
            return 1
        fi
    )
    # The return value of the subshell (the last command executed in it) will be the return value of the function
}

# Optional: Create a shorter alias for convenience
# alias mcserver="start_minecraft_server"
