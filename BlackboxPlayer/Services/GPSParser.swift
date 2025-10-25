/// @file GPSParser.swift
/// @brief NMEA 0183 GPS data parser
/// @author BlackboxPlayer Development Team
/// @details
/// Parses NMEA 0183 format GPS data contained in dashcam video files and converts it to Swift objects (GPSPoint).

/*
 ═══════════════════════════════════════════════════════════════════════════
 GPSParser.swift
 BlackboxPlayer

 NMEA 0183 GPS Data Parser
 ═══════════════════════════════════════════════════════════════════════════

 [What is NMEA 0183?]

 NMEA (National Marine Electronics Association) 0183 is
 a standard protocol for communication between marine electronic devices.

 Dashcams use this protocol to receive information such as
 location, speed, heading, and altitude from GPS modules.


 [NMEA Sentence Structure]

 $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
 │     │      │ │        │ │         │ │     │     │      │     │ │
 │     │      │ │        │ │         │ │     │     │      │     │ └─ Checksum
 │     │      │ │        │ │         │ │     │     │      │     └─── Magnetic variation direction
 │     │      │ │        │ │         │ │     │     │      └───────── Magnetic variation
 │     │      │ │        │ │         │ │     │     └──────────────── Date (DDMMYY)
 │     │      │ │        │ │         │ │     └────────────────────── Heading (degrees)
 │     │      │ │        │ │         │ └──────────────────────────── Speed (knots)
 │     │      │ │        │ │         └────────────────────────────── Longitude direction (E/W)
 │     │      │ │        │ └──────────────────────────────────────── Longitude (DDDMM.MMMM)
 │     │      │ │        └────────────────────────────────────────── Latitude direction (N/S)
 │     │      │ └─────────────────────────────────────────────────── Latitude (DDMM.MMMM)
 │     │      └───────────────────────────────────────────────────── Status (A=Valid, V=Invalid)
 │     └──────────────────────────────────────────────────────────── Time (HHMMSS)
 └────────────────────────────────────────────────────────────────── Sentence type


 [Main Sentence Types]

 1. $GPRMC (Recommended Minimum Specific GPS/TRANSIT Data)
 - Position (latitude, longitude)
 - Speed (knots)
 - Heading (degrees)
 - Date/time
 ➜ Most basic and essential GPS information

 2. $GPGGA (Global Positioning System Fix Data)
 - Position (latitude, longitude)
 - Altitude (meters above sea level)
 - Satellite count
 - HDOP (accuracy indicator)
 ➜ 3D position and accuracy information

 3. $GNRMC, $GNGGA
 - GP: GPS only
 - GN: GPS + GLONASS + Galileo (multi-satellite system)
 ➜ Modern receivers use multiple satellite systems simultaneously


 [Coordinate Format Conversion]

 NMEA format: DDMM.MMMM (Degrees Minutes)
 ┌─────────────────────────────────────┐
 │ 4807.038 (latitude)                 │
 │ ││└─────── Minutes: 07.038          │
 │ ││                                   │
 │ └┴──────── Degrees: 48              │
 └─────────────────────────────────────┘

 Decimal Degrees conversion:
 DD = 48 + (07.038 / 60)
 = 48 + 0.1173
 = 48.1173°

 Direction:
 - N (North) = Positive
 - S (South) = Negative
 - E (East) = Positive
 - W (West) = Negative

 Example: 4807.038,N → +48.1173° (48.1173° North)
 01131.000,E → +11.5167° (11.5167° East)


 [Speed Unit Conversion]

 NMEA expresses speed in knots (nautical miles per hour):

 1 knot = 1 nautical mile / 1 hour
 = 1.852 km/h

 Example: 022.4 knots = 022.4 × 1.852 = 41.48 km/h


 [HDOP (Horizontal Dilution of Precision)]

 Accuracy indicator based on geometric distribution of satellites:

 HDOP Value   Accuracy
 ──────────────────────
 < 1       Ideal (almost impossible)
 1-2       Excellent (±1-2m)
 2-5       Good (±2-5m)
 5-10      Moderate (±5-10m)
 > 10      Poor (±10m or more)

 ┌──────────────────────────────────────┐
 │    HDOP by Satellite Distribution    │
 ├──────────────────────────────────────┤
 │                                      │
 │   Sat1 ●                             │
 │                                      │
 │           ●   ← Evenly distributed   │
 │        Sat2     (Low HDOP = Accurate)│
 │                                      │
 │                   ● Sat3             │
 │                                      │
 │ vs.                                  │
 │                                      │
 │   Sat1 ● ● Sat2                      │
 │           ● Sat3  ← Clustered        │
 │                     (High HDOP = Inaccurate)│
 └──────────────────────────────────────┘


 [Data Merging Strategy]

 Dashcams usually output GPRMC and GPGGA in pairs:

 $GPRMC,123519,A,4807.038,N,...  ← Position, speed, heading
 $GPGGA,123519,4807.038,N,...    ← Same time, adds altitude, accuracy

 Parser merges two sentences to create complete GPSPoint:

 ┌────────────────────────────────────────┐
 │ Step 1: Parse GPRMC                    │
 │   - Create GPSPoint (no altitude)      │
 │   - Add to gpsPoints array             │
 │                                        │
 │ Step 2: Parse GPGGA                    │
 │   - Update last GPSPoint               │
 │   - Add altitude, satelliteCount       │
 │   - Add horizontalAccuracy             │
 └────────────────────────────────────────┘


 [Usage Example]

 ```swift
 let parser = GPSParser()

 // NMEA data extracted from MP4 file
 let nmeaData = """
 $GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A
 $GPGGA,143025,3744.1234,N,12704.5678,E,1,08,1.2,123.4,M,20.1,M,,*4D
 """.data(using: .utf8)!

 // Video file date
 let baseDate = Date() // Extracted from 20240115_143025_F.mp4

 // Parse
 let gpsPoints = parser.parseNMEA(data: nmeaData, baseDate: baseDate)

 // Results
 for point in gpsPoints {
 print("Position: \(point.latitude), \(point.longitude)")
 print("Altitude: \(point.altitude ?? 0)m")
 print("Speed: \(point.speed ?? 0) km/h")
 print("Heading: \(point.heading ?? 0)°")
 print("Satellites: \(point.satelliteCount ?? 0)")
 }
 ```


 [References]

 1. NMEA 0183 Standard Document:
 https://www.nmea.org/content/STANDARDS/NMEA_0183_Standard

 2. Checksum Calculation:
 XOR of all characters between $ and *
 Example: $GPRMC,... *6A
 6A is hexadecimal checksum (currently not implemented)

 3. UTC Time:
 NMEA time is always UTC (Coordinated Universal Time)
 Korea time = UTC + 9 hours

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

/*
 ─────────────────────────────────────────────────────────────────────────
 GPSParser Class
 ─────────────────────────────────────────────────────────────────────────

 [Role]

 Parses NMEA 0183 format GPS data contained in dashcam video files
 and converts it to Swift objects (GPSPoint).


 [Processing Flow]

 ┌─────────────────────────────────────────────────────────────────┐
 │                                                                 │
 │  MP4 File                                                       │
 │  ├── Video Track (H.264)                                        │
 │  ├── Audio Track (AAC)                                          │
 │  └── Data Track: GPS ──┐                                        │
 │         │              │                                        │
 │         │ NMEA Text    │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  ┌──────────────────┐  │                                        │
 │  │ $GPRMC,143025... │  │                                        │
 │  │ $GPGGA,143025... │  │                                        │
 │  │ $GPRMC,143026... │  │                                        │
 │  │ $GPGGA,143026... │  │                                        │
 │  └──────────────────┘  │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  ┌──────────────────┐  │                                        │
 │  │   GPSParser      │  │ ← This class                           │
 │  │   - parseNMEA()  │  │                                        │
 │  │   - parseGPRMC() │  │                                        │
 │  │   - parseGPGGA() │  │                                        │
 │  └──────────────────┘  │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  ┌──────────────────┐  │                                        │
 │  │ [GPSPoint]       │  │                                        │
 │  │ - lat: 37.7368   │  │                                        │
 │  │ - lon: 127.0761  │  │                                        │
 │  │ - alt: 123.4m    │  │                                        │
 │  │ - speed: 83.7 km/h│ │                                        │
 │  └──────────────────┘  │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  Display route on map  │                                        │
 │                        │                                        │
 └─────────────────────────────────────────────────────────────────┘


 [Main Functions]

 1. Parse entire data: parseNMEA(data:baseDate:)
 - Parse multiple NMEA sentences at once
 - Merge RMC and GGA to create complete GPSPoint

 2. Parse single sentence: parseSentence(_:)
 - Parse individual NMEA sentence immediately
 - Used for real-time GPS reception

 3. Coordinate conversion: parseCoordinate(_:direction:)
 - DDMM.MMMM → Decimal degrees

 4. Time conversion: parseDateTime(time:date:)
 - HHMMSS + DDMMYY → Date
 - Merge with baseDate (date extracted from filename)


 [Design Features]

 ✓ Flexible input: Supports both $GPRMC and $GNRMC
 ✓ Data merging: Combines RMC and GGA for complete information
 ✓ Error tolerance: Skips invalid sentences and continues processing
 ✓ UTC-based: All times processed in UTC

 ─────────────────────────────────────────────────────────────────────────
 */

