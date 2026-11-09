//
//  TitleDetailView.swift
//  MovieCollection
//
//  Purpose: One title's detail screen: poster, format, where a disc is (with
//  Move and Mark returned), film info, tags, trailer and IMDb links, watch
//  history, review, who in the family has seen it, and for Streaming titles
//  "Own it instead", plus Edit. From Tonight it also
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
                WatchSheet(titleName: title.title, watch: watch, family: viewModel.appModel.familyMembers) { date, note, viewers in
                    viewModel.saveWatch(date: date, note: note, viewers: viewers)
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
                MoveDiscSheet(title: title, locations: viewModel.appModel.locations) { location, borrower, date, dueBack in
                    viewModel.appModel.move(title, to: location, loanedTo: borrower, on: date, dueBack: dueBack)
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

        if let genreAndRuntime = viewModel.genreAndRuntime {
            Text(genreAndRuntime)
                .font(Theme.Fonts.body(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }

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
        family(for: title)

        if viewModel.showsOwnItInstead {
            OwnItInsteadCard(title: title, state: viewModel.ownItState) {
                viewModel.startEditing()
            }
            // Looks again if the title's format, service, or catalog match changes.
            .task(id: "\(title.format.rawValue)-\(title.catalogID ?? 0)") {
                await viewModel.loadOwnItInstead()
            }
        }

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

    // MARK: - Family

    /// One row per family member: a seen check, their last watch, and their
    /// own stars. Hidden until the user adds someone in Settings › Family.
    @ViewBuilder
    private func family(for title: OwnedTitle) -> some View {
        if let summary = viewModel.familySummary {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Family", size: 12)
                Text(summary)
                    .font(Theme.Fonts.body(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .accessibilityIdentifier("detail.familySummary")

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.familyRows) { row in
                        familyRow(row)
                    }
                }
            }
            .confirmationDialog(
                "Mark \(viewModel.confirmingUnseen?.name ?? "them") as not seen?",
                isPresented: Binding(
                    get: { viewModel.confirmingUnseen != nil },
                    set: { if !$0 { viewModel.confirmingUnseen = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Not seen", role: .destructive) { viewModel.confirmUnseen() }
            } message: {
                Text(viewModel.unseenMessage)
            }
        }
    }

    private func familyRow(_ row: TitleDetailViewModel.FamilyRow) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                viewModel.setSeen(!row.hasSeen, by: row.member)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: row.hasSeen ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(row.hasSeen ? Theme.Colors.action : Theme.Colors.textMuted)
                    FamilyAvatar(member: row.member, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.member.name)
                            .font(Theme.Fonts.body(15, weight: .semibold))
                        Text(row.detail)
                            .font(Theme.Fonts.body(12, relativeTo: .caption))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(row.member.name), \(row.detail)")
            .accessibilityValue(row.hasSeen ? "Seen" : "Not seen")
            .accessibilityHint(row.hasSeen ? "Marks as not seen" : "Marks as seen")
            .accessibilityAddTraits(.isToggle)

            Spacer(minLength: 4)

            // Their own stars. Rating it also marks it seen.
            HalfStarPicker(
                rating: Binding(get: { row.rating ?? 0 }, set: { viewModel.setFamilyRating($0, by: row.member) }),
                size: 17,
                spacing: 3,
                accessibilityName: "\(row.member.name)'s rating"
            )
            .contextMenu {
                if row.rating != nil {
                    Button("Clear \(row.member.name)'s rating", systemImage: "xmark") {
                        viewModel.setFamilyRating(nil, by: row.member)
                    }
                }
            }
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 4)
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
                                if let viewers = TitleDetailViewModel.viewersText(for: row.watch) {
                                    Text(viewers)
                                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
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
                if let due = TitleDetailViewModel.dueText(for: title) {
                    TagView(text: due, style: title.isLoanOverdue ? .main : .neutral, systemImage: "bell")
                }
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
