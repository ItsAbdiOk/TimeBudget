import SwiftUI

struct OnboardingFlow: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isRequestingPermission = false
    @State private var permissionGranted = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 1: Welcome
                OnboardingPage(
                    icon: "clock.fill",
                    iconColor: Color(.systemBlue),
                    title: "Budget Your Time",
                    subtitle: "Track how you spend every hour — automatically. Set goals, spot patterns, and make every day count.",
                    buttonTitle: "Continue",
                    action: {
                        Haptics.medium()
                        withAnimation(.easeOut(duration: 0.4)) {
                            currentPage = 1
                        }
                    }
                )
                .tag(0)

                // Page 2: What we track
                OnboardingPage(
                    icon: "heart.text.square.fill",
                    iconColor: Color(.systemPink),
                    title: "Passive Tracking",
                    subtitle: "TimeBudget reads your sleep, workouts, steps, location, and calendar — all from data your iPhone and Apple Watch already collect.",
                    buttonTitle: "Continue",
                    action: {
                        Haptics.medium()
                        withAnimation(.easeOut(duration: 0.4)) {
                            currentPage = 2
                        }
                    }
                )
                .tag(1)

                // Page 3: Permissions
                PermissionPage(
                    isRequestingPermission: $isRequestingPermission,
                    permissionGranted: $permissionGranted,
                    onComplete: { hasCompletedOnboarding = true }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom page indicator
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { page in
                        Capsule()
                            .fill(page == currentPage ? Color(.systemBlue) : Color(.separator))
                            .frame(width: page == currentPage ? 24 : 8, height: 8)
                            .animation(.easeOut(duration: 0.4), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Onboarding Page

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    @State private var iconAppeared = false
    @State private var textAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconAppeared ? 1.0 : 0.5)

                Image(systemName: icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(iconAppeared ? 1.0 : 0.3)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: iconAppeared)

            Spacer().frame(height: 32)

            // Text
            VStack(spacing: 12) {
                Text(title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color(.label))

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: textAppeared ? 0 : 20)
            .opacity(textAppeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.2), value: textAppeared)

            Spacer()

            // Button
            Button(action: action) {
                Text(buttonTitle)
            }
            .buttonStyle(PrimaryButtonStyle(color: iconColor))
            .padding(.horizontal, 24)

            Spacer().frame(height: 60)
        }
        .onAppear {
            iconAppeared = true
            textAppeared = true
        }
        .onDisappear {
            iconAppeared = false
            textAppeared = false
        }
    }
}

// MARK: - Permission Page

private struct PermissionPage: View {
    @Binding var isRequestingPermission: Bool
    @Binding var permissionGranted: Bool
    let onComplete: () -> Void

    @State private var iconAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(.systemGreen).opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconAppeared ? 1.0 : 0.5)

                Image(systemName: permissionGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color(.systemGreen))
                    .scaleEffect(iconAppeared ? 1.0 : 0.3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: iconAppeared)

            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                Text("Your Data Stays Private")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color(.label))

                Text("All data stays on your device. We need permission to read health data — we never write or share it.")
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            if permissionGranted {
                Button {
                    Haptics.success()
                    onComplete()
                } label: {
                    Text("Get Started")
                }
                .buttonStyle(PrimaryButtonStyle(color: Color(.systemBlue)))
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    Button {
                        Haptics.medium()
                        isRequestingPermission = true
                        Task {
                            do {
                                try await HealthKitService.shared.requestAuthorization()
                                permissionGranted = true
                            } catch {
                                permissionGranted = true
                            }
                            isRequestingPermission = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRequestingPermission {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Allow Health Access")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Color(.systemGreen)))
                    .disabled(isRequestingPermission)
                    .padding(.horizontal, 24)

                    Button("Skip for Now") {
                        Haptics.light()
                        onComplete()
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }

            Spacer().frame(height: 60)
        }
        .onAppear { iconAppeared = true }
        .onDisappear { iconAppeared = false }
        .animation(.easeOut(duration: 0.4), value: permissionGranted)
    }
}
