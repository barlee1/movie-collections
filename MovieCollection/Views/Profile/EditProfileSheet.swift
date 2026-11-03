//
//  EditProfileSheet.swift
//  MovieCollection
//
//  Purpose: Change the user's name and photo. A draft until Save, so Cancel
//  leaves the profile as it was.
//  Used in: ProfileView.
//

import PhotosUI
import SwiftUI

struct EditProfileSheet: View {
    /// Called with the edited profile when Save is tapped.
    let onSave: (UserProfile) -> Void
    private let original: UserProfile

    @State private var name: String
    @State private var photoData: Data?
    /// The sample profile's asset photo, shown until a photo is picked or removed.
    @State private var photoAssetName: String?
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoError = false
    @Environment(\.dismiss) private var dismiss

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.onSave = onSave
        original = profile
        _name = State(initialValue: profile.name)
        _photoData = State(initialValue: profile.photoData)
        _photoAssetName = State(initialValue: profile.photoAssetName)
    }

    private var hasPhoto: Bool { photoData != nil || photoAssetName != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 18) {
                        ProfileAvatar(name: name, photoData: photoData, photoAssetName: photoAssetName, size: 84)
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                                Text(hasPhoto ? "Change photo" : "Add a photo")
                            }
                            .buttonStyle(.pill(.secondary, fontSize: 15, height: 38, fullWidth: false))
                            if hasPhoto {
                                Button("Remove photo", role: .destructive) {
                                    photoData = nil
                                    photoAssetName = nil
                                }
                                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                                .tint(Theme.Colors.error)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Your name", size: 12)
                        TextField("Your name", text: $name)
                            .pillField()
                            .textContentType(.name)
                            .accessibilityIdentifier("editProfile.name")
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 16)
            }
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var edited = original
                        edited.name = name
                        edited.photoData = photoData
                        edited.photoAssetName = photoAssetName
                        onSave(edited)
                        dismiss()
                    }
                    .disabled(name.trimmed.isEmpty)
                }
            }
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                        let prepared = ProfilePhoto.prepared(from: data)
                    {
                        photoData = prepared
                        photoAssetName = nil
                    } else {
                        photoError = true
                    }
                    pickedPhoto = nil
                }
            }
            .alert("Couldn't use that photo", isPresented: $photoError) {
                Button("OK", role: .cancel) {}
            }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    Text("Profile")
        .sheet(isPresented: .constant(true)) {
            EditProfileSheet(profile: .sample) { _ in }
        }
}
