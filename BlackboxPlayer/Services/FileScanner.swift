/// @file FileScanner.swift
/// @brief Service for scanning and discovering dashcam video files
/// @author BlackboxPlayer Development Team
/// @details Service that recursively scans directories on dashcam SD cards to discover video files
/// and organizes them into multi-channel groups.

/*
 
 File Scanner Service
 

 [Purpose of this File]
 Recursively scans directories on dashcam SD cards to discover video files
 and organizes them into multi-channel groups.

 [Dashcam File Structure]
 Typical directory structure on dashcam SD cards:

 ```
 /SD_CARD/
 Normal/ Normal recordings
 20240115_143025_F.mp4 (Front camera)
 20240115_143025_R.mp4 (Rear camera)
 20240115_143125_F.mp4
 20240115_143125_R.mp4
 Event/ Event recordings (impact detection)
 20240115_150230_F.mp4
 20240115_150230_R.mp4
 Parking/ Parking mode
...
 GPS/ Separate GPS logs (optional)
 20240115.nmea
 ```

 [Scan Process]
 1. with FileManager.enumerator for Recursive directory traversal
 2. Video extension filtering (.mp4,.mov,.avi,.mkv)
 3. Filename parsing with regex (date, time, camera position)
 4. VideoFileInfo structure creation
 5. Multi-channel grouping by baseFilename
 6. Return VideoFileGroup array (sorted newest first)

 [Multi-Channel Grouping]
 Combines front/rear videos recorded at the same time into one group:

 Input (individual files):
 - 20240115_143025_F.mp4 (Front)
 - 20240115_143025_R.mp4 (Rear)
 - 20240115_143125_F.mp4 (Front)

 Output (groups):
 - Group 1: [Front, Rear] (2024-01-15 14:30:25)
 - Group 2: [Front] (2024-01-15 14:31:25)

 [Integration Points]
 - FileManagerService: Uses this service to scan SD cards
 - ContentView: Displays scan results in UI

 
 */

import Foundation

/*
 
 FileScanner Class
 

 [Role]
 Central service for discovering and organizing dashcam video files.

 [Key Features]
 1. Recursive directory scanning
 2. Filename pattern matching (regex)
 3. Metadata extraction (date, time, camera position, event type)
 4. Multi-channel grouping
 5. Fast file counting

 [Usage Scenarios]

 Scenario 1: Basic Scanning
 ```swift
 let scanner = FileScanner()
 let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")

 do {
 let groups = try scanner.scanDirectory(sdCardURL)
 print("\(groups.count) recording groups found")

 for group in groups {
 print("[\(group.timestamp)] \(group.channelCount)channels, \(group.totalFileSize) bytes")
 if group.hasChannel(.front) {
 print(" - Front camera: \(group.file(for:.front)!.lastPathComponent)")
 }
 if group.hasChannel(.rear) {
 print(" - Rear camera: \(group.file(for:.rear)!.lastPathComponent)")
 }
 }
 } catch {
 print("Scan failed: \(error)")
 }
 ```

 Scenario 2: Quick Count
 ```swift
 let scanner = FileScanner()
 let count = scanner.countVideoFiles(in: sdCardURL)
 print("\(count) video files found")
 ```

 Scenario 3: Filtering
 ```swift
 let groups = try scanner.scanDirectory(sdCardURL)

 // Event recordings only Filtering
 let eventGroups = groups.filter { $0.eventType ==.event }

 // Filter by specific date
 let calendar = Calendar.current
 let todayGroups = groups.filter {
 calendar.isDateInToday($0.timestamp)
 }

 // 2channel recordings only Filtering
 let twoChannelGroups = groups.filter { $0.channelCount == 2 }
 ```

 [Performance Characteristics]
 - Recursive scan: O(N) - N is total file count
 - Filename parsing: O(M) - M is video file count
 - Grouping: O(M log M) - including sorting

 Typical SD card (1000 files):
 - Scan time: approximately 100-200ms
 - Memory usage: approximately 1-2 MB
 
 */

/// @class FileScanner
/// @brief Service for scanning directories to discover and organize dashcam video files
///
/// Accesses file system using FileSystemService,
/// and parses filenames by auto-detecting vendor with VendorDetector.
class FileScanner {
 // MARK: - Properties

 /// @var fileSystemService
 /// @brief Service responsible for file system access
 ///
 /// Performs low-level file operations such as listing files and reading file information.
 /// Enhances testability through dependency injection.
 private let fileSystemService: FileSystemService

