import SwiftUI
import UIKit

// The app deliberately uses a fixed, night-forest publication palette. It keeps
// the reading experience consistent with the printed-editorial visual language.
extension Color {
    static let climateCanvas = Color(red: 0.018, green: 0.082, blue: 0.070)
    static let climateSurface = Color(red: 0.036, green: 0.122, blue: 0.104)
    static let climateSurfaceRaised = Color(red: 0.063, green: 0.175, blue: 0.148)
    static let climateSage = Color(red: 0.694, green: 0.812, blue: 0.650)
    static let climateInk = Color(red: 0.956, green: 0.965, blue: 0.930)
    static let climateMuted = Color(red: 0.692, green: 0.753, blue: 0.720)
    static let climateRule = Color.white.opacity(0.16)
    static let climatePaper = Color(red: 0.965, green: 0.961, blue: 0.941)
    static let climatePaperInk = Color(red: 0.071, green: 0.145, blue: 0.127)
    static let climatePaperMuted = Color(red: 0.260, green: 0.330, blue: 0.304)
    static let climatePaperRule = Color(red: 0.071, green: 0.145, blue: 0.127).opacity(0.16)
    static let climateNotice = Color(red: 0.125, green: 0.255, blue: 0.222)
    static let climateBackground = climateCanvas
}

extension Font {
    static func climateDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title) -> Font {
        Font(ClimateTypography.scaledFont(size: size, relativeTo: textStyle, weight: .regular, serif: true))
    }

    static let climateBody = Font.system(.body, design: .serif)
    static var climateReader: Font {
        Font(ClimateTypography.scaledFont(size: 19, relativeTo: .body, weight: .regular, serif: true))
    }
    static var climateMetadata: Font {
        Font(ClimateTypography.scaledFont(size: 14, relativeTo: .caption, weight: .medium, serif: false))
    }
}

/// Native Dynamic Type typography. UIKit performs the scaling and the modifier
/// receives the live SwiftUI content-size category, so a 44pt title, 19pt
/// reader and 14pt metadata all grow with the user's accessibility setting.
enum ClimateTypography {
    static func scaledFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: UIFont.Weight,
        serif: Bool,
        contentSizeCategory: UIContentSizeCategory? = nil
    ) -> UIFont {
        scaledFont(
            size: size,
            relativeTo: textStyle,
            weight: weight,
            design: serif ? .serif : .default,
            contentSizeCategory: contentSizeCategory
        )
    }

    static func scaledFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: UIFont.Weight,
        design: UIFontDescriptor.SystemDesign,
        contentSizeCategory: UIContentSizeCategory? = nil
    ) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = systemFont.fontDescriptor.withDesign(design) ?? systemFont.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: size)
        let traits = contentSizeCategory.map { UITraitCollection(preferredContentSizeCategory: $0) }
        return UIFontMetrics(forTextStyle: textStyle.uiTextStyle).scaledFont(for: font, compatibleWith: traits)
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}

private extension ContentSizeCategory {
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .extraSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .extraLarge: .extraLarge
        case .extraExtraLarge: .extraExtraLarge
        case .extraExtraExtraLarge: .extraExtraExtraLarge
        case .accessibilityMedium: .accessibilityMedium
        case .accessibilityLarge: .accessibilityLarge
        case .accessibilityExtraLarge: .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

private struct ClimateScaledFontModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    let size: CGFloat
    let relativeTo: Font.TextStyle
    let weight: UIFont.Weight
    let serif: Bool

    func body(content: Content) -> some View {
        content.font(Font(ClimateTypography.scaledFont(
            size: size,
            relativeTo: relativeTo,
            weight: weight,
            serif: serif,
            contentSizeCategory: sizeCategory.uiContentSizeCategory
        )))
    }
}

private struct ClimateScaledDesignFontModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    let size: CGFloat
    let relativeTo: Font.TextStyle
    let weight: UIFont.Weight
    let design: UIFontDescriptor.SystemDesign

    func body(content: Content) -> some View {
        content.font(Font(ClimateTypography.scaledFont(
            size: size,
            relativeTo: relativeTo,
            weight: weight,
            design: design,
            contentSizeCategory: sizeCategory.uiContentSizeCategory
        )))
    }
}

