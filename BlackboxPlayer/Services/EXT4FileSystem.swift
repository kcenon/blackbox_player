//
//  EXT4FileSystem.swift
//  BlackboxPlayer
//
//  Protocol-based EXT4 file system interface for easy C library integration
//

import Foundation

// MARK: - EXT4 Error Types

/// Errors that can occur during EXT4 file system operations
enum EXT4Error: Error, Equatable {
    case deviceNotFound
    case mountFailed(reason: String)
    case unmountFailed(reason: String)
    case alreadyMounted
    case notMounted
    case invalidPath
    case fileNotFound(path: String)
    case readFailed(path: String, reason: String)
    case writeFailed(path: String, reason: String)
    case permissionDenied
    case insufficientSpace
    case corruptedFileSystem
    case unsupportedOperation
    case unknownError(code: Int32)

    var localizedDescription: String {
        switch self {
        case .deviceNotFound:
            return "Device not found or disconnected"
        case .mountFailed(let reason):
            return "Failed to mount EXT4 filesystem: \(reason)"
        case .unmountFailed(let reason):
            return "Failed to unmount EXT4 filesystem: \(reason)"
        case .alreadyMounted:
            return "Device is already mounted"
        case .notMounted:
            return "Device is not mounted"
        case .invalidPath:
            return "Invalid file path"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .readFailed(let path, let reason):
            return "Failed to read file '\(path)': \(reason)"
        case .writeFailed(let path, let reason):
            return "Failed to write file '\(path)': \(reason)"
        case .permissionDenied:
            return "Permission denied"
        case .insufficientSpace:
            return "Insufficient disk space"
        case .corruptedFileSystem:
            return "Corrupted file system"
        case .unsupportedOperation:
            return "Operation not supported"
        case .unknownError(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

// MARK: - File Information

/// Information about a file in the EXT4 filesystem
struct EXT4FileInfo: Equatable, Codable {
    let path: String
    let name: String
    let size: UInt64
    let isDirectory: Bool
    let creationDate: Date?
    let modificationDate: Date?
    let permissions: UInt16

    init(
        path: String,
        name: String,
        size: UInt64,
        isDirectory: Bool,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        permissions: UInt16 = 0o644
    ) {
        self.path = path
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.permissions = permissions
    }
}

// MARK: - Device Information

/// Information about an EXT4 storage device
struct EXT4DeviceInfo: Equatable {
    let devicePath: String
    let volumeName: String?
    let totalSize: UInt64
    let freeSpace: UInt64
    let blockSize: UInt32
    let isMounted: Bool

    var usedSpace: UInt64 {
        return totalSize > freeSpace ? totalSize - freeSpace : 0
    }

    var usagePercentage: Double {
        guard totalSize > 0 else { return 0.0 }
        return Double(usedSpace) / Double(totalSize) * 100.0
    }
}

// MARK: - EXT4 File System Protocol

/// Protocol defining EXT4 file system operations
/// This abstraction allows for easy integration of C/C++ libraries
protocol EXT4FileSystemProtocol {

    // MARK: - Device Management

    /// Mount an EXT4 device
    /// - Parameter devicePath: Path to the device (e.g., "/dev/disk2s1")
    /// - Throws: EXT4Error if mounting fails
    func mount(devicePath: String) throws

    /// Unmount the currently mounted device
    /// - Throws: EXT4Error if unmounting fails
    func unmount() throws

    /// Check if a device is currently mounted
    var isMounted: Bool { get }

    /// Get information about the mounted device
    /// - Throws: EXT4Error.notMounted if no device is mounted
    func getDeviceInfo() throws -> EXT4DeviceInfo

    // MARK: - File Operations

    /// List files in a directory
    /// - Parameter path: Directory path (relative to mount point)
    /// - Returns: Array of file information
    /// - Throws: EXT4Error if operation fails
    func listFiles(at path: String) throws -> [EXT4FileInfo]

    /// Read file contents
    /// - Parameter path: File path (relative to mount point)
    /// - Returns: File data
    /// - Throws: EXT4Error if operation fails
    func readFile(at path: String) throws -> Data

    /// Write data to a file
    /// - Parameters:
    ///   - data: Data to write
    ///   - path: File path (relative to mount point)
    /// - Throws: EXT4Error if operation fails
    func writeFile(data: Data, to path: String) throws

    /// Check if a file or directory exists
    /// - Parameter path: File or directory path
    /// - Returns: true if exists, false otherwise
    func fileExists(at path: String) -> Bool

    /// Get file information
    /// - Parameter path: File path
    /// - Returns: File information
    /// - Throws: EXT4Error if file doesn't exist or operation fails
    func getFileInfo(at path: String) throws -> EXT4FileInfo

    /// Delete a file
    /// - Parameter path: File path
    /// - Throws: EXT4Error if operation fails
    func deleteFile(at path: String) throws

    /// Create a directory
    /// - Parameter path: Directory path
    /// - Throws: EXT4Error if operation fails
    func createDirectory(at path: String) throws

    // MARK: - Async Operations (for future use)

    /// Asynchronously read a large file
    /// - Parameter path: File path
    /// - Returns: File data
    /// - Throws: EXT4Error if operation fails
    @available(macOS 12.0, *)
    func readFileAsync(at path: String) async throws -> Data
}

// MARK: - Default Implementations

extension EXT4FileSystemProtocol {

    /// Default async implementation using dispatch queue
    @available(macOS 12.0, *)
    func readFileAsync(at path: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try self.readFile(at: path)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Helper to normalize paths (remove leading/trailing slashes)
    func normalizePath(_ path: String) -> String {
        var normalized = path.trimmingCharacters(in: .whitespaces)
        // Remove leading slash
        if normalized.hasPrefix("/") {
            normalized = String(normalized.dropFirst())
        }
        // Remove trailing slash
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        return normalized
    }
}
