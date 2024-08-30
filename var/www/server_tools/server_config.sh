#!/bin/bash

REPO_DIR="/var/www/BACKUP/server_config/"
LOG_FILE="/var/log/config_monitor.log"

MONITORED_FILES=(
    "/etc/fail2ban/jail.local"
    "/etc/nginx/nginx.conf"
)

MONITORED_DIRS=(
    "/var/www/server_tools"
    "/etc/nginx/sites-available"
)

# Function to copy files and directories into the repo directory
copy_new_files() {
    echo "Checking for newly added or changed files and directories..." | tee -a "$LOG_FILE"
    local changes_detected=false

    # Copy individual files
    for file in "${MONITORED_FILES[@]}"; do
        echo "Checking file: $file" | tee -a "$LOG_FILE"
        if [ -f "$file" ]; then
            local destination="$REPO_DIR$file"
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

    # Copy entire directory structures
    for dir in "${MONITORED_DIRS[@]}"; do
        echo "Checking directory: $dir" | tee -a "$LOG_FILE"
        if [ -d "$dir" ]; then
            mkdir -p "$REPO_DIR$dir"
            rsync_output=$(rsync -av --delete --exclude='.git' "$dir/" "$REPO_DIR$dir/")
            if [[ "$rsync_output" != *"sending incremental file list"* ]]; then
                changes_detected=true
                echo "Directory changes detected in: $dir" | tee -a "$LOG_FILE"
            else
                echo "No changes in directory: $dir" | tee -a "$LOG_FILE"
            fi
        else
            echo "Directory not found: $dir" | tee -a "$LOG_FILE"
        fi
    done

    echo "$changes_detected"
}

# Function to update Git repository
update_repo() {
    cd "$REPO_DIR" || { echo "Failed to change directory to $REPO_DIR" | tee -a "$LOG_FILE"; exit 1; }

    git add -A
    if ! git diff-index --quiet HEAD --; then
        echo "Changes detected, committing..." | tee -a "$LOG_FILE"
        git commit -m "Update server files - $(date)" 2>&1 | tee -a "$LOG_FILE"
        echo "Pushing changes to GitHub..." | tee -a "$LOG_FILE"
        git push origin master 2>&1 | tee -a "$LOG_FILE"
        echo "Changes committed and pushed to GitHub." | tee -a "$LOG_FILE"
    else
        echo "No changes detected, nothing to commit." | tee -a "$LOG_FILE"
    fi
}

# Initial copy of any new files and push to repo
initial_copy_done=$(copy_new_files)
if [ "$initial_copy_done" = true ]; then
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
    change_detected=$(copy_new_files)
    if [ "$change_detected" = true ]; then
        update_repo
    fi
done
