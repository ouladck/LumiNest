import AppKit
import SwiftUI

@main
struct MacMediaGalleryApp: App {
    init() {
        // SwiftPM executables do not run inside a normal .app bundle with a bundle ID.
        // Disable automatic tabbing to avoid AppKit trying to index tabs for restoration.
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 650)
        }
    }
}
