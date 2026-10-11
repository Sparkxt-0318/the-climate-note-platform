#if DEBUG
import Foundation
import SwiftUI

enum ScreenshotConfiguration {
    /// Fixture runs must never initialize production Firebase or notification
    /// services, even if a scene value is omitted by a test harness.
    static var isIsolated: Bool {
        ProcessInfo.processInfo.arguments.contains("--climate-screenshot")
            || ProcessInfo.processInfo.arguments.contains("--climate-isolated")
    }

    static var scene: String? {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--climate-screenshot") else {
            return nil
        }
        let valueIndex = ProcessInfo.processInfo.arguments.index(after: index)
        guard valueIndex < ProcessInfo.processInfo.arguments.endIndex else { return nil }
        return ProcessInfo.processInfo.arguments[valueIndex]
    }

    static let fixtureCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }()
}

struct ScreenshotRootView: View {
    let scene: String

    var body: some View {
        Group {
            switch scene {
        case "welcome":
            ScreenshotWelcomeView()
        case "home", "feed":
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) { ScreenshotFeedView() }
        case "explore":
            ScreenshotExploreView()
        case "write", "write-loading", "write-empty":
            ScreenshotWriteView(state: ScreenshotWriteState(scene: scene))
        case "profile", "saved":
            ScreenshotProfileView()
        case "story", "reader":
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) { ArticleDetailView(article: ScreenshotFixtures.article) }
        case "story-visual":
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) {
                ArticleDetailView(article: ScreenshotFixtures.article, initialScrollTarget: .articleVisual)
            }
        case "story-no-generation":
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) {
                ArticleDetailView(article: ScreenshotFixtures.articles[0])
            }
        case "summary":
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) { ScreenshotSummaryView() }
        case "actions", "action-selected", "reflection", "reflection-keyboard", "save-queued", "save-error", "save-synced":
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) {
                ScreenshotActionsView(state: ScreenshotActionState(scene: scene))
            }
        case "progress":
            ScreenshotTabShell(selectedTab: ClimateTab.saved.rawValue) { ScreenshotProgressView() }
        case "progress-completed":
            ScreenshotTabShell(selectedTab: ClimateTab.saved.rawValue) { ScreenshotProgressView(completedOnly: true) }
        case "journal-empty":
            ScreenshotTabShell(selectedTab: ClimateTab.saved.rawValue) { ScreenshotJournalStateView(state: .empty) }
        case "journal-guest":
            ScreenshotTabShell(selectedTab: ClimateTab.saved.rawValue) { ScreenshotJournalStateView(state: .guest) }
        case "signin":
            ScreenshotSignInView(isUnavailable: false)
        case "signin-unavailable":
            ScreenshotSignInView(isUnavailable: true)
        case "account":
            NavigationStack { ScreenshotAccountView() }
        case "privacy":
            ScreenshotTabShell(selectedTab: ClimateTab.saved.rawValue) { PrivacyView() }
        case "feed-loading", "feed-refreshing", "feed-stale", "feed-empty", "feed-error", "feed-image-loading", "feed-image-error":
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) {
                ScreenshotFeedStateView(state: ScreenshotFeedState(scene: scene))
            }
        case "impact-loading", "impact-threshold", "impact-populated", "impact-stale", "impact-error":
            ScreenshotTabShell(selectedTab: ClimateTab.saved.rawValue) {
                ScreenshotImpactStateView(state: ScreenshotImpactState(scene: scene))
            }
        default:
            ScreenshotTabShell(selectedTab: ClimateTab.home.rawValue) { ScreenshotFeedView() }
        }
        }
        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        .environment(\.calendar, ScreenshotConfiguration.fixtureCalendar)
        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .transaction { $0.disablesAnimations = true }
        .allowsHitTesting(false)
    }
}

private struct ScreenshotMasthead: View {
    let eyebrow: String
    let title: String
    let detail: String?

