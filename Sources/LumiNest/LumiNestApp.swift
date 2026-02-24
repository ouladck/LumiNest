import AppKit
import SwiftUI

@main
struct LumiNestApp: App {
    init() {
        // SwiftPM executables do not run inside a normal .app bundle with a bundle ID.
        // Disable automatic tabbing to avoid AppKit trying to index tabs for restoration.
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApplication.shared.setActivationPolicy(.regular)
        if let dockIcon = DockIconRenderer.makeIcon() {
            NSApplication.shared.applicationIconImage = dockIcon
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("LumiNest") {
            ContentView()
                .frame(minWidth: 900, minHeight: 650)
        }

        Window("About LumiNest", id: "about") {
            AboutView()
                .frame(minWidth: 420, minHeight: 320)
        }

        Window("LumiNest Help", id: "help") {
            HelpView()
                .frame(minWidth: 520, minHeight: 420)
        }
        .commands {
            LumiNestCommands()
        }
    }
}

struct LumiNestCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About LumiNest") {
                openWindow(id: "about")
            }
        }

        CommandGroup(after: .help) {
            Button("LumiNest Help") {
                openWindow(id: "help")
            }
            .keyboardShortcut("/", modifiers: .command)
        }
    }
}
