/// @file FileSystemService.swift
/// @brief Service for accessing files on SD card file system
/// @author BlackboxPlayer Development Team
/// @details Service for accessing SD card file system to read files, query information, and delete files.

/*
 
 File System Service
 

 [Purpose of this File]
 Safely accesses the SD card file system using macOS FileManager.
 Low-level service that forms the foundation of all file I/O operations.

 [Key Features]
 1. query video file list (listVideoFiles)
 2. file reading (readFile)
 3. file information query (getFileInfo)
 4. file deletion (deleteFiles)

 [Design Principles]
 - Native API usage: Support for APFS/FAT32/exFAT via macOS FileManager
 - Error handling: Explicit error propagation with throws
 - Type safety: Provides specific error information with FileSystemError enum
 - Testability: Mockable with protocol-based design

 [Integration Points]
 - FileScanner: can be used for file list query
 - FileManagerService: file access for metadata management
 - VideoFileLoader: reading video files

 
 */

import Foundation

// MARK: - File System Error

/*
 
 FileSystemError Enumeration
 

 [Error Types]
 - accessDenied: no file access permission
 - readFailed: file reading failure
 - writeFailed: failed to write/delete file
 - listFailed: failed to list directory
 - deviceNotFound: SD none
 - permissionDenied: macOS permission deny
 - fileNotFound: file does not exist

 Associated Values
 String type information ha.

 e.g.
 -.readFailed("Permission denied")
 -.listFailed("Directory does not exist")

 LocalizedError
 za to has remove
 
 */

/// @enum FileSystemError
/// @brief Errors that can occur during file system operations
enum FileSystemError: Error {
 /// @brief No file access permission
 ///
 /// Occurrence scenarios:
 /// - macOS Insufficient permissions
 /// - File system permission configuration issue
 /// - SD card mounted as read-only
 case accessDenied

 /// @brief Failed to read file
 ///
 /// Includes failure reason as associated value:
 /// ```swift
 /// throw FileSystemError.readFailed("File is corrupted")
 /// ```
 case readFailed(String)

 /// @brief Failed to write or delete file
 ///
 /// Occurrence scenarios:
 /// - Insufficient disk space
 /// - File locked by another process
 /// - Read-only file system
 case writeFailed(String)

 /// @brief Failed to list directory
 ///
 /// Occurrence scenarios:
 /// - Directory does not exist
 /// - No permission to read directory
 case listFailed(String)

 /// @brief SD card device not found
 ///
 /// Occurrence scenarios:
 /// - SD card not connected
 /// - SD card not mounted
 case deviceNotFound

 /// @brief Permission denied
 ///
 /// Occurrence scenarios:
 /// - User denied file access
 /// - Missing sandbox entitlements
 case permissionDenied

 /// @brief File not found
 ///
 /// Occurrence scenarios:
 /// - File was deleted
 /// - Incorrect path
 /// - SD card unmounted
 case fileNotFound
}

extension FileSystemError: LocalizedError {
 /// @brief Error message to display to user
 var errorDescription: String? {
 switch self {
 case.accessDenied:
 return "Access denied. Please check file permissions."
 case.readFailed(let reason):
 return "Failed to read file: \(reason)"
 case.writeFailed(let reason):
 return "Failed to write file: \(reason)"
 case.listFailed(let reason):
 return "Failed to list directory: \(reason)"
 case.deviceNotFound:
 return "SD card device not found. Please insert SD card."
 case.permissionDenied:
 return "Permission denied. Please grant file access in System Preferences."
 case.fileNotFound:
 return "File not found."
 }
 }
}

// MARK: - File Info

/*
 
 FileInfo Structure
 

 [Purpose]
 file metadata lightweight structure

 [Field Descriptions]
 - name: file (e.g. "video.mp4")
 - size: file size (bytes)
 - isDirectory: directory 
 - path: 
 - creationDate: creation date
 - modificationDate: modification date

 [Usage Scenarios]
 ```swift
 let fileInfo = try fileSystemService.getFileInfo(at: url)
 print("File: \(fileInfo.name)")
 print("size: \(fileInfo.size) bytes")
 print(": \(fileInfo.creationDate)")
 ```
 
 */

/// @struct FileInfo
/// @brief File metadata information
struct FileInfo {
 /// @var name
 /// @brief Filename (including extension)
 let name: String

 /// @var size
 /// @brief File size (bytes)
 let size: Int64

