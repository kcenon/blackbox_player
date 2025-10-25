/// @file SpeedometerGaugeView.swift
/// @brief Visual speedometer gauge view
/// @author BlackboxPlayer Development Team
/// @details
/// SwiftUI view that displays a circular or semi-circular speedometer gauge.
/// Colors change according to speed with animation effects.

import SwiftUI

/// @struct SpeedometerGaugeView
/// @brief Visual speedometer gauge
///
/// @details
/// ## Features
/// - Semi-circular gauge (0° ~ 180°)
/// - Speed range: 0 ~ 200 km/h
/// - Color coding: Low speed (green) → Medium speed (yellow) → High speed (orange) → Overspeed (red)
/// - Smooth animation
///
/// ## Colors by speed range
/// ```
/// 0-60 km/h   → Green   (Urban driving)
/// 60-100 km/h → Yellow  (Regular roads)
/// 100-140 km/h → Orange  (Highway)
/// 140+ km/h   → Red     (Overspeeding)
/// ```
///
/// ## Usage example
/// ```swift
/// SpeedometerGaugeView(speed: 85.0)
///     .frame(width: 160, height: 100)
/// ```
struct SpeedometerGaugeView: View {
    // MARK: - Properties

    /// @var speed
    /// @brief Current speed (km/h)
    let speed: Double

    /// @var maxSpeed
    /// @brief Maximum speed (default 200 km/h)
    let maxSpeed: Double = 200.0

    /// @var minSpeed
    /// @brief Minimum speed (default 0 km/h)
    let minSpeed: Double = 0.0

    // MARK: - Computed Properties

    /// @brief Speed ratio (0.0 ~ 1.0)
    ///
    /// @details
    /// **Calculation:**
    /// ```
    /// speedRatio = (current speed - min) / (max - min)
    /// Example: speed = 100, maxSpeed = 200
    ///     → speedRatio = 100 / 200 = 0.5 (50%)
    /// ```
    private var speedRatio: Double {
        let clamped = min(max(speed, minSpeed), maxSpeed)
        return (clamped - minSpeed) / (maxSpeed - minSpeed)
    }

    /// @brief Gauge angle (0° ~ 180°)
    ///
    /// @details
    /// 180-degree range for semi-circular gauge
    /// speedRatio = 0.0 → 0°
    /// speedRatio = 0.5 → 90°
    /// speedRatio = 1.0 → 180°
    private var gaugeAngle: Double {
        return speedRatio * 180.0
    }

    /// @brief Color based on speed
    ///
    /// @details
    /// Colors by speed range:
    /// - 0-60: Green (urban)
    /// - 60-100: Yellow (regular roads)
    /// - 100-140: Orange (highway)
    /// - 140+: Red (overspeeding)
    private var speedColor: Color {
        if speed < 60 {
            return .green
        } else if speed < 100 {
            return .yellow
        } else if speed < 140 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gauge (gray, semi-circle)
            backgroundGauge

            // Speed gauge (colored, up to current speed)
            speedGauge

            // Center speed text
            speedText
        }
    }

    // MARK: - Background Gauge

    /// @brief Background gauge (gray semi-circle)
    ///
    /// @details
    /// Semi-transparent background gauge representing the full speed range
    private var backgroundGauge: some View {
        Circle()
            .trim(from: 0, to: 0.5)  // Semi-circle (0° ~ 180°)
            .stroke(
                Color.white.opacity(0.2),
                style: StrokeStyle(lineWidth: 12, lineCap: .round)
            )
            .rotationEffect(.degrees(180))  // Rotate to bottom semi-circle
    }

    // MARK: - Speed Gauge

    /// @brief Speed gauge (colored semi-circle)
    ///
    /// @details
    /// Displays up to current speed, color changes based on speed
    private var speedGauge: some View {
        Circle()
            .trim(from: 0, to: CGFloat(speedRatio) * 0.5)  // Up to current speed
            .stroke(
                speedColor,
                style: StrokeStyle(lineWidth: 12, lineCap: .round)
            )
            .rotationEffect(.degrees(180))  // Rotate to bottom semi-circle
            .animation(.easeInOut(duration: 0.5), value: speed)  // Smooth animation
    }

    // MARK: - Speed Text

    /// @brief Center speed text
    ///
    /// @details
    /// Display speed as large numbers in the center of the gauge
    private var speedText: some View {
        VStack(spacing: 0) {
            Text(String(format: "%.0f", speed))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("km/h")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .offset(y: 20)  // Position below semi-circle
    }
}

// MARK: - Preview

struct SpeedometerGaugeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Low speed (green)
            SpeedometerGaugeView(speed: 45)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("Low Speed (45 km/h)")

            // Medium speed (yellow)
            SpeedometerGaugeView(speed: 85)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("Medium Speed (85 km/h)")

            // High speed (orange)
            SpeedometerGaugeView(speed: 120)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("High Speed (120 km/h)")

            // Overspeeding (red)
            SpeedometerGaugeView(speed: 160)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("Overspeeding (160 km/h)")
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
