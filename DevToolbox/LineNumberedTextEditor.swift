import AppKit
import SwiftUI

// MARK: - Highlight Mode

enum HighlightMode {
    case json
    case yaml
}

// MARK: - NSViewRepresentable (Tasks 2.1, 2.2)

struct LineNumberedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var errorLine: Int?
    var errorMessage: String?
    var isEditable: Bool = true
    var focusOnAppear: Bool = false
    var timestampKeys: Set<String> = []
    var highlightMode: HighlightMode = .json
    // Task 3.1 – diff line highlights: (1-indexed line number, background colour)
    var lineHighlights: [(Int, NSColor)] = []
    // Task 3.5 – called once when the NSScrollView is ready so callers can
    //            attach scroll-sync observers.
    var onScrollViewCreated: ((NSScrollView) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // Task 3.2 – build the text-view stack manually so we can inject
        // DiffLayoutManager in place of NSTextView's default layout manager.
        let textStorage    = NSTextStorage()
        let layoutManager  = DiffLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        // widthTracksTextView = true + autoresizingMask [.width] gives word-wrap behaviour:
        // text wraps at the visible width, the text view grows downward, vertical scroll only.
        // Width is managed by widthTracksTextView; height must be unbounded so
        // content can grow vertically without being clipped.
        let textContainer  = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        let textView = NSTextView(frame: .zero, textContainer: textContainer)

        // isRichText = true is required for NSTextStorage attribute-based syntax highlighting.
        // User-driven formatting is prevented by disabling font/ruler panels.
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = isEditable
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        // minSize/maxSize are required for correct layout with NSTextView(frame:textContainer:).
        // Without them the scroll view cannot determine the content size and scroll direction
        // is misinterpreted.
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.typingAttributes = Highlighter.baseAttributes
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        // Store a reference to DiffLayoutManager on the coordinator so
        // updateNSView can push new highlights without re-querying.
        context.coordinator.diffLayoutManager = layoutManager

        // Gutter (Task 2.3, 2.4)
        let gutter = ErrorGutterRulerView(scrollView: scrollView, orientation: .verticalRuler)
        gutter.clientView = textView          // must be set explicitly; AppKit does not always auto-assign
        scrollView.verticalRulerView = gutter
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.gutter = gutter

        // Task 3.5 – notify the caller (e.g. JSONDiffView) that the scroll view
        // is ready so it can set up scroll-sync observers. Must be async to
        // avoid mutating SwiftUI state during a view-update pass.
        let callback = onScrollViewCreated
        let sv = scrollView
        DispatchQueue.main.async { callback?(sv) }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Focus the text view the first time it appears in a window.
        if focusOnAppear && !context.coordinator.hasFocused {
            context.coordinator.hasFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                textView.window?.makeFirstResponder(textView)
            }
        }

        textView.isEditable = isEditable

        // Update text only if different to avoid cursor jumping.
        // Setting .string resets all NSTextStorage attributes, so re-highlight after.
        if textView.string != text {
            textView.string = text
            textView.typingAttributes = Highlighter.baseAttributes
            switch highlightMode {
            case .json:
                Highlighter.apply(to: textView)
                // .toolTip attributes must be applied after Highlighter.apply since it
                // calls setAttributes which wipes the full range first.
                applyTimestampTooltips(to: textView)
            case .yaml:
                YAMLHighlighter.apply(to: textView)
            }
        }

        // Update gutter error state (Task 2.5)
        if let gutter = scrollView.verticalRulerView as? ErrorGutterRulerView {
            gutter.errorLine = errorLine
            gutter.errorMessage = errorMessage
            gutter.needsDisplay = true
        }

        // Tasks 3.3, 3.4 – push diff line highlights to DiffLayoutManager.
        // Convert 1-indexed line numbers into NSRanges over the raw text so
        // DiffLayoutManager.drawBackground can paint full-width colour bands.
        if let lm = context.coordinator.diffLayoutManager {
            let charHighlights = characterHighlights(for: lineHighlights, in: textView.string)
            lm.lineHighlights = charHighlights
            // Invalidate display only (no layout change) so backgrounds repaint
            // without forcing a full text re-layout.  (Task 3.4)
            let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
            lm.invalidateDisplay(forCharacterRange: fullRange)
        }
    }

    /// Converts an array of (1-indexed line number, colour) pairs into
    /// (NSRange in the string's UTF-16 view, colour) pairs suitable for
    /// DiffLayoutManager.  Lines are delimited by "\n". (Task 3.3)
    private func characterHighlights(
        for highlights: [(Int, NSColor)],
        in text: String
    ) -> [(characterRange: NSRange, color: NSColor)] {
        guard !highlights.isEmpty else { return [] }

        // Split into lines and accumulate UTF-16 character ranges.
        let lines = text.components(separatedBy: "\n")
        var lineRanges: [NSRange] = []
        var offset = 0
        for (i, line) in lines.enumerated() {
            let count = line.utf16.count
            lineRanges.append(NSRange(location: offset, length: count))
            offset += count + (i < lines.count - 1 ? 1 : 0)  // +1 for the \n separator
        }

        return highlights.compactMap { (lineNum, color) -> (NSRange, NSColor)? in
            let idx = lineNum - 1
            guard idx >= 0 && idx < lineRanges.count else { return nil }
            return (lineRanges[idx], color)
        }
    }

    // Adds NSAttributedString.Key.toolTip to timestamp value ranges so NSTextView
    // shows them natively when the user hovers. Must be called after Highlighter.apply.
    private func applyTimestampTooltips(to textView: NSTextView) {
        guard !timestampKeys.isEmpty, let storage = textView.textStorage else { return }

        let str = textView.string
        guard !str.isEmpty else { return }

        let keyAlternation = timestampKeys
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let pattern = "\"(\(keyAlternation))\"\\s*:\\s*(-?\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsStr = str as NSString
        let fullRange = NSRange(location: 0, length: nsStr.length)
        let relFormatter = RelativeDateTimeFormatter()

        storage.beginEditing()
        regex.enumerateMatches(in: str, range: fullRange) { match, _, _ in
            guard let match else { return }
            let valueRange = match.range(at: 2)
            guard valueRange.location != NSNotFound,
                  let unixTime = Double(nsStr.substring(with: valueRange)) else { return }

            let date = Date(timeIntervalSince1970: unixTime)
            let absolute = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .medium)
            let relative = relFormatter.localizedString(for: date, relativeTo: Date())
            storage.addAttribute(.toolTip, value: "\(absolute)  ·  \(relative)", range: valueRange)
        }
        storage.endEditing()
    }

    // MARK: - Coordinator (Task 2.2)

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineNumberedTextEditor
        weak var textView: NSTextView?
        weak var gutter: ErrorGutterRulerView?
        weak var diffLayoutManager: DiffLayoutManager?   // Task 3.2 / 3.3
        var hasFocused = false

        init(_ parent: LineNumberedTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            if parent.text != newText {
                parent.text = newText
            }
            // Re-apply highlighting after every edit.
            // NSTextStorage attribute changes do not re-trigger textDidChange.
            switch parent.highlightMode {
            case .json:
                Highlighter.apply(to: textView)
            case .yaml:
                YAMLHighlighter.apply(to: textView)
            }
            // Restore typing attributes so newly typed characters inherit the base style.
            textView.typingAttributes = Highlighter.baseAttributes
            gutter?.needsDisplay = true
        }
    }
}

