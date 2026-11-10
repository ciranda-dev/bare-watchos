import SwiftUI

@main
struct App: SwiftUI.App {
  @StateObject private var model = Model()

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
    }
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .background:
        model.suspend()
      case .active:
        model.resume()
      default:
        break
      }
    }
  }
}
