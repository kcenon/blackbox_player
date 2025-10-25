/// @file MetadataExtractor.swift
/// @brief Service for extracting GPS and acceleration metadata from video files
/// @author BlackboxPlayer Development Team
/// @details
/// This file extracts GPS location information and G-sensor acceleration data from dashcam video files (MP4).
/// It uses FFmpeg to parse data streams and metadata dictionaries within MP4 containers.

/*
 ═══════════════════════════════════════════════════════════════════════════
 Metadata Extraction Service
 ═══════════════════════════════════════════════════════════════════════════

 【Purpose of this File】
 Extract GPS location information and G-sensor acceleration data from dashcam video files (MP4).
 This metadata is played back with the video to visualize driving routes, speed, and impact situations.

 【What is Dashcam Metadata?】
 Dashcams include the following information in MP4 files along with video:

 1. GPS Information
 - Latitude/Longitude
 - Speed (km/h)
 - Bearing
 - Satellite count
 - Accuracy (HDOP)

 2. G-sensor Information (Accelerometer)
 - X/Y/Z axis acceleration (in G units)
 - Impact detection
 - Parking mode events

 3. Device Information
 - Manufacturer/Model name
 - Firmware version
 - Serial number
 - Recording mode

 【Metadata Storage Locations】
 Metadata can be stored in multiple locations within the MP4 container:

 ┌─────────────────────────────────────────────────────────┐
 │ MP4 File Structure                                      │
 ├─────────────────────────────────────────────────────────┤
 │ ftyp: File type                                         │
 │ moov: Metadata container                                │
 │   ├── mvhd: Movie header                                │
 │   ├── trak: Tracks (video/audio/data)                   │
 │   │    ├── Video Track (H.264)                          │
 │   │    ├── Audio Track (AAC)                            │
 │   │    ├── Data Track: GPS data ←──┐                    │
 │   │    └── Subtitle Track: G-sensor ←┤ Extract from here│
 │   └── udta: User Data                │                  │
 │        └── meta: Metadata dictionary ←┘                 │
 │ mdat: Actual media data (encoded video/audio)           │
 └─────────────────────────────────────────────────────────┘

 【Extraction Process】
 1. Open MP4 file with FFmpeg (avformat_open_input)
 2. Read stream information (avformat_find_stream_info)
 3. Iterate through each stream:
 - Find streams with type AVMEDIA_TYPE_DATA or AVMEDIA_TYPE_SUBTITLE
 - Read packets and convert to Data
 4. Check format-level metadata dictionary:
 - Query "gps", "accelerometer" keys using av_dict_get()
 5. Parse with GPSParser and AccelerationParser
 6. Return as VideoMetadata struct

 【Data Flow】
 Video File → FFmpeg → Data Streams → GPSParser → GPSPoint[]
 ↓                 ↓
 → Metadata Dict  → AccelerationParser → AccelerationData[]
 ↓
 → Device Info

 【Current Status】
 Most methods in this file are commented out (/* ... */).
 Reason: FFmpeg integration is not yet complete, disabled to prevent compilation errors.
 Will uncomment and use when FFmpeg integration is complete.

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

/*
 ───────────────────────────────────────────────────────────────────────────
 MetadataExtractor Class
 ───────────────────────────────────────────────────────────────────────────

 [Role]
 Central service for extracting GPS and acceleration metadata from video files.

 [Collaborating Classes]
 - GPSParser: Parses GPS data in NMEA format
 - AccelerationParser: Parses acceleration data in Binary/CSV format
 - VideoMetadata: Structure that holds extracted metadata

 [Usage Scenarios]

 Scenario 1: Extract metadata from a single file
 ```swift
 let extractor = MetadataExtractor()
 if let metadata = extractor.extractMetadata(from: "/path/to/video.mp4") {
 print("GPS points: \(metadata.gpsPoints.count)")
 print("Acceleration data: \(metadata.accelerationData.count)")
 if let device = metadata.deviceInfo {
 print("Device: \(device.manufacturer ?? "") \(device.model ?? "")")
 }
 }
 ```

 Scenario 2: Integrate metadata from multi-channel video
 ```swift
 let extractor = MetadataExtractor()
 let frontMetadata = extractor.extractMetadata(from: "front.mp4")
 let rearMetadata = extractor.extractMetadata(from: "rear.mp4")

 // GPS is usually only available in the front camera
 let gpsPoints = frontMetadata?.gpsPoints ?? []

 // Acceleration data is available from both cameras
 let frontAccel = frontMetadata?.accelerationData ?? []
 let rearAccel = rearMetadata?.accelerationData ?? []
 ```

 Scenario 3: Query metadata at playback time
 ```swift
 let metadata = extractor.extractMetadata(from: videoPath)!
 let currentTime: TimeInterval = 15.5  // Current playback time (15.5 seconds)

 // GPS location at current time
 let currentGPS = metadata.gpsPoints.first { abs($0.timestamp - currentTime) < 0.1 }
 if let gps = currentGPS {
 print("Current location: \(gps.coordinate.latitude), \(gps.coordinate.longitude)")
 print("Current speed: \(gps.speed ?? 0) km/h")
 }

 // G-sensor value at current time
 let currentAccel = metadata.accelerationData.first { abs($0.timestamp - currentTime) < 0.05 }
 if let accel = currentAccel {
 let magnitude = sqrt(accel.x*accel.x + accel.y*accel.y + accel.z*accel.z)
 if magnitude > 2.0 {
 print("Warning: Impact detected: \(magnitude)G")
 }
 }
 ```

 [Memory Management]
 Be mindful of memory usage as metadata extraction scans the entire file:
 - 1-hour video × 10Hz GPS = approx. 36,000 points × 48 bytes ≈ 1.7 MB
 - 1-hour video × 10Hz G-sensor = approx. 36,000 × 32 bytes ≈ 1.15 MB
 - Total memory: approx. 3 MB (for 1-hour video)

 Therefore, typical dashcam videos (1-3 minutes) have minimal memory overhead.
 ───────────────────────────────────────────────────────────────────────────
 */

/// @class MetadataExtractor
/// @brief Service for extracting metadata (GPS, G-sensor) from dashcam video files
///
/// @details
/// Uses FFmpeg to parse data streams and metadata dictionaries within MP4 containers,
/// converting them to structured data through GPSParser and AccelerationParser.
///
/// ## Current Status:
/// Most methods are commented out as FFmpeg integration is not yet complete.
/// The extractMetadata method currently returns empty VideoMetadata.
///
/// ## Future Plans:
/// - Complete FFmpeg C API integration
/// - Extract GPS data streams
/// - Extract G-sensor data streams
/// - Extract device information
class MetadataExtractor {
    // MARK: - Properties