    init(_ title: String, eyebrow: String = "THE CLIMATE NOTE", detail: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.climateMetadata.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.climateSage)
            Text(title)
                .font(.climateDisplay(38, relativeTo: .largeTitle))
                .foregroundStyle(Color.climateInk)
            if let detail {
                Text(detail)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(Color.climateMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ScreenshotTabShell<Content: View>: View {
    let selectedTab: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        TabView(selection: .constant(selectedTab)) {
            NavigationStack { selectedTab == ClimateTab.home.rawValue ? AnyView(content()) : AnyView(Color.climateBackground) }
                .tabItem { Label(ClimateTab.home.title, systemImage: ClimateTab.home.systemImage) }
                .tag(ClimateTab.home.rawValue)
            NavigationStack { selectedTab == ClimateTab.explore.rawValue ? AnyView(content()) : AnyView(Color.climateBackground) }
                .tabItem { Label(ClimateTab.explore.title, systemImage: ClimateTab.explore.systemImage) }
                .tag(ClimateTab.explore.rawValue)
            NavigationStack { selectedTab == ClimateTab.write.rawValue ? AnyView(content()) : AnyView(Color.climateBackground) }
                .tabItem { Label(ClimateTab.write.title, systemImage: ClimateTab.write.systemImage) }
                .tag(ClimateTab.write.rawValue)
            NavigationStack { selectedTab == ClimateTab.saved.rawValue ? AnyView(content()) : AnyView(Color.climateBackground) }
                .tabItem { Label(ClimateTab.saved.title, systemImage: ClimateTab.saved.systemImage) }
                .tag(ClimateTab.saved.rawValue)
        }
        .climateTabBarChrome()
    }
}

private struct ScreenshotWelcomeView: View {
    var body: some View {
        ZStack {
            Image("ClimateHeroV2").resizable().scaledToFill()
            .ignoresSafeArea()
            LinearGradient(colors: [Color.climateCanvas.opacity(0.06), .clear, Color.climateCanvas.opacity(0.98)], startPoint: .top, endPoint: .bottom)
            VStack {
                Spacer()
                Text("THE")
                    .font(.climateMetadata.weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(Color.climateSage)
                Text("climate\nnote")
                    .font(.climateDisplay(48, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)
                Text("Real people. Real thoughts.\nA healthier planet.")
                    .font(.system(.title3, design: .default).weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                Text("Get Started")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.climatePaperInk)
                    .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                    .background(Color.climateSage, in: .rect(cornerRadius: ClimateRadius.control))
                    .padding(.top, 40)
                Text("Log In")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.climateSage)
                    .frame(minHeight: ClimateLayout.minimumTarget)
                    .padding(.top, 8)
            }
            .foregroundStyle(Color.climateInk)
            .padding(.horizontal, ClimateLayout.phoneGutter)
            .padding(.bottom, 30)
        }
    }
}

private struct ScreenshotFeedView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("the climate note").font(.climateDisplay(28, relativeTo: .title))
                        Spacer()
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(Color.climateMuted)
                            .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                    }
                    Text("Good morning,").font(.climateDisplay(28, relativeTo: .title))
                    Text("Here’s what’s new in the climate community.")
                        .font(.body).foregroundStyle(Color.climateMuted)
                }
                .padding(.bottom, ClimateLayout.section)
                ZStack(alignment: .bottomLeading) {
                    Image(ClimateLocalArt.assetName(for: ScreenshotFixtures.articles[0])).resizable().scaledToFill()
                    .frame(height: 232).clipped()
                    LinearGradient(colors: [.clear, Color.climateCanvas.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("FEATURED").font(.climateMetadata.weight(.bold)).tracking(1.1)
                        Text(ScreenshotFixtures.articles[0].title).font(.climateDisplay(25, relativeTo: .title2))
                        Text(ScreenshotFixtures.articles[0].excerpt)
                            .font(.subheadline).lineLimit(2)
                    }
                    .padding(ClimateLayout.cardPadding)
                }
                .clipShape(.rect(cornerRadius: ClimateRadius.image))
                HStack(spacing: 7) {
                    Circle().fill(Color.climateSage)
                    Circle().fill(Color.climateMuted)
                    Circle().fill(Color.climateMuted)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 10)
                HStack {
                    Text("Latest Articles").font(.climateDisplay(28, relativeTo: .title))
                    Spacer()
                    Text("Archive ···").font(.climateMetadata).foregroundStyle(Color.climateSage)
                }
                .padding(.top, ClimateLayout.section).padding(.bottom, 10)
                ForEach(Array(ScreenshotFixtures.articles.dropFirst().prefix(4))) { article in
                    ScreenshotArticleCard(article: article)
                    ClimateRule()
                }
            }
            .foregroundStyle(Color.climateInk)
            .padding(.horizontal, ClimateLayout.phoneGutter)
            .padding(.top, 18)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateBackground)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ScreenshotArticleCard: View {
    let article: Article

    var body: some View {
        HStack(spacing: 16) {
            ClimateCoverImage(url: nil, altText: article.coverAsset?.altText ?? "Climate article image", assetName: ClimateLocalArt.assetName(for: article))
                .frame(width: 92, height: 92).clipShape(.rect(cornerRadius: ClimateRadius.image))
            VStack(alignment: .leading, spacing: 5) {
                Text(article.title).font(.climateDisplay(21, relativeTo: .title3)).lineLimit(3)
                Text(article.excerpt).font(.subheadline).foregroundStyle(Color.climateMuted).lineLimit(2)
                Text("by \(article.displayAuthor) · \(article.readingMinutes) min read")
                    .font(.climateMetadata).foregroundStyle(Color.climateMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(Color.climateSage)
                .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
        }
        .padding(.vertical, 16)
    }
}

private struct ScreenshotSummaryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("THE SHORT VERSION").font(.climateMetadata.weight(.bold)).tracking(1.2).foregroundStyle(Color.climatePaperMuted)
                Text("The story in three parts")
                    .font(.climateDisplay(30, relativeTo: .title))
                    .foregroundStyle(Color.climatePaperInk)
                SummaryItem(title: "What is happening", copy: ScreenshotFixtures.summary.problem)
                SummaryItem(title: "Why it matters", copy: ScreenshotFixtures.summary.whyItMatters)
                SummaryItem(title: "What we can do", copy: ScreenshotFixtures.summary.whatWeCanDo)
                Text("AI summary. Read the article and sources for context.")
                    .font(.climateMetadata).foregroundStyle(Color.climatePaperMuted)
            }
            .padding(ClimateLayout.cardPadding)
            .background(Color.climateNotice.opacity(0.08), in: .rect(cornerRadius: ClimateRadius.card))
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climatePaperRule, lineWidth: 1) }
            .overlay(alignment: .leading) { Rectangle().fill(Color.climateSage).frame(width: 3) }
            .padding(ClimateLayout.phoneGutter)
        }
        .background(Color.climatePaper)
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SummaryItem: View {
    let title: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.bold)).foregroundStyle(Color.climatePaperInk)
            Text(copy).font(.body).foregroundStyle(Color.climatePaperMuted).lineSpacing(4)
        }
        .padding(.leading, 14)
    }
}

private struct ScreenshotActionsView: View {
    let state: ScreenshotActionState

    init(state: ScreenshotActionState = .actions) {
        self.state = state
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("WRITE A NOTE").font(.climateMetadata.weight(.bold)).tracking(1.2).foregroundStyle(Color.climateSage)
                Text("Choose one\nsmall step")
                    .font(.climateDisplay(40, relativeTo: .largeTitle))
                Text("Save one article-specific action to your private note. You can change it later.")
                    .font(.body).foregroundStyle(Color.climateMuted).lineSpacing(3)
                ForEach(Array(ScreenshotFixtures.actions.enumerated()), id: \.element.id) { index, action in
                    let selected = state.showsSelection && index == 1
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(selected ? Color.climateSage : Color.climateMuted)
                            .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(action.title).font(.climateDisplay(22, relativeTo: .title2))
                            Text(action.instruction).font(.subheadline).foregroundStyle(Color.climateMuted).lineSpacing(2)
                            Text(action.cadence).font(.climateMetadata).foregroundStyle(Color.climateSage)
                        }
                    }
                    .padding(ClimateLayout.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selected ? Color.climateSurfaceRaised : Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                    .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(selected ? Color.climateSage.opacity(0.75) : Color.climateRule, lineWidth: 1) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                if state.showsReflection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR PRIVATE REFLECTION").font(.climateMetadata.weight(.bold)).tracking(1).foregroundStyle(Color.climateSage)
                        Text("I’ll check our medicine cabinet and find a local take-back point.")
                            .font(.body).foregroundStyle(Color.climatePaperInk)
                            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                            .padding(16)
                            .background(Color.climatePaper, in: .rect(cornerRadius: ClimateRadius.control))
                            .overlay {
                                RoundedRectangle(cornerRadius: ClimateRadius.control)
                                    .stroke(state == .reflectionKeyboard ? Color.climateSage : Color.climatePaperRule, lineWidth: state == .reflectionKeyboard ? 2 : 1)
                            }
                        Text("Your draft stays on this device until you save it.")
                            .font(.climateMetadata).foregroundStyle(Color.climateMuted)
                    }
                }
                if let notice = state.notice {
                    Label(notice.text, systemImage: notice.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(notice.color)
                        .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(notice.background, in: .rect(cornerRadius: ClimateRadius.control))
                        .accessibilityElement(children: .combine)
                } else {
                    Text("Choose a suggestion or write a reflection. Saved notes stay private to My Note.")
                        .font(.climateMetadata).foregroundStyle(Color.climateMuted)
                }
                Text(state.buttonTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.climatePaperInk)
                    .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                    .background(state == .saveError ? Color.red.opacity(0.85) : Color.climateSage, in: .rect(cornerRadius: ClimateRadius.control))
            }
            .foregroundStyle(Color.climateInk)
            .padding(ClimateLayout.phoneGutter)
            .padding(.bottom, state == .reflectionKeyboard ? 270 : ClimateLayout.majorSection)
        }
        .background(Color.climateBackground)
        .navigationTitle("Your climate note")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if state == .reflectionKeyboard {
                ScreenshotKeyboardChrome()
            }
        }
    }
}

private enum ScreenshotActionState: Equatable {
    case actions, selected, reflection, reflectionKeyboard, saveQueued, saveError, saveSynced

    init(scene: String) {
        switch scene {
        case "action-selected": self = .selected
        case "reflection": self = .reflection
        case "reflection-keyboard": self = .reflectionKeyboard
        case "save-queued": self = .saveQueued
        case "save-error": self = .saveError
        case "save-synced": self = .saveSynced
        default: self = .actions
        }
    }

