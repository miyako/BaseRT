#!/usr/bin/env python3
"""Reject engine assets and unreviewed binary payloads in the distributable tree."""

import hashlib
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
# Retain only these existing, unrelated/open-source native assets, byte-for-byte.
APPROVED_NATIVE = {
    "BaseRT/Resources/bin/macOS/basert":
        "0f2693c75280525746179e91575fecfe9038a4567dba38becca028ec096bb5ba",
    "BaseRT/Libraries/lib4d-arm64.dylib":
        "de5b8943f7a33f52124297d25dab11d49b3182cad93714f8bf052f79c75e53d1",
}
NATIVE_MAGIC = {
    b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf",
    b"\xfe\xed\xfa\xce", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca", b"\x7fELF", b"MTLB",
}


def check_file(path, relative):
    name = path.name.lower().removesuffix(".exe")
    if (name.startswith("libbasert") or name.endswith(".metallib")
            or name in {"basert-bench", "basert-chat", "basert-complete", "basert-inspect",
                        "basert-serve", "basert-transcribe"}):
        if relative != "scripts/basert-serve":
            raise ValueError(f"{relative}: engine/runtime asset is not distributable here")
    if path.is_symlink():
        raise ValueError(f"{relative}: symlinks are not allowed in distribution inputs")
    with path.open("rb") as stream:
        magic = stream.read(4)
    if magic in NATIVE_MAGIC or magic[:2] == b"MZ" or relative in APPROVED_NATIVE:
        expected = APPROVED_NATIVE.get(relative)
        if not expected or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f"{relative}: unreviewed or modified native payload")
    # Do not let an archive hide a stale engine in source/component resources.
    if magic in {b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08"} or name.endswith(
            (".zip", ".dmg", ".tar", ".gz", ".xz", ".7z", ".4dz")):
        raise ValueError(f"{relative}: opaque archives are not allowed in distribution inputs")


def check_repository(root):
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=root,
    ).decode().split("\0")
    paths = {root / name for name in tracked if name
             and ((root / name).exists() or (root / name).is_symlink())}
    # Include ignored/stale files from self-hosted workspaces, not just Git's index.
    paths.update(path for path in (root / "BaseRT").rglob("*")
                 if path.is_file() or path.is_symlink())
    for path in sorted(paths):
        check_file(path, path.relative_to(root).as_posix())


if __name__ == "__main__":
    try:
        check_repository(ROOT)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"Distribution check failed: {error}")
    print("Distribution inputs contain no engine assets or unreviewed native payloads.")
