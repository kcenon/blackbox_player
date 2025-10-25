/// @file GPSPoint.swift
/// @brief Blackbox GPS location data model
/// @author BlackboxPlayer Development Team
/// @details Struct representing GPS location data embedded in blackbox videos.
///          Includes latitude, longitude, altitude, speed, heading information and provides CoreLocation compatibility.

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                         GPSPoint Model Overview                          │
 │                                                                          │
 │  A struct representing GPS location data embedded in blackbox videos.   │
 │                                                                          │
 │  【Key Properties】                                                      │
 │  1. timestamp: Measurement time                                          │
 │  2. latitude/longitude: Latitude/Longitude (decimal degrees)             │
 │  3. altitude: Altitude (meters)                                          │
 │  4. speed: Speed (km/h)                                                  │
 │  5. heading: Direction/course (0-360 degrees)                            │
 │  6. horizontalAccuracy: Horizontal accuracy (meters)                     │
 │  7. satelliteCount: Number of satellites                                 │
 │                                                                          │
 │  【Coordinate System】                                                   │
 │                                                                          │
 │  Latitude:                                                               │
 │    -90° (South Pole) ◀─────── 0° (Equator) ────────▶ +90° (North Pole)  │
 │                                                                          │
 │  Longitude:                                                              │
 │    -180° (West) ◀────── 0° (Prime Meridian) ──────▶ +180° (East)        │
 │                                                                          │
 │  Heading:                                                                │
 │              0° (North)                                                  │
 │               │                                                          │
 │        270° ──┼── 90° (East)                                            │
 │               │                                                          │
 │             180° (South)                                                 │
 │                                                                          │
 │  【Data Source】                                                         │
 │                                                                          │
 │  Blackbox SD Card                                                        │
 │      │                                                                   │
 │      ├─ 20250115_100000_F.mp4 (Video)                                   │
 │      └─ 20250115_100000.gps (GPS Data)                                  │
 │           │                                                              │
 │           ├─ $GPRMC (Position, speed, direction)                        │
 │           └─ $GPGGA (Altitude, satellites, accuracy)                    │
 │                │                                                         │
 │                ▼                                                         │
 │           GPSParser                                                      │
 │                │                                                         │
 │                ▼                                                         │
 │           GPSPoint (this struct)                                         │
 │                │                                                         │
 │                ▼                                                         │
 │           MapKit / CoreLocation                                          │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【Struct vs Class Design Decision】

 This model is defined as a struct for the following reasons:

 1. Value Type:
 - GPS data should be immutable
 - Creates completely independent copies when copied
 - No need for reference tracking

 2. Stack Memory:
 - Allocated on the stack, not the heap
 - Faster creation/deallocation
 - No ARC (Automatic Reference Counting) overhead

 3. Thread Safety:
 - Safe for concurrent access from multiple threads
 - Each thread holds an independent copy
 - No synchronization mechanism needed

 Example:
 ```swift
 var point1 = GPSPoint(timestamp: Date(), latitude: 37.5, longitude: 127.0)
 var point2 = point1  // Creates a complete copy

 point2.latitude = 38.0  // ❌ Compile error! (immutable let property)
 // Since struct is a value type, point1 remains unaffected
 ```

 【What is Codable Protocol?】

 Codable = Encodable + Decodable

 A protocol that enables converting Swift objects to external representations
 like JSON, Property List, etc., and vice versa.

 JSON ↔ GPSPoint conversion example:
 ```swift
 // GPSPoint → JSON (Encoding)
 let point = GPSPoint(timestamp: Date(), latitude: 37.5, longitude: 127.0)
 let encoder = JSONEncoder()
 let jsonData = try encoder.encode(point)

 // JSON:
 // {
 //   "timestamp": 1641974400.0,
 //   "latitude": 37.5,
 //   "longitude": 127.0,
 //   "altitude": null,
 //   "speed": null
 // }

 // JSON → GPSPoint (Decoding)
 let decoder = JSONDecoder()
 let decoded = try decoder.decode(GPSPoint.self, from: jsonData)
 ```

 Use cases:
 - Saving/loading GPS data files
 - Network communication
 - UserDefaults storage
 - CloudKit synchronization

 【Equatable & Hashable Protocols】

 Equatable:
 - Compares two GPSPoints for equality (==, !=)
 - Automatically generated: Considered equal if all properties match

 Hashable:
 - Can be used as keys in Set, Dictionary
 - hash() function automatically generated
 - Same values always produce the same hash

 Example:
 ```swift
 let point1 = GPSPoint(timestamp: date1, latitude: 37.5, longitude: 127.0)
 let point2 = GPSPoint(timestamp: date1, latitude: 37.5, longitude: 127.0)

 // Equatable
 if point1 == point2 {
 print("Same location")
 }

 // Hashable
 var uniqueLocations: Set<GPSPoint> = []
 uniqueLocations.insert(point1)
 uniqueLocations.insert(point2)  // Ignored if duplicate
 print("Unique location count: \(uniqueLocations.count)")

 // Using as Dictionary key
 var pointData: [GPSPoint: String] = [:]
 pointData[point1] = "Seoul City Hall"
 ```
 */

import Foundation
import CoreLocation

/*
 【GPSPoint Struct】

 A GPS location data point collected during blackbox recording.

 Data structure:
 - Value type (struct) - Immutability and thread safety
 - Codable - JSON serialization/deserialization
 - Equatable - Comparison operations (==, !=)
 - Hashable - Usable as Set, Dictionary keys
 - Identifiable - For use in SwiftUI Lists

 Usage example:
 ```swift
 // 1. Parse GPS data
 let parser = GPSParser()
 let points = try parser.parseGPSData(from: gpsFileURL)

 // 2. Display on map
 for point in points {
 let annotation = MKPointAnnotation()
 annotation.coordinate = point.coordinate
 mapView.addAnnotation(annotation)
 }

 // 3. Route analysis
 let totalDistance = points.adjacentPairs()
 .map { $0.distance(to: $1) }
 .reduce(0, +)
 print("Total distance: \(totalDistance)m")
 ```
 */
