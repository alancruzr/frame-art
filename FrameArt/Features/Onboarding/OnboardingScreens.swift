import AVFoundation
import SwiftUI

struct OnboardingScreenFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = geo.size.height >= 700 ? 22 : 16
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    content()
                }
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
                .padding(.vertical, pad)
                .frame(minHeight: max(0, geo.size.height - pad * 2), alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
    }
}

struct OnboardingTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title.weight(.bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .minimumScaleFactor(0.86)
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct OnboardingSubtitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(enabled ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    enabled ? FrameStudioBrand.buttonFill : FrameStudioBrand.softLavender,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .disabled(!enabled)
        .padding(.horizontal, 24)
        .accessibilityLabel(title)
    }
}

struct OnboardingHeroAppIcon: View {
    var size: CGFloat = 158
    var glowSize: CGFloat = 218
    var cornerRadius: CGFloat = 36
    /// Resplandor que respira (paywall), como el de Clarity. Quieto con Reducir movimiento.
    var animated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FrameStudioBrand.accent.opacity(animated ? 0.34 : 0.20),
                            FrameStudioBrand.blue.opacity(animated ? 0.18 : 0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: glowSize / 2
                    )
                )
                .frame(width: glowSize, height: glowSize)
                .blur(radius: animated ? 16 : 10)
                .scaleEffect(breathing ? 1.08 : 0.96)

            Image("OnboardingAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    .white.opacity(0.10),
                                    FrameStudioBrand.accent.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.34), radius: 26, y: 18)
                .shadow(color: FrameStudioBrand.accent.opacity(0.14), radius: 34, y: 12)
        }
        .frame(width: glowSize, height: glowSize)
        .accessibilityLabel("Icono de Frame Studio")
        .onAppear {
            guard animated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) { breathing = true }
        }
    }
}

struct OnboardingChoiceCard: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FrameStudioBrand.accent)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? FrameStudioBrand.accent : .secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(selected ? FrameStudioBrand.softLavender : FrameStudioBrand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? FrameStudioBrand.accent.opacity(0.55) : Color(uiColor: .separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(selected ? "Seleccionado" : "No seleccionado")
    }
}

struct WelcomeScreen: View {
    var store: OnboardingStore

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                OnboardingHeroAppIcon()

                Spacer().frame(height: 30)

                VStack(spacing: 8) {
                    OnboardingTitle(text: "Tu obra, en su pared,\na tamaño real")
                    OnboardingSubtitle(text: "Toma una foto, recorta el lienzo y manda un enlace. El cliente la cuelga en AR, sin instalar la app.")
                }

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Probar con una obra") { store.next() }
                }
                .padding(.top, 34)
            }
        }
    }
}

/// Objetivo + dolor en una sola pantalla (HIG Onboarding: breve y sin memorizar).
struct NeedsScreen: View {
    var store: OnboardingStore
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "¿Qué quieres resolver?")
                    OnboardingSubtitle(text: "Dos toques y te mostramos cómo.")
                }

                Spacer().frame(height: 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Vas a compartir…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(OnboardingGoalID.allCases, id: \.self) { goal in
                            goalChip(goal)
                        }
                    }

                    Text("Lo que más te frena con una foto")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                    ForEach(OnboardingPainID.allCases, id: \.self) { pain in
                        OnboardingChoiceCard(
                            title: pain.title,
                            systemImage: pain.icon,
                            selected: store.selectedPain == pain
                        ) {
                            store.selectPain(pain)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                OnboardingPrimaryButton(title: "Continuar", enabled: store.selectedPain != nil) {
                    store.next()
                }
            }
        }
    }

    private func goalChip(_ goal: OnboardingGoalID) -> some View {
        let selected = store.selectedGoal == goal
        return Button {
            store.selectGoal(goal)
        } label: {
            Label(goal.title, systemImage: goal.systemImage)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? FrameStudioBrand.accent.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selected ? FrameStudioBrand.accent : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
