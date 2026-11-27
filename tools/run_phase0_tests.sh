#!/usr/bin/env bash
# Build itklib (if needed) and run the Phase 0 checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

alr build
alr exec -- gprbuild -p -P tests/itklib_tests.gpr
alr exec -- gprbuild -p -P examples/adaimg/adaimg.gpr

ITK_LIB="$(sed -n 's/.*ITK_Lib_Dir := "\([^"]*\)".*/\1/p' itk_paths.gpr | head -1)"
LIBSTD="$(dirname "$(alr exec -- g++ -print-file-name=libstdc++.so)")"
export LD_LIBRARY_PATH="${ROOT}/lib:${ITK_LIB}:${LIBSTD}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

./bin/itklib_tests
./bin/adaimg obj/phase0-uint16.png obj/phase0-uint16-copy.png
./bin/itklib_tests --compare obj/phase0-uint16.png obj/phase0-uint16-copy.png

LOG="$(mktemp)"
set +e
alr exec -- gprbuild -p -P tests/compile_fail/bad_pixel.gpr >"${LOG}" 2>&1
STATUS=$?
set -e
if [[ "${STATUS}" -eq 0 ]]; then
  echo "expected Pixel_Signature size mismatch to fail compilation" >&2
  exit 1
fi
grep -q "Pixel size does not match Kind" "${LOG}"
echo "phase 0 checks passed"
