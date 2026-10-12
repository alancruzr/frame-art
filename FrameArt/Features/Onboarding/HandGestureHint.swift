import SwiftUI

/// Mano animada que enseña cada gesto. Con Reducir movimiento se muestra quieta.
struct HandGestureHint: View {
    enum Gesture: Equatable {
        case tap, scan, pinch, drag
    }

    let gesture: Gesture
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    private var moving: Bool { !reduceMotion }

    var body: some View {
        ZStack {
            switch gesture {
            case .tap: tap
            case .scan: scan
            case .pinch: pinch
            case .drag: drag
            }
        }
        .frame(width: 140, height: 120)
        .id(gesture)
        .onAppear { start() }
        .onChange(of: gesture) { _, _ in on = false; start() }
        .accessibilityHidden(true)
    }

    private func start() {
        guard moving else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: gesture != .tap)) {
                on = true
            }
        }
    }

    private var duration: Double {
        switch gesture {
        case .tap: return 1.1
        case .scan: return 1.8
        case .pinch: return 1.2
        case .drag: return 1.5
        }
    }

    private var hand: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 46))
            .foregroundStyle(.white)
            .shadow(color: FrameStudioBrand.accent.opacity(0.6), radius: 8)
    }

    private var tap: some View {
        ZStack {
            Circle()
                .stroke(FrameStudioBrand.softLavender, lineWidth: 3)
                .frame(width: 44, height: 44)
                .scaleEffect(on ? 1.8 : 0.6)
                .opacity(on ? 0 : (moving ? 0.9 : 0.6))
                .offset(x: -14, y: -26)
            hand
                .scaleEffect(on ? 0.86 : 1)
                .offset(y: on ? 2 : 10)
        }
    }

    private var scan: some View {
        ZStack {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: FrameStudioBrand.blue.opacity(0.6), radius: 8)
                .rotationEffect(.degrees(on ? 8 : -8))
                .offset(x: on ? 34 : -34)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FrameStudioBrand.softBlue)
                .offset(x: on ? 34 : -34, y: -44)
                .opacity(moving ? (on ? 1 : 0.4) : 1)
        }
    }

    private var pinch: some View {
        ZStack {
            Circle().fill(FrameStudioBrand.softLavender).frame(width: 18, height: 18)
                .offset(x: on ? -34 : -10, y: on ? -26 : -8)
            Circle().fill(FrameStudioBrand.softLavender).frame(width: 18, height: 18)
                .offset(x: on ? 34 : 10, y: on ? 26 : 8)
            Image(systemName: "hand.pinch.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .shadow(color: FrameStudioBrand.accent.opacity(0.6), radius: 8)
                .scaleEffect(on ? 1.08 : 0.94)
                .offset(x: 8, y: 34)
        }
    }

    private var drag: some View {
        ZStack {
            Capsule()
                .fill(FrameStudioBrand.softBlue.opacity(0.7))
                .frame(width: on ? 90 : 10, height: 6)
                .offset(x: on ? 0 : -40, y: -22)
            hand
                .offset(x: on ? 40 : -40, y: 6)
        }
    }
}
