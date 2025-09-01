# Sajda - A Minimalist Prayer Times App for macOS

![Sajda App Screenshot](https://github.com/user-attachments/assets/6e8bd922-a446-4b33-a184-e5e89493a4b1) 

## About The Project

As a Muslim working on a Mac, I simply wanted a prayer app that felt as clean and calm as macOS itself. Many of the options available felt cluttered or didn't quite fit the native experience I was looking for.

That's why I built Sajda. It’s a simple and beautiful prayer times app for your menu bar. It delivers accurate schedules and gentle reminders directly on your desktop. It’s designed to be present when you need it and invisible when you don’t, helping you integrate moments of prayer into your day without distraction.

This project is fully open-source. I built it to solve my own problem, and I hope you find it useful too.

## Features

Sajda is designed to be simple on the surface but powerful and deeply customizable when you need it.

#### ✨ Native Look & Feel
*   **Menu Bar Native:** Lives entirely in the menu bar, saving screen space and staying out of your way.
*   **SwiftUI Built:** A modern, fast, and efficient app built with the latest Apple technologies.
*   **Light & Dark Mode:** Automatically adapts to your system's appearance.
*   **No Dock Icon:** Runs as a quiet background agent (`LSUIElement`), just like a proper menu bar utility.
*   **Polished Onboarding:** A beautiful and helpful welcome guide to get you started.

#### 🕌 Accurate & Flexible Prayer Times
*   **Smart Location:** Automatically detects your location for precise prayer times.
*   **Manual Location:** Search for and set any city in the world, or input latitude/longitude coordinates directly.
*   **Trusted Calculation Methods:** Choose from a wide range of standard methods (MWL, ISNA, Umm al-Qura, Kemenag, Diyanet, etc.).
*   **Hanafi Madhhab:** A dedicated toggle to adjust the Asr prayer time.
*   **Precision Time Correction:** Manually adjust *each* of the five daily prayers (+/- 60 minutes) to perfectly match your local mosque.
*   **Smart Timezone Handling:** Automatically applies the correct timezone for any manually set location.

#### 🛠️ Deep Customization
*   **Customizable Menu Bar:** Choose exactly what you see:
    *   A simple moon icon.
    *   A countdown to the next prayer (`Asr in 24m`).
    *   The exact time of the next prayer (`Maghrib at 6:05 PM`).
    *   A compact, minimal text style (`Asr -2h 4m`).
*   **Optional Sunnah Prayers:** Choose to show or hide the times for Tahajud and Dhuha.
*   **Selectable Animations:** Choose between a modern "Fade," a classic "Slide," or "None" for instant transitions.
*   **Native Accent Color:** Uses your Mac's own system accent color to highlight the next prayer for a beautifully integrated feel.

#### 🔔 System Integration
*   **Native Notifications:** Get gentle, standard macOS notifications to remind you before each prayer begins.
*   **Custom Sounds:** Choose between the default beep, no sound, or select your own custom audio file for notifications.
*   **Run at Login:** Set it once and forget it. Sajda can launch automatically and silently every time you start your Mac.
*   **Multi-Language Support:** Full interface localization for English, Arabic (العربية), and Indonesian, including proper Right-to-Left (RTL) support.

---

## Installation

**➡️ [Download Sajda Pro on Gumroad](https://ikoshura.gumroad.com/l/sajda)**
Or check out the [Releases page on GitHub](https://github.com/ikoshura/Sajda/releases).

#### Important: First-Time Launch Instructions
Because this app is built by a solo developer and isn't on the App Store yet, it isn't "signed." This is perfectly safe, but it means you must give macOS permission to open it the first time.

The easiest way is to **right-click** (or Control-click) the **Sajda** app icon in your Applications folder and select **Open**.

<details>
<summary><strong>Troubleshooting? Click here for the complete installation guide.</strong></summary>

Here are three methods to get the app running. If the first one doesn't work, try the next.

---

### **Method 1: The Easiest Way (Right-Click to Open)**

This is the quickest method and works for most users.

1.  After downloading, drag the **Sajda** app into your **Applications** folder.
2.  Find **Sajda** in your Applications folder, but don't double-click it.
3.  Right-click (or hold the **Control** key and click) on the **Sajda** app icon.
4.  Select **Open** from the top of the menu that appears.
5.  A warning pop-up will appear, but this time it will include an **Open** button. Click it.

That’s it! **Sajda** will now be saved as a safe app on your Mac and you can open it normally from now on.

---

### **Method 2: Using System Settings**

If you accidentally clicked **Cancel** or the method above didn’t work, this is the official way to create an exception.

1.  Try to open **Sajda** by double-clicking it. A warning will appear saying it cannot be opened. Click **OK**. (This step is necessary to make the next option appear).
2.  Open **System Settings** (in older macOS versions, this is called **System Preferences**).
3.  Go to **Privacy & Security**.
4.  Scroll down until you see the **Security** section. You will find a message that says "`Sajda` was blocked from use because it is not from an identified developer."
5.  Click the **Open Anyway** button next to the message. You may be asked for your Mac's password.

After this, **Sajda** is approved and will open without any more warnings.

---

### **Method 3: The Guaranteed Fix (Using Terminal)**

If the methods above still don’t work, you can manually remove the "quarantine" flag that macOS places on downloaded apps.

1.  Open the **Terminal** app. (You can find it in your **Applications > Utilities** folder, or just search for "Terminal" in **Spotlight**).

2.  Carefully copy and paste the following command, followed by a **space**:
    ```
    xattr -r -d com.apple.quarantine 
    ```

3.  Find the **Sajda** app in your **Applications** folder and drag the app icon directly onto the Terminal window. The path to the app will appear automatically.
   (It will look something like this):
    ```
    xattr -r -d com.apple.quarantine /Applications/Sajda.app
    ```

4.  Press **Return** (or **Enter**).

The quarantine flag is now removed. You can close the Terminal and open **Sajda** normally.

</details>

---

## System Requirements
*   **macOS Ventura (13.0) or later.**
*   Compatible with both **Apple Silicon** (M1, M2, etc.) and **Intel-based** Macs.

As a testament to its efficiency, Sajda was developed and tested on a 2012 MacBook Pro (using Ventura OCLP) . It is designed to be extremely lightweight and will not slow down your machine.


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
*   [FluidMenuBarExtra](https://github.com/lfroms/fluid-menu-bar-extra) - For the dynamically resizing menu bar window.
*   [NavigationStack](https://github.com/indieSoftware/NavigationStack) - For the flexible view navigation system.
