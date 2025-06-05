#!/bin/bash

if [[ $KEEP_OLD_FILES_DAYS == "" ]]; then
    if [[ $KEEP_OLD_FILES_MINUTES == "" ]]; then
        echo "skipping old file deletions"
    else
        echo "deleting old files"
        find /usr/files -mmin +$KEEP_OLD_FILES_MINUTES -exec rm -f {} \;
    fi
else
    echo "deleting old files"
    find /usr/files -mtime +$KEEP_OLD_FILES_DAYS -exec rm -f {} \;
fi

if [[ $MONGO_HOST == "" ]]; then
    echo "Mongo db host not found"
    exit 1
fi

if [[ $MONGO_PORT == "" ]]; then
    echo "Trying default mongo port: 27017"
    MONGO_PORT=27017
fi

dateString="$(date +%d-%m-%Y-%H_%M_%S)"
path=/usr/files/
filename=$(echo mongodump_$dateString.zip)
echo "Creating $path$filename"

args=("--host" "$MONGO_HOST" "--port" "$MONGO_PORT" "--archive=$path$filename" "--gzip")

if [[ $AUTH_DB == "" ]]; then
    echo "Setting default authentication database as 'admin'"
    AUTH_DB=admin
fi

if [[ $MONGO_USER != "" && $MONGO_PASSWORD != "" ]]; then
    args+=("--username" "$MONGO_USER" "--password" "$MONGO_PASSWORD" "--authenticationDatabase=$AUTH_DB")
else
    echo "Skipping user authentication"
fi

# Check S3 environment variables
if [[ -z "$ACCESS_KEY_ID" || -z "$SECRET_ACCESS_KEY" || -z "$ENDPOINT" || -z "$BUCKET_NAME" ]]; then
    echo "Error: Missing required S3 environment variables (ACCESS_KEY_ID, SECRET_ACCESS_KEY, ENDPOINT, BUCKET_NAME)"
    exit 1
fi

# Configure s3cmd for custom endpoint
mkdir -p ~/.s3cmd
cat <<EOL > ~/.s3cfg
[default]
access_key = $ACCESS_KEY_ID
secret_key = $SECRET_ACCESS_KEY
host_base = ${ENDPOINT#https://}
host_bucket = ${ENDPOINT#https://}
use_https = True
bucket_location = ${DEFAULT_REGION:-us-east-1}
multipart_chunk_size_mb = 5
EOL

echo "Running mongodump and s3 push"
# Run mongodump
if mongodump "${args[@]}"; then
    echo "mongodump succeeded"
else
    echo "mongodump failed"
    if [[ -n "$HEALTHCHECK_IO_CHECK_URL" ]]; then
        curl --retry 3 "$HEALTHCHECK_IO_CHECK_URL/fail"
    fi
    exit 1
fi

# Debug s3cmd version
echo "s3cmd version: $(s3cmd --version)"

# Run S3 upload with progress in console
if s3cmd put "$path$filename" s3://$BUCKET_NAME/$BUCKET_PATH/$filename --progress; then
    echo "Backup succeeded"
    if [[ -n "$HEALTHCHECK_IO_CHECK_URL" ]]; then
        curl -m 10 --retry 5 "$HEALTHCHECK_IO_CHECK_URL"
    fi
else
    echo "Backup failed"
    if [[ -n "$HEALTHCHECK_IO_CHECK_URL" ]]; then
        curl --retry 3 "$HEALTHCHECK_IO_CHECK_URL/fail"
    fi
    exit 1
fi

# node ./deleteOldBackupsFromS3.js