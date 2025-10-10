//
//  VideoPlayerView.swift
//  BlackboxPlayer
//
//  Main video player view
//

import SwiftUI
import AppKit

/// Main video player view with controls
struct VideoPlayerView: View {
    let videoFile: VideoFile

    @StateObject private var viewModel = VideoPlayerViewModel()
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isFullscreen = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Video display area
            videoDisplay
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .onHover { isHovering in
                    if isHovering {
                        showControls = true
                        resetControlsTimer()
                    }
                }

            // Controls (shown at bottom)
            if showControls {
                PlayerControlsView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            viewModel.loadVideo(videoFile)
            resetControlsTimer()
            setupKeyboardMonitor()
        }
        .onDisappear {
            viewModel.stop()
            controlsTimer?.invalidate()
            removeKeyboardMonitor()
        }
    }

    // MARK: - Video Display

    private var videoDisplay: some View {
        ZStack {
            // Video frame
            if let frame = viewModel.currentFrame {
                VideoFrameView(frame: frame)
            } else if viewModel.isBuffering {
                ProgressView("Loading...")
                    .foregroundColor(.white)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)

                    Text("Error")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .padding()
            } else {
                // Placeholder
                VStack(spacing: 16) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("No video loaded")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func resetControlsTimer() {
        controlsTimer?.invalidate()

        // Auto-hide controls after 3 seconds of inactivity (only when playing)
        if viewModel.playbackState == .playing {
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation {
                    showControls = false
                }
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            handleKeyEvent(event)
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Get the key code
        let keyCode = event.keyCode

        switch keyCode {
        case 49: // Space
            viewModel.togglePlayPause()
            return nil

        case 123: // Left arrow
            viewModel.seekBySeconds(-5.0)
            return nil

        case 124: // Right arrow
            viewModel.seekBySeconds(5.0)
            return nil

        case 126: // Up arrow
            viewModel.adjustVolume(by: 0.1)
            return nil

        case 125: // Down arrow
            viewModel.adjustVolume(by: -0.1)
            return nil

        case 3: // F key
            toggleFullscreen()
            return nil

        case 53: // ESC
            if isFullscreen {
                toggleFullscreen()
                return nil
            }

        default:
            break
        }

        return event
    }

    // MARK: - Fullscreen

    private func toggleFullscreen() {
        guard let window = NSApplication.shared.keyWindow else { return }

        isFullscreen.toggle()

        if isFullscreen {
            window.toggleFullScreen(nil)
        } else {
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
}

// MARK: - Video Frame View

/// View for displaying a single video frame
struct VideoFrameView: View {
    let frame: VideoFrame

    var body: some View {
        GeometryReader { geometry in
            if let cgImage = frame.toCGImage() {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                Color.black
            }
        }
    }
}

// MARK: - Preview

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(videoFile: VideoFile.allSamples.first!)
            .frame(width: 800, height: 600)
    }
}