/// @struct GPSPoint
/// @brief Blackbox GPS location data point
/// @details A struct representing GPS location data collected during blackbox recording.
///          Guarantees immutability and thread safety as a value type (struct),
///          and conforms to Codable, Equatable, and Hashable protocols.
struct GPSPoint: Codable, Equatable, Hashable {
    /*
     【Timestamp】

     The time when this GPS measurement was taken.

     Type: Date
     - Swift's standard date/time type
     - UTC based (Coordinated Universal Time)
     - TimeInterval: Seconds elapsed since 1970-01-01 00:00:00 UTC

     Example:
     ```swift
     let point = GPSPoint(timestamp: Date(), ...)

     // Formatting
     let formatter = DateFormatter()
     formatter.dateStyle = .medium
     formatter.timeStyle = .long
     print(formatter.string(from: point.timestamp))
     // "January 15, 2025 at 10:30:45 AM GMT+9"

     // Synchronize with video time
     let videoStart = Date(timeIntervalSince1970: 1641974400)
     let offset = point.timestamp.timeIntervalSince(videoStart)
     print("Video playback time: \(offset) seconds")
     ```

     Uses:
     - Synchronizing video frames with GPS data
     - Time-based filtering (display only routes from specific time periods)
     - Speed calculation (distance / time difference)
     */
    /// @var timestamp
    /// @brief GPS measurement time
    let timestamp: Date

    /*
     【Latitude】

     Coordinates representing north/south latitude.

     Range: -90° ~ +90°
     - +90°: North Pole
     - 0°: Equator
     - -90°: South Pole

     Decimal Degrees:
     - 37.5665° = 37.5665 degrees north latitude
     - 6 decimal places ≈ 0.1 meter precision

     Examples (South Korea):
     - Seoul: 37.5665° (north latitude)
     - Busan: 35.1796° (north latitude)
     - Jeju: 33.4996° (north latitude)

     Conversion:
     ```swift
     // Decimal degrees → DMS (Degrees, Minutes, Seconds)
     let dms = point.dmsString
     // "37°33'59.4\"N"

     // Decimal degrees → Map coordinates
     let coordinate = point.coordinate
     mapView.centerCoordinate = coordinate
     ```

     Notes:
     - Range validation required (use isValid property)
     - Double type provides sufficient precision (approximately 1mm)
     */
    /// @var latitude
    /// @brief Latitude (-90° ~ +90°)
    let latitude: Double

    /*
     【Longitude】

     Coordinates representing east/west longitude.

     Range: -180° ~ +180°
     - 0°: Prime Meridian (Greenwich Observatory, UK)
     - +180°: East (International Date Line)
     - -180°: West (International Date Line)

     Decimal Degrees:
     - 126.9780° = 126.9780 degrees east longitude
     - 6 decimal places ≈ 0.1 meter precision

     Examples (South Korea):
     - Seoul: 126.9780° (east longitude)
     - Busan: 129.0756° (east longitude)
     - Jeju: 126.5312° (east longitude)

     Longitude characteristics:
     - Unlike latitude, distance varies by location
     - At equator: 1° longitude ≈ 111km
     - At 37° north latitude: 1° longitude ≈ 89km
     - At polar regions: 1° longitude ≈ 0km

     Calculation example:
     ```swift
     let seoul = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     let busan = GPSPoint(latitude: 35.1796, longitude: 129.0756, ...)

     let distance = seoul.distance(to: busan)
     print("Seoul-Busan distance: \(distance / 1000)km")  // Approximately 325km
     ```
     */
    /// @var longitude
    /// @brief Longitude (-180° ~ +180°)
    let longitude: Double

    /*
     【Altitude】

     Altitude above sea level in meters.

     Type: Double? (Optional)
     - May not have altitude information if GPS signal is weak
     - Only included in GPGGA sentence (not in GPRMC)

     Range:
     - Negative: Below sea level (e.g., Dead Sea -430m)
     - 0: Sea level
     - Positive: Above sea level

     Accuracy:
     - Lower than horizontal accuracy (approximately 2x worse)
     - Inaccurate between buildings, in tunnels

     Examples (South Korea):
     - Seoul City Hall: 15m
     - N Seoul Tower: 243m
     - Incheon Airport: 7m
     - Mount Baekdu: 2744m

     Usage example:
     ```swift
     if let altitude = point.altitude {
     print("Current altitude: \(Int(altitude))m")

     // Calculate altitude change (climbing/descending)
     let previousAltitude = previousPoint.altitude ?? 0
     let elevationChange = altitude - previousAltitude
     if elevationChange > 0 {
     print("Climbing: +\(elevationChange)m")
     }
     } else {
     print("No altitude information")
     }
     ```
     */
    /// @var altitude
    /// @brief Altitude (meters, optional)
    let altitude: Double?

    /*
     【Speed】

     Travel speed in km/h.

     Type: Double? (Optional)
     - nil when GPS signal is weak or stationary

     Unit conversion:
     - GPS: m/s (meters per second)
     - Blackbox: km/h (kilometers per hour)
     - Conversion: km/h = m/s × 3.6

     Speed in NMEA:
     - Provided in knots in GPRMC sentence
     - 1 knot = 1.852 km/h
     - Conversion: km/h = knots × 1.852

     Accuracy:
     - Small values (0.5~2 km/h) may appear when stationary
     - While moving: ±5% error
     - High-speed travel: More accurate

     Example:
     ```swift
     if let speed = point.speed {
     print("Current speed: \(Int(speed)) km/h")

     // Speeding detection
     if speed > 100 {
     print("⚠️ Speeding warning!")
     }

     // Speed category classification
     switch speed {
     case 0..<5: print("Stopped")
     case 5..<30: print("Low speed")
     case 30..<80: print("Regular road")
     case 80...: print("Highway")
     default: break
     }
     }

     // Calculate average speed
     let avgSpeed = points.compactMap { $0.speed }.reduce(0, +) / Double(points.count)
     print("Average speed: \(Int(avgSpeed)) km/h")
     ```
     */
    /// @var speed
    /// @brief Speed (km/h, optional)
    let speed: Double?

