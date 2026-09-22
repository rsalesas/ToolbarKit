import SwiftUI

/// How tall the titlebar is. Both sizes are macOS's own titlebar heights, so
/// the system itself places and centres the close, minimise and zoom buttons.
public enum TitlebarSize: String, Sendable, CaseIterable {
    /// The compact titlebar (40 pt on macOS 27).
    case small
    /// The standard titlebar (52 pt on macOS 27).
    case large

    /// The toolbar style whose height this size borrows.
    var toolbarStyle: NSWindow.ToolbarStyle {
        switch self {
        case .small: .unifiedCompact
        case .large: .unified
        }
    }

    /// The window title's size in the pre-glass style.
    var titlePointSize: CGFloat { self == .small ? 13 : 15 }
    var titleWeight: Font.Weight { self == .small ? .semibold : .bold }
}

/// What the bar is painted with.
public enum TitlebarBackground {
    /// The pre-glass titlebar material, blended with the window itself.
    case titlebar
    /// Opaque, in the titlebar's own tone: nothing shows through or blurs.
    /// Follows light and dark and the window's active state.
    case solid
    /// Blurs what is behind the window — the desktop, other windows — the
    /// way sidebars and menus do.
    case translucent
    /// A SwiftUI material over the window's own content, which shows through
    /// blurred when it scrolls under the bar.
    case material(Material)
    /// A flat colour.
    case color(Color)
    /// Nothing: whatever is behind the bar shows through unblurred.
    case clear
}

extension EnvironmentValues {
    /// The size of the titlebar the view is in, so its contents can adapt.
    @Entry public var titlebarSize: TitlebarSize = .large
}

public extension View {
    /// Puts `content` in the window's titlebar: a plain row you fill with
    /// anything — a title, buttons, a search field, tabs. The real close,
    /// minimise and zoom buttons stay where macOS puts them; the row starts
    /// after them. Dragging an empty part of the bar moves the window and a
    /// double-click does what the user chose in System Settings.
    ///
    /// Apply it once, to the root view of a window.
    func titlebar<Bar: View>(
        _ size: TitlebarSize = .large,
        background: TitlebarBackground = .titlebar,
        separator: Bool = true,
        @ViewBuilder content: () -> Bar
    ) -> some View {
        modifier(TitlebarModifier(size: size, background: background, separator: separator, bar: content()))
    }

    /// The window title, in the style that matches the titlebar's size.
    func titlebarTitle() -> some View {
        modifier(TitlebarTitleModifier())
    }
}

private struct TitlebarTitleModifier: ViewModifier {
    @Environment(\.titlebarSize) private var size
    @Environment(\.appearsActive) private var appearsActive

    func body(content: Content) -> some View {
        content
            .font(.system(size: size.titlePointSize, weight: size.titleWeight))
            .lineLimit(1)
            .opacity(appearsActive ? 1 : 0.5)
            // The title is part of the bar you drag the window by.
            .allowsHitTesting(false)
    }
}

/// The bar's content as hosted in the titlebar: the modifier's environment,
/// except whether the window is active, which is read where the bar actually
/// is. Copied from the content, it was sometimes left stale and the bar stayed
/// dimmed in an active window.
private struct HostedBar: View {
    let content: AnyView
    let environment: EnvironmentValues
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        content
            .environment(\.self, environment)
            .environment(\.appearsActive, appearsActive)
    }
}

private struct TitlebarModifier<Bar: View>: ViewModifier {
    let size: TitlebarSize
    let background: TitlebarBackground
    let separator: Bool
    let bar: Bar

    @State private var metrics = TitlebarMetrics()
    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        // The content keeps the safe area macOS gives it, which is the
        // titlebar's height. The bar's background and separator are drawn in
        // that band from here; its content lives in the titlebar itself (see
        // `WindowObserverView.barHost`), carrying this view's environment.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                barBackground
                    .frame(height: metrics.height)
                    .offset(y: -metrics.height)
                    .allowsHitTesting(false)
            }
            .background(WindowConfigurator(size: size, bar: AnyView(HostedBar(content: AnyView(barContent), environment: environment))) { metrics = $0 })
    }

    private var barContent: some View {
        HStack(spacing: 8) {
            bar
        }
        // Too much content for the width spills to the right and is clipped,
        // never leftwards into the window buttons. What to drop when narrow is
        // the app's call (ViewThatFits and friends).
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipped()
        .padding(.trailing, 12)
        // Empty parts of the bar drag the window and double-click to zoom.
        .background(WindowDragArea())
        .environment(\.titlebarSize, size)
    }

    private var barBackground: some View {
        backgroundView
            .overlay(alignment: .bottom) {
                if separator {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                }
            }
    }

    @ViewBuilder private var backgroundView: some View {
        switch background {
        case .titlebar: EffectView(blending: .withinWindow)
        case .solid:
            // The titlebar's tone on an opaque base: nothing scrolls through.
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                EffectView(blending: .withinWindow)
            }
            .compositingGroup()
        case .translucent: EffectView(blending: .behindWindow)
        case .material(let material): Rectangle().fill(material)
        case .color(let color): color
        case .clear: Color.clear
        }
    }
}

/// The titlebar's own material, as pre-glass windows drew it, blended either
/// with the window or with what is behind it. It follows the window's active
/// state, light and dark, and the user's contrast settings.
private struct EffectView: NSViewRepresentable {
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .titlebar
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.blendingMode = blending
    }
}
