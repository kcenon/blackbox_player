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

    /// Renderer reference (for screenshot capture)
    @State private var renderer: MultiChannelRenderer?

    /// Video transformation service
    @ObservedObject private var transformationService = VideoTransformationService.shared

    /// Show transformation controls
    @State private var showTransformControls = false

    /// Fullscreen mode state
    @State private var isFullscreen = false

    /// Auto-hide timer for controls
    @State private var controlsTimer: Timer?

    /// Available displays for fullscreen
    @State private var availableDisplays: [NSScreen] = []

    /// Selected display for fullscreen
    @State private var selectedDisplay: NSScreen?

    // MARK: - Body

    var body: some View {
        ZStack {
            // Metal view for rendering
            MetalVideoView(
                syncController: syncController,
                layoutMode: layoutMode,
                focusedPosition: focusedPosition,
                onRendererCreated: { renderer = $0 }
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
            detectAvailableDisplays()
        }
        .onDisappear {
            syncController.stop()
            controlsTimer?.invalidate()
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                // Show controls when mouse enters
                showControls = true
                resetControlsTimer()
            }
        }
        .gesture(
            // Track mouse movement to show controls
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    showControls = true
                    resetControlsTimer()
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
            infoLog("[MultiChannelPlayerView] Entering fullscreen mode")
            resetControlsTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
            showControls = true
            controlsTimer?.invalidate()
            infoLog("[MultiChannelPlayerView] Exiting fullscreen mode")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            detectAvailableDisplays()
            infoLog("[MultiChannelPlayerView] Screen configuration changed")
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            // Top bar: Layout and transformation controls
            VStack(spacing: 8) {
                HStack {
                    layoutControls
                    Spacer()
                    // Transformation toggle button
                    Button(action: { showTransformControls.toggle() }) {
                        Image(systemName: showTransformControls ? "slider.horizontal.3" : "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(showTransformControls ? .white : .white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(showTransformControls ? Color.accentColor : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Video Transformations")

                    Spacer()
                        .frame(width: 12)

                    channelIndicators
                }

                // Transformation controls (shown when toggled)
                if showTransformControls {
                    transformationControls
                }
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

    // MARK: - Transformation Controls

    private var transformationControls: some View {
        VStack(spacing: 12) {
            // First row: Brightness and Zoom
            HStack(spacing: 20) {
                // Brightness control
                HStack(spacing: 8) {
                    Image(systemName: "sun.min")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    Slider(
                        value: Binding(
                            get: { transformationService.transformations.brightness },
                            set: { transformationService.setBrightness($0) }
                        ),
                        in: -1.0...1.0
                    )
                    .frame(width: 120)

                    Image(systemName: "sun.max")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    Text(String(format: "%.2f", transformationService.transformations.brightness))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40)
                }

                // Zoom control
                HStack(spacing: 8) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    Slider(
                        value: Binding(
                            get: { transformationService.transformations.zoomLevel },
                            set: { transformationService.setZoomLevel($0) }
                        ),
                        in: 1.0...5.0
                    )
                    .frame(width: 120)

                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    Text(String(format: "%.1fx", transformationService.transformations.zoomLevel))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40)
                }
            }

            // Second row: Flip controls and Reset
            HStack(spacing: 12) {
                // Flip Horizontal
                Button(action: { transformationService.toggleFlipHorizontal() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 14))
                        Text("Flip H")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(
                        transformationService.transformations.flipHorizontal
                            ? Color.accentColor
                            : Color.white.opacity(0.2)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Flip Horizontal")

                // Flip Vertical
                Button(action: { transformationService.toggleFlipVertical() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 14))
                        Text("Flip V")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(
                        transformationService.transformations.flipVertical
                            ? Color.accentColor
                            : Color.white.opacity(0.2)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Flip Vertical")

                Spacer()

                // Reset button
                Button(action: { transformationService.resetTransformations() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                        Text("Reset")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Reset all transformations")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
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

            Spacer()
                .frame(width: 20)

            // Screenshot button
            Button(action: captureScreenshot) {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Capture Screenshot")

            // Fullscreen toggle button
            Button(action: toggleFullscreen) {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help(isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen")
        }
    }

    // MARK: - Fullscreen

    private func toggleFullscreen() {
        // Get the current window
        guard let window = NSApplication.shared.keyWindow else {
            warningLog("[MultiChannelPlayerView] No key window available for fullscreen toggle")
            return
        }

        // Toggle fullscreen
        window.toggleFullScreen(nil)
        isFullscreen.toggle()

        infoLog("[MultiChannelPlayerView] Fullscreen mode: \(isFullscreen)")
    }

    // MARK: - Auto-hide Controls

    private func resetControlsTimer() {
        // Invalidate existing timer
        controlsTimer?.invalidate()

        // Don't auto-hide if not in fullscreen mode
        guard isFullscreen else {
            return
        }

        // Create new timer to hide controls after 3 seconds of inactivity
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
    }

    // MARK: - Screenshot

    private func captureScreenshot() {
        guard let renderer = renderer else {
            warningLog("[MultiChannelPlayerView] Renderer not available for screenshot")
            return
        }

        infoLog("[MultiChannelPlayerView] Capturing screenshot")

        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "Blackbox_\(dateString)"

        // Capture with timestamp overlay
        renderer.captureAndSave(
            format: .png,
            timestamp: Date(),
            videoTimestamp: syncController.currentTime,
            defaultFilename: filename
        )
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

    // MARK: - Display Management

    private func detectAvailableDisplays() {
        availableDisplays = NSScreen.screens
        selectedDisplay = NSScreen.main

        let displayCount = availableDisplays.count
        infoLog("[MultiChannelPlayerView] Detected \(displayCount) display(s)")

        for (index, screen) in availableDisplays.enumerated() {
            let frame = screen.frame
            let name = screen.localizedName
            debugLog("[MultiChannelPlayerView] Display \(index + 1): \(name), frame: \(frame)")
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
    let onRendererCreated: (MultiChannelRenderer) -> Void

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
        Coordinator(
            syncController: syncController,
            layoutMode: layoutMode,
            focusedPosition: focusedPosition,
            onRendererCreated: onRendererCreated
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        let syncController: SyncController
        var layoutMode: LayoutMode
        var focusedPosition: CameraPosition
        var renderer: MultiChannelRenderer?

        init(
            syncController: SyncController,
            layoutMode: LayoutMode,
            focusedPosition: CameraPosition,
            onRendererCreated: @escaping (MultiChannelRenderer) -> Void
        ) {
            self.syncController = syncController
            self.layoutMode = layoutMode
            self.focusedPosition = focusedPosition
            super.init()

            if let renderer = MultiChannelRenderer() {
                self.renderer = renderer
                onRendererCreated(renderer)
            }
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
