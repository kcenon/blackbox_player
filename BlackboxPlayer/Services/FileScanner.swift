//
//  FileScanner.swift
//  BlackboxPlayer
//
//  Service for scanning and discovering dashcam video files
//

import Foundation

/// Service for scanning directories and discovering dashcam video files
class FileScanner {
    // MARK: - Properties

    /// Supported video file extensions
    private let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv"]

    /// Regular expression for BlackVue filename pattern (YYYYMMDD_HHMMSS_X.mp4)
    private let filenamePattern = #"^(\d{8})_(\d{6})_([FRLIi]+)\.(\w+)$"#
    private let filenameRegex: NSRegularExpression?

    // MARK: - Initialization

    init() {
        self.filenameRegex = try? NSRegularExpression(pattern: filenamePattern, options: [])
    }

    // MARK: - Public Methods

    /// Scan directory for dashcam video files
    /// - Parameter directoryURL: URL of directory to scan
    /// - Returns: Array of discovered video file groups
    /// - Throws: Error if directory cannot be accessed
    func scanDirectory(_ directoryURL: URL) throws -> [VideoFileGroup] {
        let fileManager = FileManager.default

        // Check if directory exists
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            throw FileScannerError.directoryNotFound(directoryURL.path)
        }

        // Get all files recursively
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw FileScannerError.cannotEnumerateDirectory(directoryURL.path)
        }

        var videoFiles: [VideoFileInfo] = []

        // Enumerate files
        for case let fileURL as URL in enumerator {
            // Check if it's a regular file
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }

            // Check extension
            let fileExtension = fileURL.pathExtension.lowercased()
            guard videoExtensions.contains(fileExtension) else {
                continue
            }

            // Parse filename
            if let fileInfo = parseVideoFile(fileURL) {
                videoFiles.append(fileInfo)
            }
        }

        // Group files by timestamp and base path
        let groups = groupVideoFiles(videoFiles)

        return groups
    }

    /// Quick scan to count video files without full parsing
    /// - Parameter directoryURL: URL of directory to scan
    /// - Returns: Number of video files found
    func countVideoFiles(in directoryURL: URL) -> Int {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: directoryURL.path),
              let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return 0
        }

        var count = 0
        for case let fileURL as URL in enumerator {
            let fileExtension = fileURL.pathExtension.lowercased()
            if videoExtensions.contains(fileExtension) {
                count += 1
            }
        }

        return count
    }

    // MARK: - Private Methods

    private func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        let filename = fileURL.lastPathComponent
        let pathString = fileURL.path

        // Try to match BlackVue pattern
        guard let regex = filenameRegex else { return nil }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range) else {
            // Not a BlackVue file, skip
            return nil
        }

        // Extract components
        guard match.numberOfRanges == 5 else { return nil }

        let dateString = (filename as NSString).substring(with: match.range(at: 1))
        let timeString = (filename as NSString).substring(with: match.range(at: 2))
        let positionCode = (filename as NSString).substring(with: match.range(at: 3))
        let extensionString = (filename as NSString).substring(with: match.range(at: 4))

        // Parse timestamp
        let timestampString = dateString + timeString  // "YYYYMMDDHHMMSS"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        guard let timestamp = dateFormatter.date(from: timestampString) else {
            return nil
        }

        // Detect camera position
        let position = CameraPosition.detect(from: positionCode)

        // Detect event type from path
        let eventType = EventType.detect(from: pathString)

        // Get file size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: pathString)[.size] as? UInt64) ?? 0

        // Create base filename (without camera position suffix)
        let baseFilename = "\(dateString)_\(timeString)"

        return VideoFileInfo(
            url: fileURL,
            timestamp: timestamp,
            position: position,
            eventType: eventType,
            fileSize: fileSize,
            baseFilename: baseFilename
        )
    }

    private func groupVideoFiles(_ files: [VideoFileInfo]) -> [VideoFileGroup] {
        // Group by base filename and event type
        var groups: [String: [VideoFileInfo]] = [:]

        for file in files {
            let key = "\(file.baseFilename)_\(file.eventType.rawValue)"
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(file)
        }

        // Convert to VideoFileGroup
        return groups.values.map { groupFiles in
            let sortedFiles = groupFiles.sorted { $0.position.displayPriority < $1.position.displayPriority }
            return VideoFileGroup(files: sortedFiles)
        }.sorted { $0.timestamp > $1.timestamp }  // Newest first
    }
}

// MARK: - Supporting Types

/// Information about a single video file
struct VideoFileInfo {
    let url: URL
    let timestamp: Date
    let position: CameraPosition
    let eventType: EventType
    let fileSize: UInt64
    let baseFilename: String
}

/// Group of video files from the same recording (multiple channels)
struct VideoFileGroup {
    let files: [VideoFileInfo]

    var timestamp: Date {
        return files.first?.timestamp ?? Date()
    }

    var eventType: EventType {
        return files.first?.eventType ?? .unknown
    }

    var baseFilename: String {
        return files.first?.baseFilename ?? ""
    }

    var basePath: String {
        guard let firstFile = files.first else { return "" }
        return firstFile.url.deletingLastPathComponent().path
    }

    var channelCount: Int {
        return files.count
    }

    var totalFileSize: UInt64 {
        return files.reduce(0) { $0 + $1.fileSize }
    }

    /// Get file URL for specific camera position
    func file(for position: CameraPosition) -> URL? {
        return files.first { $0.position == position }?.url
    }

    /// Check if group has file for specific position
    func hasChannel(_ position: CameraPosition) -> Bool {
        return files.contains { $0.position == position }
    }
}

/// Errors that can occur during file scanning
enum FileScannerError: Error {
    case directoryNotFound(String)
    case cannotEnumerateDirectory(String)
    case invalidPath(String)
}

extension FileScannerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .cannotEnumerateDirectory(let path):
            return "Cannot enumerate directory: \(path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}
