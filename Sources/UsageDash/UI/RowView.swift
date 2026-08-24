import SwiftUI
import UsageDashCore

struct RowView: View {
    let row: DashboardViewModel.RowDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(row.label)
                    .font(.subheadline)
                Spacer()
                Text(primaryText)
                    .font(.subheadline.monospacedDigit())
            }

            if let progress = row.progress {
                ProgressView(value: progress)
            }

            if let reset = row.resetText {
                Text("重置 \(reset)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
