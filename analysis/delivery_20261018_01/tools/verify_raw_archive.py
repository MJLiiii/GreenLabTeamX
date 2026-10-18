"""Offline ZIP verification only; no extraction, experiments or analysis."""
import argparse
import csv
import hashlib
import json
import stat
import zipfile
from pathlib import Path, PurePosixPath

def file_sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def load_manifest(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != 261 or len({r["path"].casefold() for r in rows}) != 261:
        raise ValueError("Expected exactly261 unique manifest paths")
    for row in rows:
        name = row["path"]
        parts = PurePosixPath(name).parts
        if not name.startswith("results/main/") or "\\" in name or ":" in name or name.startswith("/") or ".." in parts or "." in parts:
            raise ValueError("Unsafe manifest path: " + name)
        if str(PurePosixPath(name)) != name:
            raise ValueError("Non-canonical manifest path: " + name)
    return rows

def verify(archive_path, manifest_path, expected_sha256):
    actual_archive_sha = file_sha(archive_path)
    if actual_archive_sha != expected_sha256.lower():
        raise ValueError("Archive SHA-256 mismatch")
    required = {r["path"]: r for r in load_manifest(manifest_path)}
    results = []
    with zipfile.ZipFile(archive_path) as archive:
        infos = archive.infolist()
        names = [i.filename for i in infos]
        if len(infos) != 261 or len(set(n.casefold() for n in names)) != 261 or set(names) != set(required):
            raise ValueError("ZIP entries differ from exactly261 manifest files")
        for info in infos:
            mode = info.external_attr >> 16
            if info.is_dir() or stat.S_IFMT(mode) not in (0, stat.S_IFREG) or info.flag_bits & 1:
                raise ValueError("Unexpected directory/symlink/encrypted member: " + info.filename)
            digest, size = hashlib.sha256(), 0
            with archive.open(info, "r") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk); size += len(chunk)
            row = required[info.filename]
            passed = size == int(row["bytes"]) == info.file_size and digest.hexdigest() == row["sha256"]
            results.append({"path": info.filename, "expected_bytes": int(row["bytes"]), "decompressed_bytes": size,
                "expected_sha256": row["sha256"], "decompressed_sha256": digest.hexdigest(),
                "zip_crc32": f"{info.CRC:08x}", "passed": passed})
    if not all(r["passed"] for r in results):
        raise ValueError("One or more decompressed members differ from approved bytes")
    return {"passed": True, "archive_sha256": actual_archive_sha, "files": len(results),
        "uncompressed_bytes": sum(r["decompressed_bytes"] for r in results),
        "exact_manifest_members": True, "paths_unique_and_safe": True,
        "all_sizes_and_sha256_match": True, "crc_checked_by_full_stream_reads": True,
        "verification_mode": "decompress each member to a read-only memory stream; no filesystem extraction"}, results

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--expected-sha256", required=True)
    args = parser.parse_args()
    summary, _ = verify(args.archive, args.manifest, args.expected_sha256)
    print(json.dumps(summary, indent=2))