 /// @var vendorDetector
 /// @brief Automatic dashcam vendor detection
 ///
 /// Analyzes filename patterns to select appropriate parser.
 private let vendorDetector: VendorDetector

 /// @var currentParser
 /// @brief Currently active parser
 ///
 /// Caches parser for detected vendor.
 private var currentParser: VendorParserProtocol?


 // MARK: - Initialization

 /*
 
 Initialization
 

 [VendorDetector Initialization]
 VendorDetector manages registered parsers (BlackVue, CR2000Omega, etc.),
 and automatically detects the vendor by analyzing filename patterns.

 Initialization all parsers are automatically registered:
 - BlackVueParser: YYYYMMDD_HHMMSS_X.mp4
 - CR2000OmegaParser: YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4
 
 */

 /// @brief FileScanner Initialization
 ///
 /// @param fileSystemService File system access service (default: new instance)
 ///
 /// VendorDetector to register vendor-specific parsers.
 ///
 /// Dependency injection pattern:
 /// - Production: FileScanner() - uses default FileSystemService
 /// - Testing: FileScanner(fileSystemService: mockService) - uses mocked service
 init(fileSystemService: FileSystemService = FileSystemService()) {
 self.fileSystemService = fileSystemService
 self.vendorDetector = VendorDetector()
 }

 // MARK: - Public Methods

 /*
 
 Method 1: scanDirectory
 

 [Purpose]
 Recursively scans directory to discover all video files and group them.

 [FileManager.enumerator]
 Apple's standard API for recursive directory traversal:

 ```swift
 let enumerator = fileManager.enumerator(
 at: directoryURL,
 includingPropertiesForKeys: [.isRegularFileKey,...],
 options: [.skipsHiddenFiles]
 )
 ```

 Operation:
 1. Iterates through all directory items (recursively)
 2. includingPropertiesForKeys: Specify properties to preload
 3. options: exclude hidden files

 [includingPropertiesForKeys]
 Preloads file attributes for improved performance:
 -.isRegularFileKey: normal file (excluding directories/symbolic links)
 -.fileSizeKey: file size
 -.contentModificationDateKey: modification date

 If not preloaded:
 - Requires separate system call for each file
 - Performance degradation (especially with many files)

 [options:.skipsHiddenFiles]
 Exclude hidden files/directories:
 -.DS_Store (macOS metadata)
 -.Trash (trash)
 -._ starting files (macOS resource forks)

 [Return Type: [VideoFileGroup]]
 Returns groups instead of individual files:
 - Combines front/rear videos from the same time into one group
 - Sorted newest first (most recent recordings first)

 [throws]
 Throws error when directory access fails:
 - directoryNotFound: Directory not found
 - cannotEnumerateDirectory: Insufficient permissions etc.
 
 */

 /// @brief Scan directory to discover dashcam video files
 ///
 /// Uses FileManager.enumerator to recursively explore all subdirectories
 /// Parses video files and organizes them into multi-channel groups.
 ///
 /// @param directoryURL URL of directory to scan
 /// @return Array of VideoFileGroup (sorted newest first)
 /// @throws FileScannerError
 /// -.directoryNotFound: Directory does not exist
 /// -.cannotEnumerateDirectory: Failed to open directory
 ///
 /// Scan process:
 /// 1. Check if directory exists
 /// 2. Recursive traversal with FileManager.enumerator
 /// 3. Check file extensions (.mp4,.mov etc.)
 /// 4. Filename parsing with regex (date, time, camera position)
 /// 5. VideoFileInfo structure creation
 /// 6. Group by baseFilename
 /// 7. Sort newest first and return
 ///
 /// Usage example:
 /// ```swift
 /// let scanner = FileScanner()
 /// let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")
 ///
 /// do {
 /// let groups = try scanner.scanDirectory(sdCardURL)
 /// print("\(groups.count) recording groups found")
 ///
 /// for group in groups {
 /// print("[\(group.timestamp)]")
 /// print(" channels: \(group.channelCount)")
 /// print(" type: \(group.eventType)")
 /// print(" size: \(group.totalFileSize) bytes")
 /// }
 /// } catch FileScannerError.directoryNotFound(let path) {
 /// print("Directory not found: \(path)")
 /// } catch {
 /// print("Scan failed: \(error)")
 /// }
 /// ```
 ///
 /// Performance:
 /// - Time: O(N) - N is total file count
 /// - Memory: O(M) - M is video file count
 /// - Typical SD card (1000 files): approximately 100-200ms
 func scanDirectory(_ directoryURL: URL) throws -> [VideoFileGroup] {
 // Step 1: Automatic vendor detection
 guard let parser = vendorDetector.detectVendor(in: directoryURL) else {
 throw FileScannerError.unsupportedVendor("Could not identify blackbox vendor from file patterns")
 }
 currentParser = parser

 // Step 2: Get video file list using FileSystemService
 let videoFileURLs: [URL]
 do {
 videoFileURLs = try fileSystemService.listVideoFiles(at: directoryURL)
 } catch FileSystemError.fileNotFound {
 throw FileScannerError.directoryNotFound(directoryURL.path)
 } catch FileSystemError.accessDenied {
 throw FileScannerError.cannotEnumerateDirectory(directoryURL.path)
 }

 // Step 3: Parse each file with detected parser to create VideoFileInfo
 var videoFiles: [VideoFileInfo] = []
 for fileURL in videoFileURLs {
 if let fileInfo = parser.parseVideoFile(fileURL) {
 videoFiles.append(fileInfo)
 }
 }

 // 4step: Multi-channel grouping
 let groups = groupVideoFiles(videoFiles)

 return groups
 }

