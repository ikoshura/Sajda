// MARK: - SettingsAccordion.swift
//
// Single-open accordion header + collapsible content for the Settings root
// page. Collapsed it is just one compact row (title + chevron); expanding
// reveals the group's rows inline. The parent owns which section is open so
// opening one group always closes the previous one.
//
// Expand/collapse drives the menu height through `Animation.sajdaAccordion`
// (a slow 0.38 s smooth curve), so the panel and the MenuBarExtra window
// resize in lockstep. The reveal itself is `AccordionReveal`: the content
// stays in the tree and its height animates between its natural size and zero.
// It used to be a `move` + `fade` transition, which either flew the rows over
// the content above them on the way in or stranded a ghost copy of them there
// on the way out — read the header note on that type before putting a
// transition back. This view applies the curve to `onToggle` itself, because a
// height change needs an animation in context and callers cannot be expected
// to know that.

import SwiftUI

/// Accordion section used on the Settings page: a hover-highlighted header
/// row that toggles an inline content block underneath it.
///
/// - `titleKey`: Localizable.strings key for the header title.
/// - `collapsedChevron`: chevron shown when collapsed (callers pass
///   `vm.forwardChevron` so RTL layouts mirror correctly); expanded state
///   always shows `chevron.up`.
/// - `onToggle`: flips the parent's single-open section state (instant swap — see top note).
struct SettingsAccordion<Content: View>: View {
    let titleKey: String
    let isExpanded: Bool
    let collapsedChevron: String
    let onToggle: () -> Void
    /// Horizontal inset the header row and the expanded content add *inside*
    /// the accordion, on top of whatever padding the page already applies.
    /// The default (8 + 5 = 13) is what the About page's content wants; a page
    /// whose surrounding rows already sit flush at their own padding passes 0
    /// so the header and its content line up with them instead of stepping in.
    var horizontalInset: CGFloat = 13
    @ViewBuilder let content: Content

    /// Gap between the collapse and the expand when switching sections
    /// (single-open): long enough that both contents never overlap
    /// mid-animation, short enough to still feel like one motion.
    static var switchDelay: Double { 0.22 }

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The animation is applied *here*, not left to the caller's
            // `onToggle`, because it is this view's frame that has to animate
            // and a caller cannot know that. The old reveal was a
            // `.transition`, which SwiftUI runs even with no animation in
            // context, so callers got a moving reveal for free. `AccordionReveal`
            // animates a height instead, and a frame change is a plain layout
            // mutation — with nothing wrapping the state change it applies
            // instantly and the accordion snaps open with no motion at all,
            // which is exactly what happened when this was first wired up.
            //
            // Wrapping the call (rather than mutating a binding) keeps the
            // single-open callers, which toggle their own `@State`, working
            // unchanged.
            Button(action: { withAnimation(.sajdaAccordion) { onToggle() } }) {
                HStack {
                    Text(LocalizedStringKey(titleKey))
                        .scaledFont(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : collapsedChevron)
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .liquidHover(isHovering)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, horizontalInset - 8)
            .onHover { hovering in isHovering = hovering }

            // Always in the tree, revealed by height: see `AccordionReveal` for
            // why an `if` + transition strands a ghost copy of the rows over
            // the content above them while the panel resizes. The old
            // `.opacity` + `.move` combo had both halves of that problem — the
            // slide painted over the row above on the way in, the fade left the
            // ghost on the way out.
            //
            // The 12pt spacing and the padding stay on the content itself, so
            // the geometry the callers tuned is unchanged; only the reveal
            // mechanism moved.
            AccordionReveal(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                // Same geometry as the header row above it (the same 8 + inset
                // split) so the expanded rows' text sits flush under the
                // section title — and flush with the sub-page buttons too.
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .padding(.horizontal, horizontalInset - 8)
            }
        }
    }
}
