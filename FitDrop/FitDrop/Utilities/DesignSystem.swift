import SwiftUI

// MARK: - Color Palette

extension Color {
    static let fdAccent = Color("AccentColor")
    static let fdBackground = Color(UIColor.systemBackground)
    static let fdSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let fdGroupedBackground = Color(UIColor.systemGroupedBackground)
    static let fdLabel = Color(UIColor.label)
    static let fdSecondaryLabel = Color(UIColor.secondaryLabel)
    static let fdTertiaryLabel = Color(UIColor.tertiaryLabel)
    static let fdSeparator = Color(UIColor.separator)

    // Brand colors
    static let fdGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let fdOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let fdRed = Color(red: 1.0, green: 0.27, blue: 0.27)
    static let fdBlue = Color(red: 0.20, green: 0.60, blue: 1.0)
    static let fdPurple = Color(red: 0.69, green: 0.40, blue: 0.93)
    static let fdYellow = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let fdIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let fdTeal = Color(red: 0.25, green: 0.78, blue: 0.72)

    // Card gradient pairs
    static let fdGradientStart = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let fdGradientEnd = Color(red: 0.09, green: 0.58, blue: 0.84)
}

// MARK: - Typography

extension Font {
    static let fdLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let fdTitle = Font.system(.title, design: .rounded, weight: .bold)
    static let fdTitle2 = Font.system(.title2, design: .rounded, weight: .semibold)
    static let fdTitle3 = Font.system(.title3, design: .rounded, weight: .semibold)
    static let fdHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let fdBody = Font.system(.body, design: .rounded)
    static let fdCallout = Font.system(.callout, design: .rounded)
    static let fdSubheadline = Font.system(.subheadline, design: .rounded)
    static let fdFootnote = Font.system(.footnote, design: .rounded)
    static let fdCaption = Font.system(.caption, design: .rounded)
    static let fdCaption2 = Font.system(.caption2, design: .rounded)
}

// MARK: - Spacing

enum FDSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum FDRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let card: CGFloat = 16
}

// MARK: - ViewModifiers

struct FDCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.fdSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.card))
    }
}

struct FDShadow: ViewModifier {
    var radius: CGFloat = 8
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.08), radius: radius, x: 0, y: 2)
    }
}

extension View {
    func fdCard() -> some View { modifier(FDCard()) }
    func fdShadow(radius: CGFloat = 8) -> some View { modifier(FDShadow(radius: radius)) }
}

// MARK: - Gradient Helpers

extension LinearGradient {
    static let fdPrimary = LinearGradient(
        colors: [Color.fdGreen, Color.fdBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let fdFire = LinearGradient(
        colors: [Color.fdOrange, Color.fdRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let fdCool = LinearGradient(
        colors: [Color.fdBlue, Color.fdPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let fdNight = LinearGradient(
        colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Reusable Components

struct FDStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.fdTitle3)
                    .foregroundColor(.fdLabel)
                Text(unit)
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow(radius: 4)
    }
}

struct FDProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    let backgroundColor: Color

    init(progress: Double, lineWidth: CGFloat = 12, color: Color = .fdGreen, backgroundColor: Color = .fdSecondaryBackground) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.color = color
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

struct FDBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.fdCaption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct FDPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isLoading = isLoading
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                        .accessibilityLabel("Loading")
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.fdHeadline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(LinearGradient.fdPrimary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
        }
        .accessibilityLabel(isLoading ? "Loading" : title)
        .accessibilityAddTraits(.isButton)
        .disabled(isLoading)
    }
}

struct FDSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "See All"

    var body: some View {
        HStack {
            Text(title)
                .font(.fdTitle3)
            Spacer()
            if let action {
                Button(actionTitle, action: action)
                    .font(.fdSubheadline)
                    .foregroundColor(.fdGreen)
            }
        }
    }
}

// MARK: - Pace Zone Color Helper

extension PaceZone {
    var swiftUIColor: Color {
        switch self {
        case .easy: return .fdGreen
        case .tempo: return .fdOrange
        case .interval: return .fdRed
        case .long: return .fdBlue
        }
    }
}

extension SpeedZone {
    var swiftUIColor: Color {
        switch self {
        case .easy: return .fdGreen
        case .tempo: return .fdOrange
        case .interval: return .fdRed
        case .walk: return .fdBlue
        case .rest: return .fdSecondaryLabel
        }
    }
}

extension FastingStage {
    var swiftUIColor: Color {
        switch self {
        case .digestion: return .fdBlue
        case .fatBurning: return .fdOrange
        case .glucoseDepletion: return .fdYellow
        case .ketosis: return .fdGreen
        case .autophagy: return .fdPurple
        case .deepFast: return .fdIndigo
        }
    }
}
