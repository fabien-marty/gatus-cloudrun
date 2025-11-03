#!/bin/bash

set -x
# Backup the SQLite database to the GCP / CloudStorage bucket
# (this script should be run every minute)

# Create a lock file to prevent multiple executions
LOCK_FILE="/tmp/backup.lock"

# Check if lock file exists and if the process is still running
# (note: this is a very basic and naive lock system but it's good enough for our use case)
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE")
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "Backup script is already running (PID: $LOCK_PID). Exiting."
        exit 0
    else
        echo "Stale lock file found. Removing it."
        rm -f "$LOCK_FILE"
    fi
fi
# Create lock file with current PID
echo $$ > "$LOCK_FILE"

# Ensure lock file is removed on exit
trap 'rm -f "$LOCK_FILE"' EXIT

# Backup the SQLite database locally
cd "${APP_DIR}/data" || exit 1
if ! [ -f data.db ]; then
    echo "data.db not found. Exiting."
    exit 1
fi
rm -f data.db.backup
echo "Backing up data.db to data.db.backup..."
sqlite3 data.db ".backup 'data.db.backup'"
if [ ! -f data.db.backup ]; then
    echo "Error: Backup file data.db.backup was not created. Exiting."
    exit 1
fi
if [ ! -s data.db.backup ]; then
    echo "Error: Backup file data.db.backup is empty. Exiting."
    exit 1
fi
sqlite3 data.db.backup "PRAGMA integrity_check"
if [ $? -ne 0 ]; then
    echo "Error: Backup file data.db.backup is corrupted. Exiting."
    exit 1
fi
echo "Done"
trap 'rm -f "${APP_DIR}/data/data.db.backup"' EXIT

echo "Backing up data.db.backup to ${GATUS_CLOUDRUN_DB_PATH}..."
if [[ "$GATUS_CLOUDRUN_DB_PATH" =~ ^gs:// ]]; then
    timeout ${GATUS_CLOUDRUN_GCS_TIMEOUT} gsutil cp "${APP_DIR}/data/data.db.backup" "${GATUS_CLOUDRUN_DB_PATH}"
    RES=$?
else
    cp -f "${APP_DIR}/data/data.db.backup" "${GATUS_CLOUDRUN_DB_PATH}"
    RES=$?
fi
if [ $RES -eq 0 ]; then
    # Let's add a "by week" backup file
    WEEK=$(date +%V)
    echo "Backing up data.db.backup to ${GATUS_CLOUDRUN_DB_PATH}.week${WEEK}..."
    timeout ${GATUS_CLOUDRUN_GCS_TIMEOUT} gsutil cp "${APP_DIR}/data/data.db.backup" "${GATUS_CLOUDRUN_DB_PATH}.week${WEEK}"
fi
if [ $RES -ne 0 ]; then
    echo "Error: Failed to backup the Gatus database file to the GCP / CloudStorage bucket. Exiting."
    exit 1
fi
echo "Done"
