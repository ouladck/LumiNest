import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("LumiNest Help")
                    .font(.title.bold())

                helpSection(
                    title: "Getting Started",
                    lines: [
                        "1. Click Select Folder (or press Cmd+O).",
                        "2. Choose a folder containing photos/videos.",
                        "3. Click any media item to open preview."
                    ]
                )

                helpSection(
                    title: "Viewer Controls",
                    lines: [
                        "Left / Right arrows: previous / next media",
                        "Space: play/pause current video",
                        "R: replay current video",
                        "Esc: close preview",
                        "Click outside the preview: close preview"
                    ]
                )

                helpSection(
                    title: "Library Tools",
                    lines: [
                        "Switch Grid/List from the header.",
                        "Use filters: All, Photos, Videos.",
                        "Sort by Name, Date, or Size.",
                        "Right-click an item for: Open, Reveal in Finder, Copy Path, Move to Trash."
                    ]
                )
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func helpSection(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
