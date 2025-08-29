// Salin dan tempel SELURUH kode ini ke dalam file ManualLocationView.swift

import SwiftUI
import MapKit

struct ManualLocationView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    let returnPage: ActivePage
    
    @State private var searchQuery = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var hoveringResult: UUID?
    // PERBAIKAN: State baru untuk hover effect pada header
    @State private var isHeaderHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // PERBAIKAN: Header sekarang memiliki hover effect yang konsisten
            Button(action: { activePage = returnPage }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("Set Location").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isHeaderHovering ? 0.25 : 0)).cornerRadius(5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12)
            
            TextField("Search for a city...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .onChange(of: searchQuery) { newValue in
                    isSearching = true
                    vm.searchLocation(query: newValue) { results in
                        self.searchResults = results; self.isSearching = false
                    }
                }
            
            ScrollView {
                if isSearching && !searchQuery.isEmpty {
                    ProgressView().padding()
                } else {
                    VStack(spacing: 2) {
                        ForEach(searchResults) { result in
                            Button(action: {
                                vm.setManualLocation(city: result.name, coordinates: result.coordinates)
                                activePage = .main
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(result.name).fontWeight(.semibold)
                                        Text(result.country).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                                .background(hoveringResult == result.id ? Color.secondary.opacity(0.25) : Color.clear)
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in hoveringResult = isHovering ? result.id : nil }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            // Beri tinggi minimal agar view tidak kolaps saat hasil kosong
            .frame(maxWidth: .infinity, minHeight: 200)
        }
        .padding(.vertical, 8)
    }
}
