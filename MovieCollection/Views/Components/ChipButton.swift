//
//  ChipButton.swift
//  MovieCollection
//
//  Purpose: The pill-shaped filter chip: action color when on, surface color when off.
//  Used in: Shelf review tabs, search filters, Tonight filters, forms.
//

import SwiftUI

struct ChipButton: View {
    enum Size {
        /// 44pt tall, 15pt text (shelf tabs, Tonight).
        case regular
        /// 38pt tall, 14pt text (search overlay).
        case small

        var height: CGFloat { self == .regular ? 44 : 38 }
        var fontSize: CGFloat { self == .regular ? 15 : 14 }
        var horizontalPadding: CGFloat { self == .regular ? 18 : 14 }
    }

    let label: String
    let isOn: Bool
    var size: Size = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Fonts.body(size.fontSize, weight: .semibold, relativeTo: .subheadline))
                .lineLimit(1)
                .foregroundStyle(isOn ? Theme.Colors.onAction : Theme.Colors.text)
                .padding(.horizontal, size.horizontalPadding)
                .frame(minHeight: size.height)
                .background(isOn ? Theme.Colors.action : Theme.Colors.surface, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isOn ? Theme.Colors.action : Theme.Colors.divider)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(.snappy(duration: 0.15), value: isOn)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var selected = "All"
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 8) {
            ForEach(["All", "Not reviewed", "Reviewed"], id: \.self) { option in
                ChipButton(label: option, isOn: selected == option) { selected = option }
            }
        }
        HStack(spacing: 8) {
            ChipButton(label: "DVD", isOn: true, size: .small) {}
            ChipButton(label: "Digital", isOn: false, size: .small) {}
        }
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}
