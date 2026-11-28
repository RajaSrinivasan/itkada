#!/usr/bin/env python3
"""Add or remove one ITK scalar pixel type.

    tools/add_pixel_type.py --pixel float32 --dims 2,3 --dry-run
    tools/add_pixel_type.py --pixel float32 --dims 2,3
    tools/add_pixel_type.py --pixel float32 --remove

The default matrix stays UInt16. This command edits tools/matrix.yaml and
regenerates the committed sources. --dry-run and --diff write nothing.
PNG writers are not generated for pixels PNG cannot store; the reason is
printed. RGB, vector, and complex pixels are rejected until phase 5.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from codegen.engine import (
    apply_plan,
    build_plan,
    diff_plan,
    load_filters,
    load_matrix,
    pixel_db,
    skip_reasons,
    try_compile,
    validate_addition,
    write_matrix,
)


def parse_dims(text: str) -> list[int]:
    dims = []
    for piece in text.split(","):
        piece = piece.strip()
        if not piece:
            continue
        dims.append(int(piece))
    return dims


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pixel", required=True)
    parser.add_argument("--dims", default="2,3")
    parser.add_argument("--filters", default="", help="comma-separated allow-list; default is every eligible filter")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--diff", action="store_true")
    parser.add_argument("--remove", action="store_true")
    args = parser.parse_args()
    dims = parse_dims(args.dims)
    pixels = pixel_db()
    filters = load_filters()
    matrix = load_matrix()
    validate_addition(args.pixel, dims, pixels)
    names = [pixel["name"] for pixel in matrix["pixels"]]
    if args.remove:
        if args.pixel == "uint16":
            raise SystemExit("refusing to remove the pre-built uint16 pixel")
        if args.pixel not in names:
            raise SystemExit(f"{args.pixel} is not in the matrix")
        updated = {
            "dimensions": matrix["dimensions"],
            "pixels": [pixel for pixel in matrix["pixels"] if pixel["name"] != args.pixel],
        }
    else:
        notes = skip_reasons(args.pixel, dims, filters, pixels, matrix)
        for note in notes:
            print(note)
        allow = [item.strip() for item in args.filters.split(",") if item.strip()] or None
        if allow:
            unknown = [item for item in allow if item not in {filt["name"] for filt in filters}]
            if unknown:
                raise SystemExit(f"unknown filters: {', '.join(unknown)}")
        if args.pixel in names:
            print(f"{args.pixel} is already in the matrix; regeneration is a no-op when the files match")
            updated = matrix
            for pixel in updated["pixels"]:
                if pixel["name"] == args.pixel:
                    pixel["filters"] = allow
        else:
            extra_dims = [dim for dim in dims if dim not in matrix["dimensions"]]
            dimensions = list(matrix["dimensions"])
            for dim in extra_dims:
                dimensions.append(dim)
            updated = {
                "dimensions": dimensions,
                "pixels": list(matrix["pixels"]) + [{"name": args.pixel, "filters": allow}],
            }
    plan = build_plan(matrix=updated)
    if args.dry_run:
        print("dry-run: no files written")
        print(f"matrix pixels: {', '.join(pixel['name'] for pixel in updated['pixels'])}")
        return 0
    if args.diff:
        # Show the plan against the current tree without writing matrix.yaml.
        sys.stdout.write(diff_plan(plan))
        return 0
    if not args.remove and args.pixel not in names:
        try_compile(pixels[args.pixel], dims)
    write_matrix(updated)
    changed = apply_plan(plan)
    if changed:
        print("updated:")
        for path in changed:
            print(f"  {path}")
    else:
        print("sources already match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
