FROM node:alpine

# set working directory
WORKDIR /usr/local/bin

COPY package*.json ./
COPY awesomescript.sh myawesomescript.sh
COPY setcron.sh setcron.sh

COPY instant.sh instant

RUN chmod +x instant
RUN chmod +x myawesomescript.sh
RUN chmod +x setcron.sh

RUN apk add bash

RUN echo "Install System dependencies" && \
    apk add --no-cache

RUN apk add --no-cache tzdata

RUN echo "Install MongoDB dependencies" && \
    apk add --no-cache mongodb-tools

RUN echo "Install Curl as dependency" && \
    apk add --no-cache curl

RUN echo "Install aws-cli" && \
    apk add --no-cache aws-cli

RUN npm install

COPY . .

RUN rm /var/cache/apk/*

CMD setcron.sh
