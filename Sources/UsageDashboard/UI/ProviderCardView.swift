import SwiftUI
import UsageDashCore

struct ProviderCardView: View {
    let provider: DashboardViewModel.ProviderDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(provider.name)
                    .font(.headline)
                Spacer()
                statusBadge
                if let fetched = provider.fetchedAtText {
                    Text("· \(fetched)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let error = provider.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            ForEach(provider.rows) { row in
                RowView(row: row)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch provider.status {
        case .ok:
            Text("正常").font(.caption).foregroundStyle(.green)
        case .error:
            Text("错误").font(.caption).foregroundStyle(.red)
        case .idle:
            Text("等待").font(.caption).foregroundStyle(.secondary)
        }
    }
}
