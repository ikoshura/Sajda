# Sajda

A prayer times app for macOS that lives in the menu bar.

<img src="https://github.com/user-attachments/assets/6e8bd922-a446-4b33-a184-e5e89493a4b1" alt="Sajda App Screenshot">

[![Latest Release](https://img.shields.io/github/v/release/ikoshura/Sajda)](https://github.com/ikoshura/Sajda/releases)
[![macOS Sonoma 14.0+](https://img.shields.io/badge/macOS-Sonoma%2014.0%2B-blue)](https://github.com/ikoshura/Sajda/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- Shows the next prayer in the menu bar as an icon, a countdown, or the exact time.
- Turns red a set amount of time before prayer. You choose how early.
- Detects your location automatically, or lets you pick any city.
- Supports several calculation methods, and mosque timetables through Mawaqit.
- Works offline for prayer time calculation. No accounts or tracking.
- Available in English, Indonesian, Arabic, Spanish, French, German, Japanese, Korean, and Simplified Chinese.

## Installation

Requires macOS Sonoma 14.0 or later (Apple Silicon or Intel).

### Homebrew

```bash
brew install --cask ikoshura/sajda/sajda
```

### DMG

Download the latest `.dmg` from the [Releases page](https://github.com/ikoshura/Sajda/releases), open it, and drag Sajda to your Applications folder.

### First launch

Sajda is ad-hoc signed but not notarized, because the Apple Developer Program costs $99/year and I can't cover it right now. Because of this, macOS may say "Sajda.app is damaged and can't be opened". The app is fine. macOS shows this message for unnotarized apps downloaded from the internet.

To fix it, run this once after copying the app to Applications:

```bash
/usr/bin/xattr -cr /Applications/Sajda.app
```

Then open Sajda as usual.

<details>
<summary>Still blocked?</summary>

**System Settings**
1. Try to open Sajda and click OK on the warning.
2. Go to **System Settings → Privacy & Security**.
3. Find Sajda and click **Open Anyway**.

**Terminal**
```bash
xattr -r -d com.apple.quarantine /Applications/Sajda.app
```
</details>

## Build from source

Requires macOS Sonoma 14.0+ and Xcode with the macOS SDK.

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

For signing and notarization, see [docs/RELEASE.md](docs/RELEASE.md).

## Contributing

Pull requests are welcome. For bigger changes, please open an issue first.

## Contributors

- [@ikoshura](https://github.com/ikoshura)
- [@omar-hanafy](https://github.com/omar-hanafy)
- [@novan](https://github.com/novan)
- [@maddada](https://github.com/maddada)
- [@sabuz796](https://github.com/sabuz796)

[![Contributors](https://contrib.rocks/image?repo=ikoshura/Sajda)](https://github.com/ikoshura/Sajda/graphs/contributors)

Thanks also to [@iMacLion](https://github.com/iMacLion) for testing releases and giving detailed feedback.

## Privacy

- No accounts, analytics, or tracking. The app has no servers and collects nothing.
- Location is used only to calculate prayer times, and stays on your device.
- Prayer times are calculated offline with the Adhan library.
- City search sends only the text you type to [OpenStreetMap Nominatim](https://wiki.openstreetmap.org/wiki/Nominatim). Requests identify as `Sajda/1.0`.
- Timezone detection uses Apple's standard reverse geocoding.
- Settings are stored locally on your Mac.

## Acknowledgements

- [Adhan](https://github.com/batoulapps/Adhan): prayer time calculation
- [ColorSelector](https://github.com/jaywcjlove/ColorSelector): highlight colour picker
- [FluidMenuBarExtra](https://github.com/lfroms/fluid-menu-bar-extra): resizing menu bar window
- [MacControlCenterUI](https://github.com/orchetect/MacControlCenterUI): Control Center style menu and controls
- [Mawaqit](https://mawaqit.net): mosque prayer and iqama timetables
- [NavigationStack](https://github.com/indieSoftware/NavigationStack): view navigation

## License

MIT. See [LICENSE](LICENSE).
