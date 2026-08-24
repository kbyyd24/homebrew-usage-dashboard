import SwiftUI
import UsageDashCore

struct ProviderCardView: View {
    let provider: DashboardViewModel.ProviderDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.name)
                    .font(.headline)
                Spacer()
                statusBadge
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

            if let fetched = provider.fetchedAtText {
                Text("更新于 \(fetched)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25)))
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
