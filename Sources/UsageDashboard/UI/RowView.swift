import SwiftUI
import UsageDashCore

struct RowView: View {
    let row: DashboardViewModel.RowDisplay

    var body: some View {
        HStack(spacing: 10) {
            Text(row.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
                .lineLimit(1)

            if let progress = row.progress {
                ProgressBar(value: progress)
                    .frame(height: 5)
            } else {
                Spacer(minLength: 8)
            }

            Text(primaryText)
                .font(.subheadline.monospacedDigit())
                .lineLimit(1)

            if let reset = row.resetText {
                Text("重置 \(reset)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.vertical, 3)
    }

    private var primaryText: String {
        if let balance = row.balanceText {
            if let unit = row.unit, !unit.isEmpty {
                return "\(balance) \(unit)"
            }
            return balance
        }
        if let used = row.usedText, let cap = row.capText {
            return "\(used) / \(cap) (\(row.percentText ?? "0%"))"
        }
        return ""
    }
}

/// Thin capsule progress bar that fills the available width.
struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(Color.accentColor)
                    .frame(width: max(3, geo.size.width * min(max(value, 0), 1)))
            }
        }
    }
}
