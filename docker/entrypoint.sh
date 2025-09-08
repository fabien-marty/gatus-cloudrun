#!/bin/bash

SCHEDULER_PID=""

# Handle SIGTERM gracefully
sigterm_handler() {
    echo "Received SIGTERM/SIGINT, let's the docker container..."
    if [ -n "$SCHEDULER_PID" ]; then
        kill -15 "$SCHEDULER_PID" 2>/dev/null
    else
        echo "No scheduler process running. Exiting."
        exit 0
    fi
}

cd "${APP_DIR}" || exit 1

# Validate required environment variables
if [ -z "$GATUS_CLOUDRUN_CONFIG_PATH" ]; then
    echo "Error: GATUS_CLOUDRUN_CONFIG_PATH is required. Exiting."
    exit 1
fi

if [ -z "$GATUS_CLOUDRUN_DB_PATH" ]; then
    echo "Error: GATUS_CLOUDRUN_DB_PATH is required. Exiting."
    exit 1
fi

if [[ ! "$GATUS_CLOUDRUN_CONFIG_PATH" =~ ^gs:// ]]; then
    echo "WARNING: GATUS_CLOUDRUN_CONFIG_PATH should start with 'gs://'."
fi

if [[ ! "$GATUS_CLOUDRUN_DB_PATH" =~ ^gs:// ]]; then
    echo "WARNING: GATUS_CLOUDRUN_DB_PATH should start with 'gs://'."
fi

# Set default values for optional environment variables
export GATUS_CLOUDRUN_DB_ALLOW_NOT_FOUND=${GATUS_CLOUDRUN_DB_ALLOW_NOT_FOUND:-1}
export GATUS_CLOUDRUN_GCS_TIMEOUT=${GATUS_CLOUDRUN_GCS_TIMEOUT:-60}

# Set up signal handler
trap sigterm_handler SIGTERM
trap sigterm_handler SIGINT


# Get the Gatus configuration file
./bin/config.sh || exit 1

# Get the Gatus database file
RES=0
echo "Getting the Gatus database file from ${GATUS_CLOUDRUN_DB_PATH}..."
if [[ "$GATUS_CLOUDRUN_CONFIG_PATH" =~ ^gs:// ]]; then
    timeout ${GATUS_CLOUDRUN_GCS_TIMEOUT} gsutil cp "${GATUS_CLOUDRUN_DB_PATH}" "${APP_DIR}/data/data.db" 
    RES=$?
else
    cp -f "${GATUS_CLOUDRUN_DB_PATH}" "${APP_DIR}/data/data.db" 2>/dev/null
    RES=$?
fi
if [ $RES -ne 0 ]; then
    if [ "$GATUS_CLOUDRUN_DB_ALLOW_NOT_FOUND" -eq "0" ]; then
        echo "Error: No Gatus database file found and GATUS_CLOUDRUN_DB_ALLOW_NOT_FOUND is set to 0. Exiting."
        exit 1
    else
        echo "WARNING: Can't get a Gatus database file but GATUS_CLOUDRUN_DB_ALLOW_NOT_FOUND != 0 => let's continue" 
    fi
else
    echo "Done"
fi

# Launch the scheduler in the background
./bin/scheduler.sh &
SCHEDULER_PID=$!

# Run Gatus
./bin/gatus "${APP_DIR}/config/config.yml" &
GATUS_PID=$!

while true; do
    if ! kill -0 "$GATUS_PID" 2>/dev/null; then
        echo "Gatus process has stopped. Exiting."
        kill -15 "$SCHEDULER_PID" 2>/dev/null
    fi
    if ! kill -0 "$SCHEDULER_PID" 2>/dev/null; then
        echo "Scheduler process has stopped. Exiting."
        break
    fi
    sleep 1
done

kill -15 "$GATUS_PID" 2>/dev/null
while true; do
    if ! kill -0 "$GATUS_PID" 2>/dev/null; then
        echo "Gatus process has stopped. Exiting."
        break
    fi
    sleep 1
done

./bin/backup.sh || exit 1
echo "Exited"