 /*
 
 Method 2: countVideoFiles
 

 [Purpose]
 Quick count of video files without filename parsing

 [Usage Scenarios]
 1. Progress display:
 "Total file count: 1000 "
 "Scanning... (500/1000)"

 2. Quick check:
 "Are there video files on the SD card?"

 3. Memory approximately:
 When only count is needed without detailed information

 [Difference from scanDirectory()]
 scanDirectory():
 - Filename regex matching
 - VideoFileInfo creation
 - Grouping
 - Memory: O(M) - M is video file count
 - Time: approximately 100-200ms

 countVideoFiles():
 - Check extensions only
 - Memory: O(1) - count variable only
 - Time: approximately 50-100ms (2x faster)

 [Return Type: Int]
 Returns 0 on error (not throws):
 - Directory not found 0
 - Insufficient permissions 0
 - No files 0

 User-friendly handling:
 ```swift
 let count = scanner.countVideoFiles(in: url)
 if count == 0 {
 print("No video files found")
 } else {
 print("\(count) files found")
 }
 ```
 
 */

 /// @brief Quickly count video files in directory
 ///
 /// Performs quick count by checking extensions only without filename parsing.
 /// Approximately 2x faster than scanDirectory() and uses minimal memory.
 ///
 /// @param directoryURL URL of directory to scan
 /// @return Number of video files, or 0 on error
 ///
 /// Usage example:
 /// ```swift
 /// let scanner = FileScanner()
 /// let count = scanner.countVideoFiles(in: sdCardURL)
 ///
 /// if count == 0 {
 /// print("No video files found")
 /// } else {
 /// print("\(count) files found")
 /// // Now start full scan
 /// let groups = try scanner.scanDirectory(sdCardURL)
 /// }
 /// ```
 ///
 /// Progress display example:
 /// ```swift
 /// let totalCount = scanner.countVideoFiles(in: sdCardURL)
 /// var scannedCount = 0
 ///
 /// // Update progress while scanning
 /// for group in groups {
 /// scannedCount += group.channelCount
 /// let progress = Double(scannedCount) / Double(totalCount)
 /// updateProgressBar(progress)
 /// }
 /// ```
 ///
 /// Note:
 /// - Returns 0 on error (not throws)
 /// - Faster than scanDirectory() by omitting filename parsing
 /// - Memory usage: O(1) - count variable only
 func countVideoFiles(in directoryURL: URL) -> Int {
 // Get video file list using FileSystemService
 // Returns 0 on error (no files or access denied)
 guard let videoFileURLs = try? fileSystemService.listVideoFiles(at: directoryURL) else {
 return 0
 }

 return videoFileURLs.count
 }

 // MARK: - Private Methods


