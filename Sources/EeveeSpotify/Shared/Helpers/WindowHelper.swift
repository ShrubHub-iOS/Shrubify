import UIKit

struct WindowHelper {
    static let shared = WindowHelper()
    
    var window: UIWindow? {
        guard Thread.isMainThread else { return nil }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let windows = scenes.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow)
            ?? windows.first(where: { !$0.isHidden && $0.windowLevel == .normal })
    }
    var rootViewController: UIViewController? { window?.rootViewController }
    var topViewController: UIViewController? {
        var current = rootViewController
        while let vc = current {
            if let presented = vc.presentedViewController { current = presented }
            else if let nav = vc as? UINavigationController { current = nav.visibleViewController; if current == nil { return nav } }
            else if let tab = vc as? UITabBarController { current = tab.selectedViewController; if current == nil { return tab } }
            else { return vc }
        }
        return nil
    }

    func present(_ viewController: UIViewController) {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.present(viewController) }; return }
        guard let presenter = topViewController, !presenter.isBeingDismissed else { return }
        presenter.present(viewController, animated: true)
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
        topViewController?.dismiss(animated: true)
    }

    func overrideUserInterfaceStyle(_ style: UIUserInterfaceStyle) {
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
