//
//  MultiChannelPlayerView.swift
//  BlackboxPlayer
//
//  Multi-channel synchronized video player view
//

import SwiftUI
import MetalKit

/// Multi-channel video player view with synchronized playback
struct MultiChannelPlayerView: View {
    // MARK: - Properties

    /// Sync controller
    @StateObject private var syncController = SyncController()

    /// Video file to play
    let videoFile: VideoFile

    /// Current layout mode
    @State private var layoutMode: LayoutMode = .grid

    /// Focused camera position
    @State private var focusedPosition: CameraPosition = .front

    /// Show controls overlay
    @State private var showControls = true

    /// Mouse hover state
    @State private var isHovering = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Metal view for rendering
            MetalVideoView(
                syncController: syncController,
                layoutMode: layoutMode,
                focusedPosition: focusedPosition
            )

            // GPS Map overlay
            MapOverlayView(
                gpsService: syncController.gpsService,
                gsensorService: syncController.gsensorService,
                currentTime: syncController.currentTime
            )

            // G-Sensor graph overlay
            GraphOverlayView(
                gsensorService: syncController.gsensorService,
                currentTime: syncController.currentTime
            )

            // Controls overlay
            if showControls || isHovering {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .onAppear {
            loadVideoFile()
        }
        .onDisappear {
            syncController.stop()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            // Top bar: Layout controls
            HStack {
                layoutControls
                Spacer()
                channelIndicators
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // Bottom bar: Playback controls
            VStack(spacing: 12) {
                // Timeline
                timelineView

                // Playback controls
                HStack(spacing: 20) {
                    playbackControls
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Layout Controls

    private var layoutControls: some View {
        HStack(spacing: 12) {
            ForEach(LayoutMode.allCases, id: \.self) { mode in
                Button(action: { layoutMode = mode }) {
                    Image(systemName: iconName(for: mode))
                        .font(.system(size: 18))
                        .foregroundColor(layoutMode == mode ? .white : .white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(layoutMode == mode ? Color.accentColor : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(mode.displayName)
            }
        }
    }

    private var channelIndicators: some View {
        HStack(spacing: 8) {
            ForEach(videoFile.channels.filter(\.isEnabled), id: \.position) { channel in
                Button(action: {
                    focusedPosition = channel.position
                    if layoutMode != .focus {
                        layoutMode = .focus
                    }
                }) {
                    Text(channel.position.shortName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            focusedPosition == channel.position && layoutMode == .focus
                                ? Color.accentColor
                                : Color.white.opacity(0.3)
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(channel.position.displayName)
            }
        }
    }

    // MARK: - Timeline

    private var timelineView: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)

                    // Progress
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * syncController.playbackPosition, height: 4)
                }
                .cornerRadius(2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let position = Double(value.location.x / geometry.size.width)
                            let time = position * syncController.duration
                            syncController.seekToTime(time)
                        }
                )
            }
            .frame(height: 4)

            // Time labels
            HStack {
                Text(syncController.currentTimeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Text(syncController.remainingTimeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 20) {
            // Play/Pause
            Button(action: { syncController.togglePlayPause() }) {
                Image(systemName: syncController.playbackState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .help(syncController.playbackState == .playing ? "Pause" : "Play")

            // Seek backward
            Button(action: { syncController.seekBySeconds(-10) }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Seek backward 10 seconds")

            // Seek forward
            Button(action: { syncController.seekBySeconds(10) }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Seek forward 10 seconds")

            Spacer()

            // Playback speed
            speedControl

            // Buffer status indicator
            if syncController.isBuffering {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            }

            // Channel count
            Text("\(syncController.channelCount) channels")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var speedControl: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: { syncController.playbackSpeed = speed }) {
                    HStack {
                        Text(String(format: "%.2fx", speed))
                        if syncController.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(syncController.playbackSpeedString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 28)
                .background(Color.white.opacity(0.2))
                .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .help("Playback speed")
    }

    // MARK: - Helper Methods

    private func iconName(for mode: LayoutMode) -> String {
        switch mode {
        case .grid:
            return "square.grid.2x2"
        case .focus:
            return "rectangle.inset.filled.and.person.filled"
        case .horizontal:
            return "rectangle.split.3x1"
        }
    }

    private func loadVideoFile() {
        do {
            infoLog("[MultiChannelPlayerView] Loading video file: \(videoFile.baseFilename)")
            try syncController.loadVideoFile(videoFile)
            infoLog("[MultiChannelPlayerView] Video file loaded successfully. Channels: \(syncController.channelCount)")
        } catch {
            errorLog("[MultiChannelPlayerView] Failed to load video file: \(error)")
        }
    }
}

// MARK: - Metal Video View

/// Metal-based video rendering view
private struct MetalVideoView: NSViewRepresentable {
    // MARK: - Properties

    @ObservedObject var syncController: SyncController
    let layoutMode: LayoutMode
    let focusedPosition: CameraPosition

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 30  // Set target frame rate
        mtkView.framebufferOnly = true
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.layoutMode = layoutMode
        context.coordinator.focusedPosition = focusedPosition
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(syncController: syncController, layoutMode: layoutMode, focusedPosition: focusedPosition)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        let syncController: SyncController
        var layoutMode: LayoutMode
        var focusedPosition: CameraPosition
        var renderer: MultiChannelRenderer?

        init(syncController: SyncController, layoutMode: LayoutMode, focusedPosition: CameraPosition) {
            self.syncController = syncController
            self.layoutMode = layoutMode
            self.focusedPosition = focusedPosition
            super.init()
            self.renderer = MultiChannelRenderer()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes if needed
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderer = renderer else {
                debugLog("[MetalVideoView] Draw skipped: drawable or renderer is nil")
                return
            }

            // Update renderer settings
            renderer.setLayoutMode(layoutMode)
            renderer.setFocusedPosition(focusedPosition)

            // Get synchronized frames
            let frames = syncController.getSynchronizedFrames()

            if frames.isEmpty {
                // No frames available yet, just return (black screen will be shown)
                return
            }

            debugLog("[MetalVideoView] Rendering \(frames.count) frames at time \(String(format: "%.2f", syncController.currentTime))")

            // Render
            renderer.render(
                frames: frames,
                to: drawable,
                drawableSize: view.drawableSize
            )
        }
    }
}

// MARK: - Preview

// Preview temporarily disabled - requires sample data
// struct MultiChannelPlayerView_Previews: PreviewProvider {
//     static var previews: some View {
//         MultiChannelPlayerView(videoFile: sampleVideoFile)
//             .frame(width: 1280, height: 720)
//     }
// }
