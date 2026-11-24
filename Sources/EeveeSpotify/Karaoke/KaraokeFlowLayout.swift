import SwiftUI

/// Wraps child views onto multiple rows when they don't fit the available
/// width — needed so karaoke lines wrap naturally at the screen edge like
/// real running text, rather than being clipped or forced onto one line —
/// and positions each wrapped row per `alignment` (centered by default,
/// matching Spotify's own lyrics view and Spicetify's, rather than ragged
/// left-aligned text; configurable via the left/center/right setting).
///
/// SwiftUI's Layout protocol (the clean way to do this) is iOS 16+. This
/// project's only existing @available check gates at iOS 15, so on iOS 15
/// devices we fall back to a simple non-wrapping, centered HStack instead
/// of crashing — lines will run off-screen on iOS 15 rather than wrapping,
/// which is a known limitation rather than a silent bug, until/unless iOS
/// 15 support for this specific view is worth a more involved
/// manual-wrapping fallback.
struct KaraokeFlowLayout<Content: View>: View {
    let spacing: CGFloat
    var alignment: HorizontalAlignment = .center
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            KaraokeFlowLayoutImpl(spacing: spacing, alignment: alignment) {
                content()
            }
        } else {
            HStack(spacing: spacing) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        }
    }
}

@available(iOS 16.0, *)
private struct KaraokeFlowLayoutImpl: Layout {
    let spacing: CGFloat
    var alignment: HorizontalAlignment = .center

    /// One wrapped row: which subview indices it contains, their
    /// individually-measured sizes, and the row's total content width
    /// (sum of subview widths + interior spacing). Computing this width
    /// up front — rather than just placing subviews left-to-right as
    /// they're measured — is what lets placeSubviews center each row
    /// within the available width instead of starting it flush at the
    /// leading edge.
    private struct Row {
        var items: [(index: Int, width: CGFloat, proposal: ProposedViewSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let ideal = subview.sizeThatFits(.unspecified)
            // A single long word needs a width proposal even on an empty row.
            let proposal: ProposedViewSize = ideal.width > maxWidth
                ? ProposedViewSize(width: maxWidth, height: nil) : .unspecified
            let size = ideal.width > maxWidth ? subview.sizeThatFits(proposal) : ideal
            if x > 0 && x + size.width > maxWidth {
                rows.append(current)
                current = Row()
                x = 0
            }
            current.items.append((index, size.width, proposal))
            current.width = x + size.width
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(subviews: subviews, maxWidth: maxWidth)
        let totalHeight = rows.reduce(CGFloat(0)) { $0 + $1.height }
            + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            // Position this row's total content width within the available
            // width per `alignment` — centering (the default) is what makes
            // lyrics read centered like Spotify's own lyrics view instead of
            // ragged left-aligned text; leading/trailing support the
            // left/right alignment setting.
            var x: CGFloat
            switch alignment {
            case .leading:
                x = bounds.minX
            case .trailing:
                x = bounds.maxX - row.width
            default:
                x = bounds.minX + (bounds.width - row.width) / 2
            }

            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: item.proposal)
                x += item.width + spacing
            }
            y += row.height + spacing
        }
    }
}
