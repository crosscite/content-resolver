FROM phusion/passenger-full:0.9.30
LABEL maintainer="mfenner@datacite.org"

# Set correct environment variables.
ENV HOME /home/app
ENV DOCKERIZE_VERSION v0.2.0

# Allow app user to read /etc/container_environment
RUN usermod -a -G docker_env app

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# Install Ruby 2.4.4.
RUN bash -lc 'rvm --default use ruby-2.4.4'

# Update installed APT packages
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get install ntp wget tzdata -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install dockerize
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Remove unused SSH keys
RUN rm -rf /etc/my_init.d/00_regen_ssh_host_keys.sh

# Enable Passenger and Nginx and remove the default site
# Preserve env variables for nginx
RUN rm -f /etc/service/nginx/down && \
    rm /etc/nginx/sites-enabled/default && \
    rm /etc/nginx/nginx.conf

COPY vendor/docker/webapp.conf /etc/nginx/sites-enabled/webapp.conf
COPY vendor/docker/00_app_env.conf /etc/nginx/conf.d/00_app_env.conf
COPY vendor/docker/70_templates.sh /etc/my_init.d/70_templates.sh

# Use Amazon NTP servers
COPY vendor/docker/ntp.conf /etc/ntp.conf

# Install Ruby gems
COPY Gemfile* /home/app/webapp/
WORKDIR /home/app/webapp
RUN mkdir -p vendor/bundle && \
    chown -R app:app . && \
    chmod -R 755 . && \
    gem update --system && \
    gem install bundler && \
    /sbin/setuser app bundle install --path vendor/bundle

# Install Ruby gems for middleman
COPY vendor/middleman/Gemfile* /home/app/webapp/vendor/middleman/
WORKDIR /home/app/webapp/vendor/middleman
RUN /sbin/setuser app bundle install

# Copy webapp folder
WORKDIR /home/app/webapp
COPY . /home/app/webapp/
RUN mkdir -p tmp/pids && \
    mkdir -p tmp/storage && \
    chown -R app:app /home/app/webapp && \
    chmod -R 755 /home/app/webapp

# Run additional scripts during container startup (i.e. not at build time)
RUN mkdir -p /etc/my_init.d
COPY vendor/docker/10_enable_ssh.sh /etc/my_init.d/10_enable_ssh.sh
COPY vendor/docker/60_index_page.sh /etc/my_init.d/70_index_page.sh
COPY vendor/docker/80_flush_cache.sh /etc/my_init.d/80_flush_cache.sh

# Expose web
EXPOSE 80
