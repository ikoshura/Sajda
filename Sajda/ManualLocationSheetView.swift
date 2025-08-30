// MARK: - GANTI FILE: Sajda/ManualLocationSheetView.swift
// Salin dan tempel SELURUH kode ini.

import SwiftUI
import MapKit

struct ManualLocationSheetView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Environment(\.dismiss) var dismiss // Untuk menutup sheet

    @State private var searchQuery = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var hoveringResult: UUID?

    // Ambil hasil pertama yang paling relevan
    private var firstResult: LocationSearchResult? {
        searchResults.first
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack {
                Text("Set Location Manually")
                    .font(.headline)
                Text("Start typing a city name below.")
                    .font(.subheadline)
                    .foregroundColor(Color("SecondaryTextColor"))
            }

            // Text Field Pencarian
            TextField("Search for a city...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchQuery) { newValue in
                    isSearching = true
                    // Ambil hanya 5 hasil teratas agar lebih cepat dan relevan
                    vm.searchLocation(query: newValue, maxResults: 5) { results in
                        self.searchResults = results
                        self.isSearching = false
                    }
                }
            
            // Kontainer Hasil Pencarian (ukurannya dinamis)
            VStack {
                if isSearching {
                    ProgressView()
                        .padding()
                } else if let result = firstResult {
                    // Tampilkan hanya satu hasil terbaik
                    Button(action: {
                        vm.setManualLocation(city: result.name, coordinates: result.coordinates)
                        dismiss() // Tutup sheet setelah lokasi dipilih
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(result.name).fontWeight(.semibold)
                                Text(result.country).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    // Tampilan saat tidak ada hasil atau belum mencari
                    Text(searchQuery.isEmpty ? " " : "No results found.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            // Animasi untuk memunculkan/menghilangkan hasil dengan mulus
            .animation(.easeInOut(duration: 0.2), value: isSearching)
            .animation(.easeInOut(duration: 0.2), value: firstResult?.id)
        }
        .padding()
        .frame(width: 320) // Lebar tetap, tinggi akan menyesuaikan konten
        .toolbar {
            // Tombol "Cancel" di pojok kanan atas, cara standar macOS
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}
