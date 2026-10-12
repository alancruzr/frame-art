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
            .font(.system(size: 28, weight: .bold))
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
            .font(.system(size: 16))
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
                .font(.system(size: 17, weight: .semibold))
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
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(FrameStudioBrand.accent)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
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

struct GoalScreen: View {
    var store: OnboardingStore

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "¿Qué vas a compartir primero?")
                    OnboardingSubtitle(text: "Elige lo más cercano.")
                }

                Spacer().frame(height: 20)

                VStack(spacing: 10) {
                    ForEach(OnboardingGoalID.allCases, id: \.self) { goal in
                        OnboardingChoiceCard(
                            title: goal.title,
                            systemImage: goal.systemImage,
                            selected: store.selectedGoal == goal
                        ) {
                            store.selectGoal(goal)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct PainScreen: View {
    var store: OnboardingStore

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "¿Qué se pierde con una foto de WhatsApp?")
                    OnboardingSubtitle(text: "Elige lo primero que quieres resolver.")
                }

                Spacer().frame(height: 20)

                VStack(spacing: 10) {
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
            }
        }
    }
}

struct ProfileScreen: View {
    var store: OnboardingStore
    @State private var name: String = ArtistProfile.shared.displayName
    @State private var slug: String = ArtistProfile.shared.slug
    @State private var slugEdited = false
    @State private var applyingName = false
    @FocusState private var nameFocused: Bool

    private var slugPreview: String {
        let source = slugEdited ? slug : name
        let made = ArtistProfile.makeSlug(from: source)
        return made.isEmpty ? "se asignará uno al azar" : made
    }

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "¿Cómo se llama tu estudio?")
                    OnboardingSubtitle(text: "Los clientes lo ven en tu espacio. El enlace sale de este nombre, o de un slug al azar.")
                }

                Spacer().frame(height: 24)

                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Nombre del estudio", placeholder: "Taller Luna, Alan Cruz…", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .onChange(of: name) { _, newName in
                            if !slugEdited {
                                applyingName = true
                                slug = ArtistProfile.makeSlug(from: newName)
                                applyingName = false
                            }
                        }

                    field(title: "Slug del perfil", placeholder: "taller-luna", text: $slug)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: slug) { _, newValue in
                            if !applyingName {
                                slugEdited = true
                            }
                            let cleaned = ArtistProfile.makeSlug(from: newValue)
                            if cleaned != newValue {
                                applyingName = true
                                slug = cleaned
                                applyingName = false
                            }
                        }

                    Text("Tu espacio: \(slugPreview)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Vista previa del enlace, \(slugPreview)")
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Continuar") {
                        ArtistProfile.shared.save(displayName: name, slug: slug)
                        store.next()
                    }
                }
                .padding(.top, 18)
            }
        }
        .onAppear {
            nameFocused = true
        }
    }

    private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FrameStudioBrand.accent)
            TextField(placeholder, text: text)
                .foregroundStyle(.primary)
                .padding(14)
                .frame(minHeight: 44)
                .background(FrameStudioBrand.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

