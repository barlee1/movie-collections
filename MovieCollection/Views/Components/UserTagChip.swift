//
//  UserTagChip.swift
//  MovieCollection
//
//  Purpose: How the user's own tags look (a colored chip per tag), and the
//  sheet for choosing a title's tags or making a new one.
//  Used in: TitleDetailView, AddTitleView, EditTitleSheet, the flip-card back,
//  ShelfFilterSheet, TonightView, Settings › Tags.
//

import SwiftUI

/// The theme colors user tags can use, picked by `Tag.colorIndex`.
enum TagPalette {
    static var count: Int { Theme.Colors.tagColors.count }

    static func colors(_ index: Int) -> (fill: Color, text: Color) {
        let palette = Theme.Colors.tagColors
        return palette[((index % palette.count) + palette.count) % palette.count]
    }
}

/// One user tag, e.g. "Date night", in its color.
struct UserTagChip: View {
    let name: String
    let colorIndex: Int
    var isCompact = false

    init(tag: Tag, isCompact: Bool = false) {
        self.name = tag.name
        self.colorIndex = tag.colorIndex
        self.isCompact = isCompact
    }

    init(name: String, colorIndex: Int, isCompact: Bool = false) {
        self.name = name
        self.colorIndex = colorIndex
        self.isCompact = isCompact
    }

    var body: some View {
        let colors = TagPalette.colors(colorIndex)
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.system(size: isCompact ? 9 : 11, weight: .bold))
                .accessibilityHidden(true)
            Text(name)
                .font(Theme.Fonts.body(isCompact ? 12 : 13, weight: .semibold, relativeTo: .footnote))
                .lineLimit(1)
        }
        .foregroundStyle(colors.text)
        .padding(.vertical, isCompact ? 4 : 5)
        .padding(.horizontal, isCompact ? 9 : 11)
        .background(colors.fill, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tag: \(name)")
    }
}

/// Pick any number of tags for a title, or type a new one. A draft until Done.
struct TagPickerSheet: View {
    @Environment(AppViewModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    /// Called with the chosen tags when Done is tapped.
    let onDone: ([Tag]) -> Void

    @State private var selectedIDs: Set<UUID>
    @State private var newTagName = ""
    @FocusState private var isNewTagFocused: Bool

    init(selected: [Tag], onDone: @escaping ([Tag]) -> Void) {
        self.onDone = onDone
        _selectedIDs = State(initialValue: Set(selected.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        TextField("New tag, e.g. Date night", text: $newTagName)
                            .pillField()
                            .focused($isNewTagFocused)
                            .submitLabel(.done)
                            .onSubmit(createTag)
                            .accessibilityIdentifier("tagPicker.newTag")
                        Button("Add", action: createTag)
                            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 44, fullWidth: false))
                            .disabled(newTagName.cleanedTagName.isEmpty)
                    }

                    if appModel.tags.isEmpty {
                        Text("No tags yet. Make one above: \"Christmas\", \"Comfort movie\", \"Kids' favorites\"…")
                            .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.Colors.textMuted)
                    } else {
                        FlowLayout {
                            ForEach(appModel.tags) { tag in
                                tagToggle(tag)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 16)
            }
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // A typed tag that wasn't added yet still counts.
                        if !newTagName.cleanedTagName.isEmpty { createTag() }
                        onDone(appModel.tags.filter { selectedIDs.contains($0.id) })
                        dismiss()
                    }
                }
            }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.medium, .large])
    }

    private func tagToggle(_ tag: Tag) -> some View {
        let isOn = selectedIDs.contains(tag.id)
        return Button {
            selectedIDs.toggle(tag.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                UserTagChip(tag: tag)
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? Theme.Colors.action : Theme.Colors.textMuted)
        .accessibilityLabel(tag.name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Makes the typed tag (or finds an existing one with that name) and selects it.
    private func createTag() {
        guard let tag = appModel.findOrCreateTag(named: newTagName) else { return }
        selectedIDs.insert(tag.id)
        newTagName = ""
    }
}

#Preview {
    HStack {
        UserTagChip(name: "Christmas", colorIndex: 0)
        UserTagChip(name: "Date night", colorIndex: 2)
        UserTagChip(name: "Comfort", colorIndex: 4, isCompact: true)
    }
    .padding()
}
