import XCTest
@testable import DevToolbox

class DiffEngineTests: XCTestCase {

    // MARK: - Dictionary Tests

    func testDictionary_keyAdded() {
        let old: [String: Any] = ["a": 1]
        let new: [String: Any] = ["a": 1, "b": 2]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["b"], type: .added(value: 2)))
    }

    func testDictionary_keyRemoved() {
        let old: [String: Any] = ["a": 1, "b": 2]
        let new: [String: Any] = ["a": 1]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["b"], type: .removed(value: 2)))
    }

    func testDictionary_valueModified() {
        let old: [String: Any] = ["a": 1]
        let new: [String: Any] = ["a": 2]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["a"], type: .modified(oldValue: 1, newValue: 2)))
    }

    func testDictionary_noChanges() {
        let old: [String: Any] = ["a": 1, "b": "hello"]
        let new: [String: Any] = ["b": "hello", "a": 1] // Order doesn't matter
        let diffs = DiffEngine.compare(old, new)
        XCTAssertTrue(diffs.isEmpty)
    }

    // MARK: - Array Tests

    func testArray_elementAdded() {
        let old = [1, 2]
        let new = [1, 2, 3]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["[2]"], type: .added(value: 3)))
    }

    func testArray_elementRemoved() {
        let old = [1, 2, 3]
        let new = [1, 2]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["[2]"], type: .removed(value: 3)))
    }

    func testArray_elementModified() {
        let old = [1, 2, 3]
        let new = [1, 5, 3]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["[1]"], type: .modified(oldValue: 2, newValue: 5)))
    }

    // MARK: - Nested & Complex Tests

    func testNestedObject_valueModified() {
        let old: [String: Any] = ["user": ["name": "John", "address": ["city": "New York"]]]
        let new: [String: Any] = ["user": ["name": "John", "address": ["city": "San Francisco"]]]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["user", "address", "city"], type: .modified(oldValue: "New York", newValue: "San Francisco")))
    }

    func testTypeMismatch() {
        let old: [String: Any] = ["value": 1]
        let new: [String: Any] = ["value": "1"]
        let diffs = DiffEngine.compare(old, new)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first, Diff(path: ["value"], type: .modified(oldValue: 1, newValue: "1")))
    }
}