    /*
     ───────────────────────────────────────────────────────────────────────
     Dependencies
     ───────────────────────────────────────────────────────────────────────

     [Dependency Injection]
     Currently created directly in init(), but can be changed to injection pattern for testing:

     ```swift
     class MetadataExtractor {
     private let gpsParser: GPSParserProtocol
     private let accelerationParser: AccelerationParserProtocol

     init(gpsParser: GPSParserProtocol = GPSParser(),
     accelerationParser: AccelerationParserProtocol = AccelerationParser()) {
     self.gpsParser = gpsParser
     self.accelerationParser = accelerationParser
     }
     }
     ```

     This allows injecting mock parsers during testing.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @var gpsParser
    /// @brief GPS NMEA data parser
    /// @details
    /// Converts NMEA 0183 format GPS strings to GPSPoint arrays.
    /// Example: "$GPGGA,123456.00,3723.1234,N,12658.5678,E,..."
    private let gpsParser: GPSParser

    /// @var accelerationParser
    /// @brief Acceleration data parser
    /// @details
    /// Converts G-sensor data in Binary or CSV format to AccelerationData arrays.
    /// Supported formats:
    /// - Binary: Float32 or Int16 (3 axes × N samples)
    /// - CSV: "timestamp,x,y,z" format
    private let accelerationParser: AccelerationParser

    // MARK: - Initialization

    /*
     ───────────────────────────────────────────────────────────────────────
     Initialization
     ───────────────────────────────────────────────────────────────────────

     [Singleton vs Instance]
     Currently uses instance creation approach.

     Singleton pattern example:
     ```swift
     class MetadataExtractor {
     static let shared = MetadataExtractor()
     private init() { ... }
     }

     // Usage
     let metadata = MetadataExtractor.shared.extractMetadata(from: path)
     ```

     Pros: Global access, memory savings
     Cons: Difficult to test, parallel processing limitations

     Benefits of current approach:
     - Can create independent instances for each task
     - Safe for parallel processing (no state sharing)
     - Easy to test
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief Initialize MetadataExtractor
    ///
    /// @details
    /// Creates GPSParser and AccelerationParser to prepare for metadata extraction.
    init() {
        self.gpsParser = GPSParser()
        self.accelerationParser = AccelerationParser()
    }

    // MARK: - Public Methods

    /*
     ───────────────────────────────────────────────────────────────────────
     Public Method: extractMetadata
     ───────────────────────────────────────────────────────────────────────

     [Current Status: Not Implemented]
     Currently returns empty VideoMetadata. Actual extraction logic will be
     implemented after FFmpeg integration.

     [Future Implementation Plan]
     1. Open file with FFmpeg:
     ```c
     AVFormatContext *formatContext = avformat_alloc_context();
     avformat_open_input(&formatContext, filePath, NULL, NULL);
     avformat_find_stream_info(formatContext, NULL);
     ```

     2. Extract base date:
     Parse recording start time from filename (e.g., "20240115_143025_F.mp4")

     3. Extract GPS data:
     extractGPSData(from: formatContext, baseDate: baseDate)

     4. Extract acceleration data:
     extractAccelerationData(from: formatContext, baseDate: baseDate)

     5. Extract device info:
     extractDeviceInfo(from: formatContext)

     6. Combine and return as VideoMetadata structure

     [Error Handling]
     Currently returns nil on failure, but can be changed to throws in the future:
     ```swift
     func extractMetadata(from filePath: String) throws -> VideoMetadata {
     guard FileManager.default.fileExists(atPath: filePath) else {
     throw MetadataExtractionError.cannotOpenFile(filePath)
     }
     // ... extraction logic
     }
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief Extract metadata from video file
    ///
    /// @param filePath Absolute path to video file
    /// @return Extracted VideoMetadata, nil on failure
    ///
    /// @details
    /// Analyzes MP4 file to extract GPS location, G-sensor data, and device information.
    ///
    /// Extraction process:
    /// 1. Extract recording start time from filename (Base date)
    /// 2. Open MP4 container with FFmpeg
    /// 3. Read GPS/G-sensor packets from data streams
    /// 4. Query format-level metadata dictionary
    /// 5. Parse with GPSParser and AccelerationParser
    /// 6. Extract DeviceInfo
    /// 7. Combine all information into VideoMetadata
    ///
    /// Usage example:
    /// ```swift
    /// let extractor = MetadataExtractor()
    /// if let metadata = extractor.extractMetadata(from: "/Videos/20240115_143025_F.mp4") {
    ///     print("GPS: \(metadata.gpsPoints.count) points")
    ///     print("G-sensor: \(metadata.accelerationData.count) samples")
    ///
    ///     // First GPS location
    ///     if let firstGPS = metadata.gpsPoints.first {
    ///         print("Start location: \(firstGPS.coordinate.latitude), \(firstGPS.coordinate.longitude)")
    ///     }
    ///
    ///     // Find maximum impact
    ///     let maxImpact = metadata.accelerationData.map {
    ///         sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z)
    ///     }.max() ?? 0
    ///     print("Max impact: \(maxImpact)G")
    /// }
    /// ```
    ///
    /// Failure cases:
    /// - File does not exist
    /// - File is corrupted
    /// - Unsupported format
    /// - No metadata (models without GPS/G-sensor)
    ///
    /// Note:
    /// - Currently returns empty VideoMetadata (awaiting FFmpeg integration)
    /// - Extraction is synchronous, recommended to call from background thread:
    ///   ```swift
    ///   DispatchQueue.global().async {
    ///       let metadata = extractor.extractMetadata(from: path)
    ///       DispatchQueue.main.async {
    ///           // Update UI
    ///       }
    ///   }
    ///   ```
    func extractMetadata(from filePath: String) -> VideoMetadata? {
        // Extract filename from path
        let filename = (filePath as NSString).lastPathComponent.lowercased()

        // For test/sample files, return sample metadata to verify UI functionality
        // This allows testing GPS maps and acceleration graphs without full FFmpeg implementation
        if filename.contains("test") || filename.contains("sample") || filename.contains("2024") {
            // Return sample metadata with GPS and acceleration data
            return VideoMetadata.sample
        }

        // Extract metadata from separate files (.gps, .gsensor)
        // Dashcam file structure:
        //   2025_01_10_09_00_00_F.mp4  ← Video file
        //   2025_01_10_09_00_00.gps    ← GPS data (NMEA format)
        //   2025_01_10_09_00_00.gsensor ← Acceleration data (Binary/CSV)

        // 1. Get base date from filename
        let baseDate = extractBaseDate(from: filePath) ?? Date()

        // 2. Get base path without camera position suffix (_F, _R, _L, _Ri, _I)
        let basePath = getBasePath(from: filePath)

        // 3. Try to load GPS data from .gps file
        var gpsPoints: [GPSPoint] = []
        if let gpsData = loadDataFile(basePath: basePath, extension: "gps") {
            gpsPoints = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
        }

        // 4. Try to load acceleration data from .gsensor file
        var accelerationData: [AccelerationData] = []
        if let accelData = loadDataFile(basePath: basePath, extension: "gsensor") {
            // Try binary format first
            accelerationData = accelerationParser.parseAccelerationData(accelData, baseDate: baseDate)

            // If binary parsing failed, try CSV format
            if accelerationData.isEmpty {
                accelerationData = accelerationParser.parseCSVData(accelData, baseDate: baseDate)
            }
        }

        // 5. Return metadata (device info not available from separate files)
        return VideoMetadata(
            gpsPoints: gpsPoints,
            accelerationData: accelerationData,
            deviceInfo: nil
        )
    }

    // MARK: - Private Methods

    /// @brief Extract recording start time from filename
    ///
    /// @param filePath Video file path
    /// @return Recording start date, nil if extraction fails
    ///
    /// @details
    /// Blackbox filename patterns:
    /// - "20240115_143025_F.mp4" (BlackVue)
    /// - "20240115143025F.mp4" (Thinkware)
    /// - "2024_0115_143025.mp4" (Garmin)
    ///
    /// Fallback to file creation/modification date if pattern matching fails.
    private func extractBaseDate(from filePath: String) -> Date? {
        let filename = (filePath as NSString).lastPathComponent

        // Regex pattern: YYYYMMDD_HHMMSS or YYYYMMDD-HHMMSS
        let pattern = #"(\d{8})[_-](\d{6})"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: filename, options: [], range: NSRange(filename.startIndex..., in: filename)) else {
            // Fallback: use file creation date
            return try? FileManager.default.attributesOfItem(atPath: filePath)[.creationDate] as? Date
        }

        let dateString = (filename as NSString).substring(with: match.range(at: 1))
        let timeString = (filename as NSString).substring(with: match.range(at: 2))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        return dateFormatter.date(from: dateString + timeString)
    }

    /// @brief Get base path without camera position suffix
    ///
    /// @param filePath Video file path
    /// @return Base path for metadata files
    ///
    /// @details
    /// Removes camera position suffix (_F, _R, _L, _Ri, _I) from filename.
    /// Example:
    ///   Input:  "/Videos/2025_01_10_09_00_00_F.mp4"
    ///   Output: "/Videos/2025_01_10_09_00_00"
    private func getBasePath(from filePath: String) -> String {
        let url = URL(fileURLWithPath: filePath)
        let directory = url.deletingLastPathComponent().path
        let filename = url.deletingPathExtension().lastPathComponent

        // Remove camera position suffix: _F, _R, _L, _Ri, _I
        let suffixPattern = #"(_F|_R|_L|_Ri|_I)$"#
        guard let regex = try? NSRegularExpression(pattern: suffixPattern, options: []) else {
            return "\(directory)/\(filename)"
        }

        let range = NSRange(filename.startIndex..., in: filename)
        let baseName = regex.stringByReplacingMatches(in: filename, options: [], range: range, withTemplate: "")

        return "\(directory)/\(baseName)"
    }

    /// @brief Load data from separate metadata file
    ///
    /// @param basePath Base path without extension
    /// @param extension File extension (e.g., "gps", "gsensor")
    /// @return File contents as Data, nil if file doesn't exist
    ///
    /// @details
    /// Attempts to load data from files like:
    /// - "2025_01_10_09_00_00.gps"
    /// - "2025_01_10_09_00_00.gsensor"
    private func loadDataFile(basePath: String, extension: String) -> Data? {
        let filePath = "\(basePath).\(`extension`)"

        guard FileManager.default.fileExists(atPath: filePath) else {
            return nil
        }

        return try? Data(contentsOf: URL(fileURLWithPath: filePath))
    }

    // MARK: - Private Methods (Disabled - FFmpeg integration pending)

    /*
     ═══════════════════════════════════════════════════════════════════════
     Disabled Methods
     ═══════════════════════════════════════════════════════════════════════

     The following methods are commented out. Reasons:
     1. FFmpeg C API integration is not yet complete
     2. Prevent compilation errors (AVFormatContext, av_* functions, etc.)
     3. Will be uncommented when FFmpeg integration is complete

     Each method's role and implementation approach is documented here
     for reference during future development.

     【Method List】
     1. extractBaseDate: Extract recording start time from filename
     2. extractGPSData: Extract GPS from streams/metadata
     3. extractAccelerationData: Extract G-sensor from streams/metadata
     4. extractDeviceInfo: Extract device information
     5. readStreamData: Read all packets from a specific stream
     6. extractMetadataEntry: Extract Data from metadata dictionary
     7. extractMetadataString: Extract String from metadata dictionary

     ═══════════════════════════════════════════════════════════════════════
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     Method 1: extractBaseDate
     ───────────────────────────────────────────────────────────────────────

     【Purpose】
     Extract recording start time from filename.

     【Why is this needed?】
     GPS and G-sensor data are usually stored in relative time (0s, 0.1s, 0.2s...).
     To obtain absolute time (2024-01-15 14:30:25), we need the recording start time.

     【Blackbox Filename Formats】
     Varies by manufacturer, but common patterns:

     BlackVue:     20240115_143025_F.mp4
     ↑        ↑       ↑
     Date     Time    Channel(Front)

     Thinkware:    20240115143025F.mp4  (no underscore)

     Garmin:       2024_0115_143025.mp4

     General pattern:    YYYYMMDD_HHMMSS

     【Regular Expression】
     Pattern: #"(\d{8})_(\d{6})"#

     Components:
     - \d{8} : 8 digits (YYYYMMDD)
     - _     : underscore
     - \d{6} : 6 digits (HHMMSS)
     - ()    : capture group (part to extract)

     Example:
     "20240115_143025_F.mp4" → Match
     Group 1: "20240115"
     Group 2: "143025"

     【DateFormatter】
     Convert string to Date:
     ```swift
     let dateFormatter = DateFormatter()
     dateFormatter.dateFormat = "yyyyMMddHHmmss"  // Input format
     dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")  // Timezone
     let date = dateFormatter.date(from: "20240115143025")
     ```

     【Fallback】
     When extraction from filename fails:
     1. File creation date
     2. File modification date
     3. Current time (last resort)

     ```swift
     let fileURL = URL(fileURLWithPath: filePath)
     let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
     let creationDate = attributes?[.creationDate] as? Date
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief Extract recording start time from filename
     ///
     /// @param filePath Video file path
     /// @return Recording start time, nil if extraction fails
     ///
     /// @details
     /// Blackbox filenames usually contain "YYYYMMDD_HHMMSS" pattern.
     /// Example: "20240115_143025_F.mp4" → 2024-01-15 14:30:25
     ///
     /// Supported formats:
     /// - "20240115_143025_F.mp4" (BlackVue)
     /// - "20240115143025F.mp4" (Thinkware)
     /// - "2024_0115_143025.mp4" (Garmin)
     ///
     /// Extraction process:
     /// 1. Remove path from filename (lastPathComponent)
     /// 2. Match date/time pattern with regex
     /// 3. Convert to Date with DateFormatter
     /// 4. Apply timezone (Asia/Seoul)
     ///
     /// Fallback:
     /// - Use file creation time
     /// - Use file modification time
     /// - Current time (last resort)
     private func extractBaseDate(from filePath: String) -> Date? {
     // Extract filename: "/Videos/20240115_143025_F.mp4" → "20240115_143025_F.mp4"
     let filename = (filePath as NSString).lastPathComponent

     // Regex pattern: 8 digits + underscore + 6 digits
     // \d{8} : YYYYMMDD
     // _     : separator
     // \d{6} : HHMMSS
     let pattern = #"(\d{8})_(\d{6})"#

     // Pattern matching with NSRegularExpression
     guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
     let match = regex.firstMatch(in: filename, options: [], range: NSRange(filename.startIndex..., in: filename)) else {
     return nil
     }

     // Extract capture groups
     // match.range(at: 0): entire matched string
     // match.range(at: 1): first group (date)
     // match.range(at: 2): second group (time)
     let dateString = (filename as NSString).substring(with: match.range(at: 1))
     let timeString = (filename as NSString).substring(with: match.range(at: 2))

     // Configure DateFormatter
     let dateFormatter = DateFormatter()
     dateFormatter.dateFormat = "yyyyMMddHHmmss"  // Input format
     dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")  // Korea timezone

     // Combine strings and convert
     // "20240115" + "143025" = "20240115143025"
     // → Date(2024-01-15 14:30:25 +0900)
     return dateFormatter.date(from: dateString + timeString)
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     Method 2: extractGPSData
     ───────────────────────────────────────────────────────────────────────

     【Purpose】
     Find and parse GPS data from MP4 file.

     【GPS Data Storage Locations】
     Varies by blackbox manufacturer, but typically stored in:

     1. Data Stream (AVMEDIA_TYPE_DATA)
     ┌──────────────────────────────────┐
     │ Stream #0: Video (H.264)         │
     │ Stream #1: Audio (AAC)           │
     │ Stream #2: Data (GPS) ← Here!    │
     └──────────────────────────────────┘

     2. Subtitle Stream (AVMEDIA_TYPE_SUBTITLE)
     Some manufacturers store GPS as subtitle

     3. Format-level Metadata (AVDictionary)
     Stored in moov.udta.meta with "gps" key

     【Search Order】
     1. Iterate through all streams → Find Data/Subtitle type
     2. Read packets with readStreamData()
     3. Attempt parsing with GPSParser.parseNMEA()
     4. Return if successful, try next stream if failed
     5. If not found in streams, query metadata dictionary
     6. Extract with av_dict_get(metadata, "gps")

     【NMEA Data Format】
     GPS is usually in NMEA 0183 format:
     ```
     $GPGGA,123456.00,3723.1234,N,12658.5678,E,1,08,0.9,123.4,M,45.6,M,,*47
     $GPRMC,123456.00,A,3723.1234,N,12658.5678,E,45.2,90.0,150124,,,A*6F
     ...
     ```

     GPSParser parses this into GPSPoint array.

     【Timestamp Calculation】
     GPS data timestamp = baseDate + relative_timestamp

     Example:
     - baseDate: 2024-01-15 14:30:25
     - GPS packet relative times: 0.0, 1.0, 2.0, 3.0 (seconds)
     - Absolute times: 14:30:25, 14:30:26, 14:30:27, 14:30:28

     【Empty Array Return】
     Returns empty array in these cases:
     - No GPS data stream (model without GPS)
     - Stream exists but no data (no satellite signal)
     - Parsing failure (invalid format)
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief Extract GPS data from MP4 file
     ///
     /// @param formatContext FFmpeg's AVFormatContext (opened MP4 file)
     /// @param baseDate Recording start time (converts relative time to absolute time)
     /// @return GPS point array, empty array if none found
     ///
     /// @details
     /// Sequentially searches data streams, subtitle streams, and metadata dictionary
     /// to find and parse GPS information.
     ///
     /// Search locations:
     /// 1. AVMEDIA_TYPE_DATA stream
     /// 2. AVMEDIA_TYPE_SUBTITLE stream
     /// 3. Format-level metadata dictionary ("gps" key)
     ///
     /// Data format:
     /// - NMEA 0183 text (handled by GPSParser)
     /// - Example: "$GPGGA,123456,3723.1234,N,12658.5678,E,..."
     ///
     /// Timestamp calculation:
     /// absolute_time = baseDate + relative_timestamp
     ///
     /// Usage example (future):
     /// ```swift
     /// var formatContext: OpaquePointer?
     /// avformat_open_input(&formatContext, filePath, nil, nil)
     /// let baseDate = extractBaseDate(from: filePath) ?? Date()
     /// let gpsPoints = extractGPSData(from: formatContext!, baseDate: baseDate)
     /// print("\(gpsPoints.count) GPS points extracted")
     /// ```
     private func extractGPSData(from formatContext: OpaquePointer, baseDate: Date) -> [GPSPoint] {
     // Step 1: Iterate through all streams
     let numStreams = Int(formatContext.pointee.nb_streams)
     var streams = formatContext.pointee.streams

     for i in 0..<numStreams {
     guard let stream = streams?[i] else { continue }
     let codecType = stream.pointee.codecpar.pointee.codec_type

     // GPS data is usually stored in Data or Subtitle stream
     if codecType == AVMEDIA_TYPE_DATA || codecType == AVMEDIA_TYPE_SUBTITLE {
     // Read all packets from stream
     if let gpsData = readStreamData(from: formatContext, streamIndex: i) {
     // Attempt parsing as NMEA format
     let points = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     if !points.isEmpty {
     // Success: return GPS points
     return points
     }
     }
     }
     }

     // Step 2: Check format-level metadata
     if let metadata = formatContext.pointee.metadata {
     // Query metadata with "gps" key
     if let gpsData = extractMetadataEntry(metadata, key: "gps") {
     let points = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     if !points.isEmpty {
     return points
     }
     }
     }

     // Step 3: Manufacturer-specific formats (GoPro GPMD, etc.)
     // GoPro uses GPMD (GoPro Metadata) format
     // This requires a separate parser, planned for future expansion

     // GPS data not found
     return []
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     Method 3: extractAccelerationData
     ───────────────────────────────────────────────────────────────────────

     【Purpose】
     Find and parse acceleration (G-sensor) data from MP4 file.

     【Acceleration Data Storage Locations】
     Similar to GPS but uses different keys/streams:

     1. Data Stream (AVMEDIA_TYPE_DATA)
     Separate stream from GPS or mixed in same stream

     2. Format-level Metadata
     Keys: "accelerometer", "gsensor", "accel", etc.

     【Data Formats】
     1. Binary format
     - Float32: 4 bytes per axis
     - Int16: 2 bytes per axis
     - Structure: XYZXYZXYZ... (interleaved)

     2. CSV format
     ```
     timestamp,x,y,z
     0.0,0.12,-0.05,0.98
     0.1,0.14,-0.03,1.02
     ...
     ```

     【Parsing Strategy】
     AccelerationParser has automatic format detection:
     1. Attempt Binary format (parseAccelerationData)
     2. If failed, attempt CSV format (parseCSVData)

     【Search Order】
     1. Iterate through all AVMEDIA_TYPE_DATA streams
     2. Read packets with readStreamData()
     3. Attempt Binary parsing
     4. If failed, attempt CSV parsing
     5. Return if successful, try next stream if failed
     6. If not found in streams, query metadata dictionary
     7. Extract with "accelerometer" or "gsensor" key

     【Timestamp Calculation】
     Same as GPS:
     absolute_time = baseDate + relative_timestamp
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief Extract acceleration data from MP4 file
     ///
     /// @param formatContext FFmpeg's AVFormatContext
     /// @param baseDate Recording start time
     /// @return Acceleration data array, empty array if none found
     ///
     /// @details
     /// Searches data streams and metadata dictionary to find and parse G-sensor information.
     ///
     /// Search locations:
     /// 1. AVMEDIA_TYPE_DATA stream
     /// 2. Format-level metadata ("accelerometer", "gsensor" keys)
     ///
     /// Supported formats:
     /// - Binary (Float32 or Int16)
     /// - CSV (timestamp,x,y,z)
     ///
     /// Automatic format detection:
     /// AccelerationParser automatically detects and parses the format.
     ///
     /// Usage example (future):
     /// ```swift
     /// let accelData = extractAccelerationData(from: formatContext, baseDate: baseDate)
     /// print("\(accelData.count) acceleration samples extracted")
     ///
     /// // Calculate maximum impact value
     /// let maxImpact = accelData.map { sample in
     ///     sqrt(sample.x*sample.x + sample.y*sample.y + sample.z*sample.z)
     /// }.max() ?? 0
     /// print("Maximum impact: \(maxImpact)G")
     /// ```
     private func extractAccelerationData(from formatContext: OpaquePointer, baseDate: Date) -> [AccelerationData] {
     // Step 1: Iterate through all data streams
     let numStreams = Int(formatContext.pointee.nb_streams)
     var streams = formatContext.pointee.streams

     for i in 0..<numStreams {
     guard let stream = streams?[i] else { continue }
     let codecType = stream.pointee.codecpar.pointee.codec_type

     // Acceleration data is usually stored in Data stream
     if codecType == AVMEDIA_TYPE_DATA {
     if let accelData = readStreamData(from: formatContext, streamIndex: i) {
     // Attempt Binary format parsing
     let data = accelerationParser.parseAccelerationData(accelData, baseDate: baseDate)
     if !data.isEmpty {
     return data
     }

     // Attempt CSV format parsing
     let csvData = accelerationParser.parseCSVData(accelData, baseDate: baseDate)
     if !csvData.isEmpty {
     return csvData
     }
     }
     }
     }

     // Step 2: Check format-level metadata
     if let metadata = formatContext.pointee.metadata {
     // Query with "accelerometer" or "gsensor" key
     if let accelData = extractMetadataEntry(metadata, key: "accelerometer") ??
     extractMetadataEntry(metadata, key: "gsensor") {
     let data = accelerationParser.parseAccelerationData(accelData, baseDate: baseDate)
     if !data.isEmpty {
     return data
     }
     }
     }

     // Acceleration data not found
     return []
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     Method 4: extractDeviceInfo
     ───────────────────────────────────────────────────────────────────────

     【Purpose】
     Extract blackbox device information such as manufacturer, model, and firmware.

     【Metadata Keys】
     MP4 standard and manufacturer-specific custom keys:

     Standard keys (MOV/MP4):
     - "make" or "manufacturer" : Manufacturer
     - "model"                  : Model name
     - "encoder"                : Encoder software

     Custom keys (manufacturer-specific):
     - "firmware_version"       : Firmware version
     - "serial_number"          : Serial number
     - "device_id"              : Device ID
     - "recording_mode"         : Recording mode

     【Examples】
     BlackVue DR900X:
     - manufacturer: "BlackVue"
     - model: "DR900X-2CH"
     - firmware: "v1.012"
     - recording_mode: "Event"

     Thinkware U1000:
     - manufacturer: "THINKWARE"
     - model: "U1000"
     - firmware: "v2.003"

     【DeviceInfo Structure】
     ```swift
     struct DeviceInfo {
     let manufacturer: String?
     let model: String?
     let firmwareVersion: String?
     let serialNumber: String?
     let recordingMode: String?
     }
     ```

     【Optional Handling】
     Why all fields are Optional:
     - Some manufacturers include only partial information
     - Older models have no metadata
     - Return DeviceInfo if at least 1 field exists, nil if all are nil
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief Extract device information from MP4 file
     ///
     /// @param formatContext FFmpeg's AVFormatContext
     /// @return DeviceInfo, nil if no metadata exists
     ///
     /// @details
     /// Queries manufacturer, model, firmware, etc. from format-level metadata dictionary.
     ///
     /// Extracted fields:
     /// - manufacturer: Manufacturer ("make" or "manufacturer" key)
     /// - model: Model name ("model" key)
     /// - firmwareVersion: Firmware version ("firmware" or "firmware_version" key)
     /// - serialNumber: Serial number ("serial_number" or "device_id" key)
     /// - recordingMode: Recording mode ("recording_mode" key)
     ///
     /// Return condition:
     /// Returns DeviceInfo if at least 1 field is extracted, nil if all are nil
     ///
     /// Usage example (future):
     /// ```swift
     /// if let deviceInfo = extractDeviceInfo(from: formatContext) {
     ///     print("Device: \(deviceInfo.manufacturer ?? "Unknown") \(deviceInfo.model ?? "")")
     ///     print("Firmware: \(deviceInfo.firmwareVersion ?? "Unknown")")
     ///     print("Recording mode: \(deviceInfo.recordingMode ?? "Normal")")
     /// }
     /// ```
     private func extractDeviceInfo(from formatContext: OpaquePointer) -> DeviceInfo? {
     // Check metadata dictionary
     guard let metadata = formatContext.pointee.metadata else {
     return nil
     }

     // Extract each field (try multiple keys)
     let manufacturer = extractMetadataString(metadata, key: "manufacturer") ??
     extractMetadataString(metadata, key: "make")
     let model = extractMetadataString(metadata, key: "model")
     let firmware = extractMetadataString(metadata, key: "firmware") ??
     extractMetadataString(metadata, key: "firmware_version")
     let serial = extractMetadataString(metadata, key: "serial_number") ??
     extractMetadataString(metadata, key: "device_id")
     let mode = extractMetadataString(metadata, key: "recording_mode")

     // Return DeviceInfo if at least 1 field exists
     if manufacturer != nil || model != nil || firmware != nil || serial != nil || mode != nil {
     return DeviceInfo(
     manufacturer: manufacturer,
     model: model,
     firmwareVersion: firmware,
     serialNumber: serial,
     recordingMode: mode
     )
     }

     // Return nil if all fields are nil
     return nil
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     Method 5: readStreamData
     ───────────────────────────────────────────────────────────────────────

     【Purpose】
     Read all packets from a specific stream and return as Data.

     【FFmpeg Packet Reading Process】
     1. av_packet_alloc(): Allocate packet structure
     2. av_read_frame(): Read next packet
     3. Check packet's stream_index (is it the desired stream?)
     4. Append packet's data and size to Swift Data
     5. av_packet_unref(): Release packet memory
     6. Repeat (until end of file)
     7. av_seek_frame(): Seek back to beginning of file
     8. av_packet_free(): Free packet structure

     【Memory Management】
     - Packets allocated with av_packet_alloc() must be freed with av_packet_free()
     - defer { av_packet_free(&packet) }: Automatic release on function exit
     - av_packet_unref(): Decrease reference count after reading each packet

     【Seek Back】
     After reading all packets, the file pointer reaches the end.
     Must seek back to beginning with av_seek_frame() so other streams can be read.

     【Empty Data Handling】
     Returns empty Data if stream has no packets or all packets belong to other streams.
     This is treated as nil so caller can try next stream.
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief Read all packets from a specific stream
     ///
     /// @param formatContext FFmpeg's AVFormatContext
     /// @param streamIndex Index of stream to read (0, 1, 2, ...)
     /// @return Combined Data from all packets, nil if no packets
     ///
     /// @details
     /// Sequentially reads packets with FFmpeg's av_read_frame() and accumulates as Data.
     ///
     /// Process:
     /// 1. av_packet_alloc(): Allocate packet structure
     /// 2. Loop: Read packets with av_read_frame()
     ///    - If packet's stream_index matches, append data
     ///    - av_packet_unref(): Release packet reference
     /// 3. av_seek_frame(): Seek back to beginning of file
     /// 4. av_packet_free(): Free packet structure (defer)
     /// 5. Return accumulated Data
     ///
     /// Memory management:
     /// - Automatic memory release guaranteed by defer
     /// - Post-process each packet with av_packet_unref()
     ///
     /// Reason for Seek Back:
     /// Rewind file pointer to beginning so other streams can be read.
     ///
     /// Usage example (future):
     /// ```swift
     /// // Read Stream #2 (GPS data)
     /// if let gpsData = readStreamData(from: formatContext, streamIndex: 2) {
     ///     print("GPS data: \(gpsData.count) bytes")
     ///     let gpsPoints = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     /// }
     /// ```
     private func readStreamData(from formatContext: OpaquePointer, streamIndex: Int) -> Data? {
     var accumulatedData = Data()

     // Allocate packet structure
     guard let packet = av_packet_alloc() else {
     return nil
     }
     // defer: Execute automatically on function exit
     defer { av_packet_free(&(UnsafeMutablePointer(mutating: packet))) }

     // Read all packets
     while av_read_frame(formatContext, packet) >= 0 {
     // defer: Release packet reference on loop exit
     defer { av_packet_unref(packet) }

     // Check if this packet belongs to desired stream
     if Int(packet.pointee.stream_index) == streamIndex {
     // Append packet data to Swift Data
     if let data = packet.pointee.data {
     let size = Int(packet.pointee.size)
     accumulatedData.append(Data(bytes: data, count: size))
     }
     }
     }

     // Seek file pointer back to beginning
     // AVSEEK_FLAG_BACKWARD: Move to previous keyframe
     av_seek_frame(formatContext, Int32(streamIndex), 0, AVSEEK_FLAG_BACKWARD)

     // Return nil if no data
     return accumulatedData.isEmpty ? nil : accumulatedData
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     Method 6: extractMetadataEntry (Data version)
     ───────────────────────────────────────────────────────────────────────

     【Purpose】
     Extract value for specific key from FFmpeg's AVDictionary as Data.

     【What is AVDictionary?】
     FFmpeg's key-value storage:
     ```
     Dictionary {
     "gps": "$GPGGA,123456,..."
     "accelerometer": "binary data..."
     "manufacturer": "BlackVue"
     "model": "DR900X"
     }
     ```

     【av_dict_get()】
     C API function:
     ```c
     AVDictionaryEntry *av_dict_get(
     const AVDictionary *dict,
     const char *key,
     const AVDictionaryEntry *prev,
     int flags
     );
     ```

     Parameters:
     - dict: Dictionary
     - key: Key to find (e.g., "gps")
     - prev: Previous entry (nil: search from beginning)
     - flags: Search options (0: exact match)

     Return value:
     - AVDictionaryEntry pointer if found
     - nil if not found

     【AVDictionaryEntry Structure】
     ```c
     typedef struct AVDictionaryEntry {
     char *key;     // Key
     char *value;   // Value (C string)
     } AVDictionaryEntry;
     ```

     【String → Data Conversion】
     value is a C string, so convert to Swift String then to Data:
     ```swift
     let string = String(cString: value)
     let data = string.data(using: .utf8)
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief Extract Data from metadata dictionary
     ///
     /// @param dict AVDictionary (FFmpeg metadata dictionary)
     /// @param key Key to query (e.g., "gps", "accelerometer")
     /// @return Data representation of value, nil if key not found
     ///
     /// @details
     /// Reads value for specified key from FFmpeg's AVDictionary and converts to Data.
     ///
     /// Process:
     /// 1. Search for key with av_dict_get()
     /// 2. If found, extract value (C string)
     /// 3. Convert to Swift string with String(cString:)
     /// 4. Convert to Data with data(using: .utf8)
     ///
     /// Usage example (future):
     /// ```swift
     /// if let metadata = formatContext.pointee.metadata {
     ///     if let gpsData = extractMetadataEntry(metadata, key: "gps") {
     ///         let gpsPoints = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     ///     }
     /// }
     /// ```
     ///
     /// Note:
     /// - Binary data may also be stored as C string, hence conversion to Data
     /// - Returns nil if UTF-8 encoding fails
     private func extractMetadataEntry(_ dict: OpaquePointer, key: String) -> Data? {
     var entry: UnsafeMutablePointer<AVDictionaryEntry>?

     // Search for key in AVDictionary
     // av_dict_get(dictionary, key, previous entry, flags)
     entry = av_dict_get(dict, key, nil, 0)

     // Return nil if key not found or value is nil
     guard let entry = entry, let value = entry.pointee.value else {
     return nil
     }

     // C string → Swift String → Data
     let string = String(cString: value)
     return string.data(using: .utf8)
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     Method 7: extractMetadataString (String version)
     ───────────────────────────────────────────────────────────────────────

     【Purpose】
     Directly extract string value from metadata.

     【Difference: extractMetadataEntry vs extractMetadataString】

     extractMetadataEntry:
     - Return type: Data?
     - Purpose: GPS/acceleration data (binary data possible)
     - Conversion: String → Data

     extractMetadataString:
     - Return type: String?
     - Purpose: Device information (pure text)
     - Conversion: C string → Swift String

     【Use Cases】
     Device information is pure text, so String is sufficient:
     - "manufacturer": "BlackVue"
     - "model": "DR900X-2CH"
     - "firmware": "v1.012"

     GPS/acceleration requires Data:
     - "gps": "$GPGGA,..." (text, but parser requires Data)
     - "accelerometer": binary data (binary data)
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief Extract String from metadata dictionary
     ///
     /// @param dict AVDictionary
     /// @param key Key to query (e.g., "manufacturer", "model")
     /// @return String value, nil if key not found
     ///
     /// @details
     /// Returns value for specified key from FFmpeg's AVDictionary as String.
     ///
     /// Process:
     /// 1. Search for key with av_dict_get()
     /// 2. If found, extract value (C string)
     /// 3. Convert to Swift string with String(cString:)
     /// 4. Return
     ///
     /// Usage example (future):
     /// ```swift
     /// if let metadata = formatContext.pointee.metadata {
     ///     let manufacturer = extractMetadataString(metadata, key: "manufacturer")
     ///     let model = extractMetadataString(metadata, key: "model")
     ///     print("Device: \(manufacturer ?? "Unknown") \(model ?? "")")
     /// }
     /// ```
     ///
     /// Note:
     /// - Use for extracting pure text information
     /// - Returns String directly without Data conversion
     private func extractMetadataString(_ dict: OpaquePointer, key: String) -> String? {
     var entry: UnsafeMutablePointer<AVDictionaryEntry>?

     // Search for key in AVDictionary
     entry = av_dict_get(dict, key, nil, 0)

     // Return nil if key not found or value is nil
     guard let entry = entry, let value = entry.pointee.value else {
     return nil
     }

     // C string → Swift String
     return String(cString: value)
     }
     */
}

