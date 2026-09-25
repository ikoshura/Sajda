// MARK: - GANTI SELURUH FILE: StyledToggle.swift (NATIVE SWITCH — LIQUID GLASS)

import SwiftUI

/// Settings row: label on the leading edge, the *native* macOS switch on the
/// trailing edge — the same `Toggle(.switch)` pattern as the Sunray-xdr
/// Liquid Glass panel. Using the system control (instead of a hand-drawn
/// capsule) gives the row the native app / Liquid Glass feel for free:
/// system animation, system disabled state, and the macOS 26+ glass styling.
struct StyledToggle: View {
    var label: LocalizedStringKey
    @Binding var isOn: Bool

    /// Selected highlight colour ("#RRGGBB"); empty keeps the system accent.
    /// Read straight from UserDefaults (not through the view model) so the
    /// switch re-renders the moment a swatch is picked in Settings.
    @AppStorage("customHighlightColorHex") private var customHighlightColorHex = ""

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.panelFontScale) private var fontScale

    var body: some View {
        HStack(spacing: 8) {
            // The label and the free space next to it form the tap target,
            // preserving the previous whole-row tap behavior. The gesture is
            // scoped to this sibling of the switch (never an ancestor), so a
            // click on the native control can only be handled once.
            HStack {
                Text(label)
                    .scaledFont(.subheadline)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isEnabled {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isOn.toggle()
                    }
                }
            }
            .opacity(isEnabled ? 1.0 : 0.5)

            // Native macOS switch (Sunray-xdr pattern): label hidden because
            // the row provides its own localized, font-scaled label.
            // `.disabled(...)` applied by callers dims this automatically.
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(nativeControlSize)
                // The on-state uses the selected highlight colour so every
                // switch matches the highlight row and the Accent Panel tint;
                // nil (no colour selected) keeps the system accent.
                .tint(PrayerTimeViewModel.controlTint(fromHighlightHex: customHighlightColorHex))
        }
    }

    /// The switch follows the panel Text Size preset the same way
    /// `ScaledMenuPicker` does, so bigger text gets a natively larger
    /// control instead of a fixed hand-drawn capsule.
    private var nativeControlSize: ControlSize {
        switch fontScale {
        case ..<1.05: return .small
        case ..<1.35: return .regular
        default: return .large
        }
    }
}
