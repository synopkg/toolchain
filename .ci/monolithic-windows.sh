#!/usr/bin/env bash

set -ex
set -o pipefail

MONOREPO_ROOT="${MONOREPO_ROOT:="$(git rev-parse --show-toplevel)"}"
BUILD_DIR="${BUILD_DIR:=${MONOREPO_ROOT}/build}"

rm -rf ${BUILD_DIR}

if [[ -n "${CLEAR_CACHE:-}" ]]; then
  echo "clearing sccache"
  rm -rf "$SCCACHE_DIR"
fi

sccache --zero-stats
function show-stats {
  mkdir -p artifacts
  sccache --show-stats >> artifacts/sccache_stats.txt
}
trap show-stats EXIT

projects="${1}"
targets="${2}"

echo "--- cmake"
pip install -q -r ${MONOREPO_ROOT}/mlir/python/requirements.txt
cmake -S ${MONOREPO_ROOT}/toolchain -B ${BUILD_DIR} \
      -D TOOLCHAIN_ENABLE_PROJECTS="${projects}" \
      -G Ninja \
      -D CMAKE_BUILD_TYPE=Release \
      -D TOOLCHAIN_ENABLE_ASSERTIONS=ON \
      -D TOOLCHAIN_BUILD_EXAMPLES=ON \
      -D COMPILER_RT_BUILD_LIBFUZZER=OFF \
      -D TOOLCHAIN_LIT_ARGS="-v --xunit-xml-output ${BUILD_DIR}/test-results.xml" \
      -D COMPILER_RT_BUILD_ORC=OFF \
      -D CMAKE_C_COMPILER_LAUNCHER=sccache \
      -D CMAKE_CXX_COMPILER_LAUNCHER=sccache

echo "--- ninja"
# Targets are not escaped as they are passed as separate arguments.
ninja -C "${BUILD_DIR}" ${targets}