 /*
 
 Method 4: groupVideoFiles (Private)
 

 [Purpose]
 Combines individual video files into multi-channel groups

 [Grouping Criteria]
 - baseFilename: "20240115_143025" (time)
 - eventType:.normal,.event,.parking

 Same time + same event type = one group

 [Grouping Example]
 Input (individual files):
 ```
 [
 VideoFileInfo(baseFilename: "20240115_143025", position:.front, eventType:.normal),
 VideoFileInfo(baseFilename: "20240115_143025", position:.rear, eventType:.normal),
 VideoFileInfo(baseFilename: "20240115_143125", position:.front, eventType:.event),
 ]
 ```

 Dictionary Grouping:
 ```
 {
 "20240115_143025_normal": [Front, Rear],
 "20240115_143125_event": [Front]
 }
 ```

 Output (groups):
 ```
 [
 VideoFileGroup(files: [Front, Rear], timestamp: 2024-01-15 14:30:25),
 VideoFileGroup(files: [Front], timestamp: 2024-01-15 14:31:25)
 ]
 ```

 [Sorting]
 1. Sorting files within group:
 Sort by displayPriority (Front Rear Left Interior)

 2. Group sorting:
 Descending by timestamp (newest first)

 [Using Dictionary]
 ```swift
 var groups: [String: [VideoFileInfo]] = [:]
 let key = "\(file.baseFilename)_\(file.eventType.rawValue)"
 groups[key, default: []].append(file)
 ```

 Or:
 ```swift
 if groups[key] == nil {
 groups[key] = []
 }
 groups[key]?.append(file)
 ```

 [Performance]
 - Dictionary Grouping: O(N) - N is file count
 - Sorting: O(M log M) - M is group count
 - Total: O(N + M log M)
 
 */

 /// @brief Combines individual video files into multi-channel groups
 ///
 /// Groups files with the same time (baseFilename) and event type.
 ///
 /// @param files Array of VideoFileInfo
 /// @return Array of VideoFileGroup (sorted newest first)
 ///
 /// Grouping process:
 /// 1. Create Dictionary with baseFilename + eventType as key
 /// 2. Accumulate files with same key into array
 /// 3. Sort by camera position within each group (Front Rear...)
 /// 4. Sort groups by timestamp descending (newest first)
 ///
 /// Example:
 /// ```swift
 /// // Input
 /// let files = [
 /// VideoFileInfo(baseFilename: "20240115_143025", position:.front,...),
 /// VideoFileInfo(baseFilename: "20240115_143025", position:.rear,...)
 /// ]
 ///
 /// // Grouping
 /// let groups = groupVideoFiles(files)
 /// // groups[0].files = [Front, Rear]
 /// // groups[0].channelCount = 2
 /// ```
 ///
 /// Note:
 /// - group within file Sort by displayPriority
 /// - group Descending by timestamp sorting (newest first)
 private func groupVideoFiles(_ files: [VideoFileInfo]) -> [VideoFileGroup] {
 // 1step: Dictionary Grouping
 // Key: "baseFilename_eventType" (e.g. "20240115_143025_normal")
 var groups: [String: [VideoFileInfo]] = [:]

 for file in files {
 let key = "\(file.baseFilename)_\(file.eventType.rawValue)"
 if groups[key] == nil {
 groups[key] = []
 }
 groups[key]?.append(file)
 }

 // Step 2: Convert to VideoFileGroup
 return groups.values.map { groupFiles in
 // 2-1: Sort files within group
 // displayPriority: Front(0) Rear(1) Left(2) Interior(3)
 let sortedFiles = groupFiles.sorted { $0.position.displayPriority < $1.position.displayPriority }
 return VideoFileGroup(files: sortedFiles)
 }.sorted { $0.timestamp > $1.timestamp } // 2-2: group sorted newest first
 }
}

// MARK: - Supporting Types

/*
 
 VideoFileInfo Structure
 

 [Purpose]
 Lightweight structure containing metadata for individual video files

 [Field Descriptions]
 - url: file URL (file Open)
 - timestamp: recording start time (sorting, Filtering)
 - position: camera position (Front/Rear distinction)
 - eventType: event type (normal//)
 - fileSize: file size (Storage space calculation)
 - baseFilename: Base filename (Grouping key)

 [Reasons for Using struct]
 - value type: 
 - Lightweight: reference none
 -: let before 

 [Usage Scenarios]
 ```swift
 let fileInfo = VideoFileInfo(
 url: URL(fileURLWithPath: "/Videos/20240115_143025_F.mp4"),
 timestamp: Date(),
 position:.front,
 eventType:.normal,
 fileSize: 104857600, // 100 MB
 baseFilename: "20240115_143025"
 )

 print(fileInfo.url.lastPathComponent) // "20240115_143025_F.mp4"
 print(fileInfo.position) // CameraPosition.front
 ```
 
 */

/// @struct VideoFileInfo
/// @brief Information about individual video file
///
/// Lightweight structure containing metadata extracted from filename parsing.
/// Represents individual file-level information before grouping.
struct VideoFileInfo {
 /// @var url
 /// @brief File URL
 ///
 /// Used to open file or read metadata:
 /// ```swift
 /// let data = try Data(contentsOf: fileInfo.url)
 /// ```
 let url: URL

