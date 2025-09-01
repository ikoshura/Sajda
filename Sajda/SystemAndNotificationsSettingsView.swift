// MARK: - GANTI SELURUH FILE: SystemAndNotificationsSettingsView.swift (DENGAN DIVIDER KUSTOM)

import SwiftUI
import NavigationStack

struct SystemAndNotificationsSettingsView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var isHeaderHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                navigationModel.popContent(SettingsView.id)
            }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("System & Notifications").font(.body).fontWeight(.bold)
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
                        Text("System").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                        StyledToggle(label: "Run at Login", isOn: $launchAtLogin)
                    }

                    Rectangle()
                        .fill(Color("DividerColor"))
                        .frame(height: 0.5)
                    
                    Group {
                        Text("Notifications").font(.caption).foregroundColor(Color("SecondaryTextColor"))
                        StyledToggle(label: "Prayer Notifications", isOn: $vm.isNotificationsEnabled)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("Notification Sound").font(.subheadline); Spacer(); Picker("", selection: $vm.adhanSound) { ForEach(AdhanSound.allCases) { sound in Text(sound.rawValue).tag(sound) } }.fixedSize() }
                            if vm.adhanSound == .custom {
                                HStack { Text("Custom File").font(.subheadline); Spacer(); Button("Browse...") { vm.selectCustomAdhanSound() } }
                                Text(URL(string: vm.customAdhanSoundPath)?.lastPathComponent ?? NSLocalizedString("No file selected", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(Color("SecondaryTextColor"))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }.disabled(!vm.isNotificationsEnabled)
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
