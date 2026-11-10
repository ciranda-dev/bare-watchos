#!/usr/bin/env bash
# Builds the app from the upstream repositories, each fetched into vendor/ at the commit pinned below with its
# patches/<repository> applied: Bare Kit with BARE_ENGINE=libqjsng, watchOS prebuilds of the addons the worklet loads,
# and the app.
#
#   ./build.sh            the steps up to app, in order
#   ./build.sh <step>...  only the named steps
#
# Steps:
#   sources   the repositories below in vendor/, at their pins, with their patches applied
#   deps      npm dependencies, with the patched JavaScript packages over them, here and in the repositories the
#             build uses
#   barekit   bare-kit-swift's framework for the three targets, then vendor/bare-kit-swift/BareKit.xcframework
#   addons    watchOS prebuilds of the addons the worklet loads, added to node_modules
#   app       the app for the watchOS simulator and, unsigned, for watchOS devices
#   run       the app in a watchOS simulator, a screenshot of it in build/simulator.png and its console in
#             build/console.log
#
# Needs Xcode (watchOS and watchOS Simulator SDKs), git, node, npm and xcodegen. npm always runs with
# --ignore-scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$ROOT/vendor"

# name url commit
REPOS=(
  "cmake-toolchains https://github.com/holepunchto/cmake-toolchains 612479a0b9a9b86b5d76cc394d1d5e887196d9f2"
  "cmake-bare https://github.com/holepunchto/cmake-bare ded6b48247fb4c8d4c4d1689ca9fdd71785eebd3"
  "cmake-napi https://github.com/holepunchto/cmake-napi 31575256bd4738bf4688396a8aa06615daa3d3c3"
  "bare-addon-resolve https://github.com/holepunchto/bare-addon-resolve 4aecd3c7f9deab9b3577269b2720f5854a6e4181"
  "bare-link https://github.com/holepunchto/bare-link 51bf1af86674dfe4ee47f054e10c4fe3db841066"
  "bare-pack https://github.com/holepunchto/bare-pack 41233ec88be9824cd2454183a9a4bf2eb8d5a0e1"
  "libuv https://github.com/libuv/libuv 840404ce8ba7cc0204be52389a6cfff9f2c90fb6"   # v1.53.0, what Bare fetches
  "bare https://github.com/holepunchto/bare c0b6b3b91c9ab41cb64804f9e6383ad6f2bc0667" # v1.36.2, what bare-kit fetches
  "libjs https://github.com/holepunchto/libjs b03f45213c2c67b0651a3a7d6b07862a0760289a"
  "libintrusive https://github.com/holepunchto/libintrusive 01eae7f87e0f9613de35572f8cf53e9282e409f4"
  "bare-kit https://github.com/holepunchto/bare-kit 174ecf83f81682b6ee530a37cec8cff6192dded0"
  "bare-kit-swift https://github.com/holepunchto/bare-kit-swift 7be67fc2506747cca92975d1d25fcffe6451fe3b"
  "sodium-native https://github.com/holepunchto/sodium-native f5d984ea4a8e237c8030ec99736bbbb7041c6efc"
  "bare-foundation https://github.com/holepunchto/bare-foundation 147774bdc4e39815be46ce40b336b2d59a5f38e8"
  "bare-switch-core https://github.com/holepunchto/bare-switch-core 3668cece2788132434135df921f006d705e2cfca"
  "hyperswarm-dht-relay https://github.com/holepunchto/hyperswarm-dht-relay 5036c4b09930228efe539a7787826fe379adb373"
)

LIBQJSNG=8f1063161a1d66ea870d1590bf460b7916f21da8 # holepunchto/libqjsng, QuickJS-NG 0.18.0

TARGETS=("watchos-arm64_32:arm64_32:" "watchos-arm64:arm64:" "watchos-arm64-simulator:arm64:--simulator")

SIMULATOR="Apple Watch Series 11 (46mm)"

log() { printf '\n== %s\n' "$*"; }

bare_make() { node "$ROOT/node_modules/bare-make/bin.js" "$@"; }

