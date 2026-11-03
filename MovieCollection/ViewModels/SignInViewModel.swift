//
//  SignInViewModel.swift
//  MovieCollection
//
//  Purpose: Signing in after trying the app as a guest: name and optional
//  photo, the streaming services they pay for, and (only if the sample
//  movies are on the shelf) whether to keep them. Nothing is saved until
//  the last step, and everything added while trying the app stays.
//  There's no account server yet, so the profile is saved on the phone.
//  Used in: SignInView (Profile and Friends show it to guests).
//

import Foundation
import Observation

@Observable
final class SignInViewModel {

    enum Step: Int {
        case aboutYou
        case services
        case shelf
    }

    /// The steps for this user. The sample-movie question only appears if
    /// the sample movies were loaded.
    let steps: [Step]
    private(set) var step: Step = .aboutYou
    var name = ""
    /// The picked photo, already shrunk for saving.
    private(set) var photoData: Data?
    var subscriptions: Set<StreamingService>
    var errorMessage: String?

    private let appModel: AppViewModel

    init(appModel: AppViewModel) {
        self.appModel = appModel
        steps = appModel.hasSampleTitles ? [.aboutYou, .services, .shelf] : [.aboutYou, .services]
        // Keep the services chosen as a guest (or saved by an early build).
        subscriptions = Set(appModel.suggestedSubscriptions)
    }

    // MARK: - Steps

    private var index: Int { steps.firstIndex(of: step) ?? 0 }

    var canContinue: Bool {
        switch step {
        case .aboutYou: !name.trimmed.isEmpty
        case .services, .shelf: true
        }
    }

    var isFirstStep: Bool { index == 0 }
    /// On the last step the bottom button signs in instead of continuing.
    var isLastStep: Bool { index == steps.count - 1 }

    /// e.g. "Step 2 of 3"
    var progressLabel: String { "Step \(index + 1) of \(steps.count)" }

    func next() {
        guard canContinue, index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    func back() {
        guard index > 0 else { return }
        step = steps[index - 1]
    }

    // MARK: - Photo

    func setPhoto(from data: Data) {
        guard let prepared = ProfilePhoto.prepared(from: data) else {
            errorMessage = "That file isn't a photo the app can use."
            return
        }
        photoData = prepared
    }

    func removePhoto() {
        photoData = nil
    }

    // MARK: - Finishing

    /// Saves the profile, keeping everything added while trying the app.
    /// - Parameter keepingSampleShelf: False removes the sample movies (and
    ///   anything written on them); titles the user added always stay.
    func signIn(keepingSampleShelf: Bool = true) {
        guard !name.trimmed.isEmpty else {
            step = .aboutYou
            return
        }
        let profile = UserProfile(
            name: name,
            photoData: photoData,
            subscriptions: Array(subscriptions)
        )
        appModel.finishSetup(with: profile, keepingSampleShelf: keepingSampleShelf)
    }
}
