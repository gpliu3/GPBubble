//
//  BubblePopAnimation.swift
//  GPBubble
//

import SwiftUI

struct BubblePopAnimation: View {
    let color: Color
    let diameter: CGFloat
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Expanding ring (splash effect)
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: 3)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(isAnimating ? 2.5 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5)
                            .delay(Double(index) * 0.3),
                        value: isAnimating
                    )
            }

            // Burst particles (8 directions)
            ForEach(0..<8, id: \.self) { index in
                ParticleView(
                    color: color,
                    angle: Double(index) * 45,
                    isAnimating: isAnimating
                )
            }

            // Sparkles/stars (firework effect)
            ForEach(0..<12, id: \.self) { index in
                SparkleView(
                    color: .white,
                    angle: Double(index) * 30,
                    distance: diameter * 0.8,
                    isAnimating: isAnimating
                )
            }

            // Center flash
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, color.opacity(0.8), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
                .frame(width: diameter, height: diameter)
                .scaleEffect(isAnimating ? 3.0 : 0.1)
                .opacity(isAnimating ? 0 : 1)
                .animation(.easeOut(duration: 1.2), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Particle View

struct ParticleView: View {
    let color: Color
    let angle: Double
    let isAnimating: Bool

    private var offset: CGSize {
        let distance: CGFloat = isAnimating ? 120 : 0
        let radians = angle * .pi / 180
        return CGSize(
            width: Foundation.cos(radians) * distance,
            height: Foundation.sin(radians) * distance
        )
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.6)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 8
                )
            )
            .frame(width: 16, height: 16)
            .offset(offset)
            .scaleEffect(isAnimating ? 0.3 : 1.0)
            .opacity(isAnimating ? 0 : 1)
            .animation(
                .easeOut(duration: 1.8),
                value: isAnimating
            )
    }
}

// MARK: - Sparkle View

struct SparkleView: View {
    let color: Color
    let angle: Double
    let distance: CGFloat
    let isAnimating: Bool

    private var offset: CGSize {
        let dist = isAnimating ? distance : 0
        let radians = angle * .pi / 180
        return CGSize(
            width: Foundation.cos(radians) * dist,
            height: Foundation.sin(radians) * dist
        )
    }

    var body: some View {
        ZStack {
            // Star shape using two rotated rectangles
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 12)

            Rectangle()
                .fill(color)
                .frame(width: 12, height: 2)

            Rectangle()
                .fill(color)
                .frame(width: 2, height: 10)
                .rotationEffect(.degrees(45))

            Rectangle()
                .fill(color)
                .frame(width: 10, height: 2)
                .rotationEffect(.degrees(45))
        }
        .offset(offset)
        .scaleEffect(isAnimating ? 0 : 1.0)
        .opacity(isAnimating ? 0 : 1)
        .rotationEffect(.degrees(isAnimating ? 180 : 0))
        .animation(
            .easeOut(duration: 2.1)
                .delay(0.3),
            value: isAnimating
        )
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.8)
            .ignoresSafeArea()

        BubblePopAnimation(color: .purple, diameter: 150)
    }
}
