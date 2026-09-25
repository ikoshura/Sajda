// MARK: - GANTI SELURUH FILE: LocationAndCalcSettingsView.swift

import SwiftUI
import NavigationStack

struct LocationAndCalcSettingsView: View {
    static let id = "LocationAndCalcSettingsStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(SettingsView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                        Text("Calculation & Location").scaledFont(.body, weight: .bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .liquidHover(isHeaderHovering)
                }.buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }
                
                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            Text("Mosque Timetable").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            MosqueTimetablePicker().environmentObject(vm)
                        }
                                                Group {
                            Text("Calculation").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            HStack { Text("Method").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.method, options: SajdaCalculationMethod.allCases, maxWidth: 150) { $0.name } }
                            HStack { Text("Time Correction").scaledFont(.subheadline); Spacer(); Button("Adjust") { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { PrayerTimeCorrectionView() } }.buttonStyle(.bordered) }
                            StyledToggle(label: "Hanafi Madhhab (for Asr)", isOn: $vm.useHanafiMadhhab)
                            HStack { Text("High-Latitude Rule").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.highLatitudeRuleSetting, options: HighLatitudeRuleSetting.allCases, maxWidth: 150) { $0.displayName } }
                            if let caption = vm.highLatitudeRuleCaption {
                                Text(caption)
                                    .scaledFont(.caption2)
                                    .foregroundColor(Color("SecondaryTextColor"))
                            }
                            if let description = vm.highLatitudeRuleDescription {
                                Text(description)
                                    .scaledFont(.caption2)
                                    .foregroundColor(Color("SecondaryTextColor"))
                            }
                        }
                        Rectangle().fill(Color("DividerColor")).frame(height: 0.5)
                        Group {
                            Text("Location").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            HStack(spacing: 6) {
                                Image(systemName: vm.isUsingManualLocation ? "pencil.circle.fill" : "location.circle.fill")
                                    .foregroundColor(.secondary)

                                Text(vm.isUsingManualLocation ? "\(NSLocalizedString("Manual:", comment: "")) \(vm.locationStatusText)" : "\(NSLocalizedString("Automatic:", comment: "")) \(vm.locationStatusText)")
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 4)

                                if !vm.isUsingManualLocation {
                                    LocationRefreshButton(
                                        action: vm.refetchAutomaticLocation,
                                        isDisabled: vm.isRequestingLocation,
                                        isRefreshing: vm.isRequestingLocation
                                    )
                                }
                            }
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
