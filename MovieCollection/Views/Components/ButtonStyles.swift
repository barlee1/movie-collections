//
//  ButtonStyles.swift
//  MovieCollection
//
//  Purpose: The design's pill buttons (solid primary, outlined
//  secondary, solid alternate) and a gentle press effect for tappable cards.
//  Used in: Profile actions, Tonight, detail, search overlay, forms, cards.
//

import SwiftUI

// MARK: - Pill button

struct PillButtonStyle: ButtonStyle {
    enum Variant {
        /// Solid action color (secondary) with light text.
        case primary
        /// Transparent with a hairline border and dark text.
        case secondary
        /// Solid alternate action color (secondary2) with light text.
        case alt
    }

    enum Typeface {
        /// Caprasimo, used by the design system's `.btn` buttons.
        case heading
        /// Figtree bold, used by the app's custom action buttons.
        case body
    }

    var variant: Variant = .primary
    var typeface: Typeface = .heading
    var fontSize: CGFloat = 16
    var height: CGFloat = 52
    var fullWidth: Bool = true

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .background(background(isPressed: configuration.isPressed), in: Capsule())
            .overlay {
                if variant == .secondary {
                    Capsule().strokeBorder(Theme.Colors.divider)
                }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }

    private var font: Font {
        switch typeface {
        case .heading: Theme.Fonts.heading(fontSize, relativeTo: .body)
        case .body: Theme.Fonts.body(fontSize, weight: .bold, relativeTo: .body)
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: Theme.Colors.onAction
        case .secondary: Theme.Colors.text
        case .alt: Theme.Colors.onActionAlt
        }
    }

    /// Pressed states are a shade darker.
    private func background(isPressed: Bool) -> Color {
        switch variant {
        case .primary: isPressed ? Theme.Colors.actionPressed : Theme.Colors.action
        case .secondary: isPressed ? Theme.Colors.text.opacity(0.07) : .clear
        case .alt: isPressed ? Theme.Colors.actionAltPressed : Theme.Colors.actionAlt
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    /// A design-system pill button.
    static func pill(
        _ variant: PillButtonStyle.Variant = .primary,
        typeface: PillButtonStyle.Typeface = .heading,
        fontSize: CGFloat = 16,
        height: CGFloat = 52,
        fullWidth: Bool = true
    ) -> PillButtonStyle {
        PillButtonStyle(variant: variant, typeface: typeface, fontSize: fontSize, height: height, fullWidth: fullWidth)
    }
}

// MARK: - Press effect for cards

/// Shrinks a tappable card slightly while pressed (the design lifts cards on hover).
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 12) {
        Button("See what your friends are watching") {}
            .buttonStyle(.pill(.alt))
        Button("Add to your Collection") {}
            .buttonStyle(.pill(.primary))
        Button("Pick one for me") {}
            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 17))
        Button("Pick one for me") {}
            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 17))
            .disabled(true)
        HStack(spacing: 10) {
            Button("Clear") {}
                .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 15, height: 46))
            Button("Show 30 titles") {}
                .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 46))
        }
        Button("See Review") {}
            .buttonStyle(.pill(.secondary, fontSize: 15, height: 40, fullWidth: false))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}
