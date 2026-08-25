import SwiftUI
import UsageDashCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var observable: StoreObservable

    var body: some View {
        Group {
            if let error = model.configError {
                errorView(error)
            } else {
                dashboardView
            }
        }
        .frame(minWidth: 520, minHeight: 400)
        .task { await model.start() }
    }

    private var dashboardView: some View {
        let providers = model.dashboard.display()
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !model.configWarnings.isEmpty {
                    warningBanner
                }
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 360), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(providers) { provider in
                        ProviderCardView(provider: provider)
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(model.configWarnings, id: \.self) { warning in
                Text("⚠ \(warning)")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3)))
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("配置错误", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
