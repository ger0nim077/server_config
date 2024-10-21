#!/bin/bash

# Log file locations
ERROR_LOG="/var/www/html/booksoft.ro/scraper/logs/curl_errors.log"
RETRY_LOG="/var/www/html/primapagina.ro/logs/curl_retries.log"

# Email sending function with retry mechanism
send_email() {
    local attempt=0
    local max_attempts=5
    local success=false
    local EMAIL="tvasile@gmail.com"
    local subject="Daily cURL Error Report"
    local body="In the last 24 hours:\n- Book Scraper: There were $ERROR_COUNT errors.\n- Prima Pagina: There were $RETRY_COUNT errors."

    while [[ $attempt -lt $max_attempts && $success == false ]]; do
        ((attempt++))
        echo -e "To: $EMAIL\nSubject: $subject\n\n$body" | /usr/bin/msmtp -a default "$EMAIL"
        if [ $? -eq 0 ]; then
            success=true
        else
            sleep 5  # Wait for 5 seconds before retrying
        fi
    done
}

# Count the number of lines containing "cURL Error" in the error log
ERROR_COUNT=$(grep -c "cURL Error" "$ERROR_LOG")

# Count the number of lines containing "Retry 3" in the retry log
RETRY_COUNT=$(grep -c "Failed to fetch content" "$RETRY_LOG")

# Send email with the error and retry counts
send_email

# Clear the log files after processing
> "$ERROR_LOG"
> "$RETRY_LOG"
