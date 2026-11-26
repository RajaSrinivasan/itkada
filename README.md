# itklib

Ada binding for the [Insight Toolkit](https://itk.org/). The Alire crate,
GPR project, and shared library are `itklib`. The top-level Ada package is
`Itklib`. C shim symbols use the `itklib_` prefix. This repository stays
`itkada`.

Phase 0 is a hand-written spike: 2D and 3D `uint16` images, PNG read/write,
and one filter (`DiscreteGaussianImageFilter`) on the lazy ITK pipeline.
Later phases add the rest of the `adaimg` operations, code generation, and
medical formats. Tracked by GitHub issues #1 and #3–#10.

## Layout

```
alire.toml              Alire crate manifest
itklib.gpr              Ada + C++ library project
src/ada/                Itklib.* sources
shim/                   extern "C" shim (itklib.h and the .cxx files)
tools/build_itk.sh      minimal ITK 5.4.8 build
tools/itk_modules.txt   modules that build enables
tools/itk_paths/        CMake probe that writes itk_paths.gpr
tools/run_phase0_tests.sh
examples/adaimg/        adaimg in.png out.png
tests/                  Phase 0 driver and a compile-fail check
```

`itk_paths.gpr` and `config/` are generated. They are not committed.

## Build ITK

The shim needs ITK **5.4.8 or newer**, discovered through `ITK_DIR` or
`CMAKE_PREFIX_PATH`. Ubuntu packages are older than that, so the default
step builds the `v5.4.8` release with only the modules in
`tools/itk_modules.txt` (Common, PNG I/O, smoothing, and the modules those
pull in). Install prefix defaults to `/opt/itk-5.4.8`.

```
alr toolchain --select gnat_native gprbuild
alr exec -- bash tools/build_itk.sh
```

Use the Alire `g++` for that build. The shim is compiled with the same
compiler, and the generated GPR records an rpath to its `libstdc++`.

A matching stamp under the prefix makes a later run return immediately.
`ITK_FORCE_BUILD=1` rebuilds. `ITK_PREFIX` and `ITK_BUILD_JOBS` override
the prefix and the Ninja job count.

On a 4-core GNAT 16 machine the Phase 0 configure-and-build took about
**5 minutes 13 seconds**. A stamp hit returned in under a second.

### Version bump policy

Crate versions are independent of ITK. The floor is 5.4.8
(`find_package(ITK 5.4.8)`). A later scheduled job (issues #28 and #32)
should compare the newest non-prerelease ITK git tag with the distro
package and use whichever is newer. If the distro package is at least the
tag, CI can skip the source build. Betas such as 6.0b02 stay on a
non-blocking job. This Phase 0 workflow only builds and caches 5.4.8.

## Build and test itklib

```
export ITK_DIR=/opt/itk-5.4.8/lib/cmake/ITK-5.4   # if it is not the default
alr build
bash tools/run_phase0_tests.sh
```

`alr build` runs `tools/generate_itk_paths.sh` first. That probe calls
`find_package` and writes include paths, compile flags, and the link line
into `itk_paths.gpr`.

The test driver checks:

- 2D and 3D `UInt16` images, regions, and a zero-copy buffer
- controlled-handle `Register` / `UnRegister` (copy bumps the ITK count;
  the last finalize drops the live-object counter)
- spacing, origin, and direction
- a 16-bit PNG round trip, including `adaimg in.png out.png`
- `Itk_Error` on a missing file, and `Unsupported_Instantiation` for a
  pixel or dimension that was not built
- a compile-time rejection when a pixel's size does not match its kind
- `DiscreteGaussianImageFilter` in 2D and 3D, including a lazy
  reader → gaussian → writer pipeline

`adaimg` is only the two-argument copy. It calls the Ada packages, not
ITK from the example itself.

## Public types

```ada
package Img is new Itklib.Images (Itklib.Pixels.UInt16, 2);
```

`Itklib.Pixel_Signature` binds an Ada type to an ITK pixel id.
`Itklib.Pixels.UInt16` is the one pre-built signature. Images are
non-limited controlled types. Readers, writers, and filters are limited
controlled types built in place by `Create`.

`SPARK_Mode` is on for `Itklib` and `Itklib.Pixel_Signature`. It is off
for `Itklib.Thin` and every package that crosses into C or ITK.

C++ exceptions are caught at the `extern "C"` boundary and returned as a
status code plus a message. Ada raises `Itklib.Itk_Error`,
`Itklib.Unsupported_Instantiation`, or `Storage_Error`.

One ITK pipeline must not be shared across Ada tasks without a protected
wrapper. ITK may still use several threads inside `Update`.

## License

Apache-2.0, the same license as ITK. ITK itself is not vendored; build it
or point `ITK_DIR` at an existing install.