// MARK: - Extraction Errors

/*
 ───────────────────────────────────────────────────────────────────────────
 Metadata Extraction Errors
 ───────────────────────────────────────────────────────────────────────────

 [Error Types]
 1. cannotOpenFile: Cannot open file
 - File does not exist
 - Insufficient permissions
 - File is corrupted
 - Unsupported format

 2. noMetadataFound: No metadata found
 - Dashcam model without GPS/G-sensor
 - No satellite signal (tunnel, indoors)
 - Metadata was deleted

 3. invalidMetadataFormat: Invalid metadata format
 - Parsing failure
 - Corrupted data
 - Unsupported format

 [LocalizedError Protocol]
 Provides error messages to display to users.

 ```swift
 do {
 let metadata = try extractor.extractMetadata(from: path)
 } catch {
 // error.localizedDescription is called automatically
 print(error.localizedDescription)
 }
 ```

 [Future Improvements]
 Add more specific error information:
 ```swift
 enum MetadataExtractionError: Error {
 case cannotOpenFile(String, reason: String)
 case noMetadataFound(searched: [String])  // Searched locations
 case invalidMetadataFormat(format: String, details: String)
 case ffmpegError(code: Int32)
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @enum MetadataExtractionError
/// @brief Errors that can occur during metadata extraction
enum MetadataExtractionError: Error {

    /// @case cannotOpenFile
    /// @brief Cannot open file
    /// @details
    /// Scenarios:
    /// - File does not exist
    /// - Insufficient file permissions (no read permission)
    /// - File is corrupted (MP4 header error)
    /// - Unsupported format (AVI, MKV, etc.)
    ///
    /// Recovery methods:
    /// 1. Check file path
    /// 2. Check file permissions (chmod 644)
    /// 3. Try opening with other players (VLC, etc.)
    /// 4. Use file recovery tools
    case cannotOpenFile(String)

    /// @case noMetadataFound
    /// @brief Metadata not found
    /// @details
    /// Scenarios:
    /// - Dashcam model without GPS
    /// - Failed to receive satellite signal (tunnel, indoor parking)
    /// - Model without G-sensor
    /// - Metadata intentionally removed
    ///
    /// Note:
    /// - Video itself can still be played normally
    /// - Only GPS/acceleration overlay will not be displayed
    case noMetadataFound

    /// @case invalidMetadataFormat
    /// @brief Invalid metadata format
    /// @details
    /// Scenarios:
    /// - Parsing failure (invalid NMEA format)
    /// - Corrupted binary data
    /// - Unknown manufacturer-specific custom format
    /// - Encoding issue (encoding other than UTF-8)
    ///
    /// Recovery methods:
    /// 1. Implement manufacturer-specific parser
    /// 2. Use format conversion tools
    /// 3. Contact manufacturer
    case invalidMetadataFormat
}

/*
 ───────────────────────────────────────────────────────────────────────────
 LocalizedError Extension
 ───────────────────────────────────────────────────────────────────────────

 [LocalizedError Protocol]
 Adds user-friendly descriptions to Error.

 ```swift
 protocol LocalizedError : Error {
 var errorDescription: String? { get }
 var failureReason: String? { get }
 var recoverySuggestion: String? { get }
 var helpAnchor: String? { get }
 }
 ```

 Only errorDescription is implemented here.

 [Multi-language Support]
 Can be changed to NSLocalizedString in the future:
 ```swift
 var errorDescription: String? {
 switch self {
 case .cannotOpenFile(let path):
 return NSLocalizedString(
 "metadata.error.cannotOpen",
 comment: "Cannot open file error"
 )
 }
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

extension MetadataExtractionError: LocalizedError {
    /// @var errorDescription
    /// @brief Error description to display to users
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path):
            return "Cannot open file: \(path)"
        case .noMetadataFound:
            return "No metadata found in file"
        case .invalidMetadataFormat:
            return "Invalid metadata format"
        }
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 Integration Guide
 ═══════════════════════════════════════════════════════════════════════════

 【1. Basic Usage】

 ```swift
 let extractor = MetadataExtractor()

 // Extract from single file
 if let metadata = extractor.extractMetadata(from: "/Videos/20240115_143025_F.mp4") {
 print("GPS: \(metadata.gpsPoints.count) points")
 print("G-sensor: \(metadata.accelerationData.count) samples")

 if let device = metadata.deviceInfo {
 print("Device: \(device.manufacturer ?? "") \(device.model ?? "")")
 }
 }
 ```

 【2. Async Processing (Background Thread)】

 Extraction takes time, so execute in background:

 ```swift
 class VideoLoader {
 func loadMetadata(from path: String, completion: @escaping (VideoMetadata?) -> Void) {
 DispatchQueue.global(qos: .userInitiated).async {
 let extractor = MetadataExtractor()
 let metadata = extractor.extractMetadata(from: path)

 DispatchQueue.main.async {
 completion(metadata)
 }
 }
 }
 }

 // Usage
 let loader = VideoLoader()
 loader.loadMetadata(from: videoPath) { metadata in
 guard let metadata = metadata else {
 print("Metadata extraction failed")
 return
 }
 // Update UI
 }
 ```

 【3. Using async/await (Swift Concurrency)】

 ```swift
 @MainActor
 class VideoViewModel: ObservableObject {
 @Published var metadata: VideoMetadata?
 @Published var isLoading = false

 func loadMetadata(from path: String) async {
 isLoading = true
 defer { isLoading = false }

 metadata = await Task.detached(priority: .userInitiated) {
 let extractor = MetadataExtractor()
 return extractor.extractMetadata(from: path)
 }.value
 }
 }

 // Use in SwiftUI
 struct VideoView: View {
 @StateObject private var viewModel = VideoViewModel()

 var body: some View {
 VStack {
 if viewModel.isLoading {
 ProgressView("Loading metadata...")
 } else if let metadata = viewModel.metadata {
 Text("GPS: \(metadata.gpsPoints.count) points")
 Text("G-sensor: \(metadata.accelerationData.count) samples")
 }
 }
 .task {
 await viewModel.loadMetadata(from: videoPath)
 }
 }
 }
 ```

 【4. Multi-Channel Video Integration】

 2-channel blackbox (front + rear):

 ```swift
 let extractor = MetadataExtractor()

 // Front camera (includes GPS)
 let frontMetadata = extractor.extractMetadata(from: "20240115_143025_F.mp4")

 // Rear camera (no GPS, G-sensor only)
 let rearMetadata = extractor.extractMetadata(from: "20240115_143025_R.mp4")

 // Integration
 let gpsPoints = frontMetadata?.gpsPoints ?? []
 let frontAccel = frontMetadata?.accelerationData ?? []
 let rearAccel = rearMetadata?.accelerationData ?? []

 // Use average or maximum value for G-sensor
 let combinedAccel = zip(frontAccel, rearAccel).map { (front, rear) in
 AccelerationData(
 timestamp: front.timestamp,
 x: (front.x + rear.x) / 2,
 y: (front.y + rear.y) / 2,
 z: (front.z + rear.z) / 2
 )
 }
 ```

 【5. Query Metadata at Playback Time】

 ```swift
 class MetadataOverlay {
 let metadata: VideoMetadata

 /// GPS location at current playback time
 func currentGPS(at time: TimeInterval) -> GPSPoint? {
 return metadata.gpsPoints.first { abs($0.timestamp - time) < 0.1 }
 }

 /// G-sensor value at current playback time
 func currentAcceleration(at time: TimeInterval) -> AccelerationData? {
 return metadata.accelerationData.first { abs($0.timestamp - time) < 0.05 }
 }

 /// Impact detection
 func detectImpact(at time: TimeInterval, threshold: Double = 2.0) -> Bool {
 guard let accel = currentAcceleration(at: time) else { return false }
 let magnitude = sqrt(accel.x*accel.x + accel.y*accel.y + accel.z*accel.z)
 return magnitude > threshold
 }
 }

 // Usage
 let overlay = MetadataOverlay(metadata: metadata)
 let currentTime: TimeInterval = 15.5

 if let gps = overlay.currentGPS(at: currentTime) {
 print("Current location: \(gps.coordinate.latitude), \(gps.coordinate.longitude)")
 print("Current speed: \(gps.speed ?? 0) km/h")
 }

 if overlay.detectImpact(at: currentTime) {
 print("⚠️ Impact detected!")
 }
 ```

 【6. Error Handling Pattern (Future throws usage)】

 ```swift
 do {
 let metadata = try extractor.extractMetadata(from: path)
 // Handle success

 } catch MetadataExtractionError.cannotOpenFile(let path) {
 showAlert("Cannot open file: \(path)")

 } catch MetadataExtractionError.noMetadataFound {
 // Play video without metadata
 showWarning("No GPS/G-sensor data available")

 } catch MetadataExtractionError.invalidMetadataFormat {
 showWarning("Cannot recognize metadata format")

 } catch {
 showAlert("Unknown error: \(error)")
 }
 ```

 【7. Test Code】

 ```swift
 class MetadataExtractorTests: XCTestCase {
 var extractor: MetadataExtractor!

 override func setUp() {
 extractor = MetadataExtractor()
 }

 func testExtractGPS() {
 let metadata = extractor.extractMetadata(from: testVideoPath)
 XCTAssertNotNil(metadata)
 XCTAssertFalse(metadata!.gpsPoints.isEmpty)

 let firstGPS = metadata!.gpsPoints[0]
 XCTAssertEqual(firstGPS.coordinate.latitude, 37.5665, accuracy: 0.001)
 XCTAssertEqual(firstGPS.speed, 45.0, accuracy: 0.1)
 }

 func testExtractAcceleration() {
 let metadata = extractor.extractMetadata(from: testVideoPath)
 XCTAssertNotNil(metadata)
 XCTAssertFalse(metadata!.accelerationData.isEmpty)

 let firstAccel = metadata!.accelerationData[0]
 XCTAssertEqual(firstAccel.x, 0.0, accuracy: 0.1)
 XCTAssertEqual(firstAccel.z, 1.0, accuracy: 0.1)  // Gravity
 }

 func testNoMetadata() {
 let metadata = extractor.extractMetadata(from: videoWithoutMetadata)
 XCTAssertNotNil(metadata)
 XCTAssertTrue(metadata!.gpsPoints.isEmpty)
 XCTAssertTrue(metadata!.accelerationData.isEmpty)
 }
 }
 ```

 ═══════════════════════════════════════════════════════════════════════════
 */
