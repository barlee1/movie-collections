//
//  LetterboxdImportView.swift
//  MovieCollection
//
//  Purpose: Bring Letterboxd ratings, watch dates, and reviews in for films
//  already on the shelf. Explains how to export from Letterboxd, previews the
//  matches, and updates only the titles the user keeps checked.
//  Used in: RootTabView (Route.importLetterboxd), opened from the Add tab.
//

import SwiftUI
import UniformTypeIdentifiers

struct LetterboxdImportView: View {
    @State private var viewModel: LetterboxdImportViewModel
    @State private var isPickingFiles = false

    init(appModel: AppViewModel) {
        _viewModel = State(initialValue: LetterboxdImportViewModel(appModel: appModel))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton()
                ScreenHeader(
                    title: "Import from Letterboxd",
                    subtitle: "Bring your ratings and watch dates in for films you already own.",
                    titleSize: 34
                )

                switch viewModel.phase {
                case .choosing: choosing
                case .preview: preview
                case .done(let count):
                    ImportDoneView(
                        headline: "Updated \(count) \(count == 1 ? "title" : "titles")",
                        message: "Your Letterboxd ratings and watch dates are on your shelf now.",
                        startOver: viewModel.startOver
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .themedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.phase == .preview {
                ImportActionBar(
                    title: "Update \(viewModel.selectedCount) \(viewModel.selectedCount == 1 ? "title" : "titles")",
                    isEnabled: viewModel.selectedCount > 0,
                    action: viewModel.applySelected,
                    startOver: viewModel.startOver
                )
            }
        }
        .fileImporter(
            isPresented: $isPickingFiles,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): viewModel.load(fileURLs: urls)
            case .failure(let error): viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Couldn't import", isPresented: errorIsShowing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .animation(.snappy, value: viewModel.phase)
    }

    // MARK: - Choosing files

    private var choosing: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Get your export", size: 12)
                step(1, "On letterboxd.com, open Settings, then Import & Export, then Export Your Data.")
                step(2, "Unzip the file Letterboxd sends you.")
                step(3, "Choose ratings.csv, diary.csv, or reviews.csv. You can pick more than one.")
            }
            .cardStyle(padding: 18, bordered: true)

            Button {
                isPickingFiles = true
            } label: {
                Label("Choose export files", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 16))

            Button("Try a sample export", action: viewModel.loadSample)
                .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 15, height: 46))
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(Theme.Fonts.body(13, weight: .bold, relativeTo: .footnote))
                .foregroundStyle(Theme.Colors.onAction)
                .frame(width: 24, height: 24)
                .background(Theme.Colors.action, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.Fonts.body(15))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.matches.isEmpty {
                Text("None of these films are on your shelf yet. Add them first, then import again to bring in your ratings.")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textMuted)
            } else {
                SectionLabel(
                    text: "\(viewModel.matches.count) \(viewModel.matches.count == 1 ? "film matches" : "films match") your shelf",
                    size: 12
                )
                ForEach(viewModel.matches) { match in
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.selectedIDs.contains(match.id) },
                            set: { _ in viewModel.toggle(match) }
                        )
                    ) {
                        Text(match.titleName)
                    }
                    .toggleStyle(.checkRow(detail: match.summary))
                }
            }

            if !viewModel.unmatched.isEmpty {
                SectionLabel(text: "Not on your shelf", size: 12)
                    .padding(.top, 10)
                FlowLayout(spacing: 6) {
                    ForEach(viewModel.unmatched.prefix(12)) { entry in
                        TagView(text: entry.name, style: .neutral)
                    }
                    if viewModel.unmatched.count > 12 {
                        TagView(text: "+\(viewModel.unmatched.count - 12) more", style: .neutral)
                    }
                }
            }
        }
    }

    private var errorIsShowing: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}
