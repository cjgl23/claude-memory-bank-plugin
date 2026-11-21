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
    """Environment without Claude Code variables from the machine running tests.

    Defaults to reminder_mode=strict so the original blocking tests keep testing
    the blocking path; nudge-mode tests set the mode explicitly.
    """
    env = {
        k: v for k, v in os.environ.items()
        if k not in ("CLAUDE_PROJECT_DIR", "CLAUDE_PLUGIN_DATA")
        and not k.startswith("CLAUDE_PLUGIN_OPTION_")
    }
    env["CLAUDE_PLUGIN_OPTION_REMINDER_MODE"] = "strict"
    env.update(extra)
    return env


def invoke(cwd, data=None, env=None, raw=None, event=None):
    """Run the hook; assert it exits 0 and return its stdout."""
    stdin = raw if raw is not None else json.dumps(data or {"stop_hook_active": False})
    args = ["bash", str(HOOK)] + ([event] if event else [])
    result = subprocess.run(
        args,
        cwd=cwd, input=stdin, text=True, capture_output=True,
        env=env or clean_env(), timeout=30, errors="replace",
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


def session(sid="s1", **fields):
    payload = {"session_id": sid, "stop_hook_active": False}
    payload.update(fields)
    return payload


class Settings(unittest.TestCase):
    def test_unset_mode_defaults_to_nudge(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            env = clean_env()
            del env["CLAUDE_PLUGIN_OPTION_REMINDER_MODE"]
            out = json.loads(invoke(d, session(), env=env))
            self.assertNotIn("decision", out)
            self.assertIn("systemMessage", out)

    def test_invalid_mode_falls_back_to_nudge(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            env = clean_env(CLAUDE_PLUGIN_OPTION_REMINDER_MODE="loud")
            self.assertIn("systemMessage", json.loads(invoke(d, session(), env=env)))

    def test_mode_is_case_insensitive(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            env = clean_env(CLAUDE_PLUGIN_OPTION_REMINDER_MODE="STRICT")
            self.assertIn("changed.py", block_reason(invoke(d, env=env)))

    def test_off_mode_does_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            env = clean_env(CLAUDE_PLUGIN_OPTION_REMINDER_MODE="off")
            self.assertEqual(invoke(d, session(), env=env), "")
            self.assertEqual(invoke(d, session(prompt="hi"), env=env, event="prompt"), "")

    def test_min_changed_files_threshold(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d)
            p.add("a.py")
            p.add("b.py")
            env = clean_env(CLAUDE_PLUGIN_OPTION_MIN_CHANGED_FILES="3")
            self.assertEqual(invoke(d, env=env), "")
            p.add("c.py")
            self.assertIn("3 file(s) changed", block_reason(invoke(d, env=env)))

    def test_invalid_threshold_falls_back_to_one(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("a.py")
            for value in ("abc", "0", "-2", "1.0"):
                env = clean_env(CLAUDE_PLUGIN_OPTION_MIN_CHANGED_FILES=value)
                self.assertIn("a.py", block_reason(invoke(d, env=env)))


class NudgeStop(unittest.TestCase):
    def env(self, data_dir, **extra):
        return clean_env(CLAUDE_PLUGIN_OPTION_REMINDER_MODE="nudge",
                         CLAUDE_PLUGIN_DATA=data_dir, **extra)

    def test_nudge_never_blocks_and_tells_the_user(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            Project(d).add("changed.py")
            out = json.loads(invoke(d, session(), env=self.env(data)))
            self.assertEqual(set(out), {"systemMessage"})
            self.assertIn("1 file(s) changed", out["systemMessage"])
            self.assertIn("update memory bank", out["systemMessage"])

    def test_nudge_only_once_per_stale_period(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            p = Project(d)
            p.add("changed.py", age=30)
            env = self.env(data)
            self.assertTrue(invoke(d, session(), env=env))
            p.add("more.py", age=20)
            self.assertEqual(invoke(d, session(), env=env), "")
            # Another session gets its own nudge.
            self.assertTrue(invoke(d, session("s2"), env=env))

    def test_nudges_again_after_bank_update_goes_stale(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            p = Project(d)
            p.add("changed.py", age=30)
            env = self.env(data)
            self.assertTrue(invoke(d, session(), env=env))
            marker = Path(data, "state", "s1.stop")
            set_age(marker, 25)
            p.add("memory-bank/activeContext.md", age=10)
            self.assertEqual(invoke(d, session(), env=env), "")  # fresh now
            p.add("later.py", age=0)
            self.assertTrue(invoke(d, session(), env=env))

    def test_session_id_cannot_escape_state_folder(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            Project(d).add("changed.py")
            invoke(d, session("../../evil"), env=self.env(data))
            written = [p for p in Path(data).rglob("*") if p.is_file()]
            self.assertEqual([p.name for p in written], ["evil.stop"])
            self.assertEqual(written[0].parent, Path(data, "state"))

    def test_without_plugin_data_nudge_still_works(self):
        with tempfile.TemporaryDirectory() as d:
            Project(d).add("changed.py")
            env = clean_env(CLAUDE_PLUGIN_OPTION_REMINDER_MODE="nudge")
            self.assertIn("systemMessage", json.loads(invoke(d, session(), env=env)))


class PromptHook(unittest.TestCase):
    def env(self, data_dir, mode="nudge"):
        return clean_env(CLAUDE_PLUGIN_OPTION_REMINDER_MODE=mode,
                         CLAUDE_PLUGIN_DATA=data_dir)

    def test_injects_context_once(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            Project(d).add("changed.py")
            env = self.env(data)
            out = invoke(d, session(prompt="fix the button"), env=env, event="prompt")
            self.assertIn("memory-bank/ is out of date", out)
            self.assertIn("changed.py", out)
            self.assertEqual(
                invoke(d, session(prompt="next"), env=env, event="prompt"), "")

    def test_skipped_when_prompt_mentions_memory_bank(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            Project(d).add("changed.py")
            for prompt in ("please update memory bank", "Update the Memory-Bank"):
                out = invoke(d, session(prompt=prompt), env=self.env(data),
                             event="prompt")
                self.assertEqual(out, "")

    def test_project_path_containing_memory_bank_does_not_skip(self):
        with tempfile.TemporaryDirectory() as base, tempfile.TemporaryDirectory() as data:
            d = Path(base, "claude-memory-bank-plugin")
            d.mkdir()
            Project(d).add("changed.py")
            payload = session(prompt="fix the button", cwd=str(d))
            out = invoke(d, payload, env=self.env(data), event="prompt")
            self.assertIn("out of date", out)

    def test_silent_in_strict_mode_and_when_fresh(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            p = Project(d)
            p.add("old.py", age=120)
            self.assertEqual(
                invoke(d, session(prompt="x"), env=self.env(data), event="prompt"), "")
            p.add("changed.py")
            self.assertEqual(invoke(d, session(prompt="x"),
                                    env=self.env(data, "strict"), event="prompt"), "")

    def test_silent_in_plan_mode(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as data:
            Project(d).add("changed.py")
            payload = session(prompt="x", permission_mode="plan")
            self.assertEqual(invoke(d, payload, env=self.env(data), event="prompt"), "")


class SessionStart(unittest.TestCase):
    def start(self, d, load_mode=None, **env_extra):
        extra = dict(env_extra)
        if load_mode:
            extra["CLAUDE_PLUGIN_OPTION_LOAD_MODE"] = load_mode
        return invoke(d, session(source="startup"), env=clean_env(**extra),
                      event="session-start")

    def bank(self, d):
        p = Project(d, bank_files=())
        p.add("memory-bank/projectbrief.md", age=60,
              text="# Project Brief\n\n## Core Goal\nShip the widget API.\n")
        p.add("memory-bank/activeContext.md", age=60,
              text="# Active Context\n\n## Current Focus\nAdding auth.\n")
        p.add("memory-bank/progress.md", age=60, text="# Progress\n")
        return p

    def test_summary_includes_brief_active_and_index(self):
        with tempfile.TemporaryDirectory() as d:
            self.bank(d)
            out = self.start(d)
            self.assertIn("Ship the widget API.", out)
            self.assertIn("Adding auth.", out)
            self.assertIn("memory-bank/progress.md", out)
            self.assertNotIn("out of date", out)
            self.assertLessEqual(len(out), 2000)

    def test_summary_reports_staleness(self):
        with tempfile.TemporaryDirectory() as d:
            self.bank(d).add("changed.py")
            self.assertIn("1 file(s) changed", self.start(d))

    def test_large_active_context_is_truncated_and_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self.bank(d)
            body = "\n".join(f"- item {i} " + "x" * 120 for i in range(200))
            p.add("memory-bank/activeContext.md", age=60, text=body)
            out = self.start(d)
            self.assertLessEqual(len(out), 2000)
            self.assertIn("(truncated)", out)

    def test_size_warning_for_long_active_context(self):
        with tempfile.TemporaryDirectory() as d:
            p = self.bank(d)
            p.add("memory-bank/activeContext.md", age=60,
                  text="\n".join(f"l{i}" for i in range(200)))
            self.assertIn("consolidate memory bank", self.start(d))

    def test_two_file_names_are_preferred(self):
        with tempfile.TemporaryDirectory() as d:
            p = self.bank(d)
            p.add("memory-bank/brief.md", age=60, text="New brief text\n")
            p.add("memory-bank/active.md", age=60, text="New active text\n")
            out = self.start(d)
            self.assertIn("New brief text", out)
            self.assertIn("New active text", out)
            self.assertNotIn("Ship the widget API.", out)

    def test_pointer_and_off_modes(self):
        with tempfile.TemporaryDirectory() as d:
            self.bank(d)
            pointer = self.start(d, "pointer")
            self.assertEqual(pointer.count("\n"), 1)
            self.assertIn("memory-bank/activeContext.md", pointer)
            self.assertEqual(self.start(d, "off"), "")

    def test_missing_bank_prints_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.start(d), "")

    def test_partial_and_empty_banks_say_what_is_missing(self):
        with tempfile.TemporaryDirectory() as d:
            p = Project(d, bank_files=())
            self.assertIn("initialize memory bank", self.start(d))
            p.add("memory-bank/activeContext.md", age=60, text="Focus\n")
            self.assertIn("Missing: memory-bank/projectbrief.md", self.start(d))

    def test_malformed_stdin_fails_open(self):
        with tempfile.TemporaryDirectory() as d:
            self.bank(d)
            out = invoke(d, raw="not json", event="session-start")
            self.assertIn("Adding auth.", out)


if __name__ == "__main__":
    unittest.main()
