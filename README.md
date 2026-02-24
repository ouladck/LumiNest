# LumiNest

Version: `0.2.0`

A macOS SwiftUI gallery app that lets you:

- Select any folder on disk.
- Discover photos and videos recursively.
- Auto-refresh when media is added/removed in the selected folder.
- View media in `Grid` or `List` mode.
- Open any item in a viewer and navigate `Previous` / `Next`.
- Move through media with swipe (trackpad/mouse drag) or left/right arrow keys.
- Use keyboard shortcuts (`Cmd+O`, `Cmd+F`, `Cmd+,`, `Space`, `Esc`, `F`, `R`).
- Manage albums and favorites with persistent local SQLite storage.
- Use Settings Center to configure default behavior and performance.

## Run

### Option 1: Xcode (recommended)
1. Open terminal in this folder.
2. Run:
   ```bash
   open Package.swift
   ```
3. In Xcode, choose the `LumiNest` scheme.
4. Press Run.

### Option 2: SwiftPM
```bash
swift run LumiNest
```

## Supported media

Images:
`jpg`, `jpeg`, `png`, `heic`, `gif`, `bmp`, `tiff`, `webp`, `raw`

Videos:
`mp4`, `mov`, `m4v`, `avi`, `mkv`, `wmv`, `flv`, `webm`

## Viewer highlights

- Click outside preview to close.
- Side arrow controls for previous/next.
- Star button for favorites.
- Info button to show/hide metadata details.
- Media-only fullscreen toggle.
