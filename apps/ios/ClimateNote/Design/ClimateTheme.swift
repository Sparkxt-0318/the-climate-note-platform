import SwiftUI
import UIKit

/// Brand tokens shared by every Climate Note screen.
/// Light and dark values follow the inspected publication website.
enum ClimateTheme {
    static let pine = Color(red: 18.0 / 255.0, green: 17.0 / 255.0, blue: 14.0 / 255.0)
    static let pineRaised = Color(red: 25.0 / 255.0, green: 26.0 / 255.0, blue: 21.0 / 255.0)
    static let pineInk = Color(red: 242.0 / 255.0, green: 238.0 / 255.0, blue: 228.0 / 255.0)
    static let pineSecondaryInk = Color(red: 201.0 / 255.0, green: 195.0 / 255.0, blue: 181.0 / 255.0)
    static let pineQuietInk = Color(red: 148.0 / 255.0, green: 141.0 / 255.0, blue: 126.0 / 255.0)
    static let mint = Color(red: 127.0 / 255.0, green: 191.0 / 255.0, blue: 156.0 / 255.0)
    static let mintBright = Color(red: 155.0 / 255.0, green: 212.0 / 255.0, blue: 183.0 / 255.0)

    static let canvas = adaptiveColor(
        light: (247.0 / 255.0, 243.0 / 255.0, 236.0 / 255.0),
        // Lifted off pure pine so content and masthead separate in dark.
        dark: (22.0 / 255.0, 20.0 / 255.0, 17.0 / 255.0)
    )
    static let paper = canvas

    static let surface = adaptiveColor(
        light: (241.0 / 255.0, 236.0 / 255.0, 226.0 / 255.0),
        dark: (32.0 / 255.0, 29.0 / 255.0, 24.0 / 255.0)
    )
    static let translucentSurface = surface
    static let readingSurface = canvas
    static let listRowSurface = surface
    static let elevatedSurface = adaptiveColor(
        light: (232.0 / 255.0, 225.0 / 255.0, 212.0 / 255.0),
        dark: (44.0 / 255.0, 40.0 / 255.0, 33.0 / 255.0)
    )

    static let ink = adaptiveColor(
        light: (26.0 / 255.0, 24.0 / 255.0, 21.0 / 255.0),
        dark: (242.0 / 255.0, 238.0 / 255.0, 228.0 / 255.0)
    )
    static let secondaryInk = adaptiveColor(
        light: (70.0 / 255.0, 66.0 / 255.0, 59.0 / 255.0),
        dark: (196.0 / 255.0, 190.0 / 255.0, 176.0 / 255.0)
    )
    static let tertiaryInk = adaptiveColor(
        light: (107.0 / 255.0, 102.0 / 255.0, 89.0 / 255.0),
        dark: (152.0 / 255.0, 145.0 / 255.0, 130.0 / 255.0)
    )

    /// Bright mint belongs on pine; this darker derivative keeps text accessible on ivory.
    static let accent = adaptiveColor(
        light: (47.0 / 255.0, 93.0 / 255.0, 70.0 / 255.0),
        dark: (143.0 / 255.0, 201.0 / 255.0, 168.0 / 255.0)
    )
    static let sage = adaptiveColor(
        light: (72.0 / 255.0, 118.0 / 255.0, 94.0 / 255.0),
        dark: (143.0 / 255.0, 201.0 / 255.0, 168.0 / 255.0)
    )
    static let moss = adaptiveColor(
        light: (58.0 / 255.0, 98.0 / 255.0, 52.0 / 255.0),
        dark: (156.0 / 255.0, 198.0 / 255.0, 118.0 / 255.0)
    )
    static let clay = adaptiveColor(
        light: (168.0 / 255.0, 92.0 / 255.0, 54.0 / 255.0),
        dark: (232.0 / 255.0, 164.0 / 255.0, 118.0 / 255.0)
    )
    static let ochre = adaptiveColor(
        light: (176.0 / 255.0, 124.0 / 255.0, 36.0 / 255.0),
        dark: (236.0 / 255.0, 192.0 / 255.0, 96.0 / 255.0)
    )
    static let onAccent = adaptiveColor(light: (1, 1, 1), dark: (18.0 / 255.0, 19.0 / 255.0, 15.0 / 255.0))

