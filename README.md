# Sajda - A Minimalist Prayer Times App for macOS

![Sajda App Screenshot](https://github.com/user-attachments/assets/6e8bd922-a446-4b33-a184-e5e89493a4b1)

**Sajda** is a clean and simple prayer times app designed for your Mac's menu bar. It's built to be quiet, beautiful, and minimal, providing you with accurate prayer times and gentle reminders in a sleek, unobtrusive design.

---

## Features

* **Accurate Prayer Times**
  Automatically detects your location or allows you to set your location manually for precise prayer times.

* **Quiet Notifications**
  Receive gentle, non-intrusive reminders shortly before each prayer time.

* **Minimalist Design**
  A clean, elegant interface that feels native to macOS.

* **Lightweight & Fast**
  Sajda is optimized to be lightweight, ensuring it won’t slow down your Mac.

---

## Customization Options

* **Adjustable Times**
  Manually fine-tune each prayer time (+/- 60 minutes) to match your local mosque's schedule.

* **Custom Menu Bar Item**
  Choose how you want to display the app in your menu bar:

  * Icon only
  * Next prayer time
  * Countdown to the next prayer

* **Sunnah Prayers**
  Option to show or hide **Tahajud** and **Dhuha** prayer times.

---

## Installation

1. Download the app from the [releases section](#) of this repository.
2. Open the `.dmg` file and drag the app to your Applications folder.
3. Launch the app from your Applications folder and customize your settings as desired.

---

## A Quick Guide to Installing Sajda

### (For First-Time Installation on macOS)

Since I’m a solo developer and can’t yet afford Apple's expensive developer program fee, this app isn’t signed through their official program. This is perfectly safe, but macOS's security feature, **Gatekeeper**, will ask for your permission to run Sajda the first time.

Follow the steps below to grant that permission. You only need to do this once.

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

### **Method 3: Using Terminal**

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

---

## Contributing

We welcome contributions! Feel free to fork the repository, create a branch, and submit pull requests. If you encounter any issues or have feature requests, please open an issue on the GitHub page.

---

## License

Sajda is released under the [MIT License](LICENSE).
