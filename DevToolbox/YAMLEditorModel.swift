import Foundation
import SwiftUI
import Yams

// MARK: - Model

@Observable
final class YAMLEditorModel {
    @ObservationIgnored
    @AppStorage("yaml_editor_scratch") var text: String = "" {
        didSet { scheduleDebounce() }
    }

    var yamlValue: JSONValue?
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
            yamlValue = nil
            parseError = nil
            return
        }
        do {
            let obj = try Yams.load(yaml: source)
            yamlValue = anyToJSONValue(obj)
            parseError = nil
        } catch let err as YamlError {
            yamlValue = nil
            parseError = extractError(from: err)
        } catch {
            yamlValue = nil
            parseError = JSONParseError(line: 1, column: 1, message: error.localizedDescription)
        }
    }

    private func extractError(from err: YamlError) -> JSONParseError {
        switch err {
        case let .scanner(_, problem, mark, _):
            return JSONParseError(line: mark.line, column: mark.column, message: problem)
        case let .parser(_, problem, mark, _):
            return JSONParseError(line: mark.line, column: mark.column, message: problem)
        case let .composer(_, problem, mark, _):
            return JSONParseError(line: mark.line, column: mark.column, message: problem)
        default:
            return JSONParseError(line: 1, column: 1, message: err.localizedDescription)
        }
    }

    // MARK: - JSONValue Mapper

    private func anyToJSONValue(_ any: Any?) -> JSONValue {
        guard let any = any else { return .null }
        // Handle Optional<Any>.none wrapped inside Any (null elements in Yams collections)
        let mirror = Mirror(reflecting: any)
        if mirror.displayStyle == .optional && mirror.children.isEmpty { return .null }
        // Bool must be checked before Int to avoid misclassification
        if let b = any as? Bool { return .bool(b) }
        if let i = any as? Int { return .number(NSNumber(value: i)) }
        if let d = any as? Double { return .number(NSNumber(value: d)) }
        if let s = any as? String { return .string(s) }
        if let arr = any as? [Any] { return .array(arr.map { anyToJSONValue($0) }) }
        if let dict = any as? [String: Any] {
            let pairs = dict.map { (key: $0.key, value: anyToJSONValue($0.value)) }
            return .object(pairs)
        }
        return .string(String(describing: any))
    }

    // MARK: - Formatting

    func prettyPrint() {
        guard let value = yamlValue else { return }
        guard let yaml = try? Yams.dump(object: toYAMLObject(value), width: -1, allowUnicode: true) else { return }
        text = yaml
    }

    func serializeTree() {
        guard let value = yamlValue else { return }
        guard let yaml = try? Yams.dump(object: toYAMLObject(value), width: -1, allowUnicode: true) else { return }
        text = yaml
    }

    // Converts JSONValue to a Yams-friendly object graph using native Swift Int/Double
    // instead of NSNumber, which Yams serializes in scientific notation.
    private func toYAMLObject(_ value: JSONValue) -> Any {
        switch value {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n):
            return n.doubleValue.truncatingRemainder(dividingBy: 1) == 0 ? n.intValue : n.doubleValue
        case .string(let s): return s
        case .array(let items): return items.map { toYAMLObject($0) }
        case .object(let pairs):
            var dict: [String: Any] = [:]
            for pair in pairs { dict[pair.key] = toYAMLObject(pair.value) }
            return dict
        }
    }

    // MARK: - Tree Mutation

    func updateValue(at path: [JSONPathComponent], to newValue: JSONValue) {
        guard var root = yamlValue else { return }
        root = mutateValue(root, path: path[...], newValue: newValue)
        yamlValue = root
        serializeTree()
    }

    func updateKey(at path: [JSONPathComponent], to newKey: String) {
        guard var root = yamlValue else { return }
        root = mutateKey(root, path: path[...], newKey: newKey)
        yamlValue = root
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

// MARK: - TreeEditable conformance

extension YAMLEditorModel: TreeEditable {
    var jsonValue: JSONValue? { yamlValue }
}