    /// Primary CTAs invert in dark so pills stay visible on near-pine canvas.
    static let primaryAction = adaptiveColor(
        light: (18.0 / 255.0, 17.0 / 255.0, 14.0 / 255.0),
        dark: (242.0 / 255.0, 238.0 / 255.0, 228.0 / 255.0)
    )
    static let onPrimaryAction = adaptiveColor(
        light: (242.0 / 255.0, 238.0 / 255.0, 228.0 / 255.0),
        dark: (18.0 / 255.0, 17.0 / 255.0, 14.0 / 255.0)
    )

    // Native semantic additions, not website brand colors.
    static let success = accent
    static let warning = adaptiveColor(light: (122.0 / 255.0, 75.0 / 255.0, 12.0 / 255.0), dark: (236.0 / 255.0, 192.0 / 255.0, 112.0 / 255.0))
    static let error = adaptiveColor(light: (160.0 / 255.0, 45.0 / 255.0, 40.0 / 255.0), dark: (245.0 / 255.0, 159.0 / 255.0, 149.0 / 255.0))
    static let divider = adaptiveColor(
        light: (174.0 / 255.0, 163.0 / 255.0, 141.0 / 255.0),
        dark: (72.0 / 255.0, 66.0 / 255.0, 56.0 / 255.0)
    )
    static let pineDivider = Color.white.opacity(0.14)

    /// Apply once at launch so pine chrome keeps readable unselected controls.
    static func configureChromeAppearance() {
        let pine = UIColor(red: 18.0 / 255.0, green: 17.0 / 255.0, blue: 14.0 / 255.0, alpha: 1)
        let idle = UIColor(red: 201.0 / 255.0, green: 195.0 / 255.0, blue: 181.0 / 255.0, alpha: 1)
        let selected = UIColor(red: 155.0 / 255.0, green: 212.0 / 255.0, blue: 183.0 / 255.0, alpha: 1)

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = pine
        tab.shadowColor = UIColor.white.withAlphaComponent(0.08)
        let tabItem = UITabBarItemAppearance()
        tabItem.normal.iconColor = idle
        tabItem.normal.titleTextAttributes = [.foregroundColor: idle]
        tabItem.selected.iconColor = selected
        tabItem.selected.titleTextAttributes = [.foregroundColor: selected]
        tab.stackedLayoutAppearance = tabItem
        tab.inlineLayoutAppearance = tabItem
        tab.compactInlineLayoutAppearance = tabItem
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = selected
        UITabBar.appearance().unselectedItemTintColor = idle
    }

    enum Typography {
        private static let geistName = "Geist-Regular"
        private static let geistMonoName = "GeistMono-Regular"
        private static let newsreaderName = "Newsreader16pt-Regular"

        private static func geist(
            size: CGFloat,
            relativeTo style: Font.TextStyle,
            weight: Font.Weight = .regular
        ) -> Font {
            .custom(geistName, size: size, relativeTo: style).weight(weight)
        }

        private static func mono(
            size: CGFloat,
            relativeTo style: Font.TextStyle,
            weight: Font.Weight = .regular
        ) -> Font {
            .custom(geistMonoName, size: size, relativeTo: style).weight(weight)
        }

        private static func newsreader(
            size: CGFloat,
            relativeTo style: Font.TextStyle,
            weight: Font.Weight = .regular
        ) -> Font {
            .custom(newsreaderName, size: size, relativeTo: style).weight(weight)
        }

