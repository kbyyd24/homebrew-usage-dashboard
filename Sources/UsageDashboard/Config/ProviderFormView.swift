import AppKit
import SwiftUI
import UsageDashCore

struct ProviderFormView: View {
    @Binding var provider: ConfigEditorModel.EditableProvider
    @ObservedObject var model: ConfigEditorModel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            labeledField("名称", field: { TextField("名称", text: $provider.name).textFieldStyle(.roundedBorder) })

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("密钥（字面量）").font(.caption).foregroundStyle(.secondary)
                    TextField("sk-…", text: $provider.apiKeyLiteral).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("或环境变量名").font(.caption).foregroundStyle(.secondary)
                    TextField("KIMI_API_KEY", text: $provider.apiKeyEnvName).textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 6) {
                Text("刷新间隔（秒）").font(.caption).foregroundStyle(.secondary)
                TextField("600", text: refreshIntervalBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Spacer()
            }
            .padding(.bottom, 2)

            if provider.isCustom {
                customFields
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
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ID").font(.caption).foregroundStyle(.secondary)
                TextField("id", text: $provider.id)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("类型").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $provider.type) {
                    Text("Kimi").tag(ProviderType.kimi)
                    Text("MiniMax").tag(ProviderType.minimax)
                    Text("自定义").tag(ProviderType.custom)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("删除该订阅")
        }
    }

    private var customFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("请求 URL").font(.caption).foregroundStyle(.secondary)
                    TextField("https://…", text: $provider.url).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("方法").font(.caption).foregroundStyle(.secondary)
                    TextField("GET", text: $provider.method)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
            }
            labeledField("Headers（每行 key: value）", field: {
                borderedEditor($provider.headersText, height: 60, monospaced: true)
            })
            labeledField("Body（可选）", field: {
                borderedEditor($provider.body, height: 44, monospaced: true)
            })
            HStack(alignment: .firstTextBaseline) {
                Text("Extractor（JavaScript）").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("格式化") {
                    provider.extractor = JSFormatter.format(provider.extractor)
                }
                .controlSize(.small)
                .help("重新缩进 extractor（不修改字符串/注释内容）")
            }
            CodeEditorView(text: $provider.extractor)
                .frame(height: 180)
        }
    }

    private func labeledField<Content: View>(
        _ label: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            field()
        }
    }

    private func borderedEditor(_ text: Binding<String>, height: CGFloat, monospaced: Bool) -> some View {
        TextEditor(text: text)
            .font(monospaced ? .system(.body, design: .monospaced) : .body)
            .frame(height: height)
            .padding(4)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: .separatorColor)))
    }

    private var refreshIntervalBinding: Binding<String> {
        Binding(
            get: { provider.refreshIntervalSec.map(String.init) ?? "" },
            set: { newValue in
                provider.refreshIntervalSec = Int(newValue.trimmingCharacters(in: .whitespaces))
            }
        )
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
