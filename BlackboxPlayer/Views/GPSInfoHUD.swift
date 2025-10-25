/// @file GPSInfoHUD.swift
/// @brief HUD component displaying GPS information in the top bar
/// @author BlackboxPlayer Development Team
/// @details
/// Displays GPS information such as speed, coordinates, altitude, and satellite count in a compact format.

import SwiftUI

/// GPS Information HUD (Heads-Up Display)
///
/// ## Display Information
/// - Speed (km/h)
/// - GPS Coordinates (latitude, longitude)
/// - Altitude (m)
/// - Satellite Count
/// - Heading (°)
///
/// ## Usage Example
/// ```swift
/// GPSInfoHUD(
///     gpsService: gpsService,
///     currentTime: syncController.currentTime
/// )
/// ```
struct GPSInfoHUD: View {
    // MARK: - Properties

    /// GPS Service
    @ObservedObject var gpsService: GPSService

    /// Current playback time
    let currentTime: TimeInterval

    /// Debug mode (show detailed information)
    @State private var showDebugInfo = false

    // MARK: - Computed Properties

    /// Current GPS point
    private var currentGPSPoint: GPSPoint? {
        return gpsService.getCurrentLocation(at: currentTime)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            /// GPS data status indicator
            HStack(spacing: 6) {
                Image(systemName: gpsService.hasData ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(gpsService.hasData ? .green : .red)

                Text(gpsService.hasData ? "GPS" : "No GPS")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            if let gpsPoint = currentGPSPoint {
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.3))

                /// Speed display
                if let speed = gpsPoint.speed {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Text(String(format: "%.0f km/h", speed))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }

                /// GPS coordinates
                HStack(spacing: 4) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    Text(coordinateString(gpsPoint))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }

                /// Altitude (if available)
                if let altitude = gpsPoint.altitude {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Text(String(format: "%.0f m", altitude))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                /// Satellite count (if available)
                if let satelliteCount = gpsPoint.satelliteCount {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Text("\(satelliteCount)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(satelliteColor(count: satelliteCount))
                    }
                }
            } else if gpsService.hasData {
                /// GPS data exists but no data at current time
                Text("Searching...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }

            /// Debug info toggle button
            if gpsService.hasData {
                Button(action: { showDebugInfo.toggle() }) {
                    Image(systemName: showDebugInfo ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Toggle GPS debug info")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        /// Debug info popover
        .popover(isPresented: $showDebugInfo, arrowEdge: .bottom) {
            debugInfoView
                .padding()
                .frame(width: 300)
        }
    }

    // MARK: - Helper Views

    /// Debug info view
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPS Debug Info")
                .font(.headline)

            Divider()

            /// Overall data statistics
            debugRow(label: "Total Points", value: "\(gpsService.pointCount)")
            debugRow(label: "Has Data", value: gpsService.hasData ? "Yes" : "No")

            if let summary = gpsService.summary {
                if let maxSpeed = summary.maximumSpeed {
                    debugRow(label: "Max Speed", value: String(format: "%.1f km/h", maxSpeed))
                }
                if let avgSpeed = summary.averageSpeed {
                    debugRow(label: "Avg Speed", value: String(format: "%.1f km/h", avgSpeed))
                }
                debugRow(label: "Total Distance", value: String(format: "%.2f km", summary.totalDistance / 1000))
            }

            Divider()

            /// Current time data
            debugRow(label: "Current Time", value: String(format: "%.2f s", currentTime))

            if let gpsPoint = currentGPSPoint {
                debugRow(label: "Latitude", value: String(format: "%.6f°", gpsPoint.latitude))
                debugRow(label: "Longitude", value: String(format: "%.6f°", gpsPoint.longitude))

                if let speed = gpsPoint.speed {
                    debugRow(label: "Speed", value: String(format: "%.2f km/h", speed))
                }

                if let heading = gpsPoint.heading {
                    debugRow(label: "Heading", value: String(format: "%.1f°", heading))
                }
            } else {
                Text("No GPS data at current time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            /// Distance and speed information
            debugRow(label: "Distance", value: String(format: "%.2f km", gpsService.distanceTraveled(at: currentTime) / 1000))

            if let avgSpeed = gpsService.averageSpeed(at: currentTime) {
                debugRow(label: "Avg Speed", value: String(format: "%.1f km/h", avgSpeed))
            }
        }
    }

    /// Debug info row
    private func debugRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Helper Methods

    /// Generate coordinate string
    private func coordinateString(_ point: GPSPoint) -> String {
        let lat = point.latitude
        let lon = point.longitude

        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"

        return String(format: "%.4f°%@ %.4f°%@", abs(lat), latDir, abs(lon), lonDir)
    }

    /// Color based on satellite count
    private func satelliteColor(count: Int) -> Color {
        switch count {
        case 0...3:
            return .red
        case 4...8:
            return .yellow
        case 9...:
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Preview

struct GPSInfoHUD_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            VStack(spacing: 20) {
                /// With GPS data
                GPSInfoHUD(
                    gpsService: {
                        let service = GPSService()
                        // Mock data would be loaded here
                        return service
                    }(),
                    currentTime: 10.0
                )

                /// Without GPS data
                GPSInfoHUD(
                    gpsService: GPSService(),
                    currentTime: 0.0
                )
            }
            .padding()
        }
        .frame(width: 800, height: 200)
    }
}
