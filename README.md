# Clipp

A lightweight macOS clipboard manager. Lives in your menu bar, summons a horizontal palette of recent clips, supports text, images, and files.

## Features

- Menu-bar accessory app — no Dock icon
- Hotkey: **⌘⌥K** to summon/dismiss the palette
- Captures text, images (PNG/TIFF), and file copies (with QuickLook previews)
- Search by content or filename
- Keyboard navigation: ← / → to move, Return to copy, Esc to dismiss
- History persists across launches (last 100 items)
- Five themes: Dark, Midnight, Nord, Solarized Dark, Dracula

## Run from source

```sh
swift run Clipp
```

Requires macOS 13+ and Xcode 15+ (Swift 5.9).

## Build the .app

```sh
./scripts/package.sh
```

Produces a universal (arm64 + x86_64), ad-hoc signed `dist/Clipp.app`. Drop it into `/Applications`.

## Status-bar menu

Right-click the menu-bar icon for: Show Palette, Clear History, Theme, Quit.

## Storage

History and preferences live in `~/Library/Application Support/Clipp/`.
