// MARK: - AdhanMuteIcon: modern per-prayer adhan toggle
//
// Minimal ring-and-dot in the modern reference: a thin ring with a centred
// dot when the adhan is on (tinted with the row's highlight colour so it
// blends with the panel's interactive accents), a faint ring alone when
// muted. One glyph, no speaker waves, no slash — the slash variant read as
// "broken audio" at 11pt rather than "muted by choice".
//
// Sizes: the prayer-list rows render it at `.caption`; the Adhan Sound
// settings rows pass an explicit 12pt so it matches their pickers.

import SwiftUI

struct AdhanMuteIcon: View {
    var muted: Bool
    /// Filled-dot colour when on (the row's highlight/text colour).
    var activeColor: Color = .secondary
    var size: CGFloat = 11

    var body: some View {
        ZStack {
            // Ring: full strength when on, faint when muted.
            Circle()
                .stroke(muted ? Color.secondary.opacity(0.35) : activeColor, lineWidth: 1.6)
                .frame(width: size, height: size)
            // Dot: present only when on.
            if !muted {
                Circle()
                    .fill(activeColor)
                    .frame(width: size * 0.42, height: size * 0.42)
            }
        }
        .frame(width: 16, height: 14)
    }
}
