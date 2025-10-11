//
//  ContentView.swift
//  BlackboxPlayer
//
//  Main application view with integrated UI
//

import SwiftUI
import MapKit
import AppKit
import Combine

// MARK: - Log Manager (inline for build compatibility)

/// Log entry with timestamp and message
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel

    var formattedMessage: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = formatter.string(from: timestamp)
        return "[\(timeString)] [\(level.displayName)] \(message)"
    }
}

/// Log level
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var displayName: String {
        return self.rawValue
    }
}

/// Centralized log manager
class LogManager: ObservableObject {
    /// Shared instance
    static let shared = LogManager()

    /// Published log entries
    @Published private(set) var logs: [LogEntry] = []

    /// Maximum number of logs to keep
    private let maxLogs = 500

    /// Lock for thread-safe access
    private let lock = NSLock()

    private init() {}

    /// Log a message
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)

        lock.lock()
        logs.append(entry)

        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        lock.unlock()

        print("[\(level.displayName)] \(message)")
    }

    /// Clear all logs
    func clear() {
        lock.lock()
        logs.removeAll()
        lock.unlock()
    }
}

/// Convenience logging functions
func debugLog(_ message: String) {
    LogManager.shared.log(message, level: .debug)
}

func infoLog(_ message: String) {
    LogManager.shared.log(message, level: .info)
}

func warningLog(_ message: String) {
    LogManager.shared.log(message, level: .warning)
}

func errorLog(_ message: String) {
    LogManager.shared.log(message, level: .error)
}

/// Main application content view
struct ContentView: View {
    // MARK: - State Properties

    /// Selected video file
    @State private var selectedVideoFile: VideoFile?

    /// All video files
    @State private var videoFiles: [VideoFile] = VideoFile.allTestFiles

    /// Sidebar visibility
    @State private var showSidebar = true

    /// Playback state (simulated)
    @State private var isPlaying = false
    @State private var currentPlaybackTime: Double = 0.0
    @State private var playbackSpeed: Double = 1.0
    @State private var volume: Double = 0.8
    @State private var showControls = true

    /// Current opened folder path
    @State private var currentFolderPath: String?

    /// Loading state
    @State private var isLoading = false

    /// Error alert
    @State private var showError = false
    @State private var errorMessage = ""

    /// Show debug log
    @State private var showDebugLog = false

    // MARK: - Services

    private let fileScanner = FileScanner()
    private let videoFileLoader = VideoFileLoader()

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

                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open blackbox video folder")
                .disabled(isLoading)

                Button(action: { showDebugLog.toggle() }) {
                    Image(systemName: showDebugLog ? "terminal.fill" : "terminal")
                }
                .help("Toggle debug log")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(.circular)
                        Text("Scanning folder...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottom) {
            if showDebugLog {
                DebugLogView()
                    .padding()
                    .transition(.move(edge: .bottom))
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Video Files")
                        .font(.headline)

                    Spacer()

                    Button(action: refreshFileList) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh file list")
                    .disabled(isLoading || currentFolderPath == nil)
                }
                .padding(.horizontal)
                .padding(.top)

                if let folderPath = currentFolderPath {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                        Text((folderPath as NSString).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(videoFiles.count) files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else {
                    Text("No folder selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
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
        // Multi-channel video player
        MultiChannelPlayerView(videoFile: videoFile)
            .id(videoFile.id)  // Force view recreation when video changes
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(12)
            .shadow(radius: 4)
    }

    private var singleChannelPlaceholder: some View {
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

    private func multiChannelLayout(for videoFile: VideoFile) -> some View {
        GeometryReader { geometry in
            let channels = videoFile.channels.filter(\.isEnabled)
            let layout = calculateChannelLayout(count: channels.count, in: geometry.size)

            ZStack {
                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                    if index < layout.count {
                        channelPlaceholder(for: channel)
                            .frame(width: layout[index].width, height: layout[index].height)
                            .position(x: layout[index].x, y: layout[index].y)
                    }
                }

                // Play overlay
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.9))

                    Text("\(channels.count) Channels")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
            }
        }
    }

    private func channelPlaceholder(for channel: ChannelInfo) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))

