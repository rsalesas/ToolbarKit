import SwiftUI
import ToolbarKit

@main
struct TitlebarDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoView()
                .onAppear { NSApplication.shared.activate() }
        }
        .defaultSize(width: 900, height: 560)
    }
}

/// One window with a ToolbarKit titlebar and the switches to try it.
/// Launch arguments set the starting state, for screenshots:
/// `-size small|large`, `-appearance light|dark`, `-separator NO`,
/// `-background titlebar|solid|translucent|thin|regular|bar|clear`, `-window opaque|translucent`,
/// `-scroll <row>` to start scrolled so that row sits under the bar.
struct DemoView: View {
    private static let defaults = UserDefaults.standard
    @State private var size = TitlebarSize(rawValue: defaults.string(forKey: "size") ?? "") ?? .large
    @State private var appearance = defaults.string(forKey: "appearance") ?? "system"
    @State private var separator = defaults.object(forKey: "separator") as? Bool ?? true
    @State private var background = defaults.string(forKey: "background") ?? "titlebar"
    @State private var translucentWindow = defaults.string(forKey: "window") == "translucent"
    @State private var query = ""
    @State private var lastAction = "nothing yet"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                    stripes
                }
                .padding(24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                let row = Self.defaults.integer(forKey: "scroll")
                if row > 0 { DispatchQueue.main.async { proxy.scrollTo(row, anchor: .top) } }
            }
        }
        .titlebar(size, background: titlebarBackground, separator: separator) {
            Button("Back", systemImage: "chevron.left") { lastAction = "Back" }
            Button("Forward", systemImage: "chevron.right") { lastAction = "Forward" }
            Text("Inbox").titlebarTitle()
            Spacer()
            Button("Compose", systemImage: "square.and.pencil") { lastAction = "Compose" }
            Button("Archive", systemImage: "archivebox") { lastAction = "Archive" }
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
        }
        .buttonStyle(.titlebar)
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .modifier(WindowTranslucency(enabled: translucentWindow))
    }

    private var titlebarBackground: TitlebarBackground {
        switch background {
        case "solid": .solid
        case "translucent": .translucent
        case "thin": .material(.thinMaterial)
        case "regular": .material(.regularMaterial)
        case "bar": .material(.bar)
        case "clear": .clear
        default: .titlebar
        }
    }

    private var controls: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Titlebar size", selection: $size) {
                    Text("Small").tag(TitlebarSize.small)
                    Text("Large").tag(TitlebarSize.large)
                }
                Picker("Bar background", selection: $background) {
                    Text("Titlebar").tag("titlebar")
                    Text("Solid").tag("solid")
                    Text("Translucent (desktop)").tag("translucent")
                    Text("Thin material").tag("thin")
                    Text("Regular material").tag("regular")
                    Text("Bar material").tag("bar")
                    Text("Clear").tag("clear")
                }
                Toggle("Translucent window (desktop shows through)", isOn: $translucentWindow)
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Toggle("Separator line", isOn: $separator)
                LabeledContent("Last button clicked", value: lastAction)
                Text("Scroll the stripes up under the bar to see how each background lets them through.")
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var stripes: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { i in
                Color(hue: Double(i) / 24, saturation: 0.7, brightness: 0.9)
                    .frame(height: 40)
                    .overlay(Text("Row \(i + 1)").font(.headline).foregroundStyle(.white))
                    .id(i + 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// `.containerBackground(…, for: .window)` (macOS 15) replaces the window's
/// background with a material, so the desktop blurs through behind it.
private struct WindowTranslucency: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.containerBackground(.thinMaterial, for: .window)
        } else {
            content
        }
    }
}
