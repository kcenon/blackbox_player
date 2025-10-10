//
//  FileRow.swift
//  BlackboxPlayer
//
//  Row component for displaying video file in list
//

import SwiftUI

struct FileRow: View {
    let videoFile: VideoFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Event type badge
            EventBadge(eventType: videoFile.eventType)
                .frame(width: 80)

            // File information
            VStack(alignment: .leading, spacing: 4) {
                // Filename
                Text(videoFile.baseFilename)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Timestamp
                Text(videoFile.timestampString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Metadata info
                HStack(spacing: 12) {
                    // Duration
                    Label(videoFile.durationString, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // File size
                    Label(videoFile.totalFileSizeString, systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Channel count
                    Label("\(videoFile.channelCount) channels", systemImage: "video")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // GPS indicator
                    if videoFile.hasGPSData {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    // Impact indicator
                    if videoFile.hasImpactEvents {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    // Favorite indicator
                    if videoFile.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }

                    // Corrupted indicator
                    if videoFile.isCorrupted {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            // Playback button
            if videoFile.isPlayable {
                Button(action: {
                    // TODO: Play video
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Event Badge

struct EventBadge: View {
    let eventType: EventType

    var body: some View {
        Text(eventType.displayName.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: eventType.colorHex))
            )
    }
}

// MARK: - Preview

struct FileRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            FileRow(videoFile: .normal5Channel, isSelected: false)
            FileRow(videoFile: .impact2Channel, isSelected: true)
            FileRow(videoFile: .parking1Channel, isSelected: false)
            FileRow(videoFile: .favoriteRecording, isSelected: false)
            FileRow(videoFile: .corruptedFile, isSelected: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
