#!/usr/bin/env python3
"""Verify source-built CLI contracts without downloading an engine or model."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", type=Path)
    args = parser.parse_args()
    runtime = args.runtime.resolve()
    metadata = json.loads((runtime / "build-info.json").read_text())
    if metadata["engine_included"] is not False:
        raise ValueError("Source-only artifacts must not include the proprietary engine")
    for name, expected in metadata["sha256"].items():
        actual = hashlib.sha256((runtime / name).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"{name}: staged binary hash mismatch")
    forbidden = ("libbaseRT*", "*.metallib", "basert-chat", "basert-complete", "basert-bench",
                 "basert-inspect", "basert-transcribe")
    for pattern in forbidden:
        if list(runtime.rglob(pattern)):
            raise ValueError(f"Source-only stage contains an engine/legacy companion: {pattern}")

    with tempfile.TemporaryDirectory(prefix="basert-smoke-") as directory:
        env = dict(os.environ, HOME=directory, BASERT_SUPERFLUID_AUTO_INSTALL="0",
                   BASERT_SUPERFLUID_DIR=str(runtime / "superfluid"),
                   BASERT_LIB=str(Path(directory) / "engine-not-installed"),
                   SUPERFLUID_WORKER_BASERT=str(runtime / "superfluid/libexec/superfluid/superfluid-worker-basert"),
                   SUPERFLUID_NO_UPDATE_CHECK="1",
                   SUPERFLUID_HOME=str(Path(directory) / "superfluid"),
                   XDG_CACHE_HOME=str(Path(directory) / "cache"),
                   BASERT_STATE_DIR=str(Path(directory) / "state"))
        commands = [
            ([runtime / "basert", "--version"], metadata["basert"]["version"]),
            ([runtime / "basert", "--help"], "serve"),
            ([runtime / "basert", "serve", "--help"], "--max-context"),
            ([runtime / "basert-serve", "--help"], "--max-context"),
            ([runtime / "basert-serve", "--version"], metadata["basert"]["version"]),
            ([runtime / "superfluid/bin/superfluid", "--version"], metadata["superfluid"]["version"]),
            ([runtime / "superfluid/bin/superfluid", "--help"], "serve"),
            ([runtime / "superfluid/bin/superfluid", "serve", "--help"], "runtime"),
        ]
        for command, expected in commands:
            result = subprocess.run(list(map(str, command)), env=env, text=True,
                                    capture_output=True, timeout=30, check=True)
            if expected not in result.stdout + result.stderr:
                raise ValueError(f"{command}: expected {expected!r} in help/version output")
            print("Passed:", " ".join(map(str, command)))
        status = subprocess.run([str(runtime / "basert"), "superfluid", "status"],
                                env=env, text=True, capture_output=True, timeout=30)
        if status.returncode != 2 or str(runtime / "superfluid") not in status.stdout + status.stderr:
            raise ValueError(f"Expected the staged server to be recognized but engine unavailable: {status}")
        probe = subprocess.run([str(runtime / "superfluid/bin/superfluid"), "runtimes", "--json"],
                               env=env, text=True, capture_output=True, timeout=30, check=True)
        basert = next(item for item in json.loads(probe.stdout) if item["id"] == "basert")
        if basert["worker"]["path"] != env["SUPERFLUID_WORKER_BASERT"]:
            raise ValueError(f"The staged BaseRT worker was not selected: {basert}")
        if basert["state"] == "ready" or "libbaseRT" not in basert.get("ready", ""):
            raise ValueError(f"Expected an explicit missing-engine diagnostic: {basert}")
        print("Passed: staged server/worker discovery and explicit missing-engine diagnostics.")
    print("CLI smoke checks passed. No engine/model was loaded; inference is not validated.")


if __name__ == "__main__":
    main()
