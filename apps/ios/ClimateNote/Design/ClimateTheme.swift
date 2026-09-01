import SwiftUI

extension Color {
    static let climateSage = Color(red: 0.35, green: 0.53, blue: 0.44)
    static let climateBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.08, blue: 0.07, alpha: 1)
            : UIColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1)
    })
}

struct ClimatePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(Color.climateSage.opacity(configuration.isPressed ? 0.75 : 1), in: .rect(cornerRadius: 15))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
