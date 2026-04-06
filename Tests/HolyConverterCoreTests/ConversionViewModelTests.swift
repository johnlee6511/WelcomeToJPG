import AppKit
import Testing
@testable import WelcomeToJPGCore

struct ConversionViewModelTests {
    @MainActor
    @Test
    func canConvertRequiresFilesAndOutputFolder() throws {
        let viewModel = ConversionViewModel()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let sourceURL = tempDirectory.appendingPathComponent("sample.png")
        try writeTransparentPNG(to: sourceURL)

        #expect(viewModel.canConvert == false)

        viewModel.addFiles([sourceURL])
        #expect(viewModel.canConvert == false)

        viewModel.setOutputFolder(URL(fileURLWithPath: "/tmp/output", isDirectory: true))
        #expect(viewModel.canConvert == true)
    }

    @MainActor
    @Test
    func applyResultsUpdatesSummaryAndStatuses() {
        let sourceOne = URL(fileURLWithPath: "/tmp/one.png")
        let sourceTwo = URL(fileURLWithPath: "/tmp/two.heic")
        let outputOne = URL(fileURLWithPath: "/tmp/output/one.jpg")
        let viewModel = ConversionViewModel(
            queuedImages: [
                QueuedImage(sourceURL: sourceOne),
                QueuedImage(sourceURL: sourceTwo),
            ]
        )

        viewModel.applyResults([
            ConversionResult(sourceURL: sourceOne, outputURL: outputOne, errorMessage: nil, sourceFileSize: 10, outputFileSize: 8),
            ConversionResult(sourceURL: sourceTwo, outputURL: nil, errorMessage: "Decode failed", sourceFileSize: 12, outputFileSize: nil),
        ])

        #expect(viewModel.summary == ConversionSummary(total: 2, succeeded: 1, failed: 1))
        #expect(viewModel.queuedImages[0].status == .success(outputURL: outputOne))
        #expect(viewModel.queuedImages[1].status == .failure(message: "Decode failed"))
        #expect(viewModel.queuedImages[0].sourceFileSize == 10)
        #expect(viewModel.queuedImages[0].outputFileSize == 8)
    }

    @MainActor
    @Test
    func defaultCompressionQualityIsMediumAndCanBeUpdated() {
        let viewModel = ConversionViewModel()

        #expect(viewModel.compressionQuality == 0.75)

        viewModel.setCompressionQuality(0.4)

        #expect(viewModel.compressionQuality == 0.4)
    }

    @MainActor
    @Test
    func defaultOutputFolderStartsAtDownloads() {
        let viewModel = ConversionViewModel()
        let expectedDownloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        #expect(viewModel.outputFolderURL == expectedDownloads)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeTransparentPNG(to url: URL) throws {
        let size = NSSize(width: 2, height: 2)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw TestError.failedToCreateImage
        }

        try pngData.write(to: url)
    }
}

private enum TestError: Error {
    case failedToCreateImage
}
