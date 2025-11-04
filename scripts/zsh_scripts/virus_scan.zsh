# Function to scan files/directories for viruses with desktop notifications
# Usage: virus_scan "/path/to/file/or/directory"
function virus_scan() {
    # Source the shared notification and logging functions
    source ~/Development/repos/dotfiles/clamav/clamav_notifications.sh
    source ~/Development/repos/dotfiles/clamav/clamav_logging.sh

    # Check if a path was provided
    if [ -z "$1" ]; then
        echo "Error: Please provide a file or directory path to scan."
        echo "Usage: virus-scan <file|directory>"
        return 1
    fi

    local target="$1"

    # Check if the target exists
    if [ ! -e "$target" ]; then
        echo "Error: '$target' not found."
        return 1
    fi

    echo "🔍 Starting ClamAV scan of: $target"
    echo "This may take a moment..."

    # Run the scan
    local scan_output
    scan_output=$(sudo clamscan -r "$target" --no-summary 2>&1)
    local scan_result=$?

    # Parse results and send notification
    if echo "$scan_output" | grep -q "FOUND"; then
        # Virus found!
        local virus_info=$(echo "$scan_output" | grep "FOUND")
        echo "🚨 VIRUS FOUND!"
        echo "$virus_info"

        # Log virus detection to file
        local log_file=$(log_multiple_viruses "$scan_output")
        if [[ -n "$log_file" ]]; then
            echo "📝 Virus details logged to: $log_file"
        fi

        # Send notification using shared function
        send_file_scan_notification "$target" "false" "$virus_info"

        return 1
    else
        # Clean scan
        echo "✅ Scan complete - No threats detected"

        # Send notification using shared function
        send_file_scan_notification "$target" "true"

        return 0
    fi
}
