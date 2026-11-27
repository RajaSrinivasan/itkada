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
  # Outside the crate. alr refuses to deploy a release inside another one,
  # and --dirname only prints the folder name.
  CACHE="${HOME}/.cache/itklib-gnatprove"
  mkdir -p "${CACHE}"
  NAME="$(alr -n get gnatprove=16.1.0 --dirname)"
  if [[ ! -x "${CACHE}/${NAME}/bin/gnatprove" ]]; then
    (cd "${CACHE}" && alr -n get gnatprove=16.1.0)
  fi
  export PATH="${CACHE}/${NAME}/bin:${PATH}"
fi

gnatprove -P tests/spark/spark_core.gpr --mode=silver --level=2 \
  --checks-as-errors=on -j"$(nproc)"
gnatprove -P tests/spark/spark_parser.gpr --mode=silver --level=2 \
  --checks-as-errors=on -j"$(nproc)"
echo "gnatprove silver passed"
