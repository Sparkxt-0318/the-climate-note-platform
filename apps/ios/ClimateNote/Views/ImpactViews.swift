import SwiftUI

/// A shared personal summary used in both My Note and Account. It only uses
/// completed action logs and only renders figures for supported factors.
struct PersonalImpactSummaryView: View {
    let summary: PersonalImpactSummary
    var title = "Your impact"
    var showsTitle = true
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            if showsTitle, !title.isEmpty {
                ClimateSectionHeader(title: title)
            }

            if compact {
                HStack(alignment: .top, spacing: 0) {
                    metricColumn(
                        value: "\(summary.completedActionCount)",
                        label: summary.completedActionCount == 1 ? "action" : "actions"
                    )
                    metricRule
                    metricColumn(value: formatted(summary.estimatedKgCO2e), label: "kg CO₂e")
                    metricRule
                    metricColumn(value: formatted(summary.estimatedKgWaste), label: "kg waste")
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: ClimateTheme.Spacing.small),
                        GridItem(.flexible(), spacing: ClimateTheme.Spacing.small),
                        GridItem(.flexible(), spacing: ClimateTheme.Spacing.small),
                    ],
                    spacing: ClimateTheme.Spacing.small
                ) {
                    metricCard(
                        value: "\(summary.completedActionCount)",
                        label: summary.completedActionCount == 1 ? "action done" : "actions done"
                    )
                    metricCard(value: formatted(summary.estimatedKgCO2e), label: "kg CO₂e est.")
                    metricCard(value: formatted(summary.estimatedKgWaste), label: "kg waste est.")
                }

                Text("Figures use reported completions and published factors. They are directional estimates, not verified measurements.")
                    .font(ClimateTheme.Typography.caption)
                    .foregroundStyle(ClimateTheme.tertiaryInk)
                    .lineSpacing(2)

                DisclosureGroup("How we estimate this") {
                    Text(methodologyText)
                        .font(ClimateTheme.Typography.subheadline)
                        .foregroundStyle(ClimateTheme.secondaryInk)
                        .lineSpacing(3)
                        .padding(.top, ClimateTheme.Spacing.small)
                }
                .font(ClimateTheme.Typography.subheadlineStrong)
                .foregroundStyle(ClimateTheme.ink)
                .tint(ClimateTheme.accent)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var metricRule: some View {
        Rectangle()
            .fill(ClimateTheme.divider.opacity(0.55))
            .frame(width: 1, height: 36)
            .padding(.horizontal, ClimateTheme.Spacing.small)
    }

    private func metricColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(ClimateTheme.Typography.sectionTitle)
                .foregroundStyle(ClimateTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(ClimateTheme.Typography.caption)
                .foregroundStyle(ClimateTheme.secondaryInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private func metricCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(ClimateTheme.Typography.headline)
                .foregroundStyle(ClimateTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(ClimateTheme.Typography.caption)
                .foregroundStyle(ClimateTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClimateTheme.Spacing.compact)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: ClimateTheme.Radius.medium)
                .stroke(ClimateTheme.divider.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var methodologyText: String {
        var lines = [
            "Completed actions count every finished action in My Note.",
            "CO₂e uses supported suggested-action factors when a completion includes one.",
            "Waste kilograms come from reported recycling inputs (for example pounds converted to kilograms).",
        ]
        if !summary.factorVersions.isEmpty {
            lines.append("Factor versions: \(summary.factorVersions.joined(separator: ", ")).")
        }
        lines.append("These are directional estimates based on self-reported completions—not audited footprints.")
        return lines.joined(separator: " ")
    }
}

struct CommunityImpactLink: View {
    var body: some View {
        NavigationLink {
            CommunityImpactView()
        } label: {
            HStack(spacing: ClimateTheme.Spacing.compact) {
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) {
                    Text("See community impact")
                        .font(ClimateTheme.Typography.bodyStrong)
                    Text("Anonymous estimates from contributors")
                        .font(ClimateTheme.Typography.subheadline)
                        .foregroundStyle(ClimateTheme.secondaryInk)
                }
                Spacer(minLength: ClimateTheme.Spacing.small)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClimateTheme.tertiaryInk)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(ClimateTheme.ink)
            .frame(minHeight: ClimateTheme.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(ClimateArticleLinkStyle())
        .accessibilityHint("Opens anonymous community impact estimates")
    }
}

struct CommunityImpactView: View {
    @EnvironmentObject private var impactStore: ImpactStore

    var body: some View {
        ScrollView {
            CommunityImpactScreenContent(
                presentation: impactStore.communityPresentation,
                onRetry: impactStore.retryCommunity
            )
            .padding(ClimateTheme.Spacing.large)
            .padding(.bottom, ClimateTheme.Spacing.hero)
            .frame(maxWidth: ClimateTheme.ContentWidth.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { ClimateBackdrop() }
        .navigationTitle("Community impact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { ClimateWordmark() }
        }
        .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(ClimateTheme.accent)
        .task { impactStore.start() }
    }
}

/// The production content composition also backs the deterministic native QA scenes.
struct CommunityImpactScreenContent: View {
    let presentation: CommunityImpactPresentation
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xLarge) {
            ClimatePageHeader(
                title: "Community impact",
                subtitle: "Anonymous estimates from contributors who chose to participate."
            )
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch presentation {
        case .loading:
            HStack(spacing: ClimateTheme.Spacing.small) {
                ProgressView().tint(ClimateTheme.accent)
                Text("Loading community impact…")
                    .font(ClimateTheme.Typography.callout)
                    .foregroundStyle(ClimateTheme.secondaryInk)
            }
            .accessibilityElement(children: .combine)

        case .threshold(let document):
            thresholdContent(document)

        case .populated(let document, let isStale):
            populatedContent(document, isStale: isStale)

        case .error(let message):
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
                ClimateInlineStatus(message: message, kind: .error)
                Button("Try again", action: onRetry)
                    .buttonStyle(ClimateSecondaryButtonStyle())
            }
        }
    }

    private func thresholdContent(_ document: CommunityImpactDocument) -> some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            Label("The community total is taking shape", systemImage: "person.2")
                .font(ClimateTheme.Typography.headline)
                .foregroundStyle(ClimateTheme.ink)
            Text("It will appear after at least \(document.minimumContributors) people choose to contribute eligible completed actions.")
                .font(ClimateTheme.Typography.body)
                .foregroundStyle(ClimateTheme.secondaryInk)
                .lineSpacing(4)
            methodology(document.methodology)
        }
        .padding(ClimateTheme.Spacing.large)
        .climateSheet()
    }

    private func populatedContent(_ document: CommunityImpactDocument, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            Text("Together, contributors estimate about")
                .font(ClimateTheme.Typography.subheadline)
                .foregroundStyle(ClimateTheme.secondaryInk)

            Text(communityMetric(document.estimatedKgCO2e ?? 0))
                .font(ClimateTheme.Typography.metric)
                .foregroundStyle(ClimateTheme.ink)
                .accessibilityLabel("Estimated \(communityMetric(document.estimatedKgCO2e ?? 0)) from reported completions")

            Text("from \(document.eligibleActionCount ?? 0) eligible reported \((document.eligibleActionCount ?? 0) == 1 ? "completion" : "completions")")
                .font(ClimateTheme.Typography.body)
                .foregroundStyle(ClimateTheme.secondaryInk)

            if let updatedAt = document.updatedAt {
                Text("Last updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(ClimateTheme.Typography.metadata)
                    .foregroundStyle(ClimateTheme.tertiaryInk)
            }

            if isStale {
                ClimateInlineStatus(
                    message: "This is the most recent saved community estimate. We’ll refresh it when a newer total is available.",
                    kind: .warning
                )
            }

            methodology(document.methodology)
        }
        .padding(ClimateTheme.Spacing.large)
        .climateSheet()
    }

    private func methodology(_ methodology: CommunityImpactMethodology) -> some View {
        DisclosureGroup("How we estimate this") {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                Text(methodology.description)
                if !methodology.factorVersions.isEmpty {
                    Text("Factor versions: \(methodology.factorVersions.joined(separator: ", "))")
                }
            }
            .font(ClimateTheme.Typography.subheadline)
            .foregroundStyle(ClimateTheme.secondaryInk)
            .lineSpacing(3)
            .padding(.top, ClimateTheme.Spacing.small)
        }
        .font(ClimateTheme.Typography.subheadlineStrong)
        .foregroundStyle(ClimateTheme.ink)
        .tint(ClimateTheme.accent)
    }

    private func communityMetric(_ kilograms: Double) -> String {
        if kilograms >= 1_000 {
            return "\((kilograms / 1_000).formatted(.number.precision(.fractionLength(0...1)))) t CO₂e"
        }
        return "\(kilograms.formatted(.number.precision(.fractionLength(0...1)))) kg CO₂e"
    }
}