// MARK: - JSON Syntax Highlighter

enum Highlighter {
    static let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
        .foregroundColor: NSColor.labelColor
    ]

    // Compiled once. Alternation order matters:
    //   Group 1: key string  ("..." followed by optional whitespace then :)
    //   Group 2: string value ("..." NOT followed by :)
    //   Group 3: number
    //   Group 4: true | false | null
    private static let regex: NSRegularExpression? = {
        let pattern = #"("(?:[^"\\]|\\.)*")\s*:|("(?:[^"\\]|\\.)*")|(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)|(true|false|null)"#
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    private static let stringValueColor = NSColor(calibratedRed: 0.133, green: 0.545, blue: 0.133, alpha: 1.0)
    private static let keyFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)

    static func apply(to textView: NSTextView) {
        guard let storage = textView.textStorage,
              let regex = regex else { return }

        let text = textView.string
        guard !text.isEmpty else { return }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        storage.beginEditing()

        // Reset everything to base style first
        storage.setAttributes(baseAttributes, range: fullRange)

        regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }

            if match.range(at: 1).location != NSNotFound {
                // Key: secondary gray, medium weight
                storage.addAttributes([
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: keyFont
                ], range: match.range(at: 1))

            } else if match.range(at: 2).location != NSNotFound {
                // String value: green
                storage.addAttributes([.foregroundColor: stringValueColor], range: match.range(at: 2))

            } else if match.range(at: 3).location != NSNotFound {
                // Number: blue
                storage.addAttributes([.foregroundColor: NSColor.systemBlue], range: match.range(at: 3))

            } else if match.range(at: 4).location != NSNotFound {
                // true/false/null: purple (null stays gray)
                let word = nsText.substring(with: match.range(at: 4))
                let color: NSColor = (word == "null") ? NSColor.secondaryLabelColor : NSColor.systemPurple
                storage.addAttributes([.foregroundColor: color], range: match.range(at: 4))
            }
        }

        storage.endEditing()
    }
}

