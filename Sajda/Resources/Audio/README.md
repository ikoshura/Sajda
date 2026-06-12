# Azan Audio Files

Place the following CC0/public domain azan audio files in this directory:

## Fajr Azan (must include "As-salatu khayrum minan-nawm")
- `adhan_fajr_1.caf`
- `adhan_fajr_2.caf`

## Standard Azan (without Fajr addition)
- `adhan_standard_1.caf`
- `adhan_standard_2.caf`
- `adhan_standard_3.caf`

## Recommended Sources (Copyright-Safe)
- Wikimedia Commons (CC0 1.0): https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg
- Internet Archive - Doha Qatar (Public Domain): https://archive.org/details/adhan.recordings.from.doha.qatar
- Pixabay (Royalty-free): https://pixabay.com/sound-effects/search/call-to-prayer/

## Notes
- Files must be in CAF format (AAC or PCM) for UNNotificationSound compatibility
- Convert from MP3 using: `afconvert input.mp3 output.caf -d aac -f caff`
- Trim to ~60-90 seconds for in-app playback (system caps notification sound at 30s)
- Verify Fajr variants contain "As-salatu khayrum minan-nawm"
- Add files to Xcode project's "Copy Bundle Resources" build phase
