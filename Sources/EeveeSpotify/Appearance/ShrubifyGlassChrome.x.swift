import UIKit

/// Retained activation name for compatibility with EvolvedIntegration.
/// Deliberately does not hook UIWindow.layoutSubviews. Both bar hosts have
/// dedicated, validated hooks in NativeTabletGlass.x.swift.
func activateShrubifyGlassChrome() {
    guard #available(iOS 26.0, *), EvolvedInterfaceAvailability.usesNativeTabletInterface else { return }
    onMainThreadSync { ShrubifyGlassChrome.start() }
}