    /*
     【Heading/Course】

     Angle representing the direction of travel.

     Type: Double? (Optional)
     - nil when stationary or GPS signal is weak

     Range: 0° ~ 360°
     - 0° (or 360°): North (N)
     - 90°: East (E)
     - 180°: South (S)
     - 270°: West (W)

     Examples (8 cardinal directions):
     - 0°: North (N)
     - 45°: Northeast (NE)
     - 90°: East (E)
     - 135°: Southeast (SE)
     - 180°: South (S)
     - 225°: Southwest (SW)
     - 270°: West (W)
     - 315°: Northwest (NW)

     Calculation method:
     - Direction of the line connecting previous and current position
     - Can be calculated using bearing(to:) method

     Usage example:
     ```swift
     if let heading = point.heading {
     // Convert to direction string
     let direction: String
     switch heading {
     case 0..<22.5, 337.5...360: direction = "North"
     case 22.5..<67.5: direction = "Northeast"
     case 67.5..<112.5: direction = "East"
     case 112.5..<157.5: direction = "Southeast"
     case 157.5..<202.5: direction = "South"
     case 202.5..<247.5: direction = "Southwest"
     case 247.5..<292.5: direction = "West"
     case 292.5..<337.5: direction = "Northwest"
     default: direction = "Unknown"
     }
     print("Travel direction: \(direction)")

     // Rotate arrow icon (map UI)
     arrowImageView.transform = CGAffineTransform(rotationAngle: heading * .pi / 180)
     }
     ```

     CoreLocation terminology:
     - course: Same meaning as heading
     - bearing: Direction between two points (calculated)
     */
    /// @var heading
    /// @brief Heading/course (0° ~ 360°, north is 0°, optional)
    let heading: Double?

    /*
     【Horizontal Accuracy】

     GPS position error range in meters.

     Type: Double? (Optional)
     - nil if no GPS signal

     Meaning:
     - 68% probability (1σ) that actual position is within this radius
     - Example: 5m → 68% probability actual position is within 5m radius

     Accuracy grades:
     - < 5m: Very accurate (can identify buildings)
     - 5-10m: Accurate (can identify roads)
     - 10-50m: Moderate (can identify blocks/areas)
     - > 50m: Inaccurate (weak GPS signal)

     Influencing factors:
     1. Satellite count (more satellites = more accurate)
     2. Buildings/terrain (more open sky = more accurate)
     3. Weather (clearer = more accurate)
     4. Ionosphere conditions

     In NMEA:
     - HDOP (Horizontal Dilution of Precision) from GPGGA sentence
     - horizontalAccuracy ≈ HDOP × 10 (approximate conversion)

     Usage example:
     ```swift
     if let accuracy = point.horizontalAccuracy {
     print("Position accuracy: ±\(Int(accuracy))m")

     // Accuracy filtering
     if accuracy > 50 {
     print("⚠️ Weak GPS signal. Position may be inaccurate")
     // Ignore this data point or change display method
     }

     // Display accuracy circle on map
     let circle = MKCircle(center: point.coordinate, radius: accuracy)
     mapView.addOverlay(circle)
     }

     // Filter only accurate points
     let accuratePoints = allPoints.filter {
     guard let acc = $0.horizontalAccuracy else { return false }
     return acc < 20  // Only within 20m
     }
     ```

     CoreLocation:
     - Same as CLLocation.horizontalAccuracy
     - -1 means invalid value
     */
    /// @var horizontalAccuracy
    /// @brief Horizontal accuracy (meters, optional)
    let horizontalAccuracy: Double?

    /*
     【Satellite Count】

     Number of GPS satellites used for position calculation.

     Type: Int? (Optional)
     - May not be included in NMEA data

     Minimum requirements:
     - 3D position (latitude, longitude, altitude): Minimum 4 satellites
     - 2D position (latitude, longitude only): Minimum 3 satellites

     Satellite count and accuracy:
     - 4: Minimum requirement (low accuracy)
     - 6-8: Typical (moderate accuracy)
     - 8-12: Good (high accuracy)
     - 12+: Very good (very high accuracy)

     Satellite types:
     - GPS (USA): 24-32 operational
     - GLONASS (Russia)
     - Galileo (Europe)
     - BeiDou (China)
     - Modern receivers use multiple systems simultaneously

     Usage example:
     ```swift
     if let satellites = point.satelliteCount {
     print("Satellites in use: \(satellites)")

     // Signal strength display
     let signalBars: Int
     switch satellites {
     case 0..<4: signalBars = 1  // Weak
     case 4..<6: signalBars = 2  // Moderate
     case 6..<8: signalBars = 3  // Good
     case 8...: signalBars = 4   // Very good
     default: signalBars = 0
     }
     print("Signal: \(String(repeating: "█", count: signalBars))")

     // Tunnel entry detection
     if satellites < 4 {
     print("⚠️ Weak GPS signal (may be in tunnel/underground)")
     }
     }
     ```

     In NMEA:
     - Included in GPGGA sentence
     - Example: $GPGGA,...,08,...  → 8 satellites in use
     */
    /// @var satelliteCount
    /// @brief Number of satellites used (optional)
    let satelliteCount: Int?

    // MARK: - Initialization

