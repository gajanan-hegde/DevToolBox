import Foundation
import SwiftUI

// MARK: - Parse Error

struct JSONParseError {
    let line: Int
    let column: Int
    let message: String
}

// MARK: - Model

@Observable
final class JSONEditorModel {
    @ObservationIgnored
    @AppStorage("json_editor_scratch") var text: String = "" {
        didSet { scheduleDebounce() }
    }

    var jsonValue: JSONValue?
    var parseError: JSONParseError?

    @ObservationIgnored
    private var debounceTimer: Timer?

    init() {}

    // MARK: - Debounced Parsing

    func onTextChanged() {
        scheduleDebounce()
    }

    private func scheduleDebounce() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.parse()
        }
    }

    func parseImmediately() {
        debounceTimer?.invalidate()
        parse()
    }

    private func parse() {
        let source = text
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            jsonValue = nil
            parseError = nil
            return
        }
        guard let data = source.data(using: .utf8) else {
            jsonValue = nil
            parseError = JSONParseError(line: 1, column: 1, message: "Invalid UTF-8 text")
            return
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            jsonValue = JSONValue.from(obj)
            parseError = nil
        } catch let error as NSError {
            jsonValue = nil
            parseError = extractError(from: error, in: source)
        }
    }

    private func extractError(from error: NSError, in source: String) -> JSONParseError {
        let msg = error.localizedDescription
        // NSJSONSerialization puts character offset in userInfo
        if let offset = error.userInfo["NSJSONSerializationErrorIndex"] as? Int {
            let (line, col) = lineColumn(for: offset, in: source)
            return JSONParseError(line: line, column: col, message: msg)
        }
        return JSONParseError(line: 1, column: 1, message: msg)
    }

    // MARK: - Char Offset → Line/Column (Task 1.5)

    func lineColumn(for charOffset: Int, in text: String) -> (line: Int, column: Int) {
        var line = 1
        var col = 1
        var idx = text.startIndex
        var count = 0
        while count < charOffset && idx < text.endIndex {
            if text[idx] == "\n" {
                line += 1
                col = 1
            } else {
                col += 1
            }
            text.formIndex(after: &idx)
            count += 1
        }
        return (line, col)
    }

    // MARK: - Formatting (Task 1.3)

    func prettyPrint() {
        reformat(options: [.prettyPrinted, .sortedKeys])
    }

    func compact() {
        reformat(options: [])
    }

    private func reformat(options: JSONSerialization.WritingOptions) {
        var opts = options
        opts.insert(.withoutEscapingSlashes)
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
              let formatted = try? JSONSerialization.data(withJSONObject: obj, options: opts),
              let str = String(data: formatted, encoding: .utf8) else { return }
        text = str
    }

    // MARK: - Tree → Text Serialization (Task 1.4)

    func serializeTree() {
        guard let value = jsonValue else { return }
        let obj = value.toObject()
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let str = String(data: data, encoding: .utf8) else { return }
        text = str
    }

    // MARK: - Tree Mutation (Task 3.7)

    func updateValue(at path: [JSONPathComponent], to newValue: JSONValue) {
        guard var root = jsonValue else { return }
        root = mutateValue(root, path: path[...], newValue: newValue)
        jsonValue = root
        serializeTree()
    }

    func updateKey(at path: [JSONPathComponent], to newKey: String) {
        guard var root = jsonValue else { return }
        root = mutateKey(root, path: path[...], newKey: newKey)
        jsonValue = root
        serializeTree()
    }

    private func mutateValue(_ node: JSONValue, path: ArraySlice<JSONPathComponent>, newValue: JSONValue) -> JSONValue {
        guard let first = path.first else { return newValue }
        let rest = path.dropFirst()
        switch (node, first) {
        case (.object(let pairs), .key(let k)):
            let updated = pairs.map { pair -> (key: String, value: JSONValue) in
                pair.key == k ? (key: pair.key, value: mutateValue(pair.value, path: rest, newValue: newValue)) : pair
            }
            return .object(updated)
        case (.array(let items), .index(let i)):
            var updated = items
            if i < updated.count {
                updated[i] = mutateValue(items[i], path: rest, newValue: newValue)
            }
            return .array(updated)
        default:
            return node
        }
    }

    private func mutateKey(_ node: JSONValue, path: ArraySlice<JSONPathComponent>, newKey: String) -> JSONValue {
        guard let first = path.first else { return node }
        let rest = path.dropFirst()
        switch (node, first) {
        case (.object(let pairs), .key(let k)):
            if rest.isEmpty {
                // rename the key at this level
                let updated = pairs.map { pair -> (key: String, value: JSONValue) in
                    pair.key == k ? (key: newKey, value: pair.value) : pair
                }
                return .object(updated)
            } else {
                let updated = pairs.map { pair -> (key: String, value: JSONValue) in
                    pair.key == k ? (key: pair.key, value: mutateKey(pair.value, path: rest, newKey: newKey)) : pair
                }
                return .object(updated)
            }
        case (.array(let items), .index(let i)):
            var updated = items
            if i < updated.count {
                updated[i] = mutateKey(items[i], path: rest, newKey: newKey)
            }
            return .array(updated)
        default:
            return node
        }
    }
}

// MARK: - Path

enum JSONPathComponent {
    case key(String)
    case index(Int)
}