// MARK: - YAML Syntax Highlighter

enum YAMLHighlighter {
    static let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
        .foregroundColor: NSColor.labelColor
    ]

    // Group 1: keys (word(s) at line start followed by colon)
    // Group 2: comments (# to end of line)
    // Group 3: double-quoted strings
    // Group 4: single-quoted strings
    // Group 5: numbers
    // Group 6: booleans/nulls
    // Group 7: document markers (--- or ...)
    private static let regex: NSRegularExpression? = {
        let pattern = #"(^\s*[\w][\w\s]*:)|(#.*$)|("(?:[^"\\]|\\.)*")|('(?:[^'\\]|\\.)*')|(-?[0-9]+\.?[0-9]*(?:[eE][+-]?[0-9]+)?)|(\b(?:true|false|yes|no|null|~)\b)|(^---$|^\.\.\.$)"#
        return try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }()

    private static let keyColor = NSColor.secondaryLabelColor
    private static let keyFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
    private static let commentColor = NSColor.systemGreen
    private static let stringColor = NSColor(calibratedRed: 0.133, green: 0.545, blue: 0.133, alpha: 1.0)
    private static let numberColor = NSColor.systemBlue
    private static let boolNullColor = NSColor.systemPurple
    private static let markerColor = NSColor.systemOrange

    static func apply(to textView: NSTextView) {
        guard let storage = textView.textStorage,
              let regex = regex else { return }

        let text = textView.string
        guard !text.isEmpty else { return }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: fullRange)

        regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }

            if match.range(at: 1).location != NSNotFound {
                storage.addAttributes([.foregroundColor: keyColor, .font: keyFont], range: match.range(at: 1))
            } else if match.range(at: 2).location != NSNotFound {
                storage.addAttributes([.foregroundColor: commentColor], range: match.range(at: 2))
            } else if match.range(at: 3).location != NSNotFound {
                storage.addAttributes([.foregroundColor: stringColor], range: match.range(at: 3))
            } else if match.range(at: 4).location != NSNotFound {
                storage.addAttributes([.foregroundColor: stringColor], range: match.range(at: 4))
            } else if match.range(at: 5).location != NSNotFound {
                storage.addAttributes([.foregroundColor: numberColor], range: match.range(at: 5))
            } else if match.range(at: 6).location != NSNotFound {
                let word = nsText.substring(with: match.range(at: 6))
                let color: NSColor = (word == "null" || word == "~") ? NSColor.secondaryLabelColor : boolNullColor
                storage.addAttributes([.foregroundColor: color], range: match.range(at: 6))
            } else if match.range(at: 7).location != NSNotFound {
                storage.addAttributes([.foregroundColor: markerColor], range: match.range(at: 7))
            }
        }

        storage.endEditing()
    }
}

