//
//  TitleDetailView.swift
//  MovieCollection
//
//  Purpose: One title's detail screen: poster, format, where a disc is (with
//  Move and Mark returned), film info, tags, trailer and IMDb links, watch
//  history, and review, plus Edit. From Tonight it also
//  shows "Tonight's pick" and "Pick another".
//  Used in: RootTabView (Route.titleDetail).
//

import SwiftData
import SwiftUI

struct TitleDetailView: View {
    @State private var viewModel: TitleDetailViewModel
    @Environment(AppRouter.self) private var router
    @Environment(TonightViewModel.self) private var tonight

    init(titleID: PersistentIdentifier, fromTonight: Bool, appModel: AppViewModel) {
        _viewModel = State(initialValue: TitleDetailViewModel(titleID: titleID, fromTonight: fromTonight, appModel: appModel))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let title = viewModel.title {
                    content(for: title)
                } else {
                    Text("This title is no longer on your shelf.")
                        .font(Theme.Fonts.body(16))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .themedScreen()
        // Just the review: stars and a note.
        .sheet(isPresented: $viewModel.isWritingNote) {
            if let title = viewModel.title {
                ReviewNoteSheet(titleName: title.title, rating: viewModel.rating, note: viewModel.reviewNote) { rating, note in
                    viewModel.saveNote(rating: rating, note: note)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingWatchSheet) {
            if let title = viewModel.title {
                let watch = viewModel.editingWatch
                WatchSheet(titleName: title.title, watch: watch) { date, note in
                    viewModel.saveWatch(date: date, note: note)
                } onDelete: {
                    if let watch { viewModel.deleteWatch(watch) }
                }
            }
        }
        .sheet(isPresented: $viewModel.isPickingTags) {
            if let title = viewModel.title {
                TagPickerSheet(selected: title.sortedTags) { viewModel.setTags($0) }
            }
        }
        .sheet(isPresented: $viewModel.isMovingDisc) {
            if let title = viewModel.title {
                MoveDiscSheet(title: title, locations: viewModel.appModel.locations) { location, borrower, date in
                    viewModel.appModel.move(title, to: location, loanedTo: borrower, on: date)
                }
            }
        }
        // Everything about the title.
        .sheet(isPresented: $viewModel.isEditing) {
            if let title = viewModel.title {
                EditTitleSheet(title: title, appModel: viewModel.appModel, startWithReview: viewModel.editStartsWithReview) {
                    // The title was removed: leave its detail screen.
                    router.pop()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            BackButton()
            Spacer()
            if viewModel.fromTonight {
                TagView(text: "Tonight's pick", style: .main)
            }
            if viewModel.title != nil {
                Button("Edit") { viewModel.startEditing() }
                    .buttonStyle(.pill(.secondary, fontSize: 15, height: 40, fullWidth: false))
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for title: OwnedTitle) -> some View {
        PosterArt(title: title.title, letter: title.posterLetter, letterHeight: 0.45)
            .frame(width: 190, height: 285)
            .clipShape(.rect(cornerRadius: Theme.Radius.lg))
            .themeShadow(.md)
            .frame(maxWidth: .infinity)

        location(for: title)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.infoRows) { row in
                Text("\(Text("\(row.label):").font(Theme.Fonts.body(16, weight: .bold))) \(row.value)")
                    .font(Theme.Fonts.body(16))
                    .lineSpacing(2)
            }
        }

        place(for: title)
        tags(for: title)

        HStack(spacing: 16) {
            if let trailerURL = title.trailerURL {
                Link(destination: trailerURL) {
                    Label("Watch trailer", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 42, fullWidth: false))
                .accessibilityHint("Opens YouTube")
            }
            if let url = title.imdbURL {
                Link("IMDb Link", destination: url)
                    .font(Theme.Fonts.body(16, weight: .bold))
                    .foregroundStyle(Theme.Colors.link)
                    .underline()
            }
        }

        progress(for: title)

        if viewModel.fromTonight {
            Button("Pick another") { pickAnother() }
                .buttonStyle(.pill(.primary, fontSize: 15, height: 50))
                .disabled(tonight.matches.count < 2)
        }
    }

    private func location(for title: OwnedTitle) -> some View {
        VStack(spacing: 6) {
            FlowLayout(spacing: 6) {
                Text("Format:")
                    .font(Theme.Fonts.body(16, weight: .bold))
                TagView(text: title.format.locationLabel, style: title.format.tagStyle, systemImage: title.format.systemImage)
                if let service = title.service {
                    TagView(text: service.rawValue, style: .neutral)
                }
            }
            Text(viewModel.locationNote)
                .font(Theme.Fonts.body(13, relativeTo: .footnote))
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// Watched and Reviewed check-offs that save right away, plus the inline
    /// star rating once reviewed.
    private func progress(for title: OwnedTitle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Your progress", size: 12)

            Toggle("Watched", isOn: Binding(get: { viewModel.isWatched }, set: viewModel.setWatched))
                .toggleStyle(.checkRow(detail: viewModel.watchedLabel))
                .confirmationDialog(
                    "Remove all \(title.watchCount) watches of \(title.title)?",
                    isPresented: $viewModel.isConfirmingWatchClear,
                    titleVisibility: .visible
                ) {
                    Button("Remove watch history", role: .destructive) { viewModel.confirmWatchClear() }
                } message: {
                    Text("To remove just one watch, tap it in the watch history.")
                }

            watchHistory(for: title)

            Toggle("Reviewed", isOn: Binding(get: { viewModel.isReviewed }, set: viewModel.setReviewed))
                .toggleStyle(.checkRow(detail: viewModel.isReviewed ? "Tap the stars to change your rating" : "Not reviewed yet"))
                .confirmationDialog(
                    "Remove your review of \(title.title)?",
                    isPresented: $viewModel.isConfirmingReviewRemoval,
                    titleVisibility: .visible
                ) {
                    Button("Remove review", role: .destructive) { viewModel.confirmReviewRemoval() }
                } message: {
                    Text("What you wrote will be deleted.")
                }

            if let review = title.review {
                VStack(alignment: .leading, spacing: 10) {
                    HalfStarPicker(rating: Binding(get: { viewModel.rating }, set: viewModel.setRating), size: 30)
                        .accessibilityIdentifier("detail.rating")
                    if !review.text.isEmpty {
                        Text(review.text)
                            .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                            .lineSpacing(2)
                            .lineLimit(3)
                    }
                    FlowLayout(spacing: 16) {
                        Button(review.text.isEmpty ? "Add a note" : "Edit note") {
                            viewModel.isWritingNote = true
                        }
                        Button("See all reviews") {
                            router.push(.reviews(highlighting: title.persistentModelID))
                        }
                    }
                    .font(Theme.Fonts.body(14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.link)
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.25), value: title.isReviewed)
    }

    // MARK: - Watch history, tags, and place

    /// "3rd watch · Oct 21, 2026" rows, newest first. Tap one to edit or delete it.
    @ViewBuilder
    private func watchHistory(for title: OwnedTitle) -> some View {
        if title.isWatched {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.watchRows) { row in
                    Button {
                        viewModel.startEditing(row.watch)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(row.label) · \(row.watch.date.displayText)")
                                    .font(Theme.Fonts.body(15, weight: .semibold))
                                if !row.watch.note.isEmpty {
                                    Text(row.watch.note)
                                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 40)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit or delete this watch")
                }
            }
            .padding(.horizontal, 4)
        }
        Button {
            viewModel.startLoggingWatch()
        } label: {
            Label(title.isWatched ? "Log another watch" : "Log a watch with a date", systemImage: "plus.circle")
        }
        .font(Theme.Fonts.body(14, weight: .semibold))
        .foregroundStyle(Theme.Colors.link)
        .padding(.horizontal, 4)
    }

    /// The title's tags, with a button to change them.
    private func tags(for title: OwnedTitle) -> some View {
        FlowLayout(spacing: 6) {
            Text("Tags:")
                .font(Theme.Fonts.body(16, weight: .bold))
            ForEach(title.sortedTags) { tag in
                UserTagChip(tag: tag)
            }
            Button(title.tags.isEmpty ? "Add tag" : "Edit") { viewModel.isPickingTags = true }
                .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 14, height: 32, fullWidth: false))
                .accessibilityLabel(title.tags.isEmpty ? "Add tag" : "Edit tags")
        }
    }

    /// Where a disc physically is, with Move and (when loaned) Mark returned.
    @ViewBuilder
    private func place(for title: OwnedTitle) -> some View {
        if let place = TitleDetailViewModel.placeText(for: title) {
            FlowLayout(spacing: 8) {
                Text("Where it is:")
                    .font(Theme.Fonts.body(16, weight: .bold))
                TagView(
                    text: place, style: title.isLoanedOut ? .outline : .neutral,
                    systemImage: title.isLoanedOut ? "person.fill" : "mappin")
                Button("Move") { viewModel.isMovingDisc = true }
                    .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 14, height: 32, fullWidth: false))
                    .accessibilityLabel("Move this disc")
                if title.isLoanedOut {
                    Button("Mark returned") { viewModel.markReturned() }
                        .buttonStyle(.pill(.primary, typeface: .body, fontSize: 14, height: 32, fullWidth: false))
                }
            }
        }
    }

    // MARK: - Actions

    /// Swaps this screen for another random Tonight match.
    private func pickAnother() {
        guard let next = tonight.pick(excluding: viewModel.titleID) else { return }
        router.replaceTop(with: .titleDetail(next, fromTonight: true))
    }
}
