#!/usr/bin/env bash
# Phase 1 checks: Ada unit tests, adaimg smoke, SPARK silver, SimpleITK goldens.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

bash "${ROOT}/tools/run_phase0_tests.sh"

alr exec -- gprbuild -p -P tests/itklib_tests.gpr
ITK_LIB="$(sed -n 's/.*ITK_Lib_Dir := "\([^"]*\)".*/\1/p' itk_paths.gpr | head -1)"
LIBSTD="$(dirname "$(alr exec -- g++ -print-file-name=libstdc++.so)")"
export LD_LIBRARY_PATH="${ROOT}/lib:${ITK_LIB}:${LIBSTD}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

./bin/phase1_tests

SMOKE="${ROOT}/obj/phase1-smoke"
mkdir -p "${SMOKE}"
IN="${ROOT}/obj/phase0-uint16.png"
ADAIMG="${ROOT}/bin/adaimg"
"${ADAIMG}" identify "${IN}"
"${ADAIMG}" "${IN}" -blur 1 "${SMOKE}/blur.png"
"${ADAIMG}" "${IN}" -median 1 "${SMOKE}/median.png"
"${ADAIMG}" "${IN}" -threshold 10:40000 "${SMOKE}/threshold.png"
"${ADAIMG}" "${IN}" -rescale 0:1000 "${SMOKE}/rescale.png"
"${ADAIMG}" "${IN}" -resize 50% "${SMOKE}/shrink.png"
"${ADAIMG}" "${IN}" -resize 150% "${SMOKE}/resample.png"
"${ADAIMG}" "${IN}" -flip x "${SMOKE}/flip.png"
"${ADAIMG}" "${IN}" -crop 4x2+1+0 "${SMOKE}/crop.png"
"${ADAIMG}" "${IN}" -edge "${SMOKE}/edge.png"
"${ADAIMG}" "${IN}" -blur 1 -threshold 10:50000 -resize 50% "${SMOKE}/chain.png"
if "${ADAIMG}" "${ROOT}/obj/no-such.png" "${SMOKE}/nope.png"; then
  echo "missing file should fail" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1 && python3 -c "import SimpleITK" 2>/dev/null; then
  python3 "${ROOT}/tools/golden_compare.py" --adaimg "${ADAIMG}"
else
  echo "SimpleITK is not installed; skipping golden comparison" >&2
fi

if [[ "${ITKLIB_SKIP_SPARK:-0}" != "1" ]]; then
  bash "${ROOT}/tools/run_spark.sh"
fi

echo "phase 1 checks passed"
