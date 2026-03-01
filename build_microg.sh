#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
OUT="${2:-}"
if [[ -z "${MODE}" || -z "${OUT}" ]]; then
  echo "Usage: $0 <gmscore|companion> <out.apk>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/upstream/GmsCore"

if [[ ! -d "${SRC}" ]]; then
  echo "[microg] Source tree not found at ${SRC}" >&2
  exit 1
fi

cd "${SRC}"

case "${MODE}" in
  gmscore)
    ./gradlew --no-daemon :play-services-core:assembleRelease
    APK="$(find play-services-core/build/outputs/apk -type f -name *release*.apk | head -n1 || true)"
    ;;
  companion)
    ./gradlew --no-daemon :vending-app:assembleRelease
    APK="$(find vending-app/build/outputs/apk -type f -name *release*.apk | head -n1 || true)"
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    exit 1
    ;;
 esac

if [[ -z "${APK}" || ! -f "${APK}" ]]; then
  echo "[microg] Release APK not found after build (${MODE})." >&2
  exit 1
fi

cp -f "${APK}" "${OUT}"
