#!/bin/sh
[ -z "$CRON_EXPRESSION" ] && { echo "CRON_EXPRESSION not set" >&2; exit 1; }
mkdir -p /etc/crontabs
echo "$CRON_EXPRESSION root bash /usr/local/bin/awesomescript.sh" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root
cron -L 8 -f