import Foundation

/// Geometry belongs to the visible player container, never to a screen model.
struct PlayerLayout {
    let wide: Bool
    let artwork: CGRect
    let content: CGRect
    let header: CGRect
    let footer: CGRect
    let contentHeight: CGFloat

    init(size: CGSize, top: CGFloat, bottom: CGFloat, largeText: Bool = false) {
        let margin: CGFloat = size.width < 400 ? 20 : 28
        let usable = CGRect(x: margin, y: top + 56, width: max(0, size.width - margin * 2),
                            height: max(0, size.height - top - bottom - 120))
        wide = size.width >= 700 && size.width > size.height
        header = CGRect(x: margin, y: top + 4, width: usable.width, height: 48)
        let controlsHeight: CGFloat = largeText ? 360 : 300
        if wide {
            let gap: CGFloat = 40
            let column = max(0, (usable.width - gap) / 2)
            let side = max(0, min(column, usable.height, 560))
            artwork = CGRect(x: usable.minX + (column - side) / 2,
                             y: usable.midY - side / 2, width: side, height: side)
            content = CGRect(x: usable.minX + column + gap, y: usable.minY,
                             width: column, height: max(usable.height, controlsHeight))
            contentHeight = max(size.height, content.maxY + bottom + 64)
        } else {
            let side = max(0, min(usable.width, size.height * 0.36, 460))
            artwork = CGRect(x: (size.width - side) / 2, y: usable.minY, width: side, height: side)
            content = CGRect(x: margin, y: artwork.maxY + 24, width: usable.width,
                             height: controlsHeight)
            contentHeight = max(size.height, content.maxY + bottom + 64)
        }
        footer = CGRect(x: content.minX, y: contentHeight - bottom - 56,
                        width: content.width, height: 48)
    }
}
