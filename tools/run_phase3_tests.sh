#!/usr/bin/env bash
# Phase 3 checks: the phase 2 suite, medical-filter unit tests, adaimg
# smokes, and the SimpleITK goldens those options add.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

bash "${ROOT}/tools/run_phase2_tests.sh"

alr exec -- gprbuild -p -P tests/itklib_tests.gpr
ITK_LIB="$(sed -n 's/.*ITK_Lib_Dir := "\([^"]*\)".*/\1/p' itk_paths.gpr | head -1)"
LIBSTD="$(dirname "$(alr exec -- g++ -print-file-name=libstdc++.so)")"
export LD_LIBRARY_PATH="${ROOT}/lib:${ITK_LIB}:${LIBSTD}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
./bin/phase3_tests

SMOKE="${ROOT}/obj/phase3-smoke"
mkdir -p "${SMOKE}"
IN="${ROOT}/obj/phase0-uint16.png"
ADAIMG="${ROOT}/bin/adaimg"
"${ADAIMG}" "${IN}" -erode 1 "${SMOKE}/erode.png"
"${ADAIMG}" "${IN}" -dilate 1 "${SMOKE}/dilate.png"
"${ADAIMG}" "${IN}" -otsu "${SMOKE}/otsu.png"
"${ADAIMG}" "${IN}" -grow 1,1,0:40000 "${SMOKE}/grow.png"
if "${ADAIMG}" "${IN}" -canny 1 "${SMOKE}/canny.png"; then
  echo "canny should fail until float32 is generated" >&2
  exit 1
fi

echo "phase 3 checks passed"
