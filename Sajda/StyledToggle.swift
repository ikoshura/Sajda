// Salin dan tempel SELURUH kode ini ke dalam file StyledToggle.swift

import SwiftUI

struct StyledToggle: View {
    var label: String
    @Binding var isOn: Bool

    // PERBAIKAN: Ukuran diperkecil lagi agar sangat-sangat kompak
    private let toggleWidth: CGFloat = 32
    private let toggleHeight: CGFloat = 18
    private let thumbSize: CGFloat = 14

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            
            ZStack {
                Capsule()
                    .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: toggleWidth, height: toggleHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                    .padding(.horizontal, 2)
            }
            .frame(width: toggleWidth, height: toggleHeight)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            }
        }
    }
}
