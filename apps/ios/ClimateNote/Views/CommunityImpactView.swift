import SwiftUI

struct CommunityImpact: Decodable, Sendable {
    let schemaVersion: Int
    let completedActions: Int
    let estimatedKgCO2e: Double
    let estimatedActions: Int
    let updatedAt: String

    var isValid: Bool {
        schemaVersion == 1 && completedActions >= 0 && estimatedActions >= 0 &&
        estimatedActions <= completedActions && estimatedKgCO2e.isFinite && estimatedKgCO2e >= 0 && date != nil
    }

    var date: Date? { ISO8601DateFormatter().date(from: updatedAt) ?? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: updatedAt)
    }() }
}

struct CommunityImpactView: View {
    @State private var impact: CommunityImpact?
    @State private var loading = false
    @State private var failed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 48)).foregroundStyle(Color.climateSage)
                        .accessibilityHidden(true)
                    Text("Small actions. Shared progress.").font(.title.bold())
                    Text("Every completed climate note adds to what we do together.")
                        .foregroundStyle(.secondary)
                }
                if let impact {
                    metric(value: impact.completedActions.formatted(), title: "community actions completed", footnote: "All-time • self-reported completions")
                    if impact.estimatedActions > 0 {
                        metric(value: impact.estimatedKgCO2e.formatted(.number.precision(.fractionLength(0...2))) + " kg CO₂e",
                               title: "estimated emissions avoided",
                               footnote: "From \(impact.estimatedActions.formatted()) supported actions. This is an estimate, not a measured or verified reduction.")
                    } else {
                        Text("Every action matters. Carbon estimates will appear when completed actions have a supported calculation.")
                            .padding(22).background(.background, in: .rect(cornerRadius: 24))
                    }
                    if let date = impact.date {
                        Text("Updated \(date.formatted(date: .abbreviated, time: .shortened)). Totals refresh daily.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ShareLink(item: "Together, The Climate Note community has completed \(impact.completedActions.formatted()) climate actions (self-reported). Snapshot: \(impact.date?.formatted(date: .abbreviated, time: .omitted) ?? impact.updatedAt). Read a story and try one small action: \(AppConfig.apiBaseURL.absoluteString)") {
                        Label("Share our progress", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.bordered)
                } else if loading {
                    ProgressView("Loading community progress…").frame(maxWidth: .infinity).padding(30)
                }
                if failed {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Community totals are temporarily unavailable.", systemImage: "wifi.exclamationmark")
                        Text(impact == nil ? "Your own notes are still available in My Note. Please try again shortly." : "Showing the last totals loaded. Pull down to try again.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Try again") { Task { await refresh() } }.disabled(loading)
                    }.padding(22).background(.background, in: .rect(cornerRadius: 24))
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("What counts?").font(.headline)
                    Text("Actions marked as achieved, including your own actions. Plans alone do not count. Duplicate saves of the same article action completed on the same UTC day count once.")
                    Text("How we estimate").font(.headline).padding(.top, 6)
                    Text("Only actions linked to a supported impact factor receive a carbon estimate. Calculations use the article’s suggested quantity and U.S. EPA reference factors. They may not reflect your location or actual savings. Custom actions do not receive invented carbon values.")
                    Text("Your notes stay private").font(.headline).padding(.top, 6)
                    Text("Only combined totals are public. No names, personal activity, or reflection text are shown. Deleted action history leaves the totals at the next daily refresh.")
                    Link("Read our privacy policy", destination: AppConfig.privacyPolicyURL)
                }
                .font(.callout)
                .padding(22).background(.background, in: .rect(cornerRadius: 24))
            }.padding(18)
        }
        .navigationTitle("Our Impact")
        .background(Color.climateBackground)
        .refreshable { await refresh() }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    private func metric(value: String, title: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(value).font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color.climateSage).fixedSize(horizontal: false, vertical: true)
            Text(title).font(.headline)
            Text(footnote).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22).background(.background, in: .rect(cornerRadius: 24))
    }

    @MainActor private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: AppConfig.apiBaseURL.appending(path: "/api/impact/community"))
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let snapshot = try JSONDecoder().decode(CommunityImpact.self, from: data)
            guard snapshot.isValid else { throw URLError(.cannotParseResponse) }
            impact = snapshot
            failed = false
        } catch is CancellationError {
            // Disappearing views should not display a connectivity error.
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