    /*
     【Initialization Method】

     Creates a GPSPoint instance.

     Required parameters:
     - timestamp: Measurement time
     - latitude: Latitude (-90 ~ 90)
     - longitude: Longitude (-180 ~ 180)

     Optional parameters (default nil):
     - altitude: Altitude
     - speed: Speed
     - heading: Direction
     - horizontalAccuracy: Accuracy
     - satelliteCount: Satellite count

     Default value pattern:
     ```swift
     func foo(required: Int, optional: String? = nil) { }

     foo(required: 1)  // optional is nil
     foo(required: 1, optional: "value")  // optional is "value"
     ```

     Usage example:
     ```swift
     // Minimal information only (latitude/longitude)
     let point1 = GPSPoint(
     timestamp: Date(),
     latitude: 37.5665,
     longitude: 126.9780
     )

     // Including all information
     let point2 = GPSPoint(
     timestamp: Date(),
     latitude: 37.5665,
     longitude: 126.9780,
     altitude: 15.0,
     speed: 45.0,
     heading: 90.0,
     horizontalAccuracy: 5.0,
     satelliteCount: 8
     )

     // Created during parsing (from NMEA data)
     let point3 = GPSPoint(
     timestamp: baseDate.addingTimeInterval(timeOffset),
     latitude: parsedLat,
     longitude: parsedLon,
     altitude: gpgga?.altitude,  // Only in GPGGA
     speed: gprmc?.speed,  // Only in GPRMC
     heading: gprmc?.heading,
     horizontalAccuracy: gpgga?.horizontalAccuracy,
     satelliteCount: gpgga?.satelliteCount
     )
     ```

     Struct initialization features:
     - Memberwise initializer automatically generated
     - Takes all properties as parameters
     - Can specify default values
     */
    /// @brief Initialize GPSPoint instance
    /// @param timestamp GPS measurement time
    /// @param latitude Latitude (-90 ~ 90)
    /// @param longitude Longitude (-180 ~ 180)
    /// @param altitude Altitude (meters, default: nil)
    /// @param speed Speed (km/h, default: nil)
    /// @param heading Direction (0-360 degrees, default: nil)
    /// @param horizontalAccuracy Horizontal accuracy (meters, default: nil)
    /// @param satelliteCount Satellite count (default: nil)
    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        speed: Double? = nil,
        heading: Double? = nil,
        horizontalAccuracy: Double? = nil,
        satelliteCount: Int? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
        self.heading = heading
        self.horizontalAccuracy = horizontalAccuracy
        self.satelliteCount = satelliteCount
    }

    // MARK: - CoreLocation Interop

    /*
     【CoreLocation Compatibility - Coordinate Conversion】

     Converts GPSPoint to Apple's CoreLocation framework types.

     CLLocationCoordinate2D:
     - Basic coordinate type used in MapKit
     - Contains only latitude/longitude (no altitude, speed, etc.)
     - Lightweight struct (16 bytes)

     Usage example:
     ```swift
     let point = GPSPoint(timestamp: Date(), latitude: 37.5, longitude: 127.0)

     // Move map center
     let coordinate = point.coordinate
     mapView.centerCoordinate = coordinate

     // Add annotation
     let annotation = MKPointAnnotation()
     annotation.coordinate = point.coordinate
     annotation.title = "Accident location"
     mapView.addAnnotation(annotation)

     // Draw polyline (route)
     let coordinates = gpsPoints.map { $0.coordinate }
     let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
     mapView.addOverlay(polyline)
     ```

     Type definition:
     ```swift
     struct CLLocationCoordinate2D {
     var latitude: CLLocationDegrees  // typealias for Double
     var longitude: CLLocationDegrees
     }
     ```
     */
    /// @brief Convert to CLLocationCoordinate2D for MapKit
    /// @return CLLocationCoordinate2D coordinate object
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /*
     【CoreLocation Compatibility - Complete Location Information】

     Converts GPSPoint to CLLocation.

     CLLocation:
     - Main location type in CoreLocation
     - Includes not only latitude/longitude but also altitude, speed, accuracy, etc.
     - Provides distance calculation methods (distance(from:))

     Conversion details:
     1. altitude: Set to 0 if nil
     2. horizontalAccuracy: Set to -1 if nil (invalid)
     3. verticalAccuracy: -1 (no altitude accuracy information)
     4. course: Uses heading value, -1 if nil
     5. speed: km/h → m/s conversion (÷ 3.6)

     Usage example:
     ```swift
     let point = GPSPoint(...)
     let location = point.clLocation

     // Calculate distance
     let distance = location.distance(from: previousLocation)
     print("Distance traveled: \(distance)m")

     // Simulate location update (for testing)
     locationManager.delegate?.locationManager?(
     locationManager,
     didUpdateLocations: [location]
     )

     // Geocoding (address conversion)
     let geocoder = CLGeocoder()
     geocoder.reverseGeocodeLocation(location) { placemarks, error in
     if let placemark = placemarks?.first {
     print("Address: \(placemark.name ?? "")")
     print("City: \(placemark.locality ?? "")")
     }
     }
     ```

     Speed unit conversion:
     - GPSPoint: km/h (kilometers per hour)
     - CLLocation: m/s (meters per second)
     - Conversion: m/s = km/h ÷ 3.6

     Examples:
     - 90 km/h ÷ 3.6 = 25 m/s
     - 36 km/h ÷ 3.6 = 10 m/s
     */
    /// @brief Convert to CLLocation object with complete location information
    /// @return CLLocation object
    var clLocation: CLLocation {
        return CLLocation(
            coordinate: coordinate,  // CLLocationCoordinate2D
            altitude: altitude ?? 0,  // 0 (sea level) if no altitude info
            horizontalAccuracy: horizontalAccuracy ?? -1,  // -1 means invalid
            verticalAccuracy: -1,  // No altitude accuracy info (vertical accuracy)
            course: heading ?? -1,  // Travel direction, -1 means invalid
            speed: (speed ?? 0) / 3.6,  // km/h → m/s conversion
            timestamp: timestamp  // Measurement time
        )
    }

    /*
     【Create from CLLocation】

     Creates a GPSPoint from a CoreLocation CLLocation object.

     Conversion details:
     1. speed: m/s → km/h conversion (× 3.6)
     2. course: nil if -1 (invalid)
     3. horizontalAccuracy: nil if -1
     4. satelliteCount: CLLocation doesn't have this info → nil

     Use cases:
     ```swift
     // 1. Real-time location tracking
     func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
     guard let location = locations.last else { return }

     let point = GPSPoint.from(location)
     self.gpsPoints.append(point)
     print("Current location: \(point.decimalString)")
     }

     // 2. Generate simulation data
     let simulatedLocation = CLLocation(
     latitude: 37.5665,
     longitude: 126.9780
     )
     let point = GPSPoint.from(simulatedLocation)

     // 3. Convert test data
     let testLocations = [CLLocation(...), CLLocation(...)]
     let gpsPoints = testLocations.map { GPSPoint.from($0) }
     ```

     course vs heading:
     - course: CLLocation terminology
     - heading: GPSPoint terminology
     - Same concept (travel direction angle)

     Parameters:
     - location: CoreLocation CLLocation object

     Return value:
     - GPSPoint: Converted GPS point
     */
    /// @brief Create GPSPoint from CLLocation
    /// @param location CoreLocation CLLocation object
    /// @return GPSPoint instance
    static func from(_ location: CLLocation) -> GPSPoint {
        return GPSPoint(
            timestamp: location.timestamp,  // Measurement time
            latitude: location.coordinate.latitude,  // Latitude
            longitude: location.coordinate.longitude,  // Longitude
            altitude: location.altitude,  // Altitude (always provided, may be 0)
            speed: location.speed * 3.6,  // m/s → km/h conversion
            heading: location.course >= 0 ? location.course : nil,  // nil if -1
            horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,  // nil if -1
            satelliteCount: nil  // CLLocation doesn't have satellite count information
        )
    }

    // MARK: - Validation

    /*
     【Coordinate Validity Check】

     Verifies that latitude/longitude values are within valid ranges.

     Valid ranges:
     - Latitude: -90° ~ +90°
     - Longitude: -180° ~ +180°

     Invalid value examples:
     - Latitude 91°: Beyond North Pole
     - Longitude -181°: Out of range
     - Latitude NaN: Calculation error

     Usage example:
     ```swift
     let points = try parser.parseGPSData(from: fileURL)

     // Filter only valid points
     let validPoints = points.filter { $0.isValid }
     print("Total: \(points.count), Valid: \(validPoints.count)")

     // Process after validation
     for point in points {
     guard point.isValid else {
     print("⚠️ Invalid GPS data: \(point)")
     continue
     }

     // Display on map
     addAnnotation(for: point)
     }

     // Log invalid data
     let invalidPoints = points.filter { !$0.isValid }
     if !invalidPoints.isEmpty {
     print("⚠️ Found \(invalidPoints.count) invalid GPS points")
     for point in invalidPoints {
     print("  - Lat: \(point.latitude), Lon: \(point.longitude)")
     }
     }
     ```

     Why is this needed?
     - NMEA parsing errors can generate incorrect values
     - Corrupted GPS files
     - Uninitialized values (0, 0)
     - Calculation errors (NaN, Infinity)
     */
    /// @brief Validate coordinate
    /// @return true if coordinates are within valid range
    var isValid: Bool {
        return latitude >= -90 && latitude <= 90 &&  // Check latitude range
            longitude >= -180 && longitude <= 180  // Check longitude range
    }

    /*
     【GPS Signal Strength Check】

     Determines if GPS signal is strong based on position accuracy and satellite count.

     Criteria:
     1. horizontalAccuracy > 50m → Weak signal
     2. satelliteCount < 4 → Weak signal
     3. Both pass → Strong signal

     Accuracy threshold (50m):
     - < 50m: Road-level accuracy (good signal)
     - > 50m: Block-level accuracy (weak signal)

     Satellite count threshold (4):
     - < 4: 3D position impossible
     - >= 4: 3D position possible (latitude, longitude, altitude)

     Usage example:
     ```swift
     // Filter by signal strength
     let strongSignalPoints = allPoints.filter { $0.hasStrongSignal }
     print("Strong signal: \(strongSignalPoints.count) / \(allPoints.count)")

     // UI display
     for point in allPoints {
     let color: NSColor = point.hasStrongSignal ? .systemGreen : .systemRed
     let annotation = ColoredAnnotation(coordinate: point.coordinate, color: color)
     mapView.addAnnotation(annotation)
     }

     // Warning message
     if !point.hasStrongSignal {
     statusLabel.stringValue = "⚠️ Weak GPS signal"
     statusLabel.textColor = .systemOrange

     // Display reasons for weak signal
     var reasons: [String] = []
     if let acc = point.horizontalAccuracy, acc > 50 {
     reasons.append("Low accuracy (±\(Int(acc))m)")
     }
     if let sats = point.satelliteCount, sats < 4 {
     reasons.append("Insufficient satellites (\(sats))")
     }
     print("Weak signal reasons: \(reasons.joined(separator: ", "))")
     }

     // Tunnel entry/exit detection
     if previousPoint.hasStrongSignal && !currentPoint.hasStrongSignal {
     print("Tunnel entry detected")
     tunnelEntered = true
     } else if !previousPoint.hasStrongSignal && currentPoint.hasStrongSignal {
     print("Tunnel exit detected")
     tunnelEntered = false
     }
     ```

     nil handling:
     - If accuracy or satelliteCount is nil, ignore that condition
     - If at least one exists, judge based on that criterion
     - If both are nil, return true (conservative approach)
     */
    /// @brief Check GPS signal strength
    /// @return true if signal is strong based on accuracy and satellite count
    var hasStrongSignal: Bool {
        // Check accuracy (must be 50m or less)
        if let accuracy = horizontalAccuracy, accuracy > 50 {
            return false  // Low accuracy → Weak signal
        }
        // Check satellite count (must be 4 or more)
        if let satellites = satelliteCount, satellites < 4 {
            return false  // Insufficient satellites → Weak signal
        }
        return true  // All conditions passed → Strong signal
    }

    // MARK: - Calculations

    /*
     【Distance Calculation】

     Calculates straight-line distance to another GPS point in meters.

     Calculation method:
     - Uses CoreLocation's distance(from:) method
     - Based on Haversine formula (spherical distance)
     - Assumes Earth is a perfect sphere

     Haversine formula:
     ```
     a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
     c = 2 × atan2(√a, √(1−a))
     d = R × c
     ```
     where:
     - R = Earth's radius (6,371km)
     - Δlat = lat2 - lat1
     - Δlon = lon2 - lon1

     Accuracy:
     - Short distance (< 100km): Very accurate
     - Long distance (> 1000km): Slight error (Earth is not a perfect sphere)
     - Error: < 0.3% (sufficiently practical)

     Usage example:
     ```swift
     let seoul = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     let busan = GPSPoint(latitude: 35.1796, longitude: 129.0756, ...)

     // Calculate distance
     let distance = seoul.distance(to: busan)
     print("Seoul-Busan: \(Int(distance / 1000))km")  // Approximately 325km

     // Calculate total route distance
     var totalDistance = 0.0
     for i in 0..<(gpsPoints.count - 1) {
     let current = gpsPoints[i]
     let next = gpsPoints[i + 1]
     totalDistance += current.distance(to: next)
     }
     print("Total distance traveled: \(Int(totalDistance / 1000))km")

     // Find nearby points
     let nearbyPoints = allPoints.filter { point in
     point.distance(to: currentPoint) < 100  // Within 100m
     }

     // Verify speed
     let timeDiff = next.timestamp.timeIntervalSince(current.timestamp)
     let distance = current.distance(to: next)
     let calculatedSpeed = (distance / timeDiff) * 3.6  // m/s → km/h
     if let gpsSpeed = next.speed {
     let speedDiff = abs(calculatedSpeed - gpsSpeed)
     if speedDiff > 10 {
     print("⚠️ Speed mismatch: GPS=\(gpsSpeed), calculated=\(calculatedSpeed)")
     }
     }
     ```

     Parameters:
     - other: Destination GPS point

     Return value:
     - Double: Distance (in meters)
     */
    /// @brief Calculate distance to another GPS point
    /// @param other Destination GPS point
    /// @return Distance (meters)
    func distance(to other: GPSPoint) -> Double {
        let location1 = clLocation  // Convert to CLLocation
        let location2 = other.clLocation  // Convert to CLLocation
        return location1.distance(from: location2)  // Use CoreLocation's distance calculation method
    }

    /*
     【Bearing Calculation】

     Calculates the bearing to another GPS point.

     Bearing:
     - Direction from current position looking toward destination
     - Measured clockwise from north as 0°
     - Range: 0° ~ 360°

     Calculation formula:
     ```
     y = sin(Δlon) × cos(lat2)
     x = cos(lat1) × sin(lat2) - sin(lat1) × cos(lat2) × cos(Δlon)
     bearing = atan2(y, x)
     ```

     atan2 function:
     - Four-quadrant version of arctangent function
     - atan2(y, x) = angle of point (x, y)
     - Range: -π ~ +π (radians)
     - Add 360° to negative values to convert to 0° ~ 360° range

     Examples (from Seoul):
     - Busan: Approximately 115° (southeast)
     - Incheon: Approximately 270° (west)
     - Gangneung: Approximately 85° (east)

     Usage example:
     ```swift
     let current = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     let destination = GPSPoint(latitude: 35.1796, longitude: 129.0756, ...)

     // Calculate bearing
     let bearing = current.bearing(to: destination)
     print("Busan direction: \(Int(bearing))° (southeast)")

     // Convert to direction string
     func directionString(from bearing: Double) -> String {
     switch bearing {
     case 0..<22.5, 337.5...360: return "North"
     case 22.5..<67.5: return "Northeast"
     case 67.5..<112.5: return "East"
     case 112.5..<157.5: return "Southeast"
     case 157.5..<202.5: return "South"
     case 202.5..<247.5: return "Southwest"
     case 247.5..<292.5: return "West"
     case 292.5..<337.5: return "Northwest"
     default: return "?"
     }
     }
     print("Direction: \(directionString(from: bearing))")

     // Rotate UI arrow (point to destination)
     let angle = bearing * .pi / 180  // Degrees → radians
     arrowImageView.transform = CGAffineTransform(rotationAngle: angle)

     // Check route deviation (navigation)
     if let currentHeading = current.heading {
     let deviation = bearing - currentHeading
     if abs(deviation) > 15 {
     print("Off route! Direction correction needed: \(Int(deviation))°")
     }
     }

     // Turn direction guidance
     if let currentHeading = current.heading {
     let turnAngle = bearing - currentHeading
     if turnAngle > 10 {
     print("Turn right recommended")
     } else if turnAngle < -10 {
     print("Turn left recommended")
     } else {
     print("Go straight")
     }
     }
     ```

     Radians ↔ Degrees conversion:
     - Radians → Degrees: × 180 / π
     - Degrees → Radians: × π / 180

     truncatingRemainder(dividingBy:):
     - Remainder operator (modulo)
     - (bearing + 360) % 360
     - Converts negative to positive range (0~360)
     */
    /// @brief Calculate bearing to another GPS point
    /// @param other Destination GPS point
    /// @return Bearing (0-360 degrees)
    func bearing(to other: GPSPoint) -> Double {
        // Convert latitude/longitude to radians
        let lat1 = latitude * .pi / 180  // Current latitude (radians)
        let lon1 = longitude * .pi / 180  // Current longitude (radians)
        let lat2 = other.latitude * .pi / 180  // Destination latitude (radians)
        let lon2 = other.longitude * .pi / 180  // Destination longitude (radians)

        let dLon = lon2 - lon1  // Longitude difference

        // Calculate bearing (Haversine formula)
        let y = sin(dLon) * cos(lat2)  // y coordinate
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)  // x coordinate

        let bearing = atan2(y, x) * 180 / .pi  // Calculate angle with atan2, radians → degrees
        return (bearing + 360).truncatingRemainder(dividingBy: 360)  // -180~180 → 0~360 conversion
    }

    // MARK: - Formatting

    /*
     【DMS Format String】

     Converts latitude/longitude to Degrees, Minutes, Seconds (DMS) format.

     DMS format:
     - Degrees: 0° ~ 90° (latitude), 0° ~ 180° (longitude)
     - Minutes: 0' ~ 59'
     - Seconds: 0" ~ 59.9"

     Conversion method:
     ```
     Decimal: 37.5665°

     1. Degrees = integer part = 37°
     2. Minutes decimal = (0.5665 × 60) = 33.99
     3. Minutes = integer part = 33'
     4. Seconds = (0.99 × 60) = 59.4"

     Result: 37°33'59.4"N
     ```

     Direction indicators:
     - North (N): latitude >= 0
     - South (S): latitude < 0
     - East (E): longitude >= 0
     - West (W): longitude < 0

     Usage example:
     ```swift
     let seoul = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     print(seoul.dmsString)
     // "37°33'59.4\"N, 126°58'40.8\"E"

     // UI display
     coordinateLabel.stringValue = point.dmsString

     // Map annotation label
     annotation.subtitle = point.dmsString

     // Copyable format
     let copyText = "Location: \(point.dmsString)"
     NSPasteboard.general.clearContents()
     NSPasteboard.general.setString(copyText, forType: .string)
     ```

     Uses:
     - User-friendly format
     - Standard notation in navigation/aviation
     - Used in Google Maps, etc.

     Decimal vs DMS:
     - Decimal: 37.5665° (convenient for calculations)
     - DMS: 37°33'59.4\"N (easier to read)
     */
    /// @brief Convert latitude/longitude to DMS (Degrees, Minutes, Seconds) format
    /// @return DMS format string
    var dmsString: String {
        // Determine direction
        let latDirection = latitude >= 0 ? "N" : "S"  // North/South
        let lonDirection = longitude >= 0 ? "E" : "W"  // East/West

        // Convert to absolute value (direction shown as character)
        let latDMS = Self.toDMS(abs(latitude))  // Convert latitude to DMS
        let lonDMS = Self.toDMS(abs(longitude))  // Convert longitude to DMS

        // Format: "37°33'59.4"N, 126°58'40.8"E"
        return "\(latDMS)\(latDirection), \(lonDMS)\(lonDirection)"
    }

    /*
     【Decimal Format String】

     Converts latitude/longitude to Decimal Degrees format.

     Decimal degrees:
     - Represents latitude/longitude as decimals
     - Example: 37.566500, 126.978000

     Precision:
     - 6 decimal places: Approximately 0.1m (11cm) precision
     - 5 decimal places: Approximately 1m precision
     - 4 decimal places: Approximately 11m precision

     Usage example:
     ```swift
     let point = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     print(point.decimalString)
     // "37.566500, 126.978000"

     // Generate Google Maps URL
     let url = "https://maps.google.com/maps?q=\(point.decimalString)"
     NSWorkspace.shared.open(URL(string: url)!)

     // CSV file output
     let csvLine = "\(point.timestamp),\(point.decimalString),\(point.altitude ?? 0)"

     // Copy to clipboard
     NSPasteboard.general.setString(point.decimalString, forType: .string)
     ```

     Format:
     - "%6f": 6 decimal places
     - Example: 37.566500 (6 decimal places)
     */
    /// @brief Convert to decimal coordinate string
    /// @return Decimal format string (6 decimal places)
    var decimalString: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    /*
     【Speed String】

     Converts speed to a string in "45.0 km/h" format.

     Return value:
     - String?: "XXX.X km/h" if speed exists, nil otherwise

     Format:
     - "%.1f": 1 decimal place
     - Examples: "45.0 km/h", "120.5 km/h"

     Usage example:
     ```swift
     let point = GPSPoint(..., speed: 45.0, ...)

     // Display speed
     if let speedStr = point.speedString {
     speedLabel.stringValue = speedStr
     } else {
     speedLabel.stringValue = "No speed information"
     }

     // Using nil coalescing operator
     speedLabel.stringValue = point.speedString ?? "N/A"

     // Output speed of multiple points
     for point in gpsPoints {
     if let speedStr = point.speedString {
     print("\(point.timestamp): \(speedStr)")
     }
     }
     ```
     */
    /// @brief Convert speed to string with unit
    /// @return Speed string (e.g. "45.0 km/h"), nil if no speed
    var speedString: String? {
        guard let speed = speed else { return nil }  // nil if no speed
        return String(format: "%.1f km/h", speed)  // Format: "45.0 km/h"
    }

    // MARK: - Private Helpers

    /*
     【Decimal → DMS Conversion (Private)】

     Converts decimal coordinates to DMS (Degrees, Minutes, Seconds) format.

     Parameters:
     - decimal: Decimal coordinate (e.g., 37.5665)

     Return value:
     - String: DMS format string (e.g., "37°33'59.4\"")

     Calculation process:
     ```
     Input: 37.5665

     1. Degrees:
     Int(37.5665) = 37

     2. Minutes decimal:
     (37.5665 - 37.0) × 60 = 0.5665 × 60 = 33.99

     3. Minutes:
     Int(33.99) = 33

     4. Seconds:
     (33.99 - 33.0) × 60 = 0.99 × 60 = 59.4

     Output: "37°33'59.4\""
     ```

     Format:
     - "%d°%d'%.1f\"": degrees°minutes'seconds"
     - Example: "37°33'59.4\""

     Why private?
     - Internal implementation detail
     - Externally use dmsString property
     - Encapsulation: Implementation can be changed
     */
    /// @brief Convert decimal coordinate to DMS format (internal helper)
    /// @param decimal Decimal coordinate value
    /// @return DMS format string
    private static func toDMS(_ decimal: Double) -> String {
        let degrees = Int(decimal)  // Degrees (integer part)
        let minutesDecimal = (decimal - Double(degrees)) * 60  // Minutes decimal
        let minutes = Int(minutesDecimal)  // Minutes (integer part)
        let seconds = (minutesDecimal - Double(minutes)) * 60  // Seconds (remainder × 60)

        return String(format: "%d°%d'%.1f\"", degrees, minutes, seconds)
    }
}

