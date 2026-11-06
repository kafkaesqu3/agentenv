# agentenv-base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build and verify the shared Debian agent image as `agentenv-base`.

**Architecture:** Reuse the existing installers on the official Node Debian slim image. Install into the runtime user's home and load generated environment assets through an exec-based entrypoint.

**Tech Stack:** Docker, Debian trixie, Node 24, Bash, existing Python and Node test suites.

**Spec:** `docs/superpowers/specs/2026-11-06-agentenv-base-design.md`

## Global Constraints

- Default parent `node:24-trixie-slim`, overridable by build argument.
- Runtime user `agent`, UID/GID 1000, home `/home/agent`, passwordless sudo.
- Working directory `/workspace`; default command Bash.
- All three agents and existing shared tools; no credentials or task-specific additions.
- Node 22+ required; preserve working preinstalled Node and npm.
- Doctor must pass during build; retain version inventory and `/opt/agentenv` sources.

## Review Focus

- Existing Node with broken or missing npm must not suppress apt runtime installation.
- Custom configuration paths containing spaces must load correctly or fail clearly if unprovisioned.
- Command arguments and nonzero exit status must survive entrypoint execution unchanged.
- Bind-mounted workspaces retain host ownership; startup must not recursively chown them.
- Explicit root execution must remain possible without rewriting the installed agent home.

### Task 1: Preserve a suitable preinstalled Node runtime

**Files:** Modify `tools/install.sh`, `tests/baseline.test.mjs`, and the shared-tools explanation in `README.md`.

**Interfaces:** The installer keeps its existing arguments. Apt adds `nodejs npm` only if Node 22+ and working npm are not already available; the post-install version check remains mandatory.

- [x] Add Linux dry-run tests asserting omission of `nodejs npm` with a suitable runtime, and inclusion with absent/old Node or missing/failing npm. Mock package-manager execution only; use the real Node executable for the suitable-runtime case.
- [x] Run `node --test tests/baseline.test.mjs` and observe the preservation case fail.
- [x] Implement conditional apt runtime packages and document the behavior.
- [x] Rerun the focused tests; require all passing.

### Task 2: Build and exercise the container

**Files:** Create `Dockerfile`, `.dockerignore`, `docker/entrypoint.sh`, `tests/container.test.mjs`, and `tests/container-smoke.sh`; update `README.md`.

**Interfaces:** `docker build -t agentenv-base .`; `docker run --rm agentenv-base COMMAND ARG...`; `bash tests/container-smoke.sh agentenv-base`.

- [x] Add entrypoint tests using temporary generated environments: assert shared and agent variables reach the child, quoted arguments remain exact, exit 37 propagates, custom paths with spaces load, and missing required environment files fail clearly. Run to confirm failures before implementation.
- [x] Implement the entrypoint with existing configuration-directory conventions and `exec`; default to Bash when no arguments are given.
- [x] Add the Dockerfile: rename the parent's node user/group, provision sudo with validated sudoers, set a user-writable npm prefix, copy only required sources, run existing installers as agent, clear build caches, and gate on doctor via the entrypoint. Set useful PATH entries in image metadata for downstream build commands too.
- [x] Allowlist the Docker build context so credentials, repository metadata, local tests and temporary homes cannot enter it.
- [x] Add smoke checks for UID/GID, home/workspace writes, sudo, CLI versions, doctor, explicit root, mounted-workspace ownership, and argument/exit preservation.
- [x] Document build/rebuild, direct CLI use, interactive shell, workspace/configuration persistence, explicit root and downstream image examples. Explain that replacing the whole home masks installed files and configuration overrides must be provisioned.
- [x] Run `python3 -m unittest discover -s tests -p 'test_*.py'`, `node --test tests/*.test.mjs`, shell syntax checks, and the existing PowerShell smoke suite when available.
- [x] Run `docker build -t agentenv-base .` and `bash tests/container-smoke.sh agentenv-base`. The available Docker daemon is Linux arm64; report amd64 as unverified unless separately exercised.
- [x] Review the final diff against the approved design, correct defects, and report actual test/build results and any remaining limitations.

## Execution record

Implemented in the existing workspace with user approval. Baseline: 13 Node and 12 Python tests passed. Final source suite: 20 Node and 12 Python tests passed; shell syntax checks passed. ARM64 image built and smoke checks passed. PowerShell is unavailable; amd64 and authenticated agent sessions were not exercised. Fresh source review found no blocking issues; its empty-heading documentation note was corrected. Runtime smoke checks exposed baked Codex temporary directories; added an absence check, observed it fail, and removed those directories during build cleanup. Final rebuild and smoke verification passed after that cleanup; the Codex warning is gone.
