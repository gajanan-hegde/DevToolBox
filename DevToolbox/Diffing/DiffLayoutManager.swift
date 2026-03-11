import AppKit

// MARK: - DiffLayoutManager (Tasks 2.1, 2.2, 2.3)

/// A custom NSLayoutManager that draws full-width coloured background bands
/// behind changed lines before the normal text-drawing pass.
///
/// Callers set `lineHighlights` with (characterRange, color) pairs.
/// `drawBackground` fires before glyph drawing, so syntax-highlighted text
/// renders on top of the diff colours.
final class DiffLayoutManager: NSLayoutManager {

    /// Character ranges + colours to paint as full-width background bands.
    /// Set from the main thread via `updateNSView`; read during drawing on the
    /// main thread - no synchronisation needed.
    var lineHighlights: [(characterRange: NSRange, color: NSColor)] = []

    // MARK: - Drawing (Tasks 2.2, 2.3)

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        // Draw our diff backgrounds BEFORE calling super so that:
        //   1. Our coloured bands sit under the text glyphs.
        //   2. NSBackgroundColorAttributeName (unused in our highlighter) and
        //      the selection highlight drawn by super appear above our bands.
        if !lineHighlights.isEmpty {
            drawDiffBackgrounds(forGlyphRange: glyphsToShow, at: origin)
        }
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    }

    // MARK: - Private helpers

    private func drawDiffBackgrounds(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        for (charRange, color) in lineHighlights {
            guard charRange.location != NSNotFound else { continue }

            // Convert character range → glyph range
            let glyphRange = self.glyphRange(forCharacterRange: charRange,
                                             actualCharacterRange: nil)

            // Only draw highlights that overlap the currently-rendered glyph band
            let intersection = NSIntersectionRange(glyphRange, glyphsToShow)

            // For empty lines the glyph range has length 0; treat those specially
            // so blank diff rows still get a background band.
            let drawRange: NSRange
            if glyphRange.length == 0 {
                // An empty line lives at the edge of the visible range; only draw
                // if its glyph position falls within glyphsToShow.
                let pos = glyphRange.location
                guard pos >= glyphsToShow.location &&
                      pos <= NSMaxRange(glyphsToShow) else { continue }
                drawRange = NSRange(location: pos, length: 0)
            } else {
                guard intersection.length > 0 else { continue }
                drawRange = intersection
            }

            color.setFill()

            // Enumerate line fragments and paint a full-width rect for each.
            // Task 2.3: size.width is set large (10 000 pt) so the band reaches
            // beyond the visible viewport; NSView clips drawing to its bounds.
            enumerateLineFragments(forGlyphRange: drawRange) { rect, _, _, _, _ in
                var fillRect = rect
                fillRect.origin.x    = origin.x       // start at left edge of container
                fillRect.origin.y   += origin.y        // offset into drawing context
                fillRect.size.width  = 10_000          // full width (clipped by view bounds)
                NSBezierPath(rect: fillRect).fill()
            }

            // Handle zero-length glyph ranges (truly empty lines): get the
            // bounding rect at that glyph position and paint a full-width band.
            if drawRange.length == 0 {
                let rect = lineFragmentRect(forGlyphAt: max(0, drawRange.location - 1),
                                            effectiveRange: nil)
                var fillRect       = rect
                fillRect.origin.x  = origin.x
                fillRect.origin.y += origin.y
                fillRect.size.width = 10_000
                NSBezierPath(rect: fillRect).fill()
            }
        }
    }
}
