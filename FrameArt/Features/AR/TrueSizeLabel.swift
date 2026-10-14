import SwiftUI

/// Etiqueta "W × H cm" sobre la escena AR: refuerza que la obra está a tamaño real
/// (HIG Augmented reality: no escalar objetos que representan cosas reales).
struct TrueSizeLabel: View {
    let widthCentimeters: Double
    let heightCentimeters: Double

    var body: some View {
        Label(MeasureFormat.size(width: widthCentimeters, height: heightCentimeters), systemImage: "ruler")
            .font(.footnote.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .accessibilityLabel("Tamaño real: \(MeasureFormat.spoken(width: widthCentimeters, height: heightCentimeters))")
    }
}

/// Formato de medidas compartido (la unidad preferida se añade en MeasureUnit).
enum MeasureFormat {
    static func size(width: Double, height: Double) -> String {
        MeasureUnit.current.format(width: width, height: height)
    }

    static func spoken(width: Double, height: Double) -> String {
        let unit = MeasureUnit.current
        return "\(unit.number(width)) por \(unit.number(height)) \(unit.spokenName)"
    }
}

enum MeasureUnit: String, CaseIterable, Identifiable, Sendable {
    case centimeters = "cm"
    case inches = "in"

    static let storageKey = "measureUnit"
    static let cmPerInch = 2.54

    var id: String { rawValue }

    static var current: MeasureUnit {
        MeasureUnit(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .centimeters
    }

    var spokenName: String { self == .centimeters ? "centímetros" : "pulgadas" }

    /// Convierte centímetros a la unidad mostrada.
    func fromCentimeters(_ cm: Double) -> Double { self == .centimeters ? cm : cm / Self.cmPerInch }
    func toCentimeters(_ value: Double) -> Double { self == .centimeters ? value : value * Self.cmPerInch }

    func number(_ cm: Double) -> String {
        let v = fromCentimeters(cm)
        return self == .centimeters
            ? v.formatted(.number.precision(.fractionLength(0)))
            : v.formatted(.number.precision(.fractionLength(0...1)))
    }

    func format(width: Double, height: Double) -> String {
        "\(number(width)) × \(number(height)) \(rawValue)"
    }
}