extension View {
    func climateDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title) -> some View {
        modifier(ClimateScaledFontModifier(size: size, relativeTo: textStyle, weight: .regular, serif: true))
    }

    func climateReader() -> some View {
        modifier(ClimateScaledFontModifier(size: 19, relativeTo: .body, weight: .regular, serif: true))
    }

    func climateMetadata(weight: UIFont.Weight = .medium) -> some View {
        modifier(ClimateScaledFontModifier(size: 14, relativeTo: .caption, weight: weight, serif: false))
    }

    /// A slightly firmer New York face for notebook prompts and editorial cards.
    func climateEditorialDisplay(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title,
        weight: UIFont.Weight = .semibold
    ) -> some View {
        modifier(ClimateScaledDesignFontModifier(size: size, relativeTo: textStyle, weight: weight, design: .serif))
    }

    /// SF Rounded gives discovery surfaces a clean, contemporary voice that is
    /// visibly distinct from the private notebook's editorial serif.
    func climateDiscoveryDisplay(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title,
        weight: UIFont.Weight = .semibold
    ) -> some View {
        modifier(ClimateScaledDesignFontModifier(size: size, relativeTo: textStyle, weight: weight, design: .rounded))
    }

    func climateContentWidth(_ maxWidth: CGFloat = 760) -> some View {
        modifier(ClimateContentWidthModifier(maxWidth: maxWidth))
    }
}

private struct ClimateContentWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth, alignment: .leading)
            .padding(.horizontal, horizontalSizeClass == .regular ? ClimateLayout.tabletGutter : ClimateLayout.phoneGutter)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

enum ClimateLayout {
    static let phoneGutter: CGFloat = 24
    static let tabletGutter: CGFloat = 40
    static let compact: CGFloat = 8
    static let element: CGFloat = 16
    static let section: CGFloat = 34
    static let majorSection: CGFloat = 44
    static let cardPadding: CGFloat = 24
    static let controlHeight: CGFloat = 56
    static let minimumTarget: CGFloat = 44
    static let readerMaxWidth: CGFloat = 680
}

enum ClimateRadius {
    static let control: CGFloat = 16
    static let card: CGFloat = 24
    static let image: CGFloat = 18
}

enum ClimateMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let content = Animation.easeOut(duration: 0.20)
}

enum ClimateTab: Int, CaseIterable, Identifiable {
    case home
    case explore
    case write
    case saved

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .explore: "Explore"
        case .write: "Write"
        case .saved: "Saved"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .explore: "magnifyingglass"
        case .write: "plus.circle"
        case .saved: "bookmark"
        }
    }
}

