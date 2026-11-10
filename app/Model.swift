import BareKit
import Foundation

// Owns the worklet, which runs app.bundle on a thread of its own, and talks to
// it over its IPC: every write counts up, every reply is a line of JSON.
@MainActor
final class Model: ObservableObject {
  struct Reply: Decodable {
    let platform: String
    let arch: String
    let count: Int
    let hash: String
  }

  @Published var reply: Reply?

  private let worklet: Worklet
  private let ipc: IPC

  init() {
    worklet = try! Worklet()
    ipc = try! IPC(worklet: worklet)

    try! worklet.start("app.bundle")

    Task { await read() }

    increment()
  }

  func increment() {
    Task { try await ipc.write(Data("+".utf8)) }
  }

  func suspend() { worklet.suspend() }
  func resume() { worklet.resume() }

  private func read() async {
    var buffer = Data()

    for await data in ipc {
      buffer.append(data)

      while let newline = buffer.firstIndex(of: 0x0A) {
        reply = try? JSONDecoder().decode(Reply.self, from: buffer[..<newline])
        buffer.removeSubrange(...newline)
      }
    }
  }
}
