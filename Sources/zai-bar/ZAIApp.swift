import SwiftUI
import AppKit

@main
struct ZAIApp: App {
    @State private var model = UsageModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(model)
                .frame(width: 330)
        } label: {
            MenuLabel(pct: model.headlinePercentage,
                      state: model.state,
                      hasKey: model.keyIsSet)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Keeps the app out of the Dock / app switcher — pure menu-bar agent.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
