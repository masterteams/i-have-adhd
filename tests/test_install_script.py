"""Installer CLI contract checks that do not require network or real npm."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "install.sh"


class InstallScriptTests(unittest.TestCase):
    def invoke(self, *args, stub_npx=True):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            if stub_npx:
                fake = Path(tmp) / "npx"
                fake.write_text("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$NPX_ARGS_LOG\"\n", encoding="utf-8")
                fake.chmod(0o755)
                env["PATH"] = f"{tmp}:{env['PATH']}"
                env["NPX_ARGS_LOG"] = str(Path(tmp) / "args")
            proc = subprocess.run(
                ["bash", str(SCRIPT), *args],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            log = Path(tmp) / "args"
            args_seen = log.read_text().splitlines() if log.is_file() else []
            return proc, args_seen

    def test_default_installs_codex_in_current_project(self):
        result, args = self.invoke()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["--yes", "skills", "add", "masterteams/i-have-adhd", "--skill", "i-have-adhd", "--agent", "codex", "--yes"], args)

    def test_global_multi_agent_deduplicates(self):
        result, args = self.invoke("-a", "codex", "-a", "claude-code", "-a", "codex", "-g")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["--agent", "codex", "--agent", "claude-code", "--global", "--yes"], args[-6:])

    def test_dry_run_does_not_call_npx(self):
        result, args = self.invoke("--dry-run")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual([], args)
        self.assertIn("Dry run", result.stdout)

    def test_invalid_agent_is_rejected(self):
        result, args = self.invoke("--agent", "other")
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], args)
        self.assertIn("Unsupported agent", result.stderr)

    def test_missing_local_skill_is_rejected(self):
        result, args = self.invoke("--source", "./tests")
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], args)
        self.assertIn("Skill file missing", result.stderr)

    def test_interactive_mode_has_no_auto_yes_flag(self):
        result, args = self.invoke("--interactive")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("codex", args[-1])

    def test_unknown_option_is_rejected(self):
        result, args = self.invoke("--unknown")
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], args)


if __name__ == "__main__":
    unittest.main()
