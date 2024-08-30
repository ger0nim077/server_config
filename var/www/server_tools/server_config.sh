#!/bin/bash

REPO_DIR="/var/www/BACKUP/server_config/"
LOG_FILE="/var/log/config_monitor_debug.log"

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

# Function to copy files and directories into the repo directory
initial_copy() {
    echo "Performing initial copy of files and directories..." | tee -a "$LOG_FILE"

    # Copy individual files
    for file in "${MONITORED_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "Copying file: $file" | tee -a "$LOG_FILE"
            mkdir -p "$REPO_DIR$(dirname "$file")"
            cp "$file" "$REPO_DIR$file"
        else
            echo "File not found: $file" | tee -a "$LOG_FILE"
        fi
    done

    # Copy entire directory structures
    for dir in "${MONITORED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "Copying directory: $dir" | tee -a "$LOG_FILE"
            mkdir -p "$REPO_DIR$dir"
            rsync -av --delete --exclude='.git' "$dir/" "$REPO_DIR$dir/"
        else
            echo "Directory not found: $dir" | tee -a "$LOG_FILE"
        fi
    done
}

# Ensure REPO_DIR exists
mkdir -p "$REPO_DIR"

# Perform the initial copy
initial_copy

echo "Initial copy complete. Please check the REPO_DIR for files." | tee -a "$LOG_FILE"
