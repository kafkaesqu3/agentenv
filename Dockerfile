# syntax=docker/dockerfile:1
ARG BASE_IMAGE=node:24-trixie-slim
FROM ${BASE_IMAGE}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo ca-certificates \
    && groupmod --new-name agent node \
    && usermod --login agent --home /home/agent --move-home --shell /bin/bash node \
    && printf 'agent ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent \
    && visudo -cf /etc/sudoers.d/agent \
    && mkdir -p /workspace \
    && chown agent:agent /workspace \
    && rm -rf /var/lib/apt/lists/*

COPY . /opt/agentenv/
RUN chmod 0755 /opt/agentenv/docker/entrypoint.sh

ENV HOME=/home/agent \
    NPM_CONFIG_PREFIX=/home/agent/.local \
    PATH=/home/agent/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
USER agent
WORKDIR /workspace
RUN bash /opt/agentenv/install.sh \
    && /opt/agentenv/docker/entrypoint.sh bash /opt/agentenv/doctor.sh \
    && npm cache clean --force \
    && rm -rf /home/agent/.cache /home/agent/.codex/tmp \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/opt/agentenv/docker/entrypoint.sh"]
CMD ["bash"]
