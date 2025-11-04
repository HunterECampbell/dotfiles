#!/bin/bash

# ClamAV Shared Notification Functions
# Provides consistent notification formatting and behavior across all ClamAV components

# Function to send ClamAV notifications with consistent formatting
# Usage: send_clamav_notification <urgency> <scan_type> <file_path> <result_info> [duration_info]
send_clamav_notification() {
    local urgency="$1"
    local scan_type="$2"
    local file_path="$3"
    local result_info="$4"
    local duration_info="${5:-}"

    # Extract file and directory information
    local file_name=""
    local directory_path=""

    if [[ -n "$file_path" && "$file_path" != "N/A" ]]; then
        file_name=$(basename "$file_path")
        directory_path=$(dirname "$file_path")
    fi

    # Build notification message with consistent format
    local message=""

    # Add file and directory information if available
    if [[ -n "$file_name" ]]; then
        # Convert relative paths to absolute paths for better display
        if [[ "$file_path" != /* ]]; then
            file_path="$(pwd)/$file_path"
            directory_path=$(dirname "$file_path")
        fi

        # Shorten very long directory paths for better display
        local display_path="$directory_path"
        if [[ ${#directory_path} -gt 50 ]]; then
            # Replace home directory with ~ and truncate middle if still too long
            display_path="${directory_path/#$HOME/~}"
            if [[ ${#display_path} -gt 45 ]]; then
                local path_start="${display_path:0:20}"
                local path_end="${display_path: -20}"
                display_path="${path_start}...${path_end}"
            fi
        fi

        message="📁 ${display_path}\n📄 ${file_name}\n"
    fi

    # Add result information - extract virus name if it's a virus detection
    local display_result="$result_info"

    # If this is a virus detection, extract just the virus name part
    if echo "$result_info" | grep -q "FOUND"; then
        # Extract everything after the colon (virus name and "FOUND")
        display_result=$(echo "$result_info" | sed 's/.*: //')
    fi

    message="${message}🔍 ${display_result}"

    # Add duration information if provided
    if [[ -n "$duration_info" ]]; then
        message="${message}\nDuration: $duration_info"
    fi

    # Determine notification behavior based on result
    local timeout
    local title

    if echo "$result_info" | grep -qi "clean\|no threats"; then
        # Clean scan - auto-close notification
        timeout="0"
        title="✅ ClamAV: $scan_type Complete"
    else
        # Virus found - persistent notification (requires manual dismissal)
        timeout="0"
        title="🚨 ClamAV: Virus Found!"
        urgency="critical"
    fi

    # Send notification with proper user context and formatting options
    local user_name="hcnureth"
    sudo -u "$user_name" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$user_name")/bus notify-send \
        --hint=int:transient:1 \
        --hint=string:desktop-entry:clamav \
        --hint=int:resident:1 \
        -u "$urgency" \
        -t "$timeout" \
        "$title" \
        "$message"
}

# Helper function for single file scans (manual virus-scan command)
# Usage: send_file_scan_notification <file_path> <is_clean> [virus_info]
send_file_scan_notification() {
    local file_path="$1"
    local is_clean="$2"
    local virus_info="${3:-}"

    if [[ "$is_clean" == "true" ]]; then
        send_clamav_notification "normal" "File Scan" "$file_path" "Clean"
    else
        send_clamav_notification "critical" "File Scan" "$file_path" "$virus_info"
    fi
}

# Helper function for download monitor notifications
# Usage: send_download_scan_notification <file_path> <is_clean> [virus_info]
send_download_scan_notification() {
    local file_path="$1"
    local is_clean="$2"
    local virus_info="${3:-}"

    if [[ "$is_clean" == "true" ]]; then
        send_clamav_notification "normal" "Download Scan" "$file_path" "Clean"
    else
        send_clamav_notification "critical" "Download Scan" "$file_path" "$virus_info"
    fi
}

# Helper function for scheduled scan notifications (full/light scans)
# Usage: send_scheduled_scan_notification <scan_type> <file_count> <duration> <infected_count> [results_file]
send_scheduled_scan_notification() {
    local scan_type="$1"
    local file_count="$2"
    local duration="$3"
    local infected_count="$4"
    local results_file="${5:-}"

    if [[ "$infected_count" -eq 0 ]]; then
        # Clean scan
        local result_msg="System is clean!\nFiles scanned: $file_count"
        send_clamav_notification "normal" "$scan_type" "N/A" "$result_msg" "$duration"
    else
        # Virus found
        local result_msg="$infected_count infected file(s) detected!"
        if [[ -n "$results_file" ]]; then
            result_msg="${result_msg}\nDetails: $results_file"
        fi
        send_clamav_notification "critical" "$scan_type" "N/A" "$result_msg" "$duration"
    fi
}