 /// @var isDirectory
 /// @brief directory 
 let isDirectory: Bool

 /// @var path
 /// @brief file 
 let path: String

 /// @var creationDate
 /// @brief File creation date (may not exist)
 let creationDate: Date?

 /// @var modificationDate
 /// @brief File modification date (may not exist)
 let modificationDate: Date?
}

// MARK: - File System Service

/*
 
 FileSystemService Class
 

 [Role]
 macOS FileManager wrapping safe file system access remove.

 [Key Methods]
 1. listVideoFiles(at:) - query video file list
 2. readFile(at:) - file contents reading
 3. getFileInfo(at:) - file metadata query
 4. deleteFiles(_:) - file deletion

 [Thread Safety]
 FileManager.default beforeha therefore,
 Independent per instance FileManager has.

 [Testing]
 protocol mock mockable design:
 ```swift
 protocol FileSystemServiceProtocol {
 func listVideoFiles(at url: URL) throws -> [URL]
 //...
 }
 ```
 
 */

/// @class FileSystemService
/// @brief SD card file system access service
///
/// Accesses FAT32/exFAT/APFS file systems using macOS FileManager.
/// Low-level service that forms the foundation of all file I/O operations.
class FileSystemService {
 // MARK: - Properties

 /// @var fileManager
 /// @brief FileManager instance
 ///
 /// Uses independent FileManager per instance for thread safety.
 /// FileManager.default is not thread-safe, so caution needed.
 private let fileManager: FileManager

 /// @var supportedVideoExtensions
 /// @brief Supported video file extensions
 ///
 /// Stored as Set for O(1) time inclusion check.
 /// Commonly used formats in dashcams:
 /// - mp4: H.264/H.265, most common
 /// - h264: Raw H.264 stream
 /// - avi: legacy format
 private let supportedVideoExtensions: Set<String> = ["mp4", "h264", "avi"]

 // MARK: - Initialization

 /*
 
 Initialization
 

 [Dependency Injection]
 Improves testability by injecting FileManager:

 Production:
 ```swift
 let service = FileSystemService() // FileManager.default 
 ```

 Testing:
 ```swift
 let mockFileManager = MockFileManager()
 let service = FileSystemService(fileManager: mockFileManager)
 ```
 
 */

 /// @brief FileSystemService Initialization
 ///
 /// @param fileManager FileManager instance (default: FileManager.default)
 ///
 /// Usage example:
 /// ```swift
 /// // Basic usage
 /// let service = FileSystemService()
 ///
 /// // Inject mock for testing
 /// let service = FileSystemService(fileManager: mockFileManager)
 /// ```
 init(fileManager: FileManager = .default) {
 self.fileManager = fileManager
 }

 // MARK: - Public Methods

 /*
 
 Method 1: listVideoFiles
 

 [Purpose]
 Retrieves list of video files from directory.

 [Algorithm]
 1. Verify directory exists
 2. Recursive traversal with FileManager.enumerator
 3. file only Filtering (excludes directories, symbolic links)
 4. za only Filtering (.mp4,.h264,.avi)
 5. Return URL array

 [enumerator Options]
 - includingPropertiesForKeys: properties to preload (performance improvement)
 -.isRegularFileKey: file 
 -.fileSizeKey: file size
 -.creationDateKey: creation date
 - options:
 -.skipsHiddenFiles: exclude hidden files (.DS_Store etc.)

 [Performance]
 - Time complexity: O(N) - N is total file count in directory
 - Space complexity: O(M) - M is video file count
 
 */

