// MARK: - GANTI SELURUH FILE: LocationAndCalcSettingsView.swift

import SwiftUI
import NavigationStack

struct LocationAndCalcSettingsView: View {
    static let id = "LocationAndCalcSettingsStack"

    /// Whether this instance was pushed from the panel's location list rather
    /// than from Settings — the same page, one row away, with no Settings hop.
    ///
    /// It only changes where Back goes. The page is pushed onto *different*
    /// stacks by the two entries (Settings pushes it onto `SettingsView.id`;
    /// the panel pushes it onto the root stack, `ContentView.id`, because that
    /// is the stack the panel's own rows already push onto), and a page can
    /// only pop the id it was pushed with. Everything inside the page is
    /// unchanged: its own sub-pages live on `Self.id` either way.
    ///
    /// Named like `ManualLocationView(isModal:)`, which is the same situation —
    /// one view, two entries, two Back targets.
    let enteredFromPanel: Bool

    /// Explicit because a `let` with an initial value is not a memberwise-init
    /// parameter, and this flag has to be settable from the panel's row.
    init(enteredFromPanel: Bool = false) {
        self.enteredFromPanel = enteredFromPanel
    }

    @EnvironmentObject var vm: PrayerTimeViewModel
    @EnvironmentObject var navigationModel: NavigationModel

    /// The stack this page itself sits on, and so the one Back dismisses.
    private var parentStackID: String {
        enteredFromPanel ? ContentView.id : SettingsView.id
    }

    @State private var isHeaderHovering = false
    /// Calculation accordion, closed on every open of this page. `@State`, not
    /// `@AppStorage`: the panel tears this page down when it closes, so a fresh
    /// `@State` is all the reset needed — and unlike the Time Correction tab
    /// (which lives in UserDefaults to survive a mid-pop recreation) this page
    /// has no transition to get wrong.
    @State private var calculationExpanded = false

    private var viewWidth: CGFloat {
        return vm.panelWidth(base: vm.useCompactLayout ? 220 : 260)
    }

    var body: some View {
        NavigationStackView(Self.id) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    navigationModel.hideView(parentStackID, animation: vm.backwardAnimation())
                }) {
                    HStack {
                        Image(systemName: vm.backChevron).scaledFont(.body, weight: .semibold)
                        Text("Calculation & Location").scaledFont(.body, weight: .semibold)
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
                        // Order: Location, Calculation, Mosque Timetable — where
                        // the times come from, in that order: the city or mosque
                        // you picked, the method used to calculate from it, and
                        // the published timetable that replaces both when it's
                        // active. No rule between Location and Calculation: the
                        // accordion header is its own separator, and a second
                        // line under the location row read as a section break
                        // where there is none.
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
                            // Timetable mode replaces both buttons with a single
                            // exit back to calculated times (manual or automatic,
                            // whichever was active); the normal two-button row
                            // returns once calculation mode is back.
                            if vm.useCustomTimetable {
                                HStack { Button("Use Calculated Times") { vm.disableCustomTimetable() }.buttonStyle(.bordered); Spacer() }
                            } else {
                                HStack { Button("Change Manual Location") { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { ManualLocationView(isModal: false) } }.buttonStyle(.bordered); Spacer(); if vm.isUsingManualLocation { Button("Use Automatic") { vm.switchToAutomaticLocation() }.buttonStyle(.bordered) } }
                            }
                        }

                        // Time Correction sits directly above the Calculation
                        // accordion — on the page rather than inside the
                        // collapsed accordion, so reaching it takes one click
                        // instead of two. Same mosque-timetable dimming the
                        // accordion rows have: a published timetable overrides
                        // the calculated path entirely, so the offsets would
                        // be inert.
                        HStack { Text("Time Correction").scaledFont(.subheadline); Spacer(); Button("Adjust") { navigationModel.showView(Self.id, animation: vm.forwardAnimation()) { PrayerTimeCorrectionView() } }.buttonStyle(.bordered) }
                            .allowsHitTesting(!vm.isMosqueTimetableActive)
                            .opacity(vm.isMosqueTimetableActive ? 0.5 : 1)
                            .disabled(vm.isMosqueTimetableActive)

                        // Calculation starts closed. It is the least-used block on
                        // this page — the method, the madhhab and the latitude
                        // rule are set once and then left alone — and it is the
                        // tallest one, so leaving it open pushed the mosque
                        // search (the only control here people come back for)
                        // below the fold. The Location block above it stays open
                        // and unconditional: it answers "where am I?", and an
                        // answer behind a chevron is a worse answer.
                        SettingsAccordion(
                            titleKey: "Calculation",
                            isExpanded: calculationExpanded,
                            collapsedChevron: vm.forwardChevron,
                            onToggle: { calculationExpanded.toggle() },
                            // 0, not the default 13: the Location block above
                            // sits flush at the scroll view's own 16 pt gutter,
                            // and an accordion that stepped in another 13 pt
                            // read as a different page. The header and its rows
                            // now start and end on exactly the same edges.
                            horizontalInset: 0
                        ) {
                            // Everything here feeds the calculated path only: the
                            // method, the madhhab, the latitude rule, the two
                            // captions that explain the recommended rule, and
                            // Time Correction (whose own tabs grey out and say
                            // why). A downloaded mosque timetable replaces the
                            // path wholesale — its own published times win, see
                            // `applyTimetableDay` — so all of it is inert while
                            // one is active. Dimmed and non-interactive, but
                            // still shown with its values, so switching back is
                            // a one-click restore rather than a re-set.
                            Group {
                                HStack { Text("Method").scaledFont(.subheadline); Spacer(); ScaledMenuPicker(selection: $vm.method, options: SajdaCalculationMethod.allCases, maxWidth: 150) { $0.name } }
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
                            .allowsHitTesting(!vm.isMosqueTimetableActive)
                            .opacity(vm.isMosqueTimetableActive ? 0.5 : 1)
                            .disabled(vm.isMosqueTimetableActive)
                            // The reason is the one line left at full strength,
                            // and it leads: it is what the dimming above means,
                            // and a dimmed explanation nobody can read is no
                            // explanation at all. Sits directly under the
                            // disabled High-Latitude Rule row it describes.
                            if vm.isMosqueTimetableActive {
                                Text(NSLocalizedString("mosque_times_in_use", comment: ""))
                                    .scaledFont(.caption2)
                                    .foregroundColor(Color("SecondaryTextColor"))
                            }
                        }
                        Rectangle().fill(Color("DividerColor")).frame(height: 0.5)
                        Group {
                            Text(NSLocalizedString("Custom Timetables", comment: "")).scaledFont(.caption).foregroundColor(Color("SecondaryTextColor"))
                            CustomTimetableView().environmentObject(vm)
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
    }
}
