#!/usr/bin/env bash
set -euo pipefail

# Build microG APKs from repo-synced sources WITHOUT writing into the (potentially read-only)
# source tree. We copy the upstream sources into $TOP/out/... and run Gradle there.
#
# Usage:
#   build_microg.sh <gmscore|companion> <out.apk>
#
# Notes:
# - Intended to be executed as a Soong genrule tool (host).
# - Avoids creating/using <SRC>/build/** under vendor/** which can be read-only in AOSP builds.
# - Requires: bash, gradle wrapper in source, and a working JDK in the build environment.

MODE="${1:-}"
OUT="${2:-}"
if [[ -z "${MODE}" || -z "${OUT}" ]]; then
  echo "Usage: $0 <gmscore|companion> <out.apk>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/upstream/GmsCore"

if [[ ! -d "${SRC}" ]]; then
  echo "[microg] Source tree not found at: ${SRC}" >&2
  exit 1
fi

# Find Android TOP. Prefer $TOP (Soong sets it), otherwise walk up from script dir.
find_android_top() {
  if [[ -n "${TOP:-}" && -f "${TOP}/build/envsetup.sh" ]]; then
    echo "${TOP}"
    return 0
  fi
  local d="${SCRIPT_DIR}"
  while [[ "${d}" != "/" ]]; do
    if [[ -f "${d}/build/envsetup.sh" ]]; then
      echo "${d}"
      return 0
    fi
    d="$(dirname "${d}")"
  done
  return 1
}

ANDROID_TOP="$(find_android_top)" || {
  echo "[microg] Could not locate Android TOP (build/envsetup.sh). Set TOP or run inside the tree." >&2
  exit 1
}

mkdir -p "$(dirname "${OUT}")"

WORK_BASE="${ANDROID_TOP}/out/maleicacid-microg"
WORK_SRC="${WORK_BASE}/work/${MODE}/GmsCore"
GRADLE_HOME="${WORK_BASE}/gradle-home"

rm -rf "${WORK_BASE}/work/${MODE}"
mkdir -p "$(dirname "${WORK_SRC}")" "${GRADLE_HOME}"

echo "[microg] Copying sources to: ${WORK_SRC}"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "${SRC}/" "${WORK_SRC}/"
else
  mkdir -p "${WORK_SRC}"
  cp -a "${SRC}/." "${WORK_SRC}/"
fi

export GRADLE_USER_HOME="${GRADLE_HOME}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_TOP}/prebuilts/sdk}"  # best-effort

cd "${WORK_SRC}"

APK=""
case "${MODE}" in
  gmscore)
    ./gradlew --no-daemon :play-services-core:assembleRelease
    APK="$(find play-services-core/build/outputs/apk -type f -iname '*release-unsigned*.apk' | head -n1 || true)"
    if [[ -z "${APK}" ]]; then
      APK="$(find play-services-core/build/outputs/apk -type f -iname '*release*.apk' | head -n1 || true)"
    fi
    ;;
  companion)
    ./gradlew --no-daemon :vending-app:assembleRelease
    APK="$(find vending-app/build/outputs/apk -type f -iname '*release-unsigned*.apk' | head -n1 || true)"
    if [[ -z "${APK}" ]]; then
      APK="$(find vending-app/build/outputs/apk -type f -iname '*release*.apk' | head -n1 || true)"
    fi
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac

if [[ -z "${APK}" || ! -f "${APK}" ]]; then
  echo "[microg] Release APK not found after build (${MODE})." >&2
  echo "[microg] Searched under: ${WORK_SRC}" >&2
  exit 1
fi

echo "[microg] Built APK: ${APK}"
cp -f "${APK}" "${OUT}"
echo "[microg] Copied to: ${OUT}"
