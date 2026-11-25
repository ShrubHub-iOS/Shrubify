import UIKit

/// Delivers Spotify links to this app's own navigation handlers.
@MainActor
enum PlayerArtistNavigation {
    @discardableResult
    static func open(id: String, in scene: UIWindowScene?, dispatch: (String) -> Bool) -> Bool {
        guard let uri = URL(string: "spotify:artist:\(id)"),
              let webURL = URL(string: "https://open.spotify.com/artist/\(id)") else { return false }
        if dispatch(uri.absoluteString) { return true }

        let app = UIApplication.shared
        if app.delegate?.application?(app, open: uri, options: [:]) == true { return true }
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = webURL
        if app.delegate?.application?(app, continue: activity, restorationHandler: { _ in }) == true { return true }
        let selector = NSSelectorFromString("scene:continueUserActivity:")
        guard let scene, let delegate = scene.delegate, delegate.responds(to: selector) else { return false }
        delegate.scene?(scene, continue: activity)
        return true
    }
}