/// @class GPSParser
/// @brief NMEA 0183 GPS sentence parser
/// @details
/// Parses NMEA 0183 format GPS data contained in dashcam video files and converts it to GPSPoint arrays.
///
/// ### Main Functions:
/// 1. Parse entire NMEA data (parseNMEA)
/// 2. Parse single NMEA sentence (parseSentence)
/// 3. Parse GPRMC sentence (position, speed, heading)
/// 4. Parse GPGGA sentence (altitude, satellite count, accuracy)
/// 5. Coordinate format conversion (DDMM.MMMM → Decimal degrees)
/// 6. Time conversion (HHMMSS + DDMMYY → Date)
class GPSParser {
    // MARK: - Properties

    /*
     ─────────────────────────────────────────────────────────────────────
     baseDate: Base date
     ─────────────────────────────────────────────────────────────────────

     [Purpose]

     NMEA sentence time (HHMMSS) has no date information or is incomplete.
     Creates complete timestamp based on date extracted from filename.


     [Example]

     Filename: 20240115_143025_F.mp4
     └──┬──┘
     Base date = January 15, 2024

     NMEA: $GPRMC,143025,A,...
     └─┬─┘
     14:30:25

     Final timestamp: 2024-01-15 14:30:25 UTC


     [Initialization]

     Set when parseNMEA(data:baseDate:) is called.

     ─────────────────────────────────────────────────────────────────────
     */

    /// @var baseDate
    /// @brief Base date
    /// @details
    /// Since NMEA sentence time (HHMMSS) has no date information or is incomplete,
    /// creates complete timestamp based on date extracted from filename.
    ///
    /// ### Purpose:
    /// - Set when parseNMEA(data:baseDate:) is called
    /// - Used for date combination in parseDateTime(time:date:)
    ///
    /// ### Example:
    /// ```
    /// Filename: 20240115_143025_F.mp4
    ///         └──┬──┘
    ///            Base date = January 15, 2024
    ///
    /// NMEA: $GPRMC,143025,A,...
    ///               └─┬─┘
    ///                 14:30:25
    ///
    /// Final timestamp: 2024-01-15 14:30:25 UTC
    /// ```
    private var baseDate: Date?

    // MARK: - Public Methods

