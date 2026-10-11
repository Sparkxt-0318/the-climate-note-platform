import Foundation

enum AppConfig {
    static var apiBaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "ClimateNoteAPIBaseURL") as? String,
            let url = URL(string: value)
        else { return URL(string: "https://the-climate-note.vercel.app")! }
        return url
    }

    static var privacyPolicyURL: URL {
        apiBaseURL.appending(path: "/privacy")
    }

    /// Optional Pixabay key used only to fill missing published covers.
    static var pixabayAPIKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PixabayAPIKey") as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }

    /// The app currently relies on Apple's standard licensed-application EULA.
    /// Replace this only after a project-specific agreement has completed legal review.
    static var termsOfServiceURL: URL {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }

    static var supportURL: URL {
        apiBaseURL.appending(path: "/support")
    }

    static var aboutURL: URL {
        apiBaseURL.appending(path: "/about")
    }

    static func articleURL(slug: String) -> URL {
        apiBaseURL.appending(path: "/articles/\(slug)")
    }
}
