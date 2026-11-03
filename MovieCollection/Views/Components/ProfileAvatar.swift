//
//  ProfileAvatar.swift
//  MovieCollection
//
//  Purpose: The user's round profile photo with the design's highlight ring.
//  Shows their chosen photo, the sample profile's asset photo, or their
//  initials when there's no photo. Also shrinks picked photos for saving.
//  Used in: ProfileView, OnboardingView, EditProfileSheet.
//

import SwiftUI
import UIKit

struct ProfileAvatar: View {
    var name: String
    var photoData: Data?
    var photoAssetName: String?
    var size: CGFloat = 104

    var body: some View {
        photo
            .frame(width: size, height: size)
            .clipShape(Circle())
            .padding(size * 0.06)
            .background(Theme.Colors.highlight, in: Circle())
            .accessibilityElement()
            .accessibilityLabel(name.trimmed.isEmpty ? "Profile photo" : "Photo of \(name)")
    }

    @ViewBuilder
    private var photo: some View {
        if let photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .washed()
        } else if let photoAssetName {
            Image(photoAssetName)
                .resizable()
                .scaledToFill()
                .washed()
        } else {
            Text(UserProfile(name: name).initials)
                .font(Theme.Fonts.heading(size * 0.38, relativeTo: .largeTitle))
                .foregroundStyle(Theme.Colors.onHighlight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.tintMain)
        }
    }
}

extension ProfileAvatar {
    init(profile: UserProfile, size: CGFloat = 104) {
        self.init(name: profile.name, photoData: profile.photoData, photoAssetName: profile.photoAssetName, size: size)
    }
}

/// Prepares picked photos for saving with the profile.
nonisolated enum ProfilePhoto {
    /// The longest side of a saved photo, in pixels. Plenty for a 104pt circle.
    static let maxDimension: CGFloat = 400

    /// A small square-cropped JPEG, or nil if the data isn't an image.
    static func prepared(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let scale = min(1, maxDimension / side)
        let output = CGSize(width: side * scale, height: side * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: output, format: format)
        let resized = renderer.image { _ in
            // Center the crop on the middle of the photo.
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (output.width - drawSize.width) / 2, y: (output.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    HStack(spacing: 20) {
        ProfileAvatar(profile: .sample, size: 80)
        ProfileAvatar(name: "Sam Rivera", size: 80)
    }
    .padding()
}