// MARK: - Identifiable

/*
 【Identifiable Protocol Extension】

 Provides unique identifiers for use in SwiftUI List, ForEach, etc.

 Identifiable protocol:
 - Ensures uniqueness of list items in SwiftUI
 - Requires id property (Hashable type)
 - Uses timestamp as id here

 Why use timestamp as id?
 - GPS points are recorded in chronological order
 - No two measurements at the same time
 - Date is Hashable (uniquely identifiable)

 Usage example:
 ```swift
 // SwiftUI List
 List(gpsPoints) { point in
 HStack {
 Text(point.decimalString)
 Spacer()
 if let speed = point.speedString {
 Text(speed)
 }
 }
 }
 // No need to specify id (handled automatically by Identifiable protocol)

 // ForEach
 ForEach(gpsPoints) { point in
 MapAnnotation(coordinate: point.coordinate) {
 Image(systemName: "mappin")
 }
 }

 // Manual id specification (when Identifiable is not used)
 // List(gpsPoints, id: \.timestamp) { point in ... }
 ```

 Identifiable vs id parameter:
 ```swift
 // Using Identifiable (recommended)
 struct GPSPoint: Identifiable {
 var id: Date { timestamp }
 }
 List(points) { point in ... }

 // Using id parameter
 List(points, id: \.timestamp) { point in ... }
 ```
 */
