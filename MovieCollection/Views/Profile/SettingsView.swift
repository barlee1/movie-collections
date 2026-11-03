//
//  SettingsView.swift
//  MovieCollection
//
//  Purpose: Settings, opened from the gear on Profile: account (name and
//  photo), streaming services, organizing (locations and tags), data (import, CSV export, sample movies,
//  delete everything), and About (feedback, privacy, TMDB credit, version).
//  Later milestones add Family and Suggestions here.
//  Used in: RootTabView (Route.settings).
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appModel
    @Environment(AppRouter.self) private var router
    @State private var isEditingProfile = false
    @State private var isEditingSubscriptions = false
    @State private var isConfirmingSampleRemoval = false
    @State private var isConfirmingDeleteAll = false
    @State private var exportURL: URL?
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                BackButton()
                ScreenHeader(title: "Settings", titleSize: 34)

                accountSection
                servicesSection
                organizingSection
                dataSection
                aboutSection
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .themedScreen()
        // A fresh export file whenever the shelf changes, ready to share.
        .task(id: appModel.titles.count) { refreshExport() }
        .sheet(isPresented: $isEditingProfile) {
            if let profile = appModel.profile {
                EditProfileSheet(profile: profile) { appModel.updateProfile($0) }
            }
        }
        .sheet(isPresented: $isEditingSubscriptions) {
            EditSubscriptionsSheet(current: appModel.subscriptions) { appModel.setSubscriptions($0) }
        }
        .confirmationDialog("Remove the sample movies?", isPresented: $isConfirmingSampleRemoval, titleVisibility: .visible) {
            Button("Remove Sample Movies", role: .destructive) {
                let removed = appModel.removeSampleShelf()
                message = "Removed \(removed) sample \(removed == 1 ? "title" : "titles")."
            }
        } message: {
            Text("Any reviews or dates you added to them go too. Titles you added yourself stay.")
        }
        .confirmationDialog("Delete all your data?", isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                if appModel.deleteAllData() {
                    // The signed-out Profile shows sign-in, so leave Settings.
                    router.select(.shelf)
                }
            }
        } message: {
            Text("This removes every title, review, and your profile from this phone. It can't be undone. Export your shelf first to keep a copy.")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        section("Account") {
            HStack(spacing: 14) {
                if let profile = appModel.profile {
                    ProfileAvatar(profile: profile, size: 52)
                    Text(profile.name)
                        .font(Theme.Fonts.body(17, weight: .semibold))
                }
                Spacer()
                Button("Edit") { isEditingProfile = true }
                    .buttonStyle(.pill(.secondary, fontSize: 15, height: 36, fullWidth: false))
                    .accessibilityLabel("Edit profile")
            }
        }
    }

    private var servicesSection: some View {
        section("Streaming services") {
            HStack(alignment: .firstTextBaseline) {
                Text(appModel.subscriptions.isEmpty ? "None yet" : appModel.subscriptions.map(\.rawValue).joined(separator: ", "))
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(appModel.subscriptions.isEmpty ? Theme.Colors.textMuted : Theme.Colors.text)
                Spacer()
                Button("Edit") { isEditingSubscriptions = true }
                    .buttonStyle(.pill(.secondary, fontSize: 15, height: 36, fullWidth: false))
                    .accessibilityLabel("Edit streaming services")
            }
        }
    }

    private var organizingSection: some View {
        section("Organizing") {
            row("Locations", detail: "\(appModel.locations.count)", systemImage: "mappin.and.ellipse") { router.push(.manageLocations) }
            row("Tags", detail: appModel.tags.isEmpty ? "None yet" : "\(appModel.tags.count)", systemImage: "tag") { router.push(.manageTags) }
            if !appModel.loanedOutTitles.isEmpty {
                Text("Loaned out: " + appModel.loanedOutTitles.map { title in
                    title.loanedTo.map { "\(title.title) (\($0))" } ?? title.title
                }.joined(separator: ", "))
                .font(Theme.Fonts.body(13, relativeTo: .footnote))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.top, 4)
            }
        }
    }

    private var dataSection: some View {
        section("Data") {
            row("Import a spreadsheet", systemImage: "tablecells") { router.push(.importSpreadsheet) }
            row("Import from Letterboxd", systemImage: "star") { router.push(.importLetterboxd) }

            if let exportURL, !appModel.titles.isEmpty {
                ShareLink(item: exportURL) {
                    rowLabel("Export shelf as CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }

            if appModel.hasSampleTitles {
                row("Remove the sample movies", systemImage: "minus.circle") { isConfirmingSampleRemoval = true }
            }
            if !appModel.isSampleShelfLoaded {
                row("Load the sample movies", systemImage: "film.stack") {
                    let added = appModel.loadSampleShelf()
                    message = "Added \(added) sample \(added == 1 ? "title" : "titles") to your shelf."
                }
            }

            Button(role: .destructive) {
                isConfirmingDeleteAll = true
            } label: {
                rowLabel("Delete all data", systemImage: "trash", color: Theme.Colors.error)
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutSection: some View {
        section("About") {
            if let feedbackURL = AppInfo.feedbackURL {
                Link(destination: feedbackURL) { rowLabel("Send feedback", systemImage: "envelope") }
                    .buttonStyle(.plain)
            }
            if let privacyURL = AppInfo.privacyPolicyURL {
                Link(destination: privacyURL) { rowLabel("Privacy policy", systemImage: "hand.raised") }
                    .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(AppInfo.tmdbCredit)
                if let tmdbURL = AppInfo.tmdbURL {
                    Link("themoviedb.org", destination: tmdbURL)
                        .tint(Theme.Colors.link)
                }
                Text(AppInfo.versionText)
            }
            .font(Theme.Fonts.body(13, relativeTo: .footnote))
            .foregroundStyle(Theme.Colors.textMuted)
            .padding(.top, 4)
        }
    }

    // MARK: - Builders

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Fonts.heading(20, relativeTo: .title3))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(bordered: true)
        }
    }

    private func row(_ title: String, detail: String? = nil, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(title, detail: detail, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, detail: String? = nil, systemImage: String, color: Color = Theme.Colors.text) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
            Spacer()
            if let detail {
                Text(detail)
                    .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .font(Theme.Fonts.body(16, weight: .semibold))
        .foregroundStyle(color)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    private func refreshExport() {
        exportURL = try? CollectionExporter.exportFile(for: appModel.titles)
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        SettingsView()
    }
    .environment(appModel)
    .environment(AppRouter())
    .task { await appModel.start() }
}
