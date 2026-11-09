//
//  OwnItInsteadCard.swift
//  MovieCollection
//
//  Purpose: The "Own it instead" card on a Streaming title's detail screen,
//  so the user can keep a movie even after dropping a subscription: an eBay
//  search for a disc, the digital stores that sell it (from TMDB's JustWatch
//  data), or "No way to own this yet" for streaming-only titles. Without that
//  data it still offers eBay and store searches.
//  Used in: TitleDetailView. Turned off in Settings › Suggestions.
//

import SwiftUI

struct OwnItInsteadCard: View {
    let title: OwnedTitle
    let state: TitleDetailViewModel.OwnItState
    /// Opens the Edit sheet, to switch the title to DVD or Digital once bought.
    let onBought: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Own it instead")
                    .font(Theme.Fonts.heading(20, relativeTo: .title3))
                    .accessibilityAddTraits(.isHeader)
                Text("Keep it even if you leave \(title.service?.rawValue ?? "the service").")
                    .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            if let eBay = OwnItLinks.eBayURL(title: title.title, year: title.year) {
                Link(destination: eBay) {
                    Label("Search eBay for a disc", systemImage: "opticaldisc")
                }
                .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 42, fullWidth: false))
                .accessibilityHint("Opens eBay")
            }

            digital

            Button("Bought it? Change it to DVD or Digital", action: onBought)
                .font(Theme.Fonts.body(14, weight: .semibold))
                .foregroundStyle(Theme.Colors.link)
                .frame(minHeight: 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(background: Theme.Colors.tintSecondary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.ownItInstead")
    }

    // MARK: - Digital stores

    @ViewBuilder
    private var digital: some View {
        switch state {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Checking where it's sold…")
                    .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        case .known(let options) where options.isBuyable:
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Buy digitally", size: 12)
                FlowLayout(spacing: 8) {
                    ForEach(options.stores) { store in
                        if let url = OwnItLinks.storeURL(
                            for: store, title: title.title, year: title.year,
                            region: options.region, watchPage: options.watchPageURL)
                        {
                            storeLink(store.name, url: url)
                        }
                    }
                }
                credit
            }
        case .known(let options):
            VStack(alignment: .leading, spacing: 4) {
                Label("No way to own this yet", systemImage: "nosign")
                    .font(Theme.Fonts.body(15, weight: .semibold))
                Text(notSoldText(region: options.region))
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.textMuted)
                credit
            }
        case .unknown:
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Search digital stores", size: 12)
                FlowLayout(spacing: 8) {
                    ForEach(OwnItLinks.fallbackStores(title: title.title, year: title.year), id: \.name) { store in
                        storeLink(store.name, url: store.url)
                    }
                }
            }
        }
    }

    private func storeLink(_ name: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 4) {
                Text(name)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 14, height: 34, fullWidth: false))
        .accessibilityHint("Opens \(name)")
    }

    /// TMDB requires crediting JustWatch wherever its where-to-buy data is shown.
    @ViewBuilder
    private var credit: some View {
        if let url = AppInfo.justWatchURL {
            Link(AppInfo.justWatchCredit, destination: url)
                .font(Theme.Fonts.body(12, relativeTo: .caption))
                .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    /// e.g. "It isn't sold digitally in the United States. Streaming originals often aren't."
    private func notSoldText(region: String) -> String {
        let country = Locale.current.localizedString(forRegionCode: region) ?? region
        let place = region == "US" ? "the \(country)" : country
        return "It isn't sold digitally in \(place). Streaming originals often aren't, but eBay may still have a disc."
    }
}

#Preview {
    let title = OwnedTitle(title: "Inception", year: 2010, format: .streaming, service: .netflix)
    let stores = PurchaseOptions(
        stores: [.init(id: 2, name: "Apple TV Store"), .init(id: 10, name: "Amazon Video"), .init(id: 7, name: "Fandango At Home")],
        region: "US", watchPageURL: nil)
    ScrollView {
        VStack(spacing: 16) {
            OwnItInsteadCard(title: title, state: .known(stores)) {}
            OwnItInsteadCard(title: title, state: .known(PurchaseOptions(stores: [], region: "US", watchPageURL: nil))) {}
            OwnItInsteadCard(title: title, state: .unknown) {}
        }
        .padding(Theme.Spacing.page)
    }
    .themedScreen()
}
