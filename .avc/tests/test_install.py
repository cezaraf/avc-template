from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
INSTALLER = ROOT / "install.sh"


class PortableInstallerTests(unittest.TestCase):
    def make_target(self, parent: Path, name: str = "sample-app") -> Path:
        target = parent / name
        target.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main"], cwd=target, check=True)
        return target

    def run_installer(self, target: Path, harness: str, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "bash",
                str(INSTALLER),
                "--target",
                str(target),
                "--project",
                target.name,
                "--harness",
                harness,
                *extra,
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def tree_digest(self, root: Path) -> str:
        digest = hashlib.sha256()
        for path in sorted(root.rglob("*")):
            if not path.is_file() or ".git" in path.parts:
                continue
            digest.update(path.relative_to(root).as_posix().encode())
            digest.update(b"\0")
            digest.update(path.read_bytes())
            digest.update(b"\0")
        return digest.hexdigest()

    def test_generic_install_is_idempotent_and_preserves_agents_content(self):
        with tempfile.TemporaryDirectory(prefix="avc-install-generic-") as directory:
            target = self.make_target(Path(directory))
            original = "# Existing project instructions\n\nKeep this product rule.\n"
            (target / "AGENTS.md").write_text(original, encoding="utf-8")

            first = self.run_installer(target, "generic")
            self.assertEqual(first.returncode, 0, first.stderr)
            second = self.run_installer(target, "generic")
            self.assertEqual(second.returncode, 0, second.stderr)

            agents = (target / "AGENTS.md").read_text(encoding="utf-8")
            self.assertIn(original.strip(), agents)
            self.assertEqual(agents.count("<!-- avc:start -->"), 1)
            self.assertEqual(agents.count("<!-- avc:end -->"), 1)
            self.assertEqual(agents.count("<!-- ai-memory:start -->"), 1)
            self.assertEqual(agents.count("<!-- ai-memory:end -->"), 1)
            self.assertFalse((target / ".codex").exists())
            self.assertTrue((target / ".agents/skills/avc-start/SKILL.md").is_file())

            config = yaml.safe_load((target / ".avc/config.yaml").read_text(encoding="utf-8"))
            self.assertEqual(config["project"]["name"], "sample-app")
            marker = (target / ".ai-memory.toml").read_text(encoding="utf-8")
            self.assertIn('project = "sample-app"', marker)

            doctor = subprocess.run(
                ["python3", ".avc/bin/avc.py", "doctor", "--offline"],
                cwd=target,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(doctor.returncode, 0, doctor.stdout + doctor.stderr)

    def test_dry_run_leaves_target_unchanged(self):
        with tempfile.TemporaryDirectory(prefix="avc-install-dry-") as directory:
            target = self.make_target(Path(directory))
            (target / "sentinel.txt").write_text("untouched\n", encoding="utf-8")
            before = self.tree_digest(target)

            result = self.run_installer(target, "all", "--dry-run")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("DRY-RUN", result.stdout)
            self.assertEqual(self.tree_digest(target), before)

    def test_codex_adapter_is_installed_only_when_selected(self):
        with tempfile.TemporaryDirectory(prefix="avc-install-codex-") as directory:
            target = self.make_target(Path(directory), "codex-app")

            result = self.run_installer(target, "codex")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((target / ".codex/config.toml").is_file())
            self.assertTrue((target / ".codex/hooks.json").is_file())
            self.assertTrue((target / ".codex/rules/avc.rules").is_file())
            self.assertFalse((target / "CLAUDE.md").exists())

    def test_all_adapters_add_claude_launchers_without_duplicating_skills(self):
        with tempfile.TemporaryDirectory(prefix="avc-install-all-") as directory:
            target = self.make_target(Path(directory), "multi-harness-app")

            result = self.run_installer(target, "all")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((target / ".codex/config.toml").is_file())
            self.assertTrue((target / "CLAUDE.md").is_file())
            self.assertTrue((target / ".claude/skills/avc-start").is_symlink())
            self.assertTrue((target / ".agents/skills/avc-start/SKILL.md").is_file())
            self.assertIn("OpenCode", result.stdout)


if __name__ == "__main__":
    unittest.main()
