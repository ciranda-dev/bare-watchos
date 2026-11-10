# Results

Measured on 2026-11-07 on one Mac. Nothing here ran on a real Apple Watch.

- Mac17,2 (Apple M5), macOS 26.7.1 (25G241).
- Xcode 26.2 (17C52): watchOS and watchOS Simulator SDKs 26.2, simulator runtime watchOS 26.2 (23S303), simulator
  `Apple Watch Series 11 (46mm)`. Linker: Xcode's ld-1230.1.
- `../tools`: bare-make 2.1.2, cmake-toolchains 2.2.2 with the fork over it, cmake-runtime 4.3.1, ninja-runtime
  1.13.2, llvm-runtime 23.1.6-0 (clang 23.1.5). Node 24.21.0, npm 11.19.0, XcodeGen 2.46.0.
- Bare Kit sources: Bare v1.36.2 (c0b6b3b, what bare-kit 3.0.1 fetches) and libuv v1.53.0 (840404ce, what Bare
  fetches), each with its fork's commit; bare-kit 174ecf8 (3.0.1) and bare-kit-swift 7be67fc (2.2.0), each with its
  fork's commit; libqjsng 8f10631, which builds QuickJS-NG 0.18.0 with its 11 patches; libjs b03f452; libintrusive
  01eae7f.
- The worklet: hyperswarm 4.17.2, hyperdht 6.36.0, `@hyperswarm/dht-relay` 0.4.3 with its fork at b04644f
  (`fix/relayed-client`), `@ciranda/dht-relay-http` at b9b1610, bare-switch-core 1.3.0 with its fork at 61fd18c
  (`feat/watchos`), bare-foundation 0.1.1 with its fork at 7a25909 (`feat/url-session`), sodium-native 5.2.0 with its
  fork, udx-native 1.22.1, hrpc 4.3.1. The `overrides` in `package.json` give `@hyperswarm/dht-relay` sodium-universal
  5 and noise-handshake 4.2, so the app links one sodium-native, 5.2.0, instead of 5.2.0 and 4.3.3.
- The app: bare-rpc-swift 1.1.0 and compact-encoding-swift 1.0.0, pinned in `project.yml` (see below).

## Clean run

With `../work`, every `node_modules`, `build`, `prebuilds`, `BareKit.xcframework` and this repository's generated files
removed:

```sh
../build.sh            # tools sources barekit example addons: exit 0, 416 s
../build.sh app run    # exit 0, 55 s
```

Logs: `../logs/clean-build.log`, `../logs/clean-app-run.log`. 185 compiler and linker warnings, none an error: 114
`variable 'err' set but not used`, 33 unused variables and 6 typedef redefinitions from Bare, libuv and the addons, 30
`-undefined dynamic_lookup is deprecated` (cmake-bare links every Apple addon that way), and
two that are real on arm64_32 only, both harmless here: Bare's `runtime.c` puts a 64-bit `st_size` in a 32-bit `size_t`
(a file of 4 GiB or more would read short), and sodium-native's `pbkdf2.c` has a range check that is always false with a
32-bit `size_t`.

## BareKit.xcframework

`../forks/bare-kit-swift/BareKit.xcframework`, built by `../build.sh barekit` from bare-kit-swift's own CMake with
`BARE_ENGINE=github:holepunchto/libqjsng#8f1063161a1d66ea870d1590bf460b7916f21da8`, one `bare-make generate`, `build`
and `install` per target as `holepunchto/actions/compile-prebuilds` does, then merged as
`holepunchto/actions/create-xcframework` does with its fork's grouping.

| Library identifier        | Architectures                                | `BareKit`   | `minos` (LC_BUILD_VERSION) |
| ------------------------- | -------------------------------------------- | ----------- | -------------------------- |
| `watchos-arm64_arm64_32`  | arm64_32 (3,059,928 B) + arm64 (3,080,592 B) | 6,160,784 B | 8.0, 26.0                  |
| `watchos-arm64-simulator` | arm64                                        | 3,088,136 B | 8.0                        |

- Both frameworks' `Info.plist` say `MinimumOSVersion` 8.0. The toolchains target watchOS 8.0 for every arch, as Xcode
  uses one deployment target for both device archs; Xcode's linker raises the arm64 slice to 26.0 by itself (checked
  with a plain Xcode watch app at 10.0: arm64_32 `minos 10.0`, arm64 `minos 26.0`).
- They load only CoreFoundation, libSystem and libobjc, and export Bare Kit, `js_*`, `napi_*` and `uv_*`. The engine
  strings in the binary are `quickjs-ng` and `0.18.0`.

## The app

`../build.sh app`: `xcodegen generate`, then `BARE_KIT_LOCAL=1 xcodebuild -scheme App` for
`platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)` and for `generic/platform=watchOS` with
`CODE_SIGNING_ALLOWED=NO`. Both `** BUILD SUCCEEDED **`. `app.bundle` is 1,476,937 B: 275 files, 203 of them
JavaScript, and five linked addons, made into xcframeworks by the scheme's `bare-link --preset watchos`.

