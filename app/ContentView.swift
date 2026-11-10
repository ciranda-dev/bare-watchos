import SwiftUI

struct ContentView: View {
  @ObservedObject var model: SyncModel

  var body: some View {
    VStack(spacing: 8) {
      Text("Bare <-> watchOS")
        .font(.headline)

      Toggle("Switch", isOn: Binding(get: { model.on }, set: { model.setOn($0) }))

      Text("Peers: \(model.peers)")
        .font(.footnote)
        .monospacedDigit()
        .foregroundColor(.secondary)

      Text(model.publicKey)
        .font(.system(.caption2, design: .monospaced))
        .foregroundColor(.secondary)
    }
  }
}
