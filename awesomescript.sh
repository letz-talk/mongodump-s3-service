#!/bin/bash
# Дамп MongoDB (replica set) -> gzip-архив -> S3 (Backblaze B2).
#
# Результат каждого запуска пишется в s3://$BUCKET_NAME/$BUCKET_PATH/status.json —
# по нему и по свежести архивов chat_health шлёт алерты в Telegram.
# Хранение старых архивов — lifecycle-правило бакета на префикс mongodump/ (скрытие через 3 дня),
# сам скрипт в S3 ничего не удаляет.
#
# Секреты в лог не печатаются (раньше скрипт делал `env` и светил пароли в docker logs).

# При запуске из cron (--cron) пишем в docker logs; при ручном запуске (instant) — в консоль.
if [[ "$1" == "--cron" ]]; then
    exec 1>>/proc/1/fd/1
    exec 2>>/proc/1/fd/2
fi

# env, сохранённый setcron.sh (у cron своё пустое окружение)
if [[ -f /etc/backup.env ]]; then
    set -a
    # shellcheck disable=SC1091
    source /etc/backup.env
    set +a
fi

log() {
    echo "[backup $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

# Lock: не даём запускать два дампа параллельно (cron + instant)
LOCKFILE=/tmp/mongodump.lock
if [[ -f $LOCKFILE ]]; then
    pid=$(cat "$LOCKFILE" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        log "another backup is already running (PID $pid), exiting"
        exit 1
    fi
    rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

FILES_DIR=/usr/files
BACKUP_NAME=${BACKUP_NAME:-$(hostname)}
BUCKET_PATH=${BUCKET_PATH:-mongodump/$BACKUP_NAME}
BUCKET_PATH=${BUCKET_PATH#/}
BUCKET_PATH=${BUCKET_PATH%/}
MIN_DUMP_SIZE_MB=${MIN_DUMP_SIZE_MB:-100}
UPLOAD_ATTEMPTS=${UPLOAD_ATTEMPTS:-3}
S3_DEST="s3://$BUCKET_NAME/$BUCKET_PATH"
S3CFG=/root/.s3cfg

if [[ -z "$MONGO_HOST" ]]; then
    log "MONGO_HOST is not set"
    exit 1
fi
if [[ -z "$ACCESS_KEY_ID" || -z "$SECRET_ACCESS_KEY" || -z "$ENDPOINT" || -z "$BUCKET_NAME" ]]; then
    log "missing S3 variables (ACCESS_KEY_ID, SECRET_ACCESS_KEY, ENDPOINT, BUCKET_NAME)"
    exit 1
fi

umask 077
cat > "$S3CFG" <<EOL
[default]
access_key = $ACCESS_KEY_ID
secret_key = $SECRET_ACCESS_KEY
host_base = ${ENDPOINT#https://}
host_bucket = ${ENDPOINT#https://}
use_https = True
bucket_location = ${DEFAULT_REGION:-us-east-1}
multipart_chunk_size_mb = 100
EOL

STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# status.json: {"name","startedAt","finishedAt","result","error","file","sizeBytes"}
write_status() {
    local result=$1 error=$2 file=$3 size=${4:-0}
    error=${error//\\/\\\\}
    error=${error//\"/\\\"}
    error=$(echo -n "$error" | tr '\n\r\t' '   ' | cut -c1-500)
    printf '{"name":"%s","startedAt":"%s","finishedAt":"%s","result":"%s","error":"%s","file":"%s","sizeBytes":%s}\n' \
        "$BACKUP_NAME" "$STARTED_AT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$result" "$error" "$file" "$size" > /tmp/status.json
    if ! s3cmd -c "$S3CFG" --no-progress put /tmp/status.json "$S3_DEST/status.json" >/dev/null 2>/tmp/status_err.txt; then
        log "WARNING: cannot upload status.json: $(tail -1 /tmp/status_err.txt)"
    fi
}

fail() {
    log "FAILED ($1): $2"
    write_status "$1" "$2" "$3" "$4"
    exit 1
}

# Локальные архивы держим только до загрузки: на серверах мало места
mkdir -p "$FILES_DIR"
find "$FILES_DIR" -mindepth 1 -maxdepth 1 -type f -mmin +"${KEEP_OLD_FILES_MINUTES:-60}" -delete

# Хосты: "h1:27017,h2:27017" или один хост + MONGO_PORT.
# Подключаемся к replica set и читаем с secondary (не грузим primary); если secondary нет — с primary.
HOSTS=$MONGO_HOST
if [[ "$HOSTS" != *:* ]]; then
    HOSTS="$HOSTS:${MONGO_PORT:-27017}"
fi
URI="mongodb://$HOSTS/?authSource=${AUTH_DB:-admin}&readPreference=${READ_PREFERENCE:-secondaryPreferred}&compressors=zstd,snappy,zlib"
if [[ -n "$REPLICA_SET" ]]; then
    URI="$URI&replicaSet=$REPLICA_SET"
fi

filename="mongodump_$(date -u +%Y-%m-%dT%H-%M)Z.archive.gz"
filepath="$FILES_DIR/$filename"

log "dump $HOSTS (replicaSet=${REPLICA_SET:-none}, readPreference=${READ_PREFERENCE:-secondaryPreferred}) -> $filepath"
args=(--uri "$URI" --archive="$filepath" --gzip --quiet)
if [[ -n "$MONGO_USER" && -n "$MONGO_PASSWORD" ]]; then
    args+=(--username "$MONGO_USER" --password "$MONGO_PASSWORD")
fi
DUMP_START=$(date +%s)
if ! /usr/bin/mongodump "${args[@]}" 2>/tmp/mongodump_err.txt; then
    err=$(grep -v -i password /tmp/mongodump_err.txt | tail -3)
    rm -f "$filepath"
    fail dump_failed "mongodump: $err" "$filename"
fi
size=$(stat -c %s "$filepath")
log "dump done in $(( $(date +%s) - DUMP_START ))s, size $(( size / 1024 / 1024 ))MB"
if (( size < MIN_DUMP_SIZE_MB * 1024 * 1024 )); then
    rm -f "$filepath"
    fail too_small "dump is only $(( size / 1024 / 1024 ))MB (< ${MIN_DUMP_SIZE_MB}MB)" "$filename" "$size"
fi

UPLOAD_START=$(date +%s)
uploaded=0
for attempt in $(seq 1 "$UPLOAD_ATTEMPTS"); do
    # --no-progress: прогресс-бар писал в docker logs гигантские строки, из-за которых docker logs переставал читаться
    if s3cmd -c "$S3CFG" --no-progress put "$filepath" "$S3_DEST/$filename" >/tmp/s3_out.txt 2>&1; then
        uploaded=1
        break
    fi
    log "upload attempt $attempt failed: $(grep -i error /tmp/s3_out.txt | tail -1)"
    sleep 30
done
if (( ! uploaded )); then
    err=$(grep -i error /tmp/s3_out.txt | tail -1)
    rm -f "$filepath"
    fail upload_failed "s3: $err" "$filename" "$size"
fi
rm -f "$filepath"
log "uploaded $S3_DEST/$filename in $(( $(date +%s) - UPLOAD_START ))s"
write_status ok "" "$filename" "$size"
log "backup succeeded"

# Совместимость: внешний healthchecks.io-пинг, если задан
if [[ -n "$HEALTHCHECK_IO_CHECK_URL" ]]; then
    curl -fsS -m 10 --retry 5 "$HEALTHCHECK_IO_CHECK_URL" >/dev/null || true
fi
