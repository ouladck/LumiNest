import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            PrismStackLogoView()

            Text("LumiNest")
                .font(.largeTitle.bold())

            Text("Version 0.3.3")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("Fast macOS gallery for photos and videos.")
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Browse folders, switch between grid/list, and preview media with fast navigation.")
                Text("Mark favorites and organize media into albums with persistent local storage.")
                Text("Auto-refresh detects folder changes in real time.")
                Text("Settings Center lets you tune defaults, viewer behavior, and performance.")
                Text("Built with SwiftUI for macOS.")
            }
            .font(.callout)

            Spacer()
        }
        .padding(24)
    }
}
