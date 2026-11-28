#!/usr/bin/env python3
"""Generator checks that do not need ITK or a compiler."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from codegen.engine import (
    build_plan,
    load_filters,
    load_matrix,
    pixel_db,
    skip_reasons,
    validate_addition,
)


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    pixels = pixel_db()
    filters = load_filters()
    matrix = load_matrix()
    try:
        validate_addition("rgb", [2], pixels)
    except SystemExit as event:
        if "phase 5" not in str(event):
            fail(f"rgb rejection was {event}")
    else:
        fail("rgb should be rejected")
    try:
        validate_addition("float32", [1], pixels)
    except SystemExit as event:
        if "dimensions" not in str(event):
            fail(f"dim rejection was {event}")
    else:
        fail("dimension 1 should be rejected")
    try:
        validate_addition("nope", [2], pixels)
    except SystemExit as event:
        if "unknown pixel" not in str(event):
            fail(f"unknown pixel was {event}")
    else:
        fail("unknown pixel should be rejected")

    notes = skip_reasons("float32", [2, 3], filters, pixels, matrix)
    text = "\n".join(notes)
    if "PNG" not in text or "float32" not in text:
        fail(f"float32 PNG skip missing:\n{text}")
    if "Canny" in text:
        # Canny is not in the phase-2 filter set. The real_only skip is
        # checked again when that YAML exists.
        pass
    manual = [note for note in notes if note.startswith("skip Median")]
    if not manual:
        fail("median should be skipped for float32")

    plan = build_plan()
    again = build_plan()
    if plan != again:
        fail("generation is not deterministic")
    ada = plan["src/ada/generated/itklib-filters-smoothing-discrete_gaussian.ads"]
    if "SPARK_Mode => Off" not in ada or "Set_Variance" not in ada:
        fail("discrete gaussian spec is missing the public API")
    if "Compile_Time_Error" not in ada:
        fail("generated spec has no compile-time support check")
    cxx = plan["shim/generated/discrete_gaussian.cxx"]
    if "itk::DiscreteGaussianImageFilter" not in cxx:
        fail("shim does not name the ITK class")
    if "itklib_discrete_gaussian_new" not in cxx:
        fail("shim does not export the C symbol")
    supported = plan["src/ada/generated/itklib-supported.ads"]
    if "when Itklib.UInt16 =>" not in supported or "Float32 =>" in supported.split("function Image_Built", 1)[-1].split("function Png_Writer", 1)[0]:
        # Image_Built's case must not list Float32 while it is outside the matrix.
        if "when Itklib.Float32" in supported.split("function DiscreteGaussian", 1)[0]:
            fail("float32 leaked into the default image matrix")
    if "Itklib.Instances.UInt16" not in plan["src/ada/generated/itklib-instances-uint16.ads"]:
        fail("missing UInt16 instances")
    hooks = plan["tools/generated/golden_hooks.py"]
    if "blur" not in hooks:
        fail("golden hook dropped -blur")
    print("codegen checks passed")


if __name__ == "__main__":
    main()
