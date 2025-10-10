//
//  VideoPlayerView.swift
//  BlackboxPlayer
//
//  Main video player view
//

import SwiftUI

/// Main video player view with controls
struct VideoPlayerView: View {
    let videoFile: VideoFile

    @StateObject private var viewModel = VideoPlayerViewModel()
    @State private var showControls = true
    @State private var controlsTimer: Timer?

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
        }
        .onDisappear {
            viewModel.stop()
            controlsTimer?.invalidate()
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
