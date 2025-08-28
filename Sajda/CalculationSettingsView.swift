// Ganti seluruh kode di CalculationSettingsView.swift dengan ini

import SwiftUI
import Adhan

struct CalculationSettingsView: View {
    @ObservedObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    
    @State private var isHeaderHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            // FIX 3: Tombol ini sekarang kembali ke halaman Settings, bukan Main
            Button(action: { activePage = .settings }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("Calculation").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isHeaderHovering ? 0.25 : 0)).cornerRadius(5)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 15) {
                Picker("Method", selection: $vm.method) {
                    ForEach(CalculationMethod.allCases, id: \.self) {
                        Text("\($0.rawValue.capitalized)")
                    }
                }
                
                Picker("Madhhab", selection: $vm.madhab) {
                    ForEach(Madhab.allCases, id: \.self) {
                        Text("\($0 == .hanafi ? "Hanafi" : "Shafi")")
                    }
                }.pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
