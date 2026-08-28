import AVFoundation
import SwiftUI

struct WelcomeScreen: View {
    var store: OnboardingStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image("OnboardingAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 160, maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        .accessibilityLabel("Icono de Frame Studio")

                    Text("Ve tu obra en la pared del cliente")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Toma una foto o importa un escaneo 3D. Luego comparte un enlace para que el cliente vea la obra en su pared, en iPhone o Android, sin instalar la app.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }

            Button {
                store.next()
            } label: {
                Text("Continuar")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
            .padding()
        }
    }
}

struct GoalScreen: View {
    var store: OnboardingStore
    @State private var selectedID: String?

    private let options: [OnboardingChoice] = [
        OnboardingChoice(id: "painting", title: "Pintura", systemImage: "photo.artframe", iconColor: FrameStudioBrand.gold),
        OnboardingChoice(id: "scan", title: "Escaneo 3D", systemImage: "cube", iconColor: FrameStudioBrand.sapphire),
        OnboardingChoice(id: "both", title: "Ambos", systemImage: "square.on.square", iconColor: FrameStudioBrand.gold)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("¿Qué vas a compartir primero?")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    OnboardingChoiceStack(options: options, selectedID: selectedID) { option in
                        selectedID = option.id
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Button {
                store.next()
            } label: {
                Text("Continuar")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
            .disabled(selectedID == nil)
            .padding()
        }
    }
}

struct PainScreen: View {
    var store: OnboardingStore
    @State private var selectedID: String?

    private let options: [OnboardingChoice] = [
        OnboardingChoice(id: "size", title: "El tamaño real", systemImage: "ruler", iconColor: FrameStudioBrand.gold),
        OnboardingChoice(id: "wall", title: "Cómo queda en su pared", systemImage: "rectangle.portrait", iconColor: FrameStudioBrand.sapphire),
        OnboardingChoice(id: "decide", title: "El cliente no se decide", systemImage: "person.crop.circle.badge.questionmark", iconColor: FrameStudioBrand.gold)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("¿Qué se pierde con una foto?")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    OnboardingChoiceStack(options: options, selectedID: selectedID) { option in
                        selectedID = option.id
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Button {
                store.next()
            } label: {
                Text("Continuar")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
            .disabled(selectedID == nil)
            .padding()
        }
    }
}

struct PermissionsScreen: View {
    var store: OnboardingStore
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined

    private var cameraGranted: Bool { cameraStatus == .authorized }
    private var cameraBlocked: Bool { cameraStatus == .denied || cameraStatus == .restricted }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Cámara")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Para fotografiar la obra y verla en AR. Las fotos se eligen con el selector del sistema. Puedes hacerlo después en Ajustes.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        Task { await handleCameraTap() }
                    } label: {
                        Label {
                            Text(cameraBlocked ? "Abrir Ajustes" : "Cámara")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } icon: {
                            Image(systemName: cameraGranted ? "checkmark.circle.fill" : (cameraBlocked ? "gear" : "camera"))
                                .foregroundStyle(cameraGranted ? FrameStudioBrand.gold : FrameStudioBrand.sapphire)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel(cameraBlocked ? "Abrir Ajustes" : "Cámara")
                    .accessibilityValue(cameraGranted ? "Permitido" : "No permitido")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Button {
                store.complete()
            } label: {
                Text("Empezar")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
            .padding()
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

private struct OnboardingChoice: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let iconColor: Color
}

private struct OnboardingChoiceStack: View {
    let options: [OnboardingChoice]
    let selectedID: String?
    let onSelect: (OnboardingChoice) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                if index > 0 {
                    Divider()
                }
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.systemImage)
                            .font(.title3)
                            .foregroundStyle(option.iconColor)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        Text(option.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if selectedID == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(FrameStudioBrand.gold)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedID == option.id ? .isSelected : [])
            }
        }
    }
}