 /// @brief Retrieve list of video files in directory
 ///
 /// Recursively traverses directory to return only video files (.mp4,.h264,.avi).
 ///
 /// @param url to directory URL
 /// @return video files URL 
 /// @throws FileSystemError
 /// -.fileNotFound: Directory does not exist
 /// -.accessDenied: No permission to access directory
 ///
 /// Usage example:
 /// ```swift
 /// let service = FileSystemService()
 /// let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")
 ///
 /// do {
 /// let videoFiles = try service.listVideoFiles(at: sdCardURL)
 /// print("\(videoFiles.count) video files found")
 ///
 /// for videoURL in videoFiles {
 /// print(videoURL.lastPathComponent)
 /// }
 /// } catch FileSystemError.fileNotFound {
 /// print("Directory not found")
 /// } catch FileSystemError.accessDenied {
 /// print("No permission to access directory")
 /// } catch {
 /// print("Error: \(error)")
 /// }
 /// ```
 func listVideoFiles(at url: URL) throws -> [URL] {
 // 1step: Verify directory exists
 guard fileManager.fileExists(atPath: url.path) else {
 throw FileSystemError.fileNotFound
 }

 // 2step: Create recursive enumerator
 guard let enumerator = fileManager.enumerator(
 at: url,
 includingPropertiesForKeys: [.isRegularFileKey,.fileSizeKey,.creationDateKey],
 options: [.skipsHiddenFiles]
 ) else {
 throw FileSystemError.accessDenied
 }

 var videoFiles: [URL] = []

 // Step 3: Iterate through all items
 for case let fileURL as URL in enumerator {
 // 3-1: Check if regular file (excludes directories, symbolic links)
 do {
 let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
 guard let isRegularFile = resourceValues.isRegularFile, isRegularFile else {
 continue
 }
 } catch {
 // Skip if attribute reading fails
 continue
 }

 // 3-2: Check video extension
 let ext = fileURL.pathExtension.lowercased()
 if supportedVideoExtensions.contains(ext) {
 videoFiles.append(fileURL)
 }
 }

 return videoFiles
 }

 /*
 
 Method 2: readFile
 

 [Purpose]
 Reads entire file contents into memory.

 [Precautions]
 Possibility of memory shortage when reading large files (1GB+):
 - Video files are typically 100-500MB
 - Recommend streaming approach instead of loading entire file into memory

 [Alternatives]
 Streaming:
 ```swift
 let fileHandle = try FileHandle(forReadingFrom: url)
 while let chunk = try fileHandle.read(upToCount: 1024 * 1024) {
 // Process 1MB at a time
 }
 ```

 [Usage Scenarios]
 - Reading metadata files (GPS logs, configuration files)
 - Small video clips
 - File validation (header check)
 
 */

 /// @brief Read entire file contents
 ///
 /// Reads file into memory and returns as Data object.
 /// Large files can cause memory shortage, so caution is needed.
 ///
 /// @param url URL of file to read
 /// @return File contents (Data)
 /// @throws FileSystemError
 /// -.accessDenied: No permission to read file
 /// -.readFailed: file reading failure
 ///
 /// Usage example:
 /// ```swift
 /// let fileURL = URL(fileURLWithPath: "/Volumes/SD/gps.log")
 ///
 /// do {
 /// let data = try service.readFile(at: fileURL)
 /// print("File size: \(data.count) bytes")
 ///
 /// if let content = String(data: data, encoding:.utf8) {
 /// print("Content: \(content)")
 /// }
 /// } catch {
 /// print("Failed to read file: \(error)")
 /// }
 /// ```
 ///
 /// Caution:
 /// - large files(1GB+) memory shortage possible
 /// - Streaming approach recommended for video files
 func readFile(at url: URL) throws -> Data {
 // reading Check permissions
 guard fileManager.isReadableFile(atPath: url.path) else {
 throw FileSystemError.accessDenied
 }

 // Read file
 do {
 return try Data(contentsOf: url)
 } catch {
 throw FileSystemError.readFailed(error.localizedDescription)
 }
 }

 /*
 
 Method 3: getFileInfo
 

 [Purpose]
 Retrieves file metadata.

 [Queried Attributes]
 Read following attributes with FileManager.attributesOfItem:
 -.size: file size (Int64)
 -.type: file type (.typeRegular,.typeDirectory)
 -.creationDate: creation date (Date)
 -.modificationDate: modification date (Date)

 [Type Casting]
 attributesOfItem returns [FileAttributeKey: Any]:
 ```swift
 let size = attributes[.size] as? Int64 ?? 0
 let creationDate = attributes[.creationDate] as? Date
 ```

 [Use Cases]
 - file list UI display
 - sorting (size, date)
 - Filtering (after specific date)
 
 */

