// MARK: - GANTI SELURUH FILE: LocationAndCalcSettingsView.swift

import SwiftUI
import NavigationStack

struct LocationAndCalcSettingsView: View {
    static let id = "LocationAndCalcSettingsStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(SettingsView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text("Calculation & Location").font(.body).fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(isHeaderHovering ? Color("HoverColor") : .clear).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            Text("Calculation").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            HStack { Text("Method").font(.subheadline); Spacer(); Picker("", selection: $vm.method) { ForEach(SajdaCalculationMethod.allCases) { method in Text(method.name).tag(method) } }.frame(maxWidth: 140) }
                            HStack { Text("Time Correction").font(.subheadline); Spacer(); Button("Adjust") { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { PrayerTimeCorrectionView() } }.buttonStyle(.bordered) }
                            StyledToggle(label: "Hanafi Madhhab (for Asr)", isOn: $vm.useHanafiMadhhab)
                        }
                        Rectangle().fill(Color("DividerColor")).frame(height: 0.5)
                        Group {
                            Text("Location").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                            HStack { Image(systemName: vm.isUsingManualLocation ? "pencil.circle.fill" : "location.circle.fill").foregroundColor(.secondary); Text(vm.isUsingManualLocation ? "\(NSLocalizedString("Manual:", comment: "")) \(vm.locationStatusText)" : "\(NSLocalizedString("Automatic:", comment: "")) \(vm.locationStatusText)") }.lineLimit(1).truncationMode(.tail)
                            HStack { Button("Change Manual Location") { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { ManualLocationView(isModal: false) } }.buttonStyle(.bordered); Spacer(); if vm.isUsingManualLocation { Button("Use Automatic") { vm.switchToAutomaticLocation() }.buttonStyle(.bordered) } }
                        }
                    }
                    .controlSize(.small)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.vertical, 8)
            .frame(width: viewWidth)
        }
    }
}
