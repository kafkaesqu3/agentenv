# agentenv-base Docker image

## Intent and constraints

Provide the shared golden image for every downstream agent environment. Include the existing shared tools, Claude Code, Codex, OpenCode, and their baseline configuration. Keep task-specific dependencies and workflows in downstream images. Do not embed credentials or host configuration.

The user selected Debian, the official Node Debian slim parent image, and a non-root `agent` runtime user with passwordless sudo.

## Approaches

Starting from Debian directly would require maintaining a separate Node installation path. Starting from the official Node Debian slim image supplies Node and npm and lets this repository reuse its installers. The user accepted the latter approach.

## Proposed implementation

- Add a root `Dockerfile`, a narrowly scoped `.dockerignore`, and a container entrypoint under `docker/`. Build the image as `agentenv-base`.
- Default to `node:24-trixie-slim`, keeping Node 24 aligned with the repository's existing macOS baseline. Allow overriding the parent through a build argument. The official Node image metadata lists this variant for amd64 and arm64; verify the resulting agent image on available platforms before claiming support.
- Reuse the existing image user identity as `agent`, with UID/GID 1000 and home `/home/agent`, avoiding a collision with the parent's `node` user. Configure and validate passwordless sudo. Use `/workspace` as the writable working directory and Bash as the default command.
- Extend the shared apt installer to preserve an existing working Node 22+ and npm installation; install distribution Node/npm when they are absent or unsuitable. Keep its final version check. This prevents a redundant Node installation in the image and remains useful for native hosts.
- Install shared tools and all agents under the intended runtime home, using sudo for system packages and a user-owned npm global prefix. Retain installer sources at `/opt/agentenv` and the generated version inventory in the agent's state directory. Clear build caches and apt lists.
- The entrypoint sources the shared environment and all three generated agent environments, then uses `exec` to preserve arguments, exit status, and signal delivery. It does not install or rewrite configuration at startup. Explicit configuration-directory overrides use the existing installer conventions; overriding homes requires provisioning the corresponding configuration first.
- Document interactive shells, direct agent commands, workspace mounts, explicit root execution, and downstream `FROM agentenv-base` usage. No registry publishing, authentication, launcher framework, or task-specific tooling is included in this change.

## Verification

Run the existing installer tests plus focused coverage for preserving preinstalled Node and entrypoint behavior. Build the image and run doctor as `agent`; verify all three CLI versions, passwordless sudo, writable home/workspace, default shell, argument forwarding, and command exit status. Record any Docker or platform limits honestly. A build must fail when doctor reports an incomplete environment; manifest generation alone is not a health gate.

## Builder choices

The exact file layout, cache cleanup, and test implementation are delegated to the implementer. The Node 24 tag, Debian trixie variant, fixed UID/GID, and omission of automatic runtime ownership changes are proposed defaults, not additional user requirements. Latest agent releases continue to resolve during uncached builds, consistent with the existing installers; this is not a reproducible lockfile-based build.
