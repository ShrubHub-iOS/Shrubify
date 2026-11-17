import UIKit

struct WindowHelper {
    static let shared = WindowHelper()

    // Resolve the active scene each time. Settings uses a separate window, and
    // a root controller may not exist yet when an early hook first asks for it.
    private var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.filter { $0.activationState == .foregroundActive }.flatMap(\.windows)
        return active.first(where: \.isKeyWindow)
            ?? active.first(where: { !$0.isHidden && $0.windowLevel == .normal })
    }
    private var rootViewController: UIViewController? { window?.rootViewController }

    private init() {}

    private var presentationTarget: UIViewController? {
        var current = rootViewController
        while let controller = current {
            if let presented = controller.presentedViewController, !presented.isBeingDismissed {
                current = presented
            } else if let nav = controller as? UINavigationController, let visible = nav.visibleViewController {
                current = visible
            } else if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController {
                current = selected
            } else { return controller }
        }
        return nil
    }

    @discardableResult
    func present(_ viewController: UIViewController, completion: (() -> Void)? = nil) -> Bool {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.present(viewController, completion: completion) }
            return false
        }
        guard let target = presentationTarget, target.viewIfLoaded?.window != nil,
              !target.isBeingDismissed, viewController.presentingViewController == nil else { return false }
        target.present(viewController, animated: true, completion: completion)
        return true
    }

    func findFirstSubview(_ regex: String, in view: UIView) -> UIView? {
        for subview in view.subviews {
            if NSStringFromClass(type(of: subview)) ~= regex {
                return subview
            }
            if let found = findFirstSubview(regex, in: subview) {
                return found
            }
        }

        return nil
    }

    func findFirstViewController(_ regex: String) -> UIViewController? {
        guard let rootView = rootViewController?.viewIfLoaded else { return nil }
        var result: UIViewController?

        func searchViews(_ view: UIView) {
            if let viewController = self.viewController(for: view) {
                if NSStringFromClass(type(of: viewController)) ~= regex {
                    result = viewController
                    return
                }
            }

            for subview in view.subviews {
                searchViews(subview)
            }
        }

        searchViews(rootView)
        return result
    }

    func dismissCurrentViewController() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.dismissCurrentViewController() }; return }
        presentationTarget?.dismiss(animated: true)
    }

    func overrideUserInterfaceStyle(_ style: UIUserInterfaceStyle) {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.overrideUserInterfaceStyle(style) }; return }
        window?.overrideUserInterfaceStyle = style
    }

    func viewController(for view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}