    var showsSelection: Bool {
        self == .selected || self == .saveQueued || self == .saveError || self == .saveSynced
    }

    var showsReflection: Bool {
        self == .reflection || self == .reflectionKeyboard || self == .saveQueued || self == .saveError || self == .saveSynced
    }

    var buttonTitle: String {
        switch self {
        case .saveQueued: "Waiting to sync"
        case .saveError: "Retry save"
        case .saveSynced: "Saved to My Note"
        default: "Save to My Note"
        }
    }

    var notice: (text: String, symbol: String, color: Color, background: Color)? {
        switch self {
        case .saveQueued:
            ("Saved on this device — waiting to sync", "arrow.triangle.2.circlepath", Color.climateInk, Color.climateSage.opacity(0.22))
        case .saveError:
            ("Couldn’t sync — retry when you’re ready", "exclamationmark.triangle.fill", Color.red.opacity(0.95), Color.red.opacity(0.12))
        case .saveSynced:
            ("Saved to My Note", "checkmark.circle.fill", Color.climatePaperInk, Color.climateSage.opacity(0.62))
        default: nil
        }
    }
}

private struct ScreenshotKeyboardChrome: View {
    private let keys = ["Q W E R T Y U I O P", "A S D F G H J K L", "⇧ Z X C V B N M ⌫", "123          space          return"]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(keys, id: \.self) { row in
                Text(row)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .kerning(4)
                    .foregroundStyle(Color.climatePaperInk)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Color.white.opacity(0.86), in: .rect(cornerRadius: 5))
            }
        }
        .padding(10)
        .background(Color(white: 0.72))
        .accessibilityHidden(true)
    }
}

private struct ScreenshotProgressView: View {
    let completedOnly: Bool
    private let calendar = ScreenshotConfiguration.fixtureCalendar

    init(completedOnly: Bool = false) {
        self.completedOnly = completedOnly
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.section) {
                ScreenshotMasthead("My Note", eyebrow: "A PRIVATE PLACE FOR SMALL ACTIONS", detail: "Plan one action, set a reminder, and record what changed.")
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("This week").font(.climateDisplay(27, relativeTo: .title))
                        Spacer()
                        Text("SEP 6–12").font(.climateMetadata.weight(.bold)).tracking(0.8).foregroundStyle(Color.climateMuted)
                    }
                    HStack {
                        ForEach(0..<7) { offset in
                            let completed = [0, 2, 3, 5].contains(offset)
                            VStack(spacing: 9) {
                                Text(day(offset).formatted(.dateTime.weekday(.narrow))).font(.climateMetadata)
                                Text(day(offset).formatted(.dateTime.day()))
                                    .font(.headline.weight(.bold))
                                    .frame(width: 44, height: 44)
                                    .background(completed ? Color.climateSage : Color.secondary.opacity(0.1), in: .circle)
                                    .foregroundStyle(completed ? Color.climatePaperInk : Color.climateInk)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(ClimateLayout.cardPadding)
                .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your impact").font(.climateDisplay(27, relativeTo: .title))
                    Text("4").font(.system(size: 54, weight: .bold, design: .rounded)).foregroundStyle(Color.climateSage)
                    Text("climate actions completed").font(.body).foregroundStyle(Color.climateMuted)
                    Text("1.6 kg CO₂e").font(.title2.bold()).foregroundStyle(Color.climateInk)
                    Text("estimated only from supported, measurable actions")
                        .font(.climateMetadata).foregroundStyle(Color.climateMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ClimateLayout.cardPadding)
                .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))

                if !completedOnly {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("Planned action").font(.climateMetadata.weight(.bold)).tracking(1.1).foregroundStyle(Color.climateSage)
                        HStack {
                            Text("Return unused medicine safely").font(.climateDisplay(23, relativeTo: .title2))
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.climateSage)
                        }
                        Text("Use a local medicine take-back location instead of throwing medicine away.")
                            .font(.body).foregroundStyle(Color.climateMuted)
                        Text("Pharmaceutical pollution").font(.climateMetadata).foregroundStyle(Color.climateSage)
                        Label("Reminder set · Friday at 9:00 AM", systemImage: "bell.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
                            .overlay(alignment: .bottom) { ClimateRule() }
                        Text("Reflection").font(.subheadline.weight(.semibold))
                        Text("I found a take-back location near the pharmacy.")
                            .font(.body).foregroundStyle(Color.climateMuted)
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                            .padding(12)
                            .background(Color.climateCanvas, in: .rect(cornerRadius: ClimateRadius.control))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ClimateLayout.cardPadding)
                    .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                    .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Completed").font(.climateDisplay(27, relativeTo: .title))
                    Text(completedOnly ? "Every planned note is complete. Keep reading to choose what comes next." : "Four actions are building a steadier practice this week.")
                        .font(.body).foregroundStyle(Color.climateMuted)
                    Label("Check medicine cabinets", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.climateSage)
                        .frame(minHeight: ClimateLayout.minimumTarget)
                }
            }
            .padding(ClimateLayout.phoneGutter)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func day(_ offset: Int) -> Date {
        let today = calendar.startOfDay(for: ScreenshotFixtures.referenceDate)
        let weekday = calendar.component(.weekday, from: today)
        let start = calendar.date(byAdding: .day, value: -(weekday - calendar.firstWeekday + 7) % 7, to: today) ?? today
        return calendar.date(byAdding: .day, value: offset, to: start) ?? today
    }
}

private enum ScreenshotJournalState {
    case empty, guest
}

private struct ScreenshotJournalStateView: View {
    let state: ScreenshotJournalState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.section) {
                ScreenshotMasthead(
                    "My Note",
                    eyebrow: state == .guest ? "A PRIVATE PLACE FOR SMALL ACTIONS" : "PRIVATE BY DEFAULT",
                    detail: state == .guest
                        ? "Sign in to keep reflections, actions, and completion history private."
                        : "Save one action. Return later. Notice what changed."
                )
                if state == .empty {
                    ScreenshotEmptyJournalContent()
                } else {
                    ClimateStateNotice(
                        symbol: "lock",
                        title: "Keep your notes private",
                        message: "Reading stays open. Sign in only when you’re ready to save a reflection or an action."
                    )
                    Text("Sign in to save privately")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.climatePaperInk)
                        .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                        .background(Color.climateSage, in: .rect(cornerRadius: ClimateRadius.control))
                }
            }
            .padding(ClimateLayout.phoneGutter)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateBackground)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ScreenshotEmptyJournalContent: View {
    private let steps = [
        ("Read what catches you", "Explore 11 verified climate stories."),
        ("Choose one small step", "Keep the action realistic and specific."),
        ("Return and reflect", "Record what changed when you tried it."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image("ClimateHeroV2")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 248)
                    .clipped()
                LinearGradient(
                    colors: [.clear, Color.climateCanvas.opacity(0.58), Color.climateCanvas.opacity(0.97)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR FIRST NOTE").climateMetadata(weight: .bold).tracking(1.1).foregroundStyle(Color.climateSage)
                    Text("Start with a story worth keeping.").climateEditorialDisplay(32, relativeTo: .title)
                    Text("Choose one useful step from a published article. Your source stays attached for context.")
                        .font(.subheadline).foregroundStyle(Color.climateInk.opacity(0.82)).lineSpacing(3)
                }
                .padding(ClimateLayout.cardPadding)
            }
            .clipShape(.rect(cornerRadius: ClimateRadius.card))
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }

            ForEach(steps.indices, id: \.self) { index in
                HStack(spacing: 13) {
                    Text(String(format: "%02d", index + 1))
                        .climateEditorialDisplay(17, relativeTo: .body)
                        .foregroundStyle(Color.climateSage)
                        .frame(width: 38, height: 38)
                        .overlay { Circle().stroke(Color.climateSage.opacity(0.42), lineWidth: 1) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(steps[index].0).font(.body.weight(.semibold))
                        Text(steps[index].1).font(.footnote).foregroundStyle(Color.climateMuted)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                if index < steps.count - 1 { ClimateRule() }
            }

            Text("Browse 11 stories")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.climatePaperInk)
                .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                .background(Color.climateSage, in: .rect(cornerRadius: ClimateRadius.control))
                .padding(.top, ClimateLayout.element)

            Label("Your note stays private unless you choose to contribute an anonymous supported-action estimate.", systemImage: "lock")
                .font(.footnote).foregroundStyle(Color.climateMuted).lineSpacing(3).padding(.top, 14)
        }
    }
}

