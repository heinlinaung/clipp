import AppKit
import Foundation

final class ClipboardMonitor {
    private let store: ClipboardStore
    private var lastChangeCount: Int
    private var timer: Timer?

    init(store: ClipboardStore) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        let content: ClipboardContent?
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            content = .file(first)
        } else if let png = pb.data(forType: .png) {
            content = .image(png)
        } else if let tiff = pb.data(forType: .tiff),
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) {
            content = .image(png)
        } else if let text = pb.string(forType: .string) {
            content = .text(text)
        } else {
            content = nil
        }

        guard let content else { return }
        Task { @MainActor in
            self.store.add(content)
        }
    }
}