// MARK: - Gutter Ruler View (Tasks 2.3, 2.4, 2.5, 2.6)

final class ErrorGutterRulerView: NSRulerView {
    var errorLine: Int?
    var errorMessage: String?

    private var popover: NSPopover?

    static let gutterWidth: CGFloat = 44

    // NSTextView is flipped (Y increases downward). The ruler must match so
    // line-fragment Y coordinates map correctly into the ruler's drawing space.
    override var isFlipped: Bool { true }

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        ruleThickness = Self.gutterWidth
        addGestureRecognizer()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func addGestureRecognizer() {
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(click)
    }

    // MARK: Drawing (Task 2.3, 2.5)

    override func drawHashMarksAndLabels(in rect: CGRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager else { return }

        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 2, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        // Draw background
        NSColor.windowBackgroundColor.withAlphaComponent(0.95).setFill()
        bounds.fill()

        // Draw separator line on right edge
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height).fill()

        let text = textView.string as NSString
        let fullRange = NSRange(location: 0, length: text.length)

        var lineNumber = 1

        layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(forCharacterRange: fullRange, actualCharacterRange: nil)) { _, usedRect, _, _, _ in
            let lineRect = usedRect
            let lineY = lineRect.minY - visibleRect.minY

            if lineY + lineRect.height < 0 || lineY > self.bounds.height {
                lineNumber += 1
                return
            }

            if lineNumber == self.errorLine {
                // Draw warning icon (Task 2.5)
                let warningAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular),
                    .foregroundColor: NSColor.systemOrange
                ]
                let attrStr = NSAttributedString(string: "⚠", attributes: warningAttrs)
                let strSize = attrStr.size()
                let drawX = self.bounds.width - strSize.width - 6
                let drawY = lineY + (lineRect.height - strSize.height) / 2
                attrStr.draw(at: CGPoint(x: drawX, y: drawY))
            } else {
                let numStr = "\(lineNumber)" as NSString
                let strSize = numStr.size(withAttributes: attrs)
                let drawX = self.bounds.width - strSize.width - 8
                let drawY = lineY + (lineRect.height - strSize.height) / 2
                numStr.draw(at: CGPoint(x: drawX, y: drawY), withAttributes: attrs)
            }

            lineNumber += 1
        }
    }

    // MARK: Click Handling (Task 2.6)

    @objc private func handleClick(_ recognizer: NSClickGestureRecognizer) {
        guard let errorLine, let errorMessage else { return }

        let clickPoint = recognizer.location(in: self)
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager else { return }

        let visibleRect = scrollView?.contentView.bounds ?? .zero
        var lineNumber = 1

        let text = textView.string as NSString
        let fullRange = NSRange(location: 0, length: text.length)

        layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(forCharacterRange: fullRange, actualCharacterRange: nil)) { _, usedRect, _, _, _ in
            let lineY = usedRect.minY - visibleRect.minY
            if clickPoint.y >= lineY && clickPoint.y <= lineY + usedRect.height && lineNumber == errorLine {
                self.showPopover(errorMessage: errorMessage, near: CGRect(x: 0, y: lineY, width: self.bounds.width, height: usedRect.height))
            }
            lineNumber += 1
        }
    }

    private func showPopover(errorMessage: String, near rect: CGRect) {
        popover?.close()
        let popover = NSPopover()
        popover.behavior = .transient

        let label = NSTextField(wrappingLabelWithString: errorMessage)
        label.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let vc = NSViewController()
        let container = NSView(frame: .zero)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.widthAnchor.constraint(equalToConstant: 300)
        ])
        vc.view = container

        popover.contentViewController = vc
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxX)
        self.popover = popover
    }
}
