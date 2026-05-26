import AppKit
import SwiftUI

@main
struct BatchClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DownloaderStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 860, minHeight: 620)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Text File...") {
                    store.openTextFile()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Stop Batch") {
                    store.cancelBatch()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!store.isRunning)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
