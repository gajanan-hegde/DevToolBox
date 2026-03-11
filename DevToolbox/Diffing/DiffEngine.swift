import Foundation

struct DiffEngine {
    /// Compares two objects and returns an array of differences.
    /// The objects are expected to be the result of `JSONSerialization` or `Yams.load`.
    static func compare(_ old: Any, _ new: Any, path: [String] = []) -> [Diff] {
        // If types are different, we can't compare further. Mark as modified.
        if type(of: old) != type(of: new) {
            return [Diff(path: path, type: .modified(oldValue: old, newValue: new))]
        }

        if let oldDict = old as? [String: Any], let newDict = new as? [String: Any] {
            return diff(old: oldDict, new: newDict, path: path)
        } else if let oldArray = old as? [Any], let newArray = new as? [Any] {
            return diff(old: oldArray, new: newArray, path: path)
        } else if !areEqual(old, new) {
            return [Diff(path: path, type: .modified(oldValue: old, newValue: new))]
        } else {
            return [] // They are equal
        }
    }

    /// Diffs two dictionaries.
    private static func diff(old: [String: Any], new: [String: Any], path: [String]) -> [Diff] {
        var differences: [Diff] = []
        let allKeys = Set(old.keys).union(Set(new.keys))

        for key in allKeys.sorted() { // Sort keys for deterministic output
            let newPath = path + [key]
            let oldValue = old[key]
            let newValue = new[key]

            if let oldValue = oldValue, let newValue = newValue {
                // Key exists in both, compare their values
                differences.append(contentsOf: compare(oldValue, newValue, path: newPath))
            } else if let oldValue = oldValue {
                // Key only in old, so it was removed
                differences.append(Diff(path: newPath, type: .removed(value: oldValue)))
            } else if let newValue = newValue {
                // Key only in new, so it was added
                differences.append(Diff(path: newPath, type: .added(value: newValue)))
            }
        }
        return differences
    }

    /// Diffs two arrays. This is a simplified implementation.
    private static func diff(old: [Any], new: [Any], path: [String]) -> [Diff] {
        var differences: [Diff] = []
        let maxCount = max(old.count, new.count)

        for i in 0..<maxCount {
            let newPath = path + ["[\(i)]"] // Use index in path
            let oldValue = i < old.count ? old[i] : nil
            let newValue = i < new.count ? new[i] : nil
            
            if let oldValue = oldValue, let newValue = newValue {
                differences.append(contentsOf: compare(oldValue, newValue, path: newPath))
            } else if let oldValue = oldValue {
                differences.append(Diff(path: newPath, type: .removed(value: oldValue)))
            } else if let newValue = newValue {
                differences.append(Diff(path: newPath, type: .added(value: newValue)))
            }
        }
        return differences
    }
}

/// A helper function to compare two `Any` types, since `Any` is not directly Equatable.
/// This is a simplified comparison for the purpose of the data model.
private func areEqual(_ a: Any, _ b: Any) -> Bool {
    guard a is any Equatable, b is any Equatable else { return false }
    return String(describing: a) == String(describing: b)
}
