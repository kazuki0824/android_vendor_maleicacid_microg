#!/usr/bin/env bash
set -euo pipefail

# Build microG APKs from repo-synced sources, compatible with Soong genrule sandboxing (sbox).
#
# In sbox, the tool is copied under tools/out/bin, while declared srcs are available under the
# sandbox working directory. This script therefore must not assume upstream sources live next to
# the tool binary.
#
# Recommended usage from Android.bp genrule cmd:
#   build_microg.sh gmscore   --src upstream/GmsCore --workdir "$(genDir)/work" --out "$(out)"
#   build_microg.sh companion --src upstream/GmsCore --workdir "$(genDir)/work" --out "$(out)"
#
# Back-compat:
#   build_microg.sh <gmscore|companion> <out.apk>

MODE="${1:-}"
shift || true
if [[ -z "${MODE}" ]]; then
  echo "Usage: $0 <gmscore|companion> [--src <dir>] [--workdir <dir>] [--out <apk>]" >&2
  exit 1
fi

SRC_DIR=""
WORKDIR=""
OUT=""

# Back-compat: MODE OUT
if [[ $# -ge 1 && "${1:-}" != --* ]]; then
  OUT="$1"
  shift || true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC_DIR="$2"; shift 2;;
    --workdir) WORKDIR="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ -z "${OUT}" ]]; then
  echo "[microg] Missing output path. Use: --out <apk>" >&2
  exit 1
fi

# Prefer explicit --src, otherwise try common locations.
if [[ -z "${SRC_DIR}" ]]; then
  if [[ -d "upstream/GmsCore" ]]; then
    SRC_DIR="upstream/GmsCore"
  else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "${SCRIPT_DIR}/upstream/GmsCore" ]]; then
      SRC_DIR="${SCRIPT_DIR}/upstream/GmsCore"
    fi
  fi
fi

if [[ -z "${SRC_DIR}" || ! -d "${SRC_DIR}" ]]; then
  echo "[microg] Source tree not found at: ${SRC_DIR:-<unset>}" >&2
  echo "[microg] Hint: In Android.bp genrule, add srcs with upstream/GmsCore/** and pass --src upstream/GmsCore" >&2
  exit 1
fi

if [[ -z "${WORKDIR}" ]]; then
  WORKDIR="$(mktemp -d)"
fi
mkdir -p "${WORKDIR}"

WORK_SRC="${WORKDIR}/GmsCore"
GRADLE_HOME="${WORKDIR}/gradle-home"
rm -rf "${WORK_SRC}"
mkdir -p "${WORK_SRC}" "${GRADLE_HOME}"

echo "[microg] Copying sources: ${SRC_DIR} -> ${WORK_SRC}"
cp -a "${SRC_DIR}/." "${WORK_SRC}/"

export GRADLE_USER_HOME="${GRADLE_HOME}"

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
    echo "[microg] Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac

if [[ -z "${APK}" || ! -f "${APK}" ]]; then
  echo "[microg] Release APK not found after build (${MODE})." >&2
  exit 1
fi

mkdir -p "$(dirname "${OUT}")"
cp -f "${APK}" "${OUT}"
echo "[microg] Copied: ${OUT}"