extension GPSPoint: Identifiable {
    var id: Date { timestamp }  // Use timestamp as unique identifier
}

// MARK: - Sample Data

/*
 【Sample Data Extension】

 Provides sample GPS data for testing and SwiftUI previews.

 Usage purposes:
 1. Unit Tests
 2. SwiftUI Previews (Canvas)
 3. Quick testing during development
 4. Documentation examples

 Sample location: Seoul City Hall
 - Latitude: 37.5665°N
 - Longitude: 126.9780°E
 - Central Seoul, well-known location
 */
extension GPSPoint {
    /*
     【Single Sample GPS Point】

     Sample GPS point at Seoul City Hall location.

     Data:
     - Location: Seoul City Hall (37.5665°N, 126.9780°E)
     - Altitude: 15m (above sea level)
     - Speed: 45 km/h
     - Heading: 90° (east)
     - Accuracy: ±5m (very accurate)
     - Satellites: 8 (good signal)

     Usage example:
     ```swift
     // Unit test
     func testDistanceCalculation() {
     let point1 = GPSPoint.sample
     let point2 = GPSPoint(
     timestamp: Date(),
     latitude: 37.5667,
     longitude: 126.9782
     )
     let distance = point1.distance(to: point2)
     XCTAssertEqual(distance, 25, accuracy: 5)  // Approximately 25m ±5m
     }

     // SwiftUI Preview
     struct MapView_Previews: PreviewProvider {
     static var previews: some View {
     MapView(location: GPSPoint.sample)
     }
     }

     // Development testing
     let testPoint = GPSPoint.sample
     print("Sample location: \(testPoint.dmsString)")
     mapView.centerCoordinate = testPoint.coordinate
     ```
     */
    /// Sample GPS point for testing (Seoul City Hall)
    static let sample = GPSPoint(
        timestamp: Date(),  // Current time
        latitude: 37.5665,  // Seoul City Hall latitude
        longitude: 126.9780,  // Seoul City Hall longitude
        altitude: 15.0,  // Altitude 15m
        speed: 45.0,  // Speed 45 km/h
        heading: 90.0,  // Heading east
        horizontalAccuracy: 5.0,  // Accuracy ±5m
        satelliteCount: 8  // 8 satellites
    )

