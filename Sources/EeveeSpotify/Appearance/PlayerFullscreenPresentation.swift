import UIKit

/// Presents the existing player in the same window and returns it to the
/// same slot. Playback, the scroll position and pending artwork stay attached.
@MainActor
final class PlayerFullscreenPresentation: UIViewController, UIViewControllerTransitioningDelegate {
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
        transitioningDelegate = self
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
        guard !isBeingDismissed, !isBeingPresented else { return }
        dismiss(animated: returningPlayer) { [self] in restorePlayer() }
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PlayerExpansionAnimator(expanding: true, anchor: origin)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PlayerExpansionAnimator(expanding: false, anchor: placeholder ?? origin)
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

@MainActor
private final class PlayerExpansionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let expanding: Bool
    private weak var anchor: UIView?

    init(expanding: Bool, anchor: UIView?) {
        self.expanding = expanding
        self.anchor = anchor
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0.16 : 0.34
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewKey = expanding ? .to : .from
        let controllerKey: UITransitionContextViewControllerKey = expanding ? .to : .from
        guard let controller = context.viewController(forKey: controllerKey) else {
            context.completeTransition(false)
            return
        }
        let candidate: UIView? = context.view(forKey: key) ?? controller.view
        guard let view = candidate else {
            context.completeTransition(false)
            return
        }
        let container = context.containerView
        if expanding {
            let destination = context.finalFrame(for: controller)
            view.frame = destination.isEmpty ? container.bounds : destination
            container.addSubview(view)
        }
        view.layoutIfNeeded()
        let panel = anchor.map { view.convert($0.convert($0.bounds, to: container), from: container) }
        let duration = transitionDuration(using: context)
        var startsAt: CGFloat = expanding ? 0 : 1
        var endsAt: CGFloat = expanding ? 1 : 0
        if !UIAccessibility.isReduceMotionEnabled, let panel,
           panel.width > 1, panel.height > 1, panel.intersects(view.bounds) {
            let rounded = UIBezierPath(roundedRect: panel, cornerRadius: 22).cgPath
            let full = UIBezierPath(roundedRect: view.bounds, cornerRadius: 1).cgPath
            let mask = CAShapeLayer()
            mask.frame = view.bounds
            mask.path = expanding ? full : rounded
            view.layer.mask = mask
            let reveal = CABasicAnimation(keyPath: "path")
            reveal.fromValue = expanding ? rounded : full
            reveal.toValue = mask.path
            reveal.duration = duration
            reveal.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.8, 0.28, 1)
            mask.add(reveal, forKey: "player-expansion")
            startsAt = expanding ? 0.82 : 1
            endsAt = expanding ? 1 : 0.82
        }
        view.alpha = startsAt
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut]) {
            view.alpha = endsAt
        } completion: { _ in
            let finished = !context.transitionWasCancelled
            if self.expanding || !finished {
                view.layer.mask = nil
                view.alpha = 1
            }
            context.completeTransition(finished)
            view.layer.mask = nil
            view.alpha = 1
        }
    }
}