enum ClimateTabBar {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.027, green: 0.102, blue: 0.090, alpha: 1)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(red: 0.692, green: 0.753, blue: 0.720, alpha: 1)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.692, green: 0.753, blue: 0.720, alpha: 1),
            .font: UIFont.preferredFont(forTextStyle: .caption1)
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.659, green: 0.776, blue: 0.612, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.659, green: 0.776, blue: 0.612, alpha: 1),
            .font: UIFont.preferredFont(forTextStyle: .caption1)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension View {
    func climateTabBarChrome() -> some View {
        tint(Color.climateSage)
            .toolbarBackground(Color.climateCanvas, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .onAppear { ClimateTabBar.configure() }
    }
}

enum ClimateLocalArt {
    static func assetName(for article: Article) -> String {
        switch article.slug {
        case "benjamin-jance-iv-cities-the-savior-of-energy-chaeho": "PixabayCity"
        case "the-colorful-reefs-in-finding-nemo-we-grew-up-with-are-a-lie": "PixabayCoral"
        case "disappearance-of-bees": "PixabayBee"
        case "biotic-homogenization": "PixabayCommunity"
        case "mangrove-and-coastal-habitat-degradation-amrii": "PixabayMangrove"
        case "soil-salinization-seoha": "PixabayDrought"
        case "seeking-shade-killing-the-coral-reef-sunscreen-chemicals-and-the-crisis-of-coral-bleaching": "PixabayCoralSecond"
        case "the-rise-of-microtrends-clothing-waste-edition-yeseo": "PixabayTextile"
        case "addressing-the-overflow-of-food-delivery-packaging-chaeho-song": "PixabayPackaging"
        case "pharmaceutical-pollution": "PixabayLaboratory"
        case "lignin-based-materials-in-tires-and-coatings": "PixabayTire"
        default:
            // Unknown articles receive a stable distributed fallback instead of
            // making every new story look like the same one.
            let assets = ["PixabayGlacier", "PixabayCoral", "PixabayWind", "PixabayCity", "PixabayPolar", "PixabayCommunity"]
            let checksum = article.slug.unicodeScalars.reduce(UInt(0)) { ($0 &* 31) &+ UInt($1.value) }
            return assets[Int(checksum % UInt(assets.count))]
        }
    }

}

struct ClimatePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: ClimateLayout.controlHeight)
            .foregroundStyle(isEnabled ? Color.climatePaperInk : Color.climatePaperInk.opacity(0.60))
            .background(Color.climateSage.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.35), in: .rect(cornerRadius: ClimateRadius.control))
            .contentShape(.rect(cornerRadius: ClimateRadius.control))
            .scaleEffect(isEnabled && configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : ClimateMotion.press, value: configuration.isPressed)
    }
}

struct ClimateTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.climateSage.opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.42))
            .frame(minWidth: ClimateLayout.minimumTarget, minHeight: ClimateLayout.minimumTarget)
            .contentShape(.rect)
            .scaleEffect(isEnabled && configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : ClimateMotion.press, value: configuration.isPressed)
    }
}

struct ClimateRule: View {
    var body: some View {
        Rectangle().fill(Color.climateRule).frame(height: 1 / UIScreen.main.scale)
    }
}

struct ClimatePaperRule: View {
    var body: some View {
        Rectangle().fill(Color.climatePaperRule).frame(height: 1 / UIScreen.main.scale)
    }
}

struct ClimateCoverImage: View {
    let url: URL?
    let altText: String
    var assetName: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let assetName {
                Image(assetName).resizable().scaledToFill()
            } else if let url {
                AsyncImage(url: url, transaction: Transaction(animation: reduceMotion ? nil : ClimateMotion.content)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .accessibilityLabel(altText)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.104, green: 0.272, blue: 0.251), Color(red: 0.025, green: 0.102, blue: 0.090)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Color.climateSage.opacity(0.55))
        }
    }
}

struct ClimateSectionHeader: View {
    let eyebrow: String?
    let title: String
    let detail: String?
    var light: Bool = true

    init(_ title: String, eyebrow: String? = nil, detail: String? = nil, light: Bool = true) {
        self.title = title
        self.eyebrow = eyebrow
        self.detail = detail
        self.light = light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .climateMetadata(weight: .bold)
                    .tracking(1.2)
                    .foregroundStyle(light ? Color.climateMuted : Color.climatePaperMuted)
            }
            Text(title)
                .climateDisplay(32, relativeTo: .title)
                .tracking(-0.35)
                .foregroundStyle(light ? Color.climateInk : Color.climatePaperInk)
            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(light ? Color.climateMuted : Color.climatePaperMuted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ClimateStateNotice: View {
    let symbol: String
    let title: String
    let message: String
    var light = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.climateSage)
                .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                .background(Color.climateSage.opacity(0.12), in: .circle)
            Text(title)
                .climateDisplay(28, relativeTo: .title)
                .foregroundStyle(light ? Color.climateInk : Color.climatePaperInk)
            Text(message)
                .font(.body)
                .foregroundStyle(light ? Color.climateMuted : Color.climatePaperMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClimateLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(light ? Color.climateSurfaceRaised : Color.climatePaper)
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(light ? Color.climateRule : Color.climatePaperRule, lineWidth: 1) }
        .clipShape(.rect(cornerRadius: ClimateRadius.card))
    }
}
