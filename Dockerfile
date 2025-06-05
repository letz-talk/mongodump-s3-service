FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    s3cmd \
    curl \
    mongodb-clients \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY awesomescript.sh /usr/local/bin/awesomescript.sh
COPY setcron.sh /usr/local/bin/setcron.sh
COPY instant.sh /usr/local/bin/instant.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/awesomescript.sh /usr/local/bin/setcron.sh /usr/local/bin/instant.sh

# Create crontab file
RUN mkdir -p /etc/cron.d && touch /etc/crontab && chmod 0644 /etc/crontab

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/setcron.sh"]