// MARK: - BUAT FILE BARU: Sajda/TimePreviewPopover.swift

import SwiftUI

struct TimePreviewPopover: View {
    let originalTime: Date
    let adjustedTime: Date
    let formatter: DateFormatter

    /// Selected highlight colour, read straight from defaults (the same
    /// pattern as `StyledToggle`) so the preview follows a swatch change
    /// without needing the view model in the environment.
    @AppStorage("customHighlightColorHex") private var customHighlightColorHex = ""

    private var adjustedColor: Color {
        PrayerTimeViewModel.controlTint(fromHighlightHex: customHighlightColorHex) ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(formatter.string(from: originalTime))
                .scaledFont(.caption)
                .foregroundColor(.secondary)
                .strikethrough(color: .secondary)
            
            Image(systemName: "arrow.right")
                .scaledFont(.caption)
                .foregroundColor(.secondary)
            
            Text(formatter.string(from: adjustedTime))
                .scaledFont(.caption, weight: .semibold)
                .foregroundColor(adjustedColor)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        // Liquid Glass preview card: glass on macOS 26+, solid native window
        // background on older systems.
        .glassCard(cornerRadius: 8)
        // Latar belakang solid yang native dan stabil
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
        )
    }
}
