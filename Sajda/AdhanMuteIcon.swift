// MARK: - AdhanMuteIcon: modern per-prayer adhan toggle
//
// Ring-and-dot in the modern reference:
// - adhan ON (active): ring + centred dot in one colour — white on the
//   highlighted row (for contrast against the fill), the selected highlight
//   colour (custom pick, or the system accent) everywhere else.
// - adhan OFF (muted): the same colour, dot only, no ring — the state is
//   carried by the shape, never by a second colour.
//
// The icon takes a single `activeColor` and every shape uses it, so the dot can
// never drift from its ring. Callers pass white on the highlighted row (for
// contrast against the fill) and `vm.muteIconColor` everywhere else — the
// system secondary when the accent isn't in play, the highlight colour when it
// is.
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
    /// Ring + dot colour, in *both* states and for *both* shapes. Callers pass
    /// white on the highlighted row (for contrast against the fill) and
    /// `vm.muteIconColor` everywhere else — the system secondary when the
    /// accent isn't in play, the highlight colour when it is.
    var activeColor: Color = .accentColor
    var size: CGFloat = 13
    /// Opacity of the ring, the outer shape. It carries far more ink than the
    /// dot at the same alpha — a 1.8pt stroke versus a small antialiased disc —
    /// so the two need different alphas to *look* like one colour. Drawing them
    /// at the same alpha left the dot reading as washed out inside a solid ring;
    /// shrinking the dot to compensate instead just made it a blob.
    ///
    /// Defaults to 1.0, i.e. no dimming: the dimmed treatment is opt-in and
    /// belongs only to the calm secondary-colour ring (see
    /// `vm.isMuteIconDimmed`), never to a user's own accent at full strength.
    var ringOpacity: Double = 1
    /// Opacity of the centre dot, kept *higher* than the ring's while dimmed for
    /// the same reason in reverse: at a shared alpha the dot looked half-erased
    /// next to a solid ring. At the default 1.0/1.0 the two are simply the
    /// original full-strength ring and dot.
    var dotOpacity: Double = 1
    /// Colour of the centre dot *in the muted state only*, when it needs to
    /// differ from `activeColor`. `nil` (the default) keeps the single-colour
    /// rule: one colour for every shape, with on/off carried by the shape.
    ///
    /// Exists for plain accent mode, where a muted prayer would otherwise draw
    /// a full-strength accent dot — the same accent as the next-prayer
    /// highlight, so muting four of five rows still left the panel reading
    /// "every prayer is highlighted". There the dot drops to the system
    /// secondary, which is what the ring already does in the other two modes.
    /// Never applied to the un-muted state: the dot has to match its ring then.
    var mutedDotColor: Color?

    /// The centre dot, in both states. One size, so muting never resizes it —
    /// only the ring appears and disappears around it.
    private var dotSize: CGFloat { size * 0.42 }

    var body: some View {
        ZStack {
            if muted {
                // Dot only — no ring. The on/off difference is carried by the
                // shape, never by a second colour, with one exception:
                // `mutedDotColor`, which lets the muted dot step down to the
                // system secondary in plain accent mode. A hardcoded grey here
                // once meant a muted row's dot ignored the caller's colour
                // entirely, so a highlighted row's muted dot was grey on an
                // accent fill and the two states stopped looking like the same
                // control — hence a caller-supplied colour rather than a
                // built-in one. The dot keeps `dotOpacity` in this state, so
                // muting only removes the ring.
                Circle()
                    .fill(mutedDotColor ?? activeColor)
                    .opacity(dotOpacity)
                    .frame(width: dotSize, height: dotSize)
            } else {
                Circle()
                    .fill(activeColor)
                    .opacity(dotOpacity)
                    .frame(width: dotSize, height: dotSize)
                Circle()
                    .stroke(activeColor, lineWidth: 1.8)
                    .opacity(ringOpacity)
                    .frame(width: size, height: size)
            }
        }
        // Square, centred, identical in both states: no drift, no column shift.
        .frame(width: size, height: size)
    }
}

/// The per-prayer adhan toggle in whichever glyph the user picked, and in the
/// state its own style defines.
///
/// The four styles disagree on purpose, and that disagreement is the whole
/// point of the setting, so it is spelled out here rather than smoothed over:
///
/// - `.halo` — ring + dot, the original. Shape carries the state: ring present
///   when the adhan will play, dot alone when it won't.
/// - `.bell` and `.speaker` — filled SF Symbols, the *same* rule as the Adhan
///   Sound page: unslashed while the adhan will play, slashed when it won't. A
///   bell doesn't have a natural "ring, no ring" shape, so it can't borrow the
///   halo's encoding — it uses the slash, which is unambiguous.
/// - `.none` — draws nothing but keeps the button, its hit target, its tooltip
///   and its accessibility label. "No icon" has to stay *usable*: a hidden
///   control that can't be clicked would be a worse panel than no setting.
///
/// Every style draws inside the same square frame, so switching styles never
/// changes the row height or shifts the time column.
struct AdhanMuteButtonIcon: View {
    var style: MuteIconStyle
    /// Whether this prayer's adhan is muted — i.e. whether the button is
    /// currently *off*.
    var muted: Bool
    /// Colour for the glyph. Callers pass white or the row's own text colour on
    /// the highlighted row (for contrast against the fill) and
    /// `vm.muteIconColor` everywhere else.
    var color: Color
    var size: CGFloat = 13
    /// Halo only: the ring and dot alphas. Ignored by the glyph styles, which
    /// take a single colour.
    var ringOpacity: Double = 1
    var dotOpacity: Double = 1
    /// Halo only: colour for the dot in the muted state, when it differs.
    var mutedDotColor: Color?

    var body: some View {
        Group {
            switch style {
            case .halo:
                AdhanMuteIcon(
                    muted: muted,
                    activeColor: color,
                    size: size,
                    ringOpacity: ringOpacity,
                    dotOpacity: dotOpacity,
                    mutedDotColor: mutedDotColor
                )
            case .bell, .speaker:
                Image(systemName: glyphName)
                    .font(.system(size: size - 1))
                    // Muted drops to the system secondary in every mode, the
                    // same as the Adhan Sound page's speaker. The shape already
                    // says "muted", and in plain accent mode the accent is also
                    // the next-prayer highlight — a full-strength accent slash
                    // would paint the highlight's colour on rows the user had
                    // deliberately opted out of.
                    .foregroundColor(muted && !isOnHighlight ? Color.secondary : color)
            case .none:
                // Nothing drawn, but the frame is kept so the hit target and
                // the cell width match every other style.
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }

    /// Set by the panel for the highlighted row, where a `.secondary` slash
    /// would be unreadable against the fill. Defaults to false so a caller that
    /// doesn't care keeps the calm muted colour.
    var isOnHighlight: Bool = false

    /// Symbol name for the glyph styles, in the current state.
    ///
    /// The unmuted speaker is the *waved* one, matching the Adhan Sound page:
    /// a bare filled cone next to a slashed one differs by the slash alone,
    /// which left the active row looking like a hole where the sound should be.
    /// The bell has no waves to add, so it uses the plain filled form and
    /// relies on the same slash to carry the muted state.
    private var glyphName: String {
        switch (style, muted) {
        case (.bell, false): return "bell.fill"
        case (.bell, true): return "bell.slash.fill"
        case (.speaker, false): return "speaker.wave.2.fill"
        case (.speaker, true): return "speaker.slash.fill"
        case (.halo, _), (.none, _): return ""   // never drawn; see `body`
        }
    }
}
