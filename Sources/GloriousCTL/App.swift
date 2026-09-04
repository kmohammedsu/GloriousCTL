import GloriousCore
import SwiftUI

@main
struct GloriousCTLApp: App {
  @StateObject private var controller: DeviceController

  init() {
    let controller = DeviceController()
    _controller = StateObject(wrappedValue: controller)
    AppBootstrap.renderMainWindowIfRequested(controller: controller)
  }

  var body: some Scene {
    WindowGroup {
      MainWindow()
        .environmentObject(controller)
        .onAppear { AppBootstrap.start(controller: controller) }
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .toolbar) {
        Button("Reload from Mouse") { controller.reloadFromDevice() }
          .keyboardShortcut("r", modifiers: .command)
        Button("Apply to Mouse") { controller.applyToDevice() }
          .keyboardShortcut("s", modifiers: .command)
          .disabled(!controller.hasUnsavedChanges)
      }
    }
  }
}
