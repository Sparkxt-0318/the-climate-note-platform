import SwiftUI

/// A private, directional summary. It only includes completed actions and
/// supported published factors; it never treats a reflection as a completion.
struct PersonalImpactSummaryView: View {
    let summary: PersonalImpactSummary
    var title = "Your impact"
    var showsTitle = true
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            if showsTitle, !title.isEmpty {
                Text(title).climateDisplay(27, relativeTo: .title2)
            }

            if compact {
                HStack(alignment: .top, spacing: 0) {
                    metricColumn(value: "\(summary.completedActionCount)", label: summary.completedActionCount == 1 ? "action" : "actions")
                    metricRule
                    metricColumn(value: formatted(summary.estimatedKgCO2e), label: "kg CO₂e")
                    metricRule
                    metricColumn(value: formatted(summary.estimatedKgWaste), label: "kg waste")
                }
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: ClimateLayout.compact), count: 3),
                    spacing: ClimateLayout.compact
                ) {
                    metricCard(value: "\(summary.completedActionCount)", label: summary.completedActionCount == 1 ? "action done" : "actions done")
                    metricCard(value: formatted(summary.estimatedKgCO2e), label: "kg CO₂e est.")
                    metricCard(value: formatted(summary.estimatedKgWaste), label: "kg waste est.")
                }
                Text("Figures use reported completions and published factors. They are directional estimates, not verified measurements.")
                    .font(.footnote)
                    .foregroundStyle(Color.climateMuted)
                    .lineSpacing(2)
                DisclosureGroup("How we estimate this") {
                    Text(methodologyText)
                        .font(.footnote)
                        .foregroundStyle(Color.climateMuted)
                        .lineSpacing(3)
                        .padding(.top, ClimateLayout.compact)
                }
                .font(.subheadline.weight(.semibold))
                .tint(Color.climateSage)
            }
        }
        .foregroundStyle(Color.climateInk)
        .accessibilityElement(children: .contain)
    }

    private var metricRule: some View {
        Rectangle()
            .fill(Color.climateRule)
            .frame(width: 1, height: 42)
            .padding(.horizontal, ClimateLayout.compact)
    }

    private func metricColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).climateDisplay(27, relativeTo: .title2).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.footnote).foregroundStyle(Color.climateMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private func metricCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.footnote).foregroundStyle(Color.climateMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClimateLayout.element)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.control))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.control).stroke(Color.climateRule, lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var methodologyText: String {
        var values = [
            "Completed actions count every finished action in My Note.",
            "CO₂e uses supported suggested-action factors when a completion includes one.",
            "Waste kilograms come from reported recycling inputs.",
        ]
        if !summary.factorVersions.isEmpty { values.append("Factor versions: \(summary.factorVersions.joined(separator: ", ")).") }
        values.append("These are directional estimates based on self-reported completions, not audited footprints.")
        return values.joined(separator: " ")
    }
}

struct CommunityImpactLink: View {
    var body: some View {
        NavigationLink { CommunityImpactView() } label: {
            HStack(spacing: ClimateLayout.element) {
                Image(systemName: "person.2")
                    .font(.title3)
                    .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                    .background(Color.climateSage.opacity(0.16), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("See community impact").font(.headline)
                    Text("Anonymous estimates from contributors").font(.footnote).foregroundStyle(Color.climateMuted)
                }
                Spacer(minLength: ClimateLayout.compact)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.climateMuted).accessibilityHidden(true)
            }
            .foregroundStyle(Color.climateInk)
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens anonymous community impact estimates")
    }
}

struct CommunityImpactView: View {
    @EnvironmentObject private var impactStore: ImpactStore

