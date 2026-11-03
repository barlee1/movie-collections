//
//  SignInView.swift
//  MovieCollection
//
//  Purpose: The sign-in page guests see on screens that need a profile
//  (Profile and Friends). Short steps: name and photo, streaming services,
//  and, only if the sample movies are loaded, whether to keep them.
//  Everything added before signing in stays on the shelf.
//  Used in: ProfileView (as a guest), RootTabView (Route.friends as a guest).
//

import PhotosUI
import SwiftUI

struct SignInView: View {
    /// Why this screen needs signing in, shown under the heading.
    var reason = "Sign in to save your shelf under your name and set up your profile."
    /// True when pushed onto a tab's stack (Friends), so the first step has a back button.
    var showsBackButton = false

    @State private var viewModel: SignInViewModel
    @State private var pickedPhoto: PhotosPickerItem?
    @FocusState private var isNameFocused: Bool

    init(appModel: AppViewModel, reason: String? = nil, showsBackButton: Bool = false) {
        _viewModel = State(initialValue: SignInViewModel(appModel: appModel))
        if let reason { self.reason = reason }
        self.showsBackButton = showsBackButton
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch viewModel.step {
                    case .aboutYou: aboutYouStep
                    case .services: servicesStep
                    case .shelf: shelfStep
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.step != .shelf {
                Button(viewModel.isLastStep ? "Sign in" : "Continue") {
                    if viewModel.isLastStep {
                        viewModel.signIn()
                    } else {
                        viewModel.next()
                    }
                }
                .buttonStyle(.pill(.primary, height: 52))
                .disabled(!viewModel.canContinue)
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 16)
            }
        }
        .animation(.snappy, value: viewModel.step)
        .themedScreen()
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.setPhoto(from: data)
                }
                pickedPhoto = nil
            }
        }
        .alert(
            "Couldn't use that photo",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        let showsBar = !viewModel.isFirstStep || showsBackButton
        if showsBar {
            HStack {
                if viewModel.isFirstStep {
                    BackButton()
                } else {
                    Button {
                        viewModel.back()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(Theme.Fonts.body(15, weight: .semibold))
                    }
                    .tint(Theme.Colors.link)
                }
                Spacer()
                Text(viewModel.progressLabel)
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 8)
        }
    }

    // MARK: - Steps

    private var aboutYouStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScreenHeader(title: "Sign in", subtitle: reason, titleSize: 34)

            HStack(spacing: 18) {
                ProfileAvatar(name: viewModel.name, photoData: viewModel.photoData, size: 84)
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Text(viewModel.photoData == nil ? "Add a photo" : "Change photo")
                    }
                    .buttonStyle(.pill(.secondary, fontSize: 15, height: 38, fullWidth: false))
                    if viewModel.photoData != nil {
                        Button("Remove photo", role: .destructive) { viewModel.removePhoto() }
                            .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                            .tint(Theme.Colors.error)
                    } else {
                        Text("Optional")
                            .font(Theme.Fonts.body(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Your name", size: 12)
                TextField("e.g. Ella Lauren", text: $viewModel.name)
                    .pillField()
                    .textContentType(.name)
                    .submitLabel(.continue)
                    .focused($isNameFocused)
                    .onSubmit { viewModel.next() }
                    .accessibilityIdentifier("signIn.name")
            }

            Text(
                "Anything you've already added stays on your shelf. For now your profile and shelf are saved on this phone; accounts that back up and sync are coming."
            )
            .font(Theme.Fonts.body(13, relativeTo: .footnote))
            .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    private var servicesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScreenHeader(
                title: "Your streaming services",
                subtitle: "Pick the ones you pay for. You can change these any time on your profile.",
                titleSize: 34
            )
            .padding(.bottom, 10)
            ServicePickerList(selected: $viewModel.subscriptions)
        }
    }

    private var shelfStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(
                title: "Keep the sample movies?",
                subtitle:
                    "Start fresh to clear the sample movies, along with any reviews or dates you added to them. Anything you added yourself stays either way.",
                titleSize: 34
            )
            Button("Start fresh") { viewModel.signIn(keepingSampleShelf: false) }
                .buttonStyle(.pill(.primary, height: 52))
            Button("Keep the sample movies") { viewModel.signIn(keepingSampleShelf: true) }
                .buttonStyle(.pill(.secondary, height: 52))
        }
    }
}

#Preview {
    let appModel = AppViewModel.preview(asGuest: true)
    NavigationStack {
        SignInView(appModel: appModel)
    }
    .environment(AppRouter())
    .task { await appModel.start() }
}
