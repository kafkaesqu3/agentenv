# Bare agent installers

Build the shared foundation for all agent environments: install the latest Claude Code, Codex, and OpenCode releases and apply task-independent environment preferences. Do not import skills, MCP servers, hooks, plugins, task-specific instructions, model choices, or provider credentials from `../agent-shell`.

## Approach

The user selected Claude's vendor-native installer and npm latest releases for Codex and OpenCode. Node.js/npm are explicit prerequisites. Using npm for all three would simplify installation but would depart from Claude's recommended native distribution. Copying the old installer framework would import unnecessary coupling and pinned-version behavior.

## Layout and behavior

- Each of `claude/`, `codex/`, and `opencode/` owns `install.sh`, `install.ps1`, and native configuration assets.
- Root `install.sh` and `install.ps1` install all agents by default and support selecting a subset.
- Each run resolves the latest upstream release, including upgrades of existing installations.
- Repeated configuration is deterministic. Back up existing configuration before replacing it; preserve credentials and session data. Respect supported agent-specific config-home overrides.
- Align disabled attribution, telemetry, error/feedback sharing, terminal preservation, and retained local logs where supported. Document unsupported settings instead of inventing keys.
- Claude uses a local status-line renderer, Codex its built-in footer, and OpenCode its native UI. Show context, cost, reasoning, quotas, and tokens when exposed by the agent.
- Keep shared installer plumbing small. Document prerequisites, supported platforms, configuration destinations, and capability differences.

## Verification

Use temporary destinations and mocked installers to exercise selection, latest-version requests, failure propagation, backups, repeat runs, and configuration deployment. Exercise status-line formatting with representative and missing fields. Validate shell syntax and native configuration formats. Do not install or reconfigure the host's agents as part of verification. Report PowerShell execution coverage honestly if no runtime is available.

## Implementation choices

The builder selects the minimal shared helper implementation, retention values supported by upstream, and exact supported status fields after checking current documentation and schemas. Avoid modifying existing shell profiles without a clear, repeatable managed block. This repository is not currently a Git checkout, so no commit or worktree is possible.
