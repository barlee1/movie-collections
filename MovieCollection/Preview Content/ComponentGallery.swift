//
//  ComponentGallery.swift
//  MovieCollection
//
//  Purpose: One preview showing every shared component together, for a
//  quick visual check against the design.
//  Used in: Xcode Previews only.
//

import SwiftUI

private struct ComponentGallery: View {
    @State private var seen = "All"
    @State private var rating = 3.5
    @State private var year = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Your shelf", subtitle: "30 titles · 28 not reviewed yet")

                FlowLayout {
                    ForEach(["All", "Not reviewed", "Reviewed"], id: \.self) { option in
                        ChipButton(label: option, isOn: seen == option) { seen = option }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                    ShelfPosterCard(title: "Batman Begins", letter: "B", meta: "2005 · PG-13 · Plex", format: .digital, isReviewed: false)
                    ShelfPosterCard(title: "The Phantom Menace", letter: "P", meta: "1999 · 2/5", format: .dvd, isReviewed: true)
                }

                FlowLayout(spacing: 6) {
                    Text("Location:").font(Theme.Fonts.body(16, weight: .bold))
                    TagView(text: MediaFormat.streaming.locationLabel, style: .secondary, systemImage: MediaFormat.streaming.systemImage)
                    TagView(text: "Amazon Prime", style: .neutral)
                }

                HStack(alignment: .top, spacing: 12) {
                    PosterArt(title: "The Lake House", letter: "L")
                        .frame(width: 40, height: 56)
                        .clipShape(.rect(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The Lake House").font(Theme.Fonts.heading(17, relativeTo: .headline))
                        StarRatingView(rating: 4)
                    }
                }
                .cardStyle(background: Theme.Colors.tintMain)

                SectionLabel(text: "Your rating")
                HalfStarPicker(rating: $rating)

                SectionLabel(text: "Year", size: 12)
                TextField("e.g. 2006", text: $year).pillField()

                Button("Add to your Collection") {}.buttonStyle(.pill())
                Button("See what your friends are watching") {}.buttonStyle(.pill(.alt))
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.vertical, 12)
        }
        .themedScreen()
    }
}

#Preview("All components") {
    ComponentGallery()
}
