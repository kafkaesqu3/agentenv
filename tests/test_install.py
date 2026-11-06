"""Offline installer contract tests; never invokes real package installers."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil

ROOT = Path(__file__).resolve().parents[1]


class InstallTests(unittest.TestCase):
    def test_shared_completion_instructions_are_installed_for_all_agents(self):
        self.run_install('--all', '--config-only')
        expected = (ROOT / 'instructions/AGENTS.md').read_text()
        for relative in ('claude/CLAUDE.md', 'codex/AGENTS.md', 'config/opencode/AGENTS.md'):
            self.assertEqual((self.home / relative).read_text(), expected)
        config = json.loads((self.home / 'config/opencode/opencode.json').read_text())
        self.assertIn(str(self.home / 'config/opencode/AGENTS.md'), config['instructions'])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT, prefix=".test install ")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.calls = self.home / "calls"
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / "config"),
                        CODEX_HOME=str(self.home / "codex"), CLAUDE_CONFIG_DIR=str(self.home / "claude"),
                        PATH=f"{self.bin}:{os.environ['PATH']}", CALLS=str(self.calls),
                        TMPDIR=str(self.home), SHELL="/bin/bash")
        self.env.pop("OPENCODE_CONFIG_DIR", None)
        self.env.pop("OPENCODE_CONFIG", None)
        self.mock("npm", 'printf "npm %s\\n" "$*" >> "$CALLS"\n'
                  'if [ "${FAIL_NPM:-}" = 1 ]; then exit 42; fi\n'
                  'if [ "$1" = prefix ]; then printf "%s\\n" "$HOME"; fi\n')
        for agent in ("codex", "opencode", "claude"):
            self.mock(agent, 'printf "mock 1.0\\n"\n')
        native = self.home / '.local/bin'
        native.mkdir(parents=True)
        (native / 'claude').symlink_to(self.bin / 'claude')
        self.mock("curl", 'printf "curl %s\\n" "$*" >> "$CALLS"\n'
                  'while [ "$#" -gt 0 ]; do if [ "$1" = -o ]; then shift; output=$1; fi; shift; done\n'
                  'printf \'printf "claude-install %%s\\n" "$*" >> "$CALLS"\\n\' > "$output"\n')

    def mock(self, name, body):
        target = self.bin / name
        target.write_text("#!/bin/bash\nset -eu\n" + body)
        target.chmod(0o755)

    def run_install(self, *args, script="install.sh", ok=True):
        if script == 'install.sh':
            args = ('--skip-tools', *args)
        result = subprocess.run(["bash", str(ROOT / script), *args], env=self.env,
                                text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_all_requests_latest_every_run(self):
        for _ in range(2):
            self.run_install()
        calls = self.calls.read_text()
        self.assertEqual(calls.count("npm install --global @openai/codex@latest"), 2)
        self.assertEqual(calls.count("npm install --global @opencode/cli@latest"), 2)
        self.assertEqual(calls.count("claude-install latest"), 2)

    def test_root_provisions_tools_before_selected_agent_and_records_manifest(self):
        (self.bin / 'node').symlink_to(shutil.which('node'))
        self.mock('uname', 'echo Darwin\n')
        self.mock('brew', 'printf "brew %s\\n" "$*" >> "$CALLS"\n'
                  'if [ "$1" = --prefix ]; then echo "$HOME"; fi\n')
        self.env['AGENTENV_STATE_DIR'] = str(self.home / 'state')
        result = subprocess.run(['bash', str(ROOT / 'install.sh'), '--codex'],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls.read_text()
        self.assertLess(calls.index('brew install'), calls.index('npm install'))
        self.assertTrue((self.home / 'state/env.sh').exists())
        manifests = list((self.home / 'state/manifests').glob('*.json'))
        self.assertEqual(len(manifests), 1)
        report = json.loads(manifests[0].read_text())
        self.assertEqual([c['agent'] for c in report['configs']], ['codex'])
        self.assertTrue(next(t for t in report['tools'] if t['name'] == 'codex')['ok'])
        paths = (self.home / 'codex/tools-path.sh').read_bytes()
        self.run_install('--codex', '--config-only')
        self.assertEqual((self.home / 'codex/tools-path.sh').read_bytes(), paths)

    def test_config_only_selects_one_and_keeps_credentials(self):
        target = self.home / "codex"
        target.mkdir()
        (target / "auth.json").write_text('"keep"')
        self.run_install("--codex", "--config-only")
        self.assertTrue((target / "config.toml").is_file())
        self.assertEqual((target / "auth.json").read_text(), '"keep"')
        self.assertFalse((self.home / "claude").exists())
        self.assertFalse(self.calls.exists())

    def test_backup_idempotence_and_special_path(self):
        target = self.home / "claude"
        target.mkdir()
        settings = target / "settings.json"
        settings.write_text('{"model":"old","hooks":{"Stop":[]}}')
        before = settings.read_bytes()
        self.run_install("--config-only", script="claude/install.sh")
        backups = list(target.glob("settings.json.bak.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), before)
        config = json.loads(settings.read_text())
        self.assertNotIn("hooks", config)
        self.assertEqual(config["attribution"], {"commit": "", "pr": ""})
        stamp = settings.stat().st_mtime_ns
        self.run_install("--config-only", script="claude/install.sh")
        self.assertEqual(settings.stat().st_mtime_ns, stamp)
        self.assertEqual(len(list(target.glob("settings.json.bak.*"))), 1)
        result = subprocess.run(config["statusLine"]["command"], shell=True, input="{}",
                                text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_failed_download_does_not_apply_config(self):
        self.env["FAIL_NPM"] = "1"
        self.run_install("--codex", ok=False)
        self.assertFalse((self.home / "codex/config.toml").exists())

    def test_unknown_option_fails_before_side_effects(self):
        self.run_install("--claude", "--typo", ok=False)
        self.assertFalse(self.calls.exists())
        self.run_install("--help")
        self.assertFalse(self.calls.exists())

    def test_opencode_native_ui_and_private_environment(self):
        self.run_install("--opencode", "--config-only")
        folder = self.home / "config/opencode"
        config = json.loads((folder / "opencode.json").read_text())
        self.assertEqual(config["share"], "disabled")
        self.assertNotIn("plugin", config)
        ui = json.loads((folder / "cli.json").read_text())
        self.assertEqual(ui["mini"]["footer"], "show")
        self.assertTrue(ui["session"]["tps"])
        self.assertTrue((folder / "env.sh").exists())

    def test_symlink_config_is_not_overwritten(self):
        target = self.home / "codex"
        target.mkdir()
        linked = self.home / "other.toml"
        linked.write_text('model = "keep"')
        (target / "config.toml").symlink_to(linked)
        self.run_install("--codex", "--config-only", ok=False)
        self.assertEqual(linked.read_text(), 'model = "keep"')

    def test_dangling_symlink_is_not_replaced(self):
        target = self.home / "codex"
        target.mkdir()
        (target / "config.toml").symlink_to(self.home / "not-yet-created")
        self.run_install("--codex", "--config-only", ok=False)
        self.assertTrue((target / "config.toml").is_symlink())

    def test_shell_profile_preserves_content_and_activates_environment(self):
        profile = self.home / '.bashrc'
        profile.write_text('# existing user config\n')
        for _ in range(2):
            self.run_install('--opencode', '--config-only')
        self.assertTrue(profile.read_text().startswith('# existing user config\n'))
        self.assertEqual(profile.read_text().count('# >>> agentenv opencode >>>'), 1)
        result = subprocess.run(['bash', '-c', '. "$HOME/.bashrc"; test -z "${OTEL_EXPORTER_OTLP_ENDPOINT:-}"'],
                                env=dict(self.env, OTEL_EXPORTER_OTLP_ENDPOINT='https://example.invalid'), capture_output=True)
        self.assertEqual(result.returncode, 0)

    def test_powershell_utf16_profile_preserves_existing_text(self):
        profile = self.home / 'profile.ps1'
        original = '# existing café profile\r\n$env:MY_SETTING = "keep"\r\n'
        profile.write_bytes(original.encode('utf-16'))
        result = subprocess.run(['node', str(ROOT / 'lib/configure.mjs'), 'codex', '--profile', str(profile)],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        content = profile.read_text(encoding='utf-8-sig')
        self.assertTrue(content.startswith(original.replace('\r\n', '\n')))
        self.assertNotIn('\x00', content)
        self.assertNotIn('\ufffd', content)

    def test_generated_powershell_scripts_have_utf8_bom_for_unicode_paths(self):
        target = self.home / "agent's café config"
        self.env['CLAUDE_CONFIG_DIR'] = str(target)
        profile = self.home / 'profile.ps1'
        result = subprocess.run(['node', str(ROOT / 'lib/configure.mjs'), 'claude', '--profile', str(profile),
                                 '--bin', str(self.home / 'café binaries')], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for file in (profile, target / 'env.ps1', target / 'path.ps1'):
            self.assertTrue(file.read_bytes().startswith(b'\xef\xbb\xbf'), str(file))
            self.assertNotIn('\ufffd', file.read_text(encoding='utf-8-sig'))


if __name__ == "__main__":
    unittest.main()
