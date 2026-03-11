//
//  ContentView.swift
//  DevToolbox
//
//  Created by Gajanan Hegde on 01.03.26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            NavigationSplitView {
                List(Tool.allCases) { tool in
                    Button(action: { appState.selectedTool = tool }) {
                        HStack(spacing: 10) {
                            Image(systemName: tool.icon)
                                .frame(width: 18, alignment: .center)
                                .foregroundStyle(appState.selectedTool == tool ? Color.accentColor : .secondary)
                            Text(tool.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(appState.selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
                .focusable()
                .onKeyPress(.upArrow) { moveSidebarSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { moveSidebarSelection(by: 1); return .handled }
            } detail: {
                switch appState.selectedTool {
                case .jwtDecoder:
                    JWTDecoderView()
                case .jsonEditor:
                    JSONEditorView()
                case .jsonDiff:
                    JSONDiffView()
                case .yamlEditor:
                    YAMLEditorView()
                case .jsonYamlConverter:
                    JSONYAMLConverterView()
                case .urlEncoder:
                    URLEncoderView()
                case .base64Encoder:
                    Base64EncoderView()
                case .epochConverter:
                    EpochConverterView()
                }
            }

            if appState.showingPalette {
                CommandPalette(appState: appState)
            }
        }
        .onAppear { appState.hasLaunched = true }
    }

    private func moveSidebarSelection(by delta: Int) {
        let tools = Tool.allCases
        guard let currentIndex = tools.firstIndex(of: appState.selectedTool) else { return }
        let newIndex = max(0, min(tools.count - 1, currentIndex + delta))
        appState.selectedTool = tools[newIndex]
    }
}

#Preview {
    ContentView(appState: AppState())
}