    var body: some View {
        ScrollView {
            CommunityImpactScreenContent(presentation: impactStore.communityPresentation, onRetry: impactStore.retryCommunity)
                .climateContentWidth()
                .padding(.top, ClimateLayout.section)
                .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .foregroundStyle(Color.climateInk)
        .tint(Color.climateSage)
        .navigationTitle("Community impact")
        .navigationBarTitleDisplayMode(.inline)
        .task { impactStore.start() }
    }
}

/// This public content composition provides every aggregate state without
/// exposing a contributor count before the server privacy threshold is met.
struct CommunityImpactScreenContent: View {
    let presentation: CommunityImpactPresentation
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.section) {
            VStack(alignment: .leading, spacing: 8) {
                Text("COMMUNITY")
                    .climateMetadata(weight: .bold).tracking(1.2).foregroundStyle(Color.climateSage)
                Text("Community impact")
                    .climateDisplay(38, relativeTo: .largeTitle)
                Text("Anonymous estimates from contributors who chose to participate.")
                    .font(.body).foregroundStyle(Color.climateMuted).lineSpacing(4)
            }
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch presentation {
        case .loading:
            HStack(spacing: ClimateLayout.compact) {
                ProgressView().tint(Color.climateSage)
                Text("Loading community impact…").font(.body).foregroundStyle(Color.climateMuted)
            }
            .frame(minHeight: ClimateLayout.minimumTarget)
            .accessibilityElement(children: .combine)
        case .threshold(let document):
            thresholdContent(document)
        case .populated(let document, let isStale):
            populatedContent(document, isStale: isStale)
        case .error(let message):
            VStack(alignment: .leading, spacing: ClimateLayout.element) {
                ImpactStatus(message: message, symbol: "exclamationmark.triangle.fill", color: .red)
                Button("Try again", action: onRetry).buttonStyle(ClimatePrimaryButtonStyle())
            }
        }
    }

    private func thresholdContent(_ document: CommunityImpactDocument) -> some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            Label("The community total is taking shape", systemImage: "person.2")
                .font(.headline)
            Text("It will appear after at least \(document.minimumContributors) people choose to contribute eligible completed actions.")
                .font(.body).foregroundStyle(Color.climateMuted).lineSpacing(4)
            methodology(document.methodology)
        }
        .impactSurface()
    }

    private func populatedContent(_ document: CommunityImpactDocument, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            Text("Together, contributors estimate about").font(.body).foregroundStyle(Color.climateMuted)
            Text(communityMetric(document.estimatedKgCO2e ?? 0))
                .climateDisplay(44, relativeTo: .largeTitle)
                .accessibilityLabel("Estimated \(communityMetric(document.estimatedKgCO2e ?? 0)) from reported completions")
            Text("from \(document.eligibleActionCount ?? 0) eligible reported \((document.eligibleActionCount ?? 0) == 1 ? "completion" : "completions")")
                .font(.body).foregroundStyle(Color.climateMuted)
            if let updatedAt = document.updatedAt {
                Text("Last updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(Color.climateMuted)
            }
            if isStale {
                ImpactStatus(message: "This is the most recent saved community estimate. We’ll refresh it when a newer total is available.", symbol: "clock.arrow.circlepath", color: Color.climateSage)
            }
            methodology(document.methodology)
        }
        .impactSurface()
    }

    private func methodology(_ methodology: CommunityImpactMethodology) -> some View {
        DisclosureGroup("How we estimate this") {
            VStack(alignment: .leading, spacing: ClimateLayout.compact) {
                Text(methodology.description)
                if !methodology.factorVersions.isEmpty { Text("Factor versions: \(methodology.factorVersions.joined(separator: ", "))") }
            }
            .font(.footnote).foregroundStyle(Color.climateMuted).lineSpacing(3).padding(.top, ClimateLayout.compact)
        }
        .font(.subheadline.weight(.semibold))
        .tint(Color.climateSage)
    }

    private func communityMetric(_ kilograms: Double) -> String {
        kilograms >= 1_000
            ? "\((kilograms / 1_000).formatted(.number.precision(.fractionLength(0...1)))) t CO₂e"
            : "\(kilograms.formatted(.number.precision(.fractionLength(0...1)))) kg CO₂e"
    }
}

private struct ImpactStatus: View {
    let message: String
    let symbol: String
    let color: Color
    var body: some View {
        Label(message, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
            .padding(.horizontal, ClimateLayout.element)
            .background(color.opacity(0.13), in: .rect(cornerRadius: ClimateRadius.control))
    }
}

private extension View {
    func impactSurface() -> some View {
        padding(ClimateLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.climateSurfaceRaised.opacity(0.90), Color.climateSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: ClimateRadius.card)
            )
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateSage.opacity(0.20), lineWidth: 1) }
            .shadow(color: Color.black.opacity(0.22), radius: 24, y: 14)
    }
}
