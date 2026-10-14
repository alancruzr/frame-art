import simd
import Testing
@testable import FrameArt

@Suite("WallPlacementMath")
struct WallPlacementMathTests {
    @Test func hangingMatrixIsOrthonormalAndFacesNormal() {
        let pos = SIMD3<Float>(1, 1.5, -2)
        let normal = SIMD3<Float>(0, 0, 1)
        let m = WallPlacement.hangingMatrix(position: pos, normal: normal)
        #expect(abs(simd_determinant(m) - 1) < 1e-4)
        let z = SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        #expect(simd_distance(z, normal) < 1e-5)
        let up = SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z)
        #expect(simd_distance(up, SIMD3(0, 1, 0)) < 1e-5)
        // Separación de 2 cm respecto a la pared
        let t = WallPlacement.position(from: m)
        #expect(simd_distance(t, pos + normal * 0.02) < 1e-5)
    }

    @Test func hangingMatrixHandlesNearVerticalNormal() {
        let m = WallPlacement.hangingMatrix(position: .zero, normal: SIMD3(0, 1, 0))
        #expect(abs(simd_determinant(m) - 1) < 1e-3)
    }
}