        /// Type ladder for chrome screens (Read / My Note / Account):
        /// pageTitle 34 → feedHeadline 26 → sectionTitle 20 → rowTitle 18 →
        /// panelBody/pageSubtitle 17 → subheadline 15 → caption 13 → metadata 12.
        /// Newsreader is reserved for in-article reading; Geist owns UI chrome.
        static let articleTitle = newsreader(size: 32, relativeTo: .largeTitle, weight: .semibold)
        static let leadTitle = newsreader(size: 28, relativeTo: .title, weight: .semibold)
        static let display = articleTitle
        static let displayCompact = geist(size: 30, relativeTo: .title, weight: .semibold)
        /// Shared page title for Read, My Note, and Account.
        static let pageTitle = geist(size: 34, relativeTo: .largeTitle, weight: .semibold)
        static let feedHeading = pageTitle
        static let myNoteTitle = pageTitle
        /// Supporting line under a page title.
        static let pageSubtitle = geist(size: 17, relativeTo: .body)
        /// Featured story title on Read (discovery, not in-article).
        static let feedHeadline = geist(size: 26, relativeTo: .title2, weight: .semibold)
        /// Panel and list section headers.
        static let sectionTitle = geist(size: 20, relativeTo: .title2, weight: .semibold)
        /// Entry, archive, and identity titles inside lists/panels.
        static let rowTitle = geist(size: 18, relativeTo: .headline, weight: .semibold)
        static let leadDeck = newsreader(size: 18, relativeTo: .body)
        static let readingDeck = newsreader(size: 20, relativeTo: .title3)
        static let readingBody = newsreader(size: 18, relativeTo: .body)
        static let readingHeading = geist(size: 24, relativeTo: .title2, weight: .bold)
        static let readingSubheadline = newsreader(size: 15, relativeTo: .subheadline)
        static let navTitle = geist(size: 16, relativeTo: .headline, weight: .bold)
        static let headline = geist(size: 17, relativeTo: .headline, weight: .semibold)
        static let body = geist(size: 17, relativeTo: .body)
        static let bodyStrong = geist(size: 17, relativeTo: .body, weight: .semibold)
        /// Panel descriptions and secondary UI copy.
        static let callout = geist(size: 17, relativeTo: .callout)
        static let panelBody = callout
        static let subheadline = geist(size: 15, relativeTo: .subheadline)
        static let subheadlineStrong = geist(size: 15, relativeTo: .subheadline, weight: .semibold)
        static let caption = geist(size: 13, relativeTo: .caption)
        static let captionStrong = geist(size: 13, relativeTo: .caption, weight: .semibold)
        static let eyebrow = mono(size: 12, relativeTo: .caption2, weight: .medium)
        static let metadata = mono(size: 12, relativeTo: .caption2)
        static let metadataStrong = mono(size: 13, relativeTo: .caption, weight: .medium)
        /// Editorial masthead — white Newsreader on pine, no mono mark.
        static let wordmark = newsreader(size: 17, relativeTo: .headline, weight: .medium)
        static let brandMark = newsreader(size: 28, relativeTo: .title, weight: .medium)
        static let shareLabel = newsreader(size: 14, relativeTo: .subheadline, weight: .medium)
        static let calendarWeekday = mono(size: 11, relativeTo: .caption2)
        static let calendarDay = mono(size: 15, relativeTo: .subheadline, weight: .semibold)
        /// Primary CTAs use serif to match the publication chrome.
        static let button = newsreader(size: 17, relativeTo: .headline, weight: .medium)
        static let metric = mono(size: 36, relativeTo: .largeTitle, weight: .bold)
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let compact: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
        static let hero: CGFloat = 56
    }

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 10
        static let large: CGFloat = 18
        /// Story covers and archive thumbs — soft editorial round.
        static let image: CGFloat = 14
    }

    enum ContentWidth {
        static let feed: CGFloat = 720
        static let reading: CGFloat = 680
        static let empty: CGFloat = 560
        static let authentication: CGFloat = 500
    }

    enum IconSize {
        static let small: CGFloat = 16
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
    }

    static let minimumTapTarget: CGFloat = 44

    enum Motion {
        static let quickPress = Animation.easeOut(duration: 0.12)
        static let standardState = Animation.easeInOut(duration: 0.22)
        static let contentEntrance = Animation.easeOut(duration: 0.36)
        static let springResponse = Animation.spring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.08)
    }

    private static func adaptiveColor(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let components = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: components.0,
                green: components.1,
                blue: components.2,
                alpha: 1
            )
        })
    }
}

