//
//  ProfileView.swift
//  MovieCollection
//
//  Purpose: The Profile tab: the user's photo and name (editable), review
//  count, movie and TV show counts, their streaming services, shortcuts to
//  friends and Add, and a gear that opens Settings. Guests see the sign-in
//  page here instead.
//  Used in: RootTabView (Profile tab).
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppViewModel.self) private var appModel
    @Environment(AppRouter.self) private var router
    @State private var isEditingSubscriptions = false
    @State private var isEditingProfile = false

    var body: some View {
        if appModel.isGuest {
            SignInView(appModel: appModel, reason: "Sign in to set up your profile: your name, photo, and the streaming services you pay for.")
        } else {
            signedInProfile
        }
    }

    @ViewBuilder
    private var signedInProfile: some View {
        let reviewCount = appModel.reviewedTitles.count
        let profile = appModel.profile ?? UserProfile(name: "")

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    settingsButton
                }
                .padding(.bottom, -20)

                HStack(spacing: 18) {
                    ProfileAvatar(profile: profile)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(Theme.Fonts.heading(28, relativeTo: .title))
                            .accessibilityAddTraits(.isHeader)
                        Text("\(reviewCount) \(reviewCount == 1 ? "review" : "reviews") written")
                            .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.Colors.textMuted)
                        Button("Edit profile") { isEditingProfile = true }
                            .font(Theme.Fonts.body(14, weight: .semibold, relativeTo: .subheadline))
                            .tint(Theme.Colors.link)
                            .padding(.top, 2)
                    }
                }

                HStack(spacing: 12) {
                    statCard(count: appModel.movieCount, label: "Movies")
                    statCard(count: appModel.tvShowCount, label: "TV Shows")
                }

                WatchProgressBar(watched: appModel.watchedCount, total: appModel.titles.count)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Streaming Services")
                            .font(Theme.Fonts.heading(20, relativeTo: .title3))
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("Edit") { isEditingSubscriptions = true }
                            .buttonStyle(.pill(.secondary, fontSize: 15, height: 36, fullWidth: false))
                            .accessibilityLabel("Edit streaming services")
                    }
                    if appModel.subscriptions.isEmpty {
                        Text("No services yet. Tap Edit to add the ones you pay for.")
                            .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.Colors.textMuted)
                    } else {
                        FlowLayout {
                            ForEach(appModel.subscriptions) { service in
                                TagView(text: service.rawValue, style: .main, size: .large)
                            }
                        }
                    }
                }
                .animation(.snappy, value: appModel.subscriptions)

                VStack(spacing: 12) {
                    Button("See what your friends are watching") { router.push(.friends) }
                        .buttonStyle(.pill(.alt))
                    Button("Add to your Collection") { router.select(.add) }
                        .buttonStyle(.pill(.primary))
                }
            }
            .padding(24)
        }
        .themedScreen()
        .sheet(isPresented: $isEditingSubscriptions) {
            EditSubscriptionsSheet(current: appModel.subscriptions) { services in
                appModel.setSubscriptions(services)
            }
        }
        .sheet(isPresented: $isEditingProfile) {
            EditProfileSheet(profile: profile) { edited in
                appModel.updateProfile(edited)
            }
        }
    }

    private var settingsButton: some View {
        Button {
            router.push(.settings)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Colors.text)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.trailing, -12)
        .accessibilityLabel("Settings")
    }

    private func statCard(count: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(Theme.Fonts.heading(32, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.secondary)
                .contentTransition(.numericText())
            Text(label)
                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
        }
        .cardStyle(background: Theme.Colors.tintSecondary)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        ProfileView()
    }
    .environment(appModel)
    .environment(AppRouter())
    .task { await appModel.start() }
}
