#!/bin/bash
echo "Setting up cron with expression: $CRON_EXPRESSION"
echo "$CRON_EXPRESSION bash /usr/local/bin/awesomescript.sh" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root
crond -S -l 0 -f
