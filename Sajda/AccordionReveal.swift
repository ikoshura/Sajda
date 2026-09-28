// MARK: - Sajda/AccordionReveal.swift
//
// The one way an accordion in this panel opens and closes.
//
// It replaced three separate `if` + `.transition` implementations, each of
// which had the same defect in one form or another:
//
// * `.move(edge: .top)` draws the incoming content travelling *upward* out of
//   its own slot, so for the length of the reveal it painted over whatever
//   rows sit above the accordion.
// * `.opacity` fixes the way in, but SwiftUI keeps a removed view in its old
//   frame for the length of the transition while its neighbours reflow, so the
//   fade *out* stranded a ghost copy over those same rows — and clipped the
//   panel's own bottom edge while it did.
// * Overlaying the fade on top of a height animation gave two animations of the
//   same content in the same frame; near the end of a collapse the rows are a
//   sliver tall and still fading, which read as text flickering.
//
// The fix is to stop unmounting the content. It stays in the tree at its
// natural height and this view animates a frame between that height and zero,
// so the panel resizes through a plain layout animation with no outgoing copy
// and no second animation to fight. `.clipped()` keeps the content inside the
// shrinking frame, and hit testing plus accessibility are gated while shut.
//
// The height is measured rather than hardcoded — accordion content is made of
// rows whose count is not known here, and on the Location page it changes as
// favorites are added and inline searches open.

import SwiftUI

/// Reveals `content` by animating its height, for accordions in a panel that
/// resizes to fit its content.
///
/// - Parameter isExpanded: whether the accordion is currently open.
/// - Parameter content: the collapsible content. Always built, even while
///   shut — keep it cheap, and be aware that its `@State` survives a collapse.
///   The old unmount reset that state for free; now it does not, so a
///   caller whose content must not remember anything across a collapse has to
///   request that reset itself (see how `MainView` folds
///   `FavoritesSection`'s inline searches on close).
struct AccordionReveal<Content: View>: View {
    let isExpanded: Bool
    @ViewBuilder let content: Content

    @State private var naturalHeight: CGFloat = 0

    var body: some View {
        content
            // Load-bearing, and it has to sit on the content rather than on the
            // frame below: a `.frame(height:)` *proposes* its height to the view
            // it wraps, so without this the content is asked to lay itself out
            // inside a shrinking box. It compresses, the reader reports the
            // squeezed height back, and that feeds into the frame again — a
            // feedback loop that leaves the panel mis-sized. `fixedSize` opts
            // out of the proposal, so the measurement is always the natural
            // height no matter what the frame is doing.
            .fixedSize(horizontal: false, vertical: true)
            // Before the frame for the same reason: `background` takes the size
            // of the view it decorates, so behind the frame the reader would
            // only ever see the clipped height and report zero.
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { naturalHeight = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, new in
                            naturalHeight = new
                        }
                }
            }
            .frame(height: isExpanded ? naturalHeight : 0, alignment: .top)
            .clipped()
            .allowsHitTesting(isExpanded)
            // Still in the tree while it looks shut, so VoiceOver would
            // otherwise walk a list the user cannot see.
            .accessibilityHidden(!isExpanded)
    }
}
