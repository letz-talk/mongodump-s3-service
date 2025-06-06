#!/bin/bash

# Check if CRON_EXPRESSION is set
[ -z "$CRON_EXPRESSION" ] && { echo "Error: CRON_EXPRESSION not set"; exit 1; }

# Write cron job to /etc/cron.d/mytask
echo "$CRON_EXPRESSION root bash /usr/local/bin/awesomescript.sh >> /var/log/awesomescript.log 2>&1" > /etc/cron.d/mytask

# Start rsyslog and cron
service rsyslog start
exec cron -f