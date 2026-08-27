import SwiftUI
import UsageDashCore

struct ConfigEditorView: View {
    @ObservedObject var model: ConfigEditorModel
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let error = model.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            defaultIntervalRow
            providerList
            addButtons
        }
        .frame(minWidth: 680, minHeight: 560)
    }

    private var header: some View {
        HStack {
            Text("配置").font(.headline)
            Spacer()
            Button("取消", action: onCancel)
            Button("保存", action: onSave)
                .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    private var defaultIntervalRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("默认刷新间隔").font(.caption).foregroundStyle(.secondary)
            TextField("600", value: $model.defaultIntervalSec, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            Text("秒").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var providerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(model.providers.indices, id: \.self) { index in
                    ProviderFormView(
                        provider: $model.providers[index],
                        model: model,
                        onDelete: { model.removeProvider(at: index) }
                    )
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var addButtons: some View {
        HStack(spacing: 8) {
            Text("添加：")
            Button("Kimi") { model.addProvider(type: .kimi) }
            Button("MiniMax") { model.addProvider(type: .minimax) }
            Button("DeepSeek") { model.addProvider(type: .deepseek) }
            Button("自定义") { model.addProvider(type: .custom) }
            Spacer()
        }
        .padding(12)
    }
}
