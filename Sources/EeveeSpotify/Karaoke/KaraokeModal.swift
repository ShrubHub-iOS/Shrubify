import UIKit
import SwiftUI

/// Own the dismissal route per presentation. No global flag can suppress Close.
@MainActor
enum KaraokeModal {
    static func make<Content: View>(onDismiss: @escaping () -> Void,
                                   @ViewBuilder content: (@escaping () -> Void) -> Content) -> UIViewController {
        let session = Session(onDismiss: onDismiss)
        let controller = Host(rootView: content { session.close() })
        session.controller = controller
        controller.session = session
        controller.overrideUserInterfaceStyle = .dark
        // The artwork is opaque. Fullscreen isolates input from the underlying player.
        controller.modalPresentationStyle = .fullScreen
        controller.view.backgroundColor = .black
        return controller
    }

    @MainActor private final class Session {
        weak var controller: UIViewController?
        var closing = false
        var finished = false
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func close() {
            guard !closing, !finished else { return }
            guard let controller, controller.presentingViewController != nil else { finish(); return }
            closing = true
            controller.dismiss(animated: true) { self.finish() }
        }
        func finish() {
            guard !finished else { return }
            finished = true
            onDismiss()
        }
    }
    private final class Host<Content: View>: UIHostingController<Content> {
        var session: Session?
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            if presentingViewController == nil { session?.finish() }
        }
        override func accessibilityPerformEscape() -> Bool { session?.close(); return true }
        override var keyCommands: [UIKeyCommand]? {
            (super.keyCommands ?? []) + [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(closeModal))]
        }
        @objc private func closeModal() { session?.close() }
    }
}
