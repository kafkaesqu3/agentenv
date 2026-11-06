# Bare Agent Installers Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Install current agent releases with a minimal, consistent environment.

**Architecture:** Thin Bash/PowerShell entry points per agent, shared Node.js file deployment helper, native config assets. Root scripts select and invoke agent installers. Node.js is already required by the approved npm installation route and avoids separate JSON/TOML deployment implementations on Windows.

**Tech Stack:** Bash, PowerShell, Node.js built-ins; Python standard library for integration tests only.

**Spec:** `docs/superpowers/specs/2026-11-06-bare-agent-installers-design.md`

## Global Constraints

- Latest releases on every install; Claude native, Codex/OpenCode npm.
- No imported skills, MCPs, hooks, plugins, model/provider choices, or task-specific policy.
- Preserve credentials/history; back up changed configuration.
- Follow agent-shell closely and document deviations.
- Do not reconfigure host agents during testing.

## Review Focus

- Paths containing spaces or shell metacharacters: quote arguments and status commands.
- Existing configs and repeated runs: unique backups, unchanged files untouched.
- Upstream command failure: fail before reporting installation success.
- Partial/missing status data: display unavailable values honestly, preserve zero values.
- Windows behavior: avoid reserved variables, check native exit codes, document runtime test limits.

### Task 1: Installer and config deployment

Files: root and per-agent installers, `lib/install.sh`, `lib/install.ps1`, `lib/configure.mjs`, per-agent config assets, `tests/test_install.py`.

- [x] Write integration tests using temporary homes and mock npm/curl/native binaries for selection, latest requests, failures, backups, idempotence, and paths with spaces.
- [x] Run tests and observe missing entry-point failures.
- [x] Implement entry points and native configuration deployment. Root selectors: `--claude`, `--codex`, `--opencode`, `--all`, `--config-only`, `--help`; PowerShell counterparts use named switches.
- [x] Run integration tests and shell syntax checks.

### Task 2: Status display

Files: `claude/statusline.mjs`, `tests/statusline.test.mjs`, Codex native footer config.

- [x] Test representative data, zero values, missing metrics, malformed input, and control characters.
- [x] Observe failures before implementing the Claude renderer.
- [x] Implement two-line status display from native stdin JSON only; never fetch quota data or parse credentials.
- [x] Run status-line tests.

### Task 3: Documentation and final review

Files: `README.md`, `docs/agent-shell-deviations.md`.

- [x] Document installation, prerequisites, environment activation, retention, native capability gaps, and deviations with source references.
- [x] Request one independent review of the completed files; fix material findings.
- [x] Run complete checks and report actual coverage.

## Execution notes

User approved implementation and requested close alignment with agent-shell. Execute in this session without further design checkpoints. No Git repository exists here, so worktree/commit steps do not apply. Configuration deployment replaces baseline files with unique backups rather than implementing a partial TOML parser; credentials and session files remain untouched. Existing custom integrations in those config files are backed up, not imported into this bare baseline.

Review found two material Windows encoding issues. Added failing tests for UTF-16 profile preservation and UTF-8 BOMs in generated PowerShell files, then fixed both; 11/11 integration tests and 4/4 status-line tests pass. PowerShell 7 parsing/configuration smoke tests pass on macOS. Windows native installation remains unverified. No deferred review findings.
