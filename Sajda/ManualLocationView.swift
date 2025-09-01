// MARK: - GANTI SELURUH FILE: ManualLocationView.swift

import SwiftUI
import MapKit
import NavigationStack

struct ManualLocationView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    let isModal: Bool
    
    @State private var hoveringResult: UUID?
    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: handleBackButton) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text(LocalizedStringKey("Set Location")).font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(isHeaderHovering ? Color("HoverColor") : .clear).cornerRadius(5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12).drawingGroup()
            
            TextField(LocalizedStringKey("Search for a city or paste coordinates..."), text: $vm.locationSearchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
            
            ScrollView {
                if vm.isLocationSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    VStack(spacing: 2) {
                        ForEach(vm.locationSearchResults) { result in
                            Button(action: {
                                vm.setManualLocation(city: result.name, coordinates: result.coordinates)
                                handleBackButton()
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
                            .onHover { isHovering in hoveringResult = isHovering ? result.id : nil }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: viewWidth)
        .onDisappear {
            vm.locationSearchQuery = ""
        }
    }
    
    private func handleBackButton() {
        if isModal {
            navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
        } else {
            navigationModel.hideView(LocationAndCalcSettingsView.id, animation: vm.backwardAnimation())
        }
    }
}