/// An opaque app canvas. Photography belongs to an individual story only.
struct ClimateBackdrop: View {
    var body: some View {
        ClimateTheme.canvas
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Compact, reusable heading for everyday reading and settings screens.
struct ClimatePageHeader: View {
    let title: String
    let subtitle: String
    var titleFont: Font = ClimateTheme.Typography.pageTitle

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.compact) {
            Text(title)
                .font(titleFont)
                .tracking(-0.6)
                .foregroundStyle(ClimateTheme.ink)
                .accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(ClimateTheme.Typography.pageSubtitle)
                    .foregroundStyle(ClimateTheme.secondaryInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, ClimateTheme.Spacing.small)
    }
}

/// Quiet section label — small caps energy without shouting over story titles.
struct ClimateQuietLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ClimateTheme.Typography.captionStrong)
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(ClimateTheme.secondaryInk)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ClimateInlineStatus: View {
    enum Kind {
        case information, success, warning, error

        var color: Color {
            switch self {
            case .information: ClimateTheme.secondaryInk
            case .success: ClimateTheme.success
            case .warning: ClimateTheme.warning
            case .error: ClimateTheme.error
            }
        }

        var symbol: String {
            switch self {
            case .information: "info.circle"
            case .success: "checkmark.circle"
            case .warning: "exclamationmark.triangle"
            case .error: "exclamationmark.circle"
            }
        }
    }

    let message: String
    var kind: Kind = .information

    var body: some View {
        HStack(alignment: .top, spacing: ClimateTheme.Spacing.small) {
            Image(systemName: kind.symbol)
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(ClimateTheme.Typography.subheadline)
        .foregroundStyle(kind.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClimateTheme.Spacing.compact)
        .background(ClimateTheme.surface, in: .rect(cornerRadius: ClimateTheme.Radius.small))
        .accessibilityElement(children: .combine)
    }
}

struct ClimateWordmark: View {
    var foreground: Color = ClimateTheme.pineInk
    var size: WordmarkSize = .nav

    enum WordmarkSize {
        case nav
        case brand

        var font: Font {
            switch self {
            case .nav: ClimateTheme.Typography.wordmark
            case .brand: ClimateTheme.Typography.brandMark
            }
        }
    }

    var body: some View {
        Text("The Climate Note")
            .font(size.font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(minHeight: size == .nav ? 44 : nil, alignment: .leading)
            .accessibilityLabel("The Climate Note")
    }
}

struct ClimateEyebrow: View {
    let text: String
    var color: Color = ClimateTheme.accent
    /// Editorial metadata may keep small-caps tracking without shouting every label.
    var transformsCase: Bool = false

    var body: some View {
        Text(transformsCase ? text.uppercased() : text)
            .font(ClimateTheme.Typography.eyebrow)
            .tracking(transformsCase ? 1.25 : 0.4)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shared section title used on Read, My Note, and Account.
struct ClimateSectionHeader: View {
    let title: String
    var caption: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
            Text(title)
                .font(ClimateTheme.Typography.sectionTitle)
                .tracking(-0.35)
                .foregroundStyle(ClimateTheme.ink)
                .accessibilityAddTraits(.isHeader)
            if !caption.isEmpty {
                Text(caption)
                    .font(ClimateTheme.Typography.subheadline)
                    .foregroundStyle(ClimateTheme.tertiaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Distinct section panel so screens don’t collapse into a single text column.
struct ClimatePanel<Content: View>: View {
    var title: String = ""
    var caption: String = ""
    var radius: CGFloat = ClimateTheme.Radius.large
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            if !title.isEmpty {
                ClimateSectionHeader(title: title, caption: caption)
            }
            content()
        }
        .padding(ClimateTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClimateTheme.surface, in: .rect(cornerRadius: radius))
        .overlay {
            RoundedRectangle(cornerRadius: radius)
                .stroke(ClimateTheme.divider.opacity(0.65), lineWidth: 1)
        }
    }
}

/// Soft fill without a border—used when a panel already provides structure.
struct ClimateQuietSurfaceModifier: ViewModifier {
    var radius: CGFloat = ClimateTheme.Radius.medium

    func body(content: Content) -> some View {
        content
            .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: radius))
    }
}

private struct ClimateMotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var climateMotionEnabled: Bool {
        get { self[ClimateMotionEnabledKey.self] }
        set { self[ClimateMotionEnabledKey.self] = newValue }
    }
}

private struct ClimateEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.climateMotionEnabled) private var motionEnabled
    @State private var isVisible = false

    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || reduceMotion || !motionEnabled ? 1 : 0)
            .offset(y: isVisible || reduceMotion || !motionEnabled ? 0 : 10)
            .onAppear {
                guard !isVisible else { return }
                guard motionEnabled && !reduceMotion else {
                    isVisible = true
                    return
                }
                withAnimation(ClimateTheme.Motion.contentEntrance.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

private struct ClimatePinePanelModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(ClimateTheme.pineRaised, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(ClimateTheme.pineDivider, lineWidth: 1)
            }
    }
}

