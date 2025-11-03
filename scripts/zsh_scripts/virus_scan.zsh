# Function to scan files/directories for viruses with desktop notifications
# Usage: virus_scan "/path/to/file/or/directory"
function virus_scan() {
    # Check if a path was provided
    if [ -z "$1" ]; then
        echo "Error: Please provide a file or directory path to scan."
        echo "Usage: virus-scan <file|directory>"
        return 1
    fi

    local target="$1"
    local target_name=$(basename "$target")

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

        # Send critical desktop notification
        notify-send --hint=int:transient:1 -u critical -t 15000 "🚨 ClamAV: Virus Found!" "Location: $target_name\nThreat: $virus_info\nAction: Review immediately"

        return 1
    else
        # Clean scan
        echo "✅ Scan complete - No threats detected"

        # Send normal desktop notification
        notify-send --hint=int:transient:1 -u normal -t 5000 "✅ ClamAV: Scan Complete" "Location: $target_name\nResult: Clean"

        return 0
    fi
}
