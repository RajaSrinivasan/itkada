#!/usr/bin/env bash
# Build a minimal ITK for itklib Phase 0 and install it under ITK_PREFIX.
#
# Discovery order:
#   1. An existing prefix with a matching itklib stamp (CI cache hit).
#   2. ITK_DIR / CMAKE_PREFIX_PATH, if that ITK is >= 5.4.8 and has the
#      modules in tools/itk_modules.txt.
#   3. Otherwise download the v5.4.8 release tarball and build it.
#
# Override the compiler with CC/CXX. The C++ compiler used here must be the
# same one gprbuild uses for the shim (see ITKLIB_CXX), so libstdc++ matches.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${ITK_VERSION:-5.4.8}"
PREFIX="${ITK_PREFIX:-/opt/itk-${VERSION}}"
JOBS="${ITK_BUILD_JOBS:-$(nproc)}"
TARBALL_URL="${ITK_TARBALL_URL:-https://github.com/InsightSoftwareConsortium/ITK/releases/download/v${VERSION}/InsightToolkit-${VERSION}.tar.gz}"
TARBALL_SHA256="${ITK_TARBALL_SHA256:-f4f6900f5049c3dbdf5d717798615615b21efc20bab883daf4498905c6712824}"
STAMP="${PREFIX}/share/itklib-itk-stamp"
MODULES_FILE="${ROOT}/tools/itk_modules.txt"
OWNER="${ITK_OWNER:-${SUDO_USER:-${USER:-$(id -un)}}}"

read_modules() {
  awk 'NF && $1 !~ /^#/ { print $1 }' "${MODULES_FILE}"
}

stamp_text() {
  {
    echo "version=${VERSION}"
    echo "modules=$(read_modules | tr '\n' ' ')"
  } 
}

if [[ "${ITK_FORCE_BUILD:-0}" != "1" && -f "${STAMP}" ]]; then
  if [[ "$(stamp_text)" == "$(cat "${STAMP}")" ]]; then
    echo "ITK ${VERSION} already installed at ${PREFIX} (stamp matches)."
    echo "ITK_DIR=${PREFIX}/lib/cmake/ITK-$(cut -d. -f1-2 <<<"${VERSION}")"
    exit 0
  fi
fi

if [[ "${ITK_FORCE_BUILD:-0}" != "1" ]]; then
  echo "Looking for an installed ITK >= ${VERSION} (ITK_DIR/CMAKE_PREFIX_PATH)..."
  if CC="${CC:-}" CXX="${CXX:-}" bash "${ROOT}/tools/generate_itk_paths.sh"; then
    echo "Using the discovered ITK. Set ITK_FORCE_BUILD=1 to build ${VERSION} anyway."
    exit 0
  fi
  echo "No suitable ITK found. Building ${VERSION} into ${PREFIX}."
fi

: "${CC:=$(command -v gcc)}"
: "${CXX:=$(command -v g++)}"
export CC CXX

LIBSTDCXX="$("${CXX}" -print-file-name=libstdc++.so)"
LIBSTDCXX_DIR="$(cd "$(dirname "${LIBSTDCXX}")" && pwd)"

SRC="${ITK_SOURCE_DIR:-}"
if [[ -z "${SRC}" ]]; then
  CACHE="${ITK_CACHE_DIR:-${HOME}/.cache/itklib}"
  mkdir -p "${CACHE}"
  TARBALL="${CACHE}/InsightToolkit-${VERSION}.tar.gz"
  if [[ ! -f "${TARBALL}" ]]; then
    echo "Downloading ${TARBALL_URL}"
    curl -fL --retry 3 -o "${TARBALL}.partial" "${TARBALL_URL}"
    mv "${TARBALL}.partial" "${TARBALL}"
  fi
  echo "${TARBALL_SHA256}  ${TARBALL}" | sha256sum -c -
  SRC="${CACHE}/InsightToolkit-${VERSION}"
  if [[ ! -f "${SRC}/CMakeLists.txt" ]]; then
    mkdir -p "${CACHE}"
    tar -xzf "${TARBALL}" -C "${CACHE}"
  fi
fi

if [[ ! -f "${SRC}/CMakeLists.txt" ]]; then
  echo "ITK source not found at ${SRC}" >&2
  exit 1
fi

BUILD="${ITK_BUILD_DIR:-${SRC}/../itk-${VERSION}-build}"
mkdir -p "${BUILD}"

CMAKE_ARGS=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="${PREFIX}"
  -DCMAKE_C_COMPILER="${CC}"
  -DCMAKE_CXX_COMPILER="${CXX}"
  -DCMAKE_CXX_STANDARD=17
  -DBUILD_SHARED_LIBS=ON
  -DBUILD_TESTING=OFF
  -DBUILD_EXAMPLES=OFF
  -DITK_BUILD_DOCUMENTATION=OFF
  -DITK_BUILD_DEFAULT_MODULES=OFF
  -DITK_USE_SYSTEM_PNG=ON
  -DITK_USE_SYSTEM_ZLIB=ON
  -DITK_FORBID_DOWNLOADS=ON
  -DCMAKE_INSTALL_RPATH="${PREFIX}/lib;${LIBSTDCXX_DIR}"
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
)

while IFS= read -r module; do
  CMAKE_ARGS+=("-DModule_${module}=ON")
done < <(read_modules)

echo "Configuring ITK ${VERSION} with ${CXX} (-j ${JOBS})"
echo "Modules: $(read_modules | tr '\n' ' ')"
START="$(date +%s)"
cmake -S "${SRC}" -B "${BUILD}" "${CMAKE_ARGS[@]}"
cmake --build "${BUILD}" --parallel "${JOBS}"
BUILD_DONE="$(date +%s)"

install_tree() {
  cmake --install "${BUILD}"
  mkdir -p "$(dirname "${STAMP}")"
  stamp_text > "${STAMP}"
  # The Actions cache step runs as the unprivileged user.
  if [[ "$(id -u)" -eq 0 ]]; then
    chown -R "${OWNER}:${OWNER}" "${PREFIX}" || true
  fi
}

if [[ -w "$(dirname "${PREFIX}")" || -w "${PREFIX}" ]]; then
  install_tree
else
  sudo ITK_OWNER="${OWNER}" cmake --install "${BUILD}"
  sudo mkdir -p "$(dirname "${STAMP}")"
  stamp_text | sudo tee "${STAMP}" >/dev/null
  sudo chown -R "${OWNER}:${OWNER}" "${PREFIX}"
fi

END="$(date +%s)"
echo "ITK ${VERSION} installed to ${PREFIX}"
echo "configure+build $((BUILD_DONE - START))s, total $((END - START))s"
ITK_MAJOR_MINOR="$(cut -d. -f1-2 <<<"${VERSION}")"
echo "ITK_DIR=${PREFIX}/lib/cmake/ITK-${ITK_MAJOR_MINOR}"
