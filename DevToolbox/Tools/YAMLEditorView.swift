import SwiftUI

struct YAMLEditorView: View {
    @State private var model = YAMLEditorModel()

    enum ViewMode: String, CaseIterable {
        case tree = "Tree"
        case text = "Text"
    }

    @State private var viewMode: ViewMode = .text
    @State private var expandSignal = 0
    @State private var collapseSignal = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if let err = model.parseError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Line \(err.line), Col \(err.column): \(err.message)")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
            }

            Divider()

            Group {
                switch viewMode {
                case .tree:
                    EditableJSONTreeView(model: model, expandSignal: expandSignal, collapseSignal: collapseSignal)
                        .padding(8)
                case .text:
                    LineNumberedTextEditor(
                        text: Binding(
                            get: { model.text },
                            set: { newVal in
                                model.text = newVal
                                model.onTextChanged()
                            }
                        ),
                        errorLine: model.parseError?.line,
                        errorMessage: errorPopoverMessage,
                        focusOnAppear: true,
                        highlightMode: .yaml
                    )
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("YAML Editor")
        .onAppear {
            applyPendingInput()
            model.parseImmediately()
        }
        .onChange(of: AppState.shared.pendingInput) { applyPendingInput() }
    }

    private func applyPendingInput() {
        guard let pending = AppState.shared.pendingInput, pending.tool == .yamlEditor else { return }
        model.text = pending.content
        AppState.shared.pendingInput = nil
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Button("Pretty") { model.prettyPrint() }
                .buttonStyle(.bordered)
                .disabled(model.parseError != nil || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Divider().frame(height: 16)

            Button("Expand All") {
                if viewMode == .tree { expandSignal += 1 } else { model.prettyPrint() }
            }
            .buttonStyle(.bordered)
            .disabled(model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || (viewMode == .text && model.parseError != nil))

            Button("Collapse All") { collapseSignal += 1 }
                .buttonStyle(.bordered)
                .disabled(viewMode == .text
                          || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()

            statusIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Empty")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else if model.parseError != nil {
            Label("Invalid", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        } else {
            Label("Valid", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        }
    }

    private var errorPopoverMessage: String? {
        guard let err = model.parseError else { return nil }
        return "Line \(err.line), Col \(err.column): \(err.message)"
    }
}
