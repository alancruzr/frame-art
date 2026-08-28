import AVFoundation
import Photos
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
    @State private var advanceTask: Task<Void, Never>?

    private let options: [OnboardingChoice] = [
        OnboardingChoice(id: "painting", title: "Pintura", systemImage: "photo.artframe", iconColor: FrameStudioBrand.gold),
        OnboardingChoice(id: "scan", title: "Escaneo 3D", systemImage: "cube", iconColor: FrameStudioBrand.sapphire),
        OnboardingChoice(id: "both", title: "Ambos", systemImage: "square.on.square", iconColor: FrameStudioBrand.gold)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("¿Qué vas a compartir primero?")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)

                OnboardingChoiceStack(options: options, selectedID: selectedID) { option in
                    select(option.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .onDisappear {
            advanceTask?.cancel()
        }
    }

    private func select(_ id: String) {
        selectedID = id
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            store.next()
        }
    }
}

struct PainScreen: View {
    var store: OnboardingStore
    @State private var selectedID: String?
    @State private var advanceTask: Task<Void, Never>?

    private let options: [OnboardingChoice] = [
        OnboardingChoice(id: "size", title: "El tamaño real", systemImage: "ruler", iconColor: FrameStudioBrand.gold),
        OnboardingChoice(id: "wall", title: "Cómo queda en su pared", systemImage: "rectangle.portrait", iconColor: FrameStudioBrand.sapphire),
        OnboardingChoice(id: "decide", title: "El cliente no se decide", systemImage: "person.crop.circle.badge.questionmark", iconColor: FrameStudioBrand.gold)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("¿Qué se pierde con una foto?")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)

                OnboardingChoiceStack(options: options, selectedID: selectedID) { option in
                    select(option.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .onDisappear {
            advanceTask?.cancel()
        }
    }

    private func select(_ id: String) {
        selectedID = id
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            store.next()
        }
    }
}

struct PermissionsScreen: View {
    var store: OnboardingStore
    @State private var cameraGranted = false
    @State private var photosGranted = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Cámara y fotos")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Para fotografiar la obra y elegirla de la galería. Puedes hacerlo después en Ajustes.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        Button {
                            Task { await requestCamera() }
                        } label: {
                            Label {
                                Text("Cámara")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } icon: {
                                Image(systemName: cameraGranted ? "checkmark.circle.fill" : "camera")
                                    .foregroundStyle(cameraGranted ? FrameStudioBrand.gold : FrameStudioBrand.sapphire)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel("Cámara")
                        .accessibilityValue(cameraGranted ? "Permitido" : "No permitido")

                        Button {
                            Task { await requestPhotos() }
                        } label: {
                            Label {
                                Text("Fotos")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } icon: {
                                Image(systemName: photosGranted ? "checkmark.circle.fill" : "photo.on.rectangle")
                                    .foregroundStyle(photosGranted ? FrameStudioBrand.gold : FrameStudioBrand.sapphire)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel("Fotos")
                        .accessibilityValue(photosGranted ? "Permitido" : "No permitido")
                    }

                    Text("Puedes hacerlo después en Ajustes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            refreshAuthorization()
        }
    }

    private func refreshAuthorization() {
        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let photos = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosGranted = photos == .authorized || photos == .limited
    }

    private func requestCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraGranted = granted
    }

    private func requestPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photosGranted = status == .authorized || status == .limited
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
