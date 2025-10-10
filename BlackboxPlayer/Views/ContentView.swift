//
//  ContentView.swift
//  BlackboxPlayer
//
//  Main application view with integrated UI
//

import SwiftUI

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
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .font(.system(size: 64))
                .foregroundColor(.white)

            Text(videoFile.baseFilename)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                HStack {
                    Text("Event Type:")
                        .foregroundColor(.secondary)
                    Text(videoFile.eventType.displayName)
                        .foregroundColor(.white)
                }

                HStack {
                    Text("Duration:")
                        .foregroundColor(.secondary)
                    Text(videoFile.durationString)
                        .foregroundColor(.white)
                }

                HStack {
                    Text("Channels:")
                        .foregroundColor(.secondary)
                    Text("\(videoFile.channelCount)")
                        .foregroundColor(.white)
                }

                if videoFile.hasGPSData {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("GPS Data Available")
                            .foregroundColor(.green)
                    }
                }

                if videoFile.hasAccelerationData {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.blue)
                        Text("G-Sensor Data Available")
                            .foregroundColor(.blue)
                    }
                }
            }
            .font(.body)

            Text("Video playback will be implemented in later phase")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
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

    // MARK: - Actions

    private func refreshFileList() {
        // TODO: Implement actual file scanning
        // For now, just reload samples
        videoFiles = VideoFile.allSamples
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
