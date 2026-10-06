# Sajda — Agent Guide

A minimalist, native macOS menu bar prayer times app built with SwiftUI and AppKit.

## Overview

Sajda lives in the macOS menu bar as a background agent (`LSUIElement` — no Dock icon). It displays daily prayer times, countdown to the next prayer, and sends local notifications with optional adhan sounds. The app supports automatic location detection, manual location entry, multiple calculation methods, per-prayer time correction, and full localization (English, Arabic, Indonesian with RTL, Spanish, French, German, Japanese, Simplified Chinese, Korean).

**Target:** macOS Sonoma 14.0+, both Apple Silicon and Intel.

## Architecture

```
Sajda/
├── main.swift                         # NSApplication entry point
├── AppDelegate.swift                  # App lifecycle, menu bar setup, notifications
├── PrayerTimeViewModel.swift          # Central state: prayer times, location, settings (~44KB)
├── ContentView.swift                  # Root view wrapping NavigationStack
├── MainView.swift                     # Home screen: prayer list, settings/about/quit footer
├── SettingsView.swift                 # Settings root (system, display, nav to sub-settings)
├── LocationAndCalcSettingsView.swift  # Calculation method, location settings
├── SystemAndNotificationsSettingsView.swift  # Adhan sound per prayer
├── PrayerTimeCorrectionView.swift     # Per-prayer ±60 min offset
├── OnboardingView.swift               # First-launch welcome wizard
├── AboutView.swift                    # App info, version, acknowledgments
├── AlertWindowManager.swift           # NSWindow-based alert for prayer time reminders
├── NotificationManager.swift          # UNUserNotificationCenter scheduling
├── AdhanAudioPlayer.swift             # Audio playback for adhan (bundled + custom files)
├── AdhanSound.swift                   # Sound configuration model
├── LanguageManager.swift              # Runtime language switching (en/ar/id + RTL)
├── MenuBarTextMode.swift              # Enum: icon-only, countdown, exact time, compact
├── AnimationType.swift                # Enum: fade, slide, none
├── PrayerTimerMonitor.swift           # Countdown timer logic
├── PrayerTimerAlertView.swift         # In-app prayer time alert overlay
├── StartupManager.swift               # Launch at login toggle (LSSharedFileList)
├── SajdaCalculationMethod.swift       # Adhan calculation method mapping
├── SajdaStepper.swift                 # Custom stepper UI component
├── StyledToggle.swift                 # Settings row: label + native macOS switch (Liquid Glass)
├── TextFieldStepper.swift             # Text field with stepper controls
├── SajdaApp.swift                     # Notification.Name extensions
├── VisualEffectView.swift             # NSVisualEffectView wrapper
├── TimePreviewPopover.swift           # Preview popover for time settings
├── ManualLocationView.swift           # Manual location entry
├── ManualLocationSheetView.swift      # Manual location sheet variant
├── LocationSearchResult.swift         # Location search result model
├── NavigationAnimation+Custom.swift   # Custom transition animations
├── NavigationAnimations.swift         # Animation helpers
├── FluidMenuBar/                      # Custom menu bar extra implementation
│   ├── FluidMenuBarExtra.swift
│   ├── FluidMenuBarExtraStatusItem.swift
│   ├── FluidMenuBarExtraWindow.swift
│   ├── EventMonitor.swift
│   ├── RootViewModifier.swift
│   └── UpdateSizeAction.swift
└── TimeZoneLocate/
    └── TimeZoneLocate.swift           # Timezone resolution from coordinates
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI + AppKit (NSWindow, NSMenu, NSStatusItem) |
| State | MVVM via `ObservableObject` + `@Published` + Combine |
| Persistence | `@AppStorage` (UserDefaults) |
| Prayer calculation | [Adhan](https://github.com/batoulapps/Adhan) Swift package |
| Location | CoreLocation, CLGeocoder |
| Menu bar | Custom `FluidMenuBarExtra` (dynamically resizing) |
| Navigation | [NavigationStack](https://github.com/indieSoftware/NavigationStack) |
| Notifications | UserNotifications framework |
| Audio | AVAudioPlayer (bundled CAF + custom user files) |
| Build | Xcode project (`Sajda.xcodeproj`) |

## Build & Run

### Debug (local development)

```bash
xcodebuild \
  -project Sajda.xcodeproj \
  -scheme Sajda \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

open build/DerivedData/Build/Products/Debug/Sajda.app
```

### Release

The supported path is the script, which signs with Developer ID, notarizes and
staples the app and DMG, and regenerates the Sparkle appcast in `docs/`:

```bash
scripts/release.sh 4.4.15
```

Details, manual steps and prerequisites are in `docs/RELEASE.md`.

### Tests

```bash
xcodebuild \
  -project Sajda.xcodeproj \
  -scheme Sajda \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Code Conventions

