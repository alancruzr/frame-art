#!/usr/bin/env swift
import AppKit
import Foundation
import SceneKit

let args = CommandLine.arguments
guard args.count >= 6 else {
    fputs("usage: export_usdz_scn.swift jpeg out.usdz title width_m height_m\n", stderr)
    exit(2)
}

let jpegURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let title = args[3]
let widthM = CGFloat((Double(args[4]) ?? 0))
let heightM = CGFloat((Double(args[5]) ?? 0))
guard widthM > 0, heightM > 0 else {
    fputs("invalid size\n", stderr)
    exit(2)
}

guard NSImage(contentsOf: jpegURL) != nil else {
    fputs("cannot load \(jpegURL.path)\n", stderr)
    exit(1)
}

let paint = SCNMaterial()
paint.lightingModel = .constant
paint.diffuse.contents = jpegURL
paint.emission.contents = jpegURL
paint.diffuse.wrapS = .clamp
paint.diffuse.wrapT = .clamp
paint.emission.wrapS = .clamp
paint.emission.wrapT = .clamp
paint.isDoubleSided = true

let edge = SCNMaterial()
edge.lightingModel = .constant
edge.diffuse.contents = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.08, alpha: 1)
edge.emission.contents = NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.05, alpha: 1)
edge.isDoubleSided = true

let box = SCNBox(width: widthM, height: heightM, length: 0.008, chamferRadius: 0)
box.materials = [paint, edge, paint, edge, edge, edge]

let node = SCNNode(geometry: box)
node.name = "Painting"
let scene = SCNScene()
scene.rootNode.name = title
scene.rootNode.addChildNode(node)

if FileManager.default.fileExists(atPath: outURL.path) {
    try FileManager.default.removeItem(at: outURL)
}

guard scene.write(to: outURL, options: nil, delegate: nil, progressHandler: nil) else {
    fputs("SceneKit write failed\n", stderr)
    exit(1)
}

let data = try Data(contentsOf: outURL)
guard data.count > 256, data.starts(with: [0x50, 0x4B]) else {
    fputs("SceneKit wrote a non-USDZ file (\(data.count) bytes)\n", stderr)
    exit(1)
}
print("wrote \(outURL.path) \(data.count) bytes title=\(title) size=\(widthM)x\(heightM)m")