private enum ScreenshotFeedState {
    case loading, refreshing, stale, empty, error, imageLoading, imageError

    init(scene: String) {
        switch scene {
        case "feed-loading": self = .loading
        case "feed-refreshing": self = .refreshing
        case "feed-stale": self = .stale
        case "feed-empty": self = .empty
        case "feed-error": self = .error
        case "feed-image-loading": self = .imageLoading
        default: self = .imageError
        }
    }
}

private struct ScreenshotFeedStateView: View {
    let state: ScreenshotFeedState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.section) {
                ScreenshotMasthead("Good morning,", detail: "Here’s what’s new in the climate community.")
                switch state {
                case .loading:
                    loadingContent
                case .refreshing:
                    feedWithNotice("Refreshing the latest notes…", symbol: "arrow.triangle.2.circlepath")
                case .stale:
                    feedWithNotice("Showing the last available notes. A refresh did not finish.", symbol: "wifi.exclamationmark")
                case .empty:
                    ClimateStateNotice(symbol: "newspaper", title: "A new note is on its way", message: "There are no published articles right now. Please check back soon.")
                case .error:
                    ClimateStateNotice(symbol: "wifi.exclamationmark", title: "Articles are unavailable", message: "We couldn’t reach the publication. Your private notes remain safe on this device.")
                case .imageLoading:
                    imageState(isLoading: true)
                case .imageError:
                    imageState(isLoading: false)
                }
            }
            .padding(ClimateLayout.phoneGutter)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Loading articles").font(.climateDisplay(28, relativeTo: .title))
            ForEach(0..<3) { index in
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: ClimateRadius.image).fill(Color.climateSurfaceRaised).frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.climateSurfaceRaised).frame(height: 18)
                        RoundedRectangle(cornerRadius: 4).fill(Color.climateSurfaceRaised).frame(width: index == 0 ? 156 : 128, height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(Color.climateSurfaceRaised).frame(width: 104, height: 12)
                    }
                }
                .accessibilityLabel("Article loading")
            }
        }
    }

    private func feedWithNotice(_ message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(message, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.climateInk)
                .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
                .padding(.horizontal, 16)
                .background(Color.climateNotice, in: .rect(cornerRadius: ClimateRadius.control))
            Text("Latest articles").font(.climateDisplay(28, relativeTo: .title))
            ForEach(ScreenshotFixtures.articles.prefix(2)) { ScreenshotArticleCard(article: $0) }
        }
    }

    private func imageState(isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                if isLoading {
                    Color.climateSurfaceRaised
                    ProgressView().tint(Color.climateSage)
                } else {
                    LinearGradient(colors: [Color.climateNotice, Color.climateCanvas], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "photo.badge.exclamationmark").font(.system(size: 42, weight: .light)).foregroundStyle(Color.climateSage)
                }
            }
            .frame(height: 232)
            .clipShape(.rect(cornerRadius: ClimateRadius.image))
            .accessibilityLabel(isLoading ? "Article image loading" : "Article image unavailable")
            Text(isLoading ? "Loading the article image…" : "The image could not load. The story is still available to read.")
                .font(.body).foregroundStyle(Color.climateMuted)
            ScreenshotArticleCard(article: ScreenshotFixtures.articles[0])
        }
    }
}

private enum ScreenshotImpactState {
    case loading, threshold, populated, stale, error

    init(scene: String) {
        switch scene {
        case "impact-loading": self = .loading
        case "impact-threshold": self = .threshold
        case "impact-populated": self = .populated
        case "impact-stale": self = .stale
        default: self = .error
        }
    }
}

private struct ScreenshotImpactStateView: View {
    let state: ScreenshotImpactState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.section) {
                ScreenshotMasthead("Community impact", eyebrow: "TRANSPARENT ESTIMATES", detail: "Only supported completed actions are included.")
                Group {
                    switch state {
                    case .loading:
                        ClimateStateNotice(symbol: "chart.bar.xaxis", title: "Calculating community impact", message: "This takes a moment. We only show estimates with a documented factor.")
                    case .threshold:
                        ClimateStateNotice(symbol: "person.3", title: "Growing together", message: "Community totals appear after enough contributors choose to share an aggregate estimate.")
                    case .populated, .stale:
                        impactTotal
                    case .error:
                        ClimateStateNotice(symbol: "exclamationmark.triangle", title: "Impact is unavailable", message: "We couldn’t load the aggregate estimate. Your private notes are unaffected.")
                    }
                }
            }
            .padding(ClimateLayout.phoneGutter)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var impactTotal: some View {
        VStack(alignment: .leading, spacing: 13) {
            if state == .stale {
                Label("Showing the last calculated estimate", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.climateInk)
            }
            Text("1,260 kg CO₂e").font(.climateDisplay(44, relativeTo: .largeTitle)).foregroundStyle(Color.climateInk)
            Text("estimated across 187 supported completed actions from 42 contributors")
                .font(.body).foregroundStyle(Color.climateMuted)
            ClimateRule()
            Text("Methodology: versioned EPA factors. Estimates are directional, not a personal carbon score.")
                .font(.climateMetadata).foregroundStyle(Color.climateMuted)
        }
        .padding(ClimateLayout.cardPadding)
        .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
    }
}

