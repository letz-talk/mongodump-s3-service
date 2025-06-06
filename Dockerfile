FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    s3cmd \
    curl \
    cron \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install mongodb-database-tools compatible with MongoDB 5.0
RUN wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2004-x86_64-100.5.0.deb && \
    dpkg -i mongodb-database-tools-*.deb && \
    rm mongodb-database-tools-*.deb

# Copy scripts
COPY awesomescript.sh /usr/local/bin/awesomescript.sh
COPY setcron.sh /usr/local/bin/setcron.sh
COPY instant.sh /usr/local/bin/instant.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/awesomescript.sh /usr/local/bin/setcron.sh /usr/local/bin/instant.sh

# Create crontab file
RUN mkdir -p /etc/crontabs && chmod 0755 /etc/crontabs

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/setcron.sh"]