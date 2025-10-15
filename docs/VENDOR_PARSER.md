# Vendor Parser Architecture

## Overview

The Blackbox Player implements a flexible, extensible vendor parser system that automatically detects and parses video files from different dashcam manufacturers. Each vendor has unique file naming conventions, directory structures, and metadata formats. The vendor parser architecture handles these differences transparently.

## Architecture

The vendor parser system uses two primary design patterns:

### Strategy Pattern
Each vendor has its own parser implementing the `VendorParserProtocol`, allowing vendor-specific parsing logic while maintaining a consistent interface.

### Factory Pattern
`VendorDetector` analyzes files in a directory and automatically selects the appropriate parser based on filename patterns.

## Core Components

### 1. VendorParserProtocol

The protocol that all vendor parsers must implement:

```swift
protocol VendorParserProtocol {
    /// Unique vendor identifier (e.g., "cr2000omega", "blackvue")
    var vendorId: String { get }

    /// Human-readable vendor name (e.g., "CR-2000 OMEGA", "BlackVue")
    var vendorName: String { get }

    /// Check if filename matches this vendor's pattern
    func matches(_ filename: String) -> Bool

    /// Parse video file metadata from filename and path
    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo?

    /// Extract GPS data from video file
    func extractGPSData(from fileURL: URL) -> [GPSPoint]

    /// Extract accelerometer data from video file
    func extractAccelerationData(from fileURL: URL) -> [AccelerationData]

    /// Return list of features this vendor supports
    func supportedFeatures() -> [VendorFeature]
}
```

### 2. VendorDetector

Automatically detects the dashcam vendor by analyzing files in a directory:

```swift
class VendorDetector {
    /// Registered parsers (order matters - first match wins)
    private let parsers: [VendorParserProtocol] = [
        CR2000OmegaParser(),
        BlackVueParser()
    ]

    /// Cache to avoid repeated detection
    private var cache: [String: VendorParserProtocol?] = [:]

    /// Detect vendor from directory contents
    func detectVendor(in directoryURL: URL) -> VendorParserProtocol? {
        // Check cache first
        let cacheKey = directoryURL.path
        if let cached = cache[cacheKey] {
            return cached
        }

        // Enumerate video files
        let videoFiles = getVideoFiles(in: directoryURL)

        // Count matches per parser
        var matchCounts: [String: Int] = [:]
        for parser in parsers {
            let matches = videoFiles.filter { parser.matches($0) }.count
            matchCounts[parser.vendorId] = matches
        }

        // Select parser with most matches (require 50% threshold)
        let threshold = videoFiles.count / 2
        let detected = parsers.first { parser in
            (matchCounts[parser.vendorId] ?? 0) >= threshold
        }

        // Cache result
        cache[cacheKey] = detected
        return detected
    }
}
```

**Key Features:**
- **Majority voting**: Requires 50% of files to match before selecting a vendor
- **Caching**: Avoids re-scanning directories
- **Extensible**: New parsers added to `parsers` array automatically participate in detection

### 3. VideoFileInfo

Metadata extracted from a video file:

```swift
struct VideoFileInfo {
    let url: URL                    // Full file path
    let timestamp: Date             // Recording start time
    let position: CameraPosition    // .front, .rear, .left, .right, .interior
    let eventType: EventType        // .normal, .impact, .parking, .unknown
    let fileSize: UInt64           // File size in bytes
    let baseFilename: String       // Common base for multi-channel files
}
```

### 4. Supported Vendors

#### CR-2000 OMEGA

**Filename Format:** `YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4`
- Example: `2025-10-07-09h-11m-09s_F_normal.mp4`
- **X**: Camera position (F=Front, R=Rear, L=Left, I=Interior)
- **type**: Event type (normal, event, parking, motion)

**Metadata Format:**
- **Stream #2** contains GPS and accelerometer data
- Format: `X,Y,Z,gJ$GPRMC,...` or `X,Y,Z,gK$GPRMC,...`
- **X,Y,Z**: Acceleration values (first 3 comma-separated values)
- **$GPRMC**: NMEA 0183 GPS sentence

**Implementation:**
```swift
class CR2000OmegaParser: VendorParserProtocol {
    let vendorId = "cr2000omega"
    let vendorName = "CR-2000 OMEGA"

    // Regex: YYYY-MM-DD-HHh-MMm-SSs_X_type.ext
    private let filenamePattern = #"^(\d{4})-(\d{2})-(\d{2})-(\d{2})h-(\d{2})m-(\d{2})s_([FRLIi])_(normal|event|parking|motion)\.(\w+)$"#

    func extractGPSData(from fileURL: URL) -> [GPSPoint] {
        // 1. Extract Stream #2 using MetadataStreamParser
        let parser = MetadataStreamParser()
        let lines = parser.extractMetadataLines(from: fileURL, streamIndex: 2)

        // 2. Extract NMEA sentences
        for line in lines {
            if let nmeaStart = line.range(of: "$GPRMC") {
                let nmea = String(line[nmeaStart.lowerBound...])
                // Parse NMEA with GPSParser
            }
        }
    }
}
```

