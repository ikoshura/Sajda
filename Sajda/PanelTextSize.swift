// MARK: - BUAT FILE BARU: Sajda/PanelTextSize.swift

import SwiftUI
import AppKit

enum PanelTextSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case `default` = "Default"
    case large = "Large"
    case extraLarge = "Extra Large"
    case xxl = "XXL"

    var id: Self { self }

    // Properti untuk menampilkan nama yang sudah dilokalisasi di UI
    var localized: LocalizedStringKey {
        return LocalizedStringKey(self.rawValue)
    }

    // Faktor skala font untuk seluruh teks di dalam panel. macOS tidak punya
    // Dynamic Type seperti iOS (environment \.dynamicTypeSize diabaikan),
    // jadi pembesaran dilakukan manual lewat modifier `scaledFont` yang
    // membaca faktor ini dari environment. Teks di menu bar TIDAK ikut
    // diskalakan agar selalu mengikuti ukuran bawaan sistem.
    var fontScale: CGFloat {
        switch self {
        case .small: return 0.9
        case .default: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.45
        case .xxl: return 1.75
        }
    }

    // Pengali lebar panel agar teks yang membesar tidak terpotong
    // di kolom waktu shalat.
    var widthMultiplier: CGFloat {
        switch self {
        case .small: return 0.95
        case .default: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.45
        case .xxl: return 1.75
        }
    }

    // Ukuran dasar gaya .body bawaan sistem (13 pt), dipakai sebagai patokan
    // font environment di root panel untuk teks tanpa gaya eksplisit.
    static let baseBodyPointSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
}

// MARK: - Environment skala font panel

private struct PanelFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

private struct PanelBoldTextKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var panelFontScale: CGFloat {
        get { self[PanelFontScaleKey.self] }
        set { self[PanelFontScaleKey.self] = newValue }
    }

    /// Mode aksesibilitas "Bold Text": seluruh teks panel dinaikkan satu
    /// tingkat bobotnya agar lebih mudah dibaca pengguna low-vision.
    var panelBoldText: Bool {
        get { self[PanelBoldTextKey.self] }
        set { self[PanelBoldTextKey.self] = newValue }
    }
}

// MARK: - Modifier font yang diskalakan

private struct ScaledFontModifier: ViewModifier {
    @Environment(\.panelFontScale) private var scale
    @Environment(\.panelBoldText) private var boldText

    let style: Font.TextStyle
    var design: Font.Design = .default
    var weight: Font.Weight? = nil

    private var nsTextStyle: NSFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }

    private func nsWeight(for weight: Font.Weight?) -> NSFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    /// Bobot efektif setelah penyesuaian mode "Bold Text": setiap bobot
    /// dinaikkan satu tingkat; teks tanpa bobot eksplisit menjadi semibold.
    private var effectiveWeight: Font.Weight? {
        guard boldText else { return weight }
        guard let weight else { return .semibold }
        switch weight {
        case .ultraLight, .thin, .light: return .regular
        case .regular, .medium: return .semibold
        case .semibold: return .bold
        case .bold: return .heavy
        case .heavy, .black: return .black
        default: return .semibold
        }
    }

    func body(content: Content) -> some View {
        let base = NSFont.preferredFont(forTextStyle: nsTextStyle)
        let size = base.pointSize * scale
        // Dengan weight eksplisit kita bangun dari systemFont agar bobotnya
        // pasti diterapkan; tanpa weight kita pakai font bawaan gaya tersebut
        // (misal .headline yang sudah tebal) lalu ubah ukurannya saja.
        let resolvedWeight = effectiveWeight
        var descriptor = (resolvedWeight == nil ? base : NSFont.systemFont(ofSize: size, weight: nsWeight(for: resolvedWeight))).fontDescriptor
        if design == .monospaced, let mono = descriptor.withDesign(.monospaced) {
            descriptor = mono
        }
        let resolved = NSFont(descriptor: descriptor, size: size) ?? base
        return content.font(Font(resolved as CTFont))
    }
}

