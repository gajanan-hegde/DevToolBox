//
//  DevToolboxApp.swift
//  DevToolbox
//
//  Created by Gajanan Hegde on 01.03.26.
//

import SwiftUI
import AppIntents

@main
struct DevToolboxApp: App {
    @State private var appState = AppState.shared
    @Environment(\.openWindow) private var openWindow

    init() {
        DevToolboxShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .commands {
            CommandMenu("Tools") {
                Button("Command Palette") {
                    appState.showingPalette = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        WindowGroup(id: "incoming", for: IncomingContent.self) { $content in
            if let content {
                IncomingWindowView(content: content)
            }
        }
        .defaultSize(width: 480, height: 420)
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "devtoolbox",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let input = components.queryItems?.first(where: { $0.name == "input" })?.value,
              !input.isEmpty else { return }

        // Allow explicit tool override from per-tool intents
        let toolParam = components.queryItems?.first(where: { $0.name == "tool" })?.value
        let candidates: [Tool]
        if let param = toolParam, let tool = Tool.fromURLParam(param) {
            candidates = [tool]
        } else {
            candidates = ContentDetector.detect(input)
        }

        if candidates.count == 1 {
            // Unambiguous: route directly, regardless of warm/cold launch
            let tool = candidates[0]
            appState.selectedTool = tool
            appState.pendingInput = PendingInput(tool: tool, content: input)
        } else {
            // Ambiguous: open picker window
            let incoming = IncomingContent(id: UUID(), content: input, candidates: candidates)
            openWindow(id: "incoming", value: incoming)
        }
    }
}