#### BlackVue

**Filename Format:** `YYYYMMDD_HHMMSS_X.mp4`
- Example: `20240115_143025_F.mp4`
- **X**: Camera position (F=Front, R=Rear, FI/RF=Multi-channel)

**Event Type Detection:**
- Determined by **directory path** (not filename):
  - `/Normal/` → `.normal`
  - `/Event/` → `.impact`
  - `/Parking/` → `.parking`

**Implementation:**
```swift
class BlackVueParser: VendorParserProtocol {
    let vendorId = "blackvue"
    let vendorName = "BlackVue"

    // Regex: YYYYMMDD_HHMMSS_X.mp4
    private let filenamePattern = #"^(\d{8})_(\d{6})_([A-Z]+)\.(\w+)$"#

    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        // Extract event type from path
        let pathComponents = fileURL.pathComponents
        let eventType: EventType
        if pathComponents.contains("Event") {
            eventType = .impact
        } else if pathComponents.contains("Parking") {
            eventType = .parking
        } else {
            eventType = .normal
        }

        // Parse filename for timestamp and camera position
        // ...
    }
}
```

## Metadata Extraction Pipeline

### GPS Data Extraction (CR-2000 OMEGA)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. MetadataStreamParser                                     │
│    FFmpeg extracts Stream #2 as raw binary                  │
│    ├─ Command: ffmpeg -i video.mp4 -map 0:2 -c copy -f data │
│    └─ Output: Raw binary data with embedded text            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Binary Header Filtering                                  │
│    Remove non-printable characters (keep ASCII 32-126)      │
│    ├─ Input:  [binary]0.00,-0.01,0.00,gJ$GPRMC,001107.00... │
│    └─ Output: 0.00,-0.01,0.00,gJ$GPRMC,001107.00,A,3725...  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Line Separation                                          │
│    Split by \r (carriage return)                            │
│    └─ Each line: "X,Y,Z,gJ$GPRMC,..."                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. NMEA Extraction                                          │
│    Extract "$GPRMC" substring to end of line                │
│    └─ NMEA: "$GPRMC,001107.00,A,3725.31464,N,12707.10447,E" │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. GPSParser                                                │
│    Parse NMEA 0183 format                                   │
│    ├─ Latitude: 3725.31464 N → 37.388577°N                  │
│    ├─ Longitude: 12707.10447 E → 127.118407°E               │
│    ├─ Speed: knots → km/h                                   │
│    └─ Combine NMEA time + file base date → absolute time    │
└─────────────────────────────────────────────────────────────┘
                          ↓
                    [GPSPoint]
```

### Accelerometer Data Extraction (CR-2000 OMEGA)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. MetadataStreamParser (same as GPS)                       │
│    Extract Stream #2 and filter binary headers              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. CSV Parsing                                              │
│    Split by comma, extract first 3 values                   │
│    ├─ Line: "0.00,-0.01,0.00,gJ$GPRMC,..."                  │
│    └─ X=0.00, Y=-0.01, Z=0.00                               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Timestamp Generation                                     │
│    Base date from filename + 1 second per line              │
│    ├─ Base: 2025-10-07 09:11:09 (from filename)             │
│    └─ Line 0: 09:11:09, Line 1: 09:11:10, ...               │
└─────────────────────────────────────────────────────────────┘
                          ↓
                 [AccelerationData]
```

## Adding a New Vendor

To add support for a new dashcam vendor:

### Step 1: Create Parser Class

Create a new file `NewVendorParser.swift`:

