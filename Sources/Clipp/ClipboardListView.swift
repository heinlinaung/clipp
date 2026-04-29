import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var store: ClipboardStore
    @State private var query: String = ""
    let onPick: (ClipboardItem) -> Void
    let onQuit: () -> Void

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
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clipboard", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(store.items.isEmpty ? "Copy something to get started" : "No matches")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { item in
                            ClipboardRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { onPick(item) }
                            Divider()
                        }
                    }
                }
            }

            Divider()
            HStack {
                Text("\(store.items.count) item\(store.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { store.clear() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                Button("Quit", action: onQuit)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(8)
        }
        .frame(width: 360, height: 480)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem

    var body: some View {
        switch item.content {
        case .text(let s):
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s)
                        .lineLimit(3)
                        .font(.system(.body, design: .default))
                    Text(item.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        case .image(let data):
            VStack(alignment: .leading, spacing: 4) {
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 140)
                        .background(
                            Color(nsColor: .controlBackgroundColor)
                                .cornerRadius(6)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                    HStack(spacing: 6) {
                        Text("\(Int(nsImage.size.width))×\(Int(nsImage.size.height))")
                        Text("·")
                        Text(item.date, style: .relative)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .file(let url):
            VStack(alignment: .leading, spacing: 4) {
                FilePreviewView(url: url, maxHeight: 140)
                HStack(spacing: 6) {
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("·")
                    Text(item.date, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
