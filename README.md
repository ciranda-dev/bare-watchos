# Bare on watchOS

A peer-to-peer **shared switch** for watchOS - the watch shell over [bare-switch-core](https://github.com/holepunchto/bare-switch-core), the same core behind [bare-ios](https://github.com/holepunchto/bare-ios) and [bare-macos](https://github.com/holepunchto/bare-macos). Flip the switch on the watch and it flips on every other copy, and back. A worklet runs the switch on a thread of its own through [bare-kit-swift](https://github.com/holepunchto/bare-kit-swift), on QuickJS-NG ([libqjsng](https://github.com/holepunchto/libqjsng)), as V8 doesn't run on watchOS.

A watch gives an app no sockets, only `URLSession`, so the worklet reaches the DHT through a relay over plain HTTP: [`@hyperswarm/dht-relay`](https://github.com/holepunchto/hyperswarm-dht-relay) over [`@ciranda/dht-relay-http`](../dht-relay-http), with `URLSession` from [bare-foundation](https://github.com/holepunchto/bare-foundation). The relay never holds a key (`custodial: false`): Noise runs end to end between the watch and its peers, and the relay forwards ciphertext. A relayed node can connect to peers but not accept them, so the watch joins the topic as a client and finds the peers that announce it, such as bare-ios, bare-macos or `peer.js`.

## Status

watchOS isn't supported upstream yet. Until it is, this builds against branches checked out next to this repository in `../forks`: `feat/watchos` of cmake-toolchains, cmake-bare, cmake-napi, libuv, bare, bare-addon-resolve, bare-kit, bare-kit-swift, bare-link, bare-pack, sodium-native and bare-switch-core, `feat/url-session` of bare-foundation and `fix/relayed-client` of hyperswarm-dht-relay. `../build.sh` builds Bare Kit from them, installs the npm dependencies with the forks over them, and adds watchOS prebuilds to the addons the worklet loads. `@ciranda/dht-relay-http` comes from `../dht-relay-http` until it is published.

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

The `RELAY_URL` build setting names the relay, `http://localhost:49443` by default. The app allows plain HTTP only to this computer (`NSAllowsLocalNetworking`), so a watch needs the relay over HTTPS:

```sh
BARE_KIT_LOCAL=1 xcodebuild -scheme App -destination 'generic/platform=watchOS' RELAY_URL=https://relay.example.com build
```

## Running

Start the relay and a peer on the computer, then the app in the simulator:

```sh
node ../dht-relay-http/bin.js --host 127.0.0.1
node peer.js
```

Press enter in `peer.js` and the switch flips on the watch, flip it on the watch and it flips in `peer.js`. The watch looks the topic up when it starts and every 10 minutes after, so start the peer first.

## License

Apache-2.0
