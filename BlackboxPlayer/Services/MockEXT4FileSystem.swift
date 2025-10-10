//
//  MockEXT4FileSystem.swift
//  BlackboxPlayer
//
//  Mock implementation of EXT4 file system for testing and development
//  This allows development without the actual C/C++ library
//

import Foundation

/// Mock EXT4 file system implementation for testing
/// Uses in-memory storage to simulate EXT4 operations
class MockEXT4FileSystem: EXT4FileSystemProtocol {

    // MARK: - Properties

    private var _isMounted: Bool = false
    private var currentDevicePath: String?
    private var fileSystem: [String: Data] = [:]  // path -> data
    private var fileInfoCache: [String: EXT4FileInfo] = [:]  // path -> info

    var isMounted: Bool {
        return _isMounted
    }

    // MARK: - Initialization

    init() {
        // Pre-populate with sample dashcam files for testing
        createSampleFiles()
    }

    // MARK: - Device Management

    func mount(devicePath: String) throws {
        guard !_isMounted else {
            throw EXT4Error.alreadyMounted
        }

        // Simulate device validation
        guard devicePath.starts(with: "/dev/") else {
            throw EXT4Error.deviceNotFound
        }

        currentDevicePath = devicePath
        _isMounted = true
    }

    func unmount() throws {
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        currentDevicePath = nil
        _isMounted = false
    }

    func getDeviceInfo() throws -> EXT4DeviceInfo {
        guard _isMounted, let devicePath = currentDevicePath else {
            throw EXT4Error.notMounted
        }

        // Calculate total size of all files
        let totalSize: UInt64 = fileSystem.values.reduce(0) { $0 + UInt64($1.count) }
        let mockTotalCapacity: UInt64 = 32 * 1024 * 1024 * 1024  // 32 GB
        let freeSpace = mockTotalCapacity - totalSize

        return EXT4DeviceInfo(
            devicePath: devicePath,
            volumeName: "DASHCAM_SD",
            totalSize: mockTotalCapacity,
            freeSpace: freeSpace,
            blockSize: 4096,
            isMounted: true
        )
    }

    // MARK: - File Operations

    func listFiles(at path: String) throws -> [EXT4FileInfo] {
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        let normalizedPath = normalizePath(path)
        let searchPrefix = normalizedPath.isEmpty ? "" : normalizedPath + "/"

        // Find all files in this directory (not recursive)
        var files: [EXT4FileInfo] = []
        var directories: Set<String> = []

        for filePath in fileSystem.keys {
            if filePath.hasPrefix(searchPrefix) {
                let relativePath = String(filePath.dropFirst(searchPrefix.count))

                // Check if it's a direct child (not in subdirectory)
                if !relativePath.contains("/") {
                    if let info = fileInfoCache[filePath] {
                        files.append(info)
                    }
                } else {
                    // Extract directory name
                    if let firstSlash = relativePath.firstIndex(of: "/") {
                        let dirName = String(relativePath[..<firstSlash])
                        directories.insert(dirName)
                    }
                }
            }
        }

        // Also check for explicitly created directories in fileInfoCache
        for (cachePath, info) in fileInfoCache where info.isDirectory {
            if cachePath.hasPrefix(searchPrefix) {
                let relativePath = String(cachePath.dropFirst(searchPrefix.count))

                // Check if it's a direct child directory
                if !relativePath.contains("/") {
                    directories.insert(info.name)
                }
            }
        }

        // Add directories
        for dirName in directories {
            let dirPath = normalizedPath.isEmpty ? dirName : "\(normalizedPath)/\(dirName)"
            // Use cached info if available, otherwise create new
            if let cachedInfo = fileInfoCache[dirPath] {
                files.append(cachedInfo)
            } else {
                files.append(EXT4FileInfo(
                    path: dirPath,
                    name: dirName,
                    size: 0,
                    isDirectory: true,
                    modificationDate: Date()
                ))
            }
        }

        return files.sorted { $0.name < $1.name }
    }

    func readFile(at path: String) throws -> Data {
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        let normalizedPath = normalizePath(path)

        guard let data = fileSystem[normalizedPath] else {
            throw EXT4Error.fileNotFound(path: path)
        }

        return data
    }

