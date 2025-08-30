# Sajda - A Minimalist Prayer Times App for macOS

![Sajda App Screenshot](https://github.com/user-attachments/assets/6e8bd922-a446-4b33-a184-e5e89493a4b1)

## About The Project

As a Muslim who uses a Mac all day, I was looking for a prayer times app that was minimalist, fast, and felt truly native to macOS. Many of the available apps felt like clunky ports, had outdated designs, or were filled with features I didn't need.

Sajda is the app I wanted for myself. It's built entirely in modern SwiftUI to be a "calm" and quiet companion that lives in your menu bar, respects your focus, and feels like it belongs on your Mac.

This project is fully open-source. I built it to solve my own problem, but I hope others find it useful too.

## Features

Sajda is designed to be simple on the surface but powerful when you need it.

#### ✨ Native Look & Feel
*   **Menu Bar Native:** Lives entirely in the menu bar, saving screen space and staying out of your way.
*   **SwiftUI Built:** A modern, fast, and efficient app built with the latest Apple technologies.
*   **Light & Dark Mode:** Automatically adapts to your system's appearance.
*   **No Dock Icon:** Runs as a quiet background agent (`UIElement`), just like it should.

#### 🕌 Accurate & Flexible Prayer Times
*   **Smart Location:** Automatically detects your location for precise prayer times. You can also search for and set any city in the world manually.
*   **Trusted Calculation Methods:** Choose from several standard calculation methods (e.g., Muslim World League, ISNA, Karachi, Umm al-Qura) to match your preference.
*   **Hanafi Madhhab:** A dedicated toggle to adjust the Asr prayer time according to the Hanafi school.

#### 🛠️ Deep Customization
*   **Customizable Menu Bar:** Choose exactly what you see:
    *   A simple moon icon.
    *   A countdown to the next prayer (`Asr in 24m`).
    *   The exact time of the next prayer (`Maghrib at 6:05 PM`).
*   **Precision Time Correction:** A key feature for ultimate accuracy. If your local mosque's schedule differs from standard calculations, you can manually adjust *each* of the five daily prayers (+/- 60 minutes) using a simple, clean stepper interface.
*   **Optional Sunnah Prayers:** Choose to show or hide the times for Tahajud and Dhuha.
*   **Native Accent Color:** Uses your Mac's own system accent color to highlight the next prayer for a beautifully integrated feel.

#### 🔔 System Integration
*   **Native Notifications:** Get gentle, standard macOS notifications to remind you a few minutes before each prayer begins.
*   **Run at Login:** Set it once and forget it. Sajda can launch automatically and silently every time you start your Mac.

---

## Installation

**➡️ [Download Sajda now on Gumroad](https://ikoshura.gumroad.com/l/sajda)**
Or check out the [Releases page on GitHub](https://github.com/ikoshura/Sajda/releases/tag/1.0.0).

### Important: First-Time Launch Instructions
Because I'm a solo developer and can't yet afford Apple's developer program fee, this app isn't "signed." This is perfectly safe, but it means you must give macOS permission to open it the first time.

The easiest way is to **right-click** (or Control-click) the **Sajda** app icon in your Applications folder and select **Open**.

<details>
<summary><strong>Troubleshooting?</strong> Click here for the complete, detailed installation guide.</summary>

Here are three methods to get the app running. If the first one doesn't work, try the next.

---

### **Method 1: The Easiest Way (Right-Click to Open)**

This is the quickest method and works for most users.

1. After downloading, drag the **Sajda** app into your **Applications** folder.
2. Find **Sajda** in your Applications folder, but don't double-click it.
3. Right-click (or hold the **Control** key and click) on the **Sajda** app icon.
4. Select **Open** from the top of the menu that appears.
5. A warning pop-up will appear, but this time it will include an **Open** button. Click it.

That’s it! **Sajda** will now be saved as a safe app on your Mac and you can open it normally from now on.

---

### **Method 2: Using System Settings**

If you accidentally clicked **Cancel** or the method above didn’t work, this is the official way to create an exception.

1. Try to open **Sajda** by double-clicking it. A warning will appear saying it cannot be opened. Click **OK**. (This step is necessary to make the next option appear).
2. Open **System Settings** (in older macOS versions, this is called **System Preferences**).
3. Go to **Privacy & Security**.
4. Scroll down until you see the **Security** section. You will find a message that says "`Sajda` was blocked from use because it is not from an identified developer."
5. Click the **Open Anyway** button next to the message. You may be asked for your Mac's password.

After this, **Sajda** is approved and will open without any more warnings.

---

### **Method 3: The Guaranteed Fix (Using Terminal)**

If the methods above still don’t work (especially on the newest macOS versions), you can manually remove the "quarantine" flag that macOS places on downloaded apps. This may seem technical, but it's just a simple copy-paste!

1. Open the **Terminal** app.
   (You can find it in your **Applications > Utilities** folder, or just search for "Terminal" in **Spotlight**).

2. Carefully copy the following command (don’t press **Return** yet):

   ```
   xattr -r -d com.apple.quarantine 
   ```

3. Paste the command into the Terminal window, then press the **spacebar** once. Your window should now look like this:

   ```
   xattr -r -d com.apple.quarantine 
   ```

4. Find the **Sajda** app in your **Applications** folder and drag the app icon directly onto the Terminal window. The path to the app will appear automatically after the command.
   (It will look something like this after dragging):

   ```
   xattr -r -d com.apple.quarantine /Applications/Sajda.app
   ```

5. Press **Return** (or **Enter**).

That’s it! The quarantine flag has been removed. You can now close the Terminal and open **Sajda** normally by double-clicking it.

</details>

---

## Building from Source

1.  Clone the repository:
    ```sh
    git clone https://github.com/ikoshura/sajda.git
    ```
2.  Open the `Sajda.xcodeproj` file in Xcode.
3.  This project uses the `Adhan` library via Swift Package Manager, which should be fetched automatically.
4.  Press ▶ to build and run.

---

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

## Acknowledgements
*   [Adhan](https://github.com/batoulapps/Adhan) - The core library used for calculating prayer times.
*   [FluidMenuBarExtra](https://github.com/lfroms/fluid-menu-bar-extra) - For the dynamically resizing pop-up window.