```swift
import Foundation

class NewVendorParser: VendorParserProtocol {
    // MARK: - VendorParserProtocol

    let vendorId = "newvendor"
    let vendorName = "New Vendor Name"

    // Define filename pattern (NSRegularExpression)
    private let filenamePattern = #"^YOUR_REGEX_HERE$"#
    private let filenameRegex: NSRegularExpression?

    init() {
        self.filenameRegex = try? NSRegularExpression(
            pattern: filenamePattern,
            options: []
        )
    }

    func matches(_ filename: String) -> Bool {
        guard let regex = filenameRegex else { return false }
        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        return regex.firstMatch(in: filename, options: [], range: range) != nil
    }

    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        // 1. Parse filename with regex
        // 2. Extract timestamp components
        // 3. Detect camera position
        // 4. Detect event type
        // 5. Get file size
        // 6. Return VideoFileInfo
    }

    func extractGPSData(from fileURL: URL) -> [GPSPoint] {
        // Implement GPS extraction based on vendor's format
        // Return empty array if not supported
        return []
    }

    func extractAccelerationData(from fileURL: URL) -> [AccelerationData] {
        // Implement accelerometer extraction based on vendor's format
        // Return empty array if not supported
        return []
    }

    func supportedFeatures() -> [VendorFeature] {
        return [
            .gpsData,          // If GPS supported
            .accelerometer,    // If accelerometer supported
            .parkingMode,      // If parking mode supported
            .voiceRecording,   // If voice recording supported
            .cloudSync         // If cloud sync supported
        ]
    }
}
```

### Step 2: Register Parser

Add the new parser to `VendorDetector.swift`:

```swift
class VendorDetector {
    private let parsers: [VendorParserProtocol] = [
        CR2000OmegaParser(),
        BlackVueParser(),
        NewVendorParser()  // ← Add here
    ]
}
```

### Step 3: Create Unit Tests

Create tests in `VendorParserTests.swift`:

```swift
class NewVendorParserTests: XCTestCase {
    var parser: NewVendorParser!

    override func setUp() {
        super.setUp()
        parser = NewVendorParser()
    }

    func testMatchesValidFilename() {
        let validFilenames = [
            "example1.mp4",
            "example2.mp4"
        ]

        for filename in validFilenames {
            XCTAssertTrue(parser.matches(filename))
        }
    }

    func testParseVideoFile() {
        let testURL = URL(fileURLWithPath: "/test/example.mp4")
        let fileInfo = parser.parseVideoFile(testURL)

        XCTAssertNotNil(fileInfo)
        XCTAssertEqual(fileInfo?.position, .front)
        XCTAssertEqual(fileInfo?.eventType, .normal)
    }

    func testSupportedFeatures() {
        let features = parser.supportedFeatures()
        XCTAssertTrue(features.contains(.gpsData))
    }
}
```

### Step 4: Integration Testing

Create a test script to verify with real sample files:

```swift
import Foundation

let sampleDir = URL(fileURLWithPath: "/path/to/sample/files")
let detector = VendorDetector()

// Test vendor detection
if let parser = detector.detectVendor(in: sampleDir) {
    print("✅ Detected vendor: \(parser.vendorName)")

    // Test file parsing
    let files = try FileManager.default.contentsOfDirectory(at: sampleDir, ...)
    for file in files where file.pathExtension == "mp4" {
        if let info = parser.parseVideoFile(file) {
            print("  ✅ Parsed: \(file.lastPathComponent)")
            print("     Date: \(info.timestamp)")
            print("     Camera: \(info.position)")
            print("     Type: \(info.eventType)")
        }
    }

    // Test GPS extraction
    if let firstFile = files.first {
        let gpsPoints = parser.extractGPSData(from: firstFile)
        print("  ✅ GPS points: \(gpsPoints.count)")
    }
} else {
    print("❌ Vendor not detected")
}
```

## Best Practices

### 1. Filename Pattern Design

**Use anchored patterns:**
```swift
// Good: anchored with ^ and $
#"^(\d{4})-(\d{2})-(\d{2})_(\d{6})\.mp4$"#

// Bad: partial match
#"(\d{4})-(\d{2})-(\d{2})"#  // Matches anywhere in string
```

**Capture all components:**
```swift
// Capture groups for easy extraction
#"^(YYYY)-(MM)-(DD)-(HH)h-(MM)m-(SS)s_([FRLIi])_(type)\.(ext)$"#
//  ^^1   ^^2   ^^3   ^^4   ^^5   ^^6   ^^^7      ^^8    ^^9
```

### 2. Error Handling

Always validate before using regex captures:

```swift
guard match.numberOfRanges == expectedCount else { return nil }

// Safe extraction
let year = (filename as NSString).substring(with: match.range(at: 1))
guard let yearInt = Int(year) else { return nil }
```

### 3. Date Parsing with Timezone

Always specify timezone to avoid local time ambiguity:

```swift
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyyMMddHHmmss"
dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")  // Or UTC
```

### 4. GPS/Accelerometer Extraction

