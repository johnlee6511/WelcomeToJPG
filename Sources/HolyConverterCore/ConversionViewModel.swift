import Foundation
import Combine

@MainActor
public final class ConversionViewModel: ObservableObject {
    @Published public private(set) var queuedImages: [QueuedImage]
    @Published public private(set) var outputFolderURL: URL?
    @Published public private(set) var summary: ConversionSummary
    @Published public private(set) var isConverting: Bool
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var compressionQuality: Double
    public var canConvert: Bool {
        !queuedImages.isEmpty && outputFolderURL != nil && !isConverting
    }
    private let service: ImageConversionService

    public init(
        service: ImageConversionService = ImageConversionService(),
        queuedImages: [QueuedImage] = [],
        outputFolderURL: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
        summary: ConversionSummary = ConversionSummary(),
        isConverting: Bool = false,
        statusMessage: String? = nil,
        compressionQuality: Double = 0.75
    ) {
        self.service = service
        self.queuedImages = queuedImages
        self.outputFolderURL = outputFolderURL
        self.summary = summary
        self.isConverting = isConverting
        self.statusMessage = statusMessage
        self.compressionQuality = compressionQuality
    }

    @discardableResult
    public func addFiles(_ urls: [URL]) -> Int {
        let existingPaths = Set(queuedImages.map { $0.sourceURL.standardizedFileURL.path })
        let acceptedURLs = urls.filter(ImageFileInspector.isSupportedImageFile(at:))
            .filter { !existingPaths.contains($0.standardizedFileURL.path) }

        queuedImages.append(contentsOf: acceptedURLs.map { url in
            QueuedImage(
                sourceURL: url,
                sourceFileSize: fileSize(at: url)
            )
        })

        let ignoredCount = urls.count - acceptedURLs.count
        if ignoredCount > 0 {
            statusMessage = "\(ignoredCount)개 항목은 폴더이거나 지원되지 않아 제외했습니다."
        } else if !acceptedURLs.isEmpty {
            statusMessage = "\(acceptedURLs.count)개 이미지를 추가했습니다."
        }

        return acceptedURLs.count
    }

    public func setOutputFolder(_ url: URL?) {
        outputFolderURL = url
        statusMessage = url == nil ? nil : "저장 폴더를 설정했습니다."
    }

    public func applyResults(_ results: [ConversionResult]) {
        let resultMap = Dictionary(uniqueKeysWithValues: results.map { ($0.sourceURL.standardizedFileURL, $0) })

        queuedImages = queuedImages.map { item in
            guard let result = resultMap[item.sourceURL.standardizedFileURL] else {
                return item
            }

            if let outputURL = result.outputURL {
                return QueuedImage(
                    id: item.id,
                    sourceURL: item.sourceURL,
                    sourceFileSize: result.sourceFileSize ?? item.sourceFileSize,
                    outputFileSize: result.outputFileSize,
                    status: .success(outputURL: outputURL)
                )
            }

            return QueuedImage(
                id: item.id,
                sourceURL: item.sourceURL,
                sourceFileSize: result.sourceFileSize ?? item.sourceFileSize,
                outputFileSize: result.outputFileSize,
                status: .failure(message: result.errorMessage ?? "변환에 실패했습니다.")
            )
        }

        let succeeded = results.filter { $0.outputURL != nil }.count
        let failed = results.count - succeeded
        summary = ConversionSummary(total: results.count, succeeded: succeeded, failed: failed)
        statusMessage = failed == 0
            ? "\(succeeded)개 파일을 JPG로 저장했습니다."
            : "\(succeeded)개 성공, \(failed)개 실패했습니다."
    }

    public func clearQueue() {
        queuedImages.removeAll()
        summary = ConversionSummary()
        statusMessage = nil
    }

    public func setCompressionQuality(_ value: Double) {
        compressionQuality = min(max(value, 0.1), 1.0)
        statusMessage = "JPG 압축 품질을 \(Int(compressionQuality * 100))%로 설정했습니다."
    }

    public func convertAll() async {
        guard let outputFolderURL, !queuedImages.isEmpty, !isConverting else {
            return
        }

        isConverting = true
        summary = ConversionSummary(total: queuedImages.count, succeeded: 0, failed: 0)
        queuedImages = queuedImages.map {
            QueuedImage(
                id: $0.id,
                sourceURL: $0.sourceURL,
                sourceFileSize: $0.sourceFileSize,
                outputFileSize: nil,
                status: .queued
            )
        }
        let inputURLs = queuedImages.map(\.sourceURL)
        let results = await service.convert(
            urls: inputURLs,
            to: outputFolderURL,
            compressionQuality: compressionQuality
        )
        applyResults(results)
        isConverting = false
    }

    private func fileSize(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }
}
