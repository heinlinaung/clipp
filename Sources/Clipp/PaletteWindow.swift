import AppKit
import SwiftUI

private final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PaletteWindowController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private let store: ClipboardStore
    private let onPick: (ClipboardItem) -> Void

    init(store: ClipboardStore, onPick: @escaping (ClipboardItem) -> Void) {
        self.store = store
        self.onPick = onPick
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        let height: CGFloat = 280
        let frame = NSRect(x: visible.minX, y: visible.minY,
                           width: visible.width, height: height)

        let panel: NSPanel
        if let existing = self.window {
            panel = existing
            panel.setFrame(frame, display: false)
        } else {
            panel = PalettePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isMovable = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            panel.delegate = self

            let host = NSHostingController(
                rootView: PaletteView(
                    store: store,
                    onPick: { [weak self] item in
                        self?.onPick(item)
                        self?.hide()
                    },
                    onDismiss: { [weak self] in self?.hide() }
                )
            )
            panel.contentViewController = host
            self.window = panel
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