| Debug build       | App        | BareKit     | bare-foundation | sodium-native | udx-native | bare-inspect | bare-type |
| ----------------- | ---------- | ----------- | --------------- | ------------- | ---------- | ------------ | --------- |
| watchOS Simulator | 6,748 KiB  | 3,088,432 B | 92,768 B        | 798,912 B     | 242,064 B  | 68,832 B     | 68,944 B  |
| watchOS, unsigned | 12,212 KiB | 6,160,784 B | 207,808 B       | 1,654,832 B   | 535,392 B  | 200,624 B    | 200,864 B |

The simulator build is arm64, the device build arm64_32 + arm64. bare-foundation links Foundation, CoreFoundation,
libSystem and libobjc, `minos` 8.0. The device build is compiled and linked only: not signed, not installed, not run.

## The switch in the simulator

The relay and the peer ran on the Mac, on the public DHT, and the app in the simulator, built Debug with `RELAY_URL`
`http://localhost:49443`:

```sh
node ../dht-relay-http/bin.js --port 49443 --host 127.0.0.1
node peer.js
```

A script that is not part of this repository booted the simulator, started both, waited 15 s for the peer's announce,
launched the app with `simctl launch --console-pty`, read the worklet's lines from the unified log (`log stream`),
pressed enter in `peer.js` five times and then tapped the switch five times with an XCUITest runner, 3 s apart. Logs:
`../logs/switch-run-1.log`, `../logs/switch-run-2.log` (the clean build's app), with `switch-summary-*.json`, and for run
2 the app's unified log (`switch-watch-raw.log`) and the runner's (`switch-xctest.log`). The screenshots are run 2's.

| Connected, off                    | Flipped on in `peer.js` | Flipped off on the watch |
| --------------------------------- | ----------------------- | ------------------------ |
| ![Connected](media/connected.png) | ![On](media/on.png)     | ![Off](media/off.png)    |

| Run | Launch to `up` | `up` to the first peer | `peer.js` to the watch (ms) | The watch to `peer.js` (ms) |
| --- | -------------- | ---------------------- | --------------------------- | --------------------------- |
| 1   | 469 ms         | 1,883 ms               | 2.9, 5.0, 6.9, 6.7, 8.7     | 6.2, 7.2, 5.0, 5.4, 14.5    |
| 2   | 418 ms         | 1,424 ms               | 6.0, 2.9, 7.7, 6.1, 6.8     | 6.0, 3.6, 3.9, 3.3, 4.5     |

- Launch to `up` is from `simctl launch` to the worklet's `[worklet] up` line, which it writes once its bundle is
  evaluated and the swarm made. In run 2 the app's first line in the unified log came 153 ms before `up`.
- A flip is timed from the line of the side that flipped (`peer.js`'s `set` on its stdout, the worklet's `set` in the
  unified log) to the line of the other side (`state`), all on the Mac's clock. The relay and the peer are on the same
  Mac as the simulator, so this is the relay's path, not a network's.
- Every flip arrived, each value once. The relay logged `Session opened (1)` as the worklet started, and one session
  for the whole run.
- Memory, as `footprint` reports the app's process: run 1, 37 MB once connected and 44 MB at the end; run 2, 31 MB
  (peak 34 MB) once connected and 44 MB at the end. This is a Mac process: the whole app, SwiftUI and Bare Kit with the
  worklet's QuickJS-NG heap, and the simulator sets it no limit.

The worklet used only URLSession:

- `app.bundle` has no bare-tcp, bare-net, bare-dns, bare-pipe or ws. It has udx-native, as hyperswarm requires hyperdht,
  whose dht-rpc requires udx-native when it loads, so its framework is linked and loaded. The worklet makes no UDX
  socket: the swarm is given the relayed DHT and never makes one of its own.
- `lsof -p` on the app's process in run 2, once connected and at the end, listed directories, files, character
  devices, kqueues and pipes, and no socket of any kind (`lsof -i` found none in run 1 either).
- CFNetwork logged 65 data tasks of the app in run 2, all `response_status=200`, on 13 http/1.1 connections. It also logged 45 failed tasks
  (`response_status=-1`), each right after an `Uploading ATS exception ATSAllowsLocalNetworking` (45 of those): its own
  report of the ATS exception, numbered apart from the app's tasks. The worklet logs any failed request of its own
  (`[worklet] relay -`), and logged none.

Without a relay (`../build.sh run`, which launches the app alone for 5 s), the screenshot (`build/simulator.png`)
showed the worklet's key and `Peers: 0`, and no crash report was written.

## Tests of the forks

| Fork                 | Branch               | Run                               | Result                                                      |
| -------------------- | -------------------- | --------------------------------- | ----------------------------------------------------------- |
| bare-switch-core     | `feat/watchos`       | `npm test` (Bare), `npm run lint` | 11/11, 27/27 asserts, with a new `joins as a client only`   |
| hyperswarm-dht-relay | `fix/relayed-client` | `npm test` (standard, Node)       | 15/15, 50/50 asserts, 3 upstream skips, two new tests       |
| cmake-toolchains     | `feat/watchos`       | `brittle-node test.js`            | 455/455, of which 42 build for the three watchOS toolchains |
| bare-addon-resolve   | `feat/watchos`       | `npm test` (Bare and Node)        | 96/96 each, with a new `linked module, watchos`             |
| bare-link            | `feat/watchos`       | `npm test` (Bare and Node)        | 58/58 each, with four new watchOS tests                     |
| bare-pack            | `feat/watchos`       | `brittle-bare` and `brittle-node` | 25/25 each                                                  |

The last four are from the first version of this example and were not run again. hyperswarm-dht-relay's two new tests
fail before their fixes: `client mode, keep-alive of the server` for `custodial: false`, and `stream that fails to
open` with an unhandled rejection.

## What went wrong on the way

- **The keep-alives of the peer flipped the switch off.** A client of `@hyperswarm/dht-relay` 0.4.3 without custody
  gets the peer's keep-alives, every 5 s from hyperdht, as empty messages, and bare-switch-core reads an empty message
  as off. hyperdht's own streams filter them. The fork sets `filterZeroByteMessages` on the client's `SecretStream`.
- **An unreachable relay was an uncaught error.** In Node, the worklet's code with no relay ended on `fetch failed` from
  the relay's stream, which nothing listened to, and then on an unhandled rejection of the protocol's opening, which
  nothing awaits. Bare aborts on either. `app.js` now handles the errors of its stream and the fork leaves no unhandled
  rejection; then the same code stayed up with no relay, and when the relay went away mid-session (Node, on a
  `hyperdht/testnet`).
- **The spec's Swift packages didn't build.** They asked for bare-rpc-swift and compact-encoding-swift at `main`,
  where bare-rpc-swift 2.0.0 no longer has the `RPCDelegate` the generated `HRPC` uses. Regenerated with hrpc-swift and
  hyperschema-swift 1.0 they ask for `from: "1.0.0"`, but they still say macOS 11 and iOS 14, which SwiftPM reads as
  watchOS 7, while bare-rpc-swift 1.1.1 and compact-encoding-swift 1.0.1 say macOS 13 and iOS 15, so watchOS 8:
  `The package product 'BareRPC' requires minimum platform version 8.0 for the watchOS platform, but this target
supports 7.0`. `project.yml` pins the last releases before that.
- **Two sodium-natives.** `@hyperswarm/dht-relay` 0.4.3 asks for sodium-universal 4 and noise-handshake 3, which bring
  sodium-native 4.3.3 next to 5.2.0. noise-handshake 4.0.0 only adds a length check, and dht-relay uses sodium for
  `crypto_generichash` and `crypto_sign` alone, so `overrides` give it the versions hyperdht uses.
- **A client finds only the peers that announced before it looked.** Hyperswarm looks a topic up when it joins and
  then every 10 minutes. The worklet's code under the Bare CLI on the Mac, started 3 s after `peer.js`, connected in
  one run and had no peer 12 s later in another; started 15 s after, it connected.
- **XCUITest's tap on the switch didn't flip it.** The element spans the whole row and the tap lands in its middle;
  tapping its knob does.
- **One launch hung on the watch's launch screen**, after an XCUITest session on the same booted simulator: no line
  from the worklet, and the process answered neither `footprint`, `sample` nor `simctl terminate`. It didn't happen
  again on a freshly booted simulator. The cause wasn't found.
- **The Bare CLI segfaults on `Bare.exit()` while a URLSession data task is in flight** (bare-foundation's fork,
  darwin-arm64). The worklet doesn't exit, but the binding has to handle it before it goes upstream.

## What only a real watch can prove

- The network: a watch allows only URLSession's HTTP tasks (TN3135), and it needs the relay over HTTPS. The simulator
  allows sockets, so the run above shows that the worklet opened none, not that a watch lets URLSession reach the
  relay, nor how a watch's radios, Wi-Fi or the paired phone carry the long polls.
- arm64_32 execution: the simulator runs arm64 only, so QuickJS-NG, Bare and the addons have not run with 32-bit
  pointers anywhere.
- Memory: the simulator sets no limit, and its numbers are a Mac process's.
- Loading addon frameworks linked with `-undefined dynamic_lookup` on a device, and an install signed for one.
- Lifecycle: what watchOS does to a suspended worklet that holds no background task, and to its long poll; the relay
  closes a session after 60 s without a request.
