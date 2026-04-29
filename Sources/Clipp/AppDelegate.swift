import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = ClipboardStore()
    private var monitor: ClipboardMonitor!
    private var hotKey: HotKey?
    private var palette: PaletteWindowController!
    private var statusMenu: NSMenu!
    private var themeMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        ThemeManager.shared.apply()

        palette = PaletteWindowController(store: store) { [weak self] item in
            self?.store.copyToPasteboard(item)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipp")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusMenu = NSMenu()
        statusMenu.addItem(NSMenuItem(title: "Show Palette  (⌘⌥K)",
                                      action: #selector(showPalette),
                                      keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Clear History",
                                      action: #selector(clearHistory),
                                      keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeMenu = NSMenu(title: "Theme")
        themeMenu.delegate = self
        for theme in AppTheme.allCases {
            let item = NSMenuItem(title: theme.label,
                                  action: #selector(setTheme(_:)),
                                  keyEquivalent: "")
            item.representedObject = theme.rawValue
            item.target = self
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        statusMenu.addItem(themeItem)

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit Clipp",
                                      action: #selector(quit),
                                      keyEquivalent: "q"))
        for item in statusMenu.items where item.target == nil { item.target = self }

        monitor = ClipboardMonitor(store: store)
        monitor.start()

        hotKey = HotKey(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | optionKey)
        ) { [weak self] in
            self?.palette.toggle()
        }
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            palette.toggle()
        }
    }

    @objc private func showPalette() { palette.show() }
    @objc private func clearHistory() { store.clear() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    @objc private func setTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = AppTheme(rawValue: raw) else { return }
        ThemeManager.shared.theme = theme
    }

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            guard menu === themeMenu else { return }
            let current = ThemeManager.shared.theme.rawValue
            for item in menu.items {
                item.state = ((item.representedObject as? String) == current) ? .on : .off
            }
        }
    }

    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",
                         action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",
                         action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",
                         action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",
                         action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",
                         action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }
}
