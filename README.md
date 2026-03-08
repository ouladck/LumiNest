# LumiNest

Version: `1.0.1-RC`

LumiNest is a macOS gallery app for photos and videos, built with SwiftUI.

## Features

- Folder-based library browsing (recursive scan).
- Grid and List display modes.
- Fast preview with next/previous navigation.
- Keyboard shortcuts:
- `Cmd+O` select folder
- `Cmd+F` focus search
- `Cmd+,` open settings
- `Space` play/pause video
- `R` replay video
- `Esc` close viewer
- Favorites and Albums with persistent local SQLite storage.
- Metadata panel for images and videos.
- Search, media type filters, and sorting (date/name/size).
- Media-only fullscreen preview mode.
- Auto-refresh when folder content changes.
- Settings Center (viewer behavior, defaults, performance, language).
- Multi-language localization support.

## Project Structure

- App sources: `Sources/LumiNest`
- Localized strings: `Sources/LumiNest/Resources/*.lproj/Localizable.strings`
- SVG logo source: `assets/logos/prism-stack.svg`

## Run (Development)

### Xcode

```bash
open Package.swift
```

Then select scheme `LumiNest` and Run.

### SwiftPM

```bash
swift run LumiNest
```

## Build

```bash
xcodebuild \
  -scheme LumiNest \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath build \
  build
```

## Build a `.app` Bundle

SwiftPM output is an executable binary, so create the app bundle explicitly:

```bash
APP="dist/LumiNest.app"
PRODUCTS="build/Build/Products/Release"
BIN="$PRODUCTS/LumiNest"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LumiNest"
chmod +x "$APP/Contents/MacOS/LumiNest"
cp -R "$PRODUCTS"/*.bundle "$APP/Contents/Resources/"
```

Add a valid `Info.plist` under `LumiNest.app/Contents/Info.plist` before distribution.

## Package for Release

```bash
cd dist
ditto -c -k --sequesterRsrc --keepParent LumiNest.app LumiNest-1.0.1-RC.zip
```

## Supported Media

Images: `jpg`, `jpeg`, `png`, `heic`, `gif`, `bmp`, `tiff`, `webp`, `raw`  
Videos: `mp4`, `mov`, `m4v`, `avi`, `mkv`, `wmv`, `flv`, `webm`

## License

GNU GPL v3.0 only (`GPL-3.0-only`). See [LICENSE](LICENSE).
