#!/bin/sh
mkdir -p /etc/crontabs
echo "*/1 * * * * root bash /usr/local/bin/awesomescript.sh" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root
echo "Cron job installed: $(cat /etc/crontabs/root)"
cron -L 8 -f