import ARKit
import simd

/// Matemática pura de colocación en pared (testeable).
enum WallPlacement {
    static func hangingMatrix(position: SIMD3<Float>, normal: SIMD3<Float>) -> simd_float4x4 {
        let n = simd_normalize(normal)
        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(worldUp, n)
        if simd_length(right) < 0.05 {
            right = simd_cross(SIMD3<Float>(1, 0, 0), n)
        }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(n, right))
        let offset = position + n * 0.02
        return simd_float4x4(columns: (
            SIMD4(right.x, right.y, right.z, 0),
            SIMD4(up.x, up.y, up.z, 0),
            SIMD4(n.x, n.y, n.z, 0),
            SIMD4(offset.x, offset.y, offset.z, 1)
        ))
    }

    static func position(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    static func wallNormal(hit: ARRaycastResult, camera: ARCamera?) -> SIMD3<Float>? {
        var normal: SIMD3<Float>
        if let plane = hit.anchor as? ARPlaneAnchor, plane.alignment == .vertical {
            normal = simd_normalize(SIMD3(
                plane.transform.columns.1.x,
                plane.transform.columns.1.y,
                plane.transform.columns.1.z
            ))
        } else {
            let yAxis = simd_normalize(SIMD3(
                hit.worldTransform.columns.1.x,
                hit.worldTransform.columns.1.y,
                hit.worldTransform.columns.1.z
            ))
            let zAxis = simd_normalize(SIMD3(
                hit.worldTransform.columns.2.x,
                hit.worldTransform.columns.2.y,
                hit.worldTransform.columns.2.z
            ))
            normal = abs(yAxis.y) <= abs(zAxis.y) ? yAxis : zAxis
        }

        guard abs(normal.y) < 0.55 else { return nil }

        let position = position(from: hit.worldTransform)
        if let camera {
            let cam = SIMD3<Float>(
                camera.transform.columns.3.x,
                camera.transform.columns.3.y,
                camera.transform.columns.3.z
            )
            let toCamera = simd_normalize(cam - position)
            if simd_dot(normal, toCamera) < 0 {
                normal = -normal
            }
        }
        return normal
    }
}
