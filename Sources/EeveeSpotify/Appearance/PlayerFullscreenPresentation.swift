import UIKit

/// Presents the existing player in the same window and returns it to the
/// same slot. Playback, the scroll position and pending artwork stay attached.
@MainActor
final class PlayerFullscreenPresentation: UIViewController, UIViewControllerTransitioningDelegate {
    private let player: UIView
    fileprivate var transitionContent: UIView { player }
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
        if player.superview === view, player.transform.isIdentity, player.frame != view.bounds {
            player.frame = view.bounds
        }
    }

    func exit(returningPlayer: Bool = true, completion: (() -> Void)? = nil) {
        if !returningPlayer { returnsToOrigin = false }
        guard !isBeingDismissed, !isBeingPresented else { return }
        dismiss(animated: returningPlayer) { [self] in
            restorePlayer()
            if returnsToOrigin, let origin, player.superview === origin { completion?() }
        }
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
        UIAccessibility.isReduceMotionEnabled ? 0.16 : 0.44
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
        let startsAt: CGFloat = expanding ? 0 : 1
        let endsAt: CGFloat = expanding ? 1 : 0
        var startTransform = CGAffineTransform.identity
        var endTransform = CGAffineTransform.identity
        if !UIAccessibility.isReduceMotionEnabled, let panel,
           panel.width > 1, panel.height > 1, panel.intersects(view.bounds) {
            let rounded = UIBezierPath(roundedRect: panel, cornerRadius: min(22, panel.width / 2, panel.height / 2)).cgPath
            let full = UIBezierPath(roundedRect: view.bounds, cornerRadius: 1).cgPath
            let mask = CAShapeLayer()
            mask.frame = view.bounds
            mask.path = expanding ? full : rounded
            view.layer.mask = mask
            let reveal = CABasicAnimation(keyPath: "path")
            reveal.fromValue = expanding ? rounded : full
            reveal.toValue = mask.path
            reveal.duration = duration
            reveal.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.68, 0.2, 1)
            mask.add(reveal, forKey: "player-expansion")
            let settle = CGAffineTransform(translationX: (panel.midX - view.bounds.midX) * 0.06,
                                           y: (panel.midY - view.bounds.midY) * 0.06)
                .scaledBy(x: 0.97, y: 0.97)
            if expanding { startTransform = settle }
            else { endTransform = settle }
        }
        let content = (controller as? PlayerFullscreenPresentation)?.transitionContent
        content?.transform = startTransform
        view.alpha = startsAt
        let timing = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.2, y: 0.68),
                                             controlPoint2: CGPoint(x: 0.2, y: 1))
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
        animator.addAnimations {
            view.alpha = endsAt
            content?.transform = endTransform
        }
        animator.addCompletion { _ in
            let finished = !context.transitionWasCancelled
            content?.transform = .identity
            if self.expanding || !finished {
                view.layer.mask = nil
                view.alpha = 1
            }
            context.completeTransition(finished)
            view.layer.mask = nil
            view.alpha = 1
        }
        animator.startAnimation()
    }
}
