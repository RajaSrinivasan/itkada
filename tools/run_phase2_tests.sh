#!/usr/bin/env bash
# Phase 2 checks: generated sources match the YAML, the Phase 1 suite still
# passes, an unsupported filter instantiation is rejected at compile time,
# and add_pixel_type.py --pixel float32 builds and runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

python3 "${ROOT}/tools/test_codegen.py"
python3 "${ROOT}/tools/generate.py" --check

bash "${ROOT}/tools/run_phase1_tests.sh"

LOG="$(mktemp)"
set +e
alr exec -- gprbuild -p -P tests/compile_fail/unsupported_filter.gpr >"${LOG}" 2>&1
STATUS=$?
set -e
if [[ "${STATUS}" -eq 0 ]]; then
  echo "expected an unbuilt DiscreteGaussian instantiation to fail compilation" >&2
  exit 1
fi
grep -q "is not built for this pixel kind and dimension" "${LOG}"

if [[ "${ITKLIB_SKIP_FLOAT32:-0}" != "1" ]]; then
  python3 "${ROOT}/tools/add_pixel_type.py" --pixel float32 --dims 2,3
  alr build
  alr exec -- gprbuild -p -P tests/generated_tests.gpr
  ITK_LIB="$(sed -n 's/.*ITK_Lib_Dir := "\([^"]*\)".*/\1/p' itk_paths.gpr | head -1)"
  LIBSTD="$(dirname "$(alr exec -- g++ -print-file-name=libstdc++.so)")"
  export LD_LIBRARY_PATH="${ROOT}/lib:${ITK_LIB}:${LIBSTD}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  ./bin/generated_tests
  python3 "${ROOT}/tools/add_pixel_type.py" --pixel float32 --remove
  alr build
fi

echo "phase 2 checks passed"
