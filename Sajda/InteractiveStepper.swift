// MARK: - GANTI SELURUH FILE: Sajda/InteractiveStepper.swift

import SwiftUI

struct InteractiveStepper: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = -60...60
    var onHover: (Bool) -> Void
    
    @State private var isMinusHovering = false
    @State private var isPlusHovering = false
    @State private var isValueHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "minus")
                .frame(width: 28, height: 28)
                .background(isMinusHovering ? Color("HoverColor") : .clear)
                .cornerRadius(5)
                .onHover { hovering in
                    isMinusHovering = hovering
                    onHover(isMinusHovering || isPlusHovering)
                }
                .onTapGesture {
                    value = max(value - 1, range.lowerBound)
                }
            
            ZStack {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .opacity(isValueHovering && value != 0 ? 1 : 0)
                
                Text(String(format: "%+.0f", value))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .opacity(isValueHovering && value != 0 ? 0 : 1)
            }
            .frame(minWidth: 40)
            .padding(.horizontal, 4)
            .onHover { hovering in isValueHovering = hovering }
            .onTapGesture {
                if isValueHovering && value != 0 {
                    withAnimation(.spring()) { value = 0 }
                }
            }

            Image(systemName: "plus")
                .frame(width: 28, height: 28)
                .background(isPlusHovering ? Color("HoverColor") : .clear)
                .cornerRadius(5)
                .onHover { hovering in
                    isPlusHovering = hovering
                    onHover(isMinusHovering || isPlusHovering)
                }
                .onTapGesture {
                    value = min(value + 1, range.upperBound)
                }
        }
    }
}
