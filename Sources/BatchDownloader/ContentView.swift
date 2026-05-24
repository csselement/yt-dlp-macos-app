import SwiftUI

struct ContentView: View {
    @State private var store = DownloaderStore()
    @State private var linkKind: DownloadKind = .video

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderView(store: store)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                Divider()

                HSplitView {
                    EntryPanel(store: store, linkKind: $linkKind)
                        .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)

                    QueuePanel(store: store)
                        .frame(minWidth: 460)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct HeaderView: View {
    let store: DownloaderStore

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Batch Downloader")
                    .font(.title2.weight(.semibold))
                Text("Video saves as H.264 MP4. Audio saves as MP3 320 kbps.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(store.globalMessage)
                    .font(.callout.weight(.medium))
                Text(store.dependencySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EntryPanel: View {
    let store: DownloaderStore
    @Binding var linkKind: DownloadKind

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Links")
                    .font(.headline)

                TextEditor(text: Binding(
                    get: { store.pendingText },
                    set: { store.pendingText = $0 }
                ))
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)
                .utilitySurface(cornerRadius: 8)
                .frame(minHeight: 180)
                .accessibilityLabel("Links to add")
            }

            Picker("Type", selection: $linkKind) {
                ForEach(DownloadKind.allCases) { kind in
                    Label(kind.rawValue, systemImage: kind.symbolName)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)

            Button {
                store.addLinks(kind: linkKind)
            } label: {
                Label("Add to Batch", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.pendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            VStack(alignment: .leading, spacing: 8) {
                Text("Download Folder")
                    .font(.headline)

                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(store.selectedFolder.path)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Browse") {
                        store.chooseFolder()
                    }
                }
                .padding(10)
                .utilitySurface(cornerRadius: 8)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    store.startBatch()
                } label: {
                    Label("Start Batch", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canStart)

                Button {
                    store.cancelBatch()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .disabled(!store.isRunning)
            }
        }
        .padding(20)
    }
}

private struct QueuePanel: View {
    let store: DownloaderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Batch")
                    .font(.headline)
                Text("\(store.items.count)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.resetFailedAndQueued()
                } label: {
                    Label("Retry Failed", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRunning)

                Button {
                    store.clearFinished()
                } label: {
                    Label("Clear Done", systemImage: "checkmark.circle")
                }
                .disabled(store.isRunning)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if store.items.isEmpty {
                ContentUnavailableView(
                    "No Links Queued",
                    systemImage: "tray",
                    description: Text("Paste one link per line, choose video or audio, then add them to the batch.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.items) { item in
                        QueueRow(item: item)
                            .padding(.vertical, 6)
                    }
                    .onDelete(perform: store.removeItems)
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct QueueRow: View {
    let item: DownloadItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.symbolName)
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.url)
                    .font(.callout)
                    .lineLimit(2)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(item.kind.detail)
                    Text(item.status.label)
                        .foregroundStyle(statusColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if case .failed(let message) = item.status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            StatusIcon(status: item.status)
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued: .secondary
        case .running: .blue
        case .finished: .green
        case .failed: .red
        }
    }
}

private struct StatusIcon: View {
    let status: DownloadStatus

    var body: some View {
        Group {
            switch status {
            case .queued:
                Image(systemName: "circle")
            case .running:
                ProgressView()
                    .controlSize(.small)
            case .finished:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 24, height: 24)
    }
}

#Preview {
    ContentView()
}

private extension View {
    func utilitySurface(cornerRadius: CGFloat) -> some View {
        modifier(UtilitySurface(cornerRadius: cornerRadius))
    }
}

private struct UtilitySurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.background, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.separator, lineWidth: 1)
                }
        }
    }
}
