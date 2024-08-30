#!/bin/bash

# Last saved: 2024-08-30 20:02:03

# Log Monitoring Script
# ---------------------
# This script monitors specified log files for changes, detects relevant log entries,
# and sends email notifications based on predefined keywords. It also supports filtering
# out irrelevant entries using exclusion patterns and handles log rotation events to 
# ensure continuous operation.

# Key Features:
# - Monitors log files using inotifywait for real-time detection of changes.
# - Discards entire multi-line messages if any exclusion pattern is found.
# - Sends email notifications when keywords are detected in new log entries.
# - Automatically reinitializes monitoring after log rotation (e.g., when file size drops to zero).
# - Supports debounce and notification intervals to prevent duplicate alerts.

# Configuration:
# - LOG_FILES_KEYWORDS: Associative array mapping log files to keywords.
# - EXCLUSION_PATTERNS: Associative array mapping log files to exclusion patterns.
# - NOTIFICATION_INTERVAL: Minimum time between notifications for the same log file.
# - DEBOUNCE_INTERVAL: Time to wait before processing detected changes.

# How It Works:
# - The script uses inotifywait to monitor log files for modifications.
# - When a change is detected, new log entries are extracted and processed.
# - If an exclusion pattern is found in any part of the new entries, the entire message is discarded.
# - If no exclusion pattern is found, the entries are checked for keywords, and email notifications are sent if a match is found.

# Usage:
# - Configure the LOG_FILES_KEYWORDS and EXCLUSION_PATTERNS arrays.
# - Set the script to run as a service for continuous monitoring.
# - Check the log file (/var/log/log_monitor.log) for script activity and debugging.

# This script is ideal for monitoring log files across various applications and
# ensuring that only relevant log entries trigger notifications.



LOG_FILE="/var/log/log_monitor.log"
INOTIFYWAIT_PID_FILE="/var/run/inotifywait.pid"
declare -A LAST_NOTIFICATION
declare -A FILE_POSITIONS
NOTIFICATION_INTERVAL=120  # 2 minutes in seconds
DEBOUNCE_INTERVAL=2        # 2 seconds debounce

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Associative array to store log files and their corresponding keywords
declare -A LOG_FILES_KEYWORDS=(
    ["/var/www/html/booksoft.ro/auctiondb/logs/mysqli_errors.log"]=""
    ["/var/www/html/booksoft.ro/diverse/astro/logs/mysqli_errors.log"]=""
    ["/var/www/html/booksoft.ro/scraper/logs/mysqli_errors.log"]=""
    ["/var/www/html/booksoft.ro/scraper/logs/scraperH_errors.log"]=""
    ["/var/www/html/booksoft.ro/scraper/logs/scraperOK_errors.log"]=""
    ["/var/www/html/primapagina.ro/logs/mysqli_errors.log"]=""
    #["/var/www/html/booksoft.ro/scraper/logs/curl_errors.log"]="TIMEOUT|ERROR"
    ["/var/www/BACKUP/errors.log"]="FAILED"
    ["/var/log/fail2ban.log"]="BAN|ERROR|NOTICE"
    ["/var/log/letsencrypt/letsencrypt.log"]="ERROR|WARN|FAILURE"
    ["/var/log/mysql/error.log"]="ERROR|REJECT|FAILURE|WARNING"
    ["/var/log/nginx/error.log"]="ERROR|ALERT"
    ["/var/log/php8.3-fpm.log"]="WARNING|ERROR"
    ["/var/log/chromedriver.log"]=""
    ["/var/log/config_monitor.log"]=""

)

# Specific exclusion patterns for individual log files
declare -A EXCLUSION_PATTERNS=(
    ["/var/log/fail2ban.log"]="unban"
    ["/var/log/letsencrypt/letsencrypt.log"]="no renewal failures"
    ["/var/log/nginx/error.log"]="Max retries reached|Temporary authentication failure"
    ["/var/log/php8.3-fpm.log"]="Max retries reached|authentication failed|Temporary authentication failure"
)

# Email address to send notifications
EMAIL="tvasile@gmail.com"

# Function to send email with retry mechanism
send_email() {
    local file="$1"
    local matched_lines="$2"
    local subject="Log File Modified: $file"
    local body="The log file $file has been modified. Here are the matching entries:\n\n$matched_lines"
    local max_attempts=3
    local attempt=0
    local success=false

    log_message "Preparing to send email notification for $file"

    while [[ $attempt -lt $max_attempts && $success == false ]]; do
        ((attempt++))
        echo -e "To: $EMAIL\nSubject: $subject\n\n$body" | /usr/bin/msmtp -a default "$EMAIL"
        if [ $? -eq 0 ]; then
            log_message "Successfully sent email notification for $file (attempt $attempt)"
            success=true
        else
            log_message "Failed to send email notification for $file (attempt $attempt), retrying..."
            sleep 5  # Wait for 5 seconds before retrying
        fi
    done

    if [[ $success == false ]]; then
        log_message "Failed to send email notification for $file after $max_attempts attempts"
    fi
}

