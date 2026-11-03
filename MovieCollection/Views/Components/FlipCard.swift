//
//  FlipCard.swift
//  MovieCollection
//
//  Purpose: A two-sided card that turns over in 3D, like flipping a real card.
//  Animate changes to `isFlipped` (for example with withAnimation) to see the flip.
//  Used in: TitleDeckView.
//

import SwiftUI

struct FlipCard<Front: View, Back: View>: View {
    let isFlipped: Bool
    private let front: Front
    private let back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isFlipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.isFlipped = isFlipped
        self.front = front()
        self.back = back()
    }

    var body: some View {
        ZStack {
            // Both faces turn together; the back starts half a turn behind the front.
            front
                .modifier(FlipFace(angle: isFlipped ? 180 : 0, rotates: !reduceMotion))
                .accessibilityHidden(isFlipped)
            back
                .modifier(FlipFace(angle: isFlipped ? 0 : -180, rotates: !reduceMotion))
                .accessibilityHidden(!isFlipped)
        }
    }
}

/// Rotates one face of the card around its vertical axis, hiding it while it
/// faces away (SwiftUI would otherwise draw it mirrored). Animatable, so the
/// face switches exactly halfway through the turn.
private struct FlipFace: ViewModifier, Animatable {
    /// 0 means facing the viewer; ±180 means facing away.
    var angle: Double
    /// When false (Reduce Motion), the faces swap without rotating.
    let rotates: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var isFacingViewer: Bool {
        cos(angle * .pi / 180) > 0
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(rotates ? angle : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.45
            )
            .opacity(isFacingViewer ? 1 : 0)
            // The hidden face shouldn't catch taps meant for the visible one.
            .allowsHitTesting(isFacingViewer)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var isFlipped = false
    FlipCard(isFlipped: isFlipped) {
        ShelfPosterCard(
            title: "Apollo 13", letter: "A", meta: "1995 · PG", format: .dvd,
            isReviewed: false, aspectRatio: 2 / 3, titleSize: 28)
    } back: {
        Text("The back of the card")
            .font(Theme.Fonts.heading(24))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.tintMain, in: .rect(cornerRadius: Theme.Radius.poster))
    }
    .frame(width: 260, height: 390)
    .onTapGesture {
        withAnimation(.spring(duration: 0.55, bounce: 0.2)) { isFlipped.toggle() }
    }
    .padding(40)
    .themedScreen()
}
