import SwiftUI
import UIKit 

class EeveeSettingsViewController: UIViewController {
    let settingsView: AnyView
    
    init(_ frame: CGRect, settingsView: AnyView, navigationTitle: String) {
        self.settingsView = settingsView
        super.init(nibName: nil, bundle: nil)
        
        title = navigationTitle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        
        view.addSubview(hostingController.view)
        addChild(hostingController)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Become first responder so we can receive motion events
        becomeFirstResponder()
    }
    
    
    @objc func openRepositoryUrl(_ sender: UIButton) {
        UIApplication.shared.open(URL(string: "https://github.com/zoinkdoggie94/Shrubify")!)
    }
}

/// An independent UIKit window keeps settings pushes/presentations out of
/// Spotify's private tab-page registry, including parent-navigation observation.
enum ShrubifySettingsPresenter {
    private static var window: UIWindow?
    private static weak var previousWindow: UIWindow?
    private static let dismissal = SettingsDismissalDelegate()

    static func present(from presenter: UIViewController) {
        guard Thread.isMainThread else { DispatchQueue.main.async { present(from: presenter) }; return }
        guard window == nil, let scene = presenter.view.window?.windowScene else { return }
        previousWindow = scene.windows.first(where: \.isKeyWindow)
        let host = UIViewController()
        host.view.backgroundColor = .clear
        let settingsWindow = UIWindow(windowScene: scene)
        settingsWindow.windowLevel = .normal + 1
        settingsWindow.backgroundColor = .clear
        settingsWindow.rootViewController = host
        window = settingsWindow
        settingsWindow.makeKeyAndVisible()

        let navigation = UINavigationController()
        let root = EeveeSettingsViewController(presenter.view.bounds,
            settingsView: AnyView(EeveeSettingsView(navigationController: navigation)), navigationTitle: "Shrubify")
        root.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done,
            primaryAction: UIAction { [weak navigation] _ in
                navigation?.dismiss(animated: true, completion: { finish() })
            })
        navigation.setViewControllers([root], animated: false)
        navigation.modalPresentationStyle = .pageSheet
        host.present(navigation, animated: true)
        navigation.presentationController?.delegate = dismissal
    }

    fileprivate static func finish() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        SettingsNavigator.navigationController = nil
        previousWindow?.makeKey()
        previousWindow = nil
    }
}

private final class SettingsDismissalDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        ShrubifySettingsPresenter.finish()
    }
}
