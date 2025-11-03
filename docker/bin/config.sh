#!/bin/bash

set -x

# Get the configuration file from the GCP / CloudStorage bucket

# Create a lock file to prevent multiple executions
LOCK_FILE="/tmp/config.lock"

# Check if lock file exists and if the process is still running
# (note: this is a very basic and naive lock system but it's good enough for our use case)
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE")
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "Config script is already running (PID: $LOCK_PID). Exiting."
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

# Get the configuration file from the GCP / CloudStorage bucket
cd "${APP_DIR}/config" || exit 1

# Get the Gatus configuration file
echo "Getting the Gatus configuration file from ${GATUS_CLOUDRUN_CONFIG_PATH}..."
if [[ "$GATUS_CLOUDRUN_CONFIG_PATH" =~ ^gs:// ]]; then
    # Download from GCS bucket
    timeout ${GATUS_CLOUDRUN_GCS_TIMEOUT} gsutil cp "${GATUS_CLOUDRUN_CONFIG_PATH}" "${APP_DIR}/config/config.yml.new" || { echo "Error: Failed to download the Gatus configuration file. Exiting." && exit 1; }
else
    # Copy from local path
    cp -f "${GATUS_CLOUDRUN_CONFIG_PATH}" "${APP_DIR}/config/config.yml.new" || { echo "Error: Failed to copy the Gatus configuration file. Exiting." && exit 1; }
fi
yamllint --no-warnings "${APP_DIR}/config/config.yml.new" || ( echo "Invalid YAML file. Exiting." && exit 1 )
diff "${APP_DIR}/config/config.yml" "${APP_DIR}/config/config.yml.new" >/dev/null 2>&1 && { echo "No changes in the Gatus configuration file. Exiting." && exit 1; }
cp -f "${APP_DIR}/config/config.yml.new" "${APP_DIR}/config/config.yml"
echo "Done"
