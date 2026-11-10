# Bare on watchOS

A peer-to-peer **shared switch** for watchOS - the watch shell over [bare-switch-core](https://github.com/holepunchto/bare-switch-core), the same core behind [bare-ios](https://github.com/holepunchto/bare-ios) and [bare-macos](https://github.com/holepunchto/bare-macos). Flip the switch on the watch and it flips on every other copy, and back. A worklet runs the switch on a thread of its own through [bare-kit-swift](https://github.com/holepunchto/bare-kit-swift), on QuickJS-NG ([libqjsng](https://github.com/holepunchto/libqjsng)), as V8 doesn't run on watchOS.

A watch gives an app no sockets, only `URLSession`, so the worklet reaches the DHT through a relay over plain HTTP: [`@hyperswarm/dht-relay`](https://github.com/holepunchto/hyperswarm-dht-relay) over [`@ciranda/dht-relay-http`](https://github.com/ciranda-dev/dht-relay-http), with `URLSession` from [bare-foundation](https://github.com/holepunchto/bare-foundation). The relay never holds a key (`custodial: false`): Noise runs end to end between the watch and its peers, and the relay forwards ciphertext. A relayed node can connect to peers but not accept them, so the watch joins the topic as a client and finds the peers that announce it, such as bare-ios, bare-macos or `peer.js`. When the relay goes away, the watch joins again through it every 5 seconds.

## Building

```sh
./build.sh
```

It fetches the repositories the app builds from into `vendor/`, each at the commit it pins, applies [`patches/`](patches), builds Bare Kit for watchOS from them with QuickJS-NG, installs the npm dependencies with the patched packages over them, adds watchOS prebuilds to the addons the worklet loads, and builds the app for the watchOS simulator and, unsigned, for watchOS devices. `@ciranda/dht-relay-http` comes from a checkout of it next to this one, `../dht-relay-http`, until it is published.

Then build again or open it in Xcode, launched from a shell with `BARE_KIT_LOCAL=1` set, which makes bare-kit-swift use the `BareKit.xcframework` that `./build.sh` puts in `vendor/bare-kit-swift`:

```sh
BARE_KIT_LOCAL=1 xcodebuild -scheme App -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
```

The scheme's pre-actions link the native addons (`bare-link`) and pack the worklet (`app/app.js` -> `app.bundle`).

The `RELAY_URL` build setting names the relay, `http://localhost:49443` by default. The app allows plain HTTP only to this computer (`NSAllowsLocalNetworking`), so a watch needs the relay over HTTPS:

```sh
BARE_KIT_LOCAL=1 xcodebuild -scheme App -destination 'generic/platform=watchOS' RELAY_URL=https://relay.example.com build
```

## Running

Start the relay (after `npm install` in `../dht-relay-http`) and a peer on the computer, then the app in the simulator:

```sh
node ../dht-relay-http/bin.js --host 127.0.0.1
node peer.js
```

Press enter in `peer.js` and the switch flips on the watch, flip it on the watch and it flips in `peer.js`. The watch looks the topic up when it joins and every 10 minutes after, so start the peer first.

## Patches

watchOS isn't supported upstream yet. These patches make up the difference, each on top of the commit `build.sh` pins, and are offered upstream:

- **cmake-toolchains**: toolchains for `watchos-arm64_32`, `watchos-arm64` and `watchos-arm64-simulator`.
- **cmake-bare**, **cmake-napi**: `watchos` as a platform and `arm64_32` as an architecture.
- **libuv** (v1.53.0): the `uv_spawn()` stub of tvOS and watchOS compiles again.
- **bare** (v1.36.2): `watchos` for `Bare.platform` and `arm64_32` for `Bare.arch`.
- **bare-kit**: the iOS suspension is built for iOS only.
- **bare-kit-swift**: watchOS in its package and its CMake build.
- **bare-addon-resolve**, **bare-link**, **bare-pack**: addons resolved, linked and packed for watchOS, with a `watchos` preset.
- **sodium-native**: builds for watchOS.
- **bare-foundation**: `URLSession` data tasks, cancelled when Bare exits with one in flight.
- **bare-switch-core**: a session can join as a client only, and the Swift spec builds again with bare-rpc-swift 1.
- **hyperswarm-dht-relay**: a client without custody drops the keep-alives of its peers, leaves no unhandled rejection when its stream fails to open, gives its streams a round trip time, and reads as destroyed only once it is.
- **actions**: `create-xcframework` groups `arm64_32` with its platform. `build.sh` does the same itself.

## License

Apache-2.0
