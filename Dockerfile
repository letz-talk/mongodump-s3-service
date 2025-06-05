# Используем официальный образ Ubuntu как основу
FROM ubuntu:20.04

# Устанавливаем переменные окружения для избежания интерактивных запросов
ENV DEBIAN_FRONTEND=noninteractive

# Устанавливаем необходимые пакеты
RUN apt-get update && apt-get install -y \
    s3cmd \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Копируем sh-скрипт в контейнер
COPY awesomescript.sh /usr/local/bin/awesomescript.sh
COPY setcron.sh /usr/local/bin/setcron.sh
COPY instant.sh /usr/local/bin/instant.sh

# Делаем скрипт исполняемым
RUN chmod +x /usr/local/bin/awesomescript.sh

# Указываем точку входа
ENTRYPOINT ["/usr/local/bin/setcron.sh"]