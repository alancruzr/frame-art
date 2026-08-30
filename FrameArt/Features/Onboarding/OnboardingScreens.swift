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
            .foregroundStyle(.white)
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
            .foregroundStyle(.white.opacity(0.65))
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
                .foregroundStyle(FrameStudioBrand.hunter)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    FrameStudioBrand.gold.opacity(enabled ? 1 : 0.4),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .disabled(!enabled)
        .padding(.horizontal, 24)
        .accessibilityLabel(title)
    }
}

private struct OnboardingHeroAppIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FrameStudioBrand.gold.opacity(0.28),
                            FrameStudioBrand.gold.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 109
                    )
                )
                .frame(width: 218, height: 218)
                .blur(radius: 10)

            Image("OnboardingAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 158, height: 158)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    .white.opacity(0.10),
                                    FrameStudioBrand.gold.opacity(0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.34), radius: 26, y: 18)
                .shadow(color: FrameStudioBrand.gold.opacity(0.24), radius: 34, y: 12)
        }
        .frame(width: 218, height: 218)
        .accessibilityLabel("Icono de Frame Studio")
    }
}

private struct OnboardingChoiceCard: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(FrameStudioBrand.gold)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? FrameStudioBrand.gold : .white.opacity(0.3))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(selected ? FrameStudioBrand.gold.opacity(0.18) : Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? FrameStudioBrand.gold.opacity(0.5) : .clear, lineWidth: 1)
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
                    OnboardingPrimaryButton(title: "Empezar") { store.next() }
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

struct SolutionScreen: View {
    var store: OnboardingStore

    private var pain: OnboardingPainID { store.resolvedPain }

    private var rows: [(icon: String, label: String, text: String)] {
        [
            (pain.icon, "Lo que se pierde", pain.problem),
            ("sparkles", "Cómo ayuda Frame Studio", pain.action),
            ("checkmark.circle.fill", "Qué se vuelve más fácil", pain.outcome)
        ]
    }

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "Frame Studio está hecho\npara ese momento")
                    OnboardingSubtitle(text: "Cuando la obra está lista, pero en una foto no se entiende.")
                }

                Spacer().frame(height: 24)

                VStack(spacing: 14) {
                    ForEach(rows, id: \.label) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(FrameStudioBrand.gold)
                                .frame(width: 44)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(FrameStudioBrand.gold)
                                Text(item.text)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Continuar") { store.next() }
                }
                .padding(.top, 18)
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
                        .foregroundStyle(.white.opacity(0.55))
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
                .foregroundStyle(FrameStudioBrand.gold)
            TextField(placeholder, text: text)
                .foregroundStyle(.white)
                .padding(14)
                .frame(minHeight: 44)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct PermissionsScreen: View {
    var store: OnboardingStore
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined

    private var cameraGranted: Bool { cameraStatus == .authorized }
    private var cameraBlocked: Bool { cameraStatus == .denied || cameraStatus == .restricted }

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "Cámara para fotografiar\nla obra")
                    OnboardingSubtitle(text: "También para verla en AR. Las fotos de la galería se eligen con el selector del sistema.")
                }

                Spacer().frame(height: 24)

                Button {
                    Task { await handleCameraTap() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: cameraGranted ? "checkmark.circle.fill" : (cameraBlocked ? "gear" : "camera.fill"))
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(FrameStudioBrand.gold)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cameraBlocked ? "Abrir Ajustes" : "Cámara")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                            Text(cameraGranted ? "Permitida" : "Para la foto y el AR")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(cameraGranted ? FrameStudioBrand.gold.opacity(0.18) : Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(cameraGranted ? FrameStudioBrand.gold.opacity(0.5) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .accessibilityLabel(cameraBlocked ? "Abrir Ajustes" : "Cámara")
                .accessibilityValue(cameraGranted ? "Permitido" : "No permitido")

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Entrar al taller") { store.complete() }
                }
                .padding(.top, 34)
            }
        }
        .onAppear {
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    private func handleCameraTap() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? .authorized : .denied
        case .denied, .restricted:
            FrameStudioSettings.open()
        default:
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}
