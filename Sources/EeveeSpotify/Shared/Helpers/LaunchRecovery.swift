import Foundation
import UIKit

enum LaunchRecovery {
    private static var backgroundObserver: NSObjectProtocol?

    static func begin() {
        let defaults = UserDefaults.standard
        if LaunchRecoveryPolicy.begin(in: defaults) {
            eeveeBreadcrumb("Recovery: previous startup did not complete; optional interface hooks disabled")
        }
        DispatchQueue.main.async {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { _ in LaunchRecoveryPolicy.complete(in: defaults) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            LaunchRecoveryPolicy.complete(in: defaults)
        }
    }
}