private struct ScreenshotExploreView: View {
    var body: some View {
        ScreenshotTabShell(selectedTab: ClimateTab.explore.rawValue) {
            ScrollView {
                VStack(alignment: .leading, spacing: ClimateLayout.section) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DISCOVER")
                            .climateMetadata(weight: .bold)
                            .tracking(1.5)
                            .foregroundStyle(Color.climateSage)
                        Text("Explore")
                            .climateDiscoveryDisplay(42, relativeTo: .largeTitle, weight: .bold)
                            .tracking(-0.8)
                        Text("Search the archive or follow a story that catches your eye.")
                            .font(.body)
                            .foregroundStyle(Color.climateMuted)
                            .lineSpacing(3)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.climateSage)
                        Text("Search by title, topic, or idea").font(.body).foregroundStyle(Color.climateMuted)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 58)
                    .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.control))
                    .overlay { RoundedRectangle(cornerRadius: ClimateRadius.control).stroke(Color.climateRule, lineWidth: 1) }

                    VStack(alignment: .leading, spacing: ClimateLayout.element) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Start here").climateDiscoveryDisplay(24, relativeTo: .title2)
                            Spacer()
                            Text("EDITOR'S PICK")
                                .climateMetadata(weight: .bold)
                                .tracking(1)
                                .foregroundStyle(Color.climateSage)
                        }
                        ScreenshotExploreFeatureCard(article: ScreenshotFixtures.articles[0])
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Browse the archive").climateDiscoveryDisplay(25, relativeTo: .title2)
                            Spacer()
                            Text("10 NOTES").climateMetadata(weight: .bold).foregroundStyle(Color.climateMuted)
                        }
                        ForEach(ScreenshotFixtures.articles.dropFirst().prefix(3)) { article in
                            ScreenshotArticleCard(article: article)
                            ClimateRule()
                        }
                    }
                }
                .foregroundStyle(Color.climateInk)
                .padding(.horizontal, ClimateLayout.phoneGutter)
                .padding(.top, ClimateLayout.element)
                .padding(.bottom, ClimateLayout.majorSection)
            }
            .background(Color.climateCanvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ScreenshotExploreFeatureCard: View {
    let article: Article

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ClimateCoverImage(
                url: nil,
                altText: article.coverAsset?.altText ?? "Cover for \(article.title)",
                assetName: ClimateLocalArt.assetName(for: article)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 248)
            .clipped()
            LinearGradient(
                colors: [.clear, Color.climateCanvas.opacity(0.48), Color.climateCanvas.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(article.topic.uppercased())
                    .climateMetadata(weight: .bold).tracking(1).foregroundStyle(Color.climateSage)
                Text(article.title)
                    .climateEditorialDisplay(29, relativeTo: .title2)
                    .tracking(-0.35)
                    .lineLimit(3)
                HStack {
                    Text("\(article.readingMinutes) min read").climateMetadata().foregroundStyle(Color.climateMuted)
                    Spacer()
                    Label("Read story", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.climateSage)
                }
            }
            .padding(ClimateLayout.cardPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 248)
        .clipShape(.rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1) }
    }
}

private enum ScreenshotWriteState {
    case populated, loading, empty

    init(scene: String) {
        switch scene {
        case "write-loading": self = .loading
        case "write-empty": self = .empty
        default: self = .populated
        }
    }
}

private struct ScreenshotWriteView: View {
    let state: ScreenshotWriteState

    init(state: ScreenshotWriteState = .populated) {
        self.state = state
    }

    var body: some View {
        ScreenshotTabShell(selectedTab: ClimateTab.write.rawValue) {
            ScrollView {
                VStack(alignment: .leading, spacing: ClimateLayout.section) {
                    ScreenshotWriteNotebookHero()

                    switch state {
                    case .loading:
                        ProgressView("Loading stories")
                            .tint(Color.climateSage)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    case .empty:
                        ClimateStateNotice(
                            symbol: "square.and.pencil",
                            title: "Choose a story first",
                            message: "Published stories will appear here."
                        )
                    case .populated:
                        VStack(alignment: .leading, spacing: ClimateLayout.element) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Choose a story")
                                        .climateEditorialDisplay(28, relativeTo: .title)
                                        .tracking(-0.35)
                                    Text("Your note keeps the story attached for context.")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.climateMuted)
                                }
                                Spacer(minLength: ClimateLayout.compact)
                                Text("11").climateMetadata(weight: .bold).foregroundStyle(Color.climateSage)
                            }

                            ScrollView(.horizontal) {
                                LazyHStack(spacing: ClimateLayout.element) {
                                    ForEach(ScreenshotFixtures.articles.prefix(4)) { article in
                                        ScreenshotComposeStoryCard(article: article)
                                    }
                                }
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
                .padding(.horizontal, ClimateLayout.phoneGutter)
                .padding(.top, ClimateLayout.element)
                .padding(.bottom, ClimateLayout.majorSection)
                .foregroundStyle(Color.climateInk)
            }
            .background(Color.climateCanvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ScreenshotWriteNotebookHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRIVATE NOTEBOOK")
                        .climateMetadata(weight: .bold).tracking(1.35).foregroundStyle(Color.climatePaperMuted)
                    Text("Write what\nstayed with you.")
                        .climateEditorialDisplay(37, relativeTo: .largeTitle)
                        .tracking(-0.6)
                        .foregroundStyle(Color.climatePaperInk)
                }
                Spacer(minLength: ClimateLayout.element)
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.climatePaperInk)
                    .frame(width: 52, height: 52)
                    .background(Color.climateSage.opacity(0.42), in: .circle)
            }
            Text("Begin with a published story, then capture your own response. Notes are private by default.")
                .font(.body).foregroundStyle(Color.climatePaperMuted).lineSpacing(4)
            Label("Only you can see your note", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.climatePaperInk)
                .frame(minHeight: ClimateLayout.minimumTarget)
        }
        .padding(ClimateLayout.cardPadding)
        .background(Color.climatePaper, in: .rect(cornerRadius: 24))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.climateSage).frame(width: 4).padding(.vertical, 22)
        }
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.16), lineWidth: 1) }
    }
}

private struct ScreenshotComposeStoryCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ClimateCoverImage(
                url: nil,
                altText: article.coverAsset?.altText ?? "Cover for \(article.title)",
                assetName: ClimateLocalArt.assetName(for: article)
            )
            .frame(width: 252, height: 146)
            .clipped()
            .overlay(alignment: .topLeading) {
                Text(article.topic.uppercased())
                    .climateMetadata(weight: .bold).tracking(0.9).foregroundStyle(Color.climateInk)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.climateCanvas.opacity(0.82), in: .capsule)
                    .padding(12)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(article.title)
                    .climateEditorialDisplay(22, relativeTo: .title3)
                    .tracking(-0.25)
                    .lineLimit(3)
                Spacer(minLength: 0)
                HStack {
                    Text("Open notebook").font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.climateSage)
            }
            .frame(width: 252, alignment: .leading)
            .frame(minHeight: 142, alignment: .topLeading)
            .padding(ClimateLayout.element)
            .background(Color.climateSurfaceRaised)
        }
        .clipShape(.rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
    }
}

