FROM node:alpine

# set working directory
WORKDIR /usr/local/bin

COPY restorescript.sh restorescript.sh

RUN chmod +x restorescript.sh

RUN apk add bash

RUN echo "Install System dependencies" && \
    apk add --update

RUN apk add --no-cache tzdata

RUN echo "Install MongoDB dependencies" && \
    apk add \
    mongodb-tools

RUN echo "Install Curl as dependency" && \
    apk add \
    curl

RUN rm /var/cache/apk/*

CMD restorescript.sh