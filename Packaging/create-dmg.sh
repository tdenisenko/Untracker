#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "Usage: create-dmg.sh <app-name> <app-bundle> <output-dmg> <build-dir> <background-png>" >&2
    exit 64
fi

APP_NAME="$1"
APP_BUNDLE="$2"
OUTPUT_DMG="$3"
BUILD_DIR="$4"
BACKGROUND_PNG="$5"

STAGING_DIR="${BUILD_DIR}/dmg-staging"
RW_DMG="${BUILD_DIR}/${APP_NAME}-rw.dmg"
VOLUME_NAME="${APP_NAME}"
VOLUME_PATH="/Volumes/${VOLUME_NAME}"
MOUNTED=0

cleanup() {
    if [[ "${MOUNTED}" -eq 1 ]]; then
        hdiutil detach "${VOLUME_PATH}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

rm -rf "${STAGING_DIR}" "${RW_DMG}" "${OUTPUT_DMG}"
mkdir -p "${STAGING_DIR}/.background"

cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"
cp "${BACKGROUND_PNG}" "${STAGING_DIR}/.background/background.png"

hdiutil detach "${VOLUME_PATH}" >/dev/null 2>&1 || true
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "${RW_DMG}" >/dev/null

hdiutil attach "${RW_DMG}" \
    -readwrite \
    -noverify \
    -noautoopen >/dev/null
MOUNTED=1

osascript Packaging/layout-dmg.applescript "${VOLUME_NAME}" "${APP_NAME}"
sync
sleep 1

hdiutil detach "${VOLUME_PATH}" >/dev/null
MOUNTED=0

hdiutil convert "${RW_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${OUTPUT_DMG}" \
    -ov >/dev/null

rm -rf "${STAGING_DIR}" "${RW_DMG}"

hdiutil detach "${VOLUME_PATH}" >/dev/null 2>&1 || true
open "${OUTPUT_DMG}"
