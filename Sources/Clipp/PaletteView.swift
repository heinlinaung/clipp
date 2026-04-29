import AppKit
import SwiftUI

struct PaletteView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject private var themeManager = ThemeManager.shared
    let onPick: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selection: Int = 0
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
            onEscape: { onDismiss() }
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
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                CardView(item: item, isSelected: index == selection, palette: palette)
                                    .id(index)
                                    .onTapGesture { onPick(item) }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onChange(of: selection) { new in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(new, anchor: .center)
                        }
                    }
                }
            }
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
}

private struct CardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            preview
        }
        .frame(width: 200, height: 220)
        .background(palette.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? palette.accent : palette.border,
                              lineWidth: isSelected ? 2 : 1)
        )
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
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

    func makeNSView(context: Context) -> NSView {
        let v = KeyView()
        v.onLeft = onLeft
        v.onRight = onRight
        v.onReturn = onReturn
        v.onEscape = onEscape
        DispatchQueue.main.async { v.window?.makeFirstResponder(nil); _ = v }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class KeyView: NSView {
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        var onReturn: (() -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if monitor == nil, window != nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self, self.window?.isKeyWindow == true else { return event }
                    switch event.keyCode {
                    case 123: self.onLeft?(); return nil   // ←
                    case 124: self.onRight?(); return nil  // →
                    case 53:  self.onEscape?(); return nil // esc
                    case 36, 76: self.onReturn?(); return nil // return / numpad enter
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
