//
//  StarRating.swift
//  MovieCollection
//
//  Purpose: Half-star rating display, and an interactive half-star picker.
//  Used in: Review cards, friends' reviews (display); edit sheet (picker).
//

import SwiftUI

// MARK: - Display

/// Shows a 0–5 star rating, including half stars.
struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 14
    var onColor: Color = Theme.Colors.star
    var offColor: Color = Theme.Colors.starOff
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { index in
                StarShape(fill: fill(forStarAt: index), size: size, onColor: onColor, offColor: offColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StarRatingView.accessibilityText(for: rating))
    }

    /// How much of a star is filled: 0, 0.5, or 1.
    private func fill(forStarAt index: Int) -> Double {
        let remaining = rating - Double(index)
        if remaining >= 1 { return 1 }
        if remaining >= 0.5 { return 0.5 }
        return 0
    }

    static func accessibilityText(for rating: Double) -> String {
        guard rating > 0 else { return "Not rated" }
        let number = rating.formatted(.number.precision(.fractionLength(0...1)))
        return "\(number) out of 5 stars"
    }
}

/// One star: an outline when empty, filled when full, and a filled left
/// half over an outline for half stars.
private struct StarShape: View {
    let fill: Double
    let size: CGFloat
    let onColor: Color
    let offColor: Color

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let scaledSize = size * scale
        ZStack(alignment: .leading) {
            Image(systemName: fill >= 1 ? "star.fill" : "star")
                .foregroundStyle(fill >= 1 ? onColor : offColor)
            if fill == 0.5 {
                Image(systemName: "star.fill")
                    .foregroundStyle(onColor)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: scaledSize / 2)
                    }
            }
        }
        .font(.system(size: scaledSize, weight: .semibold))
        .frame(width: scaledSize, height: scaledSize)
    }
}

// MARK: - Picker

/// Tap or drag across the stars to pick a rating in half-star steps.
/// The left half of a star picks x.5, the right half picks the whole star.
/// VoiceOver users swipe up or down to adjust.
struct HalfStarPicker: View {
    @Binding var rating: Double
    var size: CGFloat = 34
    var spacing: CGFloat = 8
    /// What VoiceOver calls the picker, e.g. "Sam's rating".
    var accessibilityName = "Your rating"

    var body: some View {
        StarRatingView(rating: rating, size: size, spacing: spacing)
            .overlay {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(.rect)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    rating = HalfStarPicker.rating(at: value.location.x, width: geometry.size.width)
                                }
                        )
                }
            }
            // The picker's stars are already large, so they don't grow with text size.
            .dynamicTypeSize(...DynamicTypeSize.large)
            .sensoryFeedback(.selection, trigger: rating)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityName)
            .accessibilityValue(StarRatingView.accessibilityText(for: rating))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: rating = Review.normalized(rating + 0.5)
                case .decrement: rating = Review.normalized(rating - 0.5)
                @unknown default: break
                }
            }
    }

    /// Converts a touch position across the row into a half-star rating.
    static func rating(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return Review.minimumRating }
        let raw = Double(x / width) * 5
        // Round up to the next half star, so any touch picks at least 0.5.
        return Review.normalized((raw * 2).rounded(.up) / 2)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var rating = 3.5
    VStack(alignment: .leading, spacing: 20) {
        StarRatingView(rating: 2)
        StarRatingView(rating: 4.5)
        StarRatingView(rating: 3, onColor: Theme.Colors.starOnDark, offColor: Theme.Colors.starOffOnDark)
            .padding(8)
            .background(Theme.Colors.darkCard)
        HalfStarPicker(rating: $rating)
        Text(StarRatingView.accessibilityText(for: rating))
            .font(Theme.Fonts.body(15))
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}
