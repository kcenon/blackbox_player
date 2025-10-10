//
//  FileManagerService.swift
//  BlackboxPlayer
//
//  Service for managing video files (favorites, notes, deletion)
//

import Foundation

/// Service for managing video file metadata and operations
class FileManagerService {
    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let favoritesKey = "com.blackboxplayer.favorites"
    private let notesKey = "com.blackboxplayer.notes"

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Favorites

    /// Check if video file is marked as favorite
    /// - Parameter videoFile: VideoFile to check
    /// - Returns: true if favorited
    func isFavorite(_ videoFile: VideoFile) -> Bool {
        let favorites = loadFavorites()
        return favorites.contains(videoFile.id.uuidString)
    }

    /// Set favorite status for video file
    /// - Parameters:
    ///   - videoFile: VideoFile to update
    ///   - isFavorite: New favorite status
    func setFavorite(_ videoFile: VideoFile, isFavorite: Bool) {
        var favorites = loadFavorites()

        if isFavorite {
            favorites.insert(videoFile.id.uuidString)
        } else {
            favorites.remove(videoFile.id.uuidString)
        }

        saveFavorites(favorites)
    }

    /// Get all favorited video file IDs
    /// - Returns: Set of video file UUIDs
    func getAllFavorites() -> Set<String> {
        return loadFavorites()
    }

    /// Clear all favorites
    func clearAllFavorites() {
        userDefaults.removeObject(forKey: favoritesKey)
    }

    // MARK: - Notes

    /// Get note for video file
    /// - Parameter videoFile: VideoFile to get note for
    /// - Returns: Note text or nil if no note
    func getNote(for videoFile: VideoFile) -> String? {
        let notes = loadNotes()
        return notes[videoFile.id.uuidString]
    }

    /// Set note for video file
    /// - Parameters:
    ///   - videoFile: VideoFile to set note for
    ///   - note: Note text or nil to remove
    func setNote(for videoFile: VideoFile, note: String?) {
        var notes = loadNotes()

        if let note = note, !note.isEmpty {
            notes[videoFile.id.uuidString] = note
        } else {
            notes.removeValue(forKey: videoFile.id.uuidString)
        }

        saveNotes(notes)
    }

    /// Get all notes
    /// - Returns: Dictionary of video file UUID to note
    func getAllNotes() -> [String: String] {
        return loadNotes()
    }

    /// Clear all notes
    func clearAllNotes() {
        userDefaults.removeObject(forKey: notesKey)
    }

    // MARK: - File Operations

    /// Delete video file and all its channels
    /// - Parameter videoFile: VideoFile to delete
    /// - Throws: Error if deletion fails
    func deleteVideoFile(_ videoFile: VideoFile) throws {
        let fileManager = FileManager.default

        // Delete all channel files
        for channel in videoFile.channels {
            let filePath = channel.filePath
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
            }
        }

