import AppKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers
import WelcomeToJPGCore

struct ContentView: View {
    @StateObject private var viewModel = ConversionViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            inputSection
            outputSection
            settingsSection
            runSection
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WelcomeToJPG")
                .font(.system(size: 28, weight: .bold))
            Text("HEIC, PNG, JPEG 등 여러 이미지를 한 번에 JPG로 변환해서 원하는 폴더에 저장합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("1. 이미지 추가")
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )

                if viewModel.queuedImages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.accentColor)
                        Text("이미지를 여기로 드래그하세요")
                            .font(.headline)
                        Text("또는 파일 선택으로 여러 장을 추가할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("이미지 선택", action: chooseImages)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(28)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("선택된 이미지 \(viewModel.queuedImages.count)개")
                                .font(.headline)
                            Spacer()
                            Button("이미지 추가", action: chooseImages)
                                .buttonStyle(.borderedProminent)
                        }

                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(viewModel.queuedImages) { item in
                                    dropZonePreviewCard(for: item)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        Text("이 영역에 더 드래그하면 계속 추가됩니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                }
            }
            .frame(height: viewModel.queuedImages.isEmpty ? 180 : 230)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop(providers:))

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("2. 저장 폴더")
            HStack(spacing: 12) {
                Button("저장 폴더 선택", action: chooseOutputFolder)
                    .buttonStyle(.bordered)

                Text(viewModel.outputFolderURL?.path ?? "Downloads")
                    .font(.callout)
                    .foregroundStyle(viewModel.outputFolderURL == nil ? .secondary : .primary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("3. JPG 압축 설정")
            HStack(spacing: 14) {
                Text("품질")
                    .font(.callout.weight(.medium))
                Slider(
                    value: Binding(
                        get: { viewModel.compressionQuality },
                        set: { viewModel.setCompressionQuality($0) }
                    ),
                    in: 0.3...1.0,
                    step: 0.05
                )
                Text("\(Int(viewModel.compressionQuality * 100))%")
                    .font(.callout.monospacedDigit())
                    .frame(width: 52, alignment: .trailing)
            }

            Text(compressionHelpText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var runSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("4. 변환 실행")
            HStack(spacing: 12) {
                Button(viewModel.isConverting ? "변환 중..." : "변환 시작") {
                    Task {
                        await viewModel.convertAll()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canConvert)

                Button("목록 비우기") {
                    viewModel.clearQueue()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.queuedImages.isEmpty || viewModel.isConverting)
            }

            ProgressView(value: progressValue, total: progressTotal)
                .controlSize(.large)

            Text(summaryText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var progressTotal: Double {
        max(Double(max(viewModel.summary.total, viewModel.queuedImages.count)), 1)
    }

    private var progressValue: Double {
        if viewModel.isConverting, viewModel.summary.total == 0 {
            return 0
        }

        return Double(viewModel.summary.processed)
    }

    private var summaryText: String {
        if viewModel.summary.total == 0 {
            return "변환할 파일 \(viewModel.queuedImages.count)개가 준비되어 있습니다. 기본 저장 폴더는 Downloads이고 현재 품질은 \(Int(viewModel.compressionQuality * 100))%입니다."
        }

        return "총 \(viewModel.summary.total)개 중 \(viewModel.summary.succeeded)개 성공, \(viewModel.summary.failed)개 실패"
    }

    private var compressionHelpText: String {
        "HEIC는 JPEG보다 압축 효율이 높아서, 품질을 높게 두면 JPG가 더 커질 수 있습니다. 일반적으로 60%~80%가 용량과 화질 균형이 좋습니다."
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.title = "변환할 이미지 선택"
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        guard panel.runModal() == .OK else {
            return
        }

        _ = viewModel.addFiles(panel.urls)
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "저장할 폴더 선택"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = viewModel.outputFolderURL

        guard panel.runModal() == .OK else {
            return
        }

        viewModel.setOutputFolder(panel.url)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let supportedProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !supportedProviders.isEmpty else {
            return false
        }

        Task {
            var urls: [URL] = []
            for provider in supportedProviders {
                if let url = await provider.loadFileURL() {
                    urls.append(url)
                }
            }

            await MainActor.run {
                _ = viewModel.addFiles(urls)
            }
        }

        return true
    }

    @ViewBuilder
    private func dropZonePreviewCard(for item: QueuedImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LocalThumbnailView(url: item.sourceURL)
                .frame(width: 132, height: 96)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: symbol(for: item.status))
                        .foregroundStyle(color(for: item.status))
                    Text(item.sourceURL.lastPathComponent)
                        .font(.footnote.weight(.medium))
                        .lineLimit(2)
                }

                Text(statusText(for: item.status))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(sizeText(for: item))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 148, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func symbol(for status: QueuedImage.Status) -> String {
        switch status {
        case .queued:
            return "clock"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }

    private func color(for status: QueuedImage.Status) -> Color {
        switch status {
        case .queued:
            return .secondary
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    private func statusText(for status: QueuedImage.Status) -> String {
        switch status {
        case .queued:
            return "변환 대기 중"
        case .success(let outputURL):
            return "저장됨: \(outputURL.lastPathComponent)"
        case .failure(let message):
            return message
        }
    }

    private func sizeText(for item: QueuedImage) -> String {
        let original = formattedByteCount(item.sourceFileSize)
        if let outputSize = item.outputFileSize {
            let output = formattedByteCount(outputSize)
            let ratio = compressionDeltaText(source: item.sourceFileSize, output: outputSize)
            return "원본 \(original) -> 결과 \(output)\(ratio.map { " (\($0))" } ?? "")"
        }

        return "원본 \(original)"
    }

    private func formattedByteCount(_ value: Int64?) -> String {
        guard let value else {
            return "-"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: value)
    }

    private func compressionDeltaText(source: Int64?, output: Int64) -> String? {
        guard let source, source > 0 else {
            return nil
        }

        let delta = (Double(output) / Double(source) - 1) * 100
        let prefix = delta > 0 ? "+" : ""
        return "\(prefix)\(Int(delta.rounded()))%"
    }
}

private extension NSItemProvider {
    func loadFileURL() async -> URL? {
        await withCheckedContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard
                    let data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: url)
            }
        }
    }
}

private struct LocalThumbnailView: View {
    let url: URL
    @StateObject private var loader: ThumbnailLoader

    init(url: URL) {
        self.url = url
        _loader = StateObject(wrappedValue: ThumbnailLoader(url: url))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if loader.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                    Text("미리보기를 불러올 수 없습니다.")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            await loader.load()
        }
    }
}

@MainActor
private final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading = false

    private let url: URL
    private static let cache = NSCache<NSURL, NSImage>()

    init(url: URL) {
        self.url = url
    }

    func load() async {
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        if let thumbnail = await quickLookThumbnail(for: url) ?? NSImage(contentsOf: url) {
            Self.cache.setObject(thumbnail, forKey: url as NSURL)
            image = thumbnail
        }
    }

    private func quickLookThumbnail(for url: URL) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 320, height: 240),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                if let cgImage = representation?.cgImage {
                    continuation.resume(returning: NSImage(cgImage: cgImage, size: .zero))
                    return
                }

                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }
}
