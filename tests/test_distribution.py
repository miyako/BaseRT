import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def load_script(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


POLICY = load_script("check-distribution")
SMOKE = load_script("smoke-native")


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def test_removed_engine_names_are_rejected_at_any_depth(self):
        for name in ("basert-bench", "basert-chat", "basert-complete", "basert-inspect",
                     "basert-serve", "basert-transcribe", "libbaseRT.dylib",
                     "baseRT.metallib", "baseRT_tensor.metallib", "basert-serve.exe"):
            with self.subTest(name=name):
                path = self.root / name
                path.write_bytes(b"fixture")
                with self.assertRaisesRegex(ValueError, "not distributable"):
                    POLICY.check_file(path, f"BaseRT/cache/old/{name}")

    def test_disguised_native_payloads_and_archives_are_rejected(self):
        for magic in (*POLICY.NATIVE_MAGIC, b"MZxx", b"PK\x03\x04"):
            with self.subTest(magic=magic):
                path = self.root / "innocent.dat"
                path.write_bytes(magic + b"fixture")
                with self.assertRaises(ValueError):
                    POLICY.check_file(path, "BaseRT/Resources/innocent.dat")

    def test_retained_native_exceptions_are_byte_pinned(self):
        for relative in POLICY.APPROVED_NATIVE:
            POLICY.check_file(ROOT / relative, relative)
            path = self.root / "changed"
            path.write_bytes(b"replacement")
            with self.assertRaisesRegex(ValueError, "modified native"):
                POLICY.check_file(path, relative)

    def test_compatibility_script_is_not_a_proprietary_server(self):
        POLICY.check_file(ROOT / "scripts/basert-serve", "scripts/basert-serve")

    def test_symlink_to_external_installation_is_rejected(self):
        link = self.root / "link"
        link.symlink_to(self.root / "external")
        with self.assertRaisesRegex(ValueError, "symlinks"):
            POLICY.check_file(link, "BaseRT/Resources/runtime")

    def test_ignored_self_hosted_resource_cache_is_checked_without_deleting_it(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / ".gitignore").write_text("BaseRT/\n")
        path = self.root / "BaseRT/Resources/cache/libbaseRT.dylib"
        path.parent.mkdir(parents=True)
        path.write_bytes(b"user-owned fixture")
        with self.assertRaisesRegex(ValueError, "not distributable"):
            POLICY.check_repository(self.root)
        self.assertEqual(path.read_bytes(), b"user-owned fixture")

    def test_current_worktree_distribution_inputs(self):
        POLICY.check_repository(ROOT)

    def test_git_ignores_removed_assets_but_not_the_source_compatibility_script(self):
        names = ("basert-bench", "basert-chat", "basert-complete", "basert-inspect",
                 "basert-serve", "basert-transcribe", "libbaseRT.dylib",
                 "baseRT.metallib", "baseRT_tensor.metallib")
        paths = {f"BaseRT/Resources/bin/macOS/{name}" for name in names}
        result = subprocess.check_output(
            ["git", "check-ignore", "--no-index", *sorted(paths)], cwd=ROOT, text=True,
        )
        self.assertEqual(set(result.splitlines()), paths)
        result = subprocess.run(
            ["git", "check-ignore", "--no-index", "scripts/basert-serve"],
            cwd=ROOT, capture_output=True,
        )
        self.assertEqual(result.returncode, 1)

    def test_legacy_publication_has_no_acknowledgment_bypass(self):
        workflow = (ROOT / ".github/workflows/publish.yml").read_text()
        gate = workflow.split("  authorize:\n", 1)[1].split("\n  publish:\n", 1)[0]
        self.assertIn("exit 1", gate)
        self.assertNotIn("if:", gate)
        self.assertNotIn("redistribution_permission", workflow)
        self.assertEqual(workflow.count("needs: authorize"), 2)

    def stage(self):
        files = {
            "basert", "basert-serve", "superfluid/bin/superfluid",
            "superfluid/bin/superfluid-workerd", "superfluid/bin/superfluid-noded",
            "superfluid/libexec/superfluid/superfluid-worker-basert",
            "licenses/basert/LICENSE", "licenses/basert/NOTICE",
            "licenses/superfluid/LICENSE", "licenses/superfluid/NOTICE",
        }
        for name in files:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / "scripts/basert-serve").read_bytes()
                             if name == "basert-serve" else b"fixture; never executed")
        self.metadata = {
            "engine_included": False,
            "sha256": {name: hashlib.sha256((self.root / name).read_bytes()).hexdigest()
                       for name in files},
        }
        self.write_metadata()

    def write_metadata(self):
        (self.root / "build-info.json").write_text(json.dumps(self.metadata))

    def assert_rejected_before_execution(self, message):
        with patch("sys.argv", ["smoke-native.py", str(self.root)]), \
                patch.object(SMOKE.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, message):
                SMOKE.main()
            run.assert_not_called()

    def test_unrecorded_engine_cache_is_rejected_before_execution(self):
        self.stage()
        (self.root / "libbaseRT.dylib").write_bytes(b"engine fixture")
        self.assert_rejected_before_execution("unrecorded")

    def test_declared_extra_payload_is_rejected_before_execution(self):
        self.stage()
        self.metadata["sha256"]["cached.dat"] = "unused"
        self.write_metadata()
        self.assert_rejected_before_execution("exactly the tooling")

    def test_legacy_server_substitution_is_rejected_before_execution(self):
        self.stage()
        server = self.root / "basert-serve"
        server.write_bytes(b"\xcf\xfa\xed\xfelegacy server fixture")
        self.metadata["sha256"]["basert-serve"] = hashlib.sha256(server.read_bytes()).hexdigest()
        self.write_metadata()
        self.assert_rejected_before_execution("compatibility script")

    def test_external_cache_symlink_is_rejected_before_execution(self):
        self.stage()
        binary = self.root / "basert"
        binary.unlink()
        binary.symlink_to(self.root / "outside")
        self.assert_rejected_before_execution("symlinks")


if __name__ == "__main__":
    unittest.main()