private struct ScreenshotProfileView: View {
    var body: some View {
        ScreenshotTabShell(selectedTab: ClimateTab.saved.rawValue) {
            ScrollView {
                VStack(alignment: .leading, spacing: ClimateLayout.section) {
                    ScreenshotMasthead("My Note", eyebrow: "A PRIVATE PLACE FOR SMALL ACTIONS", detail: "Small actions add up. Capture what you’re doing and how it feels.")
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("This week").font(.climateDisplay(27, relativeTo: .title))
                            Spacer()
                            Text("SEP 6–12").font(.climateMetadata).foregroundStyle(Color.climateMuted)
                        }
                        HStack(spacing: 4) {
                            ForEach(Array(zip(["S", "M", "T", "W", "T", "F", "S"], 6...12)), id: \.1) { item in
                                VStack(spacing: 6) {
                                    Text(item.0).font(.climateMetadata)
                                    Text("\(item.1)").font(.subheadline.weight(.semibold))
                                    Image(systemName: item.1 == 8 ? "checkmark" : "circle")
                                        .font(.caption.weight(.bold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .foregroundStyle(item.1 == 8 ? Color.climatePaperInk : Color.climateMuted)
                                .background(item.1 == 8 ? Color.climateSage : Color.clear, in: .rect(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(ClimateLayout.cardPadding)
                    .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                    .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }

                    VStack(alignment: .leading, spacing: 13) {
                        Text("PLANNED ACTION").font(.climateMetadata.weight(.bold)).tracking(1.1).foregroundStyle(Color.climateSage)
                        Text("Stop flushing medications").font(.climateDisplay(25, relativeTo: .title2))
                        Text("Never flush unused or expired medications down the toilet or pour them down the drain.")
                            .font(.body).foregroundStyle(Color.climateMuted)
                        Text("From Pharmaceutical pollution").font(.climateMetadata).foregroundStyle(Color.climateSage)
                        Text("Mark complete").font(.headline.weight(.semibold)).foregroundStyle(Color.climatePaperInk)
                            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                            .background(Color.climateSage, in: .rect(cornerRadius: ClimateRadius.control))
                        Label("Remind me", systemImage: "bell")
                            .font(.headline.weight(.semibold)).frame(minHeight: ClimateLayout.minimumTarget)
                        ClimateRule()
                        Text("Reflection").font(.headline)
                        Text("Your reflection or action")
                            .font(.body).foregroundStyle(Color.climateMuted)
                            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading).padding(12)
                            .background(Color.climateCanvas, in: .rect(cornerRadius: ClimateRadius.control))
                    }
                    .padding(ClimateLayout.cardPadding)
                    .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))
                    .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completed").font(.climateDisplay(27, relativeTo: .title))
                        Label("Check medicine cabinets", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.climateSage)
                            .frame(minHeight: ClimateLayout.minimumTarget)
                    }
                }
                .foregroundStyle(Color.climateInk).padding(ClimateLayout.phoneGutter).padding(.bottom, ClimateLayout.majorSection)
            }
            .background(Color.climateCanvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ScreenshotSignInView: View {
    let isUnavailable: Bool
    let isGuest: Bool

    init(isUnavailable: Bool = false, isGuest: Bool = false) {
        self.isUnavailable = isUnavailable
        self.isGuest = isGuest
    }

    var body: some View {
        ZStack {
            Color.climateCanvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: ClimateLayout.section) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("YOUR PRIVATE NOTE")
                            .font(.climateMetadata.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.climateSage)
                        Text(isGuest ? "Keep your guest note." : "Keep your own note.")
                            .font(.climateDisplay(38, relativeTo: .largeTitle))
                        Text(isGuest
                            ? "Add Apple or Google to keep this guest account’s notes across devices."
                            : "Reading never requires an account. Continue as a guest to save privately, or use Apple or Google.")
                            .font(.body).foregroundStyle(Color.climateMuted).lineSpacing(4)
                    }

                    ClimateRule()

                    HStack(spacing: 12) {
                        Image(systemName: "square")
                            .font(.title3)
                            .foregroundStyle(Color.climateMuted)
                            .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                            .accessibilityHidden(true)
                        Text("I confirm I am 13 or older.")
                            .font(.body.weight(.medium))
                }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("I confirm I am 13 or older")
                    .accessibilityValue("Not selected")
                    Text("Confirm your age to continue.")
                        .font(.footnote).foregroundStyle(Color.climateMuted)

                    if !isGuest {
                        Text("Continue as guest")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.climatePaperInk.opacity(0.58))
                            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                            .background(Color.climateSage.opacity(0.48), in: .rect(cornerRadius: ClimateRadius.control))
                    }

                    VStack(spacing: ClimateLayout.element) {
                        Label("Continue with Apple", systemImage: "apple.logo")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.climatePaperInk.opacity(0.58))
                            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                            .background(Color.climatePaper.opacity(0.48), in: .rect(cornerRadius: ClimateRadius.control))
                        Text("Continue with Google")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.climateMuted.opacity(0.58))
                            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
                            .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.control))
                    }

                    if isUnavailable {
                        Label("Sign-in is temporarily unavailable. You can keep reading and try again later.", systemImage: "wifi.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(Color.climateMuted)
                            .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: ClimateLayout.compact) {
                        Text("By creating a guest account or continuing with Apple or Google, you agree to the Terms of Service and Privacy Policy.")
                        HStack(spacing: ClimateLayout.element) {
                            Text("Privacy Policy").underline()
                            Text("Terms of Service").underline()
                        }
                    }
                    .font(.footnote).foregroundStyle(Color.climateMuted).lineSpacing(3)
                    Text("Not now").font(.subheadline.weight(.semibold)).foregroundStyle(Color.climateSage)
                        .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget)
                }
                .padding(ClimateLayout.cardPadding)
                .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
                .padding(ClimateLayout.phoneGutter)
            }
        }
    }
}

private struct ScreenshotAccountView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.majorSection) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACCOUNT").font(.climateMetadata.weight(.bold)).tracking(1.2).foregroundStyle(Color.climateSage)
                    Text("Your climate profile").font(.climateDisplay(38, relativeTo: .largeTitle))
                    Text("reader@example.com").font(.headline)
                    Text("Notes stay private to your account.").font(.body).foregroundStyle(Color.climateMuted).lineSpacing(4)
                }

                accountGroup("YOUR DATA") {
                    accountRow("Export synced account data", showsChevron: false)
                    accountDivider
                    accountRow("Sign out", showsChevron: false)
                }

                accountGroup("IMPACT") {
                    Text("Personal estimates appear after you complete a supported action.")
                        .font(.footnote).foregroundStyle(Color.climateMuted)
                    accountDivider
                    HStack(spacing: ClimateLayout.element) {
                        Image(systemName: "person.2")
                            .font(.title3)
                            .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                            .background(Color.climateSage.opacity(0.16), in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("See community impact").font(.headline)
                            Text("Anonymous estimates from contributors").font(.footnote).foregroundStyle(Color.climateMuted)
                        }
                        Spacer(minLength: ClimateLayout.compact)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.climateMuted)
                    }
                    .frame(minHeight: ClimateLayout.controlHeight)
                    accountDivider
                    Toggle("Include my completed supported actions in anonymous community totals", isOn: .constant(true))
                        .font(.body)
                        .tint(Color.climateSage)
                        .frame(minHeight: ClimateLayout.minimumTarget)
                    Text("This is optional. You can withdraw at any time; private notes and identity are never included.")
                        .font(.footnote).foregroundStyle(Color.climateMuted).lineSpacing(2)
                }

                accountGroup("NOTIFICATIONS") {
                    Toggle("Weekly new article", isOn: .constant(false))
                        .font(.body)
                        .tint(Color.climateSage)
                        .frame(minHeight: ClimateLayout.minimumTarget)
                    Text("Off by default. Action reminders are scheduled only when you choose a date for a planned action.")
                        .font(.footnote).foregroundStyle(Color.climateMuted).lineSpacing(3)
                }

                accountGroup("HELP & PRIVACY") {
                    accountRow("Email support")
                    accountDivider
                    accountRow("Support website")
                    accountDivider
                    accountRow("Privacy Policy")
                    accountDivider
                    accountRow("Terms")
                    accountDivider
                    accountRow("Privacy in plain language")
                }

                accountGroup("ABOUT") {
                    Text("For readers 13+. AI summaries are labeled. Impact figures are estimates.")
                        .font(.footnote).foregroundStyle(Color.climateMuted).lineSpacing(3)
                }

                Text("Delete account")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(minHeight: ClimateLayout.controlHeight)
            }
            .climateContentWidth()
            .padding(.top, ClimateLayout.section)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .foregroundStyle(Color.climateInk)
        .tint(Color.climateSage)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.climateCanvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func accountGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.climateMetadata.weight(.bold)).tracking(1.1).foregroundStyle(Color.climateSage)
            content()
        }
        .padding(ClimateLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
    }

    private var accountDivider: some View {
        ClimateRule().padding(.leading, ClimateLayout.cardPadding)
    }

    private func accountRow(_ title: String, showsChevron: Bool = true) -> some View {
        HStack(spacing: ClimateLayout.element) {
            Text(title).font(.body.weight(.medium))
            Spacer(minLength: ClimateLayout.compact)
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.climateMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight, alignment: .leading)
        .padding(.horizontal, ClimateLayout.cardPadding)
    }
}

