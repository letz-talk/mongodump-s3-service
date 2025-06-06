#!/bin/sh
echo "$CRON_EXPRESSION root bash /usr/local/bin/awesomescript.sh" > /etc/cron.d/mytask
echo "" >> /etc/cron.d/mytask
chmod 0644 /etc/cron.d/mytask
echo "Cron job installed: $(cat /etc/cron.d/mytask)"
cron -L 8 -f