    /*
     【Sample Route (Array)】

     A route consisting of 5 GPS points moving around Seoul City Hall.

     Route characteristics:
     - Moving northeast
     - 1 second intervals
     - Speed increasing (30 → 50 km/h)
     - Direction slightly changing (45° → 50°)
     - Altitude slightly increasing (15m → 17m)

     Distance:
     - Each segment: Approximately 25-30m
     - Total distance: Approximately 100-120m

     Usage example:
     ```swift
     // Route test
     func testRouteDistance() {
     var totalDistance = 0.0
     for i in 0..<(GPSPoint.sampleRoute.count - 1) {
     let current = GPSPoint.sampleRoute[i]
     let next = GPSPoint.sampleRoute[i + 1]
     totalDistance += current.distance(to: next)
     }
     XCTAssertGreaterThan(totalDistance, 100)
     }

     // Draw route on map
     let coordinates = GPSPoint.sampleRoute.map { $0.coordinate }
     let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
     mapView.addOverlay(polyline)

     // SwiftUI List preview
     struct GPSListView_Previews: PreviewProvider {
     static var previews: some View {
     List(GPSPoint.sampleRoute) { point in
     HStack {
     Text(point.decimalString)
     Spacer()
     Text(point.speedString ?? "N/A")
     }
     }
     }
     }

     // Animation simulation
     for (index, point) in GPSPoint.sampleRoute.enumerated() {
     DispatchQueue.main.asyncAfter(deadline: .now() + Double(index)) {
     mapView.centerCoordinate = point.coordinate
     }
     }
     ```

     Coordinate changes:
     - Point 0: 37.5665, 126.9780
     - Point 1: 37.5667, 126.9782 (+0.0002, +0.0002)
     - Point 2: 37.5669, 126.9784 (+0.0002, +0.0002)
     - Point 3: 37.5671, 126.9786 (+0.0002, +0.0002)
     - Point 4: 37.5673, 126.9788 (+0.0002, +0.0002)

     Speed changes:
     - Point 0: 30 km/h
     - Point 1: 35 km/h (+5)
     - Point 2: 40 km/h (+5)
     - Point 3: 45 km/h (+5)
     - Point 4: 50 km/h (+5)
     */
    /// Array of sample GPS points forming a route
    static let sampleRoute: [GPSPoint] = [
        GPSPoint(timestamp: Date(), latitude: 37.5665, longitude: 126.9780, altitude: 15, speed: 30, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(1), latitude: 37.5667, longitude: 126.9782, altitude: 15, speed: 35, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(2), latitude: 37.5669, longitude: 126.9784, altitude: 16, speed: 40, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(3), latitude: 37.5671, longitude: 126.9786, altitude: 16, speed: 45, heading: 50),
        GPSPoint(timestamp: Date().addingTimeInterval(4), latitude: 37.5673, longitude: 126.9788, altitude: 17, speed: 50, heading: 50)
    ]
}
