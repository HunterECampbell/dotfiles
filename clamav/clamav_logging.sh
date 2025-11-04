#!/bin/bash

# ClamAV Shared Virus Logging Functions
# Provides consistent virus logging across all ClamAV components

# Function to generate timestamped log filename
# Returns: virus_log_MM-D-YYYY_H-MM-AM/PM.txt
# Usage: generate_virus_log_filename [target_user_home]
generate_virus_log_filename() {
    local target_home="${1:-$HOME}"
    local current_date=$(date '+%-m-%-d-%Y')
    local current_time=$(date '+%-I-%M-%P')
    echo "${target_home}/virus_log_${current_date}_${current_time}.txt"
}

# Function to log virus detection with specified format
# Usage: log_virus_detection <virus_name> <file_path>
log_virus_detection() {
    local virus_name="$1"
    local file_path="$2"

    # Extract directory and filename
    local directory=$(dirname "$file_path")
    local filename=$(basename "$file_path")

    # Generate log filename
    local log_file=$(generate_virus_log_filename)

    # Format timestamp for log entry
    local timestamp=$(date '+%-m/%-d/%Y %-I:%M%P')

    # Create log entry with specified format
    {
        echo "$virus_name"
        echo "Directory: $directory"
        echo "File: $filename"
        echo "$timestamp"
        echo ""  # Single line of white space between entries
    } >> "$log_file"

    # Return the log filename for reference
    echo "$log_file"
}

# Function to extract virus name from ClamAV output
# Usage: extract_virus_name <clamscan_output_line>
extract_virus_name() {
    local clamscan_line="$1"

    # ClamAV output format: "/path/to/file: VIRUS_NAME FOUND"
    # Extract the virus name between the colon and "FOUND"
    echo "$clamscan_line" | sed 's/.*: \(.*\) FOUND/\1/'
}

# Function to log multiple virus detections from scan output
# Usage: log_multiple_viruses <full_scan_output>
log_multiple_viruses() {
    local scan_output="$1"
    local log_file=""

    # Process each line that contains "FOUND"
    while IFS= read -r line; do
        if [[ "$line" == *"FOUND"* ]]; then
            # Extract file path (everything before the colon)
            local file_path=$(echo "$line" | sed 's/: .*//')

            # Extract virus name
            local virus_name=$(extract_virus_name "$line")

            # Log this virus detection
            log_file=$(log_virus_detection "$virus_name" "$file_path")
        fi
    done <<< "$scan_output"

    # Return the log filename if any viruses were logged
    [[ -n "$log_file" ]] && echo "$log_file"
}
