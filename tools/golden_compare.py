#!/usr/bin/env python3
"""Golden comparison of adaimg against SimpleITK.

Each case builds the same UInt16 pipeline on both sides and compares the
pixel buffers. Threshold, median, shrink, flip, crop, and rescale are
exact (rescale allows a difference of 1 for integer rounding). Blur,
resample, and gradient magnitude allow a small absolute tolerance because
those kernels round onto UInt16.

Add a case by appending a Golden(...) and the matching SimpleITK callable.
The same list is what a later YAML tests: hook should drive.

PNG spacing is whatever ITK stored. This fixture uses the default spacing
of 1, so -blur and -edge see the same geometry on both sides.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import SimpleITK as sitk


def make_fixture() -> sitk.Image:
    image = sitk.Image(8, 6, sitk.sitkUInt16)
    for y in range(6):
        for x in range(8):
            image[x, y] = (x * 40 + y * 300) % 5000
    image[3, 2] = 4000
    image[7, 5] = 50
    return image


def pixels(image: sitk.Image) -> np.ndarray:
    return sitk.GetArrayFromImage(image)


def run_ada(adaimg: Path, args: list[str]) -> None:
    completed = subprocess.run(
        [str(adaimg), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise SystemExit(
            f"adaimg {' '.join(args)} failed ({completed.returncode}): "
            f"{completed.stderr.strip()}"
        )


def threshold(image: sitk.Image) -> sitk.Image:
    # SimpleITK's procedural BinaryThreshold stores the inside value as
    # uint8. The mask is the same decision; scale the 0/1 result to the
    # UInt16 inside value adaimg writes (65535).
    mask = sitk.BinaryThreshold(image, 100, 2000, 1, 0)
    return sitk.Cast(mask, sitk.sitkUInt16) * 65535


def gradient(image: sitk.Image) -> sitk.Image:
    # SimpleITK returns a float magnitude. ITK's UInt16 output rounds it.
    magnitude = sitk.GradientMagnitude(image, useImageSpacing=True)
    return sitk.Cast(sitk.Round(magnitude), sitk.sitkUInt16)


def resample_150(image: sitk.Image) -> sitk.Image:
    scale = 1.5
    size = [max(1, int(round(image.GetSize()[i] * scale))) for i in range(2)]
    spacing = [image.GetSpacing()[i] / scale for i in range(2)]
    return sitk.Resample(
        image,
        size,
        sitk.Transform(),
        sitk.sitkLinear,
        image.GetOrigin(),
        spacing,
        image.GetDirection(),
        0,
        image.GetPixelID(),
    )


def compare(name: str, ada: sitk.Image, reference: sitk.Image, tolerance: int) -> None:
    left = pixels(ada)
    right = pixels(reference)
    if left.shape != right.shape:
        raise SystemExit(f"{name}: shape {left.shape} != {right.shape}")
    delta = np.abs(left.astype(np.int32) - right.astype(np.int32))
    worst = int(delta.max()) if delta.size else 0
    if worst > tolerance:
        raise SystemExit(f"{name}: max abs diff {worst} exceeds {tolerance}")
    print(f"ok {name} max_diff={worst} tolerance={tolerance}")


def check_identify(adaimg: Path, path: Path, image: sitk.Image) -> None:
    stats = sitk.StatisticsImageFilter()
    stats.Execute(image)
    completed = subprocess.run(
        [str(adaimg), "identify", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise SystemExit(completed.stderr.strip())
    text = completed.stdout.strip()
    size = image.GetSize()
    expected_bits = [
        f"{size[0]}x{size[1]}",
        "UInt16",
        f"min {int(stats.GetMinimum())}",
        f"max {int(stats.GetMaximum())}",
    ]
    for bit in expected_bits:
        if bit not in text:
            raise SystemExit(f"identify missing {bit!r} in {text!r}")
    # Mean is printed with four digits. Allow a small absolute gap.
    mean = stats.GetMean()
    tail = text.split("mean ", 1)[1]
    reported = float(tail.split()[0])
    if abs(reported - mean) > 0.05:
        raise SystemExit(f"identify mean {reported} != {mean}")
    print(f"ok identify {text}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adaimg", type=Path, required=True)
    args = parser.parse_args()
    adaimg = args.adaimg.resolve()
    if not adaimg.is_file():
        raise SystemExit(f"adaimg not found: {adaimg}")

    source = make_fixture()
    with tempfile.TemporaryDirectory(prefix="itklib-golden-") as folder:
        root = Path(folder)
        original = root / "in.png"
        sitk.WriteImage(source, str(original))
        loaded = sitk.ReadImage(str(original), sitk.sitkUInt16)

        missing = subprocess.run(
            [str(adaimg), str(root / "missing.png"), str(root / "out.png")],
            check=False,
            capture_output=True,
            text=True,
        )
        if missing.returncode == 0:
            raise SystemExit("missing input should fail")
        print("ok missing-file error")

        check_identify(adaimg, original, loaded)

        cases = [
            ("copy", [], lambda image: image, 0),
            ("blur", ["-blur", "1"], lambda image: sitk.DiscreteGaussian(
                image, variance=1.0, maximumError=0.01, useImageSpacing=True
            ), 2),
            ("median", ["-median", "1"], lambda image: sitk.Median(image, [1, 1]), 0),
            ("threshold", ["-threshold", "100:2000"], lambda image: threshold(image), 0),
            ("rescale", ["-rescale", "0:1000"], lambda image: sitk.RescaleIntensity(
                image, 0, 1000
            ), 1),
            ("shrink", ["-resize", "50%"], lambda image: sitk.Shrink(image, [2, 2]), 0),
            ("resample", ["-resize", "150%"], resample_150, 2),
            ("flip-x", ["-flip", "x"], lambda image: sitk.Flip(
                image, [True, False], flipAboutOrigin=True
            ), 0),
            ("flip-y", ["-flip", "y"], lambda image: sitk.Flip(
                image, [False, True], flipAboutOrigin=True
            ), 0),
            ("crop", ["-crop", "4x3+1+1"], lambda image: sitk.RegionOfInterest(
                image, [4, 3], [1, 1]
            ), 0),
            ("edge", ["-edge"], gradient, 2),
        ]

        for name, options, reference, tolerance in cases:
            output = root / f"{name}.png"
            run_ada(adaimg, [str(original), *options, str(output)])
            ada = sitk.ReadImage(str(output), sitk.sitkUInt16)
            compare(name, ada, reference(loaded), tolerance)

        chain_out = root / "chain.png"
        run_ada(
            adaimg,
            [str(original), "-median", "1", "-flip", "x", "-resize", "50%", str(chain_out)],
        )
        chained = sitk.Shrink(
            sitk.Flip(sitk.Median(loaded, [1, 1]), [True, False], True),
            [2, 2],
        )
        compare("chain", sitk.ReadImage(str(chain_out), sitk.sitkUInt16), chained, 0)

    print("golden comparisons passed")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 - report the comparison failure
        print(exc, file=sys.stderr)
        sys.exit(1)
