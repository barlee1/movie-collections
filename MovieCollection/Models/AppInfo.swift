//
//  AppInfo.swift
//  MovieCollection
//
//  Purpose: Facts about the app shown in Profile › About: version, feedback
//  and privacy links, and the credit TMDB's terms require.
//  Used in: ProfileView.
//

import Foundation

nonisolated enum AppInfo {
    /// Where PRIVACY.md is published. Set this once it's hosted (for example
    /// on GitHub Pages); the About section hides the link until then.
    static let privacyPolicyURL: URL? = nil

    /// Where "Send feedback" emails go. Set this to your beta feedback
    /// address; the About section hides the link until then. TestFlight's
    /// own screenshot feedback works either way.
    static let feedbackEmail: String? = nil

    /// A pre-addressed feedback email with the version filled in.
    static var feedbackURL: URL? {
        guard let feedbackEmail else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Rewind Club feedback (\(versionText))")]
        return components.url
    }

    /// TMDB's required attribution wording.
    static let tmdbCredit = "This product uses the TMDB API but is not endorsed or certified by TMDB."
    static let tmdbURL = URL(string: "https://www.themoviedb.org")
    /// Required wherever TMDB's where-to-buy data is shown.
    static let justWatchCredit = "Where-to-buy data from JustWatch."
    static let justWatchURL = URL(string: "https://www.justwatch.com")

    /// e.g. "Version 1.0 (3)"
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
