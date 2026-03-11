import Foundation

/// Represents a single difference found during a comparison.
struct Diff {
    /// The path to the item that has changed.
    /// For a nested object, this could be `["user", "address", "city"]`.
    /// For an array, the key would be the index as a string, e.g., `["users", "0", "name"]`.
    let path: [String]
    
    /// The type of change that occurred.
    let type: DiffType
}

/// Defines the type of difference.
enum DiffType {
    /// A new key/value pair was added.
    case added(value: Any)
    
    /// A key/value pair was removed.
    case removed(value: Any)
    
    /// The value for a key was changed.
    case modified(oldValue: Any, newValue: Any)
}

// Conforming to Equatable for easier testing later on.
extension Diff: Equatable {
    static func == (lhs: Diff, rhs: Diff) -> Bool {
        lhs.path == rhs.path && lhs.type == rhs.type
    }
}

extension DiffType: Equatable {
    static func == (lhs: DiffType, rhs: DiffType) -> Bool {
        switch (lhs, rhs) {
        case (.added(let a), .added(let b)):
            return areEqual(a, b)
        case (.removed(let a), .removed(let b)):
            return areEqual(a, b)
        case (.modified(let a1, let a2), .modified(let b1, let b2)):
            return areEqual(a1, b1) && areEqual(a2, b2)
        default:
            return false
        }
    }
}

/// A helper function to compare two `Any` types, since `Any` is not directly Equatable.
/// This is a simplified comparison for the purpose of the data model.
private func areEqual(_ a: Any, _ b: Any) -> Bool {
    guard a is any Equatable, b is any Equatable else { return false }
    return String(describing: a) == String(describing: b)
}
