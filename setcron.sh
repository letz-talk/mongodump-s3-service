#!/bin/bash

echo "Setting up cron with expression: $CRON_EXPRESSION"

# Check if CRON_EXPRESSION is set
if [ -z "$CRON_EXPRESSION" ]; then
    echo "Error: CRON_EXPRESSION is not set"
    exit 1
fi

# Write cron job to /etc/crontab
echo "$CRON_EXPRESSION root bash /usr/local/bin/awesomescript.sh" >> /etc/crontab

# Verify crontab content
cat /etc/crontab

# Start crond in foreground
exec cron -f -L 0