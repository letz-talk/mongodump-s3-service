#!/bin/sh
mkdir -p /etc/crontabs
echo "$CRON_EXPRESSION root AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY MONGO_URI=$MONGO_URI bash /usr/local/bin/awesomescript.sh" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root
echo "Cron job installed: $(cat /etc/crontabs/root)"
cron -L 8 -f