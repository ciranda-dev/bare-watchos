import BareKit
import Foundation
import HRPC
import Schema

// Owns the worklet, which runs app.bundle on a thread of its own, and talks to
// it through the generated, typed hrpc interface. The worklet reaches the DHT
// through the relay named by the RELAY_URL build setting.
@MainActor
final class SyncModel: ObservableObject {
  @Published var on = false
  @Published var peers = 0
  @Published var publicKey = "..."

  private let worklet: Worklet
  private let transport: BareTransport
  private let rpc: HRPC

  init() {
    worklet = try! Worklet()

    let ipc = try! IPC(worklet: worklet)

    transport = BareTransport(ipc: ipc)
    rpc = HRPC(delegate: transport)

    rpc.onNewState { [weak self] state in
      guard let state else { return }
      await MainActor.run { self?.on = state.on }
    }
    rpc.onPeersChanged { [weak self] peers in
      guard let peers else { return }
      await MainActor.run { self?.peers = Int(peers.count) }
    }
    rpc.onInfo { [weak self] info in
      guard let info else { return }
      await MainActor.run { self?.publicKey = info.publicKey }
    }

    let relay = Bundle.main.object(forInfoDictionaryKey: "RelayURL") as! String

    try! worklet.start("app.bundle", arguments: [relay])

    transport.readLoop(into: rpc)
  }

  // Update optimistically, then take the state the worklet returns once it has
  // told the peers.
  func setOn(_ value: Bool) {
    on = value
    Task { [weak self] in
      guard let rpc = self?.rpc else { return }
      if let result = try? await rpc.setState(SwitchState(on: value)) {
        await MainActor.run { self?.on = result.on }
      }
    }
  }

  func suspend() { worklet.suspend() }
  func resume() { worklet.resume() }
}
