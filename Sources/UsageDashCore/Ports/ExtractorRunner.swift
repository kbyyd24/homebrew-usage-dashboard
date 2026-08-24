import Foundation

public struct ExtractorOutput: Sendable {
    public let status: String
    public let message: String
    public let rows: [UsageRow]

    public init(status: String = "ok", message: String = "", rows: [UsageRow] = []) {
        self.status = status
        self.message = message
        self.rows = rows
    }
}

public protocol ExtractorRunner: Sendable {
    func run(source: String, responseJSON: String) throws -> ExtractorOutput
}
