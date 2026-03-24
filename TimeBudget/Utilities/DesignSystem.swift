import SwiftUI

// MARK: - Haptics

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Card Modifier

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }
}

struct HeroCardStyle: ViewModifier {
    var padding: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 24, y: 6)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func heroCard(padding: CGFloat = 24) -> some View {
        modifier(HeroCardStyle(padding: padding))
    }
}

// MARK: - Animated Appear Modifier

struct SlideUpAppear: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 12)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func slideUpAppear(index: Int = 0) -> some View {
        modifier(SlideUpAppear(index: index))
    }
}

// MARK: - Premium Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CircleButtonStyle: ButtonStyle {
    let size: CGFloat
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(.secondaryLabel))
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color(.tertiaryLabel))
                .symbolEffect(.pulse.byLayer, options: .repeating, value: isAnimating)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(.secondaryLabel))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Animated Counter

struct AnimatedNumber: View {
    let value: Int
    let font: Font

    var body: some View {
        Text("\(value)")
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}

// MARK: - Chip / Tag

struct ChipView: View {
    let text: String
    let color: Color
    var isSelected: Bool = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isSelected ? color : Color(.secondaryLabel))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Circular Progress

struct CircularProgress: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    var showLabel: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.separator), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: progress)

            if showLabel {
                Text("\(Int(progress * 100))")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: progress))
            }
        }
    }
}
