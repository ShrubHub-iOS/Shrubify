import UIKit

/// Use the active settings/player window instead of Spotify's private popup
/// presenter, which can display behind Shrubify's independent settings window.
struct PopUpHelper {
    private static weak var currentAlert: UIAlertController?

    static func showPopUp(
        delayed: Bool = false,
        message: String,
        buttonText: String,
        secondButtonText: String? = nil,
        onPrimaryClick: (() -> Void)? = nil,
        onSecondaryClick: (() -> Void)? = nil,
        onPresented: (() -> Void)? = nil
    ) {
        DispatchQueue.main.asyncAfter(deadline: delayed ? .now() + 3 : .now()) {
            guard currentAlert == nil else { return }
            let alert = UIAlertController(title: "Shrubify", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: buttonText, style: .default) { _ in
                currentAlert = nil
                onPrimaryClick?()
            })
            if let secondButtonText {
                alert.addAction(UIAlertAction(title: secondButtonText, style: .cancel) { _ in
                    currentAlert = nil
                    onSecondaryClick?()
                })
            }
            currentAlert = alert
            if !WindowHelper.shared.present(alert, completion: onPresented) { currentAlert = nil }
        }
    }
}