 /// @var timestamp
 /// @brief Recording start time
 ///
 /// file extractionone date/Time:
 /// "20240115_143025_F.mp4" Date(2024-01-15 14:30:25 +0900)
 ///
 /// Purpose:
 /// - File sorting (newest first/oldest)
 /// - Date filtering (, etc.)
 /// - UI display ("2024-01-15 14:30")
 let timestamp: Date

 /// @var position
 /// @brief camera position
 ///
 /// Extracted from position code in filename:
 /// - "F".front (Front)
 /// - "R".rear (Rear)
 /// - "L".left (Left)
 /// - "I".interior (Interior)
 ///
 /// Purpose:
 /// - Multi-channel grouping
 /// - UI channels select
 let position: CameraPosition

 /// @var eventType
 /// @brief event type
 ///
 /// Detected from file path:
 /// - "/Normal/" include.normal (Normal recordings)
 /// - "/Event/" include.event (impact detection)
 /// - "/Parking/" include.parking (Parking mode)
 ///
 /// Purpose:
 /// - Event filtering
 /// - UI icon display (ï )
 let eventType: EventType

 /// @var fileSize
 /// @brief File size (bytes)
 ///
 /// Retrieved from FileManager.attributesOfItem:
 /// ```swift
 /// let mb = Double(fileSize) / 1_000_000
 /// print(String(format: "%.1f MB", mb))
 /// ```
 ///
 /// Purpose:
 /// - Storage space calculation
 /// - Transfer time estimation
 /// - Large file warning
 let fileSize: UInt64

 /// @var baseFilename
 /// @brief Base filename (camera position exclude)
 ///
 /// "20240115_143025_F.mp4" "20240115_143025"
 ///
 /// Purpose:
 /// - Multi-channel grouping key
 /// - same baseFilename = same time other channels
 ///
 /// Example:
 /// - "20240115_143025_F.mp4" baseFilename: "20240115_143025"
 /// - "20240115_143025_R.mp4" baseFilename: "20240115_143025"
 /// Grouped together
 let baseFilename: String
}

/*
 
 VideoFileGroup Structure
 

 [Purpose]
 Group of multi-channel video files recorded at the same time

 [Structure]
 ```
 VideoFileGroup
 files: [VideoFileInfo]
 Front camera
 Rear camera
 timestamp: Date (first file time)
 eventType: EventType (group event type)
 channelCount: Int (channels: 1 or 2)
 ```

 [Computed Properties]
 storageha neededto Calculation:
 - timestamp: files[0].timestamp
 - eventType: files[0].eventType
 - baseFilename: files[0].baseFilename
 - basePath: files[0] path
 - channelCount: files.count
 - totalFileSize: all file size 

 point:
 - memory approximately
 - automatic (files )
 - 

 [Methods]
 - file(for:): specific position file URL query
 - hasChannel(_:): specific position channels whether

 use 
 ```swift
 let group = VideoFileGroup(files: [frontFile, rearFile])

 print(group.timestamp) // 2024-01-15 14:30:25
 print(group.channelCount) // 2
 print(group.totalFileSize) // 200000000 (200 MB)

 if let frontURL = group.file(for:.front) {
 print(frontURL.lastPathComponent) // "20240115_143025_F.mp4"
 }

 if group.hasChannel(.rear) {
 print("Rear camera recording exists")
 }
 ```
 
 */

/// @struct VideoFileGroup
/// @brief Group of multi-channel video files recorded at the same time
///
/// Represents files recorded simultaneously by front/rear cameras as one group.
struct VideoFileGroup {
 /// @var files
 /// @brief Video files belonging to the group
 ///
 /// Sort order: displayPriority (Front Rear Left Interior)
 ///
 /// Typical configuration:
 /// - 1channels: [Front]
 /// - 2channels: [Front, Rear]
 /// - 3channels: [Front, Rear, Interior] (advanced models)
 let files: [VideoFileInfo]

 /*
 
 Computed Properties
 

 Properties computed when needed without storage.

 Advantages:
 1. Memory approximately: value storageha none
 2. Automatic update: Automatically reflects when files change
 3. Consistency: Always synchronized with files

 Disadvantages:
 1. Computation cost: Calculated on each call

 However, cost is minimal here as these are simple lookup operations.
 
 */

 /// @var timestamp
 /// @brief Recording start time
 ///
 /// Returns the time of the first file in the group.
 /// All files have the same time, so only check the first file.
 ///
 /// Returns current time if files is empty (defensive code).
 var timestamp: Date {
 return files.first?.timestamp ?? Date()
 }

