import Foundation

public struct QueuedImage: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case queued
        case success(outputURL: URL)
        case failure(message: String)
    }

    public let id: UUID
    public let sourceURL: URL
    public var sourceFileSize: Int64?
    public var outputFileSize: Int64?
    public var status: Status

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourceFileSize: Int64? = nil,
        outputFileSize: Int64? = nil,
        status: Status = .queued
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceFileSize = sourceFileSize
        self.outputFileSize = outputFileSize
        self.status = status
    }
}

public struct ConversionSummary: Equatable, Sendable {
    public var total: Int
    public var succeeded: Int
    public var failed: Int

    public init(total: Int = 0, succeeded: Int = 0, failed: Int = 0) {
        self.total = total
        self.succeeded = succeeded
        self.failed = failed
    }

    public var processed: Int {
        succeeded + failed
    }
}

public struct ConversionResult: Equatable, Sendable {
    public let sourceURL: URL
    public let outputURL: URL?
    public let errorMessage: String?
    public let sourceFileSize: Int64?
    public let outputFileSize: Int64?

    public init(
        sourceURL: URL,
        outputURL: URL?,
        errorMessage: String?,
        sourceFileSize: Int64? = nil,
        outputFileSize: Int64? = nil
    ) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.errorMessage = errorMessage
        self.sourceFileSize = sourceFileSize
        self.outputFileSize = outputFileSize
    }
}