private struct ClimateSheetModifier: ViewModifier {
    let radius: CGFloat
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(isSelected ? ClimateTheme.accent.opacity(0.10) : ClimateTheme.surface, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(isSelected ? ClimateTheme.accent : ClimateTheme.divider, lineWidth: 1)
            }
    }
}

extension View {
    func climateEntrance(delay: Double = 0) -> some View {
        modifier(ClimateEntranceModifier(delay: delay))
    }

    func climatePinePanel(radius: CGFloat = ClimateTheme.Radius.large) -> some View {
        modifier(ClimatePinePanelModifier(radius: radius))
    }

    func climateSheet(radius: CGFloat = ClimateTheme.Radius.large, isSelected: Bool = false) -> some View {
        modifier(ClimateSheetModifier(radius: radius, isSelected: isSelected))
    }

    func climateQuietSurface(radius: CGFloat = ClimateTheme.Radius.medium) -> some View {
        modifier(ClimateQuietSurfaceModifier(radius: radius))
    }
}

extension Color {
    static let climateSage = ClimateTheme.accent
    static let climateBackground = ClimateTheme.canvas
}

struct ClimatePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ClimateTheme.Typography.button)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, ClimateTheme.Spacing.compact)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, ClimateTheme.Spacing.large)
            .foregroundStyle(ClimateTheme.onPrimaryAction)
            .background(
                isEnabled
                    ? ClimateTheme.primaryAction.opacity(configuration.isPressed ? 0.88 : 1)
                    : ClimateTheme.tertiaryInk,
                in: .capsule
            )
            .opacity(isEnabled ? 1 : 0.58)
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : ClimateTheme.Motion.quickPress, value: configuration.isPressed)
    }
}

struct ClimateArticleLinkStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.5)
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.988 : 1)
            .animation(reduceMotion ? nil : ClimateTheme.Motion.quickPress, value: configuration.isPressed)
    }
}

struct ClimateSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ClimateTheme.Typography.button)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, ClimateTheme.Spacing.small)
            .frame(maxWidth: .infinity)
            .frame(minHeight: ClimateTheme.minimumTapTarget)
            .padding(.horizontal, ClimateTheme.Spacing.medium)
            .foregroundStyle(ClimateTheme.ink)
            .background(ClimateTheme.elevatedSurface.opacity(configuration.isPressed ? 0.76 : 1), in: .capsule)
            .overlay {
                Capsule()
                    .stroke(ClimateTheme.ink.opacity(0.28), lineWidth: 1.5)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.5)
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : ClimateTheme.Motion.quickPress, value: configuration.isPressed)
    }
}