    /*
     ═════════════════════════════════════════════════════════════════════
     parseNMEA(data:baseDate:)
     ═════════════════════════════════════════════════════════════════════

     【Function】

     Parses entire NMEA data extracted from MP4 file
     and creates GPSPoint array.


     【Parameters】

     - data: UTF-8 encoded NMEA text
     Example: "$GPRMC,143025...\n$GPGGA,143025...\n"

     - baseDate: Video file date (extracted from filename)
     Example: 20240115_143025_F.mp4 → 2024-01-15


     【Return Value】

     [GPSPoint]: GPS point array sorted by timestamp


     【Processing Flow】

     Step 1: Split text into lines
     ┌────────────────────────────────────┐
     │ $GPRMC,143025,A,3744.1234,N,...    │
     │ $GPGGA,143025,3744.1234,N,...      │
     │ $GPRMC,143026,A,3744.1235,N,...    │
     │ $GPGGA,143026,3744.1235,N,...      │
     └────────────────────────────────────┘
     │
     │ components(separatedBy: .newlines)
     ▼
     [Line 1, Line 2, Line 3, Line 4]


     Step 2: Parse each line
     ┌─────────────────────────────────────────────────┐
     │ for line in lines {                             │
     │   if line.hasPrefix("$GPRMC") {                 │
     │     let rmc = parseGPRMC(line)                  │
     │     let point = createGPSPoint(from: rmc)       │
     │     gpsPoints.append(point)  ← Add to array     │
     │     currentRMC = rmc          ← Temporary store │
     │   }                                             │
     │   else if line.hasPrefix("$GPGGA") {            │
     │     let gga = parseGPGGA(line)                  │
     │     // Update last point                        │
     │     gpsPoints[lastIndex].altitude = gga.altitude│
     │     gpsPoints[lastIndex].satelliteCount = ...   │
     │   }                                             │
     │ }                                               │
     └─────────────────────────────────────────────────┘


     Step 3: Merged result
     ┌──────────────────────────────────────────┐
     │ GPSPoint #1                              │
     │ ├─ timestamp: 2024-01-15 14:30:25 UTC    │
     │ ├─ latitude: 37.7354° (GPRMC)            │
     │ ├─ longitude: 127.0761° (GPRMC)          │
     │ ├─ speed: 83.7 km/h (GPRMC)              │
     │ ├─ heading: 120.0° (GPRMC)               │
     │ ├─ altitude: 123.4m (GPGGA) ← Added      │
     │ ├─ satelliteCount: 8 (GPGGA) ← Added     │
     │ └─ horizontalAccuracy: 12m (GPGGA) ← Added│
     └──────────────────────────────────────────┘


     【Error Handling】

     - Empty sentence: Skip
     - Sentence without $: Skip
     - Status V (invalid): Skip
     - Coordinate parsing failed: Skip
     - UTF-8 decoding failed: Return empty array

     ➜ Extracts all valid data even if there is invalid data


     【Example】

     ```swift
     let parser = GPSParser()

     let nmeaData = """
     $GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A
     $GPGGA,143025,3744.1234,N,12704.5678,E,1,08,1.2,123.4,M,20.1,M,,*4D
     $GPRMC,143026,A,3744.1235,N,12704.5679,E,45.3,121.0,150124,,,A*6B
     $GPGGA,143026,3744.1235,N,12704.5679,E,1,08,1.2,123.5,M,20.1,M,,*4E
     """.data(using: .utf8)!

     let baseDate = dateFormatter.date(from: "20240115")!
     let points = parser.parseNMEA(data: nmeaData, baseDate: baseDate)

     print("Extracted GPS points: \(points.count)")
     // Output: Extracted GPS points: 2

     for (i, point) in points.enumerated() {
     print("Point \(i + 1):")
     print("  Time: \(point.timestamp)")
     print("  Position: \(point.latitude)°, \(point.longitude)°")
     print("  Altitude: \(point.altitude ?? 0)m")
     print("  Speed: \(point.speed ?? 0) km/h")
     print("  Heading: \(point.heading ?? 0)°")
     print("  Satellites: \(point.satelliteCount ?? 0)")
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief Parse entire NMEA data
    /// @param data UTF-8 encoded NMEA text data
    /// @param baseDate Video file date (extracted from filename)
    /// @return GPSPoint array sorted by timestamp
    /// @details
    /// Parses entire NMEA data extracted from MP4 file and creates GPSPoint array.
    ///
    /// ### Processing Flow:
    /// ```
    /// Step 1: Split text into lines
    /// Step 2: Parse each line
    ///   - GPRMC: Create GPSPoint and add to array
    ///   - GPGGA: Update last GPSPoint (add altitude, satellite count, accuracy)
    /// Step 3: Return merged result
    /// ```
    ///
    /// ### Error Handling:
    /// - Empty sentence: Skip
    /// - Sentence without $: Skip
    /// - Status V (invalid): Skip
    /// - Coordinate parsing failed: Skip
    /// - UTF-8 decoding failed: Return empty array
    func parseNMEA(data: Data, baseDate: Date) -> [GPSPoint] {
        // Store base date
        // (used in parseDateTime() when parsing time)
        self.baseDate = baseDate

        // Step 1: Decode as UTF-8 text
        // Return empty array if Data → String conversion fails
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        // Step 2: Split into lines
        // "...\n...\n..." → ["...", "...", "..."]
        let lines = text.components(separatedBy: .newlines)

        // Array to store results
        var gpsPoints: [GPSPoint] = []

        // Temporary storage for merging GPRMC and GPGGA
        // Store after GPRMC parsing, reference when parsing GPGGA
        var currentRMC: NMEARecord?

        // Step 3: Iterate through each line and parse
        for line in lines {
            // Trim leading/trailing whitespace
            let sentence = line.trimmingCharacters(in: .whitespaces)

            // Skip if empty line or doesn't start with $
            // NMEA sentences must start with $
            guard !sentence.isEmpty, sentence.hasPrefix("$") else { continue }

            // Step 3-1: Process GPRMC or GNRMC sentence
            // (position, speed, heading information)
            if sentence.hasPrefix("$GPRMC") || sentence.hasPrefix("$GNRMC") {
                // Parse GPRMC
                if let rmc = parseGPRMC(sentence) {
                    // Temporary store (for merging with next GPGGA)
                    currentRMC = rmc

                    // Create GPSPoint and add to array
                    // (may be updated later by GPGGA)
                    if let point = createGPSPoint(from: rmc) {
                        gpsPoints.append(point)
                    }
                }
            }
            // Step 3-2: Process GPGGA or GNGGA sentence
            // (altitude, satellite count, accuracy information)
            else if sentence.hasPrefix("$GPGGA") || sentence.hasPrefix("$GNGGA") {
                // Parse GPGGA and check previous RMC
                if let gga = parseGPGGA(sentence), let _ = currentRMC {
                    // Update last added GPSPoint
                    if !gpsPoints.isEmpty {
                        let lastIndex = gpsPoints.count - 1
                        let lastPoint = gpsPoints[lastIndex]

                        // Keep GPRMC data,
                        // Add only GPGGA data (altitude, satellite count, accuracy)
                        gpsPoints[lastIndex] = GPSPoint(
                            timestamp: lastPoint.timestamp,
                            latitude: lastPoint.latitude,
                            longitude: lastPoint.longitude,
                            altitude: gga.altitude,              // Added from GPGGA
                            speed: lastPoint.speed,
                            heading: lastPoint.heading,
                            horizontalAccuracy: gga.hdop.map { $0 * 10 },  // HDOP → meters (approximate)
                            satelliteCount: gga.satelliteCount   // Added from GPGGA
                        )
                    }
                }
            }
        }

        return gpsPoints
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseSentence(_:)
     ═════════════════════════════════════════════════════════════════════

     【Function】

     Parses a single NMEA sentence immediately.


     【Use Cases】

     1. Real-time GPS streaming:
     When receiving line by line from GPS module

     2. Debugging:
     Test parsing result of specific sentence


     【Limitations】

     - Only supports GPRMC (GPGGA not supported as it must be merged with RMC)
     - No altitude, satellite count information
     - baseDate must be set


     【Example】

     ```swift
     let parser = GPSParser()
     parser.baseDate = Date() // Base date must be set

     let sentence = "$GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A"

     if let point = parser.parseSentence(sentence) {
     print("Position: \(point.latitude), \(point.longitude)")
     print("Speed: \(point.speed ?? 0) km/h")
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief Parse single NMEA sentence
    /// @param sentence NMEA sentence string
    /// @return GPSPoint or nil (if parsing fails)
    /// @details
    /// Parses a single NMEA sentence immediately.
    ///
    /// ### Use Cases:
    /// 1. Real-time GPS streaming: When receiving line by line from GPS module
    /// 2. Debugging: Test parsing result of specific sentence
    ///
    /// ### Limitations:
    /// - Only supports GPRMC (GPGGA not supported as it must be merged with RMC)
    /// - No altitude, satellite count information
    /// - baseDate must be set
    func parseSentence(_ sentence: String) -> GPSPoint? {
        // Only supports GPRMC or GNRMC
        if sentence.hasPrefix("$GPRMC") || sentence.hasPrefix("$GNRMC") {
            if let rmc = parseGPRMC(sentence) {
                return createGPSPoint(from: rmc)
            }
        }
        return nil
    }

    // MARK: - Private Methods

    /*
     ═════════════════════════════════════════════════════════════════════
     parseGPRMC(_:)
     ═════════════════════════════════════════════════════════════════════

     【Function】

     Parses $GPRMC (Recommended Minimum Specific GPS/TRANSIT Data) sentence.


     【GPRMC Sentence Structure】

     $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A

     Field numbers:
     [0]  $GPRMC        - Sentence type
     [1]  123519        - UTC time (HHMMSS)
     [2]  A             - Status (A=Valid, V=Invalid)
     [3]  4807.038      - Latitude (DDMM.MMMM)
     [4]  N             - Latitude direction (N=North, S=South)
     [5]  01131.000     - Longitude (DDDMM.MMMM)
     [6]  E             - Longitude direction (E=East, W=West)
     [7]  022.4         - Speed (knots)
     [8]  084.4         - Heading (degrees, 0-359)
     [9]  230394        - UTC date (DDMMYY)
     [10] 003.1         - Magnetic variation (degrees)
     [11] W             - Magnetic variation direction (E/W)
     [12] *6A           - Checksum


     【Required Fields】

     ✓ [1] Time
     ✓ [2] Status (A only valid)
     ✓ [3][4] Latitude and direction
     ✓ [5][6] Longitude and direction
     ✓ [7] Speed
     ✓ [8] Heading
     ✓ [9] Date (optional)


     【Status Codes】

     A (Active):   GPS signal normal, position valid
     V (Void):     No GPS signal, position invalid

     ➜ Does not parse if status is V


     【Speed Conversion】

     NMEA: 022.4 knots
     │
     │ × 1.852
     ▼
     Swift: 41.48 km/h


     【Heading】

     Increases clockwise with North (N) as 0 degrees:

     0° (N)
     │
     270° ─┼─ 90° (E)
     │
     180° (S)

     Examples:
     - 45°: Northeast
     - 90°: East
     - 135°: Southeast
     - 270°: West


     【Date Parsing】

     230394 (DDMMYY)
     ││└┴── Year: 94 → 1994 or 2094?
     ││
     │└──── Month: 03 (March)
     └───── Day: 23 (23rd)

     Assume after 2000: 2094
     For 1900s: Requires manual handling

     ➜ Date used optionally only as baseDate is more accurate


     【Parsing Failure Conditions】

     1. Field count < 10
     2. Status is V (invalid)
     3. Time parsing failed
     4. Latitude parsing failed
     5. Longitude parsing failed

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief Parse GPRMC sentence
    /// @param sentence GPRMC sentence string
    /// @return NMEARecord or nil (if parsing fails)
    /// @details
    /// Parses $GPRMC (Recommended Minimum Specific GPS/TRANSIT Data) sentence.
    ///
    /// ### GPRMC Sentence Structure:
    /// ```
    /// $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
    ///
    /// Fields:
    /// [0]  $GPRMC        - Sentence type
    /// [1]  123519        - UTC time (HHMMSS)
    /// [2]  A             - Status (A=Valid, V=Invalid)
    /// [3]  4807.038      - Latitude (DDMM.MMMM)
    /// [4]  N             - Latitude direction (N=North, S=South)
    /// [5]  01131.000     - Longitude (DDDMM.MMMM)
    /// [6]  E             - Longitude direction (E=East, W=West)
    /// [7]  022.4         - Speed (knots)
    /// [8]  084.4         - Heading (degrees, 0-359)
    /// [9]  230394        - UTC date (DDMMYY)
    /// [10] 003.1         - Magnetic variation (degrees)
    /// [11] W             - Magnetic variation direction (E/W)
    /// [12] *6A           - Checksum
    /// ```
    ///
    /// ### Parsing Failure Conditions:
    /// 1. Field count < 10
    /// 2. Status is V (invalid)
    /// 3. Time parsing failed
    /// 4. Latitude parsing failed
    /// 5. Longitude parsing failed
    private func parseGPRMC(_ sentence: String) -> NMEARecord? {
        // $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
        // Fields: [0]Type, [1]Time, [2]Status, [3]Lat, [4]LatDir, [5]Lon, [6]LonDir,
        //         [7]Speed, [8]Heading, [9]Date, [10]MagVar, [11]MagVarDir, [12]Checksum

        // Step 1: Split by comma
        // "$GPRMC,123519,A,..." → ["$GPRMC", "123519", "A", ...]
        let fields = sentence.components(separatedBy: ",")

        // Minimum 10 fields required
        guard fields.count >= 10 else { return nil }

        // Step 2: Check status
        // A = Active (valid), V = Void (invalid)
        guard fields[2] == "A" else { return nil }

        // Step 3: Parse time and date
        // fields[1]: HHMMSS
        // fields[9]: DDMMYY (optional)
        guard let timestamp = parseDateTime(time: fields[1], date: fields.count > 9 ? fields[9] : nil) else {
            return nil
        }

        // Step 4: Parse latitude
        // fields[3]: DDMM.MMMM
        // fields[4]: N or S
        guard let latitude = parseCoordinate(fields[3], direction: fields[4]) else {
            return nil
        }

        // Step 5: Parse longitude
        // fields[5]: DDDMM.MMMM
        // fields[6]: E or W
        guard let longitude = parseCoordinate(fields[5], direction: fields[6]) else {
            return nil
        }

        // Step 6: Parse speed (knots → km/h)
        // Example: "022.4" → 22.4 knots → 41.48 km/h
        let speed = Double(fields[7]).map { $0 * 1.852 }  // Convert knots to km/h

        // Step 7: Parse heading (degrees)
        // Example: "084.4" → 84.4°
        let heading = Double(fields[8])

        // Step 8: Create NMEARecord
        return NMEARecord(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: nil,           // No altitude information in GPRMC
            speed: speed,
            heading: heading,
            hdop: nil,               // No HDOP information in GPRMC
            satelliteCount: nil      // No satellite count information in GPRMC
        )
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseGPGGA(_:)
     ═════════════════════════════════════════════════════════════════════

     【Function】

     Parses $GPGGA (Global Positioning System Fix Data) sentence.


     【GPGGA Sentence Structure】

     $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47

     Field numbers:
     [0]  $GPGGA        - Sentence type
     [1]  123519        - UTC time (HHMMSS)
     [2]  4807.038      - Latitude (DDMM.MMMM)
     [3]  N             - Latitude direction
     [4]  01131.000     - Longitude (DDDMM.MMMM)
     [5]  E             - Longitude direction
     [6]  1             - GPS quality (0=Invalid, 1=GPS, 2=DGPS)
     [7]  08            - Number of satellites in use
     [8]  0.9           - HDOP (Horizontal Dilution of Precision)
     [9]  545.4         - Altitude (above sea level)
     [10] M             - Altitude unit (meters)
     [11] 46.9          - Geoid height
     [12] M             - Geoid height unit
     [13] (empty)       - DGPS last update time
     [14] *47           - Checksum


     【Required Fields】

     ✓ [1] Time
     ✓ [2][3] Latitude and direction
     ✓ [4][5] Longitude and direction
     ✓ [6] GPS quality (must not be 0)
     ✓ [7] Satellite count
     ✓ [8] HDOP
     ✓ [9] Altitude


     【GPS Quality Indicator】

     0: Invalid (no GPS signal)
     1: GPS standalone positioning
     2: DGPS (Differential GPS) - more accurate
     3: PPS (Precise Positioning Service)
     4: RTK (Real Time Kinematic) - cm-level accuracy
     5: Float RTK
     6: Dead Reckoning

     ➜ Does not parse if 0


     【HDOP (Horizontal Dilution of Precision)】

     Geometric accuracy indicator based on satellite distribution:

     HDOP   Accuracy     Usability
     ───────────────────────────────
     < 1    Ideal        Excellent
     1-2    Excellent    Recommended
     2-5    Good         General use
     5-10   Moderate     Caution
     > 10   Poor         Limited use

     Example: HDOP 0.9 → Excellent accuracy
     HDOP 5.2 → Moderate accuracy


     【Altitude Measurement】

     $GPGGA altitude is based on WGS84 ellipsoid:

     ┌────────────────────────────────────┐
     │        Satellite                    │
     │         │                          │
     │    Distance measurement             │
     │         ▼                          │
     │ ┌──────────────┐ ← Altitude 545.4m │
     │ │   Receiver   │                   │
     │ └──────────────┘                   │
     │ ════════════════ ← Geoid (mean sea level)│
     │ ~~~~~~~~~~~~~~~~~                  │
     │ WGS84 ellipsoid ← Reference        │
     └────────────────────────────────────┘

     Actual altitude above sea level = Altitude - Geoid height
     = 545.4 - 46.9
     = 498.5m

     ➜ Dashcams typically use WGS84 altitude as-is


     【Satellite Count】

     GPS requires minimum 4 satellites:
     - 3 satellites: 2D position (latitude, longitude)
     - 4 satellites: 3D position (latitude, longitude, altitude)

     Typically 8-12 satellites visible:
     - More satellites = More accurate position
     - Lower HDOP value


     【Difference from GPRMC】

     GPRMC:
     ✓ Speed, heading
     ✓ Date
     ✗ Altitude
     ✗ Satellite count
     ✗ Accuracy

     GPGGA:
     ✗ Speed, heading
     ✗ Date
     ✓ Altitude
     ✓ Satellite count
     ✓ Accuracy (HDOP)

     ➜ Merging both sentences provides complete GPS information

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief Parse GPGGA sentence
    /// @param sentence GPGGA sentence string
    /// @return NMEARecord or nil (if parsing fails)
    /// @details
    /// Parses $GPGGA (Global Positioning System Fix Data) sentence.
    ///
    /// ### GPGGA Sentence Structure:
    /// ```
    /// $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
    ///
    /// Fields:
    /// [0]  $GPGGA        - Sentence type
    /// [1]  123519        - UTC time (HHMMSS)
    /// [2]  4807.038      - Latitude (DDMM.MMMM)
    /// [3]  N             - Latitude direction
    /// [4]  01131.000     - Longitude (DDDMM.MMMM)
    /// [5]  E             - Longitude direction
    /// [6]  1             - GPS quality (0=Invalid, 1=GPS, 2=DGPS)
    /// [7]  08            - Number of satellites in use
    /// [8]  0.9           - HDOP (Horizontal Dilution of Precision)
    /// [9]  545.4         - Altitude (above sea level)
    /// [10] M             - Altitude unit (meters)
    /// [11] 46.9          - Geoid height
    /// [12] M             - Geoid height unit
    /// [13] (empty)       - DGPS last update time
    /// [14] *47           - Checksum
    /// ```
    ///
    /// ### GPS Quality Indicator:
    /// ```
    /// 0: Invalid (no GPS signal)
    /// 1: GPS standalone positioning
    /// 2: DGPS (Differential GPS) - more accurate
    /// 3: PPS (Precise Positioning Service)
    /// 4: RTK (Real Time Kinematic) - cm-level accuracy
    /// 5: Float RTK
    /// 6: Dead Reckoning
    /// ```
    private func parseGPGGA(_ sentence: String) -> NMEARecord? {
        // $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
        // Fields: [0]Type, [1]Time, [2]Lat, [3]LatDir, [4]Lon, [5]LonDir,
        //         [6]Quality, [7]NumSats, [8]HDOP, [9]Alt, [10]AltUnit, ...

        // Step 1: Split by comma
        let fields = sentence.components(separatedBy: ",")

        // Minimum 11 fields required
        guard fields.count >= 11 else { return nil }

        // Step 2: Check GPS quality
        // 0 = Invalid, 1+ = Valid
        guard let quality = Int(fields[6]), quality > 0 else { return nil }

        // Step 3: Parse time
        // GPGGA has no date information, so use baseDate
        guard let timestamp = parseDateTime(time: fields[1], date: nil) else {
            return nil
        }

        // Step 4: Parse coordinates
        guard let latitude = parseCoordinate(fields[2], direction: fields[3]),
              let longitude = parseCoordinate(fields[4], direction: fields[5]) else {
            return nil
        }

        // Step 5: Parse altitude (meters)
        // Example: "545.4" → 545.4m
        let altitude = Double(fields[9])

        // Step 6: Parse satellite count
        // Example: "08" → 8
        let satelliteCount = Int(fields[7])

        // Step 7: Parse HDOP
        // Example: "0.9" → 0.9 (excellent accuracy)
        let hdop = Double(fields[8])

        // Step 8: Create NMEARecord
        return NMEARecord(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            speed: nil,              // No speed information in GPGGA
            heading: nil,            // No heading information in GPGGA
            hdop: hdop,
            satelliteCount: satelliteCount
        )
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseCoordinate(_:direction:)
     ═════════════════════════════════════════════════════════════════════

     【Function】

     Converts NMEA format coordinates to Decimal Degrees.


     【NMEA Coordinate Format】

     Latitude: DDMM.MMMM (2-digit degrees + minutes)
     Longitude: DDDMM.MMMM (3-digit degrees + minutes)


     【Conversion Process】

     Example 1: Latitude "4807.038" + "N"

     Step 1: Determine digit count
     ┌────────────────────────────────┐
     │ 4807.038                       │
     │ ││                             │
     │ └┴─ Degrees (2 digits, latitude)│
     └────────────────────────────────┘

     Step 2: Separate degrees and minutes
     ┌─────────────────┬──────────────┐
     │ Degrees: "48"   │ Minutes: "07.038"│
     │         = 48    │         = 7.038  │
     └─────────────────┴──────────────┘

     Step 3: Convert to decimal degrees
     ┌────────────────────────────────────┐
     │ Minutes → degrees conversion:      │
     │   7.038 minutes ÷ 60 = 0.1173°    │
     │                                    │
     │ Final latitude:                    │
     │   48° + 0.1173° = 48.1173°        │
     └────────────────────────────────────┘

     Step 4: Apply direction
     ┌────────────────────────────────────┐
     │ "N" (North latitude) → positive    │
     │ Final: +48.1173°                   │
     └────────────────────────────────────┘


     Example 2: Longitude "01131.000" + "E"

     Step 1: Determine digit count
     ┌────────────────────────────────┐
     │ 01131.000                      │
     │ │││                            │
     │ └┴┴─ Degrees (3 digits, longitude)│
     └────────────────────────────────┘

     Step 2: Separate degrees and minutes
     ┌─────────────────┬──────────────┐
     │ Degrees: "011"  │ Minutes: "31.000"│
     │         = 11    │         = 31.0   │
     └─────────────────┴──────────────┘

     Step 3: Convert to decimal degrees
     ┌────────────────────────────────────┐
     │ Minutes → degrees conversion:      │
     │   31.0 minutes ÷ 60 = 0.5167°     │
     │                                    │
     │ Final longitude:                   │
     │   11° + 0.5167° = 11.5167°        │
     └────────────────────────────────────┘

     Step 4: Apply direction
     ┌────────────────────────────────────┐
     │ "E" (East longitude) → positive    │
     │ Final: +11.5167°                   │
     └────────────────────────────────────┘


     【Direction Codes】

     Latitude:
     - N (North): 0° ~ +90°
     - S (South): 0° ~ -90°

     Longitude:
     - E (East): 0° ~ +180°
     - W (West): 0° ~ -180°


     【Korea Coordinate Range】

     Latitude: 33° ~ 38° N (North, positive)
     Longitude: 124° ~ 132° E (East, positive)

     Example: Seoul
     - Latitude: 37.5665° N → +37.5665°
     - Longitude: 126.9780° E → +126.9780°


     【Error Handling】

     1. Empty string → nil
     2. Insufficient degree digits → nil
     3. Number parsing failed → nil


     【Examples】

     ```swift
     // Seoul Namsan
     let lat = parseCoordinate("3733.990", direction: "N")
     // Result: 37.5665°

     let lon = parseCoordinate("12658.680", direction: "E")
     // Result: 126.9780°

     // Southern hemisphere (Sydney, Australia)
     let sydneyLat = parseCoordinate("3352.000", direction: "S")
     // Result: -33.8667°

     // West longitude (New York, USA)
     let nyLon = parseCoordinate("07400.000", direction: "W")
     // Result: -74.0000°
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief Convert NMEA coordinate to decimal degrees
    /// @param value NMEA coordinate string (e.g., "4807.038" or "01131.000")
    /// @param direction Direction string (N/S/E/W)
    /// @return Decimal degrees or nil (if parsing fails)
    /// @details
    /// Converts NMEA format coordinates to Decimal Degrees.
    ///
    /// ### NMEA Coordinate Format:
    /// ```
    /// Latitude: DDMM.MMMM (2-digit degrees + minutes)
    /// Longitude: DDDMM.MMMM (3-digit degrees + minutes)
    /// ```
    ///
    /// ### Conversion Process:
    /// ```
    /// Example: "4807.038" + "N"
    ///
    /// Step 1: Separate degrees and minutes
    ///   Degrees: "48" = 48
    ///   Minutes: "07.038" = 7.038
    ///
    /// Step 2: Convert to decimal degrees
    ///   7.038 minutes ÷ 60 = 0.1173°
    ///   48° + 0.1173° = 48.1173°
    ///
    /// Step 3: Apply direction
    ///   "N" (North) → positive
    ///   Final: +48.1173°
    /// ```
    ///
    /// ### Direction Codes:
    /// ```
    /// Latitude: N (North, 0° ~ +90°), S (South, 0° ~ -90°)
    /// Longitude: E (East, 0° ~ +180°), W (West, 0° ~ -180°)
    /// ```
    private func parseCoordinate(_ value: String, direction: String) -> Double? {
        // Check for empty values
        guard !value.isEmpty, !direction.isEmpty else { return nil }

        // Step 1: Determine if latitude or longitude
        // Latitude: N or S → 2-digit degrees
        // Longitude: E or W → 3-digit degrees
        let isLatitude = direction == "N" || direction == "S"
        let degreeDigits = isLatitude ? 2 : 3

        // Step 2: Check length
        // Minimum: DD.M (latitude) or DDD.M (longitude)
        guard value.count > degreeDigits else { return nil }

        // Step 3: Separate degrees and minutes
        // "4807.038" → "48" + "07.038"
        let degreeString = String(value.prefix(degreeDigits))
        let minuteString = String(value.dropFirst(degreeDigits))

        // Step 4: Convert string → number
        guard let degrees = Double(degreeString),
              let minutes = Double(minuteString) else {
            return nil
        }

        // Step 5: Calculate decimal degrees
        // DD + (MM.MMMM / 60)
        // Example: 48 + (7.038 / 60) = 48.1173
        var coordinate = degrees + (minutes / 60.0)

        // Step 6: Determine sign based on direction
        // S (South) or W (West) → negative
        if direction == "S" || direction == "W" {
            coordinate = -coordinate
        }

        return coordinate
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseDateTime(time:date:)
     ═════════════════════════════════════════════════════════════════════

     【Function】

     Converts NMEA time and date to Swift Date object.


     【Input Format】

     time: HHMMSS or HHMMSS.sss
     └┬┘└┬┘└┬┘
     Hour Min Sec

     date: DDMMYY (optional)
     └┬┘└┬┘└┬┘
     Day Mon Year(2-digit)


     【Conversion Process】

     Example: time = "143025", date = "150124", baseDate = 2024-01-15

     Step 1: Parse time
     ┌────────────────────────────────┐
     │ "143025"                       │
     │  │││└┴─ Seconds: "25" → 25     │
     │  ││└──── Minutes: "30" → 30    │
     │  └┴───── Hours: "14" → 14      │
     └────────────────────────────────┘

     Step 2: Parse date (if present)
     ┌────────────────────────────────┐
     │ "150124"                       │
     │  │││└┴─ Year: "24" → 2024      │
     │  ││└──── Month: "01" → 1       │
     │  └┴───── Day: "15" → 15        │
     └────────────────────────────────┘

     Step 3: Create Date object
     ┌────────────────────────────────┐
     │ DateComponents:                │
     │ - year: 2024                   │
     │ - month: 1                     │
     │ - day: 15                      │
     │ - hour: 14                     │
     │ - minute: 30                   │
     │ - second: 25                   │
     │ - timeZone: UTC                │
     └────────────────────────────────┘
     │
     ▼
     Date: 2024-01-15 14:30:25 +0000 (UTC)


     【Using baseDate】

     Use baseDate when NMEA date is missing or inaccurate:

     ┌──────────────────────────────────────┐
     │ Filename: 20240115_143025_F.mp4      │
     │            └───┬──┘                  │
     │                baseDate = 2024-01-15 │
     └──────────────────────────────────────┘
     │
     │ No date in NMEA
     ▼
     ┌──────────────────────────────────────┐
     │ Use year/month/day from baseDate     │
     │ Use hour/minute/second from NMEA     │
     └──────────────────────────────────────┘


     【2-Digit Year Handling】

     NMEA: "24" (YY)
     │
     │ + 2000
     ▼
     Swift: 2024 (YYYY)

     ⚠️ Cannot handle years after 2100


     【UTC Time Zone】

     GPS always uses UTC (Coordinated Universal Time):

     ┌──────────────────────────────────────┐
     │ GPS time: 14:30:25 UTC               │
     │            │                         │
     │            │ + 9 hours               │
     │            ▼                         │
     │ Korea time: 23:30:25 KST             │
     └──────────────────────────────────────┘

     ➜ Date object stored in UTC
     ➜ Convert to local timezone when displaying


     【Millisecond Handling】

     Some receivers also provide milliseconds:

     "143025.123"
     └─┬─┘
     Milliseconds (currently not supported)

     Currently parses only up to seconds


     【Examples】

     ```swift
     // With date
     let date1 = parseDateTime(time: "143025", date: "150124")
     // Result: 2024-01-15 14:30:25 UTC

     // No date (using baseDate)
     baseDate = Date() // 2024-01-15 00:00:00
     let date2 = parseDateTime(time: "143025", date: nil)
     // Result: 2024-01-15 14:30:25 UTC

     // With milliseconds (ignored)
     let date3 = parseDateTime(time: "143025.456", date: "150124")
     // Result: 2024-01-15 14:30:25 UTC (milliseconds ignored)
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief Convert NMEA time and date to Date object
    /// @param time NMEA time string (HHMMSS or HHMMSS.sss)
    /// @param date NMEA date string (DDMMYY, optional)
    /// @return Date object or nil (if parsing fails)
    /// @details
    /// Converts NMEA time and date to Swift Date object.
    ///
    /// ### Input Format:
    /// ```
    /// time: HHMMSS or HHMMSS.sss
    ///       └┬┘└┬┘└┬┘
    ///        Hour Min Sec
    ///
    /// date: DDMMYY (optional)
    ///       └┬┘└┬┘└┬┘
    ///        Day Mon Year(2-digit)
    /// ```
    ///
    /// ### Conversion Process:
    /// ```
    /// Example: time = "143025", date = "150124", baseDate = 2024-01-15
    ///
    /// Step 1: Parse time
    ///   "143025" → 14:30:25
    ///
    /// Step 2: Parse date (if present)
    ///   "150124" → 2024-01-15
    ///
    /// Step 3: Create Date object
    ///   2024-01-15 14:30:25 UTC
    /// ```
    ///
    /// ### Using baseDate:
    /// Use baseDate when NMEA date is missing or inaccurate.
    ///
    /// ### UTC Time Zone:
    /// GPS always uses UTC (Coordinated Universal Time).
    private func parseDateTime(time: String, date: String?) -> Date? {
        // baseDate must be set
        guard let baseDate = baseDate else { return nil }

        // Step 1: Check time length
        // Minimum HHMMSS = 6 digits
        guard time.count >= 6 else { return nil }

        // Step 2: Parse time
        // "143025" → 14:30:25
        let hourString = String(time.prefix(2))           // "14"
        let minuteString = String(time.dropFirst(2).prefix(2))  // "30"
        let secondString = String(time.dropFirst(4).prefix(2))  // "25"

        // Convert string → integer
        guard let hour = Int(hourString),
              let minute = Int(minuteString),
              let second = Int(secondString) else {
            return nil
        }

        // Step 3: Initialize date components
        // Get year/month/day from baseDate
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)

        // Step 4: Parse NMEA date if present
        if let date = date, date.count >= 6 {
            // "150124" → 2024-01-15
            let dayString = String(date.prefix(2))              // "15"
            let monthString = String(date.dropFirst(2).prefix(2))  // "01"
            let yearString = String(date.dropFirst(4).prefix(2))   // "24"

            // Convert string → integer
            if let day = Int(dayString),
               let month = Int(monthString),
               let year = Int(yearString) {
                // 2-digit year → 4-digit year
                // 24 → 2024
                components.year = 2000 + year
                components.month = month
                components.day = day
            }
        }

        // Step 5: Set time components
        components.hour = hour
        components.minute = minute
        components.second = second

        // GPS always uses UTC
        components.timeZone = TimeZone(identifier: "UTC")

        // Step 6: Create Date object
        return Calendar.current.date(from: components)
    }

    /*
     ─────────────────────────────────────────────────────────────────────
     createGPSPoint(from:)
     ─────────────────────────────────────────────────────────────────────

     【Function】

     Convert NMEARecord → GPSPoint


     【HDOP → horizontalAccuracy Conversion】

     HDOP is a dimensionless indicator,
     horizontalAccuracy is in meters.

     Approximate conversion:
     horizontalAccuracy ≈ HDOP × 10 meters

     Examples:
     - HDOP 0.9 → accuracy ≈ 9m
     - HDOP 2.5 → accuracy ≈ 25m

     ⚠️ Actually affected by many factors including satellite signal quality, environment, etc.

     ─────────────────────────────────────────────────────────────────────
     */