### State Management
- `PrayerTimeViewModel` is the single central `ObservableObject` — owns all prayer state, location, settings
- Settings are persisted via `@AppStorage` properties on the ViewModel
- Views receive the VM via `.environmentObject()`
- `LanguageManager` is a separate `ObservableObject` for runtime locale switching

### Navigation
- NavigationStack IDs: `"RootNavigationStack"` (ContentView), `"SettingsNavigationStack"` (SettingsView)
- Push: `navigationModel.showView(stackId, animation:) { DestinationView() }`
- Pop: `navigationModel.hideView(stackId, animation:)`
- `vm.forwardAnimation()` / `vm.backwardAnimation()` respect the user's `animationType` setting
- The root `ContentView` listens for `.popoverDidClose` to reset the navigation stack

### Localization
- All user-facing strings use `NSLocalizedString(key, comment:)`
- `LocalizedStringKey` for inline template interpolation in SwiftUI views
- RTL layout direction auto-applied when language is `"ar"`
- Language switching triggers a full view tree re-render via `.id(manager.language)`

### Code Organization
- Files use `// MARK: -` section comments extensively (mostly in Indonesian-English mix)
- Components: custom stepper, toggle, text field stepper extracted as reusable views
- `FluidMenuBarExtra/` is a vendored dependency (subdirectory, not a Swift package)

### macOS Behaviors
- App returns `false` from `applicationShouldTerminateAfterLastWindowClosed` — stays alive in menu bar
- Popover management via notification-based open/close tracking
- Wake-from-sleep handling reschedules prayer times after a 2-second delay
- `NSApp.setActivationPolicy(.accessory)` hides Dock icon; toggled by `showInDock` setting

### Notification Sound Pipeline
1. The notification payload is always silent (`content.sound = nil`) — `UNNotificationSound` rejects the long CAF adhans (>30s) and would then play nothing. Banners therefore need notification authorization; the adhan does not.
2. The adhan audio is played by the app itself, in order of precedence (deduped by `AdhanAudioPlayer.playedPrayers` — each prayer plays once):
   - `scheduleAdhanTriggers` (PrayerTimeViewModel) — wall-clock `Timer` per remaining prayer, scheduled alongside the notifications, fires at the prayer instant (`.common` run-loop mode, resolves the sound config at fire time).
   - The 1-second countdown poll (`updateCountdown`) — plays when the countdown reaches "Now" (safety net).
   - `userNotificationCenter(_:willPresent:)` in AppDelegate — foreground-only (Apple: "arrived while the app was running in the foreground"), i.e. effectively only while the menu is open.
   - `userNotificationCenter(_:didReceive:)` — plays when the user clicks the banner.
3. `AdhanAudioPlayer.shared` is touched at launch so its App Nap / idle-sleep assertion is held from startup — otherwise the countdown timer can be throttled while the menu is closed.
4. User can stop via the "Stop Adhan" menu command or the inline stop button in the prayer list.
5. Notification authorization is surfaced in onboarding and Settings → Adhan Sound (Allow prompt / Open System Settings shortcut); `PrayerTimeViewModel.notificationAuthorizationStatus` mirrors the system state.

## Key Dependencies

- **Adhan** — Go-based prayer time calculation library, consumed as Swift package
- **FluidMenuBarExtra** — Custom menu bar window that dynamically resizes (vendored in `Sajda/FluidMenuBar/`)
- **Sparkle 2** — In-app updates. The feed URL, EdDSA public key and the sandbox's Installer-launcher opt-in live in `Sajda/Info.plist` (`SUFeedURL`, `SUPublicEDKey`, `SUEnableInstallerLauncherService`); the Sandbox needs the `-spks`/`-spki` mach-lookup exceptions in `Sajda.entitlements`. `UpdateChecker` is only a SwiftUI-facing wrapper around `SPUUpdater`.
- **iCloudStorage** — NavigationStack dependency for iCloud sync (NavigationStack itself is the primary nav dependency)

## Files to Avoid Modifying Lightly

- `PrayerTimeViewModel.swift` — 44KB, central nervous system of the app. Changes here ripple everywhere.
- `AppDelegate.swift` — App lifecycle, menu bar setup, notification delegate, wake-from-sleep handler.
- `LanguageManager.swift` — Method swizzling on `Bundle` for runtime language. Brittle; test carefully.
- `FluidMenuBarExtra/` — Vendored fork. Changes should be deliberate and documented.
