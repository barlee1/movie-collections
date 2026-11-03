//
//  FlowLayout.swift
//  MovieCollection
//
//  Purpose: Lays views out in a row and wraps onto new lines when they run
//  out of room, like the design's wrapping chip and tag rows.
//  Used in: Filter chips, tag rows, service lists.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                // Center each item vertically within its row.
                let itemY = y + (row.height - item.size.height) / 2
                subviews[item.index].place(
                    at: CGPoint(x: x, y: itemY),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    // MARK: - Row building

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Greedily fills each row, starting a new one when the next item won't fit.
    /// Items wider than the whole row are shrunk to the row width.
    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }

            let neededWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if neededWidth > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

// MARK: - Previews

#Preview {
    FlowLayout {
        ForEach(["Feel-good", "Laugh out loud", "Edge of seat", "Cozy", "Comedy", "Drama", "Action"], id: \.self) { label in
            ChipButton(label: label, isOn: label == "Cozy") {}
        }
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}
