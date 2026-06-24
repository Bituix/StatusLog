#!/usr/bin/env python3
"""
rename_abap.py — Bulk rename ABAP objects downloaded via abapGit.

Renames files AND replaces matching text inside file contents, recursively.
Runs in dry-run mode by default; pass --apply to commit changes.

Usage examples:
  # Preview renames (dry-run):
  python rename_abap.py ./my_objects zmm_c_ zc_mm_

  # Apply changes:
  python rename_abap.py ./my_objects zmm_c_ zc_mm_ --apply

  # Case-sensitive match (default is case-insensitive):
  python rename_abap.py ./my_objects ZMMC_ ZC_MM_ --apply --case-sensitive

  # Multiple replacements via --pair OLD NEW (repeatable):
  python rename_abap.py ./my_objects --pair zmm_c_ zc_mm_ --pair zmm_r_ zr_mm_ --apply

  # Rename folder names too:
  python rename_abap.py ./my_objects zmm_c_ zc_mm_ --apply --rename-dirs
"""

import argparse
import os
import sys
import re
from pathlib import Path

BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".svg",
    ".pdf", ".zip", ".tar", ".gz", ".jar", ".class",
    ".exe", ".dll", ".so", ".bin",
}


def make_replacer(pairs: list[tuple[str, str]], case_sensitive: bool):
    """Return a function that applies all (old, new) replacements to a string."""
    flags = 0 if case_sensitive else re.IGNORECASE
    patterns = [(re.compile(re.escape(old), flags), new) for old, new in pairs]

    def replace(text: str) -> str:
        for pattern, new in patterns:
            text = pattern.sub(new, text)
        return text

    return replace


def is_binary(path: Path) -> bool:
    if path.suffix.lower() in BINARY_EXTENSIONS:
        return True
    try:
        with open(path, "rb") as f:
            chunk = f.read(8192)
        return b"\x00" in chunk
    except OSError:
        return True


def collect_renames(
    root: Path,
    replacer,
    rename_dirs: bool,
) -> list[tuple[Path, Path]]:
    """
    Walk bottom-up so child renames happen before parent renames.
    Returns list of (old_path, new_path) pairs where old != new.
    """
    renames = []
    for dirpath, dirnames, filenames in os.walk(root, topdown=False):
        dp = Path(dirpath)

        for fname in filenames:
            new_fname = replacer(fname)
            if new_fname != fname:
                renames.append((dp / fname, dp / new_fname))

        if rename_dirs and dp != root:
            new_dname = replacer(dp.name)
            if new_dname != dp.name:
                renames.append((dp, dp.parent / new_dname))

    return renames


def collect_content_changes(
    root: Path,
    replacer,
) -> list[tuple[Path, str, str]]:
    """
    Walk all files and return (path, old_content, new_content) for files that change.
    Skips binary files.
    """
    changes = []
    for dirpath, _, filenames in os.walk(root):
        for fname in filenames:
            fpath = Path(dirpath) / fname
            if is_binary(fpath):
                continue
            try:
                original = fpath.read_text(encoding="utf-8", errors="replace")
            except OSError as e:
                print(f"  [WARN] Cannot read {fpath}: {e}", file=sys.stderr)
                continue
            replaced = replacer(original)
            if replaced != original:
                changes.append((fpath, original, replaced))
    return changes


def preview(renames, content_changes):
    if renames:
        print(f"\nFile/folder renames ({len(renames)}):")
        for old, new in renames:
            print(f"  {old.name}  →  {new.name}")
            if old.parent != new.parent:
                print(f"    (in {old.parent})")
    else:
        print("\nNo file/folder renames.")

    if content_changes:
        print(f"\nContent replacements in ({len(content_changes)}) files:")
        for fpath, _, _ in content_changes:
            print(f"  {fpath}")
    else:
        print("\nNo content changes.")


def apply_content_changes(changes, dry_run: bool):
    for fpath, _, new_content in changes:
        if dry_run:
            continue
        fpath.write_text(new_content, encoding="utf-8")


def apply_renames(renames, dry_run: bool):
    for old, new in renames:
        if new.exists() and new != old:
            print(f"  [SKIP] Target already exists: {new}", file=sys.stderr)
            continue
        if not dry_run:
            old.rename(new)


def main():
    parser = argparse.ArgumentParser(
        description="Rename ABAP object files and their contents recursively.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("folder", help="Root folder to process")
    parser.add_argument("old", nargs="?", help="Text to replace (shorthand for single pair)")
    parser.add_argument("new", nargs="?", help="Replacement text (shorthand for single pair)")
    parser.add_argument(
        "--pair", nargs=2, metavar=("OLD", "NEW"), action="append", default=[],
        help="Replacement pair (repeatable); use instead of positional OLD/NEW for multiple pairs",
    )
    parser.add_argument("--apply", action="store_true", help="Actually apply changes (default is dry-run)")
    parser.add_argument("--case-sensitive", action="store_true", help="Case-sensitive matching (default: insensitive)")
    parser.add_argument("--rename-dirs", action="store_true", help="Also rename matching directory names")
    parser.add_argument("--no-content", action="store_true", help="Skip content replacement, rename only")
    parser.add_argument("--no-rename", action="store_true", help="Skip file renaming, content replace only")

    args = parser.parse_args()

    # Build replacement pairs
    pairs = list(args.pair)
    if args.old and args.new:
        pairs.insert(0, (args.old, args.new))
    elif args.old or args.new:
        parser.error("Provide both OLD and NEW positional arguments, or use --pair OLD NEW.")
    if not pairs:
        parser.error("No replacement pairs specified. Provide OLD NEW or --pair OLD NEW.")

    root = Path(args.folder).resolve()
    if not root.is_dir():
        parser.error(f"Folder not found: {root}")

    dry_run = not args.apply
    replacer = make_replacer(pairs, args.case_sensitive)

    print(f"Root   : {root}")
    print(f"Pairs  : {pairs}")
    print(f"Mode   : {'APPLY' if args.apply else 'DRY-RUN (pass --apply to commit)'}")
    print(f"Case   : {'sensitive' if args.case_sensitive else 'insensitive'}")

    renames = [] if args.no_rename else collect_renames(root, replacer, args.rename_dirs)
    content_changes = [] if args.no_content else collect_content_changes(root, replacer)

    preview(renames, content_changes)

    if dry_run:
        print("\nDry-run complete. No changes written.")
        return

    print("\nApplying content changes...")
    apply_content_changes(content_changes, dry_run=False)

    print("Applying renames...")
    apply_renames(renames, dry_run=False)

    print(f"\nDone. {len(content_changes)} file(s) updated, {len(renames)} item(s) renamed.")


if __name__ == "__main__":
    main()
