import AppKit
import QuickLookThumbnailing
import SwiftUI

@MainActor
final class FilePreviewCache {
    static let shared = FilePreviewCache()
    private var cache: [URL: NSImage] = [:]
    private var inflight: Set<URL> = []

    func image(for url: URL) -> NSImage? { cache[url] }

    func load(_ url: URL, size: CGSize, scale: CGFloat, completion: @escaping (NSImage?) -> Void) {
        if let cached = cache[url] { completion(cached); return }
        guard !inflight.contains(url) else { return }
        inflight.insert(url)

        let req = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] rep, _ in
            let image = rep?.nsImage
            DispatchQueue.main.async {
                guard let self else { return }
                self.inflight.remove(url)
                if let image { self.cache[url] = image }
                completion(image)
            }
        }
    }
}

struct FilePreviewView: View {
    let url: URL
    let maxHeight: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: maxHeight)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    ProgressView().controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .frame(height: maxHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .onAppear { loadIfNeeded() }
    }

    private func loadIfNeeded() {
        if image != nil { return }
        if let cached = FilePreviewCache.shared.image(for: url) {
            self.image = cached
            return
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        FilePreviewCache.shared.load(url, size: CGSize(width: 320, height: maxHeight), scale: scale) { img in
            self.image = img
        }
    }
}
