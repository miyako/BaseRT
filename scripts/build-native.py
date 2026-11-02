#!/usr/bin/env python3
"""Build only the open BaseRT frontend/server; never fetch or stage the engine."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build"


def run(*args, cwd=ROOT, env=None, capture=False):
    print("+", " ".join(map(str, args)), flush=True)
    result = subprocess.run(
        list(map(str, args)), cwd=cwd, env=env, check=True,
        text=True, stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_output(path):
    info = json.loads((path / "build-info.json").read_text())
    expected = info["sha256"]
    files = list(path.rglob("*"))
    if info.get("engine_included") is not False or any(item.is_symlink() for item in files):
        raise ValueError(f"{path}: refusing to replace an unexpected runtime")
    actual = {str(item.relative_to(path)) for item in files if item.is_file()}
    if actual != set(expected) | {"build-info.json"}:
        raise ValueError(f"{path}: preserve unexpected files before rebuilding")
    if any(digest(path / name) != checksum for name, checksum in expected.items()):
        raise ValueError(f"{path}: preserve modified files before rebuilding")


def checkout(name, source, offline):
    path = BUILD / f"{name}-src"
    git_env = dict(os.environ, GIT_NO_LAZY_FETCH="1") if offline else None
    if path.is_symlink():
        raise ValueError(f"Refusing symlinked source directory: {path}")
    if not path.exists():
        if offline:
            raise ValueError(f"Offline source checkout is missing: {path}")
        run("git", "clone", "--filter=blob:none", source["repository"], path)
    remote = run("git", "remote", "get-url", "origin", cwd=path, env=git_env, capture=True)
    if remote != source["repository"]:
        raise ValueError(f"{path}: origin does not match the pinned repository")
    if run("git", "status", "--porcelain", cwd=path, env=git_env, capture=True):
        raise ValueError(f"{path}: source has local changes; preserve them before rebuilding")
    if not offline:
        run("git", "fetch", "--depth=1", "origin", source["revision"], cwd=path)
    run("git", "checkout", "--detach", source["revision"], cwd=path, env=git_env)
    actual = run("git", "rev-parse", "HEAD", cwd=path, env=git_env, capture=True)
    if actual != source["revision"]:
        raise ValueError(f"{path}: revision mismatch")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="cargo clean both pinned workspaces first")
    parser.add_argument("--offline", action="store_true", help="use existing checkouts and Cargo cache only")
    parser.add_argument("--jobs", type=int, help="limit Cargo parallel jobs")
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("This component build supports native Apple Silicon macOS only")
    if args.jobs is not None and args.jobs < 1:
        raise ValueError("--jobs must be positive")
    config = json.loads((ROOT / "native-sources.json").read_text())
    if BUILD.is_symlink():
        raise ValueError("Refusing symlinked .build directory")
    BUILD.mkdir(exist_ok=True)
    env = dict(os.environ, MACOSX_DEPLOYMENT_TARGET=config["macos_deployment_target"])
    toolchain = config["rust_toolchain"]
    rust = run("rustup", "run", toolchain, "rustc", "-Vv", capture=True)
    if f"host: {config['target']}" not in rust:
        raise ValueError("The pinned Rust toolchain must be installed for Apple Silicon macOS")
    sources = {
        name: checkout(name, config[name], args.offline)
        for name in ("basert", "superfluid")
    }
    manifests = {
        "basert": sources["basert"] / "base-convert/Cargo.toml",
        "superfluid": sources["superfluid"] / "Cargo.toml",
    }
    for name, manifest in manifests.items():
        cargo = ["rustup", "run", toolchain, "cargo"]
        build_env = dict(env)
        build_env.pop("CARGO_BUILD_TARGET", None)
        target_dir = manifest.parent / "target"
        if args.force:
            run(*cargo, "clean", "--manifest-path", manifest, "--target-dir", target_dir, env=build_env)
        command = cargo + ["build", "--manifest-path", str(manifest),
                           "--target-dir", str(target_dir), "--locked", "--release"]
        if args.offline:
            command.append("--offline")
        if args.jobs:
            command += ["--jobs", str(args.jobs)]
        if name == "basert":
            command += ["-p", "base-convert", "--bin", "basert"]
        else:
            command += ["-p", "superfluid", "--bins", "-p", "superfluid-adapter-basert",
                        "--bin", "superfluid-worker-basert"]
        run(*command, env=build_env)

    output = BUILD / "runtime"
    if output.is_symlink():
        raise ValueError("Refusing symlinked runtime output")
    if output.exists() and not (output / "build-info.json").is_file():
        raise ValueError("Refusing to overwrite an unrecognized runtime directory")
    if output.exists():
        verify_output(output)
    with tempfile.TemporaryDirectory(prefix="native-stage-", dir=BUILD) as directory:
        stage = Path(directory)
        stage_runtime(stage, sources, manifests, config, rust, toolchain, env)
        previous = BUILD / "runtime-previous"
        if previous.exists() or previous.is_symlink():
            raise ValueError(f"Preserve/remove the previous runtime manually before retrying: {previous}")
        if output.exists():
            output.rename(previous)
        stage.rename(output)
        if previous.exists():
            shutil.rmtree(previous)
    print(f"Source-built tooling: {output}\nNo proprietary engine was downloaded, copied, or changed.")


def stage_runtime(stage, sources, manifests, config, rust, toolchain, env):
    products = {
        "basert": manifests["basert"].parent / "target/release/basert",
        "superfluid/bin/superfluid": sources["superfluid"] / "target/release/superfluid",
        "superfluid/bin/superfluid-workerd": sources["superfluid"] / "target/release/superfluid-workerd",
        "superfluid/bin/superfluid-noded": sources["superfluid"] / "target/release/superfluid-noded",
        "superfluid/libexec/superfluid/superfluid-worker-basert":
            sources["superfluid"] / "target/release/superfluid-worker-basert",
    }
    for destination, source in products.items():
        output = stage / destination
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, output)
    for name, source in sources.items():
        notices = stage / "licenses" / name
        notices.mkdir(parents=True, exist_ok=True)
        for filename in ("LICENSE", "NOTICE"):
            notice = source / filename
            if not notice.is_file():
                raise ValueError(f"{name}: required upstream {filename} is missing")
            shutil.copy2(notice, notices / filename)
    # Adapt the standalone launcher to the 4D server entry-point contract.
    shutil.copy2(ROOT / "scripts/basert-serve", stage / "basert-serve")
    (stage / "basert-serve").chmod(0o755)
    metadata = {
        **config,
        "rustc": rust,
        "cargo": run("rustup", "run", toolchain, "cargo", "--version", capture=True),
        "xcode": run("xcodebuild", "-version", capture=True),
        "sdk": run("xcrun", "--show-sdk-version", capture=True),
        "host_macos": platform.mac_ver()[0],
        "engine_included": False,
        "lockfile_sha256": {name: digest(path.parent / "Cargo.lock")
                            for name, path in manifests.items()},
        "sha256": {str(path.relative_to(stage)): digest(path)
                   for path in sorted(stage.rglob("*")) if path.is_file()},
    }
    (stage / "build-info.json").write_text(json.dumps(metadata, indent=2) + "\n")
    run(sys.executable, ROOT / "scripts/smoke-native.py", stage, env=env)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"Native build failed: {error}")