                Text(channel.position.shortName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func calculateChannelLayout(count: Int, in size: CGSize) -> [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] {
        var layout: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = []

        switch count {
        case 1:
            layout.append((x: size.width / 2, y: size.height / 2, width: size.width, height: size.height))

        case 2:
            // Side by side
            let w = size.width / 2
            layout.append((x: w / 2, y: size.height / 2, width: w, height: size.height))
            layout.append((x: w + w / 2, y: size.height / 2, width: w, height: size.height))

        case 3:
            // One large on left, two stacked on right
            let w = size.width * 2 / 3
            let h = size.height / 2
            layout.append((x: w / 2, y: size.height / 2, width: w, height: size.height))
            layout.append((x: w + (size.width - w) / 2, y: h / 2, width: size.width - w, height: h))
            layout.append((x: w + (size.width - w) / 2, y: h + h / 2, width: size.width - w, height: h))

        case 4:
            // 2x2 grid
            let w = size.width / 2
            let h = size.height / 2
            layout.append((x: w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w / 2, y: h + h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h + h / 2, width: w, height: h))

        case 5:
            // 3 on top, 2 on bottom
            let w = size.width / 3
            let h = size.height / 2
            // Top row
            layout.append((x: w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h / 2, width: w, height: h))
            layout.append((x: 2 * w + w / 2, y: h / 2, width: w, height: h))
            // Bottom row
            let bottomW = size.width / 2
            layout.append((x: bottomW / 2, y: h + h / 2, width: bottomW, height: h))
            layout.append((x: bottomW + bottomW / 2, y: h + h / 2, width: bottomW, height: h))

        default:
            // Fallback: single channel
            layout.append((x: size.width / 2, y: size.height / 2, width: size.width, height: size.height))
        }

        return layout
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

    // MARK: - Playback Controls

    private func playbackControls(for videoFile: VideoFile) -> some View {
        VStack(spacing: 0) {
            // Timeline
            timelineSlider(for: videoFile)
                .padding(.horizontal)
                .padding(.top, 8)

            // Control buttons
            HStack(spacing: 20) {
                // Play/Pause button
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                // Seek backward 10s
                Button(action: { seekBy(-10, in: videoFile) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Seek forward 10s
                Button(action: { seekBy(10, in: videoFile) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Current time / Duration
                Text(formatTime(currentPlaybackTime) + " / " + videoFile.durationString)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                // Speed control
                speedControl

                // Volume control
                volumeControl
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func timelineSlider(for videoFile: VideoFile) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                // Progress
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * (currentPlaybackTime / max(1, videoFile.duration)), height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: geometry.size.width * (currentPlaybackTime / max(1, videoFile.duration)) - 6)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newTime = Double(value.location.x / geometry.size.width) * videoFile.duration
                        currentPlaybackTime = max(0, min(videoFile.duration, newTime))
                    }
            )
        }
        .frame(height: 12)
    }

    private var speedControl: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: { playbackSpeed = speed }) {
                    HStack {
                        Text(formatSpeed(speed))
                        if playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge")
                    .font(.system(size: 14))
                Text(formatSpeed(playbackSpeed))
                    .font(.system(size: 13))
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 28)
            .background(Color.white.opacity(0.2))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Button(action: { volume = volume > 0 ? 0 : 0.8 }) {
                Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Slider(value: $volume, in: 0...1)
                .frame(width: 80)
                .accentColor(.white)
        }
    }

    private func seekBy(_ seconds: Double, in videoFile: VideoFile) {
        currentPlaybackTime = max(0, min(videoFile.duration, currentPlaybackTime + seconds))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.2gx", speed)
    }

    // MARK: - Actions

    /// Open folder selection dialog
    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing blackbox video files"
        panel.prompt = "Select"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                scanAndLoadFolder(url)
            }
        }
    }

    /// Scan and load video files from folder
    private func scanAndLoadFolder(_ folderURL: URL) {
        isLoading = true
        selectedVideoFile = nil

        // Perform scanning on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Scan directory
                let groups = try fileScanner.scanDirectory(folderURL)

                // Load video files
                let loadedFiles = videoFileLoader.loadVideoFiles(from: groups)

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.currentFolderPath = folderURL.path
                    self.videoFiles = loadedFiles
                    self.isLoading = false

                    // Select first file if available
                    if let firstFile = loadedFiles.first {
                        self.selectedVideoFile = firstFile
                    }
                }
            } catch {
                // Handle error on main thread
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to scan folder: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    /// Refresh file list from current folder
    private func refreshFileList() {
        guard let folderPath = currentFolderPath else {
            // No folder selected, reload test files
            videoFiles = VideoFile.allTestFiles
            return
        }

        let folderURL = URL(fileURLWithPath: folderPath)
        scanAndLoadFolder(folderURL)
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

// MARK: - Debug Log View

/// Debug log viewer overlay
struct DebugLogView: View {
    @ObservedObject var logManager = LogManager.shared
    @State private var autoScroll = true
    @State private var showCopyConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Log")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .foregroundColor(.white)

                // Copy all button
                Button(action: copyAllLogs) {
                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Copy all logs")

                // Clear button
                Button(action: { logManager.clear() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Clear logs")
            }
            .padding()
            .background(Color.black.opacity(0.9))

            Divider()

            // Log list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logManager.logs) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.8))
                .onChange(of: logManager.logs.count) { _ in
                    if autoScroll, let lastLog = logManager.logs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .cornerRadius(8)
        .shadow(radius: 10)
    }

    private func copyAllLogs() {
        let allLogs = logManager.logs.map { $0.formattedMessage }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(allLogs, forType: .string)

        // Show confirmation
        showCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showCopyConfirmation = false
        }
    }
}

/// Single log entry row
private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        Text(entry.formattedMessage)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(textColor)
            .textSelection(.enabled)
    }

    private var textColor: Color {
        switch entry.level {
        case .debug:
            return .gray
        case .info:
            return .white
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
