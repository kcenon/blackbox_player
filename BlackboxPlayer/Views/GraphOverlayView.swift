//
//  GraphOverlayView.swift
//  BlackboxPlayer
//
//  Graph overlay showing acceleration data
//

import SwiftUI

/// Graph overlay showing real-time acceleration data
struct GraphOverlayView: View {
    @ObservedObject var gsensorService: GSensorService
    let currentTime: TimeInterval

    /// Time window to display (in seconds)
    private let timeWindow: TimeInterval = 10.0

    var body: some View {
        VStack {
            Spacer()

            HStack {
                if gsensorService.hasData {
                    accelerationGraph
                        .frame(width: 400, height: 180)
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
            // Title and Current G-Force
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
                Text("G-Force")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                // Current G-Force Display
                if let currentAccel = gsensorService.currentAcceleration {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currentAccel.magnitudeString)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(gforceColor(for: currentAccel.magnitude))

                        if currentAccel.isImpact {
                            Text(currentAccel.impactSeverity.displayName)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }

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
            EnhancedAccelerationGraphView(
                accelerationData: visibleAccelerationData,
                impactEvents: visibleImpactEvents,
                currentTime: currentTime,
                timeWindow: timeWindow
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func gforceColor(for magnitude: Double) -> Color {
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
        return gsensorService.getData(from: startTime, to: endTime)
    }

    private var visibleImpactEvents: [AccelerationData] {
        let startTime = max(0, currentTime - timeWindow)
        let endTime = currentTime
        return gsensorService.getImpacts(from: startTime, to: endTime, minSeverity: .moderate)
    }
}

// MARK: - Enhanced Acceleration Graph View

/// Enhanced graph view for acceleration data with impact highlighting
struct EnhancedAccelerationGraphView: View {
    let accelerationData: [AccelerationData]
    let impactEvents: [AccelerationData]
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

                // Impact event background highlights
                impactHighlights(in: geometry)

                // X axis line
                linePath(for: \.x, in: geometry, color: .red)

                // Y axis line
                linePath(for: \.y, in: geometry, color: .green)

                // Z axis line
                linePath(for: \.z, in: geometry, color: .blue)

                // Impact markers
                impactMarkers(in: geometry)

                // Current time indicator
                currentTimeIndicator(in: geometry)
            }
        }
        .frame(height: 120)
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

    // MARK: - Impact Highlights

    private func impactHighlights(in geometry: GeometryProxy) -> some View {
        ForEach(impactEvents, id: \.timestamp) { impact in
            let startTime = currentTime - timeWindow
            let impactTime = impact.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
            let x = xPosition(for: impactTime, startTime: startTime, in: geometry)

            Rectangle()
                .fill(impactColor(for: impact).opacity(0.2))
                .frame(width: 20)
                .position(x: x, y: geometry.size.height / 2)
        }
    }

    private func impactMarkers(in geometry: GeometryProxy) -> some View {
        ForEach(impactEvents, id: \.timestamp) { impact in
            let startTime = currentTime - timeWindow
            let impactTime = impact.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
            let x = xPosition(for: impactTime, startTime: startTime, in: geometry)

            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(impactColor(for: impact), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
        }
    }

    private func impactColor(for impact: AccelerationData) -> Color {
        switch impact.impactSeverity {
        case .severe:
            return .red
        case .high:
            return .orange
        case .moderate:
            return .yellow
        case .low:
            return .cyan
        case .none:
            return .white
        }
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
        let gsensorService = GSensorService()
        let videoFile = VideoFile.allSamples.first!

        // Load sample data
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        return ZStack {
            Color.black

            GraphOverlayView(
                gsensorService: gsensorService,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
