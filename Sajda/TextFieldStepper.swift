// MARK: - PASTIKAN KODE INI ADA DI: Sajda/TextFieldStepper.swift

import SwiftUI
import Combine

struct TextFieldStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onCommit: () -> Void
    let onHover: (Bool) -> Void

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    
    @State private var isMinusHovering = false
    @State private var isPlusHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring()) { value = 0 }
            }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .disabled(value == 0)

            HStack(spacing: 4) {
                Button(action: {
                    if value > range.lowerBound { value -= 1 }
                }) {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(isMinusHovering ? Color("HoverColor") : .clear)
                .cornerRadius(5)
                .onHover { hovering in isMinusHovering = hovering }

                TextField(title, text: $textValue, onCommit: {
                    updateValue(from: textValue)
                    onCommit()
                })
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: 45)
                .focused($isFocused)
                .onChange(of: isFocused) { focused in
                    if !focused {
                        updateValue(from: textValue)
                        onCommit()
                    }
                }
                
                Button(action: {
                    if value < range.upperBound { value += 1 }
                }) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(isPlusHovering ? Color("HoverColor") : .clear)
                .cornerRadius(5)
                .onHover { hovering in isPlusHovering = hovering }
            }
            .onHover { hovering in
                onHover(hovering)
            }
        }
        .onAppear {
            textValue = formatValue(value)
        }
        .onChange(of: value) { newValue in
            textValue = formatValue(newValue)
            onCommit()
        }
    }

    private func formatValue(_ val: Double) -> String {
        return String(format: "%+.0f", val)
    }

    private func updateValue(from text: String) {
        if let newDouble = Double(text) {
            value = min(max(newDouble, range.lowerBound), range.upperBound)
        }
        textValue = formatValue(value)
    }
}
