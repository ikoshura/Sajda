# Sajda

Prayer times for macOS, done quietly. Sajda lives in your menu bar, shows what matters at a glance, and stays out of your way.

<img src="https://github.com/user-attachments/assets/6e8bd922-a446-4b33-a184-e5e89493a4b1" alt="Sajda App Screenshot">

> Now with a Liquid Glass interface. A refractive glass panel, frosted interior, and native glass controls that feel at home on the latest macOS.

[![Latest Release](https://img.shields.io/github/v/release/ikoshura/Sajda)](https://github.com/ikoshura/Sajda/releases)
[![macOS Ventura 13.3+](https://img.shields.io/badge/macOS-Ventura%2013.3%2B-blue)](https://github.com/ikoshura/Sajda/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Why Sajda

Most prayer apps want your attention. Sajda wants the opposite. It sits in the menu bar, updates itself, reminds you gently, and never gets in the way of your work.

- **Glanceable.** Icon, countdown, or exact time in the menu bar. Pick the style you like.
- **Urgent when it matters.** Icon and text turn red together in the last 10 minutes before prayer.
- **Accurate.** Automatic location or any city worldwide, with trusted calculation methods.
- **Private.** No accounts, no analytics, no tracking. Everything happens on your Mac.

---

## Features

| Area | What you get |
|------|--------------|
| **Menu bar** | Icon only, countdown, exact time, or icon plus text. Compact and minimal styles available. Adapts to light and dark mode. |
| **Liquid Glass panel** | Refractive glass dropdown with a frosted interior, glass header pill, and sharp settings rows with no blur stacking. |
| **Prayer times** | Automatic location detection or manual city and coordinates. Supports MWL, ISNA, Umm al-Qura, Kemenag, Diyanet, and more. Hanafi Asr toggle plus per-prayer offset up to 60 minutes. |
| **Sunnah prayers** | Optional Tahajud and Dhuha rows. |
| **High latitudes** | Configurable high-latitude rule (Recommended, Middle of the Night, Seventh of the Night, Twilight Angle) with a caption that explains which rule is active. |
| **Notifications** | Native macOS notifications with per-prayer adhan sounds, bundled tones, custom audio files, and run at login. |
| **Languages** | English, Arabic with full RTL layout, and Indonesian. |
| **Accessibility** | VoiceOver labels on the menu bar item, keyboard friendly panels, and a Text Size setting (Small to Extra Large) that scales the whole panel. |
| **Updates** | Optional in-app update checks notify you when a new release is available. Off by default; enable it in Settings or during onboarding. |

---

## Installation

### Homebrew (recommended)
```bash
brew install --cask ikoshura/sajda/sajda
```

### DMG
Download the latest `.dmg` from the [Releases page](https://github.com/ikoshura/Sajda/releases), open it, and drag Sajda to your Applications folder.

### First launch on macOS (important)

Sajda releases are ad-hoc signed and not notarized. The Apple Developer Program costs $99/year, which is not affordable for this project right now. Because of that, macOS Gatekeeper may say **"Sajda.app is damaged and can't be opened"** on first launch. The app is not damaged; macOS shows this misleading message for unsigned apps downloaded from the internet.

To open Sajda, run this once in Terminal after copying the app to Applications:
```bash
/usr/bin/xattr -cr /Applications/Sajda.app
```
Then launch Sajda normally. You only need to do this once per install.

<details>
<summary>Still blocked? More options</summary>

**System Settings**
1. Try to open Sajda. When the warning appears, click OK.
2. Open **System Settings → Privacy & Security**.
3. Find the Sajda entry and click **Open Anyway**.

**Terminal (alternative)**
```bash
xattr -r -d com.apple.quarantine /Applications/Sajda.app
```
</details>

---

## System Requirements

- macOS Ventura 13.3 or later
- Apple Silicon or Intel

---

## Build from Source

Requirements: macOS Ventura 13.3+, Xcode with macOS SDK.

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

For production signing and notarization, see [docs/RELEASE.md](docs/RELEASE.md).

---

## Contributing

Pull requests are welcome. For larger changes, open an issue first to discuss what you'd like to change.

---

## Contributors

Thanks to everyone who has contributed to this project.

- [@ikoshura](https://github.com/ikoshura)
- [@omar-hanafy](https://github.com/omar-hanafy)
- [@novan](https://github.com/novan)
- [@maddada](https://github.com/maddada)
- [@sabuz796](https://github.com/sabuz796)

[![Contributors](https://contrib.rocks/image?repo=ikoshura/Sajda)](https://github.com/ikoshura/Sajda/graphs/contributors)

---

## Privacy

Sajda respects your privacy:

- **No accounts, no analytics, no tracking.** The app has no servers and collects nothing.
- **Location** is requested only to calculate prayer times and is processed on your device. Prayer time calculation happens entirely offline (Adhan library).
- **City search** sends only the text you type to [OpenStreetMap's Nominatim](https://wiki.openstreetmap.org/wiki/Nominatim) service (requests identify as `Sajda/1.0`).
- **Timezone detection** uses Apple's standard reverse geocoding.
- All settings stay in local storage on your Mac.

---

## Acknowledgements

- [Adhan](https://github.com/batoulapps/Adhan) - prayer time calculation library
- [FluidMenuBarExtra](https://github.com/lfroms/fluid-menu-bar-extra) - dynamically resizing menu bar window
- [NavigationStack](https://github.com/indieSoftware/NavigationStack) - view navigation system

---

## License

MIT. See [LICENSE](LICENSE) for details.
