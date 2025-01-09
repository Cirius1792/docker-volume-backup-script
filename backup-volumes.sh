#!/bin/bash

# Backup script for Docker volumes

# Variables
SOURCE_DIR="{{ docker_dir }}"   # Replace with the source directory containing Docker volumes
BACKUP_DIR="{{ docker_bkp_dir }}"  # Replace with the target backup directory
LOG_FILE="{{ backup_log_file }}"        # Replace with the path to the log file
DATE=$(date '+%Y-%m-%d_%H-%M-%S')      # Timestamp for log entries
ARCHIVE_NAME="backup-$DATE.tar.gz"
KEEP_LAST=7                            # Number of recent backups to keep

# Docker-related variables
declare -A CONTAINER_STATES    # Associative array to store container states
BACKUP_CONTAINER_NAME="volume-backup-$DATE"

# Function to log messages
log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

# Function to check if docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_message "Error: docker is not installed or not in PATH"
        exit 1
    fi
}

# Function to get running containers that use volumes in SOURCE_DIR
get_affected_containers() {
    log_message "Identifying containers using volumes in $SOURCE_DIR..."
    
    # Get all running containers
    local containers
    containers=$(docker ps --format '{{.ID}}')
    
    # Check each container for volumes in SOURCE_DIR
    for container_id in $containers; do
        # Get volume mounts for this container
        local mounts
        mounts=$(docker inspect --format='{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' "$container_id")
        
        # Check if any mount points are in SOURCE_DIR
        if echo "$mounts" | grep -q "^$SOURCE_DIR"; then
            # Get container name for better logging
            local container_name
            container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/\///')
            CONTAINER_STATES["$container_id"]="$container_name"
            log_message "Container $container_name ($container_id) uses volumes in backup directory"
        fi
    done
    
    if [ ${#CONTAINER_STATES[@]} -eq 0 ]; then
        log_message "No running containers found using volumes in $SOURCE_DIR"
    else
        log_message "Found ${#CONTAINER_STATES[@]} containers using volumes in backup directory"
    fi
}

# Function to stop running containers
stop_containers() {
    if [ ${#CONTAINER_STATES[@]} -eq 0 ]; then
        return 0
    fi
    
    log_message "Stopping affected Docker containers..."
    
    for container_id in "${!CONTAINER_STATES[@]}"; do
        local container_name="${CONTAINER_STATES[$container_id]}"
        log_message "Stopping container $container_name ($container_id)..."
        
        if docker stop "$container_id" >/dev/null 2>&1; then
            log_message "Successfully stopped container $container_name"
        else
            log_message "Failed to stop container $container_name"
            return 1
        fi
    done
    
    log_message "All affected containers stopped successfully"
    return 0
}

# Function to start containers
start_containers() {
    if [ ${#CONTAINER_STATES[@]} -eq 0 ]; then
        return 0
    fi
    
    log_message "Starting Docker containers..."
    
    for container_id in "${!CONTAINER_STATES[@]}"; do
        local container_name="${CONTAINER_STATES[$container_id]}"
        log_message "Starting container $container_name ($container_id)..."
        
        if docker start "$container_id" >/dev/null 2>&1; then
            log_message "Successfully started container $container_name"
        else
            log_message "Failed to start container $container_name. Manual intervention may be required!"
            return 1
        fi
    done
    
    log_message "All containers started successfully"
    return 0
}

# Function to create backup using a temporary container
create_backup() {
    log_message "Creating backup using temporary container..."
    
    if docker run --rm \
        --name "$BACKUP_CONTAINER_NAME" \
        -v "$SOURCE_DIR:/backup/source:ro" \
        -v "$BACKUP_DIR:/backup/dest:rw" \
        alpine:latest \
        tar -czf "/backup/dest/$ARCHIVE_NAME" -C /backup/source .; then
        log_message "Backup container completed successfully"
        return 0
    fi
    log_message "Backup container failed"
    return 1
}

# Function to cleanup old backups
cleanup_old_backups() {
    log_message "Starting cleanup of old backups..."
    
    # List all backup files sorted by date (oldest first)
    local backup_files
    readarray -t backup_files < <(ls -t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null)
    local total_backups=${#backup_files[@]}
    
    if [ "$total_backups" -le $KEEP_LAST ]; then
        log_message "No cleanup needed. Current backups ($total_backups) <= maximum allowed ($KEEP_LAST)"
        return 0
    fi
    
    # Calculate how many files to delete
    local files_to_delete=$((total_backups - KEEP_LAST))
    log_message "Found $total_backups backups, removing $files_to_delete old backup(s)..."
    
    # Remove the oldest backups
    for ((i = total_backups - 1; i >= KEEP_LAST; i--)); do
        if rm "${backup_files[i]}"; then
            log_message "Deleted old backup: ${backup_files[i]}"
        else
            log_message "Failed to delete backup: ${backup_files[i]}"
        fi
    done
    
    log_message "Cleanup completed"
}

# Set up trap to ensure containers are started even if script fails
trap 'start_containers' EXIT

# Start backup process
log_message "Backup process started."

# Check for docker
check_docker

# Identify and stop running containers that use the volumes
get_affected_containers
stop_containers

START_TIME=$(date +%s)

# Create backup using temporary container
if create_backup; then
    log_message "Backup completed successfully."
    cleanup_old_backups
else
    log_message "Backup failed. Check the logs for details."
    exit 1
fi

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))

log_message "Backup process completed in $ELAPSED_TIME seconds."

# Start containers (will also be called by trap if script fails)
start_containers

exit 0
