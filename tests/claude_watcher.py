"""Integration checks against disposable local Git repositories; no GitHub credentials needed."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("watcher", Path(__file__).resolve().parents[1] / "tools/claude_watcher.py")
watcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watcher)


class WatcherTests(unittest.TestCase):
    def test_publications_deletions_and_access_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            remote, author, observer, output = [base / name for name in ["remote", "author", "observer", "status"]]
            def git(repo, *args):
                return subprocess.run(["git", "-C", str(repo), *args], check=True,
                                      capture_output=True, text=True).stdout.strip()
            remote.mkdir(); git(remote, "init", "--bare")
            author.mkdir(); git(author, "init")
            git(author, "config", "user.name", "Watcher test")
            git(author, "config", "user.email", "watcher@example.invalid")
            git(author, "remote", "add", "origin", str(remote))
            git(author, "checkout", "-b", "claude/test")
            (author / "docs").mkdir()
            handoff = author / "docs/AI_HANDOFF.md"
            handoff.write_text("First handoff", encoding="utf-8")
            git(author, "add", "."); git(author, "commit", "-m", "Initial")
            git(author, "push", "origin", "claude/test")
            observer.mkdir(); git(observer, "init")
            git(observer, "remote", "add", "origin", str(remote))
            (observer / "user-file").write_text("Preserve this")
            output.mkdir(); state = {"interval": 600}
            before = git(observer, "status", "--porcelain")
            self.assertTrue(watcher.poll(observer, output, state))
            self.assertEqual(state["events"], [])
            handoff.write_text("Updated handoff", encoding="utf-8")
            git(author, "add", "."); git(author, "commit", "-m", "Update")
            git(author, "push", "origin", "claude/test")
            self.assertTrue(watcher.poll(observer, output, state))
            self.assertEqual(len(state["events"]), 1)
            snapshot = output / "handoffs" / state["handoffs"]["claude/test"]
            self.assertIn("Updated handoff", snapshot.read_text())
            self.assertTrue(watcher.poll(observer, output, state))
            self.assertEqual(len(state["events"]), 1)
            git(author, "push", "origin", "HEAD:refs/heads/codex/test")
            watcher.poll(observer, output, state)
            self.assertEqual(state["events"][-1]["change"], "new branch")
            git(author, "push", "origin", "--delete", "claude/test")
            watcher.poll(observer, output, state)
            self.assertEqual(state["events"][-1]["change"], "deleted")
            heads = state["heads"].copy()
            git(observer, "remote", "set-url", "origin", str(base / "missing"))
            self.assertFalse(watcher.poll(observer, output, state))
            self.assertEqual(state["heads"], heads)
            self.assertIn("Check failed", (output / "status.html").read_text())
            self.assertEqual(git(observer, "status", "--porcelain"), before)

    def test_page_escapes_untrusted_text(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            watcher.render({"status": "<script>alert(1)</script>"}, directory)
            self.assertNotIn("<script>", (directory / "status.html").read_text())


if __name__ == "__main__":
    unittest.main()
