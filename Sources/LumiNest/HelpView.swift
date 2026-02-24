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
                        "F: add/remove current media from favorites",
                        "R: replay current video",
                        "Esc: close preview",
                        "Use the fullscreen button in viewer header for media-only full-screen mode",
                        "Details is collapsible: click the Details line to expand/collapse metadata",
                        "Click outside the preview: close preview"
                    ]
                )

                helpSection(
                    title: "Library Tools",
                    lines: [
                        "Switch Grid/List from the header.",
                        "Use Album picker: All, Favorites, or a custom album.",
                        "Use filters: All, Photos, Videos.",
                        "Sort by Name, Date, or Size.",
                        "Right-click an item for: Open, Reveal in Finder, Copy Path, Move to Trash."
                    ]
                )

                helpSection(
                    title: "Favorites & Albums",
                    lines: [
                        "To select a favorite: right-click media and choose Add to Favorites.",
                        "Favorited items show a yellow star in grid/list.",
                        "To show only favorites: set Album picker to Favorites.",
                        "To create an album: right-click media and choose New Album....",
                        "To add media into an existing album: right-click media -> Add to Album.",
                        "Use the folder-gear button next to Album picker to rename or delete the selected album.",
                        "While viewing a selected album, right-click media -> Remove from \"Album\" to unassign it."
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
