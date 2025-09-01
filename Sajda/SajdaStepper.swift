// MARK: - GANTI SELURUH FILE: Sajda/SajdaStepper.swift

import SwiftUI

struct SajdaStepper: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = -60...60
    var step: Double = 1

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    
    @State private var isMinusHovering = false
    @State private var isPlusHovering = false

    var body: some View {
        HStack(spacing: 2) {
            // Tombol Minus
            Button(action: {
                if value > range.lowerBound { value -= step }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(isMinusHovering ? Color("HoverColor") : .clear)
            .cornerRadius(4)
            .onHover { hovering in isMinusHovering = hovering }

            // TextField Nilai
            TextField("", text: $textValue, onCommit: {
                updateValue(from: textValue)
            })
            .font(.system(size: 12, design: .monospaced))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .frame(width: 35)
            .focused($isFocused)
            
            // Tombol Plus
            Button(action: {
                if value < range.upperBound { value += step }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(isPlusHovering ? Color("HoverColor") : .clear)
            .cornerRadius(4)
            .onHover { hovering in isPlusHovering = hovering }
        }
        .onAppear { textValue = formatValue(value) }
        .onChange(of: value) { newValue in textValue = formatValue(newValue) }
        .onChange(of: isFocused) { focused in
            if !focused { updateValue(from: textValue) }
        }
        .controlSize(.mini)
    }

    private func formatValue(_ val: Double) -> String {
        String(format: "%+.0f", val)
    }

    private func updateValue(from text: String) {
        if let newDouble = Double(text) {
            value = min(max(newDouble.rounded(), range.lowerBound), range.upperBound)
        }
        textValue = formatValue(value)
    }
}
