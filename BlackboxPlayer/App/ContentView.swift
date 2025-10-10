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

    /// Overlay visibility toggles
    @State private var showMetadataOverlay = true
    @State private var showMapOverlay = true
    @State private var showGraphOverlay = true

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

            // Main content: Video player with overlays
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

            ToolbarItemGroup(placement: .automatic) {
                overlayToggles
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
                // Video player (full screen background)
                VideoPlayerView(videoFile: selectedFile)

                // Overlays on top
                overlaysStack(for: selectedFile)
                    .allowsHitTesting(false) // Allow clicks to pass through to player
            } else {
                // Empty state
                emptyState
            }
        }
        .background(Color.black)
    }

    // MARK: - Overlays Stack

    private func overlaysStack(for videoFile: VideoFile) -> some View {
        ZStack {
            // Metadata overlay (top-left and top-right)
            if showMetadataOverlay {
                MetadataOverlayView(
                    videoFile: videoFile,
                    currentTime: 0 // TODO: Sync with player time
                )
            }

            // Map overlay (bottom-right)
            if showMapOverlay && videoFile.hasGPSData {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MapOverlayView(
                            videoFile: videoFile,
                            currentTime: 0 // TODO: Sync with player time
                        )
                        .frame(width: 300, height: 250)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding()
                    }
                }
            }

            // Graph overlay (bottom-left)
            if showGraphOverlay && videoFile.hasAccelerationData {
                VStack {
                    Spacer()
                    HStack {
                        GraphOverlayView(
                            videoFile: videoFile,
                            currentTime: 0 // TODO: Sync with player time
                        )
                        .frame(width: 400, height: 180)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding()

                        Spacer()
                    }
                }
            }
        }
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

                Text("Select a video from the sidebar to start playback")
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

    // MARK: - Overlay Toggles

    private var overlayToggles: some View {
        Group {
            Toggle(isOn: $showMetadataOverlay) {
                Image(systemName: "info.circle")
            }
            .toggleStyle(.button)
            .help("Toggle metadata overlay")

            if selectedVideoFile?.hasGPSData == true {
                Toggle(isOn: $showMapOverlay) {
                    Image(systemName: "map")
                }
                .toggleStyle(.button)
                .help("Toggle map overlay")
            }

            if selectedVideoFile?.hasAccelerationData == true {
                Toggle(isOn: $showGraphOverlay) {
                    Image(systemName: "waveform.path.ecg")
                }
                .toggleStyle(.button)
                .help("Toggle acceleration graph")
            }
        }
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
