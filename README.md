## mongodump-s3-service

Дамп MongoDB (replica set `dbrs`, чтение с secondary) по cron → gzip-архив → Backblaze B2 (`backup-letz`).

- Архивы: `s3://backup-letz/mongodump/<BACKUP_NAME>/mongodump_<UTC>.archive.gz`
- Результат последнего запуска: `s3://backup-letz/mongodump/<BACKUP_NAME>/status.json`
  (`result`: `ok` / `dump_failed` / `too_small` / `upload_failed`, `error`, `sizeBytes`).
  Его и свежесть архивов проверяет `chat_health` (BackupCheck) и шлёт алерты в Telegram.
- Хранение: lifecycle-правило бакета на префикс `mongodump/` — скрытие через 3 дня, удаление через 1 день после скрытия,
  незавершённые multipart-загрузки отменяются через 1 день. Скрипт сам в S3 ничего не удаляет.
- Сервис запущен на `letztalk-prod-fin-1` и `letztalk-pay-se-1`: **бэкап каждый час**, каждый сервер — раз в 2 часа
  (fin — чётные часы UTC `0 */2 * * *`, pay — нечётные `0 1-23/2 * * *`). Дамп ~5 ГБ идёт 25–55 мин с secondary (health),
  загрузка в S3 ещё 4–10 мин; параллельный запуск на одном сервере исключён lock-файлом.
  chat_health тревожит, если с сервера нет нового архива дольше 4 ч или во всём бакете — дольше 3 ч.

Запуск: `docker compose up -d --build` (переменные — см. `.sample.env`).

Бэкап вне расписания: `docker exec mongodump-s3-service_bck_service_1 instant.sh`

Восстановление: скачать архив и `mongorestore --uri ... --gzip --archive=<file>` (см. `restore/`).

Сеть `letztalk_network` — зашифрованный overlay: между узлами swarm должен быть разрешён протокол ESP
(`ufw allow proto esp from <ip узла>`), иначе контейнеры на разных серверах не видят друг друга.