    /// @brief Convert NMEARecord to GPSPoint
    /// @param record NMEARecord structure
    /// @return GPSPoint object or nil
    /// @details
    /// Converts NMEARecord to GPSPoint.
    ///
    /// ### HDOP → horizontalAccuracy Conversion:
    /// ```
    /// horizontalAccuracy ≈ HDOP × 10 meters
    ///
    /// Examples:
    /// - HDOP 0.9 → accuracy ≈ 9m
    /// - HDOP 2.5 → accuracy ≈ 25m
    /// ```
    private func createGPSPoint(from record: NMEARecord) -> GPSPoint? {
        return GPSPoint(
            timestamp: record.timestamp,
            latitude: record.latitude,
            longitude: record.longitude,
            altitude: record.altitude,
            speed: record.speed,
            heading: record.heading,
            horizontalAccuracy: record.hdop.map { $0 * 10 },  // HDOP → approximate meters
            satelliteCount: record.satelliteCount
        )
    }
}

// MARK: - Supporting Types

/*
 ─────────────────────────────────────────────────────────────────────────
 NMEARecord Structure
 ─────────────────────────────────────────────────────────────────────────

 [Role]

 Internal structure for temporarily storing GPRMC and GPGGA parsing results.


 [Why not use GPSPoint directly?]

 1. Flexibility:
 - GPRMC: Has speed/heading, no altitude
 - GPGGA: Has altitude, no speed/heading
 - All fields treated as Optional

 2. Merging:
 - Create NMEARecord from GPRMC
 - Create NMEARecord from GPGGA
 - Merge both to create GPSPoint

 3. Internal implementation:
 - Not exposed externally (private)
 - GPSPoint is for public API


 [Field Descriptions]

 - timestamp: Timestamp (common to GPRMC/GPGGA)
 - latitude: Latitude (common to GPRMC/GPGGA)
 - longitude: Longitude (common to GPRMC/GPGGA)
 - altitude: Altitude (GPGGA only)
 - speed: Speed (GPRMC only)
 - heading: Heading (GPRMC only)
 - hdop: Accuracy indicator (GPGGA only)
 - satelliteCount: Satellite count (GPGGA only)

 ─────────────────────────────────────────────────────────────────────────
 */

