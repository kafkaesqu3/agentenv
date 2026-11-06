# Deliberate differences from agent-shell

Compared with the local `../agent-shell` tree on 2026-11-06. This is a fresh,
minimal foundation, not a migration of an existing agent-shell installation.

| Area | agent-shell | This repository | Reason |
| --- | --- | --- | --- |
| Layout | `install/` modules, `claude-config/`, `codex-config/`, `opencode/` | Requested `claude/`, `codex/`, `opencode/`, each with Bash/PowerShell installers | Each family is directly installable; root entry points orchestrate them |
| Root selection | Interactive family/Advanced selection by default | All three by default; explicit selection switches | Small noninteractive interface suitable for images |
| Claude install | Official native installer only when missing | Same official native installer, explicit `latest` every run | Existing installations must also update |
| Codex install | Official standalone installer; skips sufficiently new versions and removes npm shims | `@openai/codex@latest` through npm every run | User-approved installation route; native daemon auto-upgrade semantics differ |
| OpenCode install | npm `@opencode/cli@2.0.32`, skipped if command exists | Same package family, `@opencode/cli@latest` every run | Resolve latest release; do not reuse the older `opencode-ai` v1 package |
| Dependencies | Installs system tools, Python, jq, Node/fnm, optional toolchains | Node 22+/npm and platform prerequisites are explicit | Bare agent scope; use Node built-ins for deployment and status rendering |
| Config application | Selective Claude merge, Codex merge, OpenCode copy-if-missing | Deterministic replacement with unique backups; identical files untouched | Avoid carrying integrations or stale privacy preferences into the bare baseline; custom settings require deliberate reapplication |
| Backups | Several `.bak` files reused; some timestamped backups | Unique timestamp + UUID; restrictive file modes on POSIX; atomic file replacement | Retain earlier backups and avoid partially written config files |
| Claude status | Bash/jq, two-line display, Git, context, cost, session duration, cache hit/TTL details | Node, two-line display; retains core metrics and native cache warmth/expiry; adds native reasoning, quota resets, spend, total input/output and version | Cross-platform renderer without jq or a Git Bash status wrapper; omits decorative bars/colors and cache-hit percentage |
| Claude terminal | `clearTerminalOnLaunch: false` and disable-alternate-screen environment variable | Retains disable-alternate-screen; adds documented `tui: default`; omits undocumented `clearTerminalOnLaunch` | Prefer the current supported renderer setting; preserves classic terminal behavior |
| Claude privacy | Telemetry/error/survey opt-outs | Retains those, adds feedback-command opt-out, drafted feedback off, OTel off | Cover feedback submission as well as surveys |
| Claude retention | 365 days | 3,650 days | Requested log retention; zero is not a valid unlimited-retention setting |
| Codex history | `persistence = "none"` | `save-all` and explicit `log_dir` | Keep local history and enable the local TUI text log |
| Codex footer/privacy | Native footer list, analytics/feedback off, OTel exporters none | Retained | Already fits the requested environment |
| Codex task policy | Reasoning high, verbosity medium, pragmatic personality, live web, workspace sandbox, restricted network, feature overrides | Omitted | Golden image must be usable beyond software-development workflows |
| Attribution | Claude native settings plus attribution-blocking hook; global instructions | Claude native settings retained; one focused instruction for Codex/OpenCode | User asked for no attribution and no hooks; instruction-only enforcement is weaker than a Git hook |
| OpenCode config | Local provider addresses, fixed models, specialist agents, plugins | Sharing disabled; attribution-only instruction; native v2 `cli.json` UI preferences | No machine-specific endpoints, agents, models, or extensions in the baseline |
| OpenCode telemetry | No comparable bare baseline | Generated environment removes OTLP export endpoint and headers | Verified v2 release behavior; do not invent a telemetry config key |
| Shell setup | Native PATH, fnm, launcher symlink, yolo aliases, `.env` seed | Native PATH and per-agent env files, managed profile blocks; no aliases or launcher | Environment setup only; preserves native CLI command names |
| Installed extras | Instructions library, prompts, skills, MCPs, plugins, hooks, voice/autoharness, optional tools | None imported | Explicitly excluded from this stage |
| Failure handling | Some setup failures warn and continue | Download/install/version/config errors fail the script | Avoid claiming successful setup after partial failure |
| Windows text encoding | PowerShell-specific configuration writers | Shared writer decodes UTF-16 profiles and emits `.ps1` with a UTF-8 BOM | Preserve existing profile text and support non-ASCII paths under PS5.1 |

## Known parity limits

- OpenCode's default TUI does not expose a verified no-alternate-screen switch.
  The native Mini footer configuration is provided but does not itself select
  that renderer. No terminal wrapper or custom plugin is added.
- OpenCode's diagnostic log has fixed upstream trimming (50 MiB to approximately
  25 MiB); this baseline does not provide indefinite diagnostic-log archival.
- Codex and OpenCode have no verified native no-attribution key in the current
  schemas. Focused instructions express the preference but cannot guarantee it.
- Codex's retained footer provides token and quota data, not a verified dollar
  cost item. OpenCode's built-in UI exposes the metrics available to it.
- Environment setup affects newly started processes. Existing OpenCode service
  processes and independently configured remote servers need their own restart
  and environment review. Provider-side account data controls are separate from
  these CLI settings.
- Local config replacement does not uninstall previously installed extension
  directories. Use a clean home/config directory for the golden image.
- Unlike agent-shell's Codex migration, old installations from other package
  managers are not removed. The installer verifies the exact binary it installed;
  a conflicting executable elsewhere on PATH may still need manual reconciliation.

## Upstream references used

- [Claude native setup](https://code.claude.com/docs/en/setup)
- [Claude environment variables](https://code.claude.com/docs/en/env-vars)
- [Claude settings reference](https://code.claude.com/docs/en/settings-reference)
- [Claude terminal rendering](https://code.claude.com/docs/en/fullscreen)
- [Claude status-line protocol](https://code.claude.com/docs/en/statusline)
- [Codex configuration reference](https://developers.openai.com/codex/config-reference)
- [Codex configuration schema](https://developers.openai.com/codex/config-schema.json)
- [OpenCode main configuration schema](https://opencode.ai/config.json)
- [OpenCode v2 CLI schema](https://opencode.ai/v2/cli.json)
- [OpenCode v2.2.5 CLI config loading](https://github.com/anomalyco/opencode/blob/v2.2.5/packages/cli/src/config/config.ts)
- [OpenCode v2.2.5 OTLP export](https://github.com/anomalyco/opencode/blob/v2.2.5/packages/util/src/observability/otlp.ts)
- [OpenCode v2.2.5 logging and retention](https://github.com/anomalyco/opencode/blob/v2.2.5/packages/util/src/observability/logging.ts)

Versioned source links explain the behavior examined, not an installation pin.
Installers always request `latest`.
# Shared system-tool layer

The follow-on baseline adds explicit Homebrew/apt/WinGet provisioning of general
file, network, scripting and archive tools before root agent installation. It
does not import agent-shell's task-specific packages, extensions or policies.
`--skip-tools` preserves the earlier agent-only entry point; `--config-only`
still performs no downloads. New `doctor` scripts inspect local readiness, and
normal root installs write immutable version/path inventories. Inventories are
observations, not dependency lockfiles. Package managers are prerequisites;
unsupported systems and distribution Node versions below 22 fail explicitly.
