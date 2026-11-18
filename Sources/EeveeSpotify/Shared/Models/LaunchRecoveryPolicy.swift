import Foundation

/// A persisted startup probe, not an assertion that an exit was a crash.
/// A healthy main run loop or a graceful background transition clears it.
enum LaunchRecoveryPolicy {
    static let pendingKey = "ShrubifyLaunchProbePending"
    static let recoveryKey = "ShrubifyRecoveredIncompleteLaunch"

    static func begin(in defaults: UserDefaults) -> Bool {
        let incomplete = defaults.bool(forKey: pendingKey)
        if incomplete {
            defaults.set(true, forKey: "ShrubifyStabilityMode")
            defaults.set(true, forKey: recoveryKey)
        }
        defaults.set(true, forKey: pendingKey)
        // This probe must survive an immediate abort before defaults' normal flush.
        _ = defaults.synchronize()
        return incomplete
    }

    static func complete(in defaults: UserDefaults) {
        defaults.set(false, forKey: pendingKey)
        _ = defaults.synchronize()
    }
}
