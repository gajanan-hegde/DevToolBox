import SwiftUI

// MARK: - Expand/Collapse All Environment Keys

private struct ExpandAllSignalKey: EnvironmentKey { static let defaultValue = 0 }
private struct CollapseAllSignalKey: EnvironmentKey { static let defaultValue = 0 }

extension EnvironmentValues {
    fileprivate var expandAllSignal: Int {
        get { self[ExpandAllSignalKey.self] }
        set { self[ExpandAllSignalKey.self] = newValue }
    }
    fileprivate var collapseAllSignal: Int {
        get { self[CollapseAllSignalKey.self] }
        set { self[CollapseAllSignalKey.self] = newValue }
    }
}

// MARK: - Tree Editable Protocol

protocol TreeEditable: AnyObject {
    var jsonValue: JSONValue? { get }
    func updateValue(at path: [JSONPathComponent], to newValue: JSONValue)
    func updateKey(at path: [JSONPathComponent], to newKey: String)
}

extension JSONEditorModel: TreeEditable {}

// MARK: - Root View (Task 3.1)

struct EditableJSONTreeView<M: TreeEditable>: View {
    let model: M
    var expandSignal: Int = 0
    var collapseSignal: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let value = model.jsonValue {
                    EditableJSONNodeView(value: value, key: nil, path: [], model: model)
                } else {
                    Text("(empty)")
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(8)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
        .environment(\.expandAllSignal, expandSignal)
        .environment(\.collapseAllSignal, collapseSignal)
    }
}

// MARK: - Node View (Task 3.2)

struct EditableJSONNodeView<M: TreeEditable>: View {
    let value: JSONValue
    let key: String?
    let path: [JSONPathComponent]
    let model: M

    @State private var isExpanded = true
    @Environment(\.expandAllSignal) private var expandAllSignal
    @Environment(\.collapseAllSignal) private var collapseAllSignal

    var body: some View {
        Group {
            switch value {
            case .null:
                leaf {
                    Text("null").foregroundStyle(.secondary).italic()
                }
            case .bool(let b):
                EditableBoolNode(value: b, key: key, path: path, model: model)
            case .number(let n):
                EditableNumberNode(value: n, key: key, path: path, model: model)
            case .string(let s):
                EditableStringNode(value: s, key: key, path: path, model: model)
            case .array(let items):
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        EditableJSONNodeView(
                            value: item,
                            key: "[\(i)]",
                            path: path + [.index(i)],
                            model: model
                        )
                        .padding(.leading, 16)
                    }
                } label: {
                    collectionLabel("[\(items.count)]")
                }
            case .object(let pairs):
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(Array(pairs.enumerated()), id: \.element.key) { _, pair in
                        EditableJSONNodeView(
                            value: pair.value,
                            key: pair.key,
                            path: path + [.key(pair.key)],
                            model: model
                        )
                        .padding(.leading, 16)
                    }
                } label: {
                    collectionLabel("{\(pairs.count)}")
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding(.vertical, 1)
        .onChange(of: expandAllSignal) { isExpanded = true }
        .onChange(of: collapseAllSignal) { isExpanded = false }
    }

    @ViewBuilder
    private func leaf<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        HStack(spacing: 4) {
            if let key {
                Text("\(key):")
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            content()
            Spacer(minLength: 0)
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func collectionLabel(_ suffix: String) -> some View {
        HStack(spacing: 4) {
            if let key {
                EditableKeyLabel(keyName: key, path: path, model: model)
            }
            Text(suffix).foregroundStyle(.tertiary).font(.system(.caption, design: .monospaced))
        }
    }
}

// MARK: - Editable Key Label (Task 3.6)

struct EditableKeyLabel<M: TreeEditable>: View {
    let keyName: String
    let path: [JSONPathComponent]
    let model: M

    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        if isEditing {
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .onSubmit { commitKey() }
                .onExitCommand { isEditing = false }
                .onAppear { draft = keyName }
        } else {
            Text("\(keyName):")
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .onTapGesture {
                    draft = keyName
                    isEditing = true
                }
        }
    }

    private func commitKey() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != keyName {
            model.updateKey(at: path, to: trimmed)
        }
        isEditing = false
    }
}

// MARK: - Editable String Node (Task 3.3)

struct EditableStringNode<M: TreeEditable>: View {
    let value: String
    let key: String?
    let path: [JSONPathComponent]
    let model: M

    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 4) {
            if let key {
                EditableKeyLabel(keyName: key, path: path, model: model)
            }
            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.green)
                    .onSubmit { commit() }
                    .onExitCommand { isEditing = false }
                    .onAppear { draft = value }
            } else {
                Text("\"\(value)\"")
                    .foregroundStyle(Color.green)
                    .onTapGesture {
                        draft = value
                        isEditing = true
                    }
            }
            Spacer(minLength: 0)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .padding(.vertical, 1)
    }

    private func commit() {
        model.updateValue(at: path, to: .string(draft))
        isEditing = false
    }
}

// MARK: - Editable Number Node (Task 3.4)

struct EditableNumberNode<M: TreeEditable>: View {
    let value: NSNumber
    let key: String?
    let path: [JSONPathComponent]
    let model: M

    @State private var isEditing = false
    @State private var draft = ""

    private var displayString: String {
        value.doubleValue.truncatingRemainder(dividingBy: 1) == 0
            ? String(value.intValue) : String(value.doubleValue)
    }

    var body: some View {
        HStack(spacing: 4) {
            if let key {
                EditableKeyLabel(keyName: key, path: path, model: model)
            }
            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.blue)
                    .onSubmit { commit() }
                    .onExitCommand { isEditing = false }
                    .onAppear { draft = displayString }
            } else {
                Text(displayString)
                    .foregroundStyle(Color.blue)
                    .onTapGesture {
                        draft = displayString
                        isEditing = true
                    }
            }
            Spacer(minLength: 0)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .padding(.vertical, 1)
    }

    private func commit() {
        if let n = NumberFormatter().number(from: draft) {
            model.updateValue(at: path, to: .number(n))
        }
        // else: revert silently (keep old value)
        isEditing = false
    }
}

// MARK: - Editable Bool Node (Task 3.5)

struct EditableBoolNode<M: TreeEditable>: View {
    let value: Bool
    let key: String?
    let path: [JSONPathComponent]
    let model: M

    var body: some View {
        HStack(spacing: 4) {
            if let key {
                EditableKeyLabel(keyName: key, path: path, model: model)
            }
            Toggle(isOn: Binding(
                get: { value },
                set: { newVal in
                    model.updateValue(at: path, to: .bool(newVal))
                }
            )) {
                Text(value ? "true" : "false").foregroundStyle(Color.purple)
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 0)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.vertical, 1)
    }
}
