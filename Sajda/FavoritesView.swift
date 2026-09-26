// MARK: - Sajda/FavoritesView.swift
//
// Favorites as its own NavigationStack page (same mechanism as
// Settings/About): the location row on MainView pushes here, and the
// expanded rows live on this page's @State — so every open starts shut
// with no reset logic anywhere. Panel close tears the page down;
// returning from a pushed sub-search pops back with fresh state too.

import SwiftUI
import NavigationStack

struct FavoritesView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    var body: some View {
        ZStack {
            PanelInteriorBackground(material: .popover)

            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(ContentView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                        Text(NSLocalizedString("Favorites", comment: "")).scaledFont(.body, weight: .bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .liquidHover(isHeaderHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isHeaderHovering = hovering }

                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                Text(vm.panelLocationCaption)
                    .scaledFont(.caption)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 12)

                FavoritesSection()
                    .environmentObject(vm)
                    .padding(.horizontal, 4)

                Spacer(minLength: 0)
            }
            .padding(.top, 2)
            .frame(width: viewWidth)
        }
    }
}
