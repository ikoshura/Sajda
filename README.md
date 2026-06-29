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
</table>

---

## Installation

### Homebrew (recommended)

```bash
brew tap ikoshura/sajda
brew install --cask sajda
```

### DMG

Download the latest `.dmg` from the [Releases page](https://github.com/ikoshura/Sajda/releases), open it, and drag Sajda to your Applications folder.

If macOS blocks the app on first launch, right-click the app icon and select **Open**, then confirm in the dialog.

If that does not work, run this in Terminal:

```bash
/usr/bin/xattr -cr /Applications/Sajda.app
```

Then open the app normally.

<details>
<summary>More installation options</summary>

**System Settings method**

1. Try to open Sajda. When the warning appears, click OK.
2. Open System Settings > Privacy & Security.
3. Find the message about Sajda being blocked and click **Open Anyway**.

**Terminal method (guaranteed fix)**

```bash
xattr -r -d com.apple.quarantine /Applications/Sajda.app
```

Or drag the app onto the Terminal window after typing the command with a trailing space.

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

[![Contributors](https://contrib.rocks/image?repo=ikoshura/Sajda)](https://github.com/ikoshura/Sajda/graphs/contributors)

---

## Acknowledgements

- [Adhan](https://github.com/batoulapps/Adhan) - prayer time calculation library
- [FluidMenuBarExtra](https://github.com/lfroms/fluid-menu-bar-extra) - dynamically resizing menu bar window
- [NavigationStack](https://github.com/indieSoftware/NavigationStack) - view navigation system

---

## License

MIT. See [LICENSE](LICENSE) for details.