private struct ScreenshotPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.section) {
                ScreenshotMasthead("Privacy", eyebrow: "YOUR INFORMATION", detail: "Clear boundaries for what is public, private, and never sold.")
                privacyGroup("WHAT IS PUBLIC", "Published articles, their cited sources, and labeled AI additions.")
                privacyGroup("WHAT IS PRIVATE", "Your reflections, chosen actions, completion history, and impact estimates.")
                privacyGroup("WHAT WE DO NOT DO", "We do not sell data, show behavioral ads, or use your private notes to train public AI models.")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Questions").font(.climateDisplay(26, relativeTo: .title))
                    Text("theclimatenote@gmail.com").font(.body.weight(.semibold)).foregroundStyle(Color.climateSage)
                }
                .padding(ClimateLayout.cardPadding)
                .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))
            }
            .padding(ClimateLayout.phoneGutter).padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.climateCanvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func privacyGroup(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.climateMetadata.weight(.bold)).tracking(1.1).foregroundStyle(Color.climateSage)
            Text(detail).font(.body).foregroundStyle(Color.climateMuted).lineSpacing(3)
        }
        .padding(ClimateLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
    }
}

// Internal so the DEBUG test target can verify the deterministic preview uses
// the canonical fixture without exposing it to production clients.
enum ScreenshotFixtures {
    static let referenceDate = ScreenshotConfiguration.fixtureCalendar.date(
        from: DateComponents(year: 2026, month: 9, day: 9, hour: 12)
    )!

    static let summary = ClimateSummary(
        problem: "Unused or expired medicines are often flushed down the toilet or thrown away incorrectly, polluting rivers and oceans with chemical drugs.",
        whyItMatters: "These chemicals disrupt the hormones of aquatic animals, causing reproductive problems, and can eventually lead to antimicrobial resistance in humans who eat contaminated fish.",
        whatWeCanDo: "We can stop flushing medications and instead dispose of them safely by mixing them with items like coffee grounds in a sealed bag before throwing them in the trash."
    )

    static let actions = [
        SuggestedAction(
            id: "action-1",
            title: "Check medicine cabinets",
            instruction: "Review all prescription and over-the-counter medications in your home once every six months to identify expired or unused products.",
            cadence: "Every six months",
            evidence: "Many individuals have previously been prescribed medication, and as of 2021, 64.8% of adults aged 18 and older continued to take prescription medication.",
            category: "waste",
            factorId: nil,
            factorQuantity: nil
        ),
        SuggestedAction(
            id: "action-2",
            title: "Stop flushing medications",
            instruction: "Never flush unused or expired medications down the toilet or pour them down the drain.",
            cadence: "Always",
            evidence: "We should avoid flushing or pouring pharmaceuticals down the drain.",
            category: "water",
            factorId: nil,
            factorQuantity: nil
        ),
        SuggestedAction(
            id: "action-3",
            title: "Dispose of medicines safely in the trash",
            instruction: "Take medicines out of their original containers, mix them with undesirable waste like used coffee grounds without crushing them, and seal them in a bag before throwing them away.",
            cadence: "Whenever disposing of unused medicine",
            evidence: "MedlinePlus provides guidelines on how to properly dispose of medication: take the medicine out of its container and mix it with undesirable garbage.",
            category: "waste",
            factorId: nil,
            factorQuantity: nil
        ),
    ]

    static let articles: [Article] = [
        preview("drive-1Ww2e3lTPhKcrEr5kKzt2_bVVYhdQvhRe", "benjamin-jance-iv-cities-the-savior-of-energy-chaeho", "Benjamin Jance IV: Cities, the savior of energy? (Chaeho)", "When people think about climate change, they often imagine melting icebergs or huge factories emitting pollution. But the real problem is much closer than that. It’s in our…", 3, 1_789_043_145.951),
        preview("drive-19NI_0f-M9SywmjzW1gN-RBfTTgpxdKtN", "the-colorful-reefs-in-finding-nemo-we-grew-up-with-are-a-lie", "The Colorful Reefs in Finding Nemo We Grew Up With Are a Lie", "If you have ever looked at reef photos online and because of that, expected the ocean to look like a kaleidoscope of colors, then you’re going to be quite shocked once you…", 3, 1_788_783_944.643),
        preview("drive-1y7_1JFN6ahFukH-exZgZo7kUjFrR-O8s", "disappearance-of-bees", "Disappearance of Bees", "Despite their small size, insects are considered to cover a significant part of Earth’s living biomass. Among one million species of them, bees are one of the most important…", 3, 1_788_697_542.933),
        preview("drive-1HeqV1tqoepzV9xFOq9DEpWfP3a9LVhE7", "biotic-homogenization", "Biotic Homogenization", "Along with the growing speed of urbanization, the increase of human activities, and the spread of invasive species, distributed ecological habitats and communities are becoming…", 3, 1_788_611_143.093),
        preview("drive-1ajPLmeV5ANnI-n69db6qGDWWZTeZaU-I", "mangrove-and-coastal-habitat-degradation-amrii", "Mangrove and Coastal Habitat Degradation (Amrii)", "Mangrove is a type of tropical tree that grows in Intertidal zones where the coastal areas are between high and low times. They are adapted to harsh conditions such as high…", 5, 1_788_438_342.157),
        preview("drive-11n4cgEZQfX3aylnGtveosYLXlkI7Tc5J", "soil-salinization-seoha", "Soil Salinization (Seoha)", "When people talk about global environmental problems, they often point to melting ice caps, rising oceans, or burning forests. Yet one of the most damaging crises remains…", 2, 1_788_351_684),
        preview("drive-1cVhrMNiAjzQUJVI6BPDbAamUS983lfDG", "seeking-shade-killing-the-coral-reef-sunscreen-chemicals-and-the-crisis-of-coral-bleaching", "Seeking Shade, Killing the Coral Reef: Sunscreen Chemicals and the Crisis of Coral Bleaching (Sooah)", "The perfect tropical holiday image always includes a white sandy beach, a blue-green sea, and a ritual of applying sunscreen to protect your skin from the hot sun. However,…", 3, 1_788_265_226.757),
        preview("drive-1X9e_9I-I1t6q-GHvaFPmKjOnsGcWCX9q", "the-rise-of-microtrends-clothing-waste-edition-yeseo", "The Rise of “Microtrends”: Clothing Waste Edition (YESEO)", "In the past few years, microtrends have become one of the most powerful ways young people get dressed and shop, especially on fast-moving platforms like TikTok, Instagram, and…", 3, 1_788_179_271.180),
        preview("drive-1bue98zpApoinzoiWLzgZQe9hCw41IBQj", "addressing-the-overflow-of-food-delivery-packaging-chaeho-song", "Addressing the Overflow of Food Delivery Packaging (Chaeho Song)", "How often do you deliver? As technology develops and the world proceeds through the pandemic, the use of food delivery has dramatically increased. Today, the market sees over…", 4, 1_788_093_937.597),
        article,
        preview("drive-1sHe_Vm8LumDAn3-02WjWFbcB_NS3OXK2", "lignin-based-materials-in-tires-and-coatings", "Lignin-based materials in tires and coatings", "Lignin, a polymer in plant cell walls that is naturally occurring, could be used as a sustainable ingredient for tires and protective paint coatings. Derived from the residual…", 3, 1_788_081_563.502),
    ]

