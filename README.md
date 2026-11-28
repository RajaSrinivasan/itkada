# itklib

Ada binding for the [Insight Toolkit](https://itk.org/). The Alire crate,
GPR project, and shared library are `itklib`. The top-level Ada package is
`Itklib`. C shim symbols use the `itklib_` prefix. This repository stays
`itkada`.

Phase 1 is the MVP: 2D and 3D `UInt16` images, geometry, zero-copy buffers,
PNG I/O, and the `adaimg` filters. Phase 2 generates filters and pixel
types from YAML. ITK does the work. Ada holds controlled handles and a
lazy pipeline. Design background is the
[itklib strategy](https://cursor.com/canvas/store-87a8889a-1eb8-4d47-b94b-44c9de3de305/14b526e1-7e87-4d37-a858-2f4b4d3bb64f)
(still a draft). Tracked by GitHub issues #1, #2, and #11–#28.

Defaults from issue #2, used here: typed generics, the lazy pipeline (no
one-call convenience layer), float32 left for the generator, and
ImageMagick-like `adaimg` options.

## Layout

```
alire.toml                 Alire crate manifest
itklib.gpr                 Ada + C++ library project
src/ada/                   Itklib.* sources
examples/adaimg/           adaimg CLI
shim/                      extern "C" shim (itklib.h and the .cxx files)
tests/                     Phase 0 and Phase 1 drivers, SPARK projects
tools/build_itk.sh         ITK 5.4.8 build
tools/itk_modules.txt      modules that build enables
tools/itk_paths/           CMake probe that writes itk_paths.gpr
tools/filters/             one YAML file per filter
tools/matrix.yaml          pre-built pixel/dimension matrix
tools/pixel_types.yaml     ITK scalar pixel catalog
tools/generate.py          YAML + Jinja2 generator
tools/add_pixel_type.py    add or remove a pixel type
tools/run_phase0_tests.sh
tools/run_phase1_tests.sh  unit tests, adaimg smoke, SPARK, goldens
tools/run_phase2_tests.sh  freshness, phase 1, float32 generator leg
tools/run_spark.sh         gnatprove silver
tools/golden_compare.py    SimpleITK comparison
```

`itk_paths.gpr` and `config/` are generated. They are not committed.

## Build ITK

The shim needs ITK **5.4.8 or newer**, discovered through `ITK_DIR` or
`CMAKE_PREFIX_PATH`. Ubuntu packages are older than that, so the default
step builds the `v5.4.8` release with the modules in
`tools/itk_modules.txt` (Common, PNG, smoothing, thresholding, intensity,
grid, gradient, and the modules those pull in). Install prefix defaults to
`/opt/itk-5.4.8`.

```
alr toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
alr exec -- bash tools/build_itk.sh
```

Use the Alire `g++` for that build. The shim is compiled with the same
compiler, and the generated GPR records an rpath to its `libstdc++`.

A matching stamp under the prefix makes a later run return immediately.
`ITK_FORCE_BUILD=1` rebuilds. `ITK_PREFIX` and `ITK_BUILD_JOBS` override
the prefix and the Ninja job count.

### Version bump policy

Crate versions are independent of ITK. The floor is 5.4.8
(`find_package(ITK 5.4.8)`). A scheduled check should compare the newest
non-prerelease ITK git tag with the distro package and use whichever is
newer. If the distro package is at least the tag, CI can skip the source
build. Betas such as 6.0b02 stay on a non-blocking job. The workflow in
this repo builds and caches 5.4.8. `.github/workflows/itk-version-watch.yml`
prints the tag and the apt version; it does not change the pin.

## Build and test itklib

```
export ITK_DIR=/opt/itk-5.4.8/lib/cmake/ITK-5.4   # if it is not the default
alr build
bash tools/run_phase1_tests.sh
```

`alr build` runs `tools/generate_itk_paths.sh` first. That probe calls
`find_package` and writes include paths, compile flags, and the link line
into `itk_paths.gpr`. It does not run Python. Generated Ada and C++ are
already committed.

```
python3 tools/generate.py --check
bash tools/run_phase2_tests.sh
```

`tools/run_phase2_tests.sh` reruns the phase 1 suite, checks that a
float32 `DiscreteGaussian` is rejected at compile time, then runs
`tools/add_pixel_type.py --pixel float32 --dims 2,3` and builds that
instantiation. The default matrix stays UInt16. Set
`ITKLIB_SKIP_FLOAT32=1` to skip that leg.

`tools/run_phase1_tests.sh` builds the library, runs the Phase 0 driver,
the Phase 1 driver, an `adaimg` smoke test, `gnatprove` silver (unless
`ITKLIB_SKIP_SPARK=1`), and `tools/golden_compare.py` when SimpleITK is
importable. Golden comparisons need:

```
python3 -m pip install SimpleITK itk
```

`itk` is imported by the CI job so the package stays installable. The
pixel comparison itself uses SimpleITK.

### What the tests cover

- 2D and 3D `UInt16` images, regions, and a zero-copy buffer
- controlled-handle `Register` / `UnRegister`
- spacing, origin, direction, and index ↔ physical point
- PNG round trip, including spacing that PNG's pHYs chunk can store exactly
- `Itk_Error` on a missing file, a crop outside a known image, and an
  `Update` attempted while `With_Buffer` holds the output
- `Unsupported_Instantiation` for a pixel or dimension that was not built
- a compile-time rejection when a pixel's size does not match its kind
- statistics, median, threshold, rescale, shrink, resample, flip, crop,
  gradient magnitude, and discrete gaussian (2D checks and 3D smokes)
- a pipeline whose Ada filter variables are finalized before `Update`
- the `adaimg` argument parser

## adaimg

`examples/adaimg` is an ImageMagick-style tool on the public Ada API, 2D
`UInt16`, and PNG. Options only connect stages. The writer's `Update` runs
the chain. Intermediate filters stay alive through pipeline links after
each `Apply` returns.

```
adaimg identify chest.png
adaimg in.png out.png
adaimg chest.png -blur 2 -threshold 12000:40000 -rescale 0:65535 -resize 50% mask.png
adaimg chest.png -median 1 -edge -flip x -crop 4x3+1+1 edges.png
```

`identify` prints the path, `PNG`, `2D`, size, `UInt16`, spacing, min, max,
and mean. Spacing has no unit: PNG does not carry ITK's spatial units.

| Option | Filter | Notes |
| --- | --- | --- |
| `identify` | reader + `Statistics` | size, spacing, min, max, mean |
| `-blur sigma` | `Discrete_Gaussian` | variance is `sigma²` on x and y. Not ImageMagick's radius |
| `-median r` | `Median` | neighborhood radius on x and y (1 is a 3-wide window) |
| `-threshold lo:hi` | `Binary_Threshold` | inside 65535, outside 0, inclusive bounds |
| `-rescale lo:hi` | `Rescale_Intensity` | output minimum and maximum |
| `-resize N%` | `Shrink` or `Resample` | see below |
| `-flip x` or `-flip y` | `Flip` | ITK also moves the origin (`FlipAboutOrigin` true) |
| `-crop WxH+X+Y` | `Extract` | index `(X,Y)`, size `(W,H)`, origin 0. `+` only |
| `-edge` | `Gradient_Magnitude` | UInt16 magnitude. Canny needs float32 and is not in this phase |

`-resize`: `N` is a positive integer. `100%` copies the image. If `N < 100`
and `100` is divisible by `N`, the image is shrunk by `100/N` on each axis
(`50%` is factor 2). ITK then multiplies spacing by that factor and shifts
the origin so the physical centers match. Any other `N`, including
enlargement, uses `Resample` with a linear interpolator and the identity
transform. Output size is `max(1, round(input * N/100))` and spacing is
divided by the same scale. The scale is applied when `Update` runs, so the
reader does not have to execute early.

`-edge` is gradient magnitude cast to `UInt16`, so the PNG writer needs no
cast. Canny and other real-valued edge detectors wait for
`tools/add_pixel_type.py --pixel float32` in a later phase.

A missing file or an unknown option exits with status 1 and a message on
stderr. `adaimg -h` prints the usage and exits 0.

## Public API

```ada
package Img is new Itklib.Images (Itklib.Pixels.UInt16, 2);
```

`Itklib.Pixel_Signature` binds an Ada type to an ITK pixel id.
`Itklib.Pixels.UInt16` is the pre-built signature. Images are non-limited
controlled types. Readers, writers, and filters are limited controlled
types built in place by `Create`.

| Package | Role |
| --- | --- |
| `Itklib.Images` | `itk::Image`. Region, spacing, origin, direction, buffer |
| `Itklib.Core.Regions` | SPARK index, size, region, iterators, pure geometry |
| `Itklib.Images.Region_Iterators` | same iterators for an image instance |
| `Itklib.Process_Object` | `Update`, `Modified`, work units, largest-region update |
| `Itklib.IO.Image_File_Reader` / `Writer` | PNG via `PNGImageIO` |
| `Itklib.Filters.Smoothing.Discrete_Gaussian` | variance, maximum error, use-image-spacing |
| `Itklib.Filters.Smoothing.Median` | radius per axis |
| `Itklib.Filters.Thresholding.Binary_Threshold` | inclusive thresholds, inside/outside |
| `Itklib.Filters.Image_Intensity.Rescale_Intensity` | output min/max |
| `Itklib.Filters.Image_Grid.Shrink` | integer shrink factors |
| `Itklib.Filters.Image_Grid.Resample` | explicit geometry, or `Set_Uniform_Scale` |
| `Itklib.Filters.Image_Grid.Flip` | axes, flip about origin |
| `Itklib.Filters.Image_Grid.Extract` | in-plane crop. Same dimension, no axis collapse |
| `Itklib.Filters.Image_Gradient.Gradient_Magnitude` | UInt16 magnitude |
| `Itklib.Filters.Image_Statistics.Statistics` | min, max, mean. No image output |

## Adding a filter

Write `tools/filters/<name>.yaml` (SimpleITK's Apache-2.0 filter
descriptions are the shape: class, members, pixel category, plus
`ada_package`, `pixel_category`, `output`, `dimensions`, and `tests`).
Then:

```
python3 tools/generate.py
```

Commit the YAML and the files it writes under `src/ada/generated/`,
`shim/generated/`, and `tests/generated/`. One YAML file produces the C
dispatch, the Ada generic (`SPARK_Mode => Off`), a `Itklib.Supported`
row, and the generated test. `alr build` does not need Python after that.
`tools/generate.py --check` fails when those files drift.

Set `generate_sources: false` only for a filter whose shim is still
hand-written. `add_pixel_type.py` prints that skip and does not extend it.

## Adding a pixel type

UInt16 × {2, 3} is the pre-built matrix in `tools/matrix.yaml`. Other ITK
scalars are listed in `tools/pixel_types.yaml` and added with:

```
python3 tools/add_pixel_type.py --pixel float32 --dims 2,3 --dry-run
python3 tools/add_pixel_type.py --pixel float32 --dims 2,3
alr build
```

`--dry-run` and `--diff` write nothing. A second run is a no-op.
`--remove` drops the pixel and regenerates. The command `try_compile`s
`itk::Image` against the ITK install before it writes files. RGB, vector,
and complex pixels are rejected. Real-only filters (Canny and anisotropic
diffusion, when those YAML files exist) are skipped for integer pixels.
The PNG writer is not generated for pixels PNG cannot store; the reason
is printed. `Itklib.Supported` and the C `itklib_filter_supported` table
come from the same matrix, and each filter checks both at compile time
and during elaboration.

`Extract` keeps the image dimension. A size of 1 does not drop an axis.
If the input region is already known, a crop outside that region raises
`Itk_Error` before ITK runs. `Disconnect_Pipeline` on an image detaches it
from the filter that produced it and drops that anchor.

`With_Buffer` overlays the ITK buffer for the callback only. x varies
fastest. A lock is held for the call. `Update` on a filter whose output is
that image raises `Itk_Error` while the view is active. Do not keep the
array after the callback returns.

`Get_Output` registers the output image and anchors the producer, so the
Ada filter variable can be finalized and the pipeline still runs.
`Set_Input` retains the input's source for the life of the consumer. One
pipeline must not be shared across Ada tasks. ITK may still use several
threads inside `Update`.

C++ exceptions stop at the shim and become `Itklib.Itk_Error`,
`Itklib.Unsupported_Instantiation`, or `Storage_Error`.

### SPARK

`SPARK_Mode` is on for `Itklib`, `Itklib.Pixel_Signature`,
`Itklib.Core.Regions`, and `Adaimg_Command`. It is off for `Itklib.Thin`,
filter bodies, and the float geometry helpers `To_Physical` / `To_Index`
(those are checked against ITK in the unit tests; unbounded `Long_Float`
overflow is not a useful proof goal). `tools/run_spark.sh` runs

```
gnatprove --mode=silver --level=2 --checks-as-errors=on
```

on `tests/spark/spark_core.gpr` and `tests/spark/spark_parser.gpr`.

### Adding a golden case

Edit `tools/golden_compare.py`. Append a `(name, adaimg options, SimpleITK
callable, tolerance)` row. Tolerance 0 is an exact `UInt16` match. Blur,
resample, and gradient magnitude use a small absolute tolerance. The script
writes one PNG, runs `adaimg`, and compares buffers.

## License

Apache-2.0, the same license as ITK. ITK itself is not vendored; build it
or point `ITK_DIR` at an existing install. SimpleITK is used only as a test
oracle, not as a runtime dependency. No SimpleITK YAML is imported yet;
that arrives with the Phase 2 generator.
