//
//  ManageTagsView.swift
//  MovieCollection
//
//  Purpose: Settings › Tags: every tag with how many titles use it. Add a
//  tag, or tap one to rename it, change its color, merge it into another
//  tag, or delete it. Renaming a tag to another tag's name merges them.
//  Used in: RootTabView (Route.manageTags), opened from Settings.
//

import SwiftUI

struct ManageTagsView: View {
    @Environment(AppViewModel.self) private var appModel
    @State private var newName = ""
    @State private var editing: Tag?

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    TextField("New tag, e.g. Comfort movie", text: $newName)
                        .font(Theme.Fonts.body(16))
                        .submitLabel(.done)
                        .onSubmit(add)
                        .accessibilityIdentifier("tags.newName")
                    Button("Add", action: add)
                        .font(Theme.Fonts.body(16, weight: .semibold))
                        .disabled(newName.cleanedTagName.isEmpty)
                }
            }

            Section {
                if appModel.tags.isEmpty {
                    Text("No tags yet. Add one above, or from a title's detail screen.")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                ForEach(appModel.tags) { tag in
                    Button {
                        editing = tag
                    } label: {
                        HStack {
                            UserTagChip(tag: tag)
                            Spacer()
                            let count = tag.titles.count
                            Text("\(count) \(count == 1 ? "title" : "titles")")
                                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                                .foregroundStyle(Theme.Colors.textMuted)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .accessibilityHidden(true)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Rename, recolor, merge, or delete")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background.ignoresSafeArea())
        .foregroundStyle(Theme.Colors.text)
        .tint(Theme.Colors.action)
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { tag in
            EditTagSheet(tag: tag)
        }
    }

    private func add() {
        if appModel.findOrCreateTag(named: newName) != nil { newName = "" }
    }
}

/// Rename, recolor, merge, or delete one tag.
private struct EditTagSheet: View {
    let tag: Tag
    @Environment(AppViewModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var colorIndex: Int
    @State private var mergeTarget: Tag?
    @State private var isConfirmingDelete = false

    init(tag: Tag) {
        self.tag = tag
        _name = State(initialValue: tag.name)
        _colorIndex = State(initialValue: tag.colorIndex)
    }

    private var otherTags: [Tag] { appModel.tags.filter { $0 !== tag } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    UserTagChip(name: name.cleanedTagName.isEmpty ? tag.name : name.cleanedTagName, colorIndex: colorIndex)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Name", size: 12)
                        TextField("Name", text: $name)
                            .pillField()
                        if let match = otherTags.first(where: { $0.name.lowercased() == name.cleanedTagName.lowercased() }) {
                            Text("\"\(match.name)\" already exists. Saving will merge the two.")
                                .font(Theme.Fonts.body(13, relativeTo: .footnote))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Color", size: 12)
                        HStack(spacing: 12) {
                            ForEach(0..<TagPalette.count, id: \.self) { index in
                                Button {
                                    colorIndex = index
                                } label: {
                                    Circle()
                                        .fill(TagPalette.colors(index).fill)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if colorIndex == index {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(TagPalette.colors(index).text)
                                            }
                                        }
                                        .overlay(Circle().strokeBorder(Theme.Colors.divider))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Color \(index + 1)")
                                .accessibilityAddTraits(colorIndex == index ? .isSelected : [])
                            }
                        }
                    }

                    if !otherTags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Merge into another tag", size: 12)
                            Text("Its titles get the other tag instead, and this one is deleted.")
                                .font(Theme.Fonts.body(13, relativeTo: .footnote))
                                .foregroundStyle(Theme.Colors.textMuted)
                            FlowLayout(spacing: 6) {
                                ForEach(otherTags) { other in
                                    Button {
                                        mergeTarget = other
                                    } label: {
                                        UserTagChip(tag: other)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Merge into this tag")
                                }
                            }
                        }
                    }

                    Button("Delete tag", role: .destructive) { isConfirmingDelete = true }
                        .font(Theme.Fonts.body(15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.error)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 16)
            }
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if colorIndex != tag.colorIndex { appModel.recolorTag(tag, colorIndex: colorIndex) }
                        if name.cleanedTagName != tag.name { appModel.renameTag(tag, to: name) }
                        dismiss()
                    }
                    .disabled(name.cleanedTagName.isEmpty)
                }
            }
            .confirmationDialog(
                "Merge \"\(tag.name)\" into \"\(mergeTarget?.name ?? "")\"?",
                isPresented: Binding(get: { mergeTarget != nil }, set: { if !$0 { mergeTarget = nil } }),
                titleVisibility: .visible
            ) {
                Button("Merge") {
                    if let mergeTarget { appModel.mergeTag(tag, into: mergeTarget) }
                    dismiss()
                }
            }
            .confirmationDialog("Delete \"\(tag.name)\"?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    appModel.deleteTag(tag)
                    dismiss()
                }
            } message: {
                let count = tag.titles.count
                Text(count == 0 ? "No titles use it." : "It comes off \(count) \(count == 1 ? "title" : "titles"). The titles stay on your shelf.")
            }
        }
        .tint(Theme.Colors.action)
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        ManageTagsView()
    }
    .environment(appModel)
    .task { await appModel.start() }
}
