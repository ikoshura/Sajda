// MARK: - GANTI SELURUH FILE: TimePreviewPopover.swift (VERSI SOLID COLOR & STABIL)

import SwiftUI

struct TimePreviewPopover: View {
    let originalTime: Date
    let adjustedTime: Date
    let formatter: DateFormatter

    var body: some View {
        HStack(spacing: 6) {
            Text(formatter.string(from: originalTime))
                .font(.caption)
                .foregroundColor(Color("SecondaryTextColor"))
                .strikethrough(color: Color("SecondaryTextColor"))
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(Color("SecondaryTextColor"))
            
            Text(formatter.string(from: adjustedTime))
                .font(.caption.weight(.semibold))
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        // PERBAIKAN: Gunakan background solid color yang native dan stabil
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
        )
    }
}
