import SwiftUI
import UIKit 

class EeveeSettingsViewController: SPTPageViewController {
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

/// Keep mod pages off Spotify's private tab/page registry. A standard UIKit
/// navigation controller owns all settings pushes for the lifetime of the sheet.
enum ShrubifySettingsPresenter {
    static func present(from presenter: UIViewController) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { present(from: presenter) }
            return
        }
        guard presenter.presentedViewController == nil else { return }
        let navigation = UINavigationController()
        let root = EeveeSettingsViewController(
            presenter.view.bounds,
            settingsView: AnyView(EeveeSettingsView(navigationController: navigation)),
            navigationTitle: "Shrubify"
        )
        root.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak navigation] _ in navigation?.dismiss(animated: true) }
        )
        navigation.setViewControllers([root], animated: false)
        navigation.modalPresentationStyle = .pageSheet
        presenter.present(navigation, animated: true)
    }
}
