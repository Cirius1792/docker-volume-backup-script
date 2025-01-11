# Docker Volume Backup Script

A robust shell script for safely backing up Docker volumes while managing container states and maintaining a clean backup history.

If you are not usign it with ansible, please remember to remove the jinja2 escape sequences where marked in the file. 
## Features

- 🔄 Automatically detects and manages containers using specified volumes
- 🛑 Safely stops affected containers before backup and restarts them afterward
- 📦 Creates compressed backups of Docker volumes
- 🧹 Maintains a clean backup history by removing old backups
- 📝 Detailed logging of all operations
- 🔒 Handles permissions safely using a temporary Docker container
- 🔄 Ensures containers are restarted even if the backup fails

## Prerequisites

- Docker installed and running
- Bash shell
- Sufficient disk space for backups
- Read access to Docker volumes
- Write access to backup destination directory

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/docker-volume-backup.git
cd docker-volume-backup
```

2. Make the script executable:
```bash
chmod +x backup-services.sh
```

## Configuration

The script uses several variables that can be configured either directly in the script or through Ansible templates:

```bash
SOURCE_DIR="/path/to/docker/volumes"    # Directory containing Docker volumes
BACKUP_DIR="/path/to/backups"           # Where backups will be stored
LOG_FILE="/path/to/backup.log"          # Log file location
KEEP_LAST=7                             # Number of recent backups to keep
```

### Using with Ansible

The script is designed to work with Ansible templates. Example variables in your Ansible playbook:

```yaml
docker_dir: /var/lib/docker/volumes
docker_bkp_dir: /mnt/backups/docker
backup_log_file: /var/log/docker-backup.log
```

## Usage

### Basic Usage

Run the script directly:
```bash
./backup-services.sh
```

### Scheduling Backups

To schedule regular backups, add a cron job:

```bash
# Edit crontab
crontab -e

# Add a line to run backup daily at 2 AM
0 2 * * * /path/to/backup-services.sh
```

## How It Works

1. **Container Detection**
   - Script identifies all running containers using volumes in the specified source directory
   - Only containers using targeted volumes are affected

2. **Safe Shutdown**
   - Detected containers are gracefully stopped before backup
   - Container states are tracked for proper restoration

3. **Backup Process**
   - A temporary Alpine Linux container is created to perform the backup
   - Source volumes are mounted read-only for safety
   - Backup is created using tar with compression

4. **Cleanup**
   - Old backups are automatically removed based on KEEP_LAST setting
   - Only successful backups trigger cleanup

5. **Container Restoration**
   - Containers are restarted in the same order they were stopped
   - Trap ensures containers are restarted even if script fails

## Backup Structure

Backups are created with the following naming convention:
```
backup-YYYY-MM-DD_HH-MM-SS.tar.gz
```

Example:
```
backup-2025-01-08_14-30-25.tar.gz
```

## Logging

The script provides detailed logging of all operations. Log entries include:
- Container operations (stop/start)
- Backup creation status
- Cleanup operations
- Error messages
- Timing information

Example log output:
```
[2025-01-08 14:30:25] Backup process started
[2025-01-08 14:30:26] Found 3 containers using volumes in backup directory
[2025-01-08 14:30:27] Successfully stopped container mysql
[2025-01-08 14:30:28] Backup completed successfully
[2025-01-08 14:30:29] Successfully started container mysql
```

## Error Handling

The script includes several safety features:
- Trap mechanism ensures containers are restarted even if script fails
- Detailed error logging
- Non-zero exit codes on failure
- Read-only mounting of source volumes
- Container state tracking

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


