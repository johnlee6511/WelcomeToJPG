import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

public actor ImageConversionService {
    public enum ConversionError: LocalizedError {
        case unsupportedInput
        case decodeFailed
        case encodeFailed
        case invalidOutputFolder

        public var errorDescription: String? {
            switch self {
            case .unsupportedInput:
                return "지원하지 않는 이미지 형식입니다."
            case .decodeFailed:
                return "이미지를 읽을 수 없습니다."
            case .encodeFailed:
                return "JPG로 저장하지 못했습니다."
            case .invalidOutputFolder:
                return "저장 폴더를 찾을 수 없습니다."
            }
        }
    }

    private let fileManager: FileManager

    public init(
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
    }

    public func convert(
        urls: [URL],
        to outputFolderURL: URL,
        compressionQuality: Double = 0.75
    ) async -> [ConversionResult] {
        urls.map { url in
            let sourceFileSize = fileSize(at: url)
            do {
                let outputURL = try convertSingle(
                    url: url,
                    to: outputFolderURL,
                    compressionQuality: compressionQuality
                )
                return ConversionResult(
                    sourceURL: url,
                    outputURL: outputURL,
                    errorMessage: nil,
                    sourceFileSize: sourceFileSize,
                    outputFileSize: fileSize(at: outputURL)
                )
            } catch {
                return ConversionResult(
                    sourceURL: url,
                    outputURL: nil,
                    errorMessage: error.localizedDescription,
                    sourceFileSize: sourceFileSize,
                    outputFileSize: nil
                )
            }
        }
    }

    public func suggestedOutputURL(
        for sourceURL: URL,
        in outputFolderURL: URL
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent.isEmpty
            ? "converted-image"
            : sourceURL.deletingPathExtension().lastPathComponent

        var candidate = outputFolderURL
            .appendingPathComponent(baseName)
            .appendingPathExtension("jpg")
        var index = 1

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = outputFolderURL
                .appendingPathComponent("\(baseName)-\(index)")
                .appendingPathExtension("jpg")
            index += 1
        }

        return candidate
    }

    private func convertSingle(
        url: URL,
        to outputFolderURL: URL,
        compressionQuality: Double
    ) throws -> URL {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: outputFolderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ConversionError.invalidOutputFolder
        }

        guard ImageFileInspector.isSupportedImageFile(at: url) else {
            throw ConversionError.unsupportedInput
        }

        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ConversionError.decodeFailed
        }

        let flattenedImage = try flattenIfNeeded(image)
        let outputURL = suggestedOutputURL(for: url, in: outputFolderURL)
        try writeJPEG(flattenedImage, to: outputURL, compressionQuality: compressionQuality)
        return outputURL
    }

    private func flattenIfNeeded(_ image: CGImage) throws -> CGImage {
        guard image.alphaInfo.containsAlpha else {
            return image
        }

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw ConversionError.encodeFailed
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard let flattened = context.makeImage() else {
            throw ConversionError.encodeFailed
        }

        return flattened
    }

    private func writeJPEG(
        _ image: CGImage,
        to outputURL: URL,
        compressionQuality: Double
    ) throws {
        let destinationData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                destinationData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            throw ConversionError.encodeFailed
        }

        let properties: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: min(max(compressionQuality, 0.1), 1.0),
        ] as CFDictionary

        CGImageDestinationAddImage(destination, image, properties)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.encodeFailed
        }

        try destinationData.write(to: outputURL, options: .atomic)
    }

    private func fileSize(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }
}

public enum ImageFileInspector {
    public static func isSupportedImageFile(at url: URL) -> Bool {
        guard !url.hasDirectoryPath else {
            return false
        }

        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        if values?.isDirectory == true {
            return false
        }

        if let contentType = values?.contentType ?? inferredType(for: url) {
            guard contentType.conforms(to: .image) else {
                return false
            }
        }

        return CGImageSourceCreateWithURL(url as CFURL, nil) != nil
    }

    private static func inferredType(for url: URL) -> UTType? {
        UTType(filenameExtension: url.pathExtension)
    }
}

private extension CGImageAlphaInfo {
    var containsAlpha: Bool {
        switch self {
        case .alphaOnly, .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        @unknown default:
            return true
        }
    }
}
