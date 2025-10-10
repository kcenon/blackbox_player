//
//  FileListView.swift
//  BlackboxPlayer
//
//  Main view for displaying list of dashcam video files
//

import SwiftUI

struct FileListView: View {
    // Bindings from parent view
    @Binding var videoFiles: [VideoFile]
    @Binding var selectedFile: VideoFile?

    // Local filter states
    @State private var searchText = ""
    @State private var selectedEventType: EventType? = nil

    // Filtered files based on search and event type
    private var filteredFiles: [VideoFile] {
        var files = videoFiles

        // Filter by search text
        if !searchText.isEmpty {
            files = files.filter { file in
                file.baseFilename.localizedCaseInsensitiveContains(searchText) ||
                file.timestampString.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by event type
        if let eventType = selectedEventType {
            files = files.filter { $0.eventType == eventType }
        }

        // Sort by timestamp (newest first)
        return files.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search videos...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding()

            // Event type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterButton(
                        title: "All",
                        isSelected: selectedEventType == nil,
                        action: { selectedEventType = nil }
                    )

                    ForEach(EventType.allCases, id: \.self) { eventType in
                        FilterButton(
                            title: eventType.displayName,
                            color: Color(hex: eventType.colorHex),
                            isSelected: selectedEventType == eventType,
                            action: { selectedEventType = eventType }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)

            Divider()

            // File list
            if filteredFiles.isEmpty {
                EmptyStateView()
            } else {
                List(filteredFiles, selection: $selectedFile) { file in
                    FileRow(videoFile: file, isSelected: selectedFile?.id == file.id)
                        .tag(file)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
                .listStyle(.plain)
            }

            Divider()

            // Status bar
            StatusBar(fileCount: filteredFiles.count, totalCount: videoFiles.count)
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    var color: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : (color ?? .primary))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? (color ?? Color.accentColor) : Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Videos Found")
                .font(.title2)
                .fontWeight(.medium)

            Text("Try adjusting your search or filters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    let fileCount: Int
    let totalCount: Int

    var body: some View {
        HStack {
            Text("\(fileCount) of \(totalCount) videos")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // TODO: Add more status information
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Placeholder Views

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Select a video to view details")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileDetailView: View {
    let videoFile: VideoFile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Basic info
                VStack(alignment: .leading, spacing: 8) {
                    Text(videoFile.baseFilename)
                        .font(.title)
                        .fontWeight(.bold)

                    HStack {
                        EventBadge(eventType: videoFile.eventType)
                        Text(videoFile.timestampString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // File details
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Information")
                        .font(.headline)

                    DetailRow(label: "Duration", value: videoFile.durationString)
                    DetailRow(label: "Size", value: videoFile.totalFileSizeString)
                    DetailRow(label: "Channels", value: "\(videoFile.channelCount)")
                }

                // Channel list
                if !videoFile.channels.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Channels")
                            .font(.headline)

                        ForEach(videoFile.channels) { channel in
                            ChannelRow(channel: channel)
                        }
                    }
                }

                // Metadata summary
                if videoFile.hasGPSData || videoFile.hasAccelerationData {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadata")
                            .font(.headline)

                        let summary = videoFile.metadata.summary

                        if videoFile.hasGPSData {
                            DetailRow(label: "Distance", value: summary.distanceString)
                            if let avgSpeed = summary.averageSpeedString {
                                DetailRow(label: "Avg Speed", value: avgSpeed)
                            }
                            if let maxSpeed = summary.maximumSpeedString {
                                DetailRow(label: "Max Speed", value: maxSpeed)
                            }
                        }

                        if videoFile.hasAccelerationData {
                            DetailRow(label: "Impact Events", value: "\(summary.impactEventCount)")
                            if let maxGForce = summary.maximumGForceString {
                                DetailRow(label: "Max G-Force", value: maxGForce)
                            }
                        }
                    }
                }

                // Notes
                if let notes = videoFile.notes {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)

                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct ChannelRow: View {
    let channel: ChannelInfo

    var body: some View {
        HStack {
            Image(systemName: "video.fill")
                .foregroundColor(.secondary)

            Text(channel.position.displayName)
                .fontWeight(.medium)

            Spacer()

            Text(channel.resolutionName)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(channel.frameRateString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Preview

struct FileListView_Previews: PreviewProvider {
    static var previews: some View {
        FileListViewPreviewWrapper()
    }
}

private struct FileListViewPreviewWrapper: View {
    @State private var videoFiles: [VideoFile] = VideoFile.allSamples
    @State private var selectedFile: VideoFile?

    var body: some View {
        FileListView(videoFiles: $videoFiles, selectedFile: $selectedFile)
            .frame(width: 400, height: 600)
    }
}
