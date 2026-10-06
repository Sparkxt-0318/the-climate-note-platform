import Foundation

enum AppConfig {
    static var apiBaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "ClimateNoteAPIBaseURL") as? String,
            let url = URL(string: value)
        else { return URL(string: "https://the-climate-note.vercel.app")! }
        return url
    }

    /// Optional Pixabay key used to fill missing article covers at runtime.
    /// Set `PIXABAY_API_KEY` in the Xcode build settings / scheme environment.
    static var pixabayAPIKey: String? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "PixabayAPIKey") as? String
        else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") { return nil }
        return trimmed
    }

    static var privacyPolicyURL: URL {
        apiBaseURL.appending(path: "/privacy")
    }

    static var termsOfServiceURL: URL {
        apiBaseURL.appending(path: "/terms")
    }

    static var supportURL: URL {
        apiBaseURL.appending(path: "/support")
    }
}