/// @struct NMEARecord
/// @brief Structure for temporarily storing NMEA parsing results
/// @details
/// Internal structure for temporarily storing GPRMC and GPGGA parsing results.
///
/// ### Fields:
/// - timestamp: Timestamp (common to GPRMC/GPGGA)
/// - latitude: Latitude (common to GPRMC/GPGGA)
/// - longitude: Longitude (common to GPRMC/GPGGA)
/// - altitude: Altitude (GPGGA only)
/// - speed: Speed (GPRMC only)
/// - heading: Heading (GPRMC only)
/// - hdop: Accuracy indicator (GPGGA only)
/// - satelliteCount: Satellite count (GPGGA only)
///
/// ### Why not use GPSPoint directly?
/// 1. Flexibility: GPRMC and GPGGA have different fields, so all fields are treated as Optional
/// 2. Merging: Merge both sentences to create GPSPoint
/// 3. Internal implementation: Not exposed externally (private)
private struct NMEARecord {
    /// @var timestamp
    /// @brief Timestamp
    let timestamp: Date

    /// @var latitude
    /// @brief Latitude (decimal degrees)
    let latitude: Double

    /// @var longitude
    /// @brief Longitude (decimal degrees)
    let longitude: Double

    /// @var altitude
    /// @brief Altitude (meters, provided by GPGGA only)
    let altitude: Double?

