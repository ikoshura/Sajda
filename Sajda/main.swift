// MARK: - BUAT FILE BARU: Sajda/main.swift

import AppKit

// Titik masuk utama aplikasi kita.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