 /// @var eventType
 /// @brief event type
 ///
 /// Returns the event type of the first file in the group.
 /// All files have the same event type, so only check the first file.
 ///
 /// Returns.unknown if files is empty.
 var eventType: EventType {
 return files.first?.eventType ??.unknown
 }

 /// @var baseFilename
 /// @brief Base filename
 ///
 /// Returns the baseFilename of the first file in the group.
 /// e.g. "20240115_143025"
 var baseFilename: String {
 return files.first?.baseFilename ?? ""
 }

 /// @var basePath
 /// @brief base path ( path)
 ///
 /// Returns the directory path where the first file in the group is located.
 ///
 /// Example:
 /// - File: "/Volumes/SD/Normal/20240115_143025_F.mp4"
 /// - basePath: "/Volumes/SD/Normal"
 ///
 /// Purpose:
 /// - Access other files in same directory
 /// - Path display
 var basePath: String {
 guard let firstFile = files.first else { return "" }
 return firstFile.url.deletingLastPathComponent().path
 }

 /// @var channelCount
 /// @brief channels 
 ///
 /// Returns the number of video files in the group.
 ///
 /// Typical values:
 /// - 1: Single channels (Frontonly)
 /// - 2: Dual channels (Front + Rear)
 /// - 3: Triple channels (Front + Rear + Interior)
 ///
 /// Purpose:
 /// - UI layout decision (1channels: Total, 2channels: to )
 /// - Filtering (2channel recordings only )
 var channelCount: Int {
 return files.count
 }

 /// @var totalFileSize
 /// @brief Total file size (bytes)
 ///
 /// Sums the sizes of all files in the group.
 ///
 /// Calculation:
 /// totalFileSize = file1.size + file2.size +...
 ///
 /// Example:
 /// - Front: 100 MB
 /// - Rear: 80 MB
 /// - Total: 180 MB
 ///
 /// Purpose:
 /// - Storage space calculation
 /// - Transfer time estimation
 /// - large group warning
 ///
 /// Using reduce:
 /// ```swift
 /// [100, 80, 50].reduce(0, +) // 230
 /// [100, 80, 50].reduce(0) { $0 + $1 } // 230
 /// ```
 var totalFileSize: UInt64 {
 return files.reduce(0) { $0 + $1.fileSize }
 }

 /*
 
 method
 

 Helper methods to retrieve files for specific camera positions.
 
 */

 /// @brief specific camera position file URL query
 ///
 /// @param position queryto camera position
 /// @return File URL for that position, or nil if not found
 ///
 /// Usage example:
 /// ```swift
 /// let group = VideoFileGroup(files: [frontFile, rearFile])
 ///
 /// if let frontURL = group.file(for:.front) {
 /// print("Front camera: \(frontURL.lastPathComponent)")
 /// // Front 
 /// }
 ///
 /// if let rearURL = group.file(for:.rear) {
 /// print("Rear camera: \(rearURL.lastPathComponent)")
 /// // Rear 
 /// } else {
 /// print("Rear camera none")
 /// }
 /// ```
 ///
 /// Internal operation:
 /// Returns URL of first file in files array matching position:
 /// ```swift
 /// files.first { $0.position == position }?.url
 /// ```
 func file(for position: CameraPosition) -> URL? {
 return files.first { $0.position == position }?.url
 }

 /// @brief specific camera position channels whether check
 ///
 /// @param position checkto camera position
 /// @return true if file exists for that position
 ///
 /// Usage example:
 /// ```swift
 /// let group = VideoFileGroup(files: [frontFile])
 ///
 /// if group.hasChannel(.front) {
 /// print(" Front camera")
 /// }
 ///
 /// if group.hasChannel(.rear) {
 /// print(" Rear camera")
 /// } else {
 /// print(" Rear camera none")
 /// }
 ///
 /// // Enable/disable UI button
 /// rearButton.isEnabled = group.hasChannel(.rear)
 /// ```
 ///
 /// Internal operation:
 /// Check if file matching position exists in files array:
 /// ```swift
 /// files.contains { $0.position == position }
 /// ```
 func hasChannel(_ position: CameraPosition) -> Bool {
 return files.contains { $0.position == position }
 }
}

