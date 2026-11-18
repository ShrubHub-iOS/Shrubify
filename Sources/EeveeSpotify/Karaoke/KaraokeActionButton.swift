import SwiftUI
import UIKit

/// Native control semantics give the whole visible button a hit region, even
/// when its label is only a thin SF Symbol and the material is noninteractive.
struct KaraokeActionButton: UIViewRepresentable {
    var symbol: String? = nil
    var title: String? = nil
    let label: String
    let identifier: String
    var value: String? = nil
    var enabled = true
    let action: () -> Void

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func activate(_ sender: UIButton) { guard sender.isEnabled else { return }; action() }
    }
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.addTarget(context.coordinator, action: #selector(Coordinator.activate(_:)), for: .touchUpInside)
        return button
    }
    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.action = action
        var config = UIButton.Configuration.plain()
        config.image = symbol.flatMap { UIImage(systemName: $0) }
        config.title = title
        config.baseForegroundColor = .white
        config.contentInsets = .zero
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: symbol == "chevron.down" ? 18 : 14, weight: .semibold)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            return result
        }
        button.configuration = config
        button.isEnabled = enabled
        button.accessibilityIdentifier = identifier
        button.accessibilityLabel = label
        button.accessibilityValue = value
    }
}

struct KaraokeCloseButton: View {
    let action: () -> Void
    var body: some View {
        KaraokeActionButton(symbol: "chevron.down", label: "Close custom lyrics",
                            identifier: "shrubify.lyrics.close", action: action)
            .frame(width: 46, height: 46)
            .background(KaraokeControlSurface())
    }
}