    func writeFile(data: Data, to path: String) throws {
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        let normalizedPath = normalizePath(path)

        // Simulate space check
        let deviceInfo = try getDeviceInfo()
        if UInt64(data.count) > deviceInfo.freeSpace {
            throw EXT4Error.insufficientSpace
        }

        fileSystem[normalizedPath] = data

        // Update file info
        let fileName = (normalizedPath as NSString).lastPathComponent
        fileInfoCache[normalizedPath] = EXT4FileInfo(
            path: normalizedPath,
            name: fileName,
            size: UInt64(data.count),
            isDirectory: false,
            creationDate: Date(),
            modificationDate: Date()
        )
    }

    func fileExists(at path: String) -> Bool {
        guard _isMounted else {
            return false
        }

        let normalizedPath = normalizePath(path)
        return fileSystem[normalizedPath] != nil
    }

    func getFileInfo(at path: String) throws -> EXT4FileInfo {
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        let normalizedPath = normalizePath(path)

        guard let info = fileInfoCache[normalizedPath] else {
            throw EXT4Error.fileNotFound(path: path)
        }

        return info
    }

    func deleteFile(at path: String) throws {
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        let normalizedPath = normalizePath(path)

        guard fileSystem[normalizedPath] != nil else {
            throw EXT4Error.fileNotFound(path: path)
        }

        fileSystem.removeValue(forKey: normalizedPath)
        fileInfoCache.removeValue(forKey: normalizedPath)
    }

    func createDirectory(at path: String) throws {
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        let normalizedPath = normalizePath(path)
        let dirName = (normalizedPath as NSString).lastPathComponent

        fileInfoCache[normalizedPath] = EXT4FileInfo(
            path: normalizedPath,
            name: dirName,
            size: 0,
            isDirectory: true,
            creationDate: Date(),
            modificationDate: Date()
        )
    }

    // MARK: - Sample Data Creation

    private func createSampleFiles() {
        // Create sample dashcam video files
        let sampleFiles: [(path: String, size: Int)] = [
            // Normal recordings
            ("normal/2025_01_10_09_00_00_F.mp4", 100 * 1024 * 1024),  // 100MB
            ("normal/2025_01_10_09_01_00_F.mp4", 100 * 1024 * 1024),
            ("normal/2025_01_10_09_02_00_F.mp4", 100 * 1024 * 1024),
            ("normal/2025_01_10_09_00_00_R.mp4", 80 * 1024 * 1024),   // Rear camera
            ("normal/2025_01_10_09_01_00_R.mp4", 80 * 1024 * 1024),

            // Impact/Event recordings
            ("event/2025_01_10_10_30_15_F.mp4", 50 * 1024 * 1024),
            ("event/2025_01_10_10_30_15_R.mp4", 40 * 1024 * 1024),

            // Parking mode
            ("parking/2025_01_10_18_00_00_F.mp4", 30 * 1024 * 1024),

            // GPS data files
            ("normal/2025_01_10_09_00_00_F.gps", 1024),
            ("normal/2025_01_10_09_01_00_F.gps", 1024),
            ("event/2025_01_10_10_30_15_F.gps", 512),

            // G-Sensor data files
            ("normal/2025_01_10_09_00_00_F.gsn", 2048),
            ("normal/2025_01_10_09_01_00_F.gsn", 2048),
            ("event/2025_01_10_10_30_15_F.gsn", 1024)
        ]

        for (path, size) in sampleFiles {
            // Create dummy data
            let data = Data(count: size)
            fileSystem[path] = data

            let fileName = (path as NSString).lastPathComponent
            let now = Date()

            fileInfoCache[path] = EXT4FileInfo(
                path: path,
                name: fileName,
                size: UInt64(size),
                isDirectory: false,
                creationDate: now,
                modificationDate: now
            )
        }
    }

    // MARK: - Testing Helpers

    /// Reset the mock filesystem to initial state
    func reset() {
        _isMounted = false
        currentDevicePath = nil
        fileSystem.removeAll()
        fileInfoCache.removeAll()
        createSampleFiles()
    }

    /// Add a custom test file
    func addTestFile(path: String, data: Data) {
        fileSystem[path] = data
        let fileName = (path as NSString).lastPathComponent
        fileInfoCache[path] = EXT4FileInfo(
            path: path,
            name: fileName,
            size: UInt64(data.count),
            isDirectory: false,
            creationDate: Date(),
            modificationDate: Date()
        )
    }
}
