# Azan Audio Files

All azan recordings from public domain sources, converted to **CAF (AAC, 44100 Hz, stereo)** via `afconvert -d aac -f caff -q 127`. macOS `NSSound` supports full-length playback without any duration cap.

## Fajr Azan (includes "As-salatu khayrum minan-nawm")

| Bundle File | Source | Muezzin | Duration |
|---|---|---|---|
| `Mishary_Rashid_al_Afasy_Fajr_Adhan.caf` | adhan.notifications | Mishary Rashid al Afasy | 3:07 |
| `Doha_Qatar_Fajr_Adhan.caf` | adhan.recordings.from.doha.qatar | Doha Qatar muezzin | 3:37 |

## Standard Azan (without Fajr addition)

| Bundle File | Source | Muezzin | Duration |
|---|---|---|---|
| `Ahmed_al_Imadi_Adhan.caf` | adhan.notifications | Ahmed al Imadi | 2:59 |
| `Majed_al_Hamathani_Adhan.caf` | adhan.notifications | Majed al Hamathani | 3:39 |
| `Nasser_al_Qatami_Adhan.caf` | adhan.notifications | Nasser al Qatami | 2:11 |

## Sources

- **[adhan.notifications](https://archive.org/details/adhan.notifications)** — Public Domain Mark 1.0. Collection of adhan recordings by multiple muezzins (Mishary Rashid al Afasy, Ahmed al Imadi, Majed al Hamathani, Nasser al Qatami, Mokhtar Hadj Slimane). Original format: OGG Vorbis.
- **[adhan.recordings.from.doha.qatar](https://archive.org/details/adhan.recordings.from.doha.qatar)** — Public Domain. Five daily prayer adhan recordings from Doha, Qatar. Original format: OGG Vorbis.

## Code Mapping

File names are referenced in `AdhanSound.swift` via `bundleFileName`:
- `fajrAzan1` → `Mishary_Rashid_al_Afasy_Fajr_Adhan`
- `fajrAzan2` → `Doha_Qatar_Fajr_Adhan`
- `standardAzan1` → `Ahmed_al_Imadi_Adhan`
- `standardAzan2` → `Majed_al_Hamathani_Adhan`
- `standardAzan3` → `Nasser_al_Qatami_Adhan`

## Xcode

Add all `.caf` files to the Xcode project's "Copy Bundle Resources" build phase. The `Sajda.xcodeproj` already includes them in the `Resources/Audio` group.
