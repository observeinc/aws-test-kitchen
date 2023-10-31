# Fetch Terraform
FROM hashicorp/terraform:1.6@sha256:9ea0e6ed0e17da57ac1a5cc2ff0e5503e6eb90b8eeb6ca9808a9b345beba5d98 as terraform-source

# Your original Dockerfile starts here with some modifications
FROM ruby:3.2-bookworm@sha256:0520a5494639036a5fdc3a7328f7378d841c41a4347da57ffe51259cf1c9de06

# Copy Terraform binary from terraform-source
COPY --from=terraform-source /bin/terraform /usr/local/bin/

# Prevents prompting for time zone information
ARG DEBIAN_FRONTEND=noninteractive

# Update package list and install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    git \
    less \
    sudo && apt-get clean

# Accept the user ID and group ID as build arguments
ARG UID=1000
ARG GID=1000

# Create a group and user with the provided IDs, and create a home directory for the user
RUN groupadd -r observe -g ${GID} && \
    useradd -r -g observe -u ${UID} -m -d /home/observe -s /bin/bash observe && \
    chown -R observe:observe /home/observe

# Add the observe user to the sudoers file and disable password requirement
RUN echo "observe ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER observe

WORKDIR /tmp

# Install AWS CLI version 2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && sudo ./aws/install \
    && aws --version

# Copy your Gemfile and Gemfile.lock into the image
COPY Gemfile Gemfile.lock ./

# Install your gems
ENV BUNDLE_APP_CONFIG /home/observe/.bundle
RUN /bin/bash -l -c "bundle config network.retry 5" && \
    /bin/bash -l -c "bundle config --global no-document true" && \
    /bin/bash -l -c "bundle install --jobs $(nproc)" && \
    /bin/bash -l -c "bundle install --verbose" || \
    /bin/bash -l -c "bundle install --verbose"

# Set up the working directory
WORKDIR /workdir

USER observe
ENV PATH /usr/local/bundle/bin:$PATH
COPY validate_deps.sh ./
RUN /bin/bash -c -l ./validate_deps.sh

USER root
COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["entrypoint.sh"]
