#!/bin/bash

# Check if CRON_EXPRESSION is set
[ -z "$CRON_EXPRESSION" ] && { echo "Error: CRON_EXPRESSION not set"; exit 1; }

# Write cron job to /etc/cron.d/mytask
echo "$CRON_EXPRESSION root bash /usr/local/bin/awesomescript.sh" > /etc/cron.d/mytask

# Start cron in foreground
exec cron -f