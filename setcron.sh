#!/bin/sh
# Часовой пояс контейнера: CRON_EXPRESSION задаётся в этом поясе (по умолчанию +07)
ln -sf "/usr/share/zoneinfo/${CRON_TZ:-Asia/Bangkok}" /etc/localtime

# У cron пустое окружение: сохраняем нужные переменные в файл с правами 600,
# скрипт сам его подхватит. В crontab (и в логи) секреты больше не попадают.
umask 077
env | grep -E '^(MONGO_HOST|MONGO_PORT|MONGO_USER|MONGO_PASSWORD|AUTH_DB|REPLICA_SET|READ_PREFERENCE|ACCESS_KEY_ID|SECRET_ACCESS_KEY|ENDPOINT|DEFAULT_REGION|BUCKET_NAME|BUCKET_PATH|BACKUP_NAME|MIN_DUMP_SIZE_MB|UPLOAD_ATTEMPTS|KEEP_OLD_FILES_MINUTES|HEALTHCHECK_IO_CHECK_URL)=' \
    | sed -E "s/'/'\\\\''/g; s/^([A-Z_]+)=(.*)$/\1='\2'/" > /etc/backup.env

echo "PATH=/usr/local/bin:/usr/bin:/bin" > /tmp/crontab
echo "$CRON_EXPRESSION /bin/bash /usr/local/bin/awesomescript.sh --cron" >> /tmp/crontab
crontab -u root /tmp/crontab

echo "backup cron installed: $CRON_EXPRESSION ($(date +%Z)), target $MONGO_HOST, s3 ${BUCKET_PATH:-mongodump/$BACKUP_NAME}"

exec cron -f
