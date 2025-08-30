// MARK: - GANTI FILE: Sajda/ManualLocationSheetView.swift
// PERBAIKAN: Memperbaiki cara pemanggilan fungsi searchLocation.

import SwiftUI
import MapKit

struct ManualLocationSheetView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Environment(\.dismiss) var dismiss

    @State private var searchQuery = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var hoveringResult: UUID?

    private var firstResult: LocationSearchResult? {
        searchResults.first
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack {
                Text("Set Location Manually")
                    .font(.headline)
                Text("Start typing a city name below.")
                    .font(.subheadline)
                    .foregroundColor(Color("SecondaryTextColor"))
            }

            TextField("Search for a city...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchQuery) { newValue in
                    isSearching = true
                    // --- PERBAIKAN DI SINI ---
                    // Menghapus argumen 'maxResults' yang sudah tidak ada.
                    vm.searchLocation(query: newValue) { results in
                        self.searchResults = results
                        self.isSearching = false
                    }
                    // --- AKHIR PERBAIKAN ---
                }
            
            VStack {
                if isSearching {
                    ProgressView()
                        .padding()
                } else if let result = firstResult {
                    Button(action: {
                        vm.setManualLocation(city: result.name, coordinates: result.coordinates)
                        dismiss()
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
                    Text(searchQuery.isEmpty ? " " : "No results found.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSearching)
            .animation(.easeInOut(duration: 0.2), value: firstResult?.id)
        }
        .padding()
        .frame(width: 320)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}
