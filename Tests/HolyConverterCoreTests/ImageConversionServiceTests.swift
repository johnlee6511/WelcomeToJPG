import AppKit
import Testing
@testable import WelcomeToJPGCore

struct ImageConversionServiceTests {
    @Test
    func suggestedOutputURLAppendsIncrementingSuffixWhenNameExists() async throws {
        let service = ImageConversionService()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sourceURL = tempDirectory.appendingPathComponent("sample.png")
        _ = FileManager.default.createFile(atPath: sourceURL.path, contents: Data())

        let existingOutput = tempDirectory.appendingPathComponent("sample.jpg")
        _ = FileManager.default.createFile(atPath: existingOutput.path, contents: Data())

        let suggested = await service.suggestedOutputURL(for: sourceURL, in: tempDirectory)

        #expect(suggested.lastPathComponent == "sample-1.jpg")
    }

    @Test
    func convertFlattensTransparentPixelsToWhiteJPEG() async throws {
        let service = ImageConversionService()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sourceURL = tempDirectory.appendingPathComponent("alpha.png")
        try writeTransparentPNG(to: sourceURL)

        let results = await service.convert(urls: [sourceURL], to: tempDirectory)

        #expect(results.count == 1)
        #expect(results[0].errorMessage == nil)
        let outputURL = try #require(results[0].outputURL)
        #expect(outputURL.pathExtension.lowercased() == "jpg")

        let pixel = try readPixel(atX: 0, y: 0, from: outputURL)
        #expect(Int(pixel.red) >= 240)
        #expect(Int(pixel.green) >= 240)
        #expect(Int(pixel.blue) >= 240)
    }

    @Test
    func convertContinuesAfterCorruptedFileFailure() async throws {
        let service = ImageConversionService()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let goodURL = tempDirectory.appendingPathComponent("good.png")
        try writeTransparentPNG(to: goodURL)

        let badURL = tempDirectory.appendingPathComponent("broken.heic")
        try Data("not-an-image".utf8).write(to: badURL)

        let results = await service.convert(urls: [goodURL, badURL], to: tempDirectory)

        #expect(results.count == 2)
        #expect(results.first(where: { $0.sourceURL == goodURL })?.outputURL != nil)
        #expect(results.first(where: { $0.sourceURL == badURL })?.errorMessage != nil)
    }

    @Test
    func lowerJPEGQualityProducesSmallerFileThanHigherQuality() async throws {
        let service = ImageConversionService()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sourceURL = tempDirectory.appendingPathComponent("pattern.png")
        try writeDetailedPNG(to: sourceURL)

        let highQualityDirectory = tempDirectory.appendingPathComponent("high", isDirectory: true)
        let lowQualityDirectory = tempDirectory.appendingPathComponent("low", isDirectory: true)
        try FileManager.default.createDirectory(at: highQualityDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: lowQualityDirectory, withIntermediateDirectories: true)

        let highResult = try #require(await service.convert(urls: [sourceURL], to: highQualityDirectory, compressionQuality: 0.95).first)
        let lowResult = try #require(await service.convert(urls: [sourceURL], to: lowQualityDirectory, compressionQuality: 0.45).first)

        let highSize = try #require(highResult.outputFileSize)
        let lowSize = try #require(lowResult.outputFileSize)

        #expect(lowSize < highSize)
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
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: 1, y: 1, width: 1, height: 1)).fill()
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

    private func writeDetailedPNG(to url: URL) throws {
        let width = 240
        let height = 180
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw TestError.failedToCreateImage
        }

        for y in 0..<height {
            for x in 0..<width {
                let red = CGFloat((x * 13 + y * 7) % 255) / 255
                let green = CGFloat((x * 5 + y * 11) % 255) / 255
                let blue = CGFloat((x * 17 + y * 3) % 255) / 255
                context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        guard
            let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw TestError.failedToCreateImage
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestError.failedToCreateImage
        }
    }

    private func readPixel(atX x: Int, y: Int, from url: URL) throws -> (red: UInt8, green: UInt8, blue: UInt8) {
        guard
            let image = NSImage(contentsOf: url),
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            throw TestError.failedToReadImage
        }

        guard let color = bitmap.colorAt(x: x, y: y) else {
            throw TestError.failedToReadPixel
        }

        let converted = color.usingColorSpace(.sRGB) ?? color
        return (
            red: UInt8((converted.redComponent * 255).rounded()),
            green: UInt8((converted.greenComponent * 255).rounded()),
            blue: UInt8((converted.blueComponent * 255).rounded())
        )
    }
}

private enum TestError: Error {
    case failedToCreateImage
    case failedToReadImage
    case failedToReadPixel
}
