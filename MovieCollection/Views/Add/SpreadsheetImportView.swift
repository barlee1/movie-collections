//
//  SpreadsheetImportView.swift
//  MovieCollection
//
//  Purpose: Add a whole collection from a CSV spreadsheet. Shows which columns
//  are understood, previews every row (matched to the catalog when possible),
//  and adds only the rows the user keeps checked.
//  Used in: RootTabView (Route.importSpreadsheet), opened from the Add tab.
//

import SwiftUI
import UniformTypeIdentifiers

struct SpreadsheetImportView: View {
    @State private var viewModel: SpreadsheetImportViewModel
    @State private var isPickingFile = false

    init(appModel: AppViewModel) {
        _viewModel = State(initialValue: SpreadsheetImportViewModel(appModel: appModel))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton()
                ScreenHeader(
                    title: "Import a spreadsheet",
                    subtitle: "Add a whole collection from a CSV file. You'll check the list before anything is added.",
                    titleSize: 34
                )

                switch viewModel.phase {
                case .choosing: choosing
                case .preview: preview
                case .done(let count):
                    ImportDoneView(
                        headline: "Added \(count) \(count == 1 ? "title" : "titles")",
                        message: "They're on your shelf now, ready to flip through.",
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
                    title: "Add \(viewModel.selectedCount) \(viewModel.selectedCount == 1 ? "title" : "titles")",
                    isEnabled: viewModel.selectedCount > 0,
                    action: viewModel.importSelected,
                    startOver: viewModel.startOver
                )
            }
        }
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url): viewModel.load(fileURL: url)
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

    // MARK: - Choosing a file

    private var choosing: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Columns it understands", size: 12)
                ForEach(SpreadsheetImporter.supportedColumns, id: \.0) { column, hint in
                    HStack {
                        Text(column).font(Theme.Fonts.body(15, weight: .semibold))
                        Spacer()
                        Text(hint)
                            .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                Text("Only Title is required. Movies found in our catalog get their director, cast, and genres filled in for you.")
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.top, 4)
            }
            .cardStyle(padding: 18, bordered: true)

            Text("In Numbers or Excel, export your sheet as CSV first (File › Export To › CSV).")
                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.Colors.textMuted)

            Button {
                isPickingFile = true
            } label: {
                Label("Choose a CSV file", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 16))

            Button("Try the sample spreadsheet", action: viewModel.loadSample)
                .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 15, height: 46))
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: previewHeading, size: 12)
            if viewModel.isMatchingOnline {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Looking up the rest in the movie database…")
                }
                .font(Theme.Fonts.body(13, relativeTo: .footnote))
                .foregroundStyle(Theme.Colors.textMuted)
            }
            ForEach(viewModel.rows) { row in
                Toggle(
                    isOn: Binding(
                        get: { viewModel.selectedIDs.contains(row.id) },
                        set: { _ in viewModel.toggle(row) }
                    )
                ) {
                    Text(row.title)
                }
                .toggleStyle(.checkRow(detail: detail(for: row)))
            }
        }
    }

    private var previewHeading: String {
        let found = "\(viewModel.rows.count) \(viewModel.rows.count == 1 ? "title" : "titles") found"
        return viewModel.skippedRows > 0 ? "\(found) · \(viewModel.skippedRows) rows skipped" : found
    }

    /// e.g. "2001 · Owned · DVD · PG · Found in catalog"
    private func detail(for row: ImportedTitle) -> String {
        let location = [row.format.locationLabel, row.service?.rawValue].compactMap { $0 }.joined(separator: " on ")
        let source =
            row.isAlreadyOnShelf
            ? "Already on your shelf"
            : (row.catalogMatch != nil ? "Found in catalog" : "Hand entered")
        return [
            row.year.map(String.init),
            row.kind == .tvShow ? "TV Show" : nil,
            location,
            row.filmRating?.label,
            source,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var errorIsShowing: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}
