import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DownloaderStore {
    static let moderateBatchWarningCount = 10
    static let highBatchWarningCount = 25
    static let minimumCooldownSeconds: UInt64 = 8
    static let maximumCooldownSeconds: UInt64 = 18

    var pendingText = ""
    var items: [DownloadItem] = []
    var selectedFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    var isRunning = false
    var globalMessage = "Ready"

    private let ytDLPPath = "/opt/homebrew/bin/yt-dlp"
    private let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
    private let runner = DownloadRunner()

    var canStart: Bool {
        !isRunning && !items.filter { $0.status != .finished }.isEmpty
    }

    var dependencySummary: String {
        let ytdlp = FileManager.default.isExecutableFile(atPath: ytDLPPath) ? "yt-dlp ready" : "yt-dlp missing"
        let ffmpeg = FileManager.default.isExecutableFile(atPath: ffmpegPath) ? "ffmpeg ready" : "ffmpeg missing"
        return "\(ytdlp) · \(ffmpeg)"
    }

    var rateLimitWarning: String? {
        let remainingCount = items.filter { $0.status != .finished }.count

        if remainingCount >= Self.highBatchWarningCount {
            return "High rate-limit risk: \(remainingCount) queued links. The app downloads sequentially with cooldowns, but large batches from the same site can still be throttled."
        }

        if remainingCount >= Self.moderateBatchWarningCount {
            return "Rate-limit caution: \(remainingCount) queued links. Downloads are slowed automatically to reduce platform throttling risk."
        }

        return nil
    }

    func addLinks(kind: DownloadKind) {
        let links = pendingText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !links.isEmpty else { return }

        let existing = Set(items.map(\.url))
        let newItems = links
            .filter { !existing.contains($0) }
            .map { DownloadItem(url: $0, kind: kind) }

        items.append(contentsOf: newItems)
        pendingText = ""
        if let rateLimitWarning {
            globalMessage = rateLimitWarning
        } else {
            globalMessage = newItems.isEmpty ? "No new links added" : "Added \(newItems.count) link\(newItems.count == 1 ? "" : "s")"
        }
    }

    func removeItems(at offsets: IndexSet) {
        guard !isRunning else { return }
        items.remove(atOffsets: offsets)
    }

    func clearFinished() {
        guard !isRunning else { return }
        items.removeAll { $0.status == .finished }
    }

    func resetFailedAndQueued() {
        guard !isRunning else { return }
        for index in items.indices {
            if case .failed = items[index].status {
                items[index].status = .queued
                items[index].log = ""
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedFolder
        panel.prompt = "Use Folder"

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            globalMessage = "Download folder set"
        }
    }

    func startBatch() {
        guard !isRunning else { return }

        guard FileManager.default.isExecutableFile(atPath: ytDLPPath) else {
            globalMessage = "Install yt-dlp at \(ytDLPPath)"
            return
        }

        guard FileManager.default.isExecutableFile(atPath: ffmpegPath) else {
            globalMessage = "Install ffmpeg at \(ffmpegPath)"
            return
        }

        isRunning = true
        Task { await runQueue() }
    }

    func cancelBatch() {
        isRunning = false
        globalMessage = "Cancelled"
        if let index = items.firstIndex(where: { $0.status == .running }) {
            items[index].status = .failed("Cancelled")
        }
        Task { await runner.cancel() }
    }

    private func runQueue() async {
        defer {
            isRunning = false
        }

        let queueIndices = items.indices.filter { items[$0].status != .finished }
        guard !queueIndices.isEmpty else {
            globalMessage = "Nothing to download"
            return
        }

        for (position, index) in queueIndices.enumerated() {
            guard !Task.isCancelled else { return }
            items[index].status = .running
            items[index].log = ""
            globalMessage = "Downloading \(index + 1) of \(items.count)"

            do {
                let output = try await runYTDLP(for: items[index])
                items[index].status = .finished
                items[index].log = output
            } catch {
                items[index].status = .failed(error.localizedDescription)
                items[index].log += "\n\(error.localizedDescription)"
            }

            let hasMoreItems = position < queueIndices.count - 1
            if hasMoreItems && isRunning {
                await cooldownBeforeNextDownload()
            }
        }

        globalMessage = "Batch complete"
    }

    private func runYTDLP(for item: DownloadItem) async throws -> String {
        try await runner.run(
            executablePath: ytDLPPath,
            arguments: arguments(for: item)
        )
    }

    private func cooldownBeforeNextDownload() async {
        let seconds = UInt64.random(in: Self.minimumCooldownSeconds...Self.maximumCooldownSeconds)
        globalMessage = "Cooling down for \(seconds)s to reduce rate-limit risk"

        do {
            try await Task.sleep(for: .seconds(seconds))
        } catch {
            globalMessage = "Cooldown interrupted"
        }
    }
}

actor DownloadRunner {
    private var activeProcess: Process?

    func cancel() {
        activeProcess?.terminate()
        activeProcess = nil
    }

    func run(executablePath: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        activeProcess = process

        try process.run()
        process.waitUntilExit()
        activeProcess = nil

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw DownloadError.processFailed(output.trimmedFallback("yt-dlp exited with status \(process.terminationStatus)"))
        }

        return output.trimmedFallback("Download completed")
    }
}

private extension DownloaderStore {
    func arguments(for item: DownloadItem) -> [String] {
        let outputTemplate = selectedFolder
            .appendingPathComponent("%(title).180B [%(id)s].%(ext)s")
            .path

        var args = [
            "--ffmpeg-location", ffmpegPath,
            "--no-playlist",
            "--newline",
            "--restrict-filenames",
            "--sleep-requests", "1.5",
            "--sleep-interval", "8",
            "--max-sleep-interval", "18",
            "--retry-sleep", "http:exp=5:60",
            "--retry-sleep", "fragment:exp=2:20",
            "-o", outputTemplate
        ]

        switch item.kind {
        case .video:
            args += [
                "-f", "bv*[vcodec^=avc1][ext=mp4]+ba[ext=m4a]/b[vcodec^=avc1][ext=mp4]/bv*+ba/b",
                "-S", "vcodec:h264,ext:mp4:m4a",
                "--merge-output-format", "mp4",
                "--recode-video", "mp4",
                "--exec", "after_move:/bin/sh -c 'file=\"$1\"; codec=\"$(/opt/homebrew/bin/ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 \"$file\")\"; if [ \"$codec\" = \"h264\" ]; then exit 0; fi; tmp=\"${file%.*}.h264.mp4\"; /opt/homebrew/bin/ffmpeg -y -i \"$file\" -map 0:v:0 -map 0:a? -c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -movflags +faststart \"$tmp\" && mv \"$tmp\" \"$file\"' sh {}"
            ]
        case .audio:
            args += [
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "320K"
            ]
        }

        args.append(item.url)
        return args
    }
}

enum DownloadError: LocalizedError {
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .processFailed(let message): message
        }
    }
}

private extension String {
    func trimmedFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
