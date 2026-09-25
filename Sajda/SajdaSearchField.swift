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
struct SajdaSearchField: View {
    /// Localized placeholder — a `LocalizedStringKey` so literals at the call
    /// sites stay translatable against `Localizable.strings`.
    let placeholder: LocalizedStringKey

    @Binding var text: String

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
                    isFocused ? Color.accentColor : Color("BorderColor"),
                    lineWidth: isFocused ? 1 : 0.5
                )
            }
            .contentShape(shape)
    }
}
