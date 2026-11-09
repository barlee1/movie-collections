//
//  RootTabView.swift
//  MovieCollection
//
//  Purpose: The app shell. Each tab keeps its own NavigationStack (so its
//  screens and scroll position survive tab switches), the system tab bar is
//  hidden, and the design's custom navBar sits at the bottom.
//  Used in: ContentView.
//

import SwiftUI

struct RootTabView: View {
    @Environment(AppRouter.self) private var router
    private let appModel: AppViewModel
    /// Shared by the Tonight tab and the detail screen's "Pick another".
    @State private var tonight: TonightViewModel
    @State private var isKeyboardVisible = false
    /// Shared by shelf posters and the card viewer for the zoom transition.
    @Namespace private var cardZoomNamespace

    init(appModel: AppViewModel) {
        self.appModel = appModel
        _tonight = State(initialValue: TonightViewModel(appModel: appModel))
    }

    var body: some View {
        @Bindable var router = router

        // The bar is stacked under the tabs (not floated over them), so screen
        // content, overlays, and bottom bars always end above it.
        VStack(spacing: 0) {
            TabView(selection: $router.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    NavigationStack(path: router.path(for: tab)) {
                        rootScreen(for: tab)
                            .navigationDestination(for: Route.self, destination: destination)
                    }
                    .toolbarVisibility(.hidden, for: .tabBar)
                    .tag(tab)
                }
            }
            // Hidden while typing so the keyboard gets the room, like most iOS apps.
            if !isKeyboardVisible {
                navBar(selectedTab: router.selectedTab) { tab in
                    router.select(tab)
                }
            }
        }
        .environment(tonight)
        .environment(\.cardZoomNamespace, cardZoomNamespace)
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification).map({ _ in () }) {
                isKeyboardVisible = true
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification).map({ _ in () }) {
                isKeyboardVisible = false
            }
        }
    }

    @ViewBuilder
    private func rootScreen(for tab: AppTab) -> some View {
        switch tab {
        case .shelf: ShelfView(appModel: appModel)
        case .tonight: TonightView()
        case .add: AddFilmsView()
        case .reviews: ReviewsView()
        case .profile: ProfileView()
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .titleDetail(let id, let fromTonight, let fromShelf):
            TitleDetailView(titleID: id, fromTonight: fromTonight, appModel: appModel)
                // A new identity per title, so "Pick another" builds a fresh screen.
                .id(id)
                // Only the Shelf's posters are zoom sources.
                .cardZoomTransition(sourceID: id, in: fromShelf ? cardZoomNamespace : nil)
        case .reviews(let highlightedID):
            ReviewsView(highlightedTitleID: highlightedID)
        case .addTitle(let prefillMovieID):
            AddTitleView(
                appModel: appModel,
                prefill: prefillMovieID.flatMap(appModel.movie(withID:))
            )
        case .scanCover:
            ScanCoverView(appModel: appModel)
        case .importSpreadsheet:
            SpreadsheetImportView(appModel: appModel)
        case .importLetterboxd:
            LetterboxdImportView(appModel: appModel)
        case .settings:
            SettingsView()
        case .manageLocations:
            ManageLocationsView()
        case .manageTags:
            ManageTagsView()
        case .manageFamily:
            ManageFamilyView()
        case .friends:
            // Following friends needs a profile, so guests sign in first.
            if appModel.isGuest {
                SignInView(appModel: appModel, reason: "Sign in to see what your friends are watching.", showsBackButton: true)
            } else {
                FriendsView()
            }
        }
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    RootTabView(appModel: appModel)
        .environment(appModel)
        .environment(AppRouter())
        .task { await appModel.start() }
}
