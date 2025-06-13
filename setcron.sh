#!/bin/sh
mkdir -p /etc/crontabs

# Устанавливаем часовой пояс +07
ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime

# Устанавливаем PATH для cron
CRON_PATH="/usr/local/bin:/usr/bin:/bin"

# Создаём временный файл для crontab
echo "PATH=$CRON_PATH" > /tmp/crontab
echo "*/2 * * * * env KEEP_OLD_FILES_DAYS=$KEEP_OLD_FILES_DAYS KEEP_OLD_FILES_MINUTES=$KEEP_OLD_FILES_MINUTES MONGO_HOST=$MONGO_HOST MONGO_PORT=$MONGO_PORT MONGO_USER=$MONGO_USER MONGO_PASSWORD=$MONGO_PASSWORD AUTH_DB=$AUTH_DB ACCESS_KEY_ID=$ACCESS_KEY_ID SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY ENDPOINT=$ENDPOINT BUCKET_NAME=$BUCKET_NAME DEFAULT_REGION=$DEFAULT_REGION BUCKET_PATH=$BUCKET_PATH HEALTHCHECK_IO_CHECK_URL=$HEALTHCHECK_IO_CHECK_URL /bin/bash /usr/local/bin/awesomescript.sh" >> /tmp/crontab
echo "* * * * * echo 'Cron test at $(date)' >> /proc/1/fd/1" >> /tmp/crontab

# Устанавливаем crontab для root
crontab -u root /tmp/crontab

# Проверяем, что crontab установлен
echo "Cron job installed:" >> /proc/1/fd/1
crontab -u root -l >> /proc/1/fd/1

# Добавляем отладку окружения
echo "Environment at setcron.sh startup:" >> /proc/1/fd/1
env >> /proc/1/fd/1

# Запускаем cron с максимальным логированием
cron -L 15 -f >> /proc/1/fd/1 2>> /proc/1/fd/2