 /// @brief File metadata information query
 ///
 /// Retrieves metadata such as file size and creation/modification dates.
 ///
 /// @param url URL of file to query
 /// @return FileInfo Structure
 /// @throws FileSystemError
 /// -.fileNotFound: file does not exist
 /// -.readFailed: Failed to read attributes
 ///
 /// Usage example:
 /// ```swift
 /// let fileURL = URL(fileURLWithPath: "/Volumes/SD/video.mp4")
 ///
 /// do {
 /// let info = try service.getFileInfo(at: fileURL)
 /// print("file: \(info.name)")
 /// print("size: \(info.size) bytes")
 /// print(": \(info.creationDate ?? Date())")
 /// print("Directory: \(info.isDirectory)")
 /// } catch {
 /// print("Failed to retrieve information: \(error)")
 /// }
 /// ```
 func getFileInfo(at url: URL) throws -> FileInfo {
 // Check if file exists
 guard fileManager.fileExists(atPath: url.path) else {
 throw FileSystemError.fileNotFound
 }

 // Retrieve file attributes
 do {
 let attributes = try fileManager.attributesOfItem(atPath: url.path)

 return FileInfo(
 name: url.lastPathComponent,
 size: attributes[.size] as? Int64 ?? 0,
 isDirectory: (attributes[.type] as? FileAttributeType) == .typeDirectory,
 path: url.path,
 creationDate: attributes[.creationDate] as? Date,
 modificationDate: attributes[.modificationDate] as? Date
 )
 } catch {
 throw FileSystemError.readFailed(error.localizedDescription)
 }
 }

 /*
 
 Method 4: deleteFiles
 

 [Purpose]
 Deletes multiple files at once.

 [Transaction]
 Current implementation is non-transactional:
 - If fails midway, only some files deleted
 - Cannot recover

 When implementing transaction:
 1. Move all files to temporary location
 2. Delete for real if all successful
 3. Restore to original location if failed

 [Error Handling]
 Immediately throws at first failure:
 ```swift
 for url in urls {
 try fileManager.removeItem(at: url) // Exit immediately on failure
 }
 ```

 [Usage Cautions]
 delete Cannot recoverha ha:
 - Display user confirmation dialog
 - Consider moving to trash
 - Log recording
 
 */

 /// @brief Batch delete files
 ///
 /// Deletes multiple files at once.
 /// Some files may be deleted if failure occurs midway (non-transactional).
 ///
 /// @param urls Array of file URLs to delete
 /// @throws FileSystemError
 /// -.writeFailed: file deletion failure
 ///
 /// Usage example:
 /// ```swift
 /// let filesToDelete = [
 /// URL(fileURLWithPath: "/Volumes/SD/old1.mp4"),
 /// URL(fileURLWithPath: "/Volumes/SD/old2.mp4")
 /// ]
 ///
 /// do {
 /// try service.deleteFiles(filesToDelete)
 /// print("\(filesToDelete.count) files delete ")
 /// } catch FileSystemError.writeFailed(let reason) {
 /// print("Failed to delete: \(reason)")
 /// }
 /// ```
 ///
 /// Caution:
 /// - delete Cannot recover
 /// - If fails midway, only some files deleted
 /// - User confirmation needed
 func deleteFiles(_ urls: [URL]) throws {
 for url in urls {
 do {
 try fileManager.removeItem(at: url)
 } catch {
 throw FileSystemError.writeFailed("Failed to delete \(url.lastPathComponent): \(error.localizedDescription)")
 }
 }
 }
}

