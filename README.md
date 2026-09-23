# Sajda - Prayer Times for macOS

![Sajda App Screenshot](https://github.com/user-attachments/assets/6e8bd922-a446-4b33-a184-e5e89493a4b1)

A minimal, native prayer times app for the menu bar. Built with SwiftUI. Accurate schedules, gentle reminders, and no clutter.

---

## Features

<table>
  <tr>
    <td width="120"><b>Menu Bar</b></td>
    <td>Lives quietly in the menu bar with no dock icon. Adapts to light and dark mode automatically.</td>
  </tr>
  <tr>
    <td><b>Prayer Times</b></td>
    <td>Automatic location detection, or set any city or coordinates manually. Supports MWL, ISNA, Umm al-Qura, Kemenag, Diyanet, and more. Includes a Hanafi Asr toggle and per-prayer manual offset (+/- 60 minutes).</td>
  </tr>
  <tr>
    <td><b>Display</b></td>
    <td>Show a moon icon, a countdown, the next prayer time, or a compact text style. Sunnah prayers (Tahajud, Dhuha) are optional.</td>
  </tr>
  <tr>
    <td><b>Notifications</b></td>
    <td>Native macOS notifications with custom sound support and run-at-login.</td>
  </tr>
  <tr>
    <td><b>Languages</b></td>
    <td>English, Arabic (with RTL support), and Indonesian.</td>
  </tr>
  <tr>
    <td><b>Updates</b></td>
    <td>Optional automatic update checks notify you in-app when a new release is available. Off by default; enable it in Settings or during onboarding.</td>
  </tr>
</table>

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
