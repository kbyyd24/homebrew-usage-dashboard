import SwiftUI
import UsageDashCore

struct ProviderFormView: View {
    @Binding var provider: ConfigEditorModel.EditableProvider
    @ObservedObject var model: ConfigEditorModel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("id", text: $provider.id)
                    .frame(width: 120)
                Picker("", selection: $provider.type) {
                    Text("Kimi").tag(ProviderType.kimi)
                    Text("MiniMax").tag(ProviderType.minimax)
                    Text("自定义").tag(ProviderType.custom)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("删除该订阅")
            }

            TextField("名称", text: $provider.name)

            HStack {
                TextField("密钥字面量", text: $provider.apiKeyLiteral)
                Text("或")
                TextField("环境变量名", text: $provider.apiKeyEnvName)
            }

            HStack {
                Text("刷新间隔（秒，留空用默认）").font(.caption).foregroundStyle(.secondary)
                TextField("", text: refreshIntervalBinding)
                    .frame(width: 70)
                Spacer()
            }

            if provider.isCustom {
                TextField("请求 URL", text: $provider.url)
                TextField("方法", text: $provider.method)
                    .frame(width: 120)
                fieldLabel("Headers（每行 key: value）")
                TextEditor(text: $provider.headersText)
                    .frame(height: 56)
                    .font(.system(.caption, design: .monospaced))
                fieldLabel("Body（可选）")
                TextEditor(text: $provider.body)
                    .frame(height: 40)
                    .font(.system(.caption, design: .monospaced))
                fieldLabel("Extractor（JavaScript）")
                TextEditor(text: $provider.extractor)
                    .frame(height: 160)
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Button("测试连接") {
                    Task { await model.testConnection(for: provider.id) }
                }
                if let snapshot = model.testSnapshots[provider.id] {
                    testResultView(snapshot)
                }
            }
        }
        .padding(8)
    }

    private var refreshIntervalBinding: Binding<String> {
        Binding(
            get: { provider.refreshIntervalSec.map(String.init) ?? "" },
            set: { newValue in
                provider.refreshIntervalSec = Int(newValue.trimmingCharacters(in: .whitespaces))
            }
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func testResultView(_ snapshot: UsageSnapshot) -> some View {
        switch snapshot.status {
        case .ok:
            Text("✓ 解析出 \(snapshot.rows.count) 行").font(.caption).foregroundStyle(.green)
        case .error:
            Text("✗ \(snapshot.message ?? "失败")").font(.caption).foregroundStyle(.red)
        case .idle:
            Text("…").font(.caption).foregroundStyle(.secondary)
        }
    }
}
