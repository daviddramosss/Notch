// PinnedApp.swift

import Foundation
import AppKit

struct PinnedApp: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var bundleIdentifier: String
    var isEnabled: Bool = true
    var customIconSymbol: String? = nil
    
    static let defaultApps: [PinnedApp] = [
        PinnedApp(
            name: "Discord",
            bundleIdentifier: "com.hnc.Discord",
            isEnabled: true,
            customIconSymbol: "bubble.left.and.bubble.right.fill"
        ),
        PinnedApp(
            name: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            isEnabled: true,
            customIconSymbol: "terminal.fill"
        )
    ]
}
