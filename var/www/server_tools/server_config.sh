#!/bin/bash

REPO_DIR="/var/www/BACKUP/server_config/"
LOG_FILE="/var/log/config_monitor.log"

MONITORED_FILES=(
    "/etc/fail2ban/jail.local"
    "/etc/nginx/nginx.conf"
    "/var/www/server_tools/test4"  # Example of a newly added file
)

MONITORED_DIRS=(
    "/var/www/server_tools"
    "/etc/nginx/sites-available"
)

copy_new_files() {
    echo "Checking for newly added or changed files and directories..." | tee -a "$LOG_FILE"
    local changes_detected=false

    for file in "${MONITORED_FILES[@]}"; do
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
    done

    for dir in "${MONITORED_DIRS[@]}"; do
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
    done

    echo "Changes detected: $changes_detected" | tee -a "$LOG_FILE"
    
    # Return 0 for true, 1 for false
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
copy_new_files
initial_copy_done=$?
echo "Initial copy result: $initial_copy_done" | tee -a "$LOG_FILE"

if [ $initial_copy_done -eq 0 ]; then
    echo "Calling update_repo after initial copy" | tee -a "$LOG_FILE"
    update_repo
else
    echo "No changes detected during initial copy." | tee -a "$LOG_FILE"
fi

# Now proceed to monitor for changes
MONITOR_PATHS=("${MONITORED_FILES[@]}" "${MONITORED_DIRS[@]}")

inotifywait -m -r -e modify,create,delete "${MONITOR_PATHS[@]}" |
while read -r path action file; do
    echo "Change detected in $path$file ($action)" | tee -a "$LOG_FILE"
    sleep 5  # Adjust as needed to batch changes
    copy_new_files
    change_detected=$?
    echo "Change detected result: $change_detected" | tee -a "$LOG_FILE"
    if [ $change_detected -eq 0 ]; then
        echo "Calling update_repo after change detected" | tee -a "$LOG_FILE"
        update_repo
    fi
done
