#!/bin/bash

# -----------------------------------------------------------------------------
# Server Configuration Monitoring Script with Email Notifications
# -----------------------------------------------------------------------------
# This script monitors specific server configuration files and directories for 
# changes (creation, modification, deletion) and syncs them to a GitHub repository.
# The script uses inotifywait to detect changes in real-time, and commits any 
# changes to the repository, ensuring that your server's configuration is always 
# backed up and version-controlled.
#
# Additionally, this script sends an email notification for each detected change,
# with a retry mechanism to ensure delivery.
# -----------------------------------------------------------------------------

# Directory where your Git repository is located
REPO_DIR="/var/www/BACKUP/server_config/"

# Log file location
LOG_FILE="/var/log/config_monitor.log"

# Email configuration
EMAIL="tvasile@gmail.com"

# List of individual files to monitor
MONITORED_FILES=(
    "/etc/fail2ban/jail.local"
    "/etc/fail2ban/fail2ban.conf"
    "/etc/fail2ban/jail.conf"
    "/etc/fail2ban/filter.d/nginx-forbidden.conf"
    "/etc/fail2ban/filter.d/mssql-auth.conf"
    "/etc/logrotate.d/fail2ban"
    "/etc/logrotate.d/log-monitor"
    "/etc/logrotate.d/pp-queries-log"
    "/etc/logrotate.d/scraper-curl-errors"
    "/etc/mysql/mysql.conf.d/mysqld.cnf"
    "/etc/mysql/mariadb.conf.d/50-server.cnf"
    "/etc/nginx/nginx.conf"
    "/etc/php/8.3/fpm/php.ini"
    "/etc/php/8.3/fpm/php-fpm.conf"
    "/etc/php/8.3/fpm/pool.d/www.conf"
    "/etc/php/8.3/fpm/pool.d/php-fpm.d/www.conf"
    "/etc/php/8.3/cli/php.ini"
    "/etc/msmtprc"
    "/etc/systemd/system/scraper.service"
    "/etc/systemd/system/logmonitor.service"
    "/etc/systemd/system/chromedriver.service"
    "/etc/systemd/system/config_monitor.service"
    "/etc/hosts"
)

# List of directories to monitor
MONITORED_DIRS=(
    "/var/www/server_tools"
    "/etc/nginx/sites-available"
)

# Global variable to store changes
CHANGES_SUMMARY=""

# -----------------------------------------------------------------------------
# Function to log messages to the LOG_FILE
# -----------------------------------------------------------------------------

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# Function to send email with retry mechanism
# -----------------------------------------------------------------------------

send_email() {
    local subject="$1"
    local action="$2"
    local changes_summary="$3"
    local body="A change was detected in the following:\n\n$changes_summary\nAction: $action"
    local max_attempts=3
    local attempt=0
    local success=false

    log_message "Preparing to send email notification for $subject (Action: $action)"

    while [[ $attempt -lt $max_attempts && $success == false ]]; do
        ((attempt++))
        echo -e "To: $EMAIL\nSubject: $subject\n\n$body" | /usr/bin/msmtp -a default "$EMAIL" 2>&1 | tee -a "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "Successfully sent email notification for $subject (Action: $action) (attempt $attempt)"
            success=true
        else
            log_message "Failed to send email notification for $subject (Action: $action) (attempt $attempt), retrying..."
            sleep 5  # Wait for 5 seconds before retrying
        fi
    done

    if [[ $success == false ]]; then
        log_message "Failed to send email notification for $subject (Action: $action) after $max_attempts attempts"
    fi
}

# -----------------------------------------------------------------------------
# Function to handle changes in files and directories
# -----------------------------------------------------------------------------
handle_change() {
    local path="$1"
    local action="$2"
    local changes_detected=false

    # Handle deletion
    if [ ! -e "$path" ]; then
        log_message "Path deleted: $path"
        git rm -rf "$REPO_DIR$path" 2>&1 | tee -a "$LOG_FILE"
        changes_detected=true
        action="Deleted"
        CHANGES_SUMMARY+="$path: $action\n"
    elif [ -f "$path" ]; then
        log_message "Handling file: $path"
        local destination="${REPO_DIR%/}$path"
        mkdir -p "$(dirname "$destination")"

        if [ ! -f "$destination" ] || ! cmp -s "$path" "$destination"; then
            cp "$path" "$destination"
            log_message "File copied: $path to $destination"
            changes_detected=true
            action="Modified"
            CHANGES_SUMMARY+="$path: $action\n"
        else
            log_message "No changes detected for $path"
        fi
    elif [ -d "$path" ]; then
        log_message "Syncing directory: $path"
        rsync_output=$(rsync -ac --delete --exclude='.git' "$path/" "$REPO_DIR$path/")

        if [ "$(echo "$rsync_output" | grep -v -e '^sending incremental file list' -e '^$' -e '^./$')" != "" ]; then
            changes_detected=true
            log_message "Directory changes detected in: $path"
            echo "$rsync_output" | tee -a "$LOG_FILE"
            action="Directory Synced"
            CHANGES_SUMMARY+="$path: $action\n"
        else
            log_message "No changes in directory: $path"
        fi
    fi

    if [ "$changes_detected" = true ]; then
        return 0  # Changes detected
    else
        return 1  # No changes detected
    fi
}


# -----------------------------------------------------------------------------
# Function to update the Git repository
# -----------------------------------------------------------------------------
update_repo() {
    cd "$REPO_DIR" || { log_message "Failed to change directory to $REPO_DIR"; exit 1; }

    log_message "Staging all changes..."
    git add -A 2>&1 | tee -a "$LOG_FILE"
    git status 2>&1 | tee -a "$LOG_FILE"

    if ! git diff-index --quiet HEAD --; then
        log_message "Changes detected, committing..."
        git commit -m "Automated commit: $(date)" 2>&1 | tee -a "$LOG_FILE"
        if [ $? -eq 0 ]; then
            log_message "Pushing changes to GitHub..."
            git push origin master 2>&1 | tee -a "$LOG_FILE"
            if [ $? -eq 0 ]; then
                log_message "Changes committed and pushed to GitHub."

                # Send an email notification for the committed changes with details
                send_email "GitHub Repository" "Changes committed and pushed" "$CHANGES_SUMMARY"

                # Clear the changes summary after sending the email
                CHANGES_SUMMARY=""
            else
                log_message "Git push failed"
            fi
        else
            log_message "Git commit failed"
        fi
    else
        log_message "No changes detected, nothing to commit."
    fi
}

# -----------------------------------------------------------------------------
# Initial Sync: Sync files and directories before starting monitoring
# -----------------------------------------------------------------------------

for file in "${MONITORED_FILES[@]}"; do
    handle_change "$file" "Initial Sync"
done

for dir in "${MONITORED_DIRS[@]}"; do
    handle_change "$dir" "Initial Sync"
done

update_repo

# -----------------------------------------------------------------------------
# Monitor for changes using inotifywait
# -----------------------------------------------------------------------------
MONITOR_PATHS=("${MONITORED_FILES[@]}" "${MONITORED_DIRS[@]}")

inotifywait -m -r -e modify,create,delete "${MONITOR_PATHS[@]}" |
while read -r path action file; do
    full_path="$path$file"
    log_message "Change detected in $full_path ($action)"

    # Handle the change and send an email notification
    handle_change "$full_path" "$action"

    log_message "Calling update_repo after change detected"
    update_repo
done
