import Foundation

public enum DateParsing {
    public static func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    public static func parseMilliseconds(_ value: Double) -> Date {
        Date(timeIntervalSince1970: value / 1000.0)
    }
}
