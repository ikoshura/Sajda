// MARK: - GANTI SELURUH FILE: StyledToggle.swift (PERBAIKAN WARNA BACKGROUND 'OFF')

import SwiftUI

struct StyledToggle: View {
    var label: LocalizedStringKey
    @Binding var isOn: Bool
    
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.panelFontScale) private var fontScale

    // Dimensi switch mengikuti preset Text Size panel agar kontrol tetap
    // proporsional dengan label di sampingnya.
    private var toggleWidth: CGFloat { 32 * fontScale }
    private var toggleHeight: CGFloat { 18 * fontScale }
    private var thumbSize: CGFloat { 14 * fontScale }

    var body: some View {
        HStack {
            Text(label)
                .scaledFont(.subheadline)
            Spacer()
            
            ZStack {
                Capsule()
                    // --- PERBAIKAN UTAMA DI SINI ---
                    // Gunakan "HoverColor" untuk state 'off' agar terlihat di Light Mode
                    .fill(isOn ? Color.accentColor : Color("HoverColor"))
                    .frame(width: toggleWidth, height: toggleHeight)
                    // Subtle specular rim so the custom toggle sits comfortably
                    // on Liquid Glass surfaces.
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(isOn ? 0.28 : 0.15), lineWidth: 0.5)
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                    .padding(.horizontal, 2)
            }
            .frame(width: toggleWidth, height: toggleHeight)
        }
        // Membuat seluruh baris dapat diklik untuk usability yang lebih baik
        .contentShape(Rectangle())
        .onTapGesture {
            if isEnabled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            }
        }
        .saturation(isEnabled ? 1.0 : 0.0)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}
