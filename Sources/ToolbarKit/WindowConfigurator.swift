import AppKit
import SwiftUI

/// What the bar needs to know about the window it sits in.
struct TitlebarMetrics: Equatable {
    /// The titlebar's height: window height minus the content layout height.
    var height: CGFloat = 0
    /// Where the bar's content may start: after the zoom button.
    var leadingInset: CGFloat = 16
    /// Padding before the bar's content, so it starts `gapAfterWindowButtons`
    /// after the zoom button wherever the titlebar placed the accessory.
    var contentPadding: CGFloat = 0
}

extension TitlebarMetrics {
    /// The gap between the zoom button and the bar's first item.
    /// Clearly wider than the 9 pt between the window buttons themselves, so a
    /// title does not read as a fourth button.
    static let gapAfterWindowButtons: CGFloat = 16

    /// `zoomButtonMaxX` is nil when the buttons are hidden (full screen).
    static func leadingInset(zoomButtonMaxX: CGFloat?) -> CGFloat {
        guard let maxX = zoomButtonMaxX else { return gapAfterWindowButtons }
        return maxX + gapAfterWindowButtons
    }
}

/// Configures the window it lands in and reports the titlebar's metrics.
///
/// The window keeps a real titlebar and an *empty* toolbar. The toolbar has no
/// items — nothing for glass to draw on — and exists only because its style
/// sets the titlebar's height, so macOS itself positions the close, minimise
/// and zoom buttons for either size, in every window state. Nothing in the
/// window's view hierarchy is moved or looked up by class name.
struct WindowConfigurator: NSViewRepresentable {
    let size: TitlebarSize
    /// The bar's interactive content, hosted in the titlebar itself.
    let bar: AnyView
    let onChange: (TitlebarMetrics) -> Void

    func makeNSView(context: Context) -> WindowObserverView {
        let view = WindowObserverView()
        view.size = size
        view.onChange = onChange
        view.barHost.rootView = bar
        return view
    }

    func updateNSView(_ view: WindowObserverView, context: Context) {
        view.onChange = onChange
        view.barHost.rootView = bar
        if view.size != size {
            view.size = size
            view.configure()
        }
    }
}

@MainActor
final class WindowObserverView: NSView {
    var size: TitlebarSize = .large
    var onChange: (TitlebarMetrics) -> Void = { _ in }
    private var tokens: [NSObjectProtocol] = []
    private var lastMetrics = TitlebarMetrics()
    /// The last height measured outside full screen, where the toolbar moves
    /// into a window of its own and the content's titlebar band is empty.
    private var windowedHeight: CGFloat = 0

    /// The bar's content, in a titlebar accessory rather than over the window's
    /// content. While the app is active the titlebar takes every click in its
    /// band, whatever is drawn there, so controls laid over it from the content
    /// view could not be clicked. Views in an accessory are the titlebar's own,
    /// and AppKit delivers their clicks as it does anywhere else.
    let barHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let accessory = NSTitlebarAccessoryViewController()

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        for token in tokens { NotificationCenter.default.removeObserver(token) }
        tokens = []
        guard let window else { return }
        configure()
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
        ]
        for name in names {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.measure() }
            })
        }
    }

    func configure() {
        // Only a titled window has a titlebar to configure. AppKit throws
        // (NSInternalInconsistencyException) when a titlebar accessory is added to a
        // borderless window, and that is where a view ends up when it is hosted
        // off-screen — a snapshot, a smoke test — or in a custom panel. There the bar
        // simply has nowhere to go, which is not worth crashing the app over.
        guard let window, window.styleMask.contains(.titled) else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.tabbingMode = .disallowed
        if !(window.toolbar is TitlebarSizingToolbar) {
            window.toolbar = TitlebarSizingToolbar()
        }
        window.toolbarStyle = size.toolbarStyle
        if !window.titlebarAccessoryViewControllers.contains(accessory) {
            barHost.sizingOptions = []
            accessory.view = barHost
            accessory.layoutAttribute = .leading
            window.addTitlebarAccessoryViewController(accessory)
        }
        // The height settles after the titlebar's next layout pass.
        DispatchQueue.main.async { [weak self] in self?.measure() }
    }

    func measure() {
        guard let window else { return }
        let fullScreen = window.styleMask.contains(.fullScreen)
        var height = window.frame.height - window.contentLayoutRect.height
        if fullScreen {
            height = windowedHeight > 0 ? windowedHeight : height
        } else {
            windowedHeight = height
        }
        let zoom = window.standardWindowButton(.zoomButton)
        let zoomMaxX = (fullScreen || zoom?.isHidden != false) ? nil : zoom.map { $0.convert($0.bounds, to: nil).maxX }
        var metrics = TitlebarMetrics(height: height, leadingInset: TitlebarMetrics.leadingInset(zoomButtonMaxX: zoomMaxX))
        // From where the titlebar put the accessory, after the window buttons,
        // to the window's trailing edge.
        let barMinX = barHost.window == nil ? metrics.leadingInset : barHost.convert(barHost.bounds, to: nil).minX
        let barWidth = max(0, window.frame.width - barMinX)
        metrics.contentPadding = max(0, metrics.leadingInset - barMinX)
        if barHost.frame.size != CGSize(width: barWidth, height: height) {
            barHost.setFrameSize(CGSize(width: barWidth, height: height))
        }
        guard metrics != lastMetrics else { return }
        lastMetrics = metrics
        onChange(metrics)
    }
}

/// A toolbar with nothing in it. Its only job is the titlebar's height.
final class TitlebarSizingToolbar: NSToolbar {
    init() {
        super.init(identifier: "ToolbarKit.titlebar")
        allowsUserCustomization = false
        displayMode = .iconOnly
    }
}
