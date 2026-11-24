"""Guest-side broker setup preserves the image baseline across kit installations."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]


class BrokerSetupTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(dir=ROOT, prefix=".test-sbx-")
        self.addCleanup(scratch.cleanup)
        self.home = Path(scratch.name)
        self.codex = self.home / ".codex"
        self.codex.mkdir()
        self.config = self.codex / "config.toml"
        self.baseline = (ROOT / "codex/config.toml").read_text()
        self.config.write_text(self.baseline)
        (self.home / ".claude").mkdir()
        self.settings = self.home / ".claude/settings.json"
        self.settings.write_text('{"statusLine": {"type": "command"}}')

    def bind(self, openai, anthropic="none", check=True):
        return subprocess.run(
            [sys.executable, ROOT / "docker/sbx-auth.py"],
            env={**os.environ, "HOME": str(self.home), "SBX_CRED_OPENAI_MODE": openai,
                 "SBX_CRED_ANTHROPIC_MODE": anthropic},
            check=check, capture_output=True, text=True,
        )

    def test_oauth_and_key_transitions_preserve_preferences(self):
        self.bind("oauth", "oauth")
        content = self.config.read_text()
        config = tomllib.loads(content)
        self.assertEqual(config["model_provider"], "sandboxd")
        self.assertEqual(config["tui"], tomllib.loads(self.baseline)["tui"])
        settings = json.loads(self.settings.read_text())
        self.assertEqual(settings["apiKeyHelper"], "echo proxy-managed")
        self.bind("oauth", "oauth")
        self.assertEqual(content, self.config.read_text())
        self.bind("apikey", "apikey")
        self.assertNotIn("model_provider", tomllib.loads(self.config.read_text()))
        auth = self.codex / "auth.json"
        self.assertEqual(auth.stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(auth.read_text()), {"OPENAI_API_KEY": "proxy-managed"})
        self.bind("none")
        self.assertFalse(auth.exists())
        self.assertEqual(self.config.read_text(), self.baseline)
        self.assertEqual(json.loads(self.settings.read_text()), {"statusLine": {"type": "command"}})

    def test_existing_unmanaged_auth_is_preserved(self):
        auth = self.codex / "auth.json"
        auth.write_text('{"other": "existing"}')
        self.bind("none")
        self.assertNotEqual(self.bind("oauth", check=False).returncode, 0)
        self.assertEqual(self.config.read_text(), self.baseline)
        self.assertEqual(json.loads(auth.read_text()), {"other": "existing"})
