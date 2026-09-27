// MARK: - AdhanMuteIcon: modern per-prayer adhan toggle
//
// Ring-and-dot in the modern reference:
// - adhan ON (active): white ring + centred white dot (the row's highlight
//   text colour, which is white on the highlighted row).
// - adhan OFF (muted): grey dot only, no ring.
//
// One glyph, no speaker waves, no slash — the slash variant read as
// "broken audio" at 11pt rather than "muted by choice".
//
// Sizes: the prayer-list rows render it at 13pt; the Adhan Sound settings
// rows pass an explicit 12pt so it matches their pickers. The glyph frame is
// always square and both states share the same outer size, so the time
// column never shifts when toggling.

import SwiftUI

struct AdhanMuteIcon: View {
    var muted: Bool
    /// Ring + dot colour when on (the row's highlight/text colour).
    var activeColor: Color = .primary
    var size: CGFloat = 13

    var body: some View {
        ZStack {
            if muted {
                // Grey dot only — no ring.
                Circle()
                    .fill(Color.secondary.opacity(0.55))
                    .frame(width: size * 0.46, height: size * 0.46)
            } else {
                // White ring + centred white dot.
                Circle()
                    .stroke(activeColor, lineWidth: 1.8)
                    .frame(width: size, height: size)
                Circle()
                    .fill(activeColor)
                    .frame(width: size * 0.42, height: size * 0.42)
            }
        }
        // Square, centred, identical in both states: no drift, no column shift.
        .frame(width: size, height: size)
    }
}