/*
 
 FileScannerError Enumeration
 

 [Error Types]
 1. directoryNotFound: Directory does not exist
 2. cannotEnumerateDirectory: Failed to open directory (Insufficient permissions etc.)
 3. invalidPath: ( )

 [LocalizedError Protocol]
 useza remove:
 ```swift
 do {
 let groups = try scanner.scanDirectory(url)
 } catch {
 print(error.localizedDescription) // "Directory not found: /path"
 }
 ```

 [Usage Pattern]
 ```swift
 do {
 let groups = try scanner.scanDirectory(sdCardURL)
 // Handle success
 } catch FileScannerError.directoryNotFound(let path) {
 showAlert("Directory not found: \(path)")
 } catch FileScannerError.cannotEnumerateDirectory(let path) {
 showAlert("Cannot read directory: \(path)")
 } catch {
 showAlert("Unknown error: \(error)")
 }
 ```
 
 */

/// @enum FileScannerError
/// @brief Errors that can occur during file scanning
enum FileScannerError: Error {
 /// @brief Directory does not exist
 ///
 /// Occurrence scenarios:
 /// - SD card not mounted
 /// - Path typo
 /// - SD card removed
 ///
 /// Recovery methods:
 /// 1. Reinsert SD card
 /// 2. Verify path
 /// 3. Try different path
 case directoryNotFound(String)

 /// @brief Failed to open directory
 ///
 /// Occurrence scenarios:
 /// - Insufficient permissions
 /// - Disk I/O error
 /// - Filesystem corruption
 ///
 /// Recovery methods:
 /// 1. Check permissions (chmod)
 /// 2. Check disk
 /// 3. Replace SD card
 case cannotEnumerateDirectory(String)

 /// @brief Unsupported dashcam vendor
 ///
 /// Occurrence scenarios:
 /// - file registervendor and ha none
 /// - SD card from new dashcam vendor
 ///
 /// Recovery methods:
 /// 1. remove parser implement and register
 /// 2. Try different SD card
 case unsupportedVendor(String)

 /// @brief Invalid path
 ///
 /// one approximately.
 /// Not currently used.
 case invalidPath(String)
}

extension FileScannerError: LocalizedError {
 /// @brief Error message to display to user
 var errorDescription: String? {
 switch self {
 case.directoryNotFound(let path):
 return "Directory not found: \(path)"
 case.cannotEnumerateDirectory(let path):
 return "Cannot enumerate directory: \(path)"
 case.unsupportedVendor(let message):
 return "Unsupported vendor: \(message)"
 case.invalidPath(let path):
 return "Invalid path: \(path)"
 }
 }
}

