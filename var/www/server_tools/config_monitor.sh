#!/bin/bash

REPO_DIR="/var/www/BACKUP/server_config/"
LOG_FILE="/var/log/config_monitor.log"

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

MONITORED_DIRS=(
    "/var/www/server_tools"
    "/etc/nginx/sites-available"
)

# Function to handle changes in files and directories
handle_change() {
    local path="$1"
    local changes_detected=false

    if [ -f "$path" ]; then
        echo "Checking file: $path" | tee -a "$LOG_FILE"
        local destination="$REPO_DIR$path"
        echo "Destination for $path is $destination" | tee -a "$LOG_FILE"
        mkdir -p "$(dirname "$destination")"
        if [ ! -f "$destination" ]; then
            echo "New file detected, copying: $path" | tee -a "$LOG_FILE"
            cp "$path" "$destination"
            changes_detected=true
        elif ! cmp -s "$path" "$destination"; then
            echo "File modified, copying: $path" | tee -a "$LOG_FILE"
            cp "$path" "$destination"
            changes_detected=true
        else
            echo "File unchanged: $path" | tee -a "$LOG_FILE"
        fi
    elif [ -d "$path" ]; then
        echo "Checking directory: $path" | tee -a "$LOG_FILE"
        mkdir -p "$REPO_DIR$path"
        rsync_output=$(rsync -av --delete --exclude='.git' "$path/" "$REPO_DIR$path/")
        if [ "$(echo "$rsync_output" | grep -v 'sending incremental file list')" != "" ]; then
            changes_detected=true
            echo "Directory changes detected in: $path" | tee -a "$LOG_FILE"
            echo "$rsync_output" | tee -a "$LOG_FILE"
        else
            echo "No changes in directory: $path" | tee -a "$LOG_FILE"
        fi
    else
        echo "Path deleted: $path" | tee -a "$LOG_FILE"
        if [ -e "$REPO_DIR$path" ]; then
            git rm -rf "$REPO_DIR$path" 2>&1 | tee -a "$LOG_FILE"
            changes_detected=true
        fi
    fi

    if [ "$changes_detected" = true ]; then
        return 0
    else
        return 1
    fi
}

update_repo() {
    cd "$REPO_DIR" || { echo "Failed to change directory to $REPO_DIR" | tee -a "$LOG_FILE"; exit 1; }

    git status 2>&1 | tee -a "$LOG_FILE"
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

# Initial copy of any new files and push to repo
for file in "${MONITORED_FILES[@]}"; do
    handle_change "$file"
done

for dir in "${MONITORED_DIRS[@]}"; do
    handle_change "$dir"
done

update_repo

# Now proceed to monitor for changes
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