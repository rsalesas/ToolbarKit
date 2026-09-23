import AppKit
import SwiftUI
import Testing
@testable import ToolbarKit

@Test func versionIsSet() {
    #expect(!ToolbarKit.version.isEmpty)
}

@Test(arguments: [
    ("Maximize", false, DoubleClickAction.zoom),
    ("Fill", false, .zoom),
    ("Minimize", false, .minimize),
    ("None", false, .none),
    (nil, false, .zoom),
    (nil, true, .minimize),
    ("Maximize", true, .zoom),
] as [(String?, Bool, DoubleClickAction)])
func doubleClickFollowsSystemSetting(value: String?, legacy: Bool, expected: DoubleClickAction) {
    #expect(DoubleClickAction(defaultsValue: value, legacyMinimize: legacy) == expected)
}

@Test func sizesBorrowTheSystemToolbarStyles() {
    #expect(TitlebarSize.small.toolbarStyle == .unifiedCompact)
    #expect(TitlebarSize.large.toolbarStyle == .unified)
    #expect(TitlebarSize.small.titlePointSize < TitlebarSize.large.titlePointSize)
}

@Test func barStartsAfterTheZoomButton() {
    #expect(TitlebarMetrics.leadingInset(zoomButtonMaxX: 74) == 74 + TitlebarMetrics.gapAfterWindowButtons)
    #expect(TitlebarMetrics.leadingInset(zoomButtonMaxX: nil) == TitlebarMetrics.gapAfterWindowButtons)
}

/// A titlebar view hosted in a window with no titlebar — how tests and snapshots
/// usually host a view — must lay out rather than throw. AppKit raises
/// NSInternalInconsistencyException for a titlebar accessory on a borderless window,
/// which took down every test run of an app that used `.titlebar`.
@MainActor
@Test func aBorderlessWindowIsLeftAlone() {
    let host = NSHostingView(rootView: Text("Content").titlebar { Text("Bar") })
    host.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless],
                          backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    // Not `titlebarAccessoryViewControllers`: on a borderless window even reading it
    // throws. Untouched is what matters — no toolbar, no style changes.
    #expect(window.toolbar == nil)
    #expect(window.styleMask == [.borderless])
}
