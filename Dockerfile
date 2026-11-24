# syntax=docker/dockerfile:1
ARG BASE_IMAGE=docker.io/dhi/sbx-templates:shell@sha256:41e7871fbea57dedcac15353f983b93d5fc584684577466e8eae4da160e3189e
FROM ${BASE_IMAGE}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends fd-find \
    && install -d -o agent -g agent /workspace \
    && rm -rf /var/lib/apt/lists/*

COPY . /opt/agentenv/
RUN chmod 0755 /opt/agentenv/docker/entrypoint.sh \
    && install -m 0755 /opt/agentenv/docker/claude-yolo /opt/agentenv/docker/codex-yolo /usr/local/bin/

ENV HOME=/home/agent \
    NPM_CONFIG_PREFIX=/home/agent/.local \
    PATH=/home/agent/.local/bin:${PATH}
USER agent
WORKDIR /workspace
RUN node /opt/agentenv/lib/tools-env.mjs \
    && npm_config_allow_scripts=@opencode/cli bash /opt/agentenv/install.sh --skip-tools \
    && /opt/agentenv/docker/entrypoint.sh bash /opt/agentenv/doctor.sh \
    && rm -rf /home/agent/.npm/_cacache /home/agent/.cache /home/agent/.codex/tmp

ENTRYPOINT ["/opt/agentenv/docker/entrypoint.sh"]
CMD ["bash"]
