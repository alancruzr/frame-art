import Foundation
import UIKit

enum TestImage {
    /// Imagen sintética (sin binarios en el repo).
    static func make(width: Int = 400, height: Int = 300) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        }
    }
}

enum TempFile {
    static func url(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
    }
}

extension Data {
    func le16(_ i: Int) -> Int { Int(self[startIndex + i]) | Int(self[startIndex + i + 1]) << 8 }
    func le32(_ i: Int) -> UInt32 {
        let b = startIndex + i
        return UInt32(self[b]) | UInt32(self[b + 1]) << 8 | UInt32(self[b + 2]) << 16 | UInt32(self[b + 3]) << 24
    }
}

/// Entrada local de un ZIP.
struct ZipEntry {
    let name: String
    let method: Int
    let crc: UInt32
    let size: Int
    let dataOffset: Int
    let data: Data
}

enum ZipReader {
    static let localSig = Data([0x50, 0x4B, 0x03, 0x04])

    static func entries(_ d: Data) -> [ZipEntry] {
        var out: [ZipEntry] = []
        var off = 0
        while off + 30 <= d.count, d.subdata(in: off..<off + 4) == localSig {
            let method = d.le16(off + 8)
            let crc = d.le32(off + 14)
            let size = Int(d.le32(off + 18))
            let n = d.le16(off + 26)
            let e = d.le16(off + 28)
            let name = String(decoding: d.subdata(in: off + 30..<off + 30 + n), as: UTF8.self)
            let start = off + 30 + n + e
            out.append(ZipEntry(name: name, method: method, crc: crc, size: size, dataOffset: start,
                                data: d.subdata(in: start..<start + size)))
            off = start + size
        }
        return out
    }
}
