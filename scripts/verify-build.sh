#!/usr/bin/env bash
set -euo pipefail

# Recreates the native Cordova build pipeline that OutSystems' Mobile Apps Build Service
# runs under the hood (cordova platform add -> cordova plugin add -> cordova build),
# using a disposable scratch app, so plugin.xml / Gradle / CocoaPods / compile errors
# surface in the time gradle or xcodebuild takes instead of a full OutSystems mobile
# build (5-10+ minutes). Used by both .github/workflows/build.yml and local runs.
#
# Usage: scripts/verify-build.sh <android|ios|both> [--keep]
#   --keep   don't delete the scratch app afterwards (useful for inspecting build output)
#
# Requirements:
#   android: JDK 17+, Android SDK (ANDROID_HOME/ANDROID_SDK_ROOT set), Node.js
#   ios:     macOS, Xcode, CocoaPods, Node.js (not runnable on Windows/Linux)

PLATFORM="${1:-}"
if [[ "$PLATFORM" != "android" && "$PLATFORM" != "ios" && "$PLATFORM" != "both" ]]; then
  echo "Usage: $0 <android|ios|both> [--keep]" >&2
  exit 1
fi
KEEP="${2:-}"

# Pinned rather than left to "npx cordova" resolving whatever happens to be cached -
# on a machine with an old cordova already cached, unpinned npx silently reuses it
# instead of fetching current. Bump deliberately, not by accident.
CORDOVA_VERSION="13"

cordova() {
  npx --yes "cordova@${CORDOVA_VERSION}" "$@"
}

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d)"
APP_DIR="$WORKDIR/testapp"

cleanup() {
  if [[ "$KEEP" == "--keep" ]]; then
    echo "Scratch app kept at: $APP_DIR"
  else
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

echo "== Creating scratch Cordova app (cordova@${CORDOVA_VERSION}) in $APP_DIR =="
cordova create "$APP_DIR" com.quatronic.enodeverify EnodeVerify >/dev/null

add_plugin() {
  echo "== Adding EnodePlugin from $PLUGIN_DIR =="
  (cd "$APP_DIR" && cordova plugin add "$PLUGIN_DIR")
}

build_android() {
  echo "== Adding android platform =="
  (cd "$APP_DIR" && cordova platform add android)
  add_plugin
  echo "== Building android (debug) =="
  (cd "$APP_DIR" && cordova build android)
  echo "== Android build OK =="
}

build_ios() {
  echo "== Adding ios platform =="
  (cd "$APP_DIR" && cordova platform add ios)
  add_plugin
  echo "== Building ios (simulator, unsigned) =="
  (cd "$APP_DIR" && cordova build ios --emulator)
  echo "== iOS build OK =="
}

case "$PLATFORM" in
  android) build_android ;;
  ios) build_ios ;;
  both) build_android; build_ios ;;
esac
