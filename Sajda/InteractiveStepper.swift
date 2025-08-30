// MARK: - BUAT FILE BARU: Sajda/InteractiveStepper.swift
// (Hapus file SimpleStepper.swift sebelumnya)
// Salin dan tempel SELURUH kode ini ke dalam file baru ini.

import SwiftUI

struct InteractiveStepper: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = -60...60
    
    // State untuk hover efek
    @State private var isMinusHovering = false
    @State private var isPlusHovering = false
    @State private var isValueHovering = false
    
    // Timer untuk long-press
    @State private var minusTimer: Timer?
    @State private var plusTimer: Timer?
    @State private var isMinusPressed = false
    @State private var isPlusPressed = false

    private func handleMinusPress(isPressing: Bool) {
        self.isMinusPressed = isPressing
        if isPressing {
            value = max(value - 1, range.lowerBound)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard self.isMinusPressed else { return }
                self.minusTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    self.value = max(self.value - 1, self.range.lowerBound)
                }
            }
        } else {
            minusTimer?.invalidate()
            minusTimer = nil
        }
    }
    
    private func handlePlusPress(isPressing: Bool) {
        self.isPlusPressed = isPressing
        if isPressing {
            value = min(value + 1, range.upperBound)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard self.isPlusPressed else { return }
                self.plusTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    self.value = min(self.value + 1, self.range.upperBound)
                }
            }
        } else {
            plusTimer?.invalidate()
            plusTimer = nil
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            // Tombol Minus dengan hover efek
            Button(action: {}) {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(isMinusHovering ? 0.25 : 0))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isMinusHovering = hovering }
            .onLongPressGesture(minimumDuration: .infinity, pressing: handleMinusPress, perform: {})
            
            // --- PERBAIKAN: ZStack untuk nilai dan tombol reset ---
            ZStack {
                // Tombol Reset (lapisan atas)
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    // Hanya muncul saat hover & nilai bukan nol
                    .opacity(isValueHovering && value != 0 ? 1 : 0)
                
                // Tampilan Nilai (lapisan bawah)
                Text(String(format: "%+.0f", value))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    // Sembunyi saat reset muncul
                    .opacity(isValueHovering && value != 0 ? 0 : 1)
            }
            .frame(minWidth: 40)
            .padding(.horizontal, 4)
            .onHover { hovering in
                // Animasikan perubahan saat hover
                withAnimation(.easeInOut(duration: 0.15)) {
                    isValueHovering = hovering
                }
            }
            .onTapGesture {
                // Aksi reset hanya jika ikon terlihat
                if isValueHovering && value != 0 {
                    withAnimation(.spring()) {
                        value = 0
                    }
                }
            }

            // Tombol Plus dengan hover efek
            Button(action: {}) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(isPlusHovering ? 0.25 : 0))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isPlusHovering = hovering }
            .onLongPressGesture(minimumDuration: .infinity, pressing: handlePlusPress, perform: {})
        }
    }
}
