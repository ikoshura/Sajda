// MARK: - GANTI SELURUH FILE: ManualLocationSheetView.swift (SOLUSI LAYOUT FINAL)

import SwiftUI
import MapKit

struct ManualLocationSheetView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Environment(\.dismiss) var dismiss

    @State private var hoveringResult: UUID?

    var body: some View {
        VStack(spacing: 16) {
            
            VStack {
                Text("Set Location Manually")
                    .font(.headline)
                Text("Start typing a city or paste coordinates.")
                    .font(.subheadline)
                    .foregroundColor(Color("SecondaryTextColor"))
            }
            .padding(.top, 8)

            TextField("Search for a city or paste coordinates...", text: $vm.locationSearchQuery)
                .textFieldStyle(.roundedBorder)
            
            if vm.isLocationSearching {
                // --- KUNCI PERBAIKAN 1 ---
                // Bungkus dalam VStack dengan Spacer agar tetap di atas.
                VStack {
                    ProgressView()
                        .padding(.top, 20)
                    Spacer()
                }
            } else if vm.locationSearchResults.isEmpty {
                // --- KUNCI PERBAIKAN 2 ---
                // Bungkus dalam VStack dengan Spacer agar tetap di atas.
                VStack {
                    Text(vm.locationSearchQuery.isEmpty ? " " : "No results found.")
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                    Spacer()
                }
            } else {
                // --- KUNCI PERBAIKAN 3 ---
                // ScrollView dibiarkan sendiri tanpa Spacer,
                // sehingga ia akan mengisi sisa ruang secara otomatis.
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(vm.locationSearchResults) { result in
                            Button(action: {
                                vm.setManualLocation(city: result.name, coordinates: result.coordinates)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(result.name).fontWeight(.semibold)
                                        Text(result.country).font(.caption).foregroundColor(Color("SecondaryTextColor"))
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                                .background(hoveringResult == result.id ? Color("HoverColor") : Color.clear)
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in
                                hoveringResult = isHovering ? result.id : nil
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding()
        .frame(width: 320, height: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isLocationSearching)
        .animation(.easeInOut, value: vm.locationSearchResults.count)
        .onDisappear {
            vm.locationSearchQuery = ""
        }
    }
}
