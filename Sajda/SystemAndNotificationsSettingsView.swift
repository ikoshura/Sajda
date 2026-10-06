import SwiftUI
import NavigationStack

struct SystemAndNotificationsSettingsView: View {
    static let id = "SystemAndNotificationsSettingsStack"

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var isHeaderHovering = false
    @State private var applyToAllAdhanType: AdhanType = .defaultBeep
    @State private var previewingPrayer: String? = nil
    /// The per-prayer adhan list, folded away until asked for. `@State`, so it
    /// starts shut on every open of the page: the panel tears this page down
    /// when it closes, and a sound choice is not something to re-inspect each
    /// time the page is opened.
    @State private var perPrayerExpanded = false

    private let obligatoryPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    private let sunnahPrayers = ["Tahajud", "Dhuha"]

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    private var allPrayers: [String] {
        var prayers = obligatoryPrayers
        if vm.showSunnahPrayers {
            prayers.append(contentsOf: sunnahPrayers)
        }
        return prayers
    }

    /// Authorization state under the Prayer Notifications toggle: a green
    /// confirmation once allowed, the one-shot prompt button while the system
    /// hasn't asked yet, and an Open System Settings shortcut once denied
    /// (the only state the app cannot fix by itself).
    @ViewBuilder
    private var notificationPermissionRow: some View {
        switch vm.notificationAuthorizationStatus {
        case .authorized:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
                Text("Notifications allowed")
                    .scaledFont(.caption)
                    .foregroundColor(Color("SecondaryTextColor"))
            }
        case .notDetermined:
            Button("Allow Notifications") {
                vm.requestNotificationPermission()
            }
            .scaledFont(.caption)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications are turned off in System Settings.")
                    .scaledFont(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open System Settings") {
                    vm.openNotificationSettings()
                }
                .scaledFont(.caption)
            }
        }
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(SettingsView.id, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                        Text("Adhan Sound").scaledFont(.body, weight: .semibold)
                        Spacer()
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .liquidHover(isHeaderHovering)
                }
                .buttonStyle(.plain).padding(.horizontal, 5).padding(.top, 2)
                .onHover { hovering in isHeaderHovering = hovering }

                Rectangle()
                    .fill(Color("DividerColor"))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StyledToggle(label: "Prayer Notifications", isOn: $vm.isNotificationsEnabled)

                        // System authorization is the gate on the banner itself
                        // (the adhan plays app-side, the banner does not) — and
                        // macOS never re-prompts after a deny, so the only fix
                        // is a shortcut to System Settings.
                        if vm.isNotificationsEnabled {
                            notificationPermissionRow
                        }

                        Rectangle()
                            .fill(Color("DividerColor"))
                            .frame(height: 0.5)

                        Text("All Prayers").scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))

                        HStack {
                            ScaledMenuPicker(selection: $applyToAllAdhanType, options: AdhanType.allCases) { $0.displayName }

                            Button("Apply") {
                                if applyToAllAdhanType == .custom {
                                    // Custom needs a real file: pick one now and
                                    // share it with every prayer (each row can
                                    // still be re-browsed afterwards). Cancelling
                                    // leaves the configs untouched instead of
                                    // writing unusable empty paths.
                                    NSApp.activate(ignoringOtherApps: true)
                                    let openPanel = NSOpenPanel()
                                    openPanel.canChooseFiles = true
                                    openPanel.canChooseDirectories = false
                                    openPanel.allowsMultipleSelection = false
                                    openPanel.allowedContentTypes = [.audio]
                                    guard openPanel.runModal() == .OK,
                                          let path = openPanel.url?.absoluteString else { return }
                                    for prayer in allPrayers {
                                        vm.setSoundConfig(PrayerSoundConfig(adhanType: .custom, customFilePath: path), for: prayer)
                                    }
                                    return
                                }
                                for prayer in allPrayers {
                                    vm.setSoundConfig(PrayerSoundConfig(adhanType: applyToAllAdhanType), for: prayer)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .disabled(!vm.isNotificationsEnabled)

                        // The per-prayer list is the tall part of this page
                        // (five to seven rows, each with its own picker), and
                        // it is the part almost nobody opens: "set them all" is
                        // one control above and covers the common case. Folding
                        // it means opening Adhan Sound shows the notification
                        // switch, the apply-to-all row, and one line to get to
                        // the rest — instead of a wall of pickers.
                        SettingsAccordion(
                            titleKey: "Per Prayer",
                            isExpanded: perPrayerExpanded,
                            collapsedChevron: vm.forwardChevron,
                            onToggle: { perPrayerExpanded.toggle() },
                            // 0, for the same reason as Calculation & Location:
                            // the rows above already sit flush at the scroll
                            // view's own 16 pt gutter.
                            horizontalInset: 0
                        ) {
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
                                        NSApp.activate(ignoringOtherApps: true)
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
        // The status can change while the page is closed (prompt answered in
        // System Settings) — re-read it every time the page is shown.
        .onAppear { vm.refreshNotificationAuthorizationStatus() }
    }
}

// MARK: - PrayerSoundRow

struct PrayerSoundRow: View {
    let prayerName: String
    let config: PrayerSoundConfig
    let isPreviewing: Bool
    let isEnabled: Bool
    let onUpdateConfig: (PrayerSoundConfig) -> Void
    let onPreview: () -> Void
    let onBrowse: () -> Void
    @EnvironmentObject var vm: PrayerTimeViewModel

    private var options: [AdhanType] {
        AdhanType.availableOptions(for: prayerName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(prayerName))
                    .scaledFont(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                // Same per-prayer mute the home panel rows flip: muting keeps
                // the sound picked in the menu below, so turning it back on
                // never loses the chosen adhan.
                Button(action: {
                    var newConfig = config
                    newConfig.muted.toggle()
                    onUpdateConfig(newConfig)
                }) {
                    // Speaker glyphs here, and always a speaker: this page is
                    // about picking sounds. Previewing gets the play/stop
                    // glyphs instead, so the two buttons beside each other
                    // never read as one control. The panel rows are free to be
                    // a bell or a halo instead (see `MuteIconStyle`) because
                    // there the icon is the whole control.
                    //
                    // Slashed when muted, waved when not — the shape carries
                    // the state, the colour only carries the styling. The wave
                    // on the unmuted glyph is the point: a bare filled speaker
                    // next to a slashed one differs by the slash alone, which
                    // left the active state looking like a hole where the
                    // sound should be.
                    //
                    // Muted drops to the system secondary in every mode. The
                    // shape already says "muted", and in plain accent mode the
                    // accent is also the next-prayer highlight, so a full-
                    // strength accent slash put the highlight's colour on rows
                    // the user had deliberately opted out of.
                    Image(systemName: config.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(config.muted ? .secondary : vm.muteIconColor)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(config.muted ? "Unmute Adhan" : "Mute Adhan")

                if config.adhanType.isAzan || config.adhanType == .custom {
                    Button(action: onPreview) {
                        // Play/stop glyphs, not speakers: the row already has a
                        // speaker for mute beside it, and two speakers side by
                        // side read as one control. The triangle says "play a
                        // sample", the square stops it.
                        Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isPreviewing ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isPreviewing ? "Stop Preview" : "Preview Adhan")
                }
            }

            HStack {
                Spacer()
                ScaledMenuPicker(selection: Binding(
                    get: { config.adhanType },
                    set: { newType in
                        var newConfig = config
                        newConfig.adhanType = newType
                        if newType != .custom { newConfig.customFilePath = "" }
                        onUpdateConfig(newConfig)
                        // Choosing Custom with no file yet goes straight to
                        // the file chooser (dispatched so the modal can't
                        // open while the menu is still tracking); otherwise
                        // the row only gains a Browse link and the switch
                        // looks like it did nothing.
                        if newType == .custom && newConfig.customFilePath.isEmpty {
                            DispatchQueue.main.async { onBrowse() }
                        }
                    }
                ), options: options) { $0.displayName }
            }

            if config.adhanType == .custom {
                HStack {
                    Spacer()
                    Button(NSLocalizedString("Browse...", comment: "")) { onBrowse() }
                        .scaledFont(.caption)
                    Text(URL(string: config.customFilePath)?.lastPathComponent ?? NSLocalizedString("No file selected", comment: ""))
                        .scaledFont(.caption)
                        .foregroundColor(Color("SecondaryTextColor"))
                }
            }
        }
        .disabled(!isEnabled)
    }
}
