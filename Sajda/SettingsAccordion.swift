// MARK: - SettingsAccordion.swift
//
// Single-open accordion header + collapsible content for the Settings root
// page. Collapsed it is just one compact row (title + chevron); expanding
// reveals the group's rows inline. The parent owns which section is open so
// opening one group always closes the previous one.
//
// Expand/collapse drives the menu height through `SettingsAccordion.animation`
// (a slow 0.38 s smooth curve), so the panel and the MenuBarExtra window
// resize in lockstep (see `toggleSection` call sites). Content reveals with
// a height slide + fade and is clipped, so rows never visibly fly or flash
// outside the bounds while the window slides to its new size.

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
    @ViewBuilder let content: Content

    /// Slow, calm expand/collapse curve so the toggle feels smooth rather
    /// than shocking. Deliberately slower than the snappy
    /// `.macControlCenterMenuResize` (0.2 s) window snap — the panel window
    /// tracks the animating content size frame-by-frame, so stretching the
    /// SwiftUI animation stretches the whole resize with it.
    static var animation: Animation {
        .smooth(duration: 0.38, extraBounce: 0)
    }
    /// Gap between the collapse and the expand when switching sections
    /// (single-open): long enough that both contents never overlap
    /// mid-animation, short enough to still feel like one motion.
    static var switchDelay: Double { 0.22 }

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(LocalizedStringKey(titleKey))
                        .scaledFont(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : collapsedChevron)
                        .scaledFont(.caption, weight: .bold)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .liquidHover(isHovering)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5)
            .onHover { hovering in isHovering = hovering }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                // Same geometry as the header row above it (outer 5 +
                // inner 8) so the expanded rows' text sits flush under the
                // section title — and flush with the sub-page buttons too.
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .padding(.horizontal, 5)
                // Slow height reveal + fade together: the window frame
                // animation tracks the animating content size, so this one
                // curve drives the smooth panel resize. Clipped so rows never
                // flash outside the bounds mid-animation.
                .transition(.opacity.combined(with: .move(edge: .top)))
                .clipped()
            }
        }
    }
}
