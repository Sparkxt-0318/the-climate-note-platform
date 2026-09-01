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

    static var supportURL: URL {
        apiBaseURL.appending(path: "/support")
    }
}
