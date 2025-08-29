// Salin dan tempel SELURUH kode ini ke dalam file FluidMenuBar/FluidMenuBarExtra.swift
import SwiftUI

public final class FluidMenuBarExtra {
    private let statusItem: FluidMenuBarExtraStatusItem
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
    public func updateTitle(to newTitle: String) {
        statusItem.updateTitle(to: newTitle)
    }
}
