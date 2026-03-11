import AppKit
import SwiftUI

// MARK: - Scroll-sync coordinator (Tasks 5.1 – 5.5)

/// Manages bidirectional scroll synchronisation between the two diff panes.
///
/// Both panes register their NSScrollViews by calling `register(left:right:)`.
/// When either pane scrolls, the coordinator looks up the top-visible line in
/// the scrolling pane, maps it to the corresponding line in the other pane
/// (using the `leftToRight` / `rightToLeft` tables built from the diff rows),
/// and programmatically scrolls the other pane there.
///
/// A simple `isSyncing` flag (Task 5.4) prevents re-entrancy: the programmatic
/// scroll on pane B will fire a bounds-change notification on B's clip view,
/// but by that time `isSyncing` is true so the handler returns immediately.
final class DiffScrollSyncCoordinator {

    private weak var leftScrollView:  NSScrollView?
    private weak var rightScrollView: NSScrollView?

    // Task 5.1 – line mappings derived from LineDiffRows
    private var leftToRight: [Int: Int] = [:]   // left line number → right line number
    private var rightToLeft: [Int: Int] = [:]   // right line number → left line number

    private var isSyncing = false
    private var observers: [NSObjectProtocol] = []

    // MARK: - Registration

    func register(left: NSScrollView, right: NSScrollView) {
        leftScrollView  = left
        rightScrollView = right
        setupObservers(left: left, right: right)
    }

    // MARK: - Line mapping (Task 5.1, 5.5)

    func updateMapping(rows: [LineDiffRow]) {
        var ltr: [Int: Int] = [:]
        var rtl: [Int: Int] = [:]
        for row in rows where row.kind == .same {
            ltr[row.leftLineNumber]  = row.rightLineNumber
            rtl[row.rightLineNumber] = row.leftLineNumber
        }
        leftToRight = ltr
        rightToLeft = rtl
    }

    // MARK: - Observer setup (Task 5.2)

    private func setupObservers(left: NSScrollView, right: NSScrollView) {
        // Remove any previous observers first
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []

        // NSView.boundsDidChangeNotification on the clip view fires for ALL
        // scroll position changes (trackpad, mouse wheel, keyboard, programmatic).
        left.contentView.postsBoundsChangedNotifications  = true
        right.contentView.postsBoundsChangedNotifications = true

        let leftObs = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: left.contentView,
            queue: .main
        ) { [weak self] _ in self?.leftDidScroll() }

        let rightObs = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: right.contentView,
            queue: .main
        ) { [weak self] _ in self?.rightDidScroll() }

        observers = [leftObs, rightObs]
    }

    // MARK: - Scroll handlers (Tasks 5.3, 5.4)

    private func leftDidScroll() {
        guard !isSyncing,
              let left = leftScrollView,
              let right = rightScrollView else { return }
        isSyncing = true
        defer { isSyncing = false }

        let topLine    = topVisibleLine(in: left)
        let targetLine = mappedLine(topLine, using: leftToRight)
        scroll(right, toLine: targetLine)
    }

    private func rightDidScroll() {
        guard !isSyncing,
              let left = leftScrollView,
              let right = rightScrollView else { return }
        isSyncing = true
        defer { isSyncing = false }

        let topLine    = topVisibleLine(in: right)
        let targetLine = mappedLine(topLine, using: rightToLeft)
        scroll(left, toLine: targetLine)
    }

    // MARK: - Helpers

    /// Returns the 1-indexed line number of the first fully-visible line
    /// in the given scroll view.  (Task 5.3)
    private func topVisibleLine(in scrollView: NSScrollView) -> Int {
        guard let textView      = scrollView.documentView as? NSTextView,
              let layoutManager = textView.layoutManager else { return 1 }

        let visibleY = scrollView.contentView.bounds.minY
        var lineNum  = 1
        let glyphCount = layoutManager.numberOfGlyphs
        guard glyphCount > 0 else { return 1 }

        layoutManager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: glyphCount)
        ) { rect, _, _, _, stop in
            if rect.maxY > visibleY {
                stop.pointee = true
            } else {
                lineNum += 1
            }
        }
        return lineNum
    }

    /// Maps a line number in one pane to the corresponding line number in the
    /// other pane.  Interpolates linearly between known same-line anchor points
    /// for lines that have no direct entry in the mapping table.
    private func mappedLine(_ line: Int, using mapping: [Int: Int]) -> Int {
        guard !mapping.isEmpty else { return line }
        if let exact = mapping[line] { return exact }

        let keys = mapping.keys.sorted()
        guard let first = keys.first, let last = keys.last else { return line }

        if line <= first { return mapping[first] ?? 1 }
        if line >= last  { return mapping[last]  ?? line }

        // Find the surrounding anchor points and interpolate
        var lo = first, hi = last
        for k in keys {
            if k <= line { lo = k }
            if k >= line { hi = k; break }
        }
        guard lo != hi else { return mapping[lo] ?? line }

        let loMapped = mapping[lo] ?? lo
        let hiMapped = mapping[hi] ?? hi
        let fraction = Double(line - lo) / Double(hi - lo)
        return loMapped + Int(fraction * Double(hiMapped - loMapped))
    }

    /// Programmatically scrolls `scrollView` so that `targetLine` is at the top
    /// of the visible area.  (Task 5.3)
    private func scroll(_ scrollView: NSScrollView, toLine targetLine: Int) {
        guard let textView      = scrollView.documentView as? NSTextView,
              let layoutManager = textView.layoutManager else { return }

        let glyphCount = layoutManager.numberOfGlyphs
        guard glyphCount > 0 else { return }

        var lineNum  = 1
        var targetY: CGFloat = 0
        var found    = false

        layoutManager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: glyphCount)
        ) { rect, _, _, _, stop in
            if lineNum == targetLine {
                targetY = rect.minY
                found   = true
                stop.pointee = true
            }
            lineNum += 1
        }
        guard found else { return }

        let maxY = max(0, textView.bounds.height - scrollView.contentView.bounds.height)
        let clampedY = min(max(targetY, 0), maxY)
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: clampedY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

