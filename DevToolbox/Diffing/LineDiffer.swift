import Foundation

// MARK: - Data Types

enum LineDiffKind: Equatable {
    case same
    case added
    case removed
    case modified
}

struct LineDiffRow: Equatable {
    let leftLine: String?
    let rightLine: String?
    let kind: LineDiffKind
    let leftLineNumber: Int
    let rightLineNumber: Int
}

// MARK: - LineDiffer

enum LineDiffer {

    static func diff(left: String, right: String) -> [LineDiffRow] {
        let ops  = lcsDiff(left.components(separatedBy: "\n"),
                           right.components(separatedBy: "\n"))
        var rows = buildRows(from: ops)
        applyModifiedHeuristic(&rows)
        return rows
    }

    // MARK: - LCS diff

    private enum EditOp {
        case equal(String), insert(String), delete(String)
    }

    private static func lcsDiff(_ a: [String], _ b: [String]) -> [EditOp] {
        let m = a.count, n = b.count
        if m == 0 { return b.map { .insert($0) } }
        if n == 0 { return a.map { .delete($0) } }
        guard m <= 5000 && n <= 5000 else {
            return a.map { .delete($0) } + b.map { .insert($0) }
        }

        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
            }
        }

        var ops: [EditOp] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && a[i-1] == b[j-1] {
                ops.append(.equal(a[i-1])); i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j-1] >= dp[i-1][j]) {
                ops.append(.insert(b[j-1])); j -= 1
            } else {
                ops.append(.delete(a[i-1])); i -= 1
            }
        }
        return ops.reversed()
    }

    // MARK: - Build rows

    private static func buildRows(from ops: [EditOp]) -> [LineDiffRow] {
        var rows: [LineDiffRow] = []
        var l = 1, r = 1
        for op in ops {
            switch op {
            case .equal(let s):
                rows.append(.init(leftLine: s, rightLine: s, kind: .same,
                                  leftLineNumber: l, rightLineNumber: r))
                l += 1; r += 1
            case .delete(let s):
                rows.append(.init(leftLine: s, rightLine: nil, kind: .removed,
                                  leftLineNumber: l, rightLineNumber: 0))
                l += 1
            case .insert(let s):
                rows.append(.init(leftLine: nil, rightLine: s, kind: .added,
                                  leftLineNumber: 0, rightLineNumber: r))
                r += 1
            }
        }
        return rows
    }

    // MARK: - Modified heuristic

    private static func applyModifiedHeuristic(_ rows: inout [LineDiffRow]) {
        var i = 0
        while i + 1 < rows.count {
            let cur = rows[i], nxt = rows[i + 1]
            guard cur.kind == .removed, nxt.kind == .added,
                  let lLine = cur.leftLine, let rLine = nxt.rightLine else { i += 1; continue }
            if normalizedEditDistance(lLine, rLine) < 0.6 {
                rows[i]     = .init(leftLine: lLine, rightLine: nil, kind: .modified,
                                    leftLineNumber: cur.leftLineNumber, rightLineNumber: 0)
                rows[i + 1] = .init(leftLine: nil, rightLine: rLine, kind: .modified,
                                    leftLineNumber: 0, rightLineNumber: nxt.rightLineNumber)
                i += 2
            } else { i += 1 }
        }
    }

    // MARK: - Levenshtein (capped at 200 chars)

    private static func normalizedEditDistance(_ a: String, _ b: String) -> Double {
        let ac = Array(a.prefix(200)), bc = Array(b.prefix(200))
        let m = ac.count, n = bc.count
        guard max(m, n) > 0 else { return 0 }
        if m == 0 { return 1 }
        if n == 0 { return 1 }
        var prev = Array(0...n), curr = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                curr[j] = ac[i-1] == bc[j-1] ? prev[j-1] : 1 + min(prev[j], curr[j-1], prev[j-1])
            }
            swap(&prev, &curr)
        }
        return Double(prev[n]) / Double(max(m, n))
    }
}
