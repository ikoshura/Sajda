// MARK: - BUAT FILE BARU: AccessibilitySettingsView.swift

import SwiftUI
import NavigationStack

/// Halaman pengaturan aksesibilitas untuk pengguna dengan keterbatasan
/// penglihatan: ukuran teks panel, penebalan, uppercase, dan pembesaran
/// teks menu bar. Dipisah dari halaman Settings utama agar tidak penuh.
struct AccessibilitySettingsView: View {
    static let id = "AccessibilitySettingsStack"

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
                        Text("Accessibility").scaledFont(.body, weight: .bold)
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
                            Text("Text").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            HStack { Text("Text Size").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.panelTextSize, options: PanelTextSize.allCases) { NSLocalizedString($0.rawValue, comment: "") } }
                            StyledToggle(label: "Bold Text", isOn: $vm.accessibilityBoldText)
                            StyledToggle(label: "Uppercase Text", isOn: $vm.accessibilityUppercaseText)
                        }

                        Rectangle().fill(Color("DividerColor")).frame(height: 0.5)

                        Group {
                            Text("Menu Bar").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            StyledToggle(label: "Larger Menu Bar Text", isOn: $vm.menuBarLargerText).disabled(vm.menuBarTextMode == .hidden)
                        }

                        Text("Make text easier to read across the panel and menu bar.")
                            .scaledFont(.caption2)
                            .foregroundColor(Color("SecondaryTextColor"))
                    }
                    .controlSize(.small)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
            // Trimmed from 8pt: the menu container already supplies the
            // panel's edge inset (internal scroll padding above is untouched).
            .padding(.top, 2)
            .padding(.bottom, 2)
            .frame(width: viewWidth)
        }
    }
}
