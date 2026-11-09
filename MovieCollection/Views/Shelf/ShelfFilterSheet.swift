//
//  ShelfFilterSheet.swift
//  MovieCollection
//
//  Purpose: The Shelf's filter sheet: chips for format, service, film
//  rating, where a disc is (like Loaned out), tags, and family members who haven't seen it. Search text lives in
//  the search field; this is for narrowing by where and how you have a
//  title. Results update live behind the sheet.
//  Used in: ShelfView (the Filter button).
//

import SwiftUI

struct ShelfFilterSheet: View {
    @Bindable var viewModel: ShelfViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    chipGroup("Format", options: MediaFormat.allCases, label: \.rawValue, selection: $viewModel.filters.formats)
                    if !viewModel.serviceOptions.isEmpty {
                        chipGroup("Service", options: viewModel.serviceOptions, label: \.rawValue, selection: $viewModel.filters.services)
                    }
                    if !viewModel.ratingOptions.isEmpty {
                        chipGroup("Film rating", options: viewModel.ratingOptions, label: \.label, selection: $viewModel.filters.ratings)
                    }
                    if !viewModel.locationOptions.isEmpty {
                        idChipGroup("Where it is", options: viewModel.locationOptions.map { ($0.id, $0.name) }, selection: $viewModel.filters.locationIDs)
                    }
                    if !viewModel.tagOptions.isEmpty {
                        idChipGroup("Tags", options: viewModel.tagOptions.map { ($0.id, $0.name) }, selection: $viewModel.filters.tagIDs)
                    }
                    if viewModel.appModel.hasFamily {
                        notSeenByGroup
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(viewModel.showResultsLabel) { dismiss() }
                    .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 48))
                    .padding(.horizontal, Theme.Spacing.page)
                    .padding(.vertical, 12)
            }
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { viewModel.clearFilters() }
                        .disabled(viewModel.filters.activeCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.medium, .large])
    }

    /// Family members to find what they haven't seen. Picking several shows
    /// titles none of them have seen.
    private var notSeenByGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Not seen by", size: 12)
            FlowLayout(spacing: 8) {
                if let you = viewModel.appModel.familyYou {
                    FamilyMemberChip(you: you, isOn: viewModel.filters.notSeenByYou) {
                        viewModel.filters.notSeenByYou.toggle()
                    }
                }
                ForEach(viewModel.appModel.familyMembers) { member in
                    FamilyMemberChip(member: member, isOn: viewModel.filters.notSeenByIDs.contains(member.id)) {
                        viewModel.filters.notSeenByIDs.toggle(member.id)
                    }
                }
            }
        }
    }

    /// Chips for saved things (locations, tags) picked by ID.
    private func idChipGroup(_ title: String, options: [(id: UUID, name: String)], selection: Binding<Set<UUID>>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title, size: 12)
            FlowLayout {
                ForEach(options, id: \.id) { option in
                    ChipButton(label: option.name, isOn: selection.wrappedValue.contains(option.id), size: .small) {
                        selection.wrappedValue.toggle(option.id)
                    }
                }
            }
        }
    }

    private func chipGroup<Option: Hashable>(
        _ title: String,
        options: [Option],
        label: KeyPath<Option, String>,
        selection: Binding<Set<Option>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title, size: 12)
            FlowLayout {
                ForEach(options, id: \.self) { option in
                    ChipButton(label: option[keyPath: label], isOn: selection.wrappedValue.contains(option), size: .small) {
                        selection.wrappedValue.toggle(option)
                    }
                }
            }
        }
    }
}
