#!/bin/bash

# -----------------------------------------------------------------------------
# Server Configuration Monitoring Script
# -----------------------------------------------------------------------------
# This script monitors specific server configuration files and directories for 
# changes (creation, modification, deletion) and syncs them to a GitHub repository.
# The script uses inotifywait to detect changes in real-time, and commits any 
# changes to the repository, ensuring that your server's configuration is always 
# backed up and version-controlled.
# -----------------------------------------------------------------------------

# Directory where your Git repository is located
REPO_DIR="/var/www/BACKUP/server_config/"

# Log file location
LOG_FILE="/var/log/config_monitor.log"

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

# -----------------------------------------------------------------------------
# Function to handle changes in files and directories
# -----------------------------------------------------------------------------
# This function handles the detected changes, including:
# - Deletion of a path
# - Modification or creation of files
# - Synchronization of directories
# It returns 0 if a change was detected and acted upon, otherwise 1.
# -----------------------------------------------------------------------------
handle_change() {
    local path="$1"
    local changes_detected=false

    # Handle deletion
    if [ ! -e "$path" ]; then
        echo "Path deleted: $path" | tee -a "$LOG_FILE"
        git rm -rf "$REPO_DIR$path" 2>&1 | tee -a "$LOG_FILE"
        changes_detected=true

    # Handle file creation/modification
    elif [ -f "$path" ]; then
        echo "Handling file: $path" | tee -a "$LOG_FILE"
        local destination="$REPO_DIR$path"
        mkdir -p "$(dirname "$destination")"
        cp "$path" "$destination"
        echo "File copied: $path to $destination" | tee -a "$LOG_FILE"
        changes_detected=true

    # Handle directory synchronization
    elif [ -d "$path" ]; then
        echo "Syncing directory: $path" | tee -a "$LOG_FILE"
        rsync -av --delete --exclude='.git' "$path/" "$REPO_DIR$path/" 2>&1 | tee -a "$LOG_FILE"
        changes_detected=true
    fi

    # Return 0 if changes were detected, 1 otherwise
    if [ "$changes_detected" = true ]; then
        return 0
    else
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Function to update the Git repository
# -----------------------------------------------------------------------------
# This function stages all changes, commits them, and pushes them to GitHub.
# It also logs the status and any errors encountered during these operations.
# -----------------------------------------------------------------------------
update_repo() {
    cd "$REPO_DIR" || { echo "Failed to change directory to $REPO_DIR" | tee -a "$LOG_FILE"; exit 1; }

    echo "Staging all changes..." | tee -a "$LOG_FILE"
    git add -A 2>&1 | tee -a "$LOG_FILE"
    git status 2>&1 | tee -a "$LOG_FILE"

    if ! git diff-index --quiet HEAD --; then
        echo "Changes detected, committing..." | tee -a "$LOG_FILE"
        git commit -m "Automated commit: $(date)" 2>&1 | tee -a "$LOG_FILE"
        if [ $? -eq 0 ]; then
            echo "Pushing changes to GitHub..." | tee -a "$LOG_FILE"
            git push origin master 2>&1 | tee -a "$LOG_FILE"
            if [ $? -eq 0 ]; then
                echo "Changes committed and pushed to GitHub." | tee -a "$LOG_FILE"
            else
                echo "Git push failed" | tee -a "$LOG_FILE"
            fi
        else
            echo "Git commit failed" | tee -a "$LOG_FILE"
        fi
    else
        echo "No changes detected, nothing to commit." | tee -a "$LOG_FILE"
    fi
}

# -----------------------------------------------------------------------------
# Initial Sync: Sync files and directories before starting monitoring
# -----------------------------------------------------------------------------
# This block ensures that all files and directories are in sync with the 
# repository before the monitoring begins.
# -----------------------------------------------------------------------------
for file in "${MONITORED_FILES[@]}"; do
    handle_change "$file"
done

for dir in "${MONITORED_DIRS[@]}"; do
    handle_change "$dir"
done

update_repo

# -----------------------------------------------------------------------------
# Monitor for changes using inotifywait
# -----------------------------------------------------------------------------
# This block uses inotifywait to monitor the specified files and directories 
# for any changes (creation, modification, deletion) and triggers the handling
# of these changes followed by a commit to the repository.
# -----------------------------------------------------------------------------
MONITOR_PATHS=("${MONITORED_FILES[@]}" "${MONITORED_DIRS[@]}")

inotifywait -m -r -e modify,create,delete "${MONITOR_PATHS[@]}" |
while read -r path action file; do
    full_path="$path$file"
    echo "Change detected in $full_path ($action)" | tee -a "$LOG_FILE"
    sleep 5  # Adjust as needed to batch changes

    handle_change "$full_path"
    change_detected=$?
    if [ $change_detected -eq 0 ]; then
        echo "Calling update_repo after change detected" | tee -a "$LOG_FILE"
        update_repo
    fi
done
