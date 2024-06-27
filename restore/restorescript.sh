#!/bin/bash

# Определение переменных
MONGO_HOST=${MONGO_HOST}
MONGO_PORT=${MONGO_PORT}
AUTH_DB=${AUTH_DB}
MONGO_USER=${MONGO_USER}
MONGO_PASSWORD=${MONGO_PASSWORD}
MONGO_URI="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/admin?authSource=${AUTH_DB}"
ARCHIVE_PATH="/usr/files/mongodump_26-06-2024-20_00_01.zip"

echo "Начало процесса восстановления MongoDB из архива $ARCHIVE_PATH..."

# Выполнение команды mongorestore
mongorestore --uri "$MONGO_URI" --gzip --archive="$ARCHIVE_PATH" --nsExclude="*.system.*" --nsInclude="*" --nsFrom="admin.*" --nsTo="admin.*" 2>error_log.txt

# Проверка статуса выполнения команды mongorestore
if [ $? -eq 0 ]; then
    echo "Восстановление успешно завершено."
else
    echo "Произошла ошибка при восстановлении базы данных. Подробности ошибки:"
    cat error_log.txt
fi

# Завершение скрипта
echo "Скрипт выполнен."