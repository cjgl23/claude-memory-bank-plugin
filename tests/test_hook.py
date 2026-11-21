"""Sandboxed tests for scripts/memory-bank-hook.sh.

Every test builds a disposable project in a TemporaryDirectory and sets file
mtimes explicitly, so results do not depend on the machine or on timing.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

HOOK = Path(__file__).resolve().parents[1] / "scripts" / "memory-bank-hook.sh"
HAS_GIT = shutil.which("git") is not None


def clean_env(**extra):
    env = {k: v for k, v in os.environ.items() if k != "CLAUDE_PROJECT_DIR"}
    env.update(extra)
    return env


def invoke(cwd, data=None, env=None, raw=None):
    """Run the hook; assert it exits 0 and prints nothing or one JSON object."""
    stdin = raw if raw is not None else json.dumps(data or {"stop_hook_active": False})
    result = subprocess.run(
        ["bash", str(HOOK)],
        cwd=cwd, input=stdin, text=True, capture_output=True,
        env=env or clean_env(), timeout=30,
    )
    assert result.returncode == 0, result.stderr
    return result.stdout


def block_reason(output):
    result = json.loads(output)
    assert result["decision"] == "block"
    return result["reason"]


def set_age(path, seconds_ago):
    stamp = time.time() - seconds_ago
    os.utime(path, (stamp, stamp))


def git(cwd, *args):
    subprocess.run(
        ["git", "-c", "user.email=t@example.com", "-c", "user.name=t", *args],
        cwd=cwd, check=True, capture_output=True,
    )


class Project:
    """A temp project with a memory bank last updated 60 seconds ago."""

    def __init__(self, root, bank_files=("activeContext.md", "progress.md")):
        self.root = Path(root)
        self.bank = self.root / "memory-bank"
        self.bank.mkdir()
        for name in bank_files:
            self.add(f"memory-bank/{name}", age=60)

    def add(self, rel, age=0, text="x"):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        set_age(path, age)
        return path


class BasicBehaviour(unittest.TestCase):
    def test_no_memory_bank_is_noop(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "a.py").write_text("x")
            self.assertEqual(invoke(d), "")

    def test_empty_memory_bank_is_noop(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d, bank_files=()).add("a.py")
            self.assertEqual(invoke(d), "")

    def test_reentrant_stop_does_not_block(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            self.assertEqual(invoke(d, {"stop_hook_active": True}), "")

    def test_reentrant_flag_without_spaces(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            self.assertEqual(invoke(d, raw='{"stop_hook_active":true}'), "")

    def test_spoofed_flag_inside_message_still_blocks(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            payload = {"stop_hook_active": False,
                       "last_assistant_message": '"stop_hook_active": true'}
            self.assertIn("changed.py", block_reason(invoke(d, payload)))

    def test_plan_mode_does_not_block(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            payload = {"stop_hook_active": False, "permission_mode": "plan"}
            self.assertEqual(invoke(d, payload), "")

    def test_source_newer_than_bank_requests_update(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            reason = block_reason(invoke(d))
            self.assertIn("changed.py", reason)
            self.assertIn("1 file(s) changed", reason)

    def test_bank_newer_than_source_is_noop(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            p.add("old.py", age=120)
            self.assertEqual(invoke(d), "")

    def test_empty_or_malformed_stdin_fails_open(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            for raw in ("", "not json"):
                out = invoke(d, raw=raw)
                self.assertIn("changed.py", block_reason(out))

    def test_lists_at_most_five_and_counts_the_rest(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            for i in range(8):
                p.add(f"f{i}.py")
            reason = block_reason(invoke(d))
            self.assertIn("8 file(s) changed", reason)
            self.assertIn("(and 3 more)", reason)


class Baseline(unittest.TestCase):
    def test_touching_unrelated_bank_subfile_does_not_silence(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            p.add("code.py", age=30)
            p.add("memory-bank/api-notes.md", age=0)
            self.assertIn("code.py", block_reason(invoke(d)))

    def test_updating_active_context_clears_reminder(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            p.add("code.py", age=30)
            p.add("memory-bank/activeContext.md", age=0)
            self.assertEqual(invoke(d), "")

    def test_legacy_bank_without_core_files_uses_any_md(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d, bank_files=("notes.md",))
            p.add("code.py")
            self.assertIn("code.py", block_reason(invoke(d)))


class RootResolution(unittest.TestCase):
    def test_payload_cwd_is_used(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as elsewhere:
            Project(d).add("changed.py")
            payload = {"stop_hook_active": False, "cwd": d}
            self.assertIn("changed.py", block_reason(invoke(elsewhere, payload)))

    def test_claude_project_dir_is_used(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as elsewhere:
            Project(d).add("changed.py")
            out = invoke(elsewhere, env=clean_env(CLAUDE_PROJECT_DIR=d))
            self.assertIn("changed.py", block_reason(out))

    def test_path_with_spaces(self):
        with tempfile.TemporaryDirectory() as base:
            d = Path(base, "my project")
            d.mkdir()
            Project(d).add("changed.py")
            self.assertIn("changed.py", block_reason(invoke(d)))

    @unittest.skipUnless(HAS_GIT, "git not installed")
    def test_session_in_subdirectory_finds_bank_at_git_root(self):
        with tempfile.TemporaryDirectory() as d:
            git(d, "init", "-q")
            p = Project(d)
            p.add("src/app.py")
            self.assertIn("src/app.py", block_reason(invoke(p.root / "src")))


class Noise(unittest.TestCase):
    def test_generated_folders_at_any_depth_are_ignored(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            for rel in ("packages/x/node_modules/lib/i.js", ".venv/lib/z.py",
                        "src/__pycache__/c.pyc", ".pytest_cache/v", "dist/out.js",
                        ".claude/settings.local.json", "sub/.DS_Store"):
                p.add(rel)
            self.assertEqual(invoke(d), "")

    @unittest.skipUnless(HAS_GIT, "git not installed")
    def test_gitignored_files_are_ignored(self):
        with tempfile.TemporaryDirectory() as d:
            git(d, "init", "-q")
            p = Project(d)
            p.add(".gitignore", age=120, text="coverage/\n*.log\n")
            p.add("coverage/index.html")
            p.add("debug.log")
            self.assertEqual(invoke(d), "")

    @unittest.skipUnless(HAS_GIT, "git not installed")
    def test_real_edit_is_reported_alongside_ignored_noise(self):
        with tempfile.TemporaryDirectory() as d:
            git(d, "init", "-q")
            p = Project(d)
            p.add(".gitignore", age=120, text="*.log\n")
            p.add("debug.log")
            p.add("app.py")
            reason = block_reason(invoke(d))
            self.assertIn("app.py", reason)
            self.assertNotIn("debug.log", reason)

    @unittest.skipUnless(HAS_GIT, "git not installed")
    def test_hook_works_without_git_on_path(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as bindir:
            Project(d).add("changed.py")
            for tool in ("bash", "cat", "grep", "sed", "head", "find", "ls", "tr"):
                found = shutil.which(tool)
                if found:
                    os.symlink(found, Path(bindir, tool))
            out = invoke(d, env=clean_env(PATH=bindir))
            self.assertIn("changed.py", block_reason(out))


class Filenames(unittest.TestCase):
    def test_special_characters_produce_valid_json(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            p.add('we"ird\\name.txt')
            p.add("tab\there.txt")
            reason = block_reason(invoke(d))
            self.assertIn('we"ird\\name.txt', reason)

    @unittest.skipIf(os.name == "nt", "POSIX byte filenames only")
    def test_invalid_utf8_filename_produces_valid_json(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            raw = os.path.join(os.fsencode(d), b"bad\xffname.txt")
            try:
                with open(raw, "wb") as f:
                    f.write(b"x")
            except OSError:
                # Some filesystems (e.g. macOS APFS) refuse non-UTF-8 names,
                # so the hook can never see one there.
                self.skipTest("filesystem rejects non-UTF-8 filenames")
            block_reason(invoke(d))  # raises if the JSON is invalid


class Clock(unittest.TestCase):
    def test_future_mtime_blocks_once_then_allows_stop(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            p.add("future.py", age=-3600)
            self.assertIn("future.py", block_reason(invoke(d)))
            self.assertEqual(invoke(d, {"stop_hook_active": True}), "")


class Performance(unittest.TestCase):
    def test_large_node_modules_is_pruned_quickly(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            for i in range(200):
                folder = p.root / "node_modules" / f"pkg{i}"
                folder.mkdir(parents=True)
                for j in range(50):
                    (folder / f"f{j}.js").write_text("")
            start = time.monotonic()
            self.assertEqual(invoke(d), "")
            self.assertLess(time.monotonic() - start, 5)


if __name__ == "__main__":
    unittest.main()