npm_ci() { (cd "$1" && npm ci --ignore-scripts --no-audit --no-fund --loglevel=error); }

npm_install() { (cd "$1" && npm install --ignore-scripts --no-audit --no-fund --loglevel=error); }

npm_overlay() { # dir repository...: installs copies of the patched repositories over what npm resolved
  local dir="$1" repos=()
  shift
  for r in "$@"; do repos+=("$VENDOR/$r"); done
  (cd "$dir" && npm install --no-save --install-links --ignore-scripts --no-audit --no-fund --loglevel=error \
    "${repos[@]}")
}

prebuild() { # dir defines...: the three targets, generated, built and installed into <dir>/prebuilds
  local src="$1" t name arch flags
  shift
  for t in "${TARGETS[@]}"; do
    IFS=: read -r name arch flags <<< "$t"
    rm -rf "$src/prebuilds/$name"
    # shellcheck disable=SC2086
    bare_make generate --source "$src" --build "$src/build/$name" --no-cache --platform watchos --arch "$arch" \
      $flags "$@"
    bare_make build --build "$src/build/$name"
    bare_make install --build "$src/build/$name" --prefix "$src/prebuilds"
  done
}

step_sources() {
  log "sources"
  local r name url commit dir patch

  for r in "${REPOS[@]}"; do
    read -r name url commit <<< "$r"
    dir="$VENDOR/$name"

    if [ ! -d "$dir/.git" ]; then
      git init --quiet "$dir"
      git -C "$dir" remote add origin "$url"
    fi

    git -C "$dir" fetch --quiet --depth 1 origin "$commit"
    git -C "$dir" reset --quiet --hard "$commit"
    git -C "$dir" clean --quiet -fd

    for patch in "$ROOT/patches/$name"/*.patch; do
      if [ -f "$patch" ]; then git -C "$dir" apply "$patch"; fi
    done
  done
}

step_deps() {
  log "deps"
  npm_install "$ROOT"
  npm_overlay "$ROOT" cmake-toolchains bare-addon-resolve bare-link bare-pack bare-foundation bare-switch-core \
    hyperswarm-dht-relay

  (cd "$VENDOR/libjs" && npm install --no-save --ignore-scripts --allow-git=none --no-audit --no-fund --loglevel=error)
  npm_ci "$VENDOR/bare"
  npm_overlay "$VENDOR/bare" cmake-bare cmake-napi bare-addon-resolve
  npm_ci "$VENDOR/bare-kit"
  npm_overlay "$VENDOR/bare-kit" cmake-bare cmake-napi bare-addon-resolve
  npm_install "$VENDOR/bare-kit-swift"
  npm_overlay "$VENDOR/bare-kit-swift" cmake-bare
}

step_barekit() {
  log "barekit"
  local src="$VENDOR/bare-kit-swift"

  rm -rf "$src/prebuilds"
  prebuild "$src" \
    -D "FETCHCONTENT_SOURCE_DIR_GITHUB+HOLEPUNCHTO+BARE-KIT=$VENDOR/bare-kit" \
    -D "FETCHCONTENT_SOURCE_DIR_GITHUB+HOLEPUNCHTO+BARE=$VENDOR/bare" \
    -D "FETCHCONTENT_SOURCE_DIR_GITHUB+LIBUV+LIBUV=$VENDOR/libuv" \
    -D "FETCHCONTENT_SOURCE_DIR_GITHUB+HOLEPUNCHTO+LIBJS=$VENDOR/libjs" \
    -D "FETCHCONTENT_SOURCE_DIR_GITHUB+HOLEPUNCHTO+LIBINTRUSIVE=$VENDOR/libintrusive" \
    -D "BARE_ENGINE=github:holepunchto/libqjsng#$LIBQJSNG"

  # holepunchto/actions/create-xcframework, as patches/actions groups the targets.
  local prefix="$src/prebuilds" output="$src/BareKit.xcframework" temp="$src/build/xcframework" args=()
  rm -rf "$output" "$temp"
  for group in $(ls "$prefix" | sed -E 's/-(arm64_32|arm64|x64)//' | sort -u); do
    local framework="$temp/$group/BareKit.framework" binaries=()
    for target in $(ls "$prefix"); do
      if [ "$(echo "$target" | sed -E 's/-(arm64_32|arm64|x64)//')" = "$group" ]; then
        if [ ! -d "$framework" ]; then
          mkdir -p "$(dirname "$framework")"
          cp -R "$prefix/$target/BareKit.framework" "$framework"
        fi
        binaries+=("$prefix/$target/BareKit.framework/BareKit")
      fi
    done
    lipo -create -output "$framework/BareKit" "${binaries[@]}"
    args+=(-framework "$framework")
  done
  xcodebuild -create-xcframework -output "$output" "${args[@]}"
  lipo -info "$output"/*/BareKit.framework/BareKit
}

