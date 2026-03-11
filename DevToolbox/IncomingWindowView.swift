import SwiftUI
import AppKit

struct IncomingWindowView: View {
    let content: IncomingContent

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTool: Tool

    init(content: IncomingContent) {
        self.content = content
        _selectedTool = State(initialValue: content.candidates.first ?? Tool.allCases[0])
    }

    private var preview: String {
        let s = content.content
        return s.count > 200 ? String(s.prefix(200)) + "…" : s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What would you like to do with this?")
                .font(.headline)

            // Content preview
            ScrollView {
                Text(preview)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
            .frame(height: 72)

            // Tool picker
            VStack(spacing: 0) {
                ForEach(Tool.allCases) { tool in
                    Button(action: { selectedTool = tool }) {
                        HStack(spacing: 10) {
                            Image(systemName: tool.icon)
                                .frame(width: 18, alignment: .center)
                                .foregroundStyle(selectedTool == tool ? Color.accentColor : .secondary)
                            Text(tool.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if content.candidates.first == tool {
                                Text("Best match")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTool == tool ? Color.accentColor.opacity(0.12) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor)))
            .focusable()
            .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
            .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Open in \(selectedTool.name)") { confirm() }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .onAppear {
            // Single unambiguous candidate: route immediately without showing picker
            if content.candidates.count == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    confirm()
                }
            }
        }
    }

    private func confirm() {
        AppState.shared.selectedTool = selectedTool
        AppState.shared.pendingInput = PendingInput(tool: selectedTool, content: content.content)
        NSApp.activate(ignoringOtherApps: true)
        dismiss()
    }

    private func moveSelection(by delta: Int) {
        let tools = Tool.allCases
        guard let idx = tools.firstIndex(of: selectedTool) else { return }
        selectedTool = tools[max(0, min(tools.count - 1, idx + delta))]
    }
}
