FROM hexpm/elixir:1.20.4-erlang-29.0.6-ubuntu-resolute-20260811.1

# Set build arguments
ARG USERNAME="devc"
ARG ADDITIONAL_PACKAGES="inotify-tools iputils-ping dnsutils postgresql-client make"

# `apt clean` empties the .deb cache but keeps /var/lib/apt/lists, which post-create.sh's
# dependency check needs: it calls `apt-get install -s`, and that resolves names against the lists.
RUN apt update && \
    apt install -y $ADDITIONAL_PACKAGES && \
    apt clean

# Rename the stock uid-1000 `ubuntu` user (inherited from the Ubuntu base image) to "devc".
# NOTE: this depends on the base image shipping that user. If BUILD_OS ever moves to an image
# without one, this fails and the user must be created here instead (useradd)
RUN usermod -l $USERNAME -d /home/$USERNAME -m ubuntu && \
    groupmod -n $USERNAME ubuntu

# Where the repo gets mounted. Must match `workspaceFolder` in devcontainer.json and the bind
# mount in docker-compose.yaml.
ARG WORKSPACE_DIR=/workspaces/pax

# Install Hex and Rebar
USER $USERNAME
RUN mix local.hex --force --if-missing && mix local.rebar --force --if-missing
USER root

WORKDIR $WORKSPACE_DIR
