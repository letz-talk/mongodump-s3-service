#!/bin/bash

# Определение переменных
MONGO_URI="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/admin?authSource=${AUTH_DB}"
ARCHIVE_PATH="./mongodump_26-06-2024-20_00_01.zip"

echo "Начало процесса восстановления MongoDB из архива $ARCHIVE_PATH..."

# Выполнение команды mongorestore
mongorestore --uri "$MONGO_URI" --gzip --archive="$ARCHIVE_PATH" --nsExclude="*.system.*" --nsInclude="*" --nsFrom="admin.*" --nsTo="admin.*"

# Проверка статуса выполнения команды mongorestore
if [ $? -eq 0 ]; then
    echo "Восстановление успешно завершено."
else
    echo "Произошла ошибка при восстановлении базы данных."
fi

# Завершение скрипта
echo "Скрипт выполнен."