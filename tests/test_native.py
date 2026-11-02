import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("build_native", ROOT / "scripts/build-native.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class OutputPreservationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.output = Path(self.directory.name)
        (self.output / "basert").write_bytes(b"source-built fixture")
        checksum = hashlib.sha256((self.output / "basert").read_bytes()).hexdigest()
        (self.output / "build-info.json").write_text(json.dumps({
            "engine_included": False, "sha256": {"basert": checksum},
        }))

    def test_unchanged_generated_output_can_be_replaced(self):
        BUILD.verify_output(self.output)

    def test_unrelated_file_is_preserved(self):
        extra = self.output / "user-file.txt"
        extra.write_text("preserve")
        with self.assertRaisesRegex(ValueError, "unexpected files"):
            BUILD.verify_output(self.output)
        self.assertEqual(extra.read_text(), "preserve")

    def test_modified_binary_is_preserved(self):
        binary = self.output / "basert"
        binary.write_bytes(b"user-modified")
        with self.assertRaisesRegex(ValueError, "modified files"):
            BUILD.verify_output(self.output)
        self.assertEqual(binary.read_bytes(), b"user-modified")

    def test_symlink_is_rejected(self):
        (self.output / "alias").symlink_to(self.output / "basert")
        with self.assertRaisesRegex(ValueError, "unexpected runtime"):
            BUILD.verify_output(self.output)

    def test_engine_artifacts_are_not_an_owned_source_stage(self):
        info = json.loads((self.output / "build-info.json").read_text())
        info["engine_included"] = True
        (self.output / "build-info.json").write_text(json.dumps(info))
        with self.assertRaisesRegex(ValueError, "unexpected runtime"):
            BUILD.verify_output(self.output)


if __name__ == "__main__":
    unittest.main()
