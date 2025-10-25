/// @file CompassView.swift
/// @brief Compass direction display view
/// @author BlackboxPlayer Development Team
/// @details
/// SwiftUI view that displays vehicle heading in compass style.
/// Uses GPS heading data to visually represent direction.

import SwiftUI

/// @struct CompassView
/// @brief Compass direction display
///
/// @details
/// ## Features
/// - Circular compass design
/// - 8-point compass display (N, NE, E, SE, S, SW, W, NW)
/// - Rotation animation
/// - Current direction highlighting
///
/// ## Direction display
/// ```
/// 0° (360°) → N (North)
/// 45°       → NE (Northeast)
/// 90°       → E (East)
/// 135°      → SE (Southeast)
/// 180°      → S (South)
/// 225°      → SW (Southwest)
/// 270°      → W (West)
/// 315°      → NW (Northwest)
/// ```
///
/// ## Usage example
/// ```swift
/// CompassView(heading: 90.0)
///     .frame(width: 80, height: 80)
/// ```
struct CompassView: View {
    // MARK: - Properties

    /// @var heading
    /// @brief Current heading (0° ~ 360°)
    ///
    /// @details
    /// 0°/360° = North
    /// 90° = East
    /// 180° = South
    /// 270° = West
    let heading: Double

    // MARK: - Constants

    /// @brief 8-point compass display
    ///
    /// @details
    /// Array of (angle, label) tuples
    /// angle: Position on compass
    /// label: Direction character to display
    private let directions: [(angle: Double, label: String)] = [
        (0, "N"),      // North
        (45, "NE"),    // Northeast
        (90, "E"),     // East
        (135, "SE"),   // Southeast
        (180, "S"),    // South
        (225, "SW"),   // Southwest
        (270, "W"),    // West
        (315, "NW")    // Northwest
    ]

    // MARK: - Computed Properties

    /// @brief Direction string
    ///
    /// @details
    /// Returns the 8-point compass label closest to current heading
    private var directionText: String {
        // Divide into 8 sections of 22.5 degrees each
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index].label
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Compass ring
            compassRing

            // 8-point markers
            directionMarkers

            // Center direction text
            centerText

            // North indicator (triangle)
            northIndicator
        }
        .rotationEffect(.degrees(-heading))  // Compass rotation
        .animation(.easeInOut(duration: 0.3), value: heading)  // Smooth animation
    }

    // MARK: - Compass Ring

    /// @brief Compass ring
    ///
    /// @details
    /// Semi-transparent white circle representing compass border
    private var compassRing: some View {
        Circle()
            .stroke(Color.white.opacity(0.3), lineWidth: 2)
    }

    // MARK: - Direction Markers

    /// @brief 8-point direction markers
    ///
    /// @details
    /// Place 8 direction labels using ForEach
    private var directionMarkers: some View {
        ForEach(directions, id: \.angle) { direction in
            Text(direction.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(
                    direction.angle == 0 ? .red : .white.opacity(0.6)
                    // Highlight North (N) in red only
                )
                .offset(y: -32)  // Move upward on circle
                .rotationEffect(.degrees(direction.angle))  // Rotate to each direction position
                .rotationEffect(.degrees(heading))  // Compensate heading rotation (always upright)
        }
    }

    // MARK: - Center Text

    /// @brief Center direction text
    ///
    /// @details
    /// Display current direction label and angle in center
    private var centerText: some View {
        VStack(spacing: 2) {
            Text(directionText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(String(format: "%.0f°", heading))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - North Indicator

    /// @brief North indicator (triangle)
    ///
    /// @details
    /// Red triangle pointing north at top of compass
    private var northIndicator: some View {
        Triangle()
            .fill(Color.red.opacity(0.8))
            .frame(width: 8, height: 12)
            .offset(y: -38)  // Move outside circle
            .rotationEffect(.degrees(heading))  // Compensate heading rotation
    }
}

// MARK: - Triangle Shape

/// @struct Triangle
/// @brief Triangle Shape
///
/// @details
/// Triangle path for north indicator
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Triangle apex (top center)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))

        // Bottom left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        // Bottom right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // Close (back to apex)
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // North
            CompassView(heading: 0)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("North (0°)")

            // East
            CompassView(heading: 90)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("East (90°)")

            // South
            CompassView(heading: 180)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("South (180°)")

            // West
            CompassView(heading: 270)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("West (270°)")

            // Northeast
            CompassView(heading: 45)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("Northeast (45°)")
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
