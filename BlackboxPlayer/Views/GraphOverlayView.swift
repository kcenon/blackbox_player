//
//  GraphOverlayView.swift
//  BlackboxPlayer
//
//  Graph overlay showing acceleration data
//

import SwiftUI

/// Graph overlay showing real-time acceleration data
struct GraphOverlayView: View {
    let videoFile: VideoFile
    let currentTime: TimeInterval

    /// Time window to display (in seconds)
    private let timeWindow: TimeInterval = 10.0

    var body: some View {
        VStack {
            Spacer()

            HStack {
                if videoFile.hasAccelerationData {
                    accelerationGraph
                        .frame(width: 350, height: 150)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding()
                }

                Spacer()
            }
        }
    }

    // MARK: - Acceleration Graph

    private var accelerationGraph: some View {
        VStack(spacing: 8) {
            // Title
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
                Text("G-Force")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                // Legend
                HStack(spacing: 12) {
                    legendItem(color: .red, label: "X")
                    legendItem(color: .green, label: "Y")
                    legendItem(color: .blue, label: "Z")
                }
                .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal)
            .padding(.top, 8)

            // Graph
            AccelerationGraphView(
                accelerationData: visibleAccelerationData,
                currentTime: currentTime,
                timeWindow: timeWindow
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Helper Methods

    private var visibleAccelerationData: [AccelerationData] {
        let startTime = max(0, currentTime - timeWindow)
        let endTime = currentTime

        return videoFile.metadata.accelerationData.filter { data in
            let dataTime = data.timestamp.timeIntervalSince(videoFile.timestamp)
            return dataTime >= startTime && dataTime <= endTime
        }
    }
}

// MARK: - Acceleration Graph View

/// Custom graph view for acceleration data
struct AccelerationGraphView: View {
    let accelerationData: [AccelerationData]
    let currentTime: TimeInterval
    let timeWindow: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                gridLines(in: geometry)

                // Zero line
                Path { path in
                    let y = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)

                // X axis line
                linePath(for: \.x, in: geometry, color: .red)

                // Y axis line
                linePath(for: \.y, in: geometry, color: .green)

                // Z axis line
                linePath(for: \.z, in: geometry, color: .blue)

                // Current time indicator
                currentTimeIndicator(in: geometry)
            }
        }
        .frame(height: 100)
    }

    // MARK: - Grid Lines

    private func gridLines(in geometry: GeometryProxy) -> some View {
        let gridColor = Color.white.opacity(0.1)

        return ZStack {
            // Horizontal grid lines
            ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
                let y = yPosition(for: Double(value), in: geometry)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(gridColor, lineWidth: 0.5)
            }

            // Vertical grid lines (every 2 seconds)
            ForEach(0..<Int(timeWindow / 2), id: \.self) { index in
                let x = CGFloat(index) * (geometry.size.width / CGFloat(timeWindow / 2))
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(gridColor, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Line Path

    private func linePath(for keyPath: KeyPath<AccelerationData, Double>, in geometry: GeometryProxy, color: Color) -> some View {
        Path { path in
            guard !accelerationData.isEmpty else { return }

            let startTime = currentTime - timeWindow

            for (index, data) in accelerationData.enumerated() {
                let dataTime = data.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
                let x = xPosition(for: dataTime, startTime: startTime, in: geometry)
                let y = yPosition(for: data[keyPath: keyPath], in: geometry)

                let point = CGPoint(x: x, y: y)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: 2)
    }

    // MARK: - Current Time Indicator

    private func currentTimeIndicator(in geometry: GeometryProxy) -> some View {
        Path { path in
            let x = geometry.size.width
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
        }
        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    }

    // MARK: - Position Calculations

    private func xPosition(for time: TimeInterval, startTime: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
        let relativeTime = time - startTime
        let ratio = relativeTime / timeWindow
        return CGFloat(ratio) * geometry.size.width
    }

    private func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
        // Map value range [-3, 3] to geometry height
        let maxValue: Double = 3.0
        let ratio = (value + maxValue) / (maxValue * 2)
        return geometry.size.height * (1.0 - CGFloat(ratio))
    }
}

// MARK: - Preview

struct GraphOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            GraphOverlayView(
                videoFile: VideoFile.allSamples.first!,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
