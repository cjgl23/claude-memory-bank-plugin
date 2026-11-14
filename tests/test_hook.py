import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

HOOK = Path(__file__).resolve().parents[1] / "scripts" / "memory-bank-hook.sh"


def invoke(cwd, data):
    return subprocess.run(
        ["bash", str(HOOK)],
        cwd=cwd, input=json.dumps(data), text=True, capture_output=True,
        check=True, timeout=10,
    ).stdout


class MemoryBankHookTests(unittest.TestCase):
    def test_no_memory_bank_is_noop(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(invoke(directory, {"stop_hook_active": False}), "")

    def test_reentrant_stop_does_not_block(self):
        with tempfile.TemporaryDirectory() as directory:
            bank = Path(directory) / "memory-bank"
            bank.mkdir()
            (bank / "progress.md").write_text("previous")
            (Path(directory) / "changed.py").write_text("new")
            self.assertEqual(invoke(directory, {"stop_hook_active": True}), "")

    def test_source_newer_than_bank_requests_update(self):
        with tempfile.TemporaryDirectory() as directory:
            bank = Path(directory) / "memory-bank"
            bank.mkdir()
            old = bank / "progress.md"
            old.write_text("previous")
            new = Path(directory) / "changed.py"
            new.write_text("new")
            timestamp = time.time()
            os.utime(old, (timestamp - 30, timestamp - 30))
            os.utime(new, (timestamp, timestamp))
            result = json.loads(invoke(directory, {"stop_hook_active": False}))
            self.assertEqual(result["decision"], "block")
            self.assertIn("changed.py", result["reason"])


if __name__ == "__main__":
    unittest.main()
