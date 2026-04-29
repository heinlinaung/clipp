import AppKit
import SwiftUI

private let visibleBadgeLimit = 8
private let cardHeight: CGFloat = 220
private let cardSpacing: CGFloat = 12
private let stripHorizontalPadding: CGFloat = 16

struct PaletteView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject private var themeManager = ThemeManager.shared
    let onPick: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selection: Int = 0
    @State private var visibleIDs: [UUID] = []
    @FocusState private var searchFocused: Bool

    private var palette: ThemePalette { themeManager.theme.palette }

    private var filtered: [ClipboardItem] {
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            switch item.content {
            case .text(let s): return s.localizedCaseInsensitiveContains(query)
            case .file(let url): return url.lastPathComponent.localizedCaseInsensitiveContains(query)
            case .image: return false
            }
        }
    }

    /// Maps the first 8 in-view items' IDs to a 1-based slot number.
    private var numbering: [UUID: Int] {
        var dict: [UUID: Int] = [:]
        for (i, id) in visibleIDs.prefix(visibleBadgeLimit).enumerated() {
            dict[id] = i + 1
        }
        return dict
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            cardStrip
        }
        .background(
            ZStack {
                VisualEffectBackground()
                palette.background.opacity(0.85)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
        .padding(8)
        .onAppear {
            selection = 0
            searchFocused = true
        }
        .background(KeyEventHandling(
            onLeft: { move(-1) },
            onRight: { move(1) },
            onReturn: { pickCurrent() },
            onEscape: { onDismiss() },
            onDigit: { digit in pickByNumber(digit) }
        ))
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { pickCurrent() }
                    .onChange(of: query) { _ in selection = 0 }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(palette.chromeFill)
            .clipShape(Capsule())
            .frame(maxWidth: 280)

            Spacer()

            Text("\(store.items.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                store.clear()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Clear")
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(palette.chromeFill)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.items.isEmpty)
            .opacity(store.items.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var cardStrip: some View {
        Group {
            if filtered.isEmpty {
                VStack {
                    Spacer()
                    Text(store.items.isEmpty ? "Copy something to get started" : "No matches")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                GeometryReader { geo in
                    let cardWidth = max(120,
                        (geo.size.width - stripHorizontalPadding * 2
                            - cardSpacing * CGFloat(visibleBadgeLimit - 1))
                        / CGFloat(visibleBadgeLimit))

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: cardSpacing) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                    CardView(
                                        item: item,
                                        isSelected: index == selection,
                                        slotNumber: numbering[item.id],
                                        palette: palette,
                                        onDelete: { store.delete(item) }
                                    )
                                    .frame(width: cardWidth, height: cardHeight)
                                    .id(index)
                                    .background(
                                        GeometryReader { itemGeo in
                                            Color.clear.preference(
                                                key: VisibleItemsKey.self,
                                                value: [VisibleItemFrame(
                                                    id: item.id,
                                                    minX: itemGeo.frame(in: .named("strip")).minX,
                                                    maxX: itemGeo.frame(in: .named("strip")).maxX
                                                )]
                                            )
                                        }
                                    )
                                    .onTapGesture { onPick(item) }
                                }
                            }
                            .padding(.horizontal, stripHorizontalPadding)
                            .padding(.vertical, 14)
                        }
                        .coordinateSpace(name: "strip")
                        .onChange(of: selection) { new in
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(new, anchor: .center)
                            }
                        }
                        .onPreferenceChange(VisibleItemsKey.self) { frames in
                            updateVisibleIDs(frames: frames, viewportWidth: geo.size.width)
                        }
                    }
                }
            }
        }
    }

    private func updateVisibleIDs(frames: [VisibleItemFrame], viewportWidth: CGFloat) {
        // Keep cards whose center sits inside the viewport, ordered left-to-right.
        let visible = frames
            .filter { ($0.minX + $0.maxX) / 2 >= 0 && ($0.minX + $0.maxX) / 2 <= viewportWidth }
            .sorted { $0.minX < $1.minX }
            .map(\.id)
        if visible != visibleIDs {
            visibleIDs = visible
        }
    }

    private func move(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selection = max(0, min(count - 1, selection + delta))
    }

    private func pickCurrent() {
        guard filtered.indices.contains(selection) else { return }
        onPick(filtered[selection])
    }

    private func pickByNumber(_ n: Int) {
        let visible = visibleIDs.prefix(visibleBadgeLimit)
        guard n >= 1, n <= visible.count else { return }
        let targetID = visible[visible.index(visible.startIndex, offsetBy: n - 1)]
        if let item = filtered.first(where: { $0.id == targetID }) {
            onPick(item)
        }
    }
}

private struct VisibleItemFrame: Equatable {
    let id: UUID
    let minX: CGFloat
    let maxX: CGFloat
}

private struct VisibleItemsKey: PreferenceKey {
    static var defaultValue: [VisibleItemFrame] = []
    static func reduce(value: inout [VisibleItemFrame], nextValue: () -> [VisibleItemFrame]) {
        value.append(contentsOf: nextValue())
    }
}

private struct CardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let slotNumber: Int?
    let palette: ThemePalette
    let onDelete: () -> Void
    @State private var hovering: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            preview
        }
        .background(palette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? palette.accent : palette.border,
                              lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if let n = slotNumber {
                Text("⌘\(n)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.accent.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(6)
            }
        }
        .onHover { hovering = $0 }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering || isSelected ? 1 : 0)
            .help("Delete")
        }
        .padding(.leading, 10)
        .padding(.trailing, slotNumber != nil ? 56 : 10)
        .padding(.vertical, 8)
    }

    private var preview: some View {
        Group {
            switch item.content {
            case .text(let s):
                ScrollView {
                    Text(s)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            case .image(let data):
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            case .file(let url):
                FilePreviewView(url: url, maxHeight: 170)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch item.content {
        case .text(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(40))
        case .image:
            return "Image"
        case .file(let url):
            return url.lastPathComponent
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct KeyEventHandling: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onReturn: () -> Void
    let onEscape: () -> Void
    let onDigit: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = KeyView()
        v.onLeft = onLeft
        v.onRight = onRight
        v.onReturn = onReturn
        v.onEscape = onEscape
        v.onDigit = onDigit
        DispatchQueue.main.async { v.window?.makeFirstResponder(nil); _ = v }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class KeyView: NSView {
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        var onReturn: (() -> Void)?
        var onEscape: (() -> Void)?
        var onDigit: ((Int) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if monitor == nil, window != nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self, self.window?.isKeyWindow == true else { return event }
                    if event.modifierFlags.contains(.command) {
                        if let chars = event.charactersIgnoringModifiers,
                           let scalar = chars.unicodeScalars.first,
                           let digit = Int(String(scalar)),
                           digit >= 1, digit <= visibleBadgeLimit {
                            self.onDigit?(digit)
                            return nil
                        }
                    }
                    switch event.keyCode {
                    case 123: self.onLeft?(); return nil
                    case 124: self.onRight?(); return nil
                    case 53:  self.onEscape?(); return nil
                    case 36, 76: self.onReturn?(); return nil
                    default: return event
                    }
                }
            }
        }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}