step_addons() {
  log "addons"
  local src

  npm_install "$VENDOR/sodium-native"
  npm_overlay "$VENDOR/sodium-native" cmake-bare cmake-napi
  prebuild "$VENDOR/sodium-native"
  cp -R "$VENDOR"/sodium-native/prebuilds/watchos-* "$ROOT/node_modules/sodium-native/prebuilds/"

  npm_install "$VENDOR/bare-foundation"
  npm_overlay "$VENDOR/bare-foundation" cmake-bare
  prebuild "$VENDOR/bare-foundation"
  mkdir -p "$ROOT/node_modules/bare-foundation/prebuilds"
  cp -R "$VENDOR"/bare-foundation/prebuilds/watchos-* "$ROOT/node_modules/bare-foundation/prebuilds/"

  # Built as published: builtins of Bare Kit that packages still load as addons of their own, and udx-native,
  # which hyperdht loads although the watch opens no socket.
  for name in bare-inspect bare-type udx-native; do
    src="$VENDOR/addons/$name"
    rm -rf "$src"
    mkdir -p "$VENDOR/addons"
    cp -R "$ROOT/node_modules/$name" "$src"
    npm_install "$src"
    npm_overlay "$src" cmake-bare cmake-napi
    prebuild "$src"
    cp -R "$src"/prebuilds/watchos-* "$ROOT/node_modules/$name/prebuilds/"
  done

  lipo -info "$ROOT"/node_modules/*/prebuilds/watchos-*/*.bare
}

xcode() { # sdk destination settings...
  local sdk="$1" destination="$2"
  shift 2
  (cd "$ROOT" && BARE_KIT_LOCAL=1 xcodebuild -scheme App -sdk "$sdk" -destination "$destination" \
    -derivedDataPath build/DerivedData "$@" build)
}

step_app() {
  log "app"
  (cd "$ROOT" && xcodegen generate --quiet)
  xcode watchsimulator "platform=watchOS Simulator,name=$SIMULATOR"
  xcode watchos "generic/platform=watchOS" CODE_SIGNING_ALLOWED=NO
}

step_run() {
  log "run"
  local udid app="$ROOT/build/DerivedData/Build/Products/Debug-watchsimulator/App.app"
  udid=$(xcrun simctl list devices available | grep -F "    $SIMULATOR (" | grep -oE '[0-9A-F-]{36}' | head -1)
  xcrun simctl bootstatus "$udid" -b > /dev/null
  xcrun simctl install "$udid" "$app"
  xcrun simctl launch --console-pty --terminate-running-process "$udid" dev.ciranda.bare.watchos \
    > "$ROOT/build/console.log" 2>&1 &
  sleep 5
  xcrun simctl io "$udid" screenshot "$ROOT/build/simulator.png"
  xcrun simctl shutdown "$udid"
  cat "$ROOT/build/console.log"
}

if [ $# -eq 0 ]; then set -- sources deps barekit addons app; fi

for s in "$@"; do
  if ! declare -F "step_$s" > /dev/null; then
    echo "unknown step: $s" >&2
    exit 1
  fi
  "step_$s"
done
