import BareKit
import BareRPC
import Foundation
import HRPC

// Bridges the generated hrpc engine to the worklet's IPC: bare-rpc hands over
// the frames to send and is fed the ones that arrive, framing them itself.
final class BareTransport: RPCDelegate {
  private let ipc: IPC

  init(ipc: IPC) {
    self.ipc = ipc
  }

  func rpc(_ rpc: RPC, send data: Data) {
    Task { try? await ipc.write(data) }
  }

  func readLoop(into hrpc: HRPC) {
    Task {
      for await chunk in ipc {
        await hrpc.receive(chunk)
      }
    }
  }
}
