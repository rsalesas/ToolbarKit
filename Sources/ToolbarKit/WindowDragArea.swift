import AppKit
import SwiftUI

/// What a double-click on the titlebar does, as the user set it in
/// System Settings › Desktop & Dock.
enum DoubleClickAction: Equatable {
    case zoom, minimize, none

    /// `value` is `AppleActionOnDoubleClick` from the global domain; `legacyMinimize`
    /// is the older `AppleMiniaturizeOnDoubleClick` switch, used when the first is absent.
    init(defaultsValue value: String?, legacyMinimize: Bool) {
        switch value {
        case "Minimize": self = .minimize
        case "None": self = .none
        // "Maximize" is zoom; "Fill" is the tiling fill, for which zoom is
        // the nearest public behaviour.
        case "Maximize", "Fill": self = .zoom
        default: self = legacyMinimize ? .minimize : .zoom
        }
    }

    static var current: DoubleClickAction {
        let defaults = UserDefaults.standard
        return DoubleClickAction(
            defaultsValue: defaults.string(forKey: "AppleActionOnDoubleClick"),
            legacyMinimize: defaults.bool(forKey: "AppleMiniaturizeOnDoubleClick")
        )
    }
}

/// The empty part of the bar: dragging it moves the window, double-clicking
/// it zooms or minimises. It sits behind the bar's content, so buttons and
/// fields keep their own clicks.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount == 2 {
                switch DoubleClickAction.current {
                case .zoom: window.performZoom(nil)
                case .minimize: window.performMiniaturize(nil)
                case .none: break
                }
            } else {
                window.performDrag(with: event)
            }
        }
    }
}

public extension ButtonStyle where Self == TitlebarButtonStyle {
    /// A borderless titlebar button in the pre-glass style: no capsule, a
    /// soft rounded highlight on hover and a darker one while pressed.
    static var titlebar: TitlebarButtonStyle { TitlebarButtonStyle() }
}

public struct TitlebarButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration)
    }

    private struct StyledButton: View {
        let configuration: Configuration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.titlebarSize) private var size
        @Environment(\.appearsActive) private var appearsActive

        var body: some View {
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: size == .small ? 14 : 16))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .opacity(appearsActive ? 1 : 0.5)   // dims with the window, as the bar used to
                .frame(minWidth: size == .small ? 26 : 32, minHeight: size == .small ? 22 : 28)
                .padding(.horizontal, 2)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : (hovering && isEnabled ? 0.08 : 0)))
                }
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}
