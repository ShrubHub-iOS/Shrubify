import UIKit

@main
final class SmokeApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = SmokeController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class SmokeController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }
    private var performed = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !performed else { return }; performed = true
        view.backgroundColor = .black
        let marker = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        marker.backgroundColor = .green; view.addSubview(marker)
        let width = min(1008, view.bounds.width - 32)
        let oldMaterial = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        oldMaterial.frame = CGRect(x: (view.bounds.width - width) / 2, y: view.bounds.height - 135, width: width, height: 83)
        view.addSubview(oldMaterial)
        let nativeBar = UIView(frame: oldMaterial.bounds)
        nativeBar.backgroundColor = .darkGray
        oldMaterial.contentView.addSubview(nativeBar)
        let host = UIView(); nativeBar.addSubview(host)
        let systemBar = UITabBar(); host.addSubview(systemBar)
        NavigationCapsuleSurface.configure(systemBar)
        systemBar.tintColor = .white
        systemBar.unselectedItemTintColor = .white
        systemBar.itemPositioning = .centered
        systemBar.items = ["house.fill", "magnifyingglass", "books.vertical", "music.note"].enumerated().map { index, symbol in
            UITabBarItem(title: nil, image: UIImage(systemName: symbol), tag: index)
        }
        systemBar.selectedItem = systemBar.items?.first
        let target = NavigationCapsuleLayout.frame(in: nativeBar.bounds, band: nativeBar.bounds, itemCount: 4)
        systemBar.itemWidth = target.width / 4
        // Reproduce the old "clear color" operation: it leaves the material alive.
        oldMaterial.backgroundColor = .clear
        let reproducedMaterial = oldMaterial.effect != nil
        NavigationCapsuleSurface.clearMaterial(in: oldMaterial)
        NavigationCapsuleSurface.layout(host: host, systemBar: systemBar, nativeBar: nativeBar, target: target)
        view.layoutIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.capture(nativeBar: nativeBar, host: host, oldMaterial: oldMaterial, target: target, reproduced: reproducedMaterial)
        }
    }

    private func capture(nativeBar: UIView, host: UIView, oldMaterial: UIVisualEffectView, target: CGRect, reproduced: Bool) {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        try? image.pngData()?.write(to: folder.appendingPathComponent("navigation-surface.png"))
        var outside = -1
        var brightInside = 0
        var markerVisible = false
        if let cg = image.cgImage {
            let width = cg.width, height = cg.height
            let storage = UnsafeMutableRawPointer.allocate(byteCount: width * height * 4, alignment: 16)
            defer { storage.deallocate() }
            if let context = CGContext(data: storage, width: width, height: height, bitsPerComponent: 8,
                                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) {
                context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                let pixels = storage.assumingMemoryBound(to: UInt8.self)
                func isGreen(_ row: Int) -> Bool {
                    let i = (row * width + 5) * 4
                    return pixels[i + 1] > 180 && pixels[i] < 50 && pixels[i + 2] < 50
                }
                markerVisible = isGreen(5) || isGreen(height - 6)
                let reversed = !isGreen(5) && isGreen(height - 6)
                let capsule = nativeBar.convert(target, to: view).insetBy(dx: -3, dy: -3)
                let band = oldMaterial.convert(oldMaterial.bounds, to: view).insetBy(dx: 4, dy: 4)
                outside = 0
                for y in stride(from: Int(band.minY), to: Int(band.maxY), by: 3) {
                    for x in stride(from: Int(band.minX), to: Int(band.maxX), by: 3) {
                        let inside = capsule.contains(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                        let row = reversed ? height - 1 - y : y
                        let i = (row * width + x) * 4
                        let value = max(pixels[i], pixels[i + 1], pixels[i + 2])
                        if inside { if value > 180 { brightInside += 1 } }
                        else if value > 12 { outside += 1 }
                    }
                }
            }
        }
        let bounded = host.bounds.width <= 352 && host.bounds.height <= 60
        NavigationCapsuleSurface.restore(nativeBar)
        let restored = nativeBar.layer.mask == nil
        let result: [String: Any] = ["passed": bounded && restored && reproduced && oldMaterial.effect == nil && outside == 0 && markerVisible && brightInside > 10,
                                     "surfaceWidth": host.bounds.width, "surfaceHeight": host.bounds.height,
                                     "oldBackingWidth": oldMaterial.bounds.width, "coloredPixelsOutsideCapsule": outside,
                                     "oldMaterialBugReproduced": reproduced, "maskRestored": restored,
                                     "markerVisible": markerVisible, "brightPixelsInsideCapsule": brightInside]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: folder.appendingPathComponent("result.json"))
        }
    }
}