/*
 
 
 

 [1. Basic Usage]

 ```swift
 let scanner = FileScanner()
 let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")

 do {
 let groups = try scanner.scanDirectory(sdCardURL)
 print("\(groups.count) recording groups found")

 for group in groups {
 let dateFormatter = DateFormatter()
 dateFormatter.dateStyle =.short
 dateFormatter.timeStyle =.short

 print("[\(dateFormatter.string(from: group.timestamp))]")
 print(" channels: \(group.channelCount)")
 print(" type: \(group.eventType)")
 print(" size: \(group.totalFileSize / 1_000_000) MB")

 if let frontURL = group.file(for:.front) {
 print(" Front: \(frontURL.lastPathComponent)")
 }
 if let rearURL = group.file(for:.rear) {
 print(" Rear: \(rearURL.lastPathComponent)")
 }
 print()
 }
 } catch {
 print("Scan failed: \(error.localizedDescription)")
 }
 ```

 [2. Filtering Examples]

 ```swift
 let groups = try scanner.scanDirectory(sdCardURL)

 // Event recordings only Filtering
 let eventGroups = groups.filter { $0.eventType ==.event }
 print("Event recordings: \(eventGroups.count) ")

 // recording only Filtering
 let calendar = Calendar.current
 let todayGroups = groups.filter {
 calendar.isDateInToday($0.timestamp)
 }
 print("Today's recordings: \(todayGroups.count) ")

 // specific date Filtering
 let startDate = Date(timeIntervalSinceNow: -7 * 24 * 3600) // 7 before
 let recentGroups = groups.filter {
 $0.timestamp > startDate
 }
 print("Last 7 days: \(recentGroups.count) ")

 // 2channel recordings only Filtering
 let dualChannelGroups = groups.filter { $0.channelCount == 2 }
 print("2channels recording: \(dualChannelGroups.count) ")

 // large files Filtering (100 MB )
 let largeGroups = groups.filter { $0.totalFileSize > 100_000_000 }
 print("Large recordings: \(largeGroups.count) ")
 ```

 [3. Progress Display]

 ```swift
 @MainActor
 class ScanViewModel: ObservableObject {
 @Published var progress: Double = 0.0
 @Published var statusMessage: String = ""
 @Published var groups: [VideoFileGroup] = []

 func scanDirectory(_ url: URL) async {
 let scanner = FileScanner()

 // 1step: 
 statusMessage = "Checking file count..."
 let totalCount = await Task.detached {
 scanner.countVideoFiles(in: url)
 }.value

 if totalCount == 0 {
 statusMessage = "No video files found"
 return
 }

 statusMessage = "\(totalCount) files Scanning..."
 progress = 0.0

 // 2step: Total 
 do {
 groups = try await Task.detached {
 try scanner.scanDirectory(url)
 }.value

 statusMessage = "Scan complete: \(groups.count) recordings"
 progress = 1.0
 } catch {
 statusMessage = "Scan failed: \(error.localizedDescription)"
 }
 }
 }

 // SwiftUI use
 struct ScanView: View {
 @StateObject private var viewModel = ScanViewModel()

 var body: some View {
 VStack {
 Text(viewModel.statusMessage)
 ProgressView(value: viewModel.progress)
 Button(" start") {
 Task {
 await viewModel.scanDirectory(sdCardURL)
 }
 }
 }
 }
 }
 ```

 [4. SwiftUI List Integration]

 ```swift
 struct VideoListView: View {
 let groups: [VideoFileGroup]

 var body: some View {
 List(groups, id: \.baseFilename) { group in
 VideoGroupRow(group: group)
 }
 }
 }

 struct VideoGroupRow: View {
 let group: VideoFileGroup

 var body: some View {
 HStack {
 // Event icon
 if group.eventType ==.event {
 Image(systemName: "exclamationmark.triangle.fill")
.foregroundColor(.red)
 }

 VStack(alignment:.leading) {
 // Date/time
 Text(group.timestamp, style:.date)
 Text(group.timestamp, style:.time)
.font(.caption)
.foregroundColor(.secondary)
 }

 Spacer()

 // channels display
 HStack(spacing: 4) {
 if group.hasChannel(.front) {
 Image(systemName: "camera.fill")
 }
 if group.hasChannel(.rear) {
 Image(systemName: "camera.fill")
.rotationEffect(.degrees(180))
 }
 }

 // File size
 Text(formatFileSize(group.totalFileSize))
.font(.caption)
.foregroundColor(.secondary)
 }
 }

 func formatFileSize(_ bytes: UInt64) -> String {
 let mb = Double(bytes) / 1_000_000
 return String(format: "%.1f MB", mb)
 }
 }
 ```

 [5. Error Handling Patterns]

 ```swift
 func handleScan(_ url: URL) {
 let scanner = FileScanner()

 do {
 let groups = try scanner.scanDirectory(url)

 if groups.isEmpty {
 showWarning("No video files found")
 } else {
 showSuccess("\(groups.count) recordings ")
 displayGroups(groups)
 }

 } catch FileScannerError.directoryNotFound(let path) {
 showAlert(
 title: "Directory not found",
 message: "path: \(path)\n\nPlease check if SD card is mounted."
 )

 } catch FileScannerError.cannotEnumerateDirectory(let path) {
 showAlert(
 title: "to no",
 message: "path: \(path)\n\nPlease check read permissions."
 )

 } catch {
 showAlert(
 title: " ",
 message: error.localizedDescription
 )
 }
 }
 ```

 [6. Test Code]

 ```swift
 class FileScannerTests: XCTestCase {
 var scanner: FileScanner!
 var testURL: URL!

 override func setUp() {
 scanner = FileScanner()
 testURL = createTestDirectory()
 }

 func testScanDirectory() throws {
 // Create test files
 createTestFile("20240115_143025_F.mp4")
 createTestFile("20240115_143025_R.mp4")
 createTestFile("20240115_143125_F.mp4")

 // Scan
 let groups = try scanner.scanDirectory(testURL)

 // Verify
 XCTAssertEqual(groups.count, 2)
 XCTAssertEqual(groups[0].channelCount, 2) // Front + Rear
 XCTAssertEqual(groups[1].channelCount, 1) // Frontonly
 }

 func testCountVideoFiles() {
 createTestFile("20240115_143025_F.mp4")
 createTestFile("20240115_143025_R.mp4")
 createTestFile("README.txt") // Non-video file

 let count = scanner.countVideoFiles(in: testURL)
 XCTAssertEqual(count, 2) // Count video files only
 }

 func testDirectoryNotFound() {
 let invalidURL = URL(fileURLWithPath: "/nonexistent")
 XCTAssertThrowsError(try scanner.scanDirectory(invalidURL)) { error in
 XCTAssertTrue(error is FileScannerError)
 }
 }
 }
 ```

 
 */