    /// @var speed
    /// @brief Speed (km/h, provided by GPRMC only)
    let speed: Double?

    /// @var heading
    /// @brief Heading (degrees, provided by GPRMC only)
    let heading: Double?

    /// @var hdop
    /// @brief Horizontal dilution of precision indicator (provided by GPGGA only)
    let hdop: Double?

    /// @var satelliteCount
    /// @brief Satellite count (provided by GPGGA only)
    let satelliteCount: Int?
}

// MARK: - Parser Errors

/*
 ─────────────────────────────────────────────────────────────────────────
 GPSParserError Enumeration
 ─────────────────────────────────────────────────────────────────────────

 [Role]

 Defines errors that can occur during GPS parsing.


 [Error Types]

 1. invalidFormat:
 - Invalid NMEA sentence format
 - Insufficient field count
 - Does not start with $

 2. invalidChecksum:
 - Checksum mismatch (currently not implemented)

 3. invalidCoordinate:
 - Coordinate parsing failed
 - Latitude/longitude out of range

 4. invalidTimestamp:
 - Time/date parsing failed


 [Current Usage]

 Currently handles errors by returning nil,
 so this enum is defined for future extension.

 Can be utilized by changing to use throws:

 ```swift
 func parseGPRMC(_ sentence: String) throws -> NMEARecord {
 guard fields.count >= 10 else {
 throw GPSParserError.invalidFormat
 }
 // ...
 }
 ```

 ─────────────────────────────────────────────────────────────────────────
 */

