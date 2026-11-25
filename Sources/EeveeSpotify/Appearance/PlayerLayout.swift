import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

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
        let headroom: CGFloat = 56
        let usable = CGRect(x: margin, y: top + headroom, width: max(0, size.width - margin * 2),
                            height: max(0, size.height - top - bottom - headroom - 64))
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

/// Artwork and controls share one measured footprint in each iPad pane.
struct TabletPlayerLayout {
    let wide: Bool
    let artwork: CGRect
    let lyric: CGRect
    let title: CGRect
    let artist: CGRect
    let progress: CGRect
    let clock: CGRect
    let transport: CGRect
    let volume: CGRect
    let footer: CGRect
    let contentHeight: CGFloat

    static func headerHeight(safeTop: CGFloat) -> CGFloat { safeTop + 62 }

    static func closeFrame(safeTop: CGFloat) -> CGRect { CGRect(x: 12, y: safeTop + 7, width: 48, height: 48) }

    // The scroll view starts below the fixed native header.
    init(size: CGSize, bottom: CGFloat, titleHeight: CGFloat, artistHeight: CGFloat, lyricHeight: CGFloat = 44) {
        let margin: CGFloat = size.width >= 700 ? 36 : 24
        let gap: CGFloat = 36
        let verticalPadding: CGFloat = 20
        let availableWidth = max(0, size.width - margin * 2)
        let availableHeight = max(0, size.height - bottom - verticalPadding * 2)
        wide = size.width >= 760 && size.width > size.height

        let lyricSpace = lyricHeight > 0 ? lyricHeight + 8 : 0
        let controlsHeight = titleHeight + artistHeight + 207
        let controlWidth = min(availableWidth, wide ? 388 : 440)
        let artworkSide: CGFloat
        let controlX: CGFloat
        let controlY: CGFloat
        if wide {
            artworkSide = max(0, min(480, availableWidth - controlWidth - gap, availableHeight - lyricSpace))
            let left = (size.width - artworkSide - gap - controlWidth) / 2
            let artworkColumnHeight = artworkSide + lyricSpace
            let groupHeight = max(artworkColumnHeight, controlsHeight)
            let top = verticalPadding + max(0, (availableHeight - groupHeight) / 2)
            artwork = CGRect(x: left, y: top + (groupHeight - artworkColumnHeight) / 2, width: artworkSide, height: artworkSide)
            controlX = artwork.maxX + gap
            controlY = top + (groupHeight - controlsHeight) / 2
        } else {
            artworkSide = min(availableWidth, 456, max(96, availableHeight - controlsHeight - lyricSpace - 18))
            let groupHeight = artworkSide + lyricSpace + 18 + controlsHeight
            let top = verticalPadding + max(0, (availableHeight - groupHeight) / 2)
            artwork = CGRect(x: (size.width - artworkSide) / 2, y: top, width: artworkSide, height: artworkSide)
            controlX = (size.width - controlWidth) / 2
            controlY = artwork.maxY + lyricSpace + 18
        }

        lyric = CGRect(x: artwork.minX,
                       y: artwork.maxY + (lyricHeight > 0 ? 8 : 0), width: artwork.width, height: lyricHeight)
        title = CGRect(x: controlX, y: controlY, width: controlWidth, height: titleHeight)
        artist = CGRect(x: controlX, y: title.maxY, width: controlWidth, height: artistHeight)
        progress = CGRect(x: controlX, y: artist.maxY + 6, width: controlWidth, height: 36)
        clock = CGRect(x: controlX, y: progress.maxY - 4, width: controlWidth, height: 18)
        transport = CGRect(x: controlX, y: clock.maxY + 6, width: controlWidth, height: 48)
        volume = CGRect(x: controlX, y: transport.maxY + 6, width: controlWidth, height: 38)
        let footerWidth = min(controlWidth, 292)
        footer = CGRect(x: controlX + (controlWidth - footerWidth) / 2,
                        y: volume.maxY + 9, width: footerWidth, height: 44)
        contentHeight = max(size.height, max(lyric.maxY, footer.maxY) + verticalPadding + bottom)
    }
}
