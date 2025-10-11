//
//  ContentView.swift
//  BlackboxPlayer
//
//  Main application view with integrated UI
//

import SwiftUI
import MapKit

/// Main application content view
struct ContentView: View {
    // MARK: - State Properties

    /// Selected video file
    @State private var selectedVideoFile: VideoFile?

    /// All video files
    @State private var videoFiles: [VideoFile] = VideoFile.allSamples

    /// Sidebar visibility
    @State private var showSidebar = true

    // MARK: - Body

    var body: some View {
        NavigationView {
            // Sidebar: File list
            if showSidebar {
                sidebar
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 500)
            }

            // Main content
            mainContent
                .frame(minWidth: 600, minHeight: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { showSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle sidebar")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Video Files")
                    .font(.headline)
                    .padding()

                Spacer()

                Button(action: refreshFileList) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh file list")
                .padding(.trailing)
            }

            Divider()

            // File list
            FileListView(
                videoFiles: $videoFiles,
                selectedFile: $selectedVideoFile
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            if let selectedFile = selectedVideoFile {
                // Selected file info
                fileInfoView(for: selectedFile)
            } else {
                // Empty state
                emptyState
            }
        }
        .background(Color.black)
    }

    // MARK: - File Info View

    private func fileInfoView(for videoFile: VideoFile) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Video thumbnail placeholder
                videoThumbnail(for: videoFile)

                // File information
                fileInformationCard(for: videoFile)

                // Channel information
                channelsCard(for: videoFile)

                // Metadata information
                if videoFile.hasGPSData || videoFile.hasAccelerationData {
                    metadataCard(for: videoFile)
                }

                // GPS Map
                if videoFile.hasGPSData {
                    gpsMapCard(for: videoFile)
                }

                // Acceleration Graph
                if videoFile.hasAccelerationData {
                    accelerationGraphCard(for: videoFile)
                }
            }
            .padding()
        }
    }

    private func videoThumbnail(for videoFile: VideoFile) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)

            VStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.8))

                Text("Video Player")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text("Implementation pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .cornerRadius(12)
        .shadow(radius: 4)
    }

    private func fileInformationCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File Information")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            InfoRow(label: "Filename", value: videoFile.baseFilename)
            InfoRow(label: "Event Type", value: videoFile.eventType.displayName)
            InfoRow(label: "Timestamp", value: videoFile.timestampString)
            InfoRow(label: "Duration", value: videoFile.durationString)
            InfoRow(label: "File Size", value: videoFile.totalFileSizeString)
            InfoRow(label: "Favorite", value: videoFile.isFavorite ? "Yes" : "No")

            if let notes = videoFile.notes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(notes)
                        .foregroundColor(.white)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func channelsCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Channels (\(videoFile.channelCount))")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            ForEach(videoFile.channels, id: \.id) { channel in
                HStack {
                    Image(systemName: "video.fill")
                        .foregroundColor(channel.isEnabled ? .green : .gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.position.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text("\(channel.width)x\(channel.height) @ \(Int(channel.frameRate))fps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(channel.codec ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func metadataCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            if videoFile.hasGPSData {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("GPS Data")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.metadata.gpsPoints.count) points")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if videoFile.hasAccelerationData {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.blue)
                    Text("G-Sensor Data")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.metadata.accelerationData.count) points")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if videoFile.hasImpactEvents {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Impact Events")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.impactEventCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Video Selected")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Select a video from the sidebar to view details")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Button(action: { showSidebar = true }) {
                Label("Show Sidebar", systemImage: "sidebar.left")
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundColor(.white)
    }

    // MARK: - GPS Map Card

    private func gpsMapCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.green)
                Text("GPS Route")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(videoFile.metadata.gpsPoints.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Map view
            GPSMapView(gpsPoints: videoFile.metadata.gpsPoints)
                .frame(height: 300)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Acceleration Graph Card

    private func accelerationGraphCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                Text("G-Sensor Data")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(videoFile.metadata.accelerationData.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Graph view
            AccelerationGraphView(accelerationData: videoFile.metadata.accelerationData)
                .frame(height: 200)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func refreshFileList() {
        // TODO: Implement actual file scanning
        // For now, just reload samples
        videoFiles = VideoFile.allSamples
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .font(.caption)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.body)
        }
    }
}

// MARK: - GPS Map View

struct GPSMapView: NSViewRepresentable {
    let gpsPoints: [GPSPoint]

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays
        mapView.removeOverlays(mapView.overlays)

        guard !gpsPoints.isEmpty else { return }

        // Create coordinates array
        let coordinates = gpsPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        // Add polyline
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        mapView.delegate = context.coordinator

        // Set region to show all points
        if let firstPoint = coordinates.first {
            let region = MKCoordinateRegion(
                center: firstPoint,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: false)
        }

        // Add pins for start and end
        if let start = coordinates.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = start
            startAnnotation.title = "Start"
            mapView.addAnnotation(startAnnotation)
        }

        if let end = coordinates.last, coordinates.count > 1 {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = end
            endAnnotation.title = "End"
            mapView.addAnnotation(endAnnotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Acceleration Graph View

struct AccelerationGraphView: View {
    let accelerationData: [AccelerationData]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.opacity(0.3)

                // Grid lines
                gridLines(in: geometry.size)

                // Acceleration curves
                accelerationCurves(in: geometry.size)

                // Legend
                legend
                    .position(x: geometry.size.width - 60, y: 30)
            }
        }
    }

    private func gridLines(in size: CGSize) -> some View {
        Path { path in
            // Horizontal lines
            for i in 0...4 {
                let y = size.height * CGFloat(i) / 4
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            // Vertical lines
            for i in 0...4 {
                let x = size.width * CGFloat(i) / 4
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }

    private func accelerationCurves(in size: CGSize) -> some View {
        ZStack {
            // X axis (red)
            accelerationPath(for: \.x, in: size, color: .red)

            // Y axis (green)
            accelerationPath(for: \.y, in: size, color: .green)

            // Z axis (blue)
            accelerationPath(for: \.z, in: size, color: .blue)
        }
    }

    private func accelerationPath(for keyPath: KeyPath<AccelerationData, Double>, in size: CGSize, color: Color) -> some View {
        Path { path in
            guard !accelerationData.isEmpty else { return }

            let maxValue: Double = 2.0 // ±2G range
            let points = accelerationData.enumerated().map { index, data in
                let x = size.width * CGFloat(index) / CGFloat(max(1, accelerationData.count - 1))
                let value = data[keyPath: keyPath]
                let normalizedValue = (value + maxValue) / (2 * maxValue) // Normalize to 0-1
                let y = size.height * (1 - CGFloat(normalizedValue))
                return CGPoint(x: x, y: y)
            }

            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: 2)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("X")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Y")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("Z")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
