//
//  MetadataOverlayView.swift
//  BlackboxPlayer
//
//  Overlay view for displaying metadata (GPS, speed, G-force)
//

import SwiftUI

/// Overlay view for displaying real-time metadata
struct MetadataOverlayView: View {
    let videoFile: VideoFile
    let currentTime: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // Left side: Speed and GPS
                leftPanel

                Spacer()

                // Right side: G-force and timestamp
                rightPanel
            }
            .padding()

            Spacer()
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Speed display
            if let gpsPoint = currentGPSPoint, let speed = gpsPoint.speed {
                speedGauge(speed: speed)
            }

            // GPS coordinates
            if let gpsPoint = currentGPSPoint {
                gpsCoordinates(gpsPoint: gpsPoint)
            }

            // Altitude
            if let gpsPoint = currentGPSPoint, let altitude = gpsPoint.altitude {
                metadataRow(
                    icon: "arrow.up.arrow.down",
                    label: "Altitude",
                    value: String(format: "%.0f m", altitude)
                )
            }

            // Heading
            if let gpsPoint = currentGPSPoint, let heading = gpsPoint.heading {
                metadataRow(
                    icon: "location.north.fill",
                    label: "Heading",
                    value: String(format: "%.0f°", heading)
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Timestamp
            timestampDisplay

            // G-force
            if let accelData = currentAccelerationData {
                gforceDisplay(accelData: accelData)
            }

            // Event type badge
            EventBadge(eventType: videoFile.eventType)
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    // MARK: - Speed Gauge

    private func speedGauge(speed: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f", speed))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("km/h")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - GPS Coordinates

    private func gpsCoordinates(gpsPoint: GPSPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text("GPS")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white.opacity(0.8))

            Text(gpsPoint.decimalString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)

            // Satellite count
            if let satelliteCount = gpsPoint.satelliteCount {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("\(satelliteCount) satellites")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - G-Force Display

    private func gforceDisplay(accelData: AccelerationData) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Text("G-Force")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.8))

            // Magnitude
            Text(accelData.magnitudeString)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(gforceColor(magnitude: accelData.magnitude))

            // X, Y, Z values
            VStack(alignment: .trailing, spacing: 2) {
                axisValue(label: "X", value: accelData.x)
                axisValue(label: "Y", value: accelData.y)
                axisValue(label: "Z", value: accelData.z)
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))

            // Impact warning
            if accelData.isImpact {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(accelData.impactSeverity.displayName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
            }
        }
    }

    private func axisValue(label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundColor(.white.opacity(0.6))
            Text(String(format: "%+.2f", value))
                .foregroundColor(.white)
        }
    }

    private func gforceColor(magnitude: Double) -> Color {
        if magnitude > 4.0 {
            return .red
        } else if magnitude > 2.5 {
            return .orange
        } else if magnitude > 1.5 {
            return .yellow
        } else {
            return .green
        }
    }

    // MARK: - Timestamp Display

    private var timestampDisplay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(videoFile.timestamp.addingTimeInterval(currentTime), style: .time)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.white)

            Text(videoFile.timestamp.addingTimeInterval(currentTime), style: .date)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Metadata Row

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    // MARK: - Helper Methods

    private var currentGPSPoint: GPSPoint? {
        return videoFile.metadata.gpsPoint(at: currentTime)
    }

    private var currentAccelerationData: AccelerationData? {
        return videoFile.metadata.accelerationData(at: currentTime)
    }
}

// MARK: - Preview

struct MetadataOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            MetadataOverlayView(
                videoFile: VideoFile.allSamples.first!,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
