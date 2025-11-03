# gatus-cloudrun

## What is it?

This is a very opinionated docker image for running [Gatus](https://github.com/TwiN/gatus), a monitoring tool for uptime, latency, and status page on GCP / CloudRun.

## Main (opinionated) ideas

- This docker image is made to be run on CloudRun with:
    - min_instances = 1
    - max_instances = 1
    - cpu_always_allocated = true

- The Gatus configuration is stored in a GCP / CloudStorage bucket:
    - The configuration is read at startup
    - The configuration is checked for changes every 5 minutes
    - If the configuration has changed, the container is stopped (and restarted by CloudRun)

- The Gatus database is stored in a GCP / CloudStorage bucket as a SQLite file:
    - The database is read at startup (and copied to the container filesystem)
    - The database is saved every minute in the same bucket in GCS

- Occasionally (during an update, for example), we may have more than one instance running:
    - So we can have a concurrency issues when reading/saving the SQLite database in the GCS bucket
    - **We accept loosing one minute or two of data (as it's a rare event)** 

## Config

- (*) `GATUS_CLOUDRUN_CONFIG_PATH`: gsutil path to the Gatus configuration file, should start with `gs://`
- (*) `GATUS_CLOUDRUN_DB_PATH`: gsutil path to the Gatus database file, should start with `gs://`
- `GATUS_CLOUDRUN_DB_ALLOW_NOT_FOUND`: allow the database file to not be found (default to `1`, means yes) => use it only for the first run (after, when the database file is created and uploaded to the GCS bucket, set it to `0`)
- `GATUS_CLOUDRUN_GCS_TIMEOUT`: timeout for the GCS operations, in seconds, default to `60`

(*) means that the variable is required
