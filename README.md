# Mac Media Gallery

A macOS SwiftUI app that lets you:

- Select any folder on disk.
- Discover photos and videos recursively.
- View media in `Grid` or `List` mode.
- Open any item in a viewer and navigate `Previous` / `Next`.
- Move through media with swipe (trackpad/mouse drag) or left/right arrow keys.
- Manage albums and favorites with persistent local SQLite storage.

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
