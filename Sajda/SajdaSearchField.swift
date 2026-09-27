// MARK: - Sajda/SajdaSearchField.swift
//
// Search-field chrome shared by the mosque and city search forms.

import SwiftUI

/// Rounded search field drawn entirely with the panel's own adaptive colours.
///
/// Why not `.textFieldStyle(.roundedBorder)`: that bezel is AppKit drawing
/// whose appearance resolves lazily, and this panel is a non-activating
/// `NSPanel` whose whole content is re-laid out and animated on every page
/// switch. When that resolution lands a frame or two late, the field shows up
/// as a black rectangle mid-transition — the "blinking black" the search forms
/// used to do. Drawing the chrome here keeps every frame on `ButtonFaceColor`
/// / `BorderColor`, exactly like the rest of the panel, so the worst case is
/// one frame of the field's own background.
///
/// The focus ring is drawn here too: `.plain` gives up the native one, and
/// without it a focused field would be indistinguishable from an idle one.
///
/// The ring takes an explicit `accent` rather than `Color.accentColor`: the
/// app's accent-panel theme flips the *colour scheme*, not the system accent,
/// so a user-picked highlight colour (Visual → Highlight) never reached
/// `Color.accentColor` and every search field kept a blue ring that clashed
/// with the rest of the panel. Call sites pass `vm.selectedHighlightColor`.
struct SajdaSearchField: View {
    /// Localized placeholder — a `LocalizedStringKey` so literals at the call
    /// sites stay translatable against `Localizable.strings`.
    let placeholder: LocalizedStringKey

    @Binding var text: String

    /// Focus-ring colour. Defaults to the system accent for any call site
    /// that has no view model to read the custom highlight from.
    var accent: Color = .accentColor

    @FocusState private var isFocused: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .scaledFont(.subheadline)
            .focused($isFocused)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background {
                shape.fill(Color("ButtonFaceColor"))
            }
            .overlay {
                shape.strokeBorder(
                    isFocused ? accent : Color("BorderColor"),
                    lineWidth: isFocused ? 1 : 0.5
                )
            }
            .contentShape(shape)
    }
}
