//
//  ScreenChrome.swift
//  MovieCollection
//
//  Purpose: Shared screen pieces from the design: the large heading with an
//  optional subtitle, the plain back arrow, and the themed screen background.
//  Used in: Every tab screen and pushed screen.
//

import SwiftUI

// MARK: - Screen header

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var titleSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Fonts.heading(titleSize, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.text)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Fonts.body(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Back button

/// The design's plain back arrow. Pops the current navigation stack.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.Colors.text)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Line the arrow up with the page edge despite the larger tap area.
        .padding(.leading, -12)
        .accessibilityLabel("Back")
    }
}

// MARK: - Screen background

extension View {
    /// Applies the page background and the default text color, and hides
    /// the system navigation bar (screens draw their own headers).
    /// - Parameter showsNavigationBar: True for screens that use the system
    ///   bar instead, like Shelf with its standard search field.
    func themedScreen(showsNavigationBar: Bool = false) -> some View {
        self
            .foregroundStyle(Theme.Colors.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.Colors.background.ignoresSafeArea())
            .background(SwipeBackEnabler())
            .toolbar(showsNavigationBar ? .automatic : .hidden, for: .navigationBar)
    }
}

// MARK: - Swipe-back gesture

/// Hiding the system navigation bar also turns off iOS's edge-swipe-to-go-back
/// gesture. This invisible helper turns it back on, only allowing it when
/// there's a screen to go back to.
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Both the edge swipe and iOS 26's swipe-anywhere back gesture.
            let gestures = [
                navigationController?.interactivePopGestureRecognizer,
                navigationController?.interactiveContentPopGestureRecognizer,
            ]
            for gesture in gestures.compactMap({ $0 }) {
                gesture.delegate = self
                gesture.isEnabled = true
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Swiping back on a tab's root screen would leave the stack in a stuck state.
            guard (navigationController?.viewControllers.count ?? 0) > 1 else { return false }

            // The swipe-anywhere back gesture steps aside when the swipe starts on
            // something that scrolls sideways (like Tonight's mood chips), so that
            // swipe scrolls the row instead of leaving the screen.
            if gestureRecognizer === navigationController?.interactiveContentPopGestureRecognizer,
                let view = gestureRecognizer.view,
                startsOnHorizontalScroller(view.hitTest(gestureRecognizer.location(in: view), with: nil))
            {
                return false
            }
            return true
        }

        /// Whether a view, or any view containing it, scrolls horizontally.
        private func startsOnHorizontalScroller(_ hitView: UIView?) -> Bool {
            var view = hitView
            while let current = view {
                if let scrollView = current as? UIScrollView,
                    scrollView.contentSize.width > scrollView.bounds.width + 1
                {
                    return true
                }
                view = current.superview
            }
            return false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Scroll views wait for the edge swipe to fail first (as with the system
            // back gesture), so a swipe from the left edge goes back instead of scrolling.
            gestureRecognizer === navigationController?.interactivePopGestureRecognizer
                && otherGestureRecognizer is UIPanGestureRecognizer
        }
    }
}

// MARK: - Previews

#Preview {
    VStack(alignment: .leading, spacing: 18) {
        BackButton()
        ScreenHeader(title: "Your shelf", subtitle: "30 titles · 28 not reviewed yet")
    }
    .padding(.horizontal, Theme.Spacing.page)
    .themedScreen()
}
