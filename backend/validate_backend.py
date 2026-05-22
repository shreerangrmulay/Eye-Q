from __future__ import annotations

import argparse
import os
import shutil
import stat
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_DIRS = {
    "__pycache__",
    ".git",
    ".dart_tool",
    ".venv",
    "venv",
    "env",
    "node_modules",
    "uploads",
    "media",
}
EXCLUDED_SUFFIXES = {".pyc"}


def _inside_workspace(path: Path) -> bool:
    try:
        path.resolve().relative_to(ROOT)
        return True
    except ValueError:
        return False


def _make_writable(path: Path) -> None:
    try:
        path.chmod(path.stat().st_mode | stat.S_IWRITE)
    except OSError:
        pass


def _retry_writable(function, path: str, _exc_info) -> None:
    _make_writable(Path(path))
    function(path)


def clean_pycache() -> list[str]:
    failures: list[str] = []
    for cache_dir in sorted(ROOT.rglob("__pycache__"), key=lambda item: len(item.parts), reverse=True):
        if not _inside_workspace(cache_dir):
            failures.append(f"refused outside workspace: {cache_dir}")
            continue
        try:
            shutil.rmtree(cache_dir, onerror=_retry_writable)
        except OSError as exc:
            failures.append(f"{cache_dir}: {exc}")
    return failures


def iter_python_files(start: Path) -> list[Path]:
    files: list[Path] = []
    for current, dirnames, filenames in os.walk(start):
        dirnames[:] = [
            name for name in dirnames
            if name not in EXCLUDED_DIRS and not name.endswith(".egg-info")
        ]
        for filename in filenames:
            path = Path(current) / filename
            if path.suffix in EXCLUDED_SUFFIXES:
                continue
            if path.suffix == ".py":
                files.append(path)
    return sorted(files)


def validate_python_sources(paths: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in paths:
        try:
            source = path.read_text(encoding="utf-8")
            compile(source, str(path), "exec")
        except SyntaxError as exc:
            errors.append(f"{path}:{exc.lineno}:{exc.offset}: {exc.msg}")
        except OSError as exc:
            errors.append(f"{path}: {exc}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate backend Python without touching bytecode caches.")
    parser.add_argument(
        "paths",
        nargs="*",
        default=[str(ROOT / "backend" / "app")],
        help="Files or directories to validate. Defaults to backend/app.",
    )
    args = parser.parse_args()

    cleanup_failures = clean_pycache()
    if cleanup_failures:
        print("Cache cleanup warnings:", file=sys.stderr)
        for failure in cleanup_failures:
            print(f"  {failure}", file=sys.stderr)

    candidates: list[Path] = []
    for raw_path in args.paths:
        path = (ROOT / raw_path).resolve() if not Path(raw_path).is_absolute() else Path(raw_path).resolve()
        if not _inside_workspace(path):
            print(f"Refusing to validate outside workspace: {path}", file=sys.stderr)
            return 2
        if path.is_dir():
            candidates.extend(iter_python_files(path))
        elif path.suffix == ".py":
            candidates.append(path)

    errors = validate_python_sources(sorted(set(candidates)))
    if errors:
        print("Python validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1

    print(f"Validated {len(set(candidates))} Python source files without generating .pyc files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
