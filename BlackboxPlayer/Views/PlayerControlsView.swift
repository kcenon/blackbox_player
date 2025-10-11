//
//  PlayerControlsView.swift
//  BlackboxPlayer
//
//  Playback controls UI for video player
//

import SwiftUI

/// Playback controls for video player
struct PlayerControlsView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    @State private var isSeeking: Bool = false
    @State private var seekPosition: Double = 0.0

    var body: some View {
        VStack(spacing: 12) {
            // Timeline slider
            timelineSlider

            HStack(spacing: 20) {
                // Play/Pause button
                playPauseButton

                // Frame step buttons
                frameStepButtons

                Spacer()

                // Time display
                timeDisplay

                Spacer()

                // Speed control
                speedControl

                // Volume control
                volumeControl
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
    }

    // MARK: - Timeline Slider

    private var timelineSlider: some View {
        VStack(spacing: 4) {
            // Custom slider with frame markers
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    // Played portion
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition), height: 4)
                        .cornerRadius(2)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(x: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition) - 8)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isSeeking = true
                            let position = max(0, min(1, value.location.x / geometry.size.width))
                            seekPosition = position
                        }
                        .onEnded { _ in
                            viewModel.seek(to: seekPosition)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 16)
            .padding(.horizontal)
        }
    }

    // MARK: - Play/Pause Button

    private var playPauseButton: some View {
        Button(action: {
            viewModel.togglePlayPause()
        }) {
            Image(systemName: playPauseIcon)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .help(viewModel.playbackState == .playing ? "Pause" : "Play")
    }

    private var playPauseIcon: String {
        switch viewModel.playbackState {
        case .stopped, .paused:
            return "play.fill"
        case .playing:
            return "pause.fill"
        }
    }

    // MARK: - Frame Step Buttons

    private var frameStepButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                viewModel.stepBackward()
            }) {
                Image(systemName: "backward.frame.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Previous frame")

            Button(action: {
                viewModel.stepForward()
            }) {
                Image(systemName: "forward.frame.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Next frame")
        }
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Text(viewModel.currentTimeString)
                .font(.system(.body, design: .monospaced))

            Text("/")
                .foregroundColor(.secondary)

            Text(viewModel.durationString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Speed Control

    private var speedControl: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: {
                    viewModel.setPlaybackSpeed(speed)
                }) {
                    HStack {
                        Text(String(format: "%.2fx", speed))
                        if abs(viewModel.playbackSpeed - speed) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge")
                Text(viewModel.playbackSpeedString)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
        .help("Playback speed")
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Slider(value: Binding(
                get: { viewModel.volume },
                set: { viewModel.setVolume($0) }
            ), in: 0...1)
            .frame(width: 80)
        }
    }

    private var volumeIcon: String {
        if viewModel.volume == 0 {
            return "speaker.slash.fill"
        } else if viewModel.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if viewModel.volume < 0.67 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Preview

// Preview temporarily disabled - requires sample data
// struct PlayerControlsView_Previews: PreviewProvider {
//     static var previews: some View {
//         PlayerControlsView(viewModel: VideoPlayerViewModel())
//             .frame(height: 100)
//     }
// }
