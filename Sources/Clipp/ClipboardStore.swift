import AppKit
import Combine
import Foundation

enum ClipboardContent: Equatable {
    case text(String)
    case image(Data)
    case file(URL)
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let content: ClipboardContent
    let date: Date

    init(id: UUID = UUID(), content: ClipboardContent, date: Date = Date()) {
        self.id = id
        self.content = content
        self.date = date
    }

    enum CodingKeys: String, CodingKey { case id, kind, text, image, fileURL, date }
    enum Kind: String, Codable { case text, image, file }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.date = try c.decode(Date.self, forKey: .date)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .text:
            self.content = .text(try c.decode(String.self, forKey: .text))
        case .image:
            self.content = .image(try c.decode(Data.self, forKey: .image))
        case .file:
            self.content = .file(try c.decode(URL.self, forKey: .fileURL))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        switch content {
        case .text(let s):
            try c.encode(Kind.text, forKey: .kind)
            try c.encode(s, forKey: .text)
        case .image(let d):
            try c.encode(Kind.image, forKey: .kind)
            try c.encode(d, forKey: .image)
        case .file(let url):
            try c.encode(Kind.file, forKey: .kind)
            try c.encode(url, forKey: .fileURL)
        }
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    private let maxItems = 100
    private let storageURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = appSupport.appendingPathComponent("Clipp", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.storageURL = base.appendingPathComponent("history.json")

        let legacy = appSupport.appendingPathComponent("Kakashi", isDirectory: true)
            .appendingPathComponent("history.json")
        if !fm.fileExists(atPath: storageURL.path),
           fm.fileExists(atPath: legacy.path) {
            try? fm.moveItem(at: legacy, to: storageURL)
        }

        load()
    }

    func add(_ content: ClipboardContent) {
        if case .text(let s) = content,
           s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        if items.first?.content == content { return }
        items.insert(ClipboardItem(content: content), at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        scheduleSave()
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.content {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .image(let d):
            pb.setData(d, forType: .png)
        case .file(let url):
            pb.writeObjects([url as NSURL])
        }
    }

    func clear() {
        items.removeAll()
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    private func save() async {
        let snapshot = items
        let url = storageURL
        await Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("Clipp: save failed: \(error)")
            }
        }.value
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            self.items = decoded
        }
    }
}