    static let article = Article(
        documentID: "drive-1WHdIl4RMFNr6FN5hIdoQoGh3CcNeV5rz",
        slug: "pharmaceutical-pollution",
        title: "Pharmaceutical pollution",
        author: nil,
        topic: "Climate",
        excerpt: "Many individuals have previously been prescribed medication, and as of 2021, 64.8% of adults aged 18 and older continued to take prescription medication. However, many…",
        status: "published",
        contentBlocks: [
            .paragraph("Many individuals have previously been prescribed medication, and as of 2021, 64.8% of adults aged 18 and older continued to take prescription medication. However, many individuals are unaware of the proper methods for disposing of their medication after use and often flush unused or expired medications down the toilet or throw them in the trash, not knowing the consequences of pharmaceutical pollution."),
            .paragraph("Pharmaceutical pollution, also known as drug pollution, occurs when pharmaceutical drugs are released into the environment. Pharmaceutical drugs are specifically designed to treat or prevent diseases in individuals. This is easy to see, as they can be prescribed with a note from a healthcare provider, and even Tylenol counts as a type of pharmaceutical drug."),
            .paragraph("Pharmaceutical pollution is a significant environmental issue caused by various factors, including the manufacturing process, agriculture, and more. However, the biggest factor is an action most people have contributed to at some point: throwing away medication improperly. Out of all the factors, this improper disposal significantly contributes to pharmaceutical pollution. Over 100,000 tons of pharmaceutical products are consumed globally each year, and most are discarded into the ocean, impacting marine life. According to the journal “Pharmaceutical Pollution of the World’s Rivers,” by John L. Wilkinson, the study highlights how pharmaceutical products impact aquatic life. The study monitored 1,052 sampling sites along 258 rivers in 104 countries, and out of the 61 targeted active pharmaceutical ingredients (APIs), 53 were detected at least at one sampling site, with the highest concentration being 70.8 µg/L."),
            .paragraph("These statistics show that many pharmaceutical products seep into aquatic environments. However, one small question lingers in our minds: do pharmaceutical drugs actually impact aquatic organisms? Consistent exposure to pharmaceutical products could lead to the “feminization of fish and amphibians.” Feminization is caused by hormonal disruption. Hormonal disruption occurs when pharmaceutical compounds interfere with normal hormone functions in marine organisms. In simple terms, feminization means a reversal of gender roles—where males take on female roles and females take on male roles. Disrupted hormones can lead to reproductive issues and anomalous mating behaviors, which may eventually reduce the populations of affected species."),
            .paragraph("While the feminization of species might not have a direct impact on humans, consuming species exposed to pharmaceutical pollution could lead to antimicrobial resistance. Antimicrobial resistance is when germs develop resistance to drugs designed to kill them. If you eat fish contaminated with a pharmaceutical product, you may experience the same side effects as if you had ingested the drug. Moreover, if you consume too much, you can develop resistance to that drug. This is why there is a limit to how much of a medication can be taken daily. Continued exposure to a particular drug may render it ineffective when you really need it. So, how can we fix this issue? As mentioned earlier, the main reason for pharmaceutical pollution is the improper disposal of medication, meaning that proper disposal methods could significantly reduce pharmaceutical pollution. We should avoid flushing or pouring pharmaceuticals down the drain. MedlinePlus provides guidelines on how to properly dispose of medication: (1) Take the medicine out of its container, (2) mix it with other undesirable garbage, such as kitty litter or used coffee grounds, (3) avoid crushing pills or capsules, (4) place the mixture into a sealable plastic bag or sealed container that won’t leak, and dispose of it in the trash. This small action can go a long way in eliminating pharmaceutical pollution."),
            .paragraph("Plastic waste that we can see with our eyes is causing major problems in the ocean, but we must not forget that issues we cannot see, such as pharmaceutical pollution, are also affecting our oceans are also affecting our oceans."),
            .paragraph("https://www.cdc.gov/mmwr/volumes/72/wr/mm7216a7.htm"),
            .paragraph("https://eeb.org/en/the-problem-of-pharmaceutical-pollution/"),
            .paragraph("https://backtoblueinitiative.com/sea-sickness-the-pharmaceutical-pollution-problem/"),
            .paragraph("https://www.epa.gov/household-medication-disposal/how-pharmaceuticals-enter-environment"),
            .paragraph("https://www.pnas.org/doi/10.1073/pnas.2113947119#con1"),
            .paragraph("https://medlineplus.gov/ency/patientinstructions/000943.htm"),
            .paragraph("https://backtoblueinitiative.com/sea-sickness-the-pharmaceutical-pollution-problem/"),
        ],
        sourceLinks: [],
        externalLinks: nil,
        readingMinutes: 3,
        publishedAt: Date(timeIntervalSince1970: 1_788_082_071.661),
        generation: ArticleGeneration(
            summary: summary,
            suggestedActions: actions,
            visualPlan: VisualPlan(
                searchQuery: "pharmaceutical pollution water testing river",
                altText: "A scientist wearing gloves taking a water sample from a river to test for chemical pollutants.",
                placement: "after-introduction",
                generationPrompt: "Clean editorial illustration of medicine disposal and a protected river"
            )
        ),
        coverAsset: nil
    )

    private static func preview(_ id: String, _ slug: String, _ title: String, _ excerpt: String, _ minutes: Int, _ timestamp: TimeInterval) -> Article {
        Article(documentID: id, slug: slug, title: title, author: nil, topic: "Climate", excerpt: excerpt, status: "published", contentBlocks: [.paragraph(excerpt)], sourceLinks: [], externalLinks: nil, readingMinutes: minutes, publishedAt: Date(timeIntervalSince1970: timestamp), generation: nil, coverAsset: nil)
    }
}
#endif
