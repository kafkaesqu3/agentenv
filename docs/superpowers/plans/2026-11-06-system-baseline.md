# Shared system baseline implementation plan

Goal: Supply general-purpose tools, read-only diagnostics, and an installed-version manifest.
Architecture: Homebrew, apt, and WinGet installers with shared Node diagnostics. Package managers must exist. Node must meet the existing >=22 prerequisite; do not add system repositories automatically.

- [x] Add tool installers with dry-run and explicit failure propagation.
- [x] Add bounded version probes, PATH conflict reporting, config presence, directory access checks, JSON output and explicit manifest writing.
- [x] Wire tools-first root installs with skip-tools/tools-only controls. Configuration-only runs skip downloads and manifests.
- [x] Test missing tools, duplicate paths, manifest safety, argument validation, package command construction and existing installers.
- [x] Document platform limitations and deviations; review and verify. Commit after final checks.

Scope: Git, curl/CA trust, ripgrep, fd, jq, Node/npm, Python3, uv, shells and archives. No integrations or specialized capabilities. Native Windows archive equivalents are acceptable.
Review focus: PATH refresh, old distro Node, Windows aliases, symlink manifests, selected-agent installs.

Review corrections: standalone tools now persist their own environment and profile
blocks; agent reconfiguration retains separate tool PATH assets. Windows cmd shim
probes use verbatim cmd arguments, and 7-Zip uses its no-argument version banner.
Offline tests cover shared PATH persistence, tools-first ordering and selected
agent inventory. Actual package installs and native Windows execution are not
performed on this macOS development host.
