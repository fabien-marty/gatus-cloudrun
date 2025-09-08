#!/bin/bash

# Very basic scheduler that runs the config and backup scripts every minute

STOP=0

# Handle SIGTERM gracefully
sigterm_handler() {
    echo "Received SIGTERM, let's stop the scheduler..."
    STOP=1
}

# Set up signal handler
trap sigterm_handler SIGTERM


cd "${APP_DIR}" || exit 1

while [ "$STOP" -eq "0" ]; do
    COUNT=0
    while [ "$STOP" -eq "0" ] && [ "$COUNT" -lt "60" ]; do
      sleep 1
      COUNT=$((COUNT + 1))
    done
    if [ "$STOP" -eq "0" ]; then
      ./bin/config.sh
      RES=$?
      if [ $RES -ne 0 ]; then
        # No changes in the Gatus configuration file, let's backup the database
        ./bin/backup.sh
      fi
    fi
done

echo "Scheduler stopped"