        // Remove from favorites and notes
        setFavorite(videoFile, isFavorite: false)
        setNote(for: videoFile, note: nil)
    }

    /// Move video file to different directory
    /// - Parameters:
    ///   - videoFile: VideoFile to move
    ///   - destinationURL: Destination directory URL
    /// - Returns: Updated VideoFile with new paths
    /// - Throws: Error if move fails
    func moveVideoFile(_ videoFile: VideoFile, to destinationURL: URL) throws -> VideoFile {
        let fileManager = FileManager.default

        // Create destination directory if needed
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        }

        // Move all channel files
        var newChannels: [ChannelInfo] = []

        for channel in videoFile.channels {
            let sourceURL = URL(fileURLWithPath: channel.filePath)
            let filename = sourceURL.lastPathComponent
            let destinationFileURL = destinationURL.appendingPathComponent(filename)

            // Move file
            try fileManager.moveItem(at: sourceURL, to: destinationFileURL)

            // Create new ChannelInfo with updated path
            let newChannel = ChannelInfo(
                id: channel.id,
                position: channel.position,
                filePath: destinationFileURL.path,
                width: channel.width,
                height: channel.height,
                frameRate: channel.frameRate,
                bitrate: channel.bitrate,
                codec: channel.codec,
                audioCodec: channel.audioCodec,
                isEnabled: channel.isEnabled,
                fileSize: channel.fileSize,
                duration: channel.duration
            )

            newChannels.append(newChannel)
        }

        // Create new VideoFile with updated paths
        return VideoFile(
            id: videoFile.id,
            timestamp: videoFile.timestamp,
            eventType: videoFile.eventType,
            duration: videoFile.duration,
            channels: newChannels,
            metadata: videoFile.metadata,
            basePath: destinationURL.path,
            isFavorite: videoFile.isFavorite,
            notes: videoFile.notes,
            isCorrupted: videoFile.isCorrupted
        )
    }

    /// Export video file to external location
    /// - Parameters:
    ///   - videoFile: VideoFile to export
    ///   - destinationURL: Export destination URL
    /// - Throws: Error if export fails
    func exportVideoFile(_ videoFile: VideoFile, to destinationURL: URL) throws {
        let fileManager = FileManager.default

        // Create destination directory if needed
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        }

        // Copy all channel files
        for channel in videoFile.channels {
            let sourceURL = URL(fileURLWithPath: channel.filePath)
            let filename = sourceURL.lastPathComponent
            let destinationFileURL = destinationURL.appendingPathComponent(filename)

            // Copy file
            try fileManager.copyItem(at: sourceURL, to: destinationFileURL)
        }
    }

    /// Get total size of all video files
    /// - Parameter videoFiles: Array of video files
    /// - Returns: Total size in bytes
    func getTotalSize(of videoFiles: [VideoFile]) -> UInt64 {
        return videoFiles.reduce(0) { total, file in
            total + file.totalFileSize
        }
    }

    /// Get available disk space at path
    /// - Parameter path: Path to check
    /// - Returns: Available space in bytes or nil if cannot determine
    func getAvailableDiskSpace(at path: String) -> UInt64? {
        do {
            let url = URL(fileURLWithPath: path)
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return values.volumeAvailableCapacity.map { UInt64($0) }
        } catch {
            return nil
        }
    }

    // MARK: - Batch Operations

    /// Apply favorite status to multiple files
    /// - Parameters:
    ///   - videoFiles: Array of video files
    ///   - isFavorite: Favorite status to apply
    func setFavorite(for videoFiles: [VideoFile], isFavorite: Bool) {
        var favorites = loadFavorites()

        for videoFile in videoFiles {
            if isFavorite {
                favorites.insert(videoFile.id.uuidString)
            } else {
                favorites.remove(videoFile.id.uuidString)
            }
        }

        saveFavorites(favorites)
    }

    /// Delete multiple video files
    /// - Parameter videoFiles: Array of video files to delete
    /// - Returns: Array of errors (empty if all successful)
    func deleteVideoFiles(_ videoFiles: [VideoFile]) -> [Error] {
        var errors: [Error] = []

        for videoFile in videoFiles {
            do {
                try deleteVideoFile(videoFile)
            } catch {
                errors.append(error)
            }
        }

        return errors
    }

    // MARK: - Private Methods

    private func loadFavorites() -> Set<String> {
        if let array = userDefaults.array(forKey: favoritesKey) as? [String] {
            return Set(array)
        }
        return []
    }

    private func saveFavorites(_ favorites: Set<String>) {
        userDefaults.set(Array(favorites), forKey: favoritesKey)
    }

    private func loadNotes() -> [String: String] {
        if let dictionary = userDefaults.dictionary(forKey: notesKey) as? [String: String] {
            return dictionary
        }
        return [:]
    }

    private func saveNotes(_ notes: [String: String]) {
        userDefaults.set(notes, forKey: notesKey)
    }
}

// MARK: - VideoFile Extension

extension VideoFile {
    /// Create updated VideoFile with favorite status
    /// - Parameter service: FileManagerService to use
    /// - Returns: Updated VideoFile
    func withUpdatedMetadata(from service: FileManagerService) -> VideoFile {
        let isFavorite = service.isFavorite(self)
        let notes = service.getNote(for: self)

        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }
}