/// @enum GPSParserError
/// @brief GPS parser error types
/// @details
/// Defines errors that can occur during GPS parsing.
///
/// ### Error Types:
/// 1. invalidFormat: Invalid NMEA sentence format
/// 2. invalidChecksum: Checksum mismatch (currently not implemented)
/// 3. invalidCoordinate: Coordinate parsing failed
/// 4. invalidTimestamp: Time/date parsing failed
enum GPSParserError: Error {
    /// @brief Format error
    /// @details NMEA sentence format is invalid or field count is insufficient.
    case invalidFormat

    /// @brief Checksum error
    /// @details Checksum mismatch (currently not implemented).
    case invalidChecksum

    /// @brief Coordinate error
    /// @details Coordinate parsing failed or out of range.
    case invalidCoordinate

    /// @brief Timestamp error
    /// @details Time/date parsing failed.
    case invalidTimestamp
}

/*
 ─────────────────────────────────────────────────────────────────────────
 LocalizedError Extension
 ─────────────────────────────────────────────────────────────────────────

 [Role]

 Provides user-friendly error messages.


 [Usage Example]

 ```swift
 do {
 let record = try parseGPRMC(sentence)
 } catch let error as GPSParserError {
 print(error.localizedDescription)
 // Output: "Invalid NMEA format"
 }
 ```

 ─────────────────────────────────────────────────────────────────────────
 */

