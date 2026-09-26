// MARK: - Sajda/MosqueSearchView.swift
//
// Mosque-timetable search reachable straight from the main screen's
// favorites shortcut (when no favorites exist yet). Same picker as
// Settings > Calculation & Location, with a back header to Main.

import SwiftUI
import NavigationStack

struct MosqueSearchView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
            }) {
                HStack {
                    Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                    Text(LocalizedStringKey("Search Mosque")).scaledFont(.body, weight: .bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .liquidHover(isHeaderHovering)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5).padding(.top, 2)
            .onHover { hovering in isHeaderHovering = hovering }

            Divider().padding(.horizontal, 12).drawingGroup()

            ScrollView {
                MosqueTimetablePicker().environmentObject(vm)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 2)
        .padding(.bottom, 2)
        .frame(width: viewWidth)
    }
}
