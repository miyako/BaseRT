#!/usr/bin/env python3
"""Exercise production 4D argument building/dispatch with controlled test components."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d", required=True, type=Path, help="path to tool4d executable (4D 21+)")
    args = parser.parse_args()
    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="4d-test-", dir=build) as directory:
        fixture = Path(directory) / "fixture"
        shutil.copytree(
            ROOT / "tests/4d", fixture,
        )
        classes = fixture / "Project/Sources/Classes"
        for name in ("_CLI", "_CLI_Controller", "_server", "_models", "_Model", "_startup", "_interface", "BaseRT"):
            shutil.copy2(ROOT / f"BaseRT/Project/Sources/Classes/{name}.4dm", classes)
        shutil.copy2(ROOT / "BaseRT/Project/Sources/Methods/start.4dm",
                     fixture / "Project/Sources/Methods")
        shutil.copy2(ROOT / "BaseRT/Project/Sources/Methods/terminatePending.4dm",
                     fixture / "Project/Sources/Methods")
        shutil.copy2(ROOT / "BaseRT/Project/Sources/Methods/onModel.4dm",
                     fixture / "Project/Sources/Methods")
        shutil.copy2(ROOT / "BaseRT/Project/Sources/Methods/main.4dm",
                     fixture / "Project/Sources/Methods")
        (fixture / "Resources/bin/macOS").mkdir(parents=True)
        result_path = Path(directory) / "result.json"
        try:
            subprocess.run(
                [str(args.tool4d.resolve()), str(fixture / "Project/Smoke.4DProject"),
                 "--skip-onstartup", "--startup-method=smoke", "--dataless",
                 f"--user-param={result_path}"],
                check=True, timeout=120,
            )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            if result_path.exists():
                print(f"Last 4D result/checkpoint: {result_path.read_text()}", flush=True)
            raise
        result = json.loads(result_path.read_text())
        if result.get("fatal") or result["errors"]:
            raise ValueError(f"4D regression checks failed: {result}")
        print("4D checks passed: argument separation/escaping, numeric/multi-model options, "
              "source-runtime environment, adapter-only option filtering, local-model dispatch, "
              "invalid runtime/missing-model errors, absent event object, and "
              "per-destination download/attempt failure/cancellation/stale-callback scheduling.")
        print("Controlled event/worker components were used; no model/engine was loaded.")
        diagnostics = result["syntax"].get("errors", [])
        print(f"Compiler syntax-only check passed ({len(diagnostics)} fixture warnings); "
              "this is not a full resolved-component/host compatibility check.")


if __name__ == "__main__":
    main()
