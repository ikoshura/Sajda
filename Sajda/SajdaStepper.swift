// MARK: - GANTI SELURUH FILE: Sajda/SajdaStepper.swift

import SwiftUI

struct SajdaStepper: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = -60...60
    var step: Double = 1
    /// When false the field shows the bare number (e.g. "10") instead of the
    /// signed form ("+10") used for correction-style values.
    var showsSign: Bool = true
    /// Width of the numeric field between the ± buttons. Rows that hold two
    /// steppers side by side (the Jumu'ah session clocks) pass a narrower field
    /// so the pair, their row number and the delete button still fit the
    /// compact 220 pt panel; those callers scale it with the text preset.
    var fieldWidth: CGFloat = 35

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
            .liquidHover(isMinusHovering, cornerRadius: 4)
            .onHover { hovering in isMinusHovering = hovering }

            // TextField Nilai
            TextField("", text: $textValue, onCommit: {
                updateValue(from: textValue)
            })
            .scaledFont(.callout)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .frame(width: fieldWidth)
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
            .liquidHover(isPlusHovering, cornerRadius: 4)
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
        showsSign ? String(format: "%+.0f", val) : String(format: "%.0f", val)
    }

    private func updateValue(from text: String) {
        if let newDouble = Double(text) {
            value = min(max(newDouble.rounded(), range.lowerBound), range.upperBound)
        }
        textValue = formatValue(value)
    }
}
