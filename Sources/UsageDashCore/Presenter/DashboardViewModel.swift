import Foundation

public struct DashboardViewModel: Sendable {
    public struct ProviderDisplay: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let status: ProviderStatus
        public let errorMessage: String?
        public let fetchedAtText: String?
        public let rows: [RowDisplay]

        public init(
            id: String,
            name: String,
            status: ProviderStatus,
            errorMessage: String?,
            fetchedAtText: String?,
            rows: [RowDisplay]
        ) {
            self.id = id
            self.name = name
            self.status = status
            self.errorMessage = errorMessage
            self.fetchedAtText = fetchedAtText
            self.rows = rows
        }
    }

    public struct RowDisplay: Identifiable, Equatable, Sendable {
        public let id: String
        public let label: String
        public let usedText: String?
        public let capText: String?
        public let percentText: String?
        public let balanceText: String?
        public let unit: String?
        public let resetText: String?
        public let progress: Double?

        public init(
            id: String,
            label: String,
            usedText: String? = nil,
            capText: String? = nil,
            percentText: String? = nil,
            balanceText: String? = nil,
            unit: String? = nil,
            resetText: String? = nil,
            progress: Double? = nil
        ) {
            self.id = id
            self.label = label
            self.usedText = usedText
            self.capText = capText
            self.percentText = percentText
            self.balanceText = balanceText
            self.unit = unit
            self.resetText = resetText
            self.progress = progress
        }
    }

    private let configs: [ProviderConfig]
    private let store: SnapshotStore
    private let timeZone: TimeZone

    public init(configs: [ProviderConfig], store: SnapshotStore, timeZone: TimeZone = .current) {
        self.configs = configs
        self.store = store
        self.timeZone = timeZone
    }

    public func display() -> [ProviderDisplay] {
        configs.map { config in
            let snapshot = store.snapshot(forId: config.id)
            return makeDisplay(config: config, snapshot: snapshot)
        }
    }

    private func makeDisplay(config: ProviderConfig, snapshot: UsageSnapshot?) -> ProviderDisplay {
        let status = snapshot?.status ?? .idle
        return ProviderDisplay(
            id: config.id,
            name: config.name,
            status: status,
            errorMessage: status == .error ? snapshot?.message : nil,
            fetchedAtText: snapshot?.fetchedAt.map { Formatting.clock($0, timeZone: timeZone) },
            rows: (snapshot?.rows ?? []).map { rowDisplay($0) }
        )
    }

    private func rowDisplay(_ row: UsageRow) -> RowDisplay {
        switch row.kind {
        case .window:
            let used = row.used ?? 0
            let cap = row.cap ?? 0
            let progress = cap > 0 ? min(max(used / cap, 0), 1) : nil
            return RowDisplay(
                id: row.id,
                label: row.label,
                usedText: Formatting.number(used),
                capText: Formatting.number(cap),
                percentText: Formatting.percent(used: used, cap: cap),
                resetText: row.resetAt.map { Formatting.time($0, timeZone: timeZone) },
                progress: progress
            )
        case .balance:
            let balance = row.balance ?? 0
            return RowDisplay(
                id: row.id,
                label: row.label,
                balanceText: Formatting.number(balance),
                unit: row.unit
            )
        }
    }
}

enum Formatting {
    static func number(_ value: Double) -> String {
        value.formatted(
            .number
            .precision(.fractionLength(0...2))
            .locale(Locale(identifier: "en_US_POSIX"))
        )
    }

    static func percent(used: Double, cap: Double) -> String {
        guard cap > 0 else { return "0%" }
        return "\(Int(((used / cap) * 100).rounded()))%"
    }

    static func time(_ date: Date, timeZone: TimeZone) -> String {
        let parts = components(date, timeZone: timeZone, units: [.year, .month, .day, .hour, .minute])
        return String(format: "%04d-%02d-%02d %02d:%02d", parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!)
    }

    static func clock(_ date: Date, timeZone: TimeZone) -> String {
        let parts = components(date, timeZone: timeZone, units: [.hour, .minute, .second])
        return String(format: "%02d:%02d:%02d", parts.hour!, parts.minute!, parts.second!)
    }

    private static func components(_ date: Date, timeZone: TimeZone, units: Set<Calendar.Component>) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents(units, from: date)
    }
}
