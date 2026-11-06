"""Behavior tests for docker/link-skills.sh; no network, no real agents."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "docker" / "link-skills.sh"


class LinkSkillsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name)
        self.shared = self.home / ".agents" / "skills"
        self.target = self.home / ".claude" / "skills"
        self.env = dict(os.environ, HOME=str(self.home))
        self.env.pop("CLAUDE_CONFIG_DIR", None)

    def skill(self, name, with_manifest=True):
        directory = self.shared / name
        directory.mkdir(parents=True)
        if with_manifest:
            (directory / "SKILL.md").write_text(f"---\nname: {name}\ndescription: test\n---\n")
        return directory

    def run_script(self):
        return subprocess.run(["bash", str(SCRIPT)], env=self.env, text=True, capture_output=True)

    def test_links_each_shared_skill_into_claude(self):
        alpha = self.skill("alpha")
        self.assertEqual(self.run_script().returncode, 0)
        link = self.target / "alpha"
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), alpha.resolve())
        self.assertTrue((link / "SKILL.md").is_file())

    def test_missing_shared_directory_is_a_no_op(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.target.exists())

    def test_ignores_directories_without_skill_manifest(self):
        self.skill("not-a-skill", with_manifest=False)
        self.run_script()
        self.assertFalse((self.target / "not-a-skill").exists())

    def test_is_idempotent(self):
        self.skill("alpha")
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual([p.name for p in self.target.iterdir()], ["alpha"])

    def test_removes_stale_links_but_keeps_unrelated_ones(self):
        gone = self.skill("gone")
        self.run_script()
        (gone / "SKILL.md").unlink()
        gone.rmdir()
        own = self.home / "own-skill"
        own.mkdir()
        (self.target / "own").symlink_to(own)
        self.skill("alpha")
        self.run_script()
        self.assertFalse((self.target / "gone").is_symlink())
        self.assertTrue((self.target / "own").is_symlink())
        self.assertTrue((self.target / "alpha").is_symlink())

    def test_does_not_replace_existing_real_skill_directory(self):
        self.skill("alpha")
        existing = self.target / "alpha"
        existing.mkdir(parents=True)
        (existing / "SKILL.md").write_text("local")
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertIn("alpha", result.stderr)
        self.assertFalse(existing.is_symlink())
        self.assertEqual((existing / "SKILL.md").read_text(), "local")

    def test_honors_claude_config_dir(self):
        self.skill("alpha")
        custom = self.home / "custom"
        self.env["CLAUDE_CONFIG_DIR"] = str(custom)
        self.run_script()
        self.assertTrue((custom / "skills" / "alpha").is_symlink())
        self.assertFalse(self.target.exists())


if __name__ == "__main__":
    unittest.main()
