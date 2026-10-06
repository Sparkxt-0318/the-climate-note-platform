import SwiftUI
import UIKit

/// Editorial signature covers when a licensed photo is missing or still in review.
/// Each topic gets a deterministic palette and mark so the archive feels authored,
/// not like generic stock placeholders. Replace with commissioned art by shipping
/// assets named `Signature/<TopicSlug>` in the asset catalog—those take priority.
struct SignatureCoverArt: View {
    let topic: String
    let title: String
    var height: CGFloat = 196
    var compact: Bool = false

    private var style: SignatureStyle { SignatureStyle.forTopic(topic) }

    var body: some View {
        ZStack {
            if let named = UIImage(named: style.assetName) {
                Image(uiImage: named)
                    .resizable()
                    .scaledToFill()
            } else {
                generatedArt
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(.rect(cornerRadius: ClimateTheme.Radius.image))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Signature cover for \(topic.isEmpty ? "climate" : topic): \(title)")
    }

    private var generatedArt: some View {
        ZStack(alignment: compact ? .center : .bottomLeading) {
            LinearGradient(
                colors: [style.top, style.mid, style.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                Circle()
                    .fill(style.accent.opacity(0.32))
                    .frame(width: geo.size.width * 0.72, height: geo.size.width * 0.72)
                    .offset(x: geo.size.width * 0.42, y: -geo.size.height * 0.28)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(style.accent.opacity(0.18))
                    .rotationEffect(.degrees(-18))
                    .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.55)
                    .offset(x: -geo.size.width * 0.18, y: geo.size.height * 0.42)
                Circle()
                    .fill(style.highlight.opacity(0.22))
                    .frame(width: geo.size.width * 0.28, height: geo.size.width * 0.28)
                    .offset(x: geo.size.width * 0.08, y: geo.size.height * 0.12)
            }
            .allowsHitTesting(false)

            // Title lives in the type hierarchy below the art — never stamp it
            // on the cover or the feed reads the headline twice.
            if compact {
                Image(systemName: style.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            } else {
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                    Image(systemName: style.symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                    Text(topic.isEmpty ? "Climate" : topic)
                        .font(ClimateTheme.Typography.captionStrong)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(ClimateTheme.Spacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }
}

private struct SignatureStyle {
    let top: Color
    let mid: Color
    let bottom: Color
    let accent: Color
    let highlight: Color
    let symbol: String
    let assetName: String

    static func forTopic(_ topic: String) -> SignatureStyle {
        let key = topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let slug = key
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let palette = catalog[key] ?? alias[key].flatMap { catalog[$0] } ?? fallbackPalette(for: key)
        return SignatureStyle(
            top: palette.top,
            mid: palette.mid,
            bottom: palette.bottom,
            accent: palette.accent,
            highlight: palette.highlight,
            symbol: palette.symbol,
            assetName: "Signature/\(slug.isEmpty ? "climate" : slug)"
        )
    }

    private struct Palette {
        let top: Color
        let mid: Color
        let bottom: Color
        let accent: Color
        let highlight: Color
        let symbol: String
    }

    private static let alias: [String: String] = [
        "ocean": "oceans",
        "reefs": "coral",
        "reef": "coral",
        "waste": "materials",
        "packaging": "materials",
        "fashion": "materials",
        "city": "cities",
        "agriculture": "food",
        "soil": "food",
        "bees": "wildlife",
        "biodiversity": "wildlife",
        "nature": "wildlife",
        "mangrove": "coastal",
        "habitat": "coastal",
    ]

    private static func fallbackPalette(for key: String) -> Palette {
        let options = Array(catalog.values)
        let index = abs(key.hashValue) % max(options.count, 1)
        return options.isEmpty
            ? Palette(
                top: Color(red: 0.22, green: 0.42, blue: 0.34),
                mid: Color(red: 0.14, green: 0.30, blue: 0.24),
                bottom: Color(red: 0.08, green: 0.16, blue: 0.13),
                accent: Color(red: 0.50, green: 0.78, blue: 0.58),
                highlight: Color(red: 0.72, green: 0.88, blue: 0.62),
                symbol: "globe.americas.fill"
            )
            : options[index]
    }

    private static let catalog: [String: Palette] = [
        "water": Palette(
            top: Color(red: 0.22, green: 0.58, blue: 0.68),
            mid: Color(red: 0.14, green: 0.42, blue: 0.52),
            bottom: Color(red: 0.08, green: 0.26, blue: 0.36),
            accent: Color(red: 0.45, green: 0.86, blue: 0.90),
            highlight: Color(red: 0.70, green: 0.92, blue: 0.95),
            symbol: "drop.fill"
        ),
        "oceans": Palette(
            top: Color(red: 0.12, green: 0.48, blue: 0.72),
            mid: Color(red: 0.08, green: 0.32, blue: 0.58),
            bottom: Color(red: 0.04, green: 0.16, blue: 0.38),
            accent: Color(red: 0.35, green: 0.78, blue: 0.95),
            highlight: Color(red: 0.55, green: 0.88, blue: 0.98),
            symbol: "water.waves"
        ),
        "coral": Palette(
            top: Color(red: 0.92, green: 0.42, blue: 0.48),
            mid: Color(red: 0.72, green: 0.28, blue: 0.42),
            bottom: Color(red: 0.28, green: 0.42, blue: 0.58),
            accent: Color(red: 1.0, green: 0.72, blue: 0.55),
            highlight: Color(red: 0.45, green: 0.82, blue: 0.88),
            symbol: "fish.fill"
        ),
        "materials": Palette(
            top: Color(red: 0.82, green: 0.52, blue: 0.28),
            mid: Color(red: 0.58, green: 0.34, blue: 0.18),
            bottom: Color(red: 0.32, green: 0.18, blue: 0.12),
            accent: Color(red: 0.95, green: 0.78, blue: 0.48),
            highlight: Color(red: 0.98, green: 0.88, blue: 0.68),
            symbol: "cube.fill"
        ),
        "energy": Palette(
            top: Color(red: 0.95, green: 0.68, blue: 0.18),
            mid: Color(red: 0.82, green: 0.42, blue: 0.12),
            bottom: Color(red: 0.42, green: 0.18, blue: 0.08),
            accent: Color(red: 1.0, green: 0.86, blue: 0.35),
            highlight: Color(red: 1.0, green: 0.94, blue: 0.62),
            symbol: "bolt.fill"
        ),
        "food": Palette(
            top: Color(red: 0.48, green: 0.68, blue: 0.28),
            mid: Color(red: 0.32, green: 0.48, blue: 0.20),
            bottom: Color(red: 0.18, green: 0.28, blue: 0.12),
            accent: Color(red: 0.72, green: 0.88, blue: 0.42),
            highlight: Color(red: 0.88, green: 0.95, blue: 0.62),
            symbol: "leaf.fill"
        ),
        "cities": Palette(
            top: Color(red: 0.42, green: 0.48, blue: 0.62),
            mid: Color(red: 0.24, green: 0.28, blue: 0.38),
            bottom: Color(red: 0.10, green: 0.12, blue: 0.18),
            accent: Color(red: 0.78, green: 0.82, blue: 0.92),
            highlight: Color(red: 0.92, green: 0.72, blue: 0.42),
            symbol: "building.2.fill"
        ),
        "wildlife": Palette(
            top: Color(red: 0.95, green: 0.72, blue: 0.22),
            mid: Color(red: 0.72, green: 0.48, blue: 0.14),
            bottom: Color(red: 0.32, green: 0.42, blue: 0.18),
            accent: Color(red: 1.0, green: 0.88, blue: 0.42),
            highlight: Color(red: 0.62, green: 0.82, blue: 0.38),
            symbol: "ladybug.fill"
        ),
        "coastal": Palette(
            top: Color(red: 0.18, green: 0.58, blue: 0.52),
            mid: Color(red: 0.12, green: 0.40, blue: 0.38),
            bottom: Color(red: 0.08, green: 0.22, blue: 0.28),
            accent: Color(red: 0.48, green: 0.88, blue: 0.78),
            highlight: Color(red: 0.72, green: 0.94, blue: 0.86),
            symbol: "tree.fill"
        ),
        "climate": Palette(
            top: Color(red: 0.28, green: 0.52, blue: 0.40),
            mid: Color(red: 0.16, green: 0.34, blue: 0.28),
            bottom: Color(red: 0.08, green: 0.18, blue: 0.15),
            accent: Color(red: 0.55, green: 0.82, blue: 0.62),
            highlight: Color(red: 0.78, green: 0.92, blue: 0.72),
            symbol: "globe.americas.fill"
        ),
    ]
}