Return empty arrays if not supported (don't return nil):

```swift
func extractGPSData(from fileURL: URL) -> [GPSPoint] {
    guard vendorSupportsGPS else {
        return []  // Not supported - return empty array
    }

    // Extraction logic...
}
```

### 5. Feature Flags

Only advertise features that are actually implemented:

```swift
func supportedFeatures() -> [VendorFeature] {
    var features: [VendorFeature] = []

    if hasGPSInMetadata {
        features.append(.gpsData)
    }

    if hasAccelerometerInMetadata {
        features.append(.accelerometer)
    }

    // Don't add features that aren't implemented!
    return features
}
```

## Testing Strategy

### Unit Tests (Required)

1. **Filename Matching Tests**
   - Valid filenames should match
   - Invalid filenames should not match
   - Edge cases (different extensions, case sensitivity)

2. **Parsing Tests**
   - Correct timestamp extraction
   - Correct camera position detection
   - Correct event type detection
   - Base filename generation

3. **Feature Tests**
   - Verify supported features list
   - Test GPS extraction if supported
   - Test accelerometer extraction if supported

### Integration Tests (Recommended)

1. **Vendor Detection**
   - Create temp directory with sample files
   - Verify correct vendor is detected
   - Test with mixed vendor files
   - Test with noise files (non-video files)

2. **Real File Parsing**
   - Use actual sample files from dashcam
   - Verify all metadata is correctly extracted
   - Verify GPS coordinates are in expected range
   - Verify accelerometer values are reasonable

## Performance Considerations

### 1. Regex Compilation

Compile regex once in `init()`, not per-call:

```swift
// Good
class Parser {
    private let regex: NSRegularExpression?

    init() {
        self.regex = try? NSRegularExpression(pattern: pattern)
    }

    func matches(_ filename: String) -> Bool {
        return regex?.firstMatch(...) != nil  // Reuse compiled regex
    }
}

// Bad
func matches(_ filename: String) -> Bool {
    let regex = try? NSRegularExpression(pattern: pattern)  // Recompiles every call!
    return regex?.firstMatch(...) != nil
}
```

### 2. Vendor Detection Caching

VendorDetector caches results per directory to avoid re-scanning:

```swift
private var cache: [String: VendorParserProtocol?] = [:]

func detectVendor(in directoryURL: URL) -> VendorParserProtocol? {
    let cacheKey = directoryURL.path
    if let cached = cache[cacheKey] {
        return cached  // Return cached result
    }

    // Perform detection...
    cache[cacheKey] = result
    return result
}
```

### 3. FFmpeg Process Pooling

For GPS/accelerometer extraction, consider process pooling if extracting from many files:

```swift
// Current: creates new Process per file
func extractGPSData(from fileURL: URL) -> [GPSPoint] {
    let parser = MetadataStreamParser()  // Creates new Process
    // ...
}

// Optimized: reuse MetadataStreamParser instance
class CR2000OmegaParser {
    private let metadataParser = MetadataStreamParser()  // Reuse

    func extractGPSData(from fileURL: URL) -> [GPSPoint] {
        let lines = metadataParser.extractMetadataLines(from: fileURL)
        // ...
    }
}
```

## Troubleshooting

### Common Issues

**1. Regex doesn't match valid filenames**
- Verify pattern is anchored with `^` and `$`
- Check for typos in pattern
- Use online regex tester (e.g., regex101.com) with sample filenames
- Verify escape sequences (use raw strings: `#"..."#`)

**2. Date parsing returns nil**
- Check DateFormatter format string matches extracted components
- Verify timezone is set (don't rely on system timezone)
- Print extracted date components before parsing

**3. GPS/Accelerometer extraction returns empty**
- Verify FFmpeg is installed (`/opt/homebrew/bin/ffmpeg`)
- Check stream index (may not be Stream #2 for all vendors)
- Use `ffprobe` to inspect file structure: `ffprobe -show_streams video.mp4`
- Print raw metadata output before parsing

**4. Vendor detection fails**
- Lower detection threshold (currently 50%)
- Add debug logging to see match counts per vendor
- Verify sample directory contains enough files (need >2 for 50% threshold)

## References

- **VendorParserProtocol**: `BlackboxPlayer/Services/VendorParser/VendorParserProtocol.swift`
- **CR2000OmegaParser**: `BlackboxPlayer/Services/VendorParser/CR2000OmegaParser.swift`
- **BlackVueParser**: `BlackboxPlayer/Services/VendorParser/BlackVueParser.swift`
- **VendorDetector**: `BlackboxPlayer/Services/VendorParser/VendorDetector.swift`
- **MetadataStreamParser**: `BlackboxPlayer/Services/VendorParser/MetadataStreamParser.swift`
- **Unit Tests**: `BlackboxPlayer/Tests/VendorParserTests.swift`

---

**Last Updated**: 2025-10-15
**Version**: 1.0.0
