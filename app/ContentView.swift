import SwiftUI

struct ContentView: View {
  @ObservedObject var model: Model

  var body: some View {
    VStack(spacing: 8) {
      Text("Bare <-> watchOS")
        .font(.headline)

      if let reply = model.reply {
        Text("\(reply.platform)-\(reply.arch)")
          .font(.footnote)
          .foregroundColor(.secondary)

        Button("\(reply.count)") { model.increment() }
          .font(.title2)
          .monospacedDigit()

        Text(reply.hash.prefix(16))
          .font(.system(.caption2, design: .monospaced))
          .foregroundColor(.secondary)
      } else {
        ProgressView()
      }
    }
  }
}
