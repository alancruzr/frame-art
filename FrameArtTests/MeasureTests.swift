import Foundation
import Testing
@testable import FrameArt

struct MeasureTests {
    @Test func inchesRoundTrip() {
        let unit = MeasureUnit.inches
        #expect(abs(unit.toCentimeters(unit.fromCentimeters(76.2)) - 76.2) < 0.0001)
        #expect(unit.number(76.2) == 30.formatted())
    }

    @Test func centimetersFormat() {
        #expect(MeasureUnit.centimeters.format(width: 60, height: 90) == "60 × 90 cm")
    }

    @Test func presetsAreSortedShortLong() {
        for size in StandardSize.all { #expect(size.shortCentimeters <= size.longCentimeters) }
        #expect(StandardSize.all.count == 9)
    }
}
