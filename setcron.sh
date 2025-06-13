#!/bin/sh
mkdir -p /etc/crontabs

# Устанавливаем PATH для cron
CRON_PATH="/usr/local/bin:/usr/bin:/bin"

# Формируем cron-задание с выражением */20 * * * * и всеми переменными
echo "*/5 * * * * root PATH=$CRON_PATH; env KEEP_OLD_FILES_DAYS=$KEEP_OLD_FILES_DAYS KEEP_OLD_FILES_MINUTES=$KEEP_OLD_FILES_MINUTES MONGO_HOST=$MONGO_HOST MONGO_PORT=$MONGO_PORT MONGO_USER=$MONGO_USER MONGO_PASSWORD=$MONGO_PASSWORD AUTH_DB=$AUTH_DB ACCESS_KEY_ID=$ACCESS_KEY_ID SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY ENDPOINT=$ENDPOINT BUCKET_NAME=$BUCKET_NAME DEFAULT_REGION=$DEFAULT_REGION BUCKET_PATH=$BUCKET_PATH HEALTHCHECK_IO_CHECK_URL=$HEALTHCHECK_IO_CHECK_URL /bin/bash /usr/local/bin/awesomescript.sh >> /tmp/cron_output 2>&1" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root

# Проверяем содержимое crontab
echo "Cron job installed: $(cat /etc/crontabs/root)"

# Добавляем отладку окружения
echo "Environment at setcron.sh startup:" >> /tmp/cron_output
env >> /tmp/cron_output

# Запускаем cron с максимальным логированием
cron -L 15 -f