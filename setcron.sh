#!/bin/sh
echo "$CRON_EXPRESSION bash /usr/local/bin/awesomescript.sh" > /etc/crontabs/root
crond -S -l 0 -f