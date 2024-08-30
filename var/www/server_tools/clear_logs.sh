#!/bin/bash

# List of log files to clear
LOG_FILES=(
    "/var/www/html/booksoft.ro/auctiondb/logs/mysqli_errors.log"
    "/var/www/html/booksoft.ro/diverse/astro/logs/mysqli_errors.log"
    "/var/www/html/booksoft.ro/scraper/logs/mysqli_errors.log"
    "/var/www/html/booksoft.ro/scraper/logs/scraperH_errors.log"
    "/var/www/html/booksoft.ro/scraper/logs/scraperOK_errors.log"
    "/var/www/html/booksoft.ro/scraper/logs/curl_errors.log"

    "/var/www/html/primapagina.ro/logs/mysqli_errors.log"
    "/var/www/html/primapagina.ro/logs/curl_retries.log"
    "/var/www/html/primapagina.ro/logs/error.log"

    "/var/log/php8.3-fpm.log"
    "/var/log/nginx/error.log"
    "/var/log/mysql/error.log"
    "/var/log/cron.log"
    "/var/log/fail2ban.log"
    "/var/log/letsencrypt/letsencrypt.log"
    "/var/log/chromedriver.log"

    "/var/log/msmtp.log"

    "/var/log/log_monitor.log"

    "/var/www/html/combined_logs.txt"
    "/var/www/BACKUP/errors.log"

)

# Iterate over each log file and clear its contents
for LOG_FILE in "${LOG_FILES[@]}"; do
    if [ -f "$LOG_FILE" ]; then
        # Overwrite the file with an empty file
        : > "$LOG_FILE"
        echo "Cleared: $LOG_FILE"
    else
        echo "File not found: $LOG_FILE"
    fi
done

