# agentenv

Bare agent installation and environment configuration for a shared golden image.
Includes Claude Code, Codex, and OpenCode. No skills, MCP servers, hooks, plugins,
model selections, provider endpoints, or task-specific workflows are installed.

## Install

Prerequisites: **Node.js 22+ and npm**, with a writable npm global prefix. Bash
installers support macOS/Linux and WSL; they also require `curl` for Claude.
PowerShell installers target native Windows (Windows PowerShell 5.1 or PowerShell
7). Install Git for Windows for agents' shell/git tools. These scripts do not
bootstrap system package managers, Node, Git, or a development toolchain.

```bash
./install.sh                         # install/update all three
./install.sh --claude --codex         # selected agents
./opencode/install.sh                # one independent installer
./install.sh --all --config-only      # apply configuration without downloads
```

```powershell
.\install.ps1                        # install/update all three
.\install.ps1 -Claude -Codex
.\opencode\install.ps1
.\install.ps1 -All -ConfigOnly
```

Every normal run invokes Claude's official native installer with `latest`, or
`npm install --global @openai/codex@latest` / `@opencode/cli@latest`. Existing
executables do not cause upgrades to be skipped. Versions are resolved at run
time rather than pinned here. Each installed executable is checked with
`--version`; download, installation, and configuration failures return nonzero.

**Configuration files are replaced with this bare baseline.** Changed files are
backed up alongside the original as `.bak.<timestamp>.<unique-id>`; identical files
are untouched. This deliberately does not import old plugins, hooks, MCP entries,
models, or custom policies. Review backups before restoring personal settings.
Credentials and session/history directories are not removed. Symlinked target
files are rejected rather than replaced. Run installers serially.

Open a new shell after installation. Managed blocks load PATH and environment
files from each agent's configuration directory. Bash installation updates
`.bashrc`, `.zshrc`, `.profile`, and an existing `.bash_profile` or `.bash_login`;
PowerShell installation updates `$PROFILE.CurrentUserAllHosts`. Existing profile
content is preserved and backed up. Agent commands still resolve to native CLIs;
no command wrappers or permission-bypass aliases are installed.
Existing installations from other package managers are not uninstalled. Check
`type -a claude codex opencode` (PowerShell: `Get-Command -All claude,codex,opencode`)
if an older executable still shadows the freshly installed one on your PATH.

For containers and other noninteractive launchers, explicitly source each selected
agent's generated `env.sh` (or dot-source `env.ps1`) before starting the agent.
Profiles do not automatically run in every noninteractive environment. Generated
PATH entries include the installer’s Node executable directory; rerun configuration
after removing or relocating that Node installation.

## Configuration locations

| Agent | Default destination | Override |
| --- | --- | --- |
| Claude | `~/.claude/` | `CLAUDE_CONFIG_DIR` |
| Codex | `~/.codex/` | `CODEX_HOME` |
| OpenCode | `~/.config/opencode/` | `OPENCODE_CONFIG_DIR`, then `XDG_CONFIG_HOME/opencode` |

OpenCode's `OPENCODE_CONFIG` can select its main JSON file; the UI configuration
and environment assets still live in the directory above. Custom directory
variables must also be present when launching the corresponding agent.

## Environment and status display

| Preference | Claude | Codex | OpenCode v2 |
| --- | --- | --- | --- |
| Git/PR attribution | Empty native attribution settings | Additional developer instruction | Small attribution-only instruction file |
| Telemetry/error/feedback | Native opt-out environment settings; feedback command disabled | Analytics and feedback disabled; all OTel exporters disabled | OTLP endpoint/headers removed by environment setup; sharing disabled |
| Terminal history | Classic renderer; alternate screen disabled | `alternate_screen = "never"` | Default TUI has no verified no-alternate-screen setting |
| Local history | 3,650-day transcript retention | Save all history; explicit local log directory | Native local sessions and logs retained, subject to upstream log trimming |
| Status | Model, reasoning/thinking, context, cost, input/output tokens, quota/reset, spend, cache warmth/expiry, duration, diff counts, branch, version | Existing agent-shell footer: model/reasoning, context, 5h/weekly limits, branch, token totals, thread ID | Native sidebar, visible reasoning, tokens/sec; native Mini footer enabled when that renderer is used |

The Claude status renderer reads native JSON from stdin, plus a bounded local Git
branch lookup. It makes no quota API calls and reads no credentials or transcripts.
Missing values display as `n/a` or are omitted; subscription quota fields appear
only when supplied by Claude. Cost is the CLI's reported estimate, not a billing
statement. Codex has no verified monetary-cost footer item in the baseline used
here. OpenCode's built-in displays determine which cost/context/token details are
available; no custom status plugin is installed.

Attribution instructions in Codex and OpenCode are behavioral requests, not Git
enforcement. There is no attribution-blocking hook. Upstream/organization/project
settings can override user-level settings. This installation does not erase
previously installed integration directories or disable bundled agent features.

OpenCode v2 enables OTLP export when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. Its
generated environment files unset that variable and headers for the **entire
shell and child processes**, including other tools launched there. Already-running
background servers retain their old environment; restart them after activating
the environment, and review any separately persisted service environment or
remote-server configuration. A remote server must be configured separately.
No global “disable every network request” claim is made: authentication,
inference, updates, and model metadata still require network access.

OpenCode v2.2.5 trims its diagnostic log when it exceeds 50 MiB, retaining roughly
25 MiB. No supported retention override was found. Claude's 3,650-day setting is
long retention, not infinite retention. These installers never prune logs; an
indefinite archive would require a separate backup facility.

## Differences from agent-shell

See [the explicit deviation record](docs/agent-shell-deviations.md) for retained
behavior, removed scope, compatibility gaps, and source links.

## Checks

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
node --test tests/statusline.test.mjs
pwsh -NoProfile -File tests/powershell-smoke.ps1
```

Tests run in disposable homes inside this repository with mocked installers.
They do not install agents, authenticate accounts, or modify host agent settings.
Verified here: 11 Python integration tests, 4 Node status-line tests, Bash syntax,
and PowerShell parsing/configuration smoke tests using PowerShell 7 on macOS.
The encoding fixtures cover UTF-16 profiles and Unicode paths for PS5 compatibility;
an actual Windows/PowerShell 5.1 installation and live authenticated agent TUIs
have not been exercised.

## Layout

```text
install.sh / install.ps1
claude/      installers, settings.json, statusline.mjs
codex/       installers, config.toml
opencode/    installers, opencode.json, cli.json, attribution.md, env.sh/ps1
lib/         shared installation and file-deployment mechanics
tests/       offline verification
docs/        design, plan, and deviations
```
