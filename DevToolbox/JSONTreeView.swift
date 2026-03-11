import SwiftUI

// MARK: - Data Model

indirect enum JSONValue {
    case null
    case bool(Bool)
    case number(NSNumber)
    case string(String)
    case array([JSONValue])
    case object([(key: String, value: JSONValue)])

    static func from(_ any: Any) -> JSONValue {
        if any is NSNull { return .null }
        if let num = any as? NSNumber {
            return CFGetTypeID(num) == CFBooleanGetTypeID() ? .bool(num.boolValue) : .number(num)
        }
        if let s = any as? String { return .string(s) }
        if let arr = any as? [Any] { return .array(arr.map { JSONValue.from($0) }) }
        if let dict = any as? [String: Any] {
            let pairs = dict.sorted { $0.key < $1.key }.map { (key: $0.key, value: JSONValue.from($0.value)) }
            return .object(pairs)
        }
        return .null
    }
}

// MARK: - Serialization

extension JSONValue {
    func toObject() -> Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n
        case .string(let s): return s
        case .array(let items): return items.map { $0.toObject() }
        case .object(let pairs):
            var dict: [String: Any] = [:]
            for pair in pairs { dict[pair.key] = pair.value.toObject() }
            return dict
        }
    }
}

// MARK: - Public View

struct JSONTreeView: View {
    let value: JSONValue
    var timestampKeys: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                JSONNodeView(value: value, key: nil, timestampKeys: timestampKeys)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
    }
}

// MARK: - Node View

private struct JSONNodeView: View {
    let value: JSONValue
    let key: String?
    var timestampKeys: Set<String> = []
    @State private var isExpanded = true

    var body: some View {
        Group {
            switch value {
            case .null:
                leaf { Text("null").foregroundStyle(.secondary).italic() }
            case .bool(let b):
                leaf { Text(b ? "true" : "false").foregroundStyle(Color.purple) }
            case .number(let n):
                if let key, timestampKeys.contains(key) {
                    leaf { TimestampValueView(unixTime: n.doubleValue) }
                } else {
                    leaf {
                        let s = n.doubleValue.truncatingRemainder(dividingBy: 1) == 0
                            ? String(n.intValue) : String(n.doubleValue)
                        Text(s).foregroundStyle(Color.blue)
                    }
                }
            case .string(let s):
                leaf { Text("\"\(s)\"").foregroundStyle(Color.green) }
            case .array(let items):
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        JSONNodeView(value: item, key: "[\(i)]", timestampKeys: timestampKeys).padding(.leading, 16)
                    }
                } label: { collectionLabel("[\(items.count)]") }
            case .object(let pairs):
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(pairs, id: \.key) { pair in
                        JSONNodeView(value: pair.value, key: pair.key, timestampKeys: timestampKeys).padding(.leading, 16)
                    }
                } label: { collectionLabel("{\(pairs.count)}") }
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func leaf<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        HStack(spacing: 4) {
            if let key { Text("\(key):").foregroundStyle(.secondary).fontWeight(.medium) }
            content()
            Spacer(minLength: 0)
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func collectionLabel(_ suffix: String) -> some View {
        HStack(spacing: 4) {
            if let key { Text("\(key):").foregroundStyle(.secondary).fontWeight(.medium) }
            Text(suffix).foregroundStyle(.tertiary).font(.system(.caption, design: .monospaced))
        }
    }
}

// MARK: - Timestamp hover view

private struct TimestampValueView: View {
    let unixTime: Double
    @State private var isHovered = false

    private var date: Date { Date(timeIntervalSince1970: unixTime) }

    private var rawString: String {
        unixTime.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(unixTime)) : String(unixTime)
    }

    private var formattedDate: String {
        let absolute = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .medium)
        let relative = RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        return "\(absolute)  ·  \(relative)"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(rawString).foregroundStyle(Color.blue)
            if isHovered {
                Text(formattedDate)
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}
