// MARK: - GANTI SELURUH FILE: StyledToggle.swift (PERBAIKAN WARNA BACKGROUND 'OFF')

import SwiftUI

struct StyledToggle: View {
    var label: LocalizedStringKey
    @Binding var isOn: Bool
    
    @Environment(\.isEnabled) private var isEnabled

    private let toggleWidth: CGFloat = 32
    private let toggleHeight: CGFloat = 18
    private let thumbSize: CGFloat = 14

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            
            ZStack {
                Capsule()
                    // --- PERBAIKAN UTAMA DI SINI ---
                    // Gunakan "HoverColor" untuk state 'off' agar terlihat di Light Mode
                    .fill(isOn ? Color.accentColor : Color("HoverColor"))
                    .frame(width: toggleWidth, height: toggleHeight)

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