extension View {
    /// Gaya font relatif yang membesar/mengecil mengikuti preset ukuran teks
    /// panel (Settings > Text Size), untuk aksesibilitas pengguna dengan
    /// keterbatasan penglihatan. Menggantikan .font(.body) dsb. di dalam panel.
    func scaledFont(_ style: Font.TextStyle, design: Font.Design = .default, weight: Font.Weight? = nil) -> some View {
        modifier(ScaledFontModifier(style: style, design: design, weight: weight))
    }
}

// MARK: - Pemilih menu yang ikut diskalakan

/// Pengganti `Picker` gaya menu (.menu) untuk di dalam panel, dibungkus
/// sebagai NSPopUpButton asli lewat NSViewRepresentable. Picker SwiftUI gaya
/// memang memakai NSPopUpButton, tetapi font-nya mengabaikan environment dan
/// tidak bisa diubah; di sini kita memasang font yang sudah diskalakan
/// langsung ke sel tombol, sehingga teks pilihan membesar/mengecil mengikuti
/// preset Text Size SAMBIL mempertahankan latar tombol popup native seperti
/// sebelumnya. Tanda centang pada item terpilih, navigasi keyboard, dan
/// pembalikan tata letak RTL ditangani AppKit.
struct ScaledMenuPicker<Value: Hashable>: NSViewRepresentable {
    @Binding var selection: Value
    let options: [Value]
    /// Batas lebar opsional; judul terpotong di ujung bila melebihi.
    var maxWidth: CGFloat? = nil
    let titleFor: (Value) -> String

    @Environment(\.panelFontScale) private var scale
    @Environment(\.panelBoldText) private var boldText
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.layoutDirection) private var layoutDirection

    final class Coordinator: NSObject {
        var parent: ScaledMenuPicker
        var widthConstraint: NSLayoutConstraint?

        init(_ parent: ScaledMenuPicker) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            guard parent.options.indices.contains(index) else { return }
            let value = parent.options[index]
            if parent.selection != value {
                parent.selection = value
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configure(button, with: context.coordinator)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        configure(button, with: context.coordinator)
    }

    /// Ukuran kontrol dinaikkan untuk preset besar agar teks yang membesar
    /// tidak terpotong vertikal di dalam tombol; preset kecil/default tetap
    /// memakai ukuran .small seperti tampilan pengaturan sebelumnya.
    private var controlSize: NSControl.ControlSize {
        switch scale {
        case ..<1.05: return .small
        case ..<1.35: return .regular
        default: return .large
        }
    }

    private var scaledFont: NSFont {
        let base = NSFont.preferredFont(forTextStyle: .subheadline)
        let size = base.pointSize * scale
        // Mode aksesibilitas "Bold Text" menebalkan teks tombol popup juga.
        if boldText {
            return NSFont.systemFont(ofSize: size, weight: .semibold)
        }
        return NSFont(descriptor: base.fontDescriptor, size: size) ?? base
    }

    private func configure(_ button: NSPopUpButton, with coordinator: Coordinator) {
        let font = scaledFont

        button.font = font
        button.controlSize = controlSize
        button.isEnabled = isEnabled
        button.userInterfaceLayoutDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        (button.cell as? NSPopUpButtonCell)?.lineBreakMode = .byTruncatingTail

        button.removeAllItems()
        for option in options {
            let title = titleFor(option)
            button.addItem(withTitle: title)
            // Font pada item menu juga diskalakan agar daftar yang terbuka
            // tetap terbaca pada preset besar.
            button.lastItem?.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.font: font]
            )
        }

        if let index = options.firstIndex(of: selection), button.indexOfSelectedItem != index {
            button.selectItem(at: index)
        }

        coordinator.widthConstraint?.isActive = false
        if let maxWidth {
            button.translatesAutoresizingMaskIntoConstraints = false
            let constraint = button.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth * scale)
            constraint.isActive = true
            coordinator.widthConstraint = constraint
        } else {
            coordinator.widthConstraint = nil
        }
    }
}
