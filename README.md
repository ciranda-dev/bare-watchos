# Bare on watchOS

A minimal watchOS app that embeds Bare through [bare-kit-swift](https://github.com/holepunchto/bare-kit-swift). A worklet runs [`app/app.js`](app/app.js) on a thread of its own and answers the app over `Bare.IPC`: every tap counts up in the worklet, which also hashes a string with [sodium-native](https://github.com/holepunchto/sodium-native) to show that native addons load. The JavaScript engine is QuickJS-NG, through [libqjsng](https://github.com/holepunchto/libqjsng), as V8 doesn't run on watchOS.

## Status

watchOS isn't supported upstream yet. Until it is, this builds against the `feat/watchos` branches of cmake-toolchains, cmake-bare, cmake-napi, libuv, bare, bare-addon-resolve, bare-kit, bare-kit-swift, bare-link, bare-pack and sodium-native, checked out next to this repository in `../forks`, and `../build.sh` builds Bare Kit from them, installs the npm dependencies with the forks of bare-addon-resolve, bare-link and bare-pack over them, and adds watchOS prebuilds to the addons the worklet loads.

## Building

One-time setup:

```sh
../build.sh
xcodegen generate
```

Then build (or open in Xcode, launched from a shell with `BARE_KIT_LOCAL=1` set):

```sh
BARE_KIT_LOCAL=1 xcodebuild -scheme App -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

`BARE_KIT_LOCAL=1` makes bare-kit-swift use the `BareKit.xcframework` that `../build.sh` puts in `../forks/bare-kit-swift`. The scheme's pre-actions link the native addons (`bare-link`) and pack the worklet (`app/app.js` -> `app.bundle`).

## License

Apache-2.0
