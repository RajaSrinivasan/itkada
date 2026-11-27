#!/usr/bin/env bash
# Silver proof of the hand-written SPARK units: Itklib, Pixel_Signature,
# region/index/iterator arithmetic, and the adaimg argument parser.
# Float geometry helpers are checked against ITK in the Ada tests; their
# bodies are SPARK_Mode Off because unbounded Long_Float arithmetic does
# not have a useful overflow bound.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v gnatprove >/dev/null 2>&1; then
  DEST="${ROOT}/.cache/gnatprove"
  if [[ ! -x "${DEST}/bin/gnatprove" ]]; then
    mkdir -p "${ROOT}/.cache"
    alr -n get gnatprove --dirname "${DEST}"
  fi
  export PATH="${DEST}/bin:${PATH}"
fi

gnatprove -P tests/spark/spark_core.gpr --mode=silver --level=2 \
  --checks-as-errors=on -j"$(nproc)"
gnatprove -P tests/spark/spark_parser.gpr --mode=silver --level=2 \
  --checks-as-errors=on -j"$(nproc)"
echo "gnatprove silver passed"
