FROM node:alpine

# set working directory
WORKDIR /usr/local/bin

COPY package*.json ./
COPY awesomescript.sh myawesomescript.sh
COPY setcron.sh setcron.sh

COPY instant.sh instant

COPY . .

# Set permissions after all COPY operations
RUN chmod +x instant
RUN chmod +x myawesomescript.sh
RUN chmod +x setcron.sh
# Ensure crontab file is accessible
RUN touch /etc/crontabs/root && chmod 0644 /etc/crontabs/root

RUN apk add bash

RUN echo "Install System dependencies" && \
    apk add --no-cache

RUN apk add --no-cache tzdata

RUN echo "Install MongoDB dependencies" && \
    apk add \
    mongodb-tools

RUN echo "Install Curl as dependency" && \
    apk add \
    curl

RUN echo "Install aws-cli" && \
    apk add \
    --no-cache py3-pip groff less mailcap && \
    pip install awscli==2.22.30 --break-system-packages

RUN npm install

RUN rm /var/cache/apk/*

CMD setcron.sh
