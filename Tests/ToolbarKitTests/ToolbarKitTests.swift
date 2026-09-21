import AppKit
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
