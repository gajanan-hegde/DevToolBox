import SwiftUI
import AppKit

struct CommandPalette: View {
    @Bindable var appState: AppState

    @State private var searchText = ""
    @State private var filteredTools: [Tool] = Tool.allCases
    @State private var highlightedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { appState.showingPalette = false }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search tools...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($searchFocused)
                        .onSubmit { selectHighlighted() }
                        .onKeyPress(.upArrow) {
                            if highlightedIndex > 0 { highlightedIndex -= 1 }
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            if highlightedIndex < filteredTools.count - 1 { highlightedIndex += 1 }
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            appState.showingPalette = false
                            return .handled
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()

                VStack(spacing: 0) {
                    ForEach(Array(filteredTools.enumerated()), id: \.element.id) { index, tool in
                        Button(action: { select(tool) }) {
                            HStack(spacing: 10) {
                                Image(systemName: tool.icon)
                                    .frame(width: 18, alignment: .center)
                                    .foregroundStyle(index == highlightedIndex ? Color.accentColor : .secondary)
                                Text(tool.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(index == highlightedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if filteredTools.isEmpty {
                        Text("No tools match \"\(searchText)\"")
                            .foregroundStyle(.secondary)
                            .padding(14)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(width: 440)
            .shadow(radius: 24, x: 0, y: 8)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            if let idx = filteredTools.firstIndex(of: appState.selectedTool) {
                highlightedIndex = idx
            }
            NSApp.keyWindow?.makeFirstResponder(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
        .onChange(of: searchText) { _, newValue in
            filteredTools = newValue.isEmpty
                ? Tool.allCases
                : Tool.allCases.filter { $0.name.localizedCaseInsensitiveContains(newValue) }
            highlightedIndex = 0
        }
    }

    private func selectHighlighted() {
        guard !filteredTools.isEmpty, highlightedIndex < filteredTools.count else { return }
        select(filteredTools[highlightedIndex])
    }

    private func select(_ tool: Tool) {
        appState.selectedTool = tool
        appState.showingPalette = false
    }
}
