import Foundation

public enum RowKind: String, Hashable, Sendable {
    case window
    case balance
}

public struct UsageRow: Hashable, Sendable, Identifiable {
    public let kind: RowKind
    public let label: String
    public let used: Double?
    public let cap: Double?
    public let balance: Double?
    public let unit: String?
    public let resetAt: Date?

    public var id: String { "\(kind.rawValue):\(label)" }

    public init(
        kind: RowKind,
        label: String,
        used: Double? = nil,
        cap: Double? = nil,
        balance: Double? = nil,
        unit: String? = nil,
        resetAt: Date? = nil
    ) {
        self.kind = kind
        self.label = label
        self.used = used
        self.cap = cap
        self.balance = balance
        self.unit = unit
        self.resetAt = resetAt
    }

    public var isValid: Bool {
        switch kind {
        case .window: return !label.isEmpty && used != nil && cap != nil
        case .balance: return !label.isEmpty && balance != nil
        }
    }
}

public enum ProviderStatus: String, Hashable, Sendable {
    case idle
    case ok
    case error
}

public struct UsageSnapshot: Hashable, Sendable {
    public let providerId: String
    public let status: ProviderStatus
    public let rows: [UsageRow]
    public let fetchedAt: Date?
    public let message: String?

    public init(
        providerId: String,
        status: ProviderStatus,
        rows: [UsageRow] = [],
        fetchedAt: Date? = nil,
        message: String? = nil
    ) {
        self.providerId = providerId
        self.status = status
        self.rows = rows
        self.fetchedAt = fetchedAt
        self.message = message
    }

    public static func ok(providerId: String, rows: [UsageRow], fetchedAt: Date = Date()) -> UsageSnapshot {
        UsageSnapshot(providerId: providerId, status: .ok, rows: rows, fetchedAt: fetchedAt, message: nil)
    }

    public static func error(providerId: String, message: String) -> UsageSnapshot {
        UsageSnapshot(providerId: providerId, status: .error, rows: [], fetchedAt: nil, message: message)
    }

    public func markingError(_ message: String) -> UsageSnapshot {
        UsageSnapshot(providerId: providerId, status: .error, rows: rows, fetchedAt: fetchedAt, message: message)
    }
}
