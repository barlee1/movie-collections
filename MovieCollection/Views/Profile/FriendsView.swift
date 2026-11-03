//
//  FriendsView.swift
//  MovieCollection
//
//  Purpose: What the user's friends are watching. Sample reviews, clearly
//  labeled as coming soon, since there's no backend yet.
//  Used in: RootTabView (Route.friends), opened from Profile.
//

import SwiftUI

struct FriendsView: View {
    var reviews: [FriendReview] = FriendReview.samples

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BackButton()
                ScreenHeader(title: "Friends are watching", titleSize: 30)
                Label {
                    Text("Following friends is coming soon. These are sample reviews to show what it'll look like.")
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.Colors.action)
                }
                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.Colors.text)
                .cardStyle(background: Theme.Colors.tintSecondary)
                .accessibilityElement(children: .combine)
                ForEach(reviews) { review in
                    FriendReviewCard(review: review)
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .themedScreen()
    }
}

/// A friend's review on a dark card.
private struct FriendReviewCard: View {
    let review: FriendReview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(review.initials)
                    .font(Theme.Fonts.body(10, weight: .bold, relativeTo: .caption2))
                    .foregroundStyle(Theme.Colors.onHighlight)
                    .frame(width: 24, height: 24)
                    .background(Theme.Colors.highlight, in: Circle())
                    .accessibilityHidden(true)
                Text(review.friendName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(review.date.displayText)
                    .opacity(0.85)
            }
            .font(Theme.Fonts.body(12, relativeTo: .caption))

            Text(review.title)
                .font(Theme.Fonts.heading(19, relativeTo: .headline))

            StarRatingView(rating: review.rating, onColor: Theme.Colors.starOnDark, offColor: Theme.Colors.starOffOnDark)

            Text(review.text)
                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.Colors.onDarkCardMuted)
                .lineSpacing(3)
        }
        .foregroundStyle(Theme.Colors.onDarkCard)
        .cardStyle(background: Theme.Colors.darkCard)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        FriendsView()
    }
}