// MARK: - JSONDiffView

struct JSONDiffView: View {

    // Task 4.1 – persisted across launches via UserDefaults
    @AppStorage("jsonDiff.text1") private var text1 = "{\n    \"hello\": \"world\",\n    \"value\": 1\n}"
    @AppStorage("jsonDiff.text2") private var text2 = "{\n    \"hello\": \"swiftui\",\n    \"value\": 2\n}"
    @State private var diffRows: [LineDiffRow] = []
    @State private var debounceTask: Task<Void, Never>? = nil

    // Scroll-sync coordinator — stored in @State so it persists across re-renders
    // without needing ObservableObject (we never publish changes to SwiftUI). (Task 5.1)
    @State private var syncCoordinator = DiffScrollSyncCoordinator()

    // Track whether both scroll views are registered so we only call
    // register(left:right:) once.
    @State private var leftScrollView:  NSScrollView? = nil
    @State private var rightScrollView: NSScrollView? = nil
    @State private var scrollViewsLinked = false

    // MARK: - Derived highlight arrays (Task 4.5)

    private var leftHighlights: [(Int, NSColor)] {
        diffRows.compactMap { row -> (Int, NSColor)? in
            guard row.leftLineNumber > 0, row.kind != .same else { return nil }
            switch row.kind {
            case .removed:  return (row.leftLineNumber, NSColor.systemRed.withAlphaComponent(0.25))
            case .modified: return (row.leftLineNumber, NSColor.systemYellow.withAlphaComponent(0.30))
            default:        return nil
            }
        }
    }

    private var rightHighlights: [(Int, NSColor)] {
        diffRows.compactMap { row -> (Int, NSColor)? in
            guard row.rightLineNumber > 0, row.kind != .same else { return nil }
            switch row.kind {
            case .added:    return (row.rightLineNumber, NSColor.systemGreen.withAlphaComponent(0.25))
            case .modified: return (row.rightLineNumber, NSColor.systemYellow.withAlphaComponent(0.30))
            default:        return nil
            }
        }
    }

    // MARK: - Summary (Task 4.6)

    private var summaryText: String {
        let adds  = diffRows.filter { $0.kind == .added    }.count
        let dels  = diffRows.filter { $0.kind == .removed  }.count
        let mods  = diffRows.filter { $0.kind == .modified && $0.leftLineNumber > 0 }.count
        let total = adds + dels + mods
        guard total > 0 else { return "No differences" }
        var parts: [String] = []
        if adds > 0 { parts.append("\(adds) addition\(adds == 1 ? "" : "s")") }
        if dels > 0 { parts.append("\(dels) deletion\(dels == 1 ? "" : "s")") }
        if mods > 0 { parts.append("\(mods) modification\(mods == 1 ? "" : "s")") }
        return "\(total) change\(total == 1 ? "" : "s") (\(parts.joined(separator: ", ")))"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                VStack(spacing: 0) {
                    Text("Document 1")
                        .font(.headline)
                        .padding(.vertical, 6)
                    LineNumberedTextEditor(
                        text: $text1,
                        focusOnAppear: true,
                        lineHighlights: leftHighlights,
                        onScrollViewCreated: { sv in
                            leftScrollView = sv
                            linkScrollViewsIfReady()
                        }
                    )
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    Text("Document 2")
                        .font(.headline)
                        .padding(.vertical, 6)
                    LineNumberedTextEditor(
                        text: $text2,
                        lineHighlights: rightHighlights,
                        onScrollViewCreated: { sv in
                            rightScrollView = sv
                            linkScrollViewsIfReady()
                        }
                    )
                }
                .padding(.horizontal)
            }

            // Task 4.6 – summary bar replaces old button toolbar
            Divider()
            HStack {
                Text(summaryText)
                    .font(.body.monospaced())
                    .foregroundStyle(diffRows.isEmpty || diffRows.allSatisfy { $0.kind == .same }
                                     ? Color.secondary
                                     : Color.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle("JSON/YAML Diff")
        // Task 4.3 – real-time debounced diff on every edit
        .onChange(of: text1) { scheduleDiff() }
        .onChange(of: text2) { scheduleDiff() }
        .onAppear {
            applyPendingInput()
            scheduleDiff()
        }
        .onChange(of: AppState.shared.pendingInput) { applyPendingInput() }
    }

    // MARK: - Scroll-view linking (Task 5.2)

    private func linkScrollViewsIfReady() {
        guard !scrollViewsLinked,
              let left = leftScrollView,
              let right = rightScrollView else { return }
        scrollViewsLinked = true
        syncCoordinator.register(left: left, right: right)
    }

    // MARK: - Real-time diff (Tasks 4.3, 4.4)

    private func scheduleDiff() {
        debounceTask?.cancel()
        let capturedLeft  = text1
        let capturedRight = text2
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let rows = LineDiffer.diff(left: capturedLeft, right: capturedRight)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                diffRows = rows                           // Task 4.4 – update state
                syncCoordinator.updateMapping(rows: rows) // Task 5.5
            }
        }
    }

    // MARK: - Pending input

    private func applyPendingInput() {
        guard let pending = AppState.shared.pendingInput, pending.tool == .jsonDiff else { return }
        text1 = pending.content
        AppState.shared.pendingInput = nil
    }
}