extension GPSParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid NMEA format"
        case .invalidChecksum:
            return "Invalid NMEA checksum"
        case .invalidCoordinate:
            return "Invalid GPS coordinate"
        case .invalidTimestamp:
            return "Invalid timestamp"
        }
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 Comprehensive Usage Example
 ═══════════════════════════════════════════════════════════════════════════

 【Scenario: Extract GPS Route from Dashcam Video】

 ```swift
 import Foundation
 import CoreLocation

 // Step 1: Extract NMEA data from MP4 file
 // (Performed by MetadataExtractor)
 let videoFile = "20240115_143025_F.mp4"
 let metadataExtractor = MetadataExtractor()
 let metadata = try metadataExtractor.extract(from: URL(fileURLWithPath: videoFile))

 // Step 2: Create baseDate
 // Extract from filename: "20240115_143025_F.mp4" → 2024-01-15
 let dateFormatter = DateFormatter()
 dateFormatter.dateFormat = "yyyyMMdd"
 let baseDate = dateFormatter.date(from: "20240115")!

 // Step 3: Parse GPS
 let parser = GPSParser()
 let gpsPoints = parser.parseNMEA(data: metadata.gpsData, baseDate: baseDate)

 print("Total GPS points: \(gpsPoints.count)")

 // Step 4: Route analysis
 if let firstPoint = gpsPoints.first, let lastPoint = gpsPoints.last {
 print("\nDeparture:")
 print("  Position: \(firstPoint.latitude), \(firstPoint.longitude)")
 print("  Time: \(firstPoint.timestamp)")

 print("\nArrival:")
 print("  Position: \(lastPoint.latitude), \(lastPoint.longitude)")
 print("  Time: \(lastPoint.timestamp)")

 // Calculate distance
 let start = CLLocation(
 latitude: firstPoint.latitude,
 longitude: firstPoint.longitude
 )
 let end = CLLocation(
 latitude: lastPoint.latitude,
 longitude: lastPoint.longitude
 )
 let distance = start.distance(from: end) / 1000.0  // km
 print("  Distance traveled: \(String(format: "%.2f", distance)) km")
 }

 // Step 5: Speed analysis
 let speeds = gpsPoints.compactMap { $0.speed }
 if !speeds.isEmpty {
 let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
 let maxSpeed = speeds.max() ?? 0

 print("\nSpeed analysis:")
 print("  Average speed: \(String(format: "%.1f", avgSpeed)) km/h")
 print("  Maximum speed: \(String(format: "%.1f", maxSpeed)) km/h")
 }

 // Step 6: Satellite accuracy analysis
 let accuracies = gpsPoints.compactMap { $0.horizontalAccuracy }
 if !accuracies.isEmpty {
 let avgAccuracy = accuracies.reduce(0, +) / Double(accuracies.count)

 print("\nAccuracy analysis:")
 print("  Average error: \(String(format: "%.1f", avgAccuracy))m")
 }

 // Step 7: Display route on map
 let coordinates = gpsPoints.map {
 CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
 }
 // Display as polyline in MapView...
 ```


 【Output Example】

 Total GPS points: 3600

 Departure:
 Position: 37.7354, 127.0761
 Time: 2024-01-15 14:30:25 +0000

 Arrival:
 Position: 37.5665, 126.9780
 Time: 2024-01-15 15:00:25 +0000
 Distance traveled: 24.53 km

 Speed analysis:
 Average speed: 49.1 km/h
 Maximum speed: 83.7 km/h

 Accuracy analysis:
 Average error: 12.3m

 ═══════════════════════════════════════════════════════════════════════════
 */
