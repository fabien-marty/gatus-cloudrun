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
- `GATUS_CLOUDRUN_GCS_TIMEOUT`: timeout for the GCS operations, in seconds, default to `120`

(*) means that the variable is required

Note: you can use this `config.yml` file as a basic example of the Gatus configuration file:

```yaml
endpoints:
  - name: google
    url: "https://google.com/"
    interval: 1m
    conditions:
      - "[STATUS] == 200"

# The storage MUST be a SQLite database located in /app/data/data.db
storage:
  type: sqlite
  path: /app/data/data.db
```

Cloud Run non-default settings:
- Container image url: `docker.io/fabienmarty/gatus-cloudrun:0.0.0.post8.dev0_84db63b` (change the version of course)
- Authentication: "Allow public access"
- Billing: instance-based (very important!)
- Minimum number of instances: 1
- Maximum number of instances: 1
- `GATUS_CLOUDRUN_CONFIG_PATH`, `GATUS_CLOUDRUN_DB_PATH`, `GATUS_CLOUDRUN_DB_ALLOW_NOT_FOUND` must be set as environment variables

Note: we produce also a "by week" backup file in the GCS bucket, in the same bucket as the database file, with the name `${GATUS_CLOUDRUN_DB_PATH}.week${WEEK}`, where `WEEK` is the current week number.
