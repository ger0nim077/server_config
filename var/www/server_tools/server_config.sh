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

# Function to check a specific file for changes
check_file() {
    local file="$1"
    local changes_detected=false

    echo "Checking file: $file" | tee -a "$LOG_FILE"
    if [ -f "$file" ]; then
        local destination="$REPO_DIR$file"
        echo "Destination for $file is $destination" | tee -a "$LOG_FILE"
        mkdir -p "$(dirname "$destination")"
        if [ ! -f "$destination" ]; then
            echo "New file detected, copying: $file" | tee -a "$LOG_FILE"
            cp "$file" "$destination"
            changes_detected=true
        elif ! cmp -s "$file" "$destination"; then
            echo "File modified, copying: $file" | tee -a "$LOG_FILE"
            cp "$file" "$destination"
            changes_detected=true
        else
            echo "File unchanged: $file" | tee -a "$LOG_FILE"
        fi
    else
        echo "File not found: $file" | tee -a "$LOG_FILE"
    fi

    if [ "$changes_detected" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to check a specific directory for changes
check_directory() {
    local dir="$1"
    local changes_detected=false

    echo "Checking directory: $dir" | tee -a "$LOG_FILE"
    if [ -d "$dir" ]; then
        mkdir -p "$REPO_DIR$dir"
        rsync_output=$(rsync -av --delete --exclude='.git' "$dir/" "$REPO_DIR$dir/")
        if [ "$(echo "$rsync_output" | grep -v 'sending incremental file list')" != "" ]; then
            changes_detected=true
            echo "Directory changes detected in: $dir" | tee -a "$LOG_FILE"
            echo "$rsync_output" | tee -a "$LOG_FILE"
        else
            echo "No changes in directory: $dir" | tee -a "$LOG_FILE"
        fi
    else
        echo "Directory not found: $dir" | tee -a "$LOG_FILE"
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

# Now proceed to monitor for changes
MONITOR_PATHS=("${MONITORED_FILES[@]}" "${MONITORED_DIRS[@]}")

inotifywait -m -r -e modify,create,delete "${MONITOR_PATHS[@]}" |
while read -r path action file; do
    echo "Change detected in $path$file ($action)" | tee -a "$LOG_FILE"
    sleep 5  # Adjust as needed to batch changes

    if [ -f "$path$file" ]; then
        check_file "$path$file"
    elif [ -d "$path$file" ]; then
        check_directory "$path$file"
    fi

    change_detected=$?
    if [ $change_detected -eq 0 ]; then
        echo "Calling update_repo after change detected" | tee -a "$LOG_FILE"
        update_repo
    fi
done