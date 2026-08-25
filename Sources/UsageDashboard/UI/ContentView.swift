import SwiftUI
import UsageDashCore

struct ContentView: View {
    let model: AppModel
    @ObservedObject var observable: StoreObservable

    var body: some View {
        Group {
            if let error = model.coordinator.configError {
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
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 360), spacing: 12)],
                spacing: 12
            ) {
                ForEach(providers) { provider in
                    ProviderCardView(provider: provider)
                }
            }
            .padding(12)
        }
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
