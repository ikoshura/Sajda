import SwiftUI

public final class FluidMenuBarExtra {
    public let statusItem: FluidMenuBarExtraStatusItem
    public init(title: String, @ViewBuilder content: @escaping () -> some View) {
        let window = FluidMenuBarExtraWindow(title: title, content: content)
        statusItem = FluidMenuBarExtraStatusItem(title: title, window: window)
    }
    public init(title: String, image: String, @ViewBuilder content: @escaping () -> some View) {
        let window = FluidMenuBarExtraWindow(title: title, content: content)
        statusItem = FluidMenuBarExtraStatusItem(title: title, image: image, window: window)
    }
    public init(title: String, systemImage: String, @ViewBuilder content: @escaping () -> some View) {
        let window = FluidMenuBarExtraWindow(title: title, content: content)
        statusItem = FluidMenuBarExtraStatusItem(title: title, systemImage: systemImage, window: window)
    }
    
    // --- PERUBAHAN: Overload fungsi untuk menerima NSAttributedString ---
    public func updateTitle(to newTitle: NSAttributedString) {
        statusItem.updateTitle(to: newTitle)
    }
}
