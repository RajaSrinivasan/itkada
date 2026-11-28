#!/usr/bin/env python3
"""Regenerate committed itklib sources from tools/filters and tools/matrix.yaml.

    python3 tools/generate.py
    python3 tools/generate.py --check
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from codegen.engine import apply_plan, build_plan, diff_plan, load_filters, modules_missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if generated files differ")
    parser.add_argument("--diff", action="store_true", help="print the diff and write nothing")
    args = parser.parse_args()
    missing = modules_missing(load_filters())
    if missing:
        print("ITK modules missing from tools/itk_modules.txt:", file=sys.stderr)
        for item in missing:
            print(f"  {item}", file=sys.stderr)
        return 1
    plan = build_plan()
    if args.diff or args.check:
        text = diff_plan(plan)
        if text:
            sys.stdout.write(text)
            if args.check:
                print("generated sources are stale; run python3 tools/generate.py", file=sys.stderr)
                return 1
        elif args.check:
            print("generated sources match the YAML")
        return 0
    changed = apply_plan(plan)
    if changed:
        print("updated:")
        for path in changed:
            print(f"  {path}")
    else:
        print("generated sources already match the YAML")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
