import UIKit

/// Presents the existing player in the same window and returns it to the
/// same slot. Playback, the scroll position and pending artwork stay attached.
@MainActor
final class PlayerFullscreenPresentation: UIViewController {
    private let player: UIView
    private weak var origin: UIView?
    private var placeholder: UIView?
    private var returnsToOrigin = true
    private let onReturn: () -> Void

    init(player: UIView, origin: UIView, onReturn: @escaping () -> Void) {
        self.player = player
        self.origin = origin
        self.onReturn = onReturn
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let origin, player.superview === origin else { return }
        let copy = player.snapshotView(afterScreenUpdates: false) ?? UIView()
        copy.backgroundColor = .black
        copy.frame = player.frame
        copy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        copy.isUserInteractionEnabled = false
        copy.accessibilityElementsHidden = true
        origin.insertSubview(copy, belowSubview: player)
        placeholder = copy
        player.frame = view.bounds
        view.addSubview(player)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if player.superview === view, player.frame != view.bounds { player.frame = view.bounds }
    }

    func exit(returningPlayer: Bool = true) {
        if !returningPlayer { returnsToOrigin = false }
        guard !isBeingDismissed else { return }
        dismiss(animated: false) { [self] in restorePlayer() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { restorePlayer() }
    }

    private func restorePlayer() {
        guard let placeholder else { return }
        self.placeholder = nil
        if returnsToOrigin, let origin, placeholder.superview === origin {
            player.frame = origin.bounds
            origin.insertSubview(player, aboveSubview: placeholder)
        } else {
            player.removeFromSuperview()
        }
        placeholder.removeFromSuperview()
        onReturn()
    }
}
