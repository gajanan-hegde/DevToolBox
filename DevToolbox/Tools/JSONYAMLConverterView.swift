import SwiftUI
import Yams

struct JSONYAMLConverterView: View {

    // MARK: - State (Tasks 1.1 – 1.4)

    @AppStorage("jsonYamlConverter.json") private var jsonText = "{\n  \"name\": \"John Doe\",\n  \"age\": 30\n}"
    @AppStorage("jsonYamlConverter.yaml") private var yamlText = "name: John Doe\nage: 30"

    @State private var jsonError: JSONParseError? = nil
    @State private var yamlError: JSONParseError? = nil

    /// Last value written programmatically into each pane.
    /// onChange is skipped when the incoming value matches this, preventing
    /// the infinite-loop that would otherwise arise from bidirectional updates.
    @State private var lastSetJSON = ""
    @State private var lastSetYAML = ""

    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var activeDirection: Direction = .json

    private enum Direction { case json, yaml }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                VStack(spacing: 0) {
                    HStack {
                        Text("JSON").font(.headline)
                        Spacer()
                        CopyButton(value: jsonText)
                    }
                    .padding(.vertical, 6)
                    LineNumberedTextEditor(                          // Tasks 3.5
                        text: $jsonText,
                        errorLine: jsonError?.line,
                        errorMessage: jsonError.map { "Line \($0.line): \($0.message)" },
                        focusOnAppear: true
                    )
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    HStack {
                        Text("YAML").font(.headline)
                        Spacer()
                        CopyButton(value: yamlText)
                    }
                    .padding(.vertical, 6)
                    LineNumberedTextEditor(                          // Tasks 3.6
                        text: $yamlText,
                        errorLine: yamlError?.line,
                        errorMessage: yamlError.map { "Line \($0.line): \($0.message)" },
                        highlightMode: .yaml
                    )
                }
                .padding(.horizontal)
            }

            // Shared status bar (Tasks 4.1 – 4.3)
            Divider()
            HStack(spacing: 6) {
                if statusIsError {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                } else if !statusIsEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Text(statusText)
                    .font(.body.monospaced())
                    .foregroundStyle(
                        statusIsError ? Color.red
                            : statusIsEmpty ? Color.secondary
                            : Color.primary
                    )
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle("JSON <> YAML Converter")
        // Tasks 3.1 – 3.4: real-time onChange wiring, old activeField + onReceive removed
        .onChange(of: jsonText) {
            guard jsonText != lastSetJSON else { return }
            activeDirection = .json
            yamlError = nil                                         // clear stale error on other pane
            scheduleConvert(from: .json)
        }
        .onChange(of: yamlText) {
            guard yamlText != lastSetYAML else { return }
            activeDirection = .yaml
            jsonError = nil                                         // clear stale error on other pane
            scheduleConvert(from: .yaml)
        }
        .onAppear { applyPendingInput() }
        .onChange(of: AppState.shared.pendingInput) { applyPendingInput() }
    }

    // MARK: - Status bar helpers (Task 4.2, 4.3)

    private var statusIsEmpty: Bool {
        jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        yamlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusIsError: Bool {
        (activeDirection == .json && jsonError != nil) ||
        (activeDirection == .yaml && yamlError != nil)
    }

    private var statusText: String {
        if statusIsEmpty { return "Empty" }
        switch activeDirection {
        case .json:
            if let err = jsonError { return "Line \(err.line): \(err.message)" }
            return "JSON → YAML"
        case .yaml:
            if let err = yamlError { return "Line \(err.line): \(err.message)" }
            return "YAML → JSON"
        }
    }

    // MARK: - Conversion scheduling (Task 2.1)

    private func scheduleConvert(from direction: Direction) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                switch direction {
                case .json: convertJSONToYAML()
                case .yaml: convertYAMLToJSON()
                }
            }
        }
    }

    // MARK: - Conversion functions (Tasks 2.2, 2.3)

    private func convertJSONToYAML() {
        let source = jsonText
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            jsonError = nil; return
        }
        guard let data = source.data(using: .utf8) else { return }
        do {
            let obj  = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            let yaml = try Yams.dump(object: normalizeForYAML(obj))
            jsonError   = nil
            lastSetYAML = yaml
            yamlText    = yaml
        } catch let nsErr as NSError {
            jsonError = extractJSONError(nsErr, in: source)
        } catch {
            jsonError = JSONParseError(line: 1, column: 1, message: error.localizedDescription)
        }
    }

    private func convertYAMLToJSON() {
        let source = yamlText
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            yamlError = nil; return
        }
        do {
            guard let obj = try Yams.load(yaml: source) else {
                yamlError = nil; return
            }
            let data = try JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .withoutEscapingSlashes]
            )
            guard let json = String(data: data, encoding: .utf8) else { return }
            yamlError   = nil
            lastSetJSON = json
            jsonText    = json
        } catch let yamlErr as YamlError {
            yamlError = extractYAMLError(yamlErr)
        } catch {
            yamlError = JSONParseError(line: 1, column: 1, message: error.localizedDescription)
        }
    }

    // MARK: - NSNumber normalisation

    /// Recursively converts Foundation types returned by JSONSerialization into
    /// native Swift types so Yams doesn't serialise integers in scientific notation
    /// (e.g. NSNumber(60) → "6e+1"). Mirrors YAMLEditorModel.toYAMLObject.
    private func normalizeForYAML(_ obj: Any) -> Any {
        // Bool must be checked before NSNumber - Bool bridges to NSNumber in ObjC
        if let b = obj as? Bool   { return b }
        if let n = obj as? NSNumber {
            return n.doubleValue.truncatingRemainder(dividingBy: 1) == 0
                ? n.intValue : n.doubleValue
        }
        if obj is NSNull          { return NSNull() }
        if let arr  = obj as? [Any]         { return arr.map { normalizeForYAML($0) } }
        if let dict = obj as? [String: Any] {
            return dict.mapValues { normalizeForYAML($0) }
        }
        return obj
    }

    // MARK: - Error extraction (Tasks 2.4, 2.5)

    private func extractJSONError(_ error: NSError, in source: String) -> JSONParseError {
        let msg = error.localizedDescription
        if let offset = error.userInfo["NSJSONSerializationErrorIndex"] as? Int {
            let (line, col) = lineColumn(for: offset, in: source)
            return JSONParseError(line: line, column: col, message: msg)
        }
        return JSONParseError(line: 1, column: 1, message: msg)
    }

    private func extractYAMLError(_ error: YamlError) -> JSONParseError {
        switch error {
        case let .scanner(_, problem, mark, _):
            return JSONParseError(line: mark.line, column: mark.column, message: problem)
        case let .parser(_, problem, mark, _):
            return JSONParseError(line: mark.line, column: mark.column, message: problem)
        case let .composer(_, problem, mark, _):
            return JSONParseError(line: mark.line, column: mark.column, message: problem)
        default:
            return JSONParseError(line: 1, column: 1, message: error.localizedDescription)
        }
    }

    private func lineColumn(for charOffset: Int, in text: String) -> (line: Int, column: Int) {
        var line = 1, col = 1, count = 0
        var idx = text.startIndex
        while count < charOffset && idx < text.endIndex {
            if text[idx] == "\n" { line += 1; col = 1 } else { col += 1 }
            text.formIndex(after: &idx)
            count += 1
        }
        return (line, col)
    }

    // MARK: - Pending input

    private func applyPendingInput() {
        guard let pending = AppState.shared.pendingInput, pending.tool == .jsonYamlConverter else { return }
        jsonText        = pending.content
        activeDirection = .json
        AppState.shared.pendingInput = nil
    }
}
