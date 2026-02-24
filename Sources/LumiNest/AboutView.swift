import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            PrismStackLogoView()

            Text("LumiNest")
                .font(.largeTitle.bold())

            Text("Fast macOS gallery for photos and videos.")
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Browse folders, switch between grid/list, and preview media with quick navigation.")
                Text("Built with SwiftUI for macOS.")
            }
            .font(.callout)

            Spacer()
        }
        .padding(24)
    }
}
