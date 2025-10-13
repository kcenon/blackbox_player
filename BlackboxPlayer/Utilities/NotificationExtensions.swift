import Foundation

extension Notification.Name {
    static let openFolderRequested = Notification.Name("openFolderRequested")
    static let refreshFileListRequested = Notification.Name("refreshFileListRequested")
    static let toggleSidebarRequested = Notification.Name("toggleSidebarRequested")
    static let toggleMetadataOverlayRequested = Notification.Name("toggleMetadataOverlayRequested")
    static let toggleMapOverlayRequested = Notification.Name("toggleMapOverlayRequested")
    static let toggleGraphOverlayRequested = Notification.Name("toggleGraphOverlayRequested")
    static let playPauseRequested = Notification.Name("playPauseRequested")
    static let stepForwardRequested = Notification.Name("stepForwardRequested")
    static let stepBackwardRequested = Notification.Name("stepBackwardRequested")
    static let increaseSpeedRequested = Notification.Name("increaseSpeedRequested")
    static let decreaseSpeedRequested = Notification.Name("decreaseSpeedRequested")
    static let normalSpeedRequested = Notification.Name("normalSpeedRequested")
    static let showAboutRequested = Notification.Name("showAboutRequested")
    static let showHelpRequested = Notification.Name("showHelpRequested")
}
