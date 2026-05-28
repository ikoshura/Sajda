import SwiftUI
import NavigationStack

struct AzanSettingsView: View {
    static let id = "AzanSettingsStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var isHeaderHovering = false
    @State private var applyToAllAdhanType: AdhanType = .defaultBeep
    @State private var previewingPrayer: String? = nil

    private let obligatoryPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    private let sunnahPrayers = ["Tahajud", "Dhuha"]

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    private var allPrayers: [String] {
        var prayers = obligatoryPrayers
        if vm.showSunnahPrayers {
            prayers.append(contentsOf: sunnahPrayers)
        }
        return prayers
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(SystemAndNotificationsSettingsView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text("Azan Sound").font(.body).fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(isHeaderHovering ? Color("HoverColor") : .clear).cornerRadius(5)
                }
                .buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2).onHover { hovering in isHeaderHovering = hovering }

                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Apply to All
                        Text("All Prayers").font(.caption).foregroundColor(Color("SecondaryTextColor"))

                        HStack {
                            Picker("", selection: $applyToAllAdhanType) {
                                ForEach(AdhanType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .fixedSize()

                            Button("Apply") {
                                for prayer in allPrayers {
                                    vm.setSoundConfig(PrayerSoundConfig(adhanType: applyToAllAdhanType), for: prayer)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .disabled(!vm.isNotificationsEnabled)

                        Rectangle()
                            .fill(Color("DividerColor"))
                            .frame(height: 0.5)

                        // Per-prayer config
                        ForEach(allPrayers, id: \.self) { prayerName in
                            PrayerSoundRow(
                                prayerName: prayerName,
                                config: vm.soundConfig(for: prayerName),
                                isPreviewing: previewingPrayer == prayerName,
                                isEnabled: vm.isNotificationsEnabled,
                                onUpdateConfig: { newConfig in
                                    vm.setSoundConfig(newConfig, for: prayerName)
                                },
                                onPreview: {
                                    if previewingPrayer == prayerName {
                                        AdhanAudioPlayer.shared.stop()
                                        previewingPrayer = nil
                                    } else {
                                        AdhanAudioPlayer.shared.stop()
                                        let config = vm.soundConfig(for: prayerName)
                                        AdhanAudioPlayer.shared.preview(
                                            adhanType: config.adhanType,
                                            customFilePath: config.customFilePath
                                        )
                                        previewingPrayer = prayerName
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                            if previewingPrayer == prayerName {
                                                previewingPrayer = nil
                                            }
                                        }
                                    }
                                },
                                onBrowse: {
                                    let openPanel = NSOpenPanel()
                                    openPanel.canChooseFiles = true
                                    openPanel.canChooseDirectories = false
                                    openPanel.allowsMultipleSelection = false
                                    openPanel.allowedContentTypes = [.audio]
                                    if openPanel.runModal() == .OK {
                                        let config = PrayerSoundConfig(
                                            adhanType: .custom,
                                            customFilePath: openPanel.url?.absoluteString ?? ""
                                        )
                                        vm.setSoundConfig(config, for: prayerName)
                                    }
                                }
                            )
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

struct PrayerSoundRow: View {
    let prayerName: String
    let config: PrayerSoundConfig
    let isPreviewing: Bool
    let isEnabled: Bool
    let onUpdateConfig: (PrayerSoundConfig) -> Void
    let onPreview: () -> Void
    let onBrowse: () -> Void

    private var options: [AdhanType] {
        AdhanType.availableOptions(for: prayerName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(prayerName))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if config.adhanType.isAzan || config.adhanType == .custom {
                    Button(action: onPreview) {
                        Image(systemName: isPreviewing ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isPreviewing ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Picker("", selection: Binding(
                    get: { config.adhanType },
                    set: { newType in
                        var newConfig = config
                        newConfig.adhanType = newType
                        if newType != .custom { newConfig.customFilePath = "" }
                        onUpdateConfig(newConfig)
                    }
                )) {
                    ForEach(options) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .fixedSize()
            }

            if config.adhanType == .custom {
                HStack {
                    Spacer()
                    Button(NSLocalizedString("Browse...", comment: "")) { onBrowse() }
                        .font(.caption)
                    Text(URL(string: config.customFilePath)?.lastPathComponent ?? NSLocalizedString("No file selected", comment: ""))
                        .font(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                }
            }
        }
        .disabled(!isEnabled)
    }
}