# Function to handle exit
cleanup() {
    log_message "Stopping log monitoring"
    kill $(cat "$INOTIFYWAIT_PID_FILE")
    rm -f "$INOTIFYWAIT_PID_FILE"
    exit 0
}

# Set up signal handling for cleanup
trap cleanup SIGINT SIGTERM

# Initialize or update the last read position for each file
initialize_positions() {
    for file in "${!LOG_FILES_KEYWORDS[@]}"; do
        FILE_POSITIONS[$file]=$(stat -c%s "$file")
        log_message "Initialized or updated file size for $file: ${FILE_POSITIONS[$file]}"
    done
}

initialize_positions
log_message "Starting log monitoring"
log_message "Setting up watches."

inotifywait -m --format '%w%f' "${!LOG_FILES_KEYWORDS[@]}" -e modify,close_write |
while read -r full_path; do
    log_message "Change detected in $full_path"
    sleep $DEBOUNCE_INTERVAL
    current_time=$(date +%s)
    last_time=${LAST_NOTIFICATION[$full_path]:-0}
    time_diff=$((current_time - last_time))

    if [[ $time_diff -lt $NOTIFICATION_INTERVAL ]]; then
        log_message "Skipping $full_path, only $time_diff seconds since last notification."
        continue
    fi

    sync
    new_size=$(stat -c%s "$full_path")
    old_size=${FILE_POSITIONS[$full_path]:-0}

    # Check if the file size suddenly drops to zero
    if [[ $new_size -eq 0 ]]; then
        log_message "Log file size is zero, treating as log rotation for $full_path"
        FILE_POSITIONS[$full_path]=0  # Reset the file position
        initialize_positions  # Reinitialize monitoring positions
        continue  # Skip to the next iteration
    fi

    # Regular file growth handling
    if [[ $new_size -gt $old_size ]]; then
        added_bytes=$((new_size - old_size))
        log_message "Old Size: $old_size, New Size: $new_size, Added Bytes: $added_bytes for $full_path"

        # Extract and clean up new lines
        new_lines=$(tail -c "$added_bytes" "$full_path" | tr -cd '\11\12\15\40-\176')
        log_message "Extracted and Cleaned Up New Lines: $new_lines"

        # Check the entire block for exclusion patterns
        if [[ -n "${EXCLUSION_PATTERNS[$full_path]}" ]]; then
            if echo "$new_lines" | grep -qE "${EXCLUSION_PATTERNS[$full_path]}"; then
                log_message "Exclusion pattern found in $full_path, discarding the entire block of new lines."
                continue  # Skip further processing of this block
            fi
        fi

        # If no exclusion pattern found, proceed with filtering and keyword matching
        log_message "No exclusion pattern found, processing the new lines."

        # Reset the matched_log_entries for the current file
        matched_log_entries=""

        # Check if keywords are defined
        if [[ -z "${LOG_FILES_KEYWORDS[$full_path]}" ]]; then
            # If no specific keywords are set (empty string), treat all new content as relevant
            matched_log_entries="$new_lines"
            log_message "No specific keywords for $full_path, treating all new content as relevant."
        else
            # Match lines with the specified keywords
            matched_log_entries=$(echo "$new_lines" | grep -Ei "${LOG_FILES_KEYWORDS[$full_path]}")
            log_message "Attempted Keyword Matching: $matched_log_entries"
        fi

        if [[ -n "${LOG_FILES_KEYWORDS[$full_path]}" ]]; then
            matched_log_entries=$(echo "$new_lines" | grep -Ei "${LOG_FILES_KEYWORDS[$full_path]}")
            log_message "Attempted Keyword Matching: $matched_log_entries"
        fi

        # If relevant content is found (either by matching keywords or by treating all new lines as relevant)
        if [[ -n "$matched_log_entries" ]]; then
            log_message "Modification detected with relevant content in $full_path"
            send_email "$full_path" "$matched_log_entries"
            LAST_NOTIFICATION[$full_path]=$current_time  # Update the last notification time
        else
            log_message "No relevant content found in $full_path after applying exclusion patterns or keyword check"
        fi

    else
        log_message "No size increase detected for $full_path"
    fi
    FILE_POSITIONS[$full_path]=$new_size
done & echo $! > "$INOTIFYWAIT_PID_FILE"


wait