/*
 
 
 

 [1. Basic Usage]

 ```swift
 let fileSystemService = FileSystemService()
 let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")

 do {
 // query video file list
 let videoFiles = try fileSystemService.listVideoFiles(at: sdCardURL)
 print("\(videoFiles.count) video files")

 for videoURL in videoFiles {
 // file information query
 let info = try fileSystemService.getFileInfo(at: videoURL)
 print("\(info.name): \(info.size) bytes")
 }

 // Read file ( metadata file)
 let gpsURL = sdCardURL.appendingPathComponent("GPS/20240115.nmea")
 let gpsData = try fileSystemService.readFile(at: gpsURL)

 // file deletion
 let oldFiles = videoFiles.filter { url in
 let info = try? fileSystemService.getFileInfo(at: url)
 let isOld = info?.creationDate?.timeIntervalSinceNow ?? 0 < -7 * 24 * 3600
 return isOld
 }
 try fileSystemService.deleteFiles(oldFiles)

 } catch FileSystemError.fileNotFound {
 print("file not found")
 } catch FileSystemError.accessDenied {
 print("file access permission not found")
 } catch {
 print("Error: \(error)")
 }
 ```

 [2. Integration with FileScanner]

 FileScanner FileManager haonly,
 FileSystemService haregister:

 ```swift
 class FileScanner {
 private let fileSystemService: FileSystemService

 init(fileSystemService: FileSystemService = FileSystemService()) {
 self.fileSystemService = fileSystemService
 }

 func scanDirectory(_ directoryURL: URL) throws -> [VideoFileGroup] {
 // FileSystemService 
 let videoFiles = try fileSystemService.listVideoFiles(at: directoryURL)

 // file Grouping
 //...
 }
 }
 ```

 [3. SwiftUI ViewModel Integration]

 ```swift
 @MainActor
 class FileListViewModel: ObservableObject {
 @Published var videoFiles: [URL] = []
 @Published var errorMessage: String?

 private let fileSystemService: FileSystemService

 init(fileSystemService: FileSystemService = FileSystemService()) {
 self.fileSystemService = fileSystemService
 }

 func loadFiles(from url: URL) async {
 do {
 let files = try fileSystemService.listVideoFiles(at: url)
 self.videoFiles = files
 } catch FileSystemError.fileNotFound {
 self.errorMessage = "SD not found"
 } catch FileSystemError.accessDenied {
 self.errorMessage = "file access permission "
 } catch {
 self.errorMessage = "Error: \(error.localizedDescription)"
 }
 }

 func deleteFile(_ url: URL) async {
 do {
 try fileSystemService.deleteFiles([url])
 videoFiles.removeAll { $0 == url }
 } catch {
 self.errorMessage = "file deletion failure"
 }
 }
 }
 ```

 [4. Test Code]

 ```swift
 class FileSystemServiceTests: XCTestCase {
 var service: FileSystemService!
 var testDirectory: URL!

 override func setUp() {
 service = FileSystemService()
 testDirectory = createTestDirectory()
 }

 func testListVideoFiles() throws {
 // Create test files
 createTestFile("video1.mp4", in: testDirectory)
 createTestFile("video2.mp4", in: testDirectory)
 createTestFile("document.txt", in: testDirectory)

 // video files only query
 let videoFiles = try service.listVideoFiles(at: testDirectory)

 // Verify
 XCTAssertEqual(videoFiles.count, 2)
 XCTAssertTrue(videoFiles.allSatisfy { $0.pathExtension == "mp4" })
 }

 func testGetFileInfo() throws {
 let fileURL = createTestFile("test.mp4", size: 1024, in: testDirectory)

 let info = try service.getFileInfo(at: fileURL)

 XCTAssertEqual(info.name, "test.mp4")
 XCTAssertEqual(info.size, 1024)
 XCTAssertFalse(info.isDirectory)
 XCTAssertNotNil(info.creationDate)
 }

 func testReadFile() throws {
 let content = "test content"
 let fileURL = createTestFile("test.txt", content: content, in: testDirectory)

 let data = try service.readFile(at: fileURL)
 let readContent = String(data: data, encoding:.utf8)

 XCTAssertEqual(readContent, content)
 }

 func testDeleteFiles() throws {
 let file1 = createTestFile("file1.mp4", in: testDirectory)
 let file2 = createTestFile("file2.mp4", in: testDirectory)

 try service.deleteFiles([file1, file2])

 XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path))
 XCTAssertFalse(FileManager.default.fileExists(atPath: file2.path))
 }

 func testFileNotFound() {
 let nonexistentURL = URL(fileURLWithPath: "/nonexistent/path")

 XCTAssertThrowsError(try service.listVideoFiles(at: nonexistentURL)) { error in
 XCTAssertTrue(error is FileSystemError)
 if case FileSystemError.fileNotFound = error {
 // Expected
 } else {
 XCTFail("Expected fileNotFound error")
 }
 }
 }
 }
 ```

 [5. Integration with DeviceDetector]

 DeviceDetector SD ha FileSystemService file access:

 ```swift
 class ContentViewModel: ObservableObject {
 @Published var videoFiles: [URL] = []

 private let deviceDetector = DeviceDetector()
 private let fileSystemService = FileSystemService()

 func startMonitoring() {
 deviceDetector.monitorDeviceChanges(
 onConnect: { [weak self] volumeURL in
 self?.handleSDCardConnected(volumeURL)
 },
 onDisconnect: { [weak self] volumeURL in
 self?.handleSDCardDisconnected(volumeURL)
 }
 )
 }

 private func handleSDCardConnected(_ volumeURL: URL) {
 Task { @MainActor in
 do {
 let files = try fileSystemService.listVideoFiles(at: volumeURL)
 self.videoFiles = files
 print("\(files.count) video files found")
 } catch {
 print("Failed to load files: \(error)")
 }
 }
 }

 private func handleSDCardDisconnected(_ volumeURL: URL) {
 self.videoFiles = []
 }
 }
 ```

 
 */
