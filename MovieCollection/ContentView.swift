//
//  ContentView.swift
//  MovieCollection
//
//  Created by Kylee Brown on 9/24/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var appModel
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch appModel.loadState {
            case .loading:
                ProgressView("Loading your shelf…")
                    .tint(Theme.Colors.action)
                    .font(Theme.Fonts.body(15))
            case .failed(let message):
                VStack(spacing: 12) {
                    Text("Couldn't load your shelf")
                        .font(Theme.Fonts.heading(24))
                    Text(message)
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Spacing.page)
            case .ready:
                // No setup needed first: new users explore as a guest right away.
                RootTabView(appModel: appModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Theme.Colors.text)
        .background(Theme.Colors.background.ignoresSafeArea())
        .environment(router)
        .alert("Something went wrong", isPresented: errorIsShowing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.errorMessage ?? "")
        }
    }

    /// Shows the alert while there's a save error, and clears it on dismiss.
    private var errorIsShowing: Binding<Bool> {
        Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    ContentView()
        .environment(appModel)
        .task { await appModel.start() }
}
