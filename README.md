## mongodump-s3-service

Дамп MongoDB (replica set `dbrs`, чтение с secondary) по cron → gzip-архив → Backblaze B2 (`backup-letz`).

- Архивы: `s3://backup-letz/mongodump/<BACKUP_NAME>/mongodump_<UTC>.archive.gz`
- Результат последнего запуска: `s3://backup-letz/mongodump/<BACKUP_NAME>/status.json`
  (`result`: `ok` / `dump_failed` / `too_small` / `upload_failed`, `error`, `sizeBytes`).
  Его и свежесть архивов проверяет `chat_health` (BackupCheck) и шлёт алерты в Telegram.
- Хранение: lifecycle-правило бакета на префикс `mongodump/` — скрытие через 3 дня, удаление через 1 день после скрытия,
  незавершённые multipart-загрузки отменяются через 1 день. Скрипт сам в S3 ничего не удаляет.
- Сервис запущен на `letztalk-prod-fin-1` и `letztalk-pay-se-1` со сдвигом расписания на 6 часов
  (бэкап раз в 6 часов, с каждого сервера — раз в 12).

Запуск: `docker compose up -d --build` (переменные — см. `.sample.env`).

Бэкап вне расписания: `docker exec mongodump-s3-service_bck_service_1 instant.sh`

Восстановление: скачать архив и `mongorestore --uri ... --gzip --archive=<file>` (см. `restore/`).

Сеть `letztalk_network` — зашифрованный overlay: между узлами swarm должен быть разрешён протокол ESP
(`ufw allow proto esp from <ip узла>`), иначе контейнеры на разных серверах не видят друг друга.
