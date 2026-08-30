import SwiftUI

/// Studio name is asked only when someone uses Taller without a name.
struct StudioNameView: View {
    @State private var profile = ArtistProfile.shared
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("¿Cómo se llama tu estudio?")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text("El nombre de tu negocio o perfil. Los clientes lo verán en tu espacio. El enlace usa un slug; si no lo escribes, sale de este nombre o uno al azar.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Taller Luna, Alan Cruz…", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .frame(minHeight: 44)
                        .onChange(of: name) { _, newName in
                            if !slugEdited {
                                applyingName = true
                                slug = ArtistProfile.makeSlug(from: newName)
                                applyingName = false
                            }
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Slug del perfil")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("taller-luna", text: $slug)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .frame(minHeight: 44)
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Button {
                profile.save(displayName: name, slug: slug)
            } label: {
                Text("Continuar")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
            .padding()
        }
        .navigationTitle("Taller")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nameFocused = true
        }
    }
}
