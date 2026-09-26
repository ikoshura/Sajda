// MARK: - GANTI SELURUH FILE: ManualLocationView.swift

import SwiftUI
import MapKit
import NavigationStack

struct ManualLocationView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    let isModal: Bool
    
    @State private var hoveringResult: UUID?
    @State private var hoveringStarID: UUID?
    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: handleBackButton) {
                HStack {
                    Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                    Text(LocalizedStringKey("Set Location")).scaledFont(.body, weight: .bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .liquidHover(isHeaderHovering)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12).drawingGroup()
            
            // Chrome drawn by the app (see `SajdaSearchField`) instead of the
            // native rounded bezel, which could blink black mid-transition.
            SajdaSearchField(placeholder: "Search for a city or paste coordinates...", text: $vm.locationSearchQuery)
                .padding(.horizontal, 12)
            
            ScrollView {
                if vm.isLocationSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    VStack(spacing: 2) {
                        ForEach(vm.locationSearchResults) { result in
                            // Row hover spans the full line (including under
                            // the star); the star sits on top with its own
                            // pill — same treatment as the Settings back+lock
                            // header. While the star is hovered the row pill
                            // is suppressed, so only the star highlights.
                            ZStack(alignment: .trailing) {
                                Button(action: {
                                    // Apply the coordinates first, then pop on the
                                    // next runloop: the mode switch publishes
                                    // several @Published/AppStorage changes and
                                    // popping the NavigationStack in the same
                                    // cycle as those updates crashed the app when
                                    // leaving mosque-timetable mode.
                                    let city = result.name
                                    let coords = result.coordinates
                                    vm.setManualLocation(city: city, coordinates: coords)
                                    DispatchQueue.main.async {
                                        handleBackButton()
                                    }
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(result.name).fontWeight(.semibold)
                                            Text(result.country).scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                                    .liquidHover(hoveringResult == result.id && hoveringStarID == nil)
                                }
                                .buttonStyle(.plain)
                                .onHover { isHovering in hoveringResult = isHovering ? result.id : nil }
                                // Star toggles the favorite without applying: the
                                // place stays saved for one-tap switching from
                                // the main screen.
                                Button(action: { vm.toggleCityFavorite(result) }) {
                                    Image(systemName: vm.isCityFavorite(result) ? "star.fill" : "star")
                                        .foregroundColor(vm.isCityFavorite(result) ? vm.selectedHighlightColor : .secondary)
                                        .padding(.vertical, 6).padding(.horizontal, 6)
                                        .contentShape(Rectangle())
                                        .liquidHover(hoveringStarID == result.id)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .onHover { isHovering in hoveringStarID = isHovering ? result.id : nil }
                                .help(Text(NSLocalizedString(vm.isCityFavorite(result) ? "Remove from Favorites" : "Add to Favorites", comment: "")))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        // Trimmed from 8pt: the menu container already supplies the panel's
        // edge inset, so the extra pad doubled the dead air.
        .padding(.top, 2)
        .padding(.bottom, 2)
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
