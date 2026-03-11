import AppIntents
import AppKit

// MARK: - Shared URL helper

private func openDevToolbox(content: String, tool: Tool? = nil) {
    guard !content.isEmpty else { return }
    var components = URLComponents()
    components.scheme = "devtoolbox"
    components.host = "open"
    var items = [URLQueryItem(name: "input", value: content)]
    if let tool { items.append(URLQueryItem(name: "tool", value: tool.urlParam)) }
    components.queryItems = items
    guard let url = components.url else { return }
    NSWorkspace.shared.open(url)
}

// MARK: - Smart Open Intent

struct SmartOpenIntent: AppIntent {
    static var title: LocalizedStringResource = "Open in DevToolbox"
    static var description = IntentDescription(
        "Detects the content type and opens it in the appropriate DevToolbox tool."
    )
    static var openAppWhenRun = true

    @Parameter(title: "Input")
    var input: String?

    func perform() async throws -> some IntentResult {
        let content = input ?? NSPasteboard.general.string(forType: .string) ?? ""
        openDevToolbox(content: content)
        return .result()
    }
}

// MARK: - Per-Tool Intents

struct OpenJWTDecoderIntent: AppIntent {
    static var title: LocalizedStringResource = "Decode JWT"
    static var description = IntentDescription("Opens the JWT Decoder with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .jwtDecoder)
        return .result()
    }
}

struct OpenJSONEditorIntent: AppIntent {
    static var title: LocalizedStringResource = "Edit JSON"
    static var description = IntentDescription("Opens the JSON Editor with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .jsonEditor)
        return .result()
    }
}

struct OpenJSONDiffIntent: AppIntent {
    static var title: LocalizedStringResource = "Diff JSON"
    static var description = IntentDescription("Opens the JSON Diff tool with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .jsonDiff)
        return .result()
    }
}

struct OpenYAMLEditorIntent: AppIntent {
    static var title: LocalizedStringResource = "Edit YAML"
    static var description = IntentDescription("Opens the YAML Editor with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .yamlEditor)
        return .result()
    }
}

struct OpenJSONYAMLConverterIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert JSON to YAML"
    static var description = IntentDescription("Opens the JSON↔YAML Converter with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .jsonYamlConverter)
        return .result()
    }
}

struct OpenURLEncoderIntent: AppIntent {
    static var title: LocalizedStringResource = "Decode URL"
    static var description = IntentDescription("Opens the URL Encoder/Decoder with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .urlEncoder)
        return .result()
    }
}

struct OpenBase64EncoderIntent: AppIntent {
    static var title: LocalizedStringResource = "Decode Base64"
    static var description = IntentDescription("Opens the Base64 Encoder/Decoder with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .base64Encoder)
        return .result()
    }
}

struct OpenEpochConverterIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert Epoch Timestamp"
    static var description = IntentDescription("Opens the Epoch Converter with clipboard content.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        openDevToolbox(content: NSPasteboard.general.string(forType: .string) ?? "", tool: .epochConverter)
        return .result()
    }
}

// MARK: - Shortcuts Provider
// Only SmartOpenIntent is registered as an App Shortcut so Spotlight always
// offers the auto-detecting action. Per-tool intents remain available in
// Shortcuts.app but do not appear as Spotlight quick actions.

struct DevToolboxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SmartOpenIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open clipboard in \(.applicationName)",
                "Detect clipboard in \(.applicationName)"
            ],
            shortTitle: "Open in DevToolbox",
            systemImageName: "wrench.and.screwdriver"
        )
    }
}
