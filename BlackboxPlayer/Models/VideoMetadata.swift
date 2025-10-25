/// @file VideoMetadata.swift
/// @brief Blackbox video metadata model (GPS and G-Sensor)
/// @author BlackboxPlayer Development Team
///
/// Model for video file metadata (GPS and G-Sensor data)

import Foundation

/*
 ═══════════════════════════════════════════════════════════════════════════════
 VideoMetadata - Video Metadata Container
 ═══════════════════════════════════════════════════════════════════════════════

 【Overview】
 VideoMetadata is a container struct that manages GPS location data and G-sensor acceleration data
 recorded with blackbox video files. It can display location and impact information in real-time
 during video playback, and calculate statistics such as travel distance, average speed, and maximum impact.

 【What is Metadata?】

 Metadata means "data about data".

 Analogies:
 - Book's table of contents, index, ISBN number → Information (metadata) about the book (data)
 - Photo EXIF information → Capture date/time, camera model, GPS location, etc.
 - Video metadata → Resolution, duration, codec, GPS/sensor data, etc.

 Blackbox metadata:
 - Video file (.mp4): Actual video data
 - GPS data: Driving route, speed information
 - G-sensor data: Impact, rapid acceleration/braking information
 - Device information: Blackbox model, firmware version

 【Time-Series Data】

 Time-series data is data recorded in chronological order.

 Timeline Structure:

 Video Start                                                    Video End
 ├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
 0s   5s   10s  15s  20s  25s  30s  35s  40s  45s  50s

 GPS:  ●    ●    ●    ●    ●    ●    ●    ●    ●    ●
 (Position, speed recording - typically every 1 second)

 G-Sensor: ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
 (Acceleration recording - typically every 0.1 second, 10Hz)

 Characteristics:
 1. Time order preserved (earlier recorded data appears first in array)
 2. Uniform or non-uniform intervals (GPS: 1s, Sensor: 0.1s, etc.)
 3. Time-based searching (finding data at specific moments)
 4. Aggregation operations (average, maximum, sum, etc.)

 【Structure Diagram】

 VideoMetadata
 ├─ gpsPoints: [GPSPoint]           ← GPS time-series data
 │   ├─ GPSPoint(timestamp: 0s, lat: 37.5, lon: 127.0, speed: 30)
 │   ├─ GPSPoint(timestamp: 1s, lat: 37.501, lon: 127.001, speed: 35)
 │   └─ GPSPoint(timestamp: 2s, lat: 37.502, lon: 127.002, speed: 40)
 │
 ├─ accelerationData: [AccelerationData] ← G-sensor time-series data
 │   ├─ AccelerationData(timestamp: 0.0s, x: 0, y: 0, z: 1)
 │   ├─ AccelerationData(timestamp: 0.1s, x: 0.1, y: 0, z: 1)
 │   └─ AccelerationData(timestamp: 0.2s, x: 0.2, y: -0.5, z: 1)
 │
 └─ deviceInfo: DeviceInfo?         ← Device information
 ├─ manufacturer: "BlackVue"
 ├─ model: "DR900X-2CH"
 └─ firmwareVersion: "1.010"

 【Usage Example】

 1. GPS data query:
 ```swift
 let metadata = VideoMetadata.sample

 // specific point abovetion 
 if let point = metadata.gpsPoint(at: 15.5) {
 print("15.5second point abovetion: \(point.latitude), \(point.longitude)")
 print("speed: \(point.speedString)")
 }

 // driving distance calculate
 print("total driving distance: \(metadata.summary.distanceString)")  // "2.5 km"

 // speed statistics
 print("average speed: \(metadata.summary.averageSpeedString ?? "N/A")")  // "45.3 km/h"
 print("maximum speed: \(metadata.summary.maximumSpeedString ?? "N/A")")  // "68.5 km/h"
 ```

 2. Impact events minute:
 ```swift
 let metadata = VideoMetadata.withImpact

 // Impact events  whether
 if metadata.hasImpactEvents {
 print("⚠️ Impact events detectioned!")

 // all Impact events query
 for event in metadata.impactEvents {
 print("impact time: \(event.timestamp)")
 print("impact : \(String(format: "%.2f G", event.magnitude))")
 print("impact : \(event.primaryDirection.displayName)")
 print("each: \(event.severity.displayName)")
 }
 }

 // maximum G-Force
 if let maxG = metadata.maximumGForce {
 print("maximum impact: \(String(format: "%.2f G", maxG))")
 }
 ```

 3. integration summary information:
 ```swift
 let summary = metadata.summary

 print("=== metadata summary ===")
 print("GPS data: \(summary.hasGPS ? "available" : "none") (\(summary.gpsPointCount) points)")
 print("driving distance: \(summary.distanceString)")
 print("average speed: \(summary.averageSpeedString ?? "N/A")")
 print("acceleration data: \(summary.hasAcceleration ? "available" : "none") (\(summary.accelerationPointCount) points)")
 print("Impact events: \(summary.impactEventCount)times")
 print("maximum G-Force: \(summary.maximumGForceString ?? "N/A")")
 ```

 【Codable 】

 VideoMetadata Codable ha JSON  storage/do number .

 JSON structure example:
 ```json
 {
 "gpsPoints": [
 {
 "timestamp": "2025-10-12T14:30:00Z",
 "latitude": 37.5665,
 "longitude": 126.9780,
 "speed": 45.5
 }
 ],
 "accelerationData": [
 {
 "timestamp": "2025-10-12T14:30:00.0Z",
 "x": 0.0,
 "y": 0.0,
 "z": 1.0
 }
 ],
 "deviceInfo": {
 "manufacturer": "BlackVue",
 "model": "DR900X-2CH",
 "firmwareVersion": "1.010"
 }
 }
 ```

 storage/ example:
 ```swift
 // JSON File storage
 let encoder = JSONEncoder()
 encoder.dateEncodingStrategy = .iso8601
 let jsonData = try encoder.encode(metadata)
 try jsonData.write(to: metadataFileURL)

 // JSON Filefrom 
 let decoder = JSONDecoder()
 decoder.dateDecodingStrategy = .iso8601
 let loadedData = try Data(contentsOf: metadataFileURL)
 let metadata = try decoder.decode(VideoMetadata.self, from: loadedData)
 ```

 【 】

 1. Notes use:
 - GPS data: 1time recording = approximately 3,600 points (1second 1items)
 - G-sensor data: 1time recording = approximately 36,000 points (10Hz Samplering)
 - example Notes: GPS approximately 500KB, Sensor approximately 2MB (1time level)

 2. search :
 - gpsPoint(at:) accelerationData(at:) O(n) linear search use
 - er queryha   search(Binary Search)  possible
 - array  timepure sort uh  search  possible

 3. filterring :
 - impactEvents  filterringha  
 - large data  lazy operation use

 ═══════════════════════════════════════════════════════════════════════════════
 */

/// @struct VideoMetadata
/// @brief Blackbox Video Metadata Container
///
/// Metadata associated with a dashcam video file
///
/// blackbox video File includeed metadata represent struct.
/// GPS abovetion information, G-Sensor acceleration data, device information integration manageha,
/// driving minuteand impact detection aboveone one method .
///
/// ** :**
/// - GPS time-series data manage  query
/// - G-Sensor acceleration data manage  minute
/// - driving statistics calculate (distance, speed)
/// - Impact events 
/// - integration summary information create
///
/// **data structure:**
/// ```
/// VideoMetadata
///   ├─ gpsPoints: [GPSPoint]              (GPS )
///   ├─ accelerationData: [AccelerationData] (Sensor )
///   └─ deviceInfo: DeviceInfo?             (device information)
/// ```
///
/// **use example:**
/// ```swift
/// // metadata create
/// let metadata = VideoMetadata(
///     gpsPoints: gpsArray,
///     accelerationData: sensorArray,
///     deviceInfo: device
/// )
///
/// // specific point data query
/// let gps = metadata.gpsPoint(at: 15.5)     // 15.5second point GPS
/// let acc = metadata.accelerationData(at: 15.5) // 15.5second point acceleration
///
/// // statistics query
/// print("driving distance: \(metadata.totalDistance)m")
/// print("average speed: \(metadata.averageSpeed ?? 0)km/h")
/// print("impact number: \(metadata.impactEvents.count)times")
/// ```
struct VideoMetadata: Codable, Equatable, Hashable {
    /// @var gpsPoints
    /// @brief GPS time-series data array
    ///
    /// GPS data points throughout the recording
    ///
    /// recording  recorded GPS abovetion information array.
    ///
    /// **time-series data characteristic:**
    /// - time purefrom sorted (timestamp level pure)
    /// - Commonuh 1second uh record (1Hz Samplering)
    /// - each points above, , speed,  etc include
    ///
    /// **data size example:**
    /// - 1 minute recording: approximately 60 points
    /// - 1time recording: approximately 3,600 points
    /// - Notes: 1time approximately 500KB
    ///
    /// **array example:**
    /// ```
    /// [0] GPSPoint(timestamp: 2025-10-12 14:30:00, lat: 37.5665, lon: 126.9780, speed: 45.5)
    /// [1] GPSPoint(timestamp: 2025-10-12 14:30:01, lat: 37.5666, lon: 126.9781, speed: 46.0)
    /// [2] GPSPoint(timestamp: 2025-10-12 14:30:02, lat: 37.5667, lon: 126.9782, speed: 47.2)
    /// ...
    /// ```
    let gpsPoints: [GPSPoint]

    /// @var accelerationData
    /// @brief G-Sensor time-series data array
    ///
    /// G-Sensor acceleration data throughout the recording
    ///
    /// recording  recorded G-Sensor acceleration data array.
    ///
    /// **time-series data characteristic:**
    /// - time purefrom sorted (timestamp level pure)
    /// - Commonuh 0.1second uh record (10Hz Samplering)
    /// - GPS 10 high sampling rate
    /// - each points X, Y, Z 3 acceleration value include
    ///
    /// **data size example:**
    /// - 1 minute recording: approximately 600 points (10Hz × 60second)
    /// - 1time recording: approximately 36,000 points
    /// - Notes: 1time approximately 2MB
    ///
    /// **sampling rate compare:**
    /// ```
    /// GPS:     ●     ●     ●     ●     ●  (1Hz, 1second )
    /// G-Sensor: ●●●●●●●●●●●●●●●●●●●● (10Hz, 0.1second )
    /// ```
    let accelerationData: [AccelerationData]

    /// @var deviceInfo
    /// @brief blackbox device information ()
    ///
    /// Device/dashcam information (optional)
    ///
    /// blackbox device information.
    ///
    /// **include information:**
    /// - manufacturer: manufacturer (example: "BlackVue", "Thinkware")
    /// - model: model (example: "DR900X-2CH")
    /// - firmwareVersion:   (example: "1.010")
    /// - serialNumber:  
    /// - recordingMode: recording mode (example: "Normal", "Parking")
    ///
    /// **in :**
    /// - nine blackbox device information recordha  number available
    /// - File format  device information not number available
    /// - not GPS/sensor data minute  none
    ///
    /// **use example:**
    /// ```swift
    /// if let device = metadata.deviceInfo {
    ///     print("manufacturer: \(device.manufacturer ?? " number none")")
    ///     print("model: \(device.model ?? " number none")")
    ///     print(": \(device.firmwareVersion ?? " number none")")
    /// }
    /// ```
    let deviceInfo: DeviceInfo?

    // MARK: - Initialization

    init(
        gpsPoints: [GPSPoint] = [],
        accelerationData: [AccelerationData] = [],
        deviceInfo: DeviceInfo? = nil
    ) {
        self.gpsPoints = gpsPoints
        self.accelerationData = accelerationData
        self.deviceInfo = deviceInfo
    }

    // MARK: - GPS Methods

    /// @brief GPS data availability check
    /// @return GPS data if available true
    ///
    /// Check if GPS data is available
    ///
    /// GPS data exists check.
    ///
    /// ** :**
    /// - gpsPoints array exists uh true
    /// - array if available false
    ///
    /// **isEmpty vs count == 0:**
    /// - isEmpty array  property  
    /// - uh count == 0and sameha operation
    /// - Swift from isEmpty use 
    ///
    /// **use example:**
    /// ```swift
    /// if metadata.hasGPSData {
    ///     // GPS  UI display
    ///     showMapView()
    ///     showSpeedInfo()
    /// } else {
    ///     // GPS data none not
    ///     showNoGPSMessage()
    /// }
    /// ```
    var hasGPSData: Bool {
        return !gpsPoints.isEmpty
    }

    /// @brief specific point GPS points search
    /// @param timeOffset video start time  (second)
    /// @return   GPS points also nil
    ///
    /// Get GPS point at specific time offset
    /// - Parameter timeOffset: Time offset in seconds from start of video
    /// - Returns: Closest GPS point or nil
    ///
    /// video specific point correspondingha GPS points .
    ///
    /// **:  points search (Nearest Point Search)**
    ///
    /// step:
    /// 1. gpsPoints if available nil return (data none)
    /// 2.  th GPS points timestamp level(t0)uh settings
    /// 3. each points  time calculate: (points timestamp - t0)
    /// 4. one timeOffsetand time  calculate: | time - timeOffset|
    /// 5. time    points return
    ///
    /// **time  calculate example:**
    /// ```
    /// gpsPoints:
    ///   [0] timestamp: 14:30:00 (t0) →  time: 0second
    ///   [1] timestamp: 14:30:01      →  time: 1second
    ///   [2] timestamp: 14:30:02      →  time: 2second
    ///   [3] timestamp: 14:30:03      →  time: 3second
    ///
    /// : timeOffset = 2.3second
    ///
    /// time  calculate:
    ///   [0] |0 - 2.3| = 2.3second
    ///   [1] |1 - 2.3| = 1.3second
    ///   [2] |2 - 2.3| = 0.3second  ← minimum! ( )
    ///   [3] |3 - 2.3| = 0.7second
    ///
    /// and: gpsPoints[2] return
    /// ```
    ///
    /// **time :**
    /// - O(n): all points iterateha minimumvalue 
    /// - n = gpsPoints.count
    ///
    /// ** possibility:**
    /// - array timepure sort uh  search(Binary Search) possible → O(log n)
    /// - er call   searchuh  
    ///
    /// **use example:**
    /// ```swift
    /// // video 15.5second point abovetion 
    /// if let gps = metadata.gpsPoint(at: 15.5) {
    ///     print("abovetion: \(gps.latitude), \(gps.longitude)")
    ///     print("speed: \(gps.speedString)")
    ///
    ///     //   display
    ///     mapView.showMarker(at: gps.coordinate)
    /// }
    ///
    /// // video playback  time abovetion update
    /// func updateGPSDisplay(currentTime: TimeInterval) {
    ///     if let gps = metadata.gpsPoint(at: currentTime) {
    ///         speedLabel.text = gps.speedString
    ///         mapView.centerCoordinate = gps.coordinate
    ///     }
    /// }
    /// ```
    func gpsPoint(at timeOffset: TimeInterval) -> GPSPoint? {
        // 1. GPS data notuh nil return
        guard !gpsPoints.isEmpty else { return nil }

        // 2. points oneonly if available  return
        guard gpsPoints.count > 1 else { return gpsPoints.first }

        let baseTime = gpsPoints[0].timestamp

        // 3. timeOffset correspondingha  points  (linear interpolation)
        var beforePoint: GPSPoint?
        var afterPoint: GPSPoint?

        for i in 0..<gpsPoints.count {
            let offset = gpsPoints[i].timestamp.timeIntervalSince(baseTime)

            if offset <= timeOffset {
                beforePoint = gpsPoints[i]
            } else {
                afterPoint = gpsPoints[i]
                break
            }
        }

        // 4. interpolation number
        if let before = beforePoint, let after = afterPoint {
            //  points between - linear interpolation
            let t1 = before.timestamp.timeIntervalSince(baseTime)
            let t2 = after.timestamp.timeIntervalSince(baseTime)
            let ratio = (timeOffset - t1) / (t2 - t1)

            // above, , speed interpolation
            let lat = before.latitude + (after.latitude - before.latitude) * ratio
            let lon = before.longitude + (after.longitude - before.longitude) * ratio
            let speed = (before.speed ?? 0) + ((after.speed ?? 0) - (before.speed ?? 0)) * ratio

            // interpolationed timestamp
            let interpolatedTime = baseTime.addingTimeInterval(timeOffset)

            return GPSPoint(
                timestamp: interpolatedTime,
                latitude: lat,
                longitude: lon,
                speed: speed
            )
        } else if let before = beforePoint {
            // timeOffset  points  -  points return
            return before
        } else if let after = afterPoint {
            // timeOffset  points  -  points return
            return after
        }

        return nil
    }

    /// @brief total driving distance calculate
    /// @return total driving distance ()
    ///
    /// Calculate total distance traveled
    ///
    /// GPS data halfuh total driving distance calculate.
    ///
    /// **:  points  distance sum**
    ///
    /// step:
    /// 1. GPS points 2 less than 0 return (distance calculate )
    /// 2. inone  points  distance pureuh calculate
    /// 3. all nine distance sumha total distance 
    ///
    /// **distance calculate :**
    /// ```
    /// GPS path:  A ─────▶ B ─────▶ C ─────▶ D
    ///           (100m)   (150m)   (200m)
    ///
    /// total distance = distance(A→B) + distance(B→C) + distance(C→D)
    ///        = 100 + 150 + 200
    ///        = 450m
    /// ```
    ///
    /// **Haversine  use:**
    /// - GPSPoint.distance(to:) method Haversine  use
    /// - nine nine ingha    only distance calculate
    /// - and (m) unit
    ///
    /// ** structure:**
    /// ```swift
    /// // array in: 0, 1, 2, 3, ..., n-1
    /// // nine: (0→1), (1→2), (2→3), ..., (n-2→n-1)
    /// // total n-1 nine
    ///
    /// for i in 0..<(gpsPoints.count - 1) {
    ///     // ith i+1th points  distance calculate
    ///     total += gpsPoints[i].distance(to: gpsPoints[i + 1])
    /// }
    /// ```
    ///
    /// **ing :**
    /// - GPS Samplering : 1second  (Common)
    /// - speed 60km/h when 1second approximately 16.7m 
    /// - from  driving distance approximately  measurement number available
    /// -  distance sum  one  half not ed
    ///
    /// **use example:**
    /// ```swift
    /// let distance = metadata.totalDistance
    /// print("total driving distance: \(distance)m")  // example: 2450.5m
    ///
    /// //  convert
    /// let km = distance / 1000.0
    /// print("total driving distance: \(String(format: "%.1f", km))km")  // example: 2.5km
    ///
    /// // MetadataSummaryfrom formated string use
    /// print(metadata.summary.distanceString)  // "2.5 km"
    /// ```
    var totalDistance: Double {
        // 1. GPS points 2 less than distance calculate  → 0 return
        guard gpsPoints.count >= 2 else { return 0 }

        // 2.  distance storagedo number initial
        var total: Double = 0

        // 3. inone  points  distance pureuh sum
        // i 0 (count - 2)to iterate
        // example: count 5 i 0, 1, 2, 3 (total 4 nine)
        for i in 0..<(gpsPoints.count - 1) {
            // ith pointsfrom i+1th pointsto distance calculate  
            total += gpsPoints[i].distance(to: gpsPoints[i + 1])
        }

        // 4. total distance return (unit: )
        return total
    }

    /// @brief average speed calculate
    /// @return average speed (km/h) also nil
    ///
    /// Calculate average speed from GPS data
    ///
    /// GPS data halfuh average speed calculate.
    ///
    /// **:  average (Arithmetic Mean)**
    ///
    /// :
    /// ```
    /// average speed = (v1 + v2 + v3 + ... + vn) / n
    ///
    /// v1, v2, v3, ..., vn: each GPS points speed
    /// n: speed data  points count
    /// ```
    ///
    /// **compactMap use:**
    /// - GPS points speed  (Double?)
    /// - compactMap nil excludeha value  only array convert
    /// - example: [30.5, nil, 45.2, nil, 50.0] → [30.5, 45.2, 50.0]
    ///
    /// ** return:**
    /// - speed data one notuh nil return
    /// - average calculate possibleone  (0uh  )
    ///
    /// **reduce number:**
    /// ```swift
    /// speeds.reduce(0, +)
    ///   = speeds[0] + speeds[1] + speeds[2] + ...
    ///   = all speed 
    ///
    /// initialvalue: 0
    /// operation: + ()
    /// ```
    ///
    /// **calculate example:**
    /// ```
    /// GPS points:
    ///   [0] speed: 30.5 km/h
    ///   [1] speed: nil (GPS  approximately)
    ///   [2] speed: 45.2 km/h
    ///   [3] speed: nil
    ///   [4] speed: 50.0 km/h
    ///   [5] speed: 42.8 km/h
    ///
    /// compactMap : [30.5, 45.2, 50.0, 42.8]
    ///
    /// : 30.5 + 45.2 + 50.0 + 42.8 = 168.5
    /// average: 168.5 / 4 = 42.125 km/h
    /// ```
    ///
    /// **:**
    /// - ing time average includeed (speed 0 include)
    /// -  "driving average speed" one speed > 0in only filterring required
    /// - etc , ing nine uh average speed 
    ///
    /// **use example:**
    /// ```swift
    /// if let avgSpeed = metadata.averageSpeed {
    ///     print("average speed: \(String(format: "%.1f", avgSpeed))km/h")
    ///
    ///     // UI display
    ///     averageSpeedLabel.text = metadata.summary.averageSpeedString  // "42.1 km/h"
    /// } else {
    ///     print("speed data none")
    /// }
    ///
    /// //   average speed (ing exclude)
    /// let movingAverage = gpsPoints
    ///     .compactMap { $0.speed }
    ///     .filter { $0 > 5.0 }  // 5km/h or moreonly (ing exclude)
    ///     .reduce(0, +) / Double(movingAverage.count)
    /// ```
    var averageSpeed: Double? {
        // 1. GPS pointsfrom nil  speed valueonly extract
        let speeds = gpsPoints.compactMap { $0.speed }

        // 2. speed data notuh nil return
        guard !speeds.isEmpty else { return nil }

        // 3. all speed  nineha count  average calculate
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    /// @brief maximum speed calculate
    /// @return maximum speed (km/h) also nil
    ///
    /// Calculate maximum speed from GPS data
    ///
    /// GPS datafrom maximum speed .
    ///
    /// **: maximumvalue **
    ///
    /// step:
    /// 1. GPS pointsfrom nil  speed valueonly extract (compactMap)
    /// 2. speed arrayfrom maximumvalue  (max())
    /// 3. speed data notuh nil return
    ///
    /// **max() method:**
    /// - array maximumvalue returnha level method
    /// - array if available nil return
    /// - time : O(n) - all  one  iterate
    ///
    /// ** :**
    /// ```swift
    /// compactMap { $0.speed }.max()
    ///                         ↑
    ///                      portion  return
    ///
    /// and:
    /// - speed data available → Double? (maximumvalue)
    /// - speed data none → nil
    /// ```
    ///
    /// **calculate example:**
    /// ```
    /// GPS points:
    ///   [0] speed: 30.5 km/h
    ///   [1] speed: nil
    ///   [2] speed: 68.5 km/h  ← maximum!
    ///   [3] speed: 45.2 km/h
    ///   [4] speed: 55.0 km/h
    ///
    /// compactMap : [30.5, 68.5, 45.2, 55.0]
    ///
    /// max() and: 68.5 km/h
    /// ```
    ///
    /// ** usage:**
    /// - and : maximum speed one speed secondand  
    /// - driving pattern minute: maximum speed   
    /// - statistics : maximum speed display
    ///
    /// **use example:**
    /// ```swift
    /// if let maxSpeed = metadata.maximumSpeed {
    ///     print("maximum speed: \(String(format: "%.1f", maxSpeed))km/h")
    ///
    ///     // and  (one speed 80km/h)
    ///     if maxSpeed > 80.0 {
    ///         print("⚠️ and nine detection: \(String(format: "%.1f", maxSpeed))km/h")
    ///     }
    ///
    ///     // UI display
    ///     maxSpeedLabel.text = metadata.summary.maximumSpeedString  // "68.5 km/h"
    /// }
    /// ```
    var maximumSpeed: Double? {
        // GPS pointsfrom nil  speedonly extract  maximumvalue return
        return gpsPoints.compactMap { $0.speed }.max()
    }

    /// @brief  display driving path  array
    /// @return validone GPS  array
    ///
    /// Get route as array of coordinates for map display
    ///
    ///  displaydo driving path return.
    ///
    /// **filterring level:**
    /// - validone GPS only include (isValid == true)
    /// - validha   exclude (above/ above )
    ///
    /// **isValid :**
    /// - above: -90° ~ +90° above 
    /// - : -180° ~ +180° above 
    /// - above  ed GPS data
    ///
    /// **filter method:**
    /// ```swift
    /// gpsPoints.filter { $0.isValid }
    ///
    /// //  approximately :
    /// gpsPoints.filter { point in
    ///     return point.isValid
    /// }
    ///
    /// // operation:
    /// - each    
    /// -  true returnha and array include
    /// -  false returnha exclude
    /// ```
    ///
    /// **filterring example:**
    /// ```
    /// original gpsPoints:
    ///   [0] GPSPoint(lat: 37.5665, lon: 126.9780)     ✓ valid
    ///   [1] GPSPoint(lat: 999.0, lon: 126.9781)       ✗ above above secondand
    ///   [2] GPSPoint(lat: 37.5667, lon: 126.9782)     ✓ valid
    ///   [3] GPSPoint(lat: 0.0, lon: 0.0)              ✗ GPS number (0,0 from one)
    ///   [4] GPSPoint(lat: 37.5669, lon: 126.9784)     ✓ valid
    ///
    /// filterring  routeCoordinates:
    ///   [0] GPSPoint(lat: 37.5665, lon: 126.9780)
    ///   [1] GPSPoint(lat: 37.5667, lon: 126.9782)
    ///   [2] GPSPoint(lat: 37.5669, lon: 126.9784)
    /// ```
    ///
    /// ** display usage:**
    /// - MapKit MKPolylineuh path 
    /// - each  ha driving path each
    /// - ed  automaticuh exclude
    ///
    /// **use example:**
    /// ```swift
    /// // MapKitfrom path 
    /// let coordinates = metadata.routeCoordinates.map { $0.coordinate }
    /// let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    /// mapView.addOverlay(polyline)
    ///
    /// // path above   /
    /// let rect = polyline.boundingMapRect
    /// mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
    ///
    /// // path start/   display
    /// if let start = metadata.routeCoordinates.first {
    ///     addMarker(at: start.coordinate, title: "start ")
    /// }
    /// if let end = metadata.routeCoordinates.last {
    ///     addMarker(at: end.coordinate, title: " ")
    /// }
    /// ```
    var routeCoordinates: [GPSPoint] {
        // validone GPS only filterringha return
        return gpsPoints.filter { $0.isValid }
    }

    // MARK: - Acceleration Methods

    /// @brief G-sensor data availability check
    /// @return G-sensor data if available true
    ///
    /// Check if G-Sensor data is available
    ///
    /// G-Sensor acceleration data exists check.
    ///
    /// ** :**
    /// - accelerationData array exists uh true
    /// - array if available false
    ///
    /// **use example:**
    /// ```swift
    /// if metadata.hasAccelerationData {
    ///     // impact detection UI display
    ///     showImpactDetectionView()
    ///     showGForceGraph()
    /// } else {
    ///     // G-sensor data none not
    ///     showNoAccelerationMessage()
    /// }
    /// ```
    var hasAccelerationData: Bool {
        return !accelerationData.isEmpty
    }

    /// @brief specific point acceleration data search
    /// @param timeOffset video start time  (second)
    /// @return   acceleration data also nil
    ///
    /// Get acceleration data at specific time offset
    /// - Parameter timeOffset: Time offset in seconds from start of video
    /// - Returns: Closest acceleration data or nil
    ///
    /// video specific point correspondingha acceleration data .
    ///
    /// **:  points search (Nearest Point Search)**
    ///
    /// - gpsPoint(at:) sameone  use
    /// - G-Sensor 10Hz Sampleringuh GPS 10  data
    ///
    /// step:
    /// 1. accelerationData if available nil return
    /// 2.  th data points timestamp level(t0)uh settings
    /// 3. each data  time calculate: (data timestamp - t0)
    /// 4. one timeOffsetand time  calculate: | time - timeOffset|
    /// 5. time    data return
    ///
    /// **time  calculate example:**
    /// ```
    /// accelerationData:
    ///   [0] timestamp: 14:30:00.0 (t0) →  time: 0.0second
    ///   [1] timestamp: 14:30:00.1      →  time: 0.1second
    ///   [2] timestamp: 14:30:00.2      →  time: 0.2second
    ///   [3] timestamp: 14:30:00.3      →  time: 0.3second
    ///
    /// : timeOffset = 0.25second
    ///
    /// time  calculate:
    ///   [0] |0.0 - 0.25| = 0.25second
    ///   [1] |0.1 - 0.25| = 0.15second
    ///   [2] |0.2 - 0.25| = 0.05second  ← minimum! ( )
    ///   [3] |0.3 - 0.25| = 0.05second  (samehaonly [2] )
    ///
    /// and: accelerationData[2] return
    /// ```
    ///
    /// **GPS vs G-Sensor Samplering compare:**
    /// ```
    /// GPS (1Hz):        ●        ●        ●        ●
    /// G-Sensor (10Hz):   ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
    ///
    /// timeOffset = 0.25second:
    /// - GPS: 0second also 1second   (ing )
    /// - G-Sensor: 0.2second also 0.3second   (ing )
    /// ```
    ///
    /// **use example:**
    /// ```swift
    /// // video 15.5second point G-Force display
    /// if let acc = metadata.accelerationData(at: 15.5) {
    ///     print("G-Force: \(String(format: "%.2f", acc.magnitude))G")
    ///     print(": \(acc.primaryDirection.displayName)")
    ///     print("each: \(acc.severity.displayName)")
    ///
    ///     // UI update
    ///     gForceLabel.text = "\(String(format: "%.2f", acc.magnitude))G"
    ///     directionImageView.image = UIImage(systemName: acc.primaryDirection.iconName)
    /// }
    ///
    /// // video playback  time G-Force 
    /// func updateAccelerationGraph(currentTime: TimeInterval) {
    ///     if let acc = metadata.accelerationData(at: currentTime) {
    ///         gForceGraph.addDataPoint(acc.magnitude)
    ///         xAxisGraph.addDataPoint(acc.x)
    ///         yAxisGraph.addDataPoint(acc.y)
    ///         zAxisGraph.addDataPoint(acc.z)
    ///     }
    /// }
    /// ```
    func accelerationData(at timeOffset: TimeInterval) -> AccelerationData? {
        // 1. G-sensor data notuh nil return
        guard !accelerationData.isEmpty else { return nil }

        // 2.  th data points timestamp level(t0)uh use
        // 3. min(by:)  each data time  calculate  minimumvalue 
        return accelerationData.min(by: { data1, data2 in
            // data1 time  calculate
            let diff1 = abs(data1.timestamp.timeIntervalSince(accelerationData[0].timestamp) - timeOffset)
            // data2 time  calculate
            let diff2 = abs(data2.timestamp.timeIntervalSince(accelerationData[0].timestamp) - timeOffset)
            // time    "more " data
            return diff1 < diff2
        })
    }

    /// @brief one acceleration event search (> 1.5G)
    /// @return one acceleration event array
    ///
    /// Find all significant acceleration events
    ///
    /// one acceleration event  .
    ///
    /// **one event (Significant Event):**
    /// - AccelerationData.isSignificant == true
    /// - acceleration size 1.5G or morein 
    /// - normal driving one //times 
    ///
    /// **1.5G level :**
    /// ```
    /// acceleration above:
    ///   0.0 ~ 1.0G: normal driving (normal)
    ///   1.0 ~ 1.5G: approximately one / ()
    ///   1.5 ~ 2.5G: one event ★
    ///   2.5 ~ 4.0G: Impact events
    ///   4.0G or more: eachone impact
    /// ```
    ///
    /// ** example:**
    /// - 1.0G: normal /ing
    /// - 1.5G: , , times
    /// - 2.0G: accident  
    /// - 3.0G: one 
    ///
    /// **filter method:**
    /// ```swift
    /// accelerationData.filter { $0.isSignificant }
    ///
    /// // operation:
    /// - each AccelerationData iterate
    /// - isSignificant truein only and array include
    /// - time : O(n)
    /// ```
    ///
    /// **filterring example:**
    /// ```
    /// accelerationData:
    ///   [0] magnitude: 0.8G  (normal driving)       ✗ exclude
    ///   [1] magnitude: 1.2G  ( )      ✗ exclude
    ///   [2] magnitude: 1.8G  ()          ✓ include
    ///   [3] magnitude: 1.0G  (normal driving)       ✗ exclude
    ///   [4] magnitude: 2.3G  (times)          ✓ include
    ///   [5] magnitude: 3.5G  (impact)            ✓ include
    ///
    /// and significantEvents: [1.8G, 2.3G, 3.5G]
    /// ```
    ///
    /// **use example:**
    /// ```swift
    /// let events = metadata.significantEvents
    /// print("one event: \(events.count)times")
    ///
    /// // ingtimeline  display
    /// for event in events {
    ///     let time = event.timestamp.timeIntervalSince(metadata.accelerationData[0].timestamp)
    ///     addTimelineMarker(at: time, severity: event.severity)
    /// }
    ///
    /// // event  display
    /// for (index, event) in events.enumerated() {
    ///     print("\(index + 1). \(event.timestamp.formatted())")
    ///     print("   : \(String(format: "%.2f", event.magnitude))G")
    ///     print("   : \(event.primaryDirection.displayName)")
    /// }
    /// ```
    var significantEvents: [AccelerationData] {
        // isSignificant truein dataonly filterring
        return accelerationData.filter { $0.isSignificant }
    }

    /// @brief Impact events search (> 2.5G)
    /// @return Impact events array
    ///
    /// Find all impact events
    ///
    /// Impact events  .
    ///
    /// **Impact events (Impact Event):**
    /// - AccelerationData.isImpact == true
    /// - acceleration size 2.5G or morein 
    /// - accident, , eachone impact 
    ///
    /// **2.5G level :**
    /// ```
    /// acceleration above:
    ///   0.0 ~ 1.5G: normal/one 
    ///   1.5 ~ 2.5G: one  (Moderate)
    ///   2.5 ~ 4.0G: Impact events ★
    ///   4.0G or more: eachone impact
    /// ```
    ///
    /// ** example:**
    /// - 2.5G: accident impact, large  and
    /// - 3.0G: one 
    /// - 5.0G: eachone 
    /// - 10G+:  eachone accident
    ///
    /// **blackbox usage:**
    /// - Impact events   automaticuh File 
    /// - event foldermore(/event/) each storage
    /// - accident  er usage
    ///
    /// **use example:**
    /// ```swift
    /// let impacts = metadata.impactEvents
    ///
    /// if !impacts.isEmpty {
    ///     print("⚠️ Impact events \(impacts.count)times detection!")
    ///
    ///     for (index, impact) in impacts.enumerated() {
    ///         print("\n[\(index + 1)] Impact events")
    ///         print("time: \(impact.timestamp.formatted())")
    ///         print(": \(String(format: "%.2f", impact.magnitude))G")
    ///         print(": \(impact.primaryDirection.displayName)")
    ///         print("each: \(impact.severity.displayName)")
    ///         print(": \(impact.severity.colorHex)")
    ///     }
    ///
    ///     //  one impact 
    ///     if let strongest = impacts.max(by: { $0.magnitude < $1.magnitude }) {
    ///         print("\n one impact: \(String(format: "%.2f", strongest.magnitude))G")
    ///     }
    /// } else {
    ///     print("✓ Impact events none (safe driving)")
    /// }
    /// ```
    var impactEvents: [AccelerationData] {
        // isImpact truein dataonly filterring
        return accelerationData.filter { $0.isImpact }
    }

    /// @brief maximum G-Force calculate
    /// @return maximum G-Force also nil
    ///
    /// Calculate maximum G-force experienced
    ///
    /// one maximum G-Force calculate.
    ///
    /// **:**
    /// 1. all acceleration data magnitude(size) extract
    /// 2.   maximumvalue return
    ///
    /// **map method:**
    /// ```swift
    /// accelerationData.map { $0.magnitude }
    ///
    /// // convert:
    /// AccelerationData → Double
    /// [AccelerationData] → [Double]
    ///
    /// // example:
    /// [AccelerationData(x:0, y:0, z:1), AccelerationData(x:1.5, y:-3.5, z:0.8)]
    ///   ↓ map { $0.magnitude }
    /// [1.0, 3.85]
    /// ```
    ///
    /// **max() method:**
    /// - array maximumvalue return
    /// - array if available nil return
    ///
    /// **calculate example:**
    /// ```
    /// accelerationData:
    ///   [0] AccelerationData(x: 0.0, y: 0.0, z: 1.0)   → magnitude: 1.0G
    ///   [1] AccelerationData(x: 0.0, y: -1.8, z: 1.0)  → magnitude: 2.06G
    ///   [2] AccelerationData(x: 2.2, y: 0.5, z: 1.0)   → magnitude: 2.45G
    ///   [3] AccelerationData(x: 1.5, y: -3.5, z: 0.8)  → magnitude: 3.85G ← maximum!
    ///
    /// map : [1.0, 2.06, 2.45, 3.85]
    /// max() and: 3.85G
    /// ```
    ///
    /// **usage:**
    /// - total driving   one impact check
    /// - accident each 
    /// -  processing   er
    ///
    /// **use example:**
    /// ```swift
    /// if let maxG = metadata.maximumGForce {
    ///     print("maximum G-Force: \(String(format: "%.2f", maxG))G")
    ///
    ///     // each 
    ///     if maxG > 4.0 {
    ///         print("🚨 eachone impact detection! accident possibility ")
    ///     } else if maxG > 2.5 {
    ///         print("⚠️ impact detection!  required")
    ///     } else if maxG > 1.5 {
    ///         print("⚡ one / detection")
    ///     } else {
    ///         print("✓ normal driving")
    ///     }
    ///
    ///     // UI display
    ///     maxGForceLabel.text = metadata.summary.maximumGForceString  // "3.85 G"
    /// }
    /// ```
    var maximumGForce: Double? {
        // all acceleration data magnitude extractone  maximumvalue return
        return accelerationData.map { $0.magnitude }.max()
    }

    /// @brief Impact events  whether check
    /// @return Impact events if available true
    ///
    /// Check if video contains impact events
    ///
    /// video Impact events exists check.
    ///
    /// ** :**
    /// - impactEvents array exists uh true
    /// - 2.5G or more impact one if available true
    ///
    /// **usage:**
    /// - accident video automatic minute
    /// - event File priority ing
    /// - UI  display
    ///
    /// **use example:**
    /// ```swift
    /// if metadata.hasImpactEvents {
    ///     // accident videouh minute
    ///     fileCategory = .accident
    ///
    ///     //   display
    ///     thumbnailBadge.backgroundColor = .red
    ///     thumbnailBadge.text = "⚠️ impact"
    ///
    ///     // automatic  trigger
    ///     backupManager.backupImmediately(videoFile)
    /// } else {
    ///     // normal driving video
    ///     fileCategory = .normal
    ///     thumbnailBadge.isHidden = true
    /// }
    /// ```
    var hasImpactEvents: Bool {
        return !impactEvents.isEmpty
    }

    // MARK: - Combined Analysis

    /// @brief metadata minute  summary information create
    /// @return MetadataSummary struct
    ///
    /// Analyze metadata and provide summary
    ///
    /// metadata minuteha summary information create.
    ///
    /// **MetadataSummary structure:**
    /// - GPS : hasGPS, gpsPointCount, totalDistance, averageSpeed, maximumSpeed
    /// - acceleration : hasAcceleration, accelerationPointCount, impactEventCount, maximumGForce
    ///
    /// **integration minute:**
    /// - GPS G-sensor data uh minute
    /// - driving patternand Impact events integration 
    /// - UI display formated string 
    ///
    /// **calculate statistics:**
    /// 1. GPS statistics:
    ///    - total driving distance ( unit, automaticuh km convert)
    ///    - average speed (km/h)
    ///    - maximum speed (km/h)
    ///
    /// 2. acceleration statistics:
    ///    - Impact events number
    ///    - maximum G-Force
    ///
    /// **use example:**
    /// ```swift
    /// let summary = metadata.summary
    ///
    /// // integration  display
    /// print("=== driving summary ===")
    /// print("📍 GPS: \(summary.hasGPS ? "available" : "none")")
    /// print("   points: \(summary.gpsPointCount)items")
    /// print("   distance: \(summary.distanceString)")
    /// print("   average speed: \(summary.averageSpeedString ?? "N/A")")
    /// print("   maximum speed: \(summary.maximumSpeedString ?? "N/A")")
    /// print("")
    /// print("📊 G-Sensor: \(summary.hasAcceleration ? "available" : "none")")
    /// print("   points: \(summary.accelerationPointCount)items")
    /// print("   Impact events: \(summary.impactEventCount)times")
    /// print("   maximum G-Force: \(summary.maximumGForceString ?? "N/A")")
    ///
    /// // SwiftUI Viewfrom use
    /// struct MetadataSummaryView: View {
    ///     let summary: MetadataSummary
    ///
    ///     var body: some View {
    ///         VStack(alignment: .leading) {
    ///             Text("driving distance: \(summary.distanceString)")
    ///             Text("average speed: \(summary.averageSpeedString ?? "N/A")")
    ///             if summary.impactEventCount > 0 {
    ///                 Text("⚠️ impact: \(summary.impactEventCount)times")
    ///                     .foregroundColor(.red)
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    var summary: MetadataSummary {
        return MetadataSummary(
            hasGPS: hasGPSData,
            gpsPointCount: gpsPoints.count,
            totalDistance: totalDistance,
            averageSpeed: averageSpeed,
            maximumSpeed: maximumSpeed,
            hasAcceleration: hasAccelerationData,
            accelerationPointCount: accelerationData.count,
            impactEventCount: impactEvents.count,
            maximumGForce: maximumGForce
        )
    }
}

// MARK: - Supporting Types

/*
 ───────────────────────────────────────────────────────────────────────────────
 DeviceInfo - blackbox device information
 ───────────────────────────────────────────────────────────────────────────────

 blackbox hardware  information storageha struct.

 【Included Information】
 - manufacturer: manufacturer (example: BlackVue, Thinkware, IROAD)
 - model: model (example: DR900X-2CH, Q800PRO)
 - firmwareVersion:   (example: 1.010, v2.5.3)
 - serialNumber:   ( Unique eacher)
 - recordingMode: recording mode (Normal, Parking, Event)

 【Usage】
 -    device information 
 -  update 
 - manufacturereach number  
 - File format  check

 ───────────────────────────────────────────────────────────────────────────────
 */

/// @struct DeviceInfo
/// @brief blackbox device information
///
/// Device/dashcam information
///
/// blackbox device hardware  information .
///
/// **use example:**
/// ```swift
/// let device = DeviceInfo(
///     manufacturer: "BlackVue",
///     model: "DR900X-2CH",
///     firmwareVersion: "1.010",
///     serialNumber: "BV900X123456",
///     recordingMode: "Normal"
/// )
///
/// // device information display
/// print("\(device.manufacturer ?? "Unknown") \(device.model ?? "Unknown")")
/// print("Firmware: \(device.firmwareVersion ?? "Unknown")")
/// ```
struct DeviceInfo: Codable, Equatable, Hashable {
    /// Device manufacturer
    ///
    /// blackbox manufacturer.
    ///
    /// **example:**
    /// - "BlackVue"
    /// - "Thinkware"
    /// - "IROAD"
    /// - "Nextbase"
    let manufacturer: String?

    /// Device model name
    ///
    /// blackbox model.
    ///
    /// **example:**
    /// - "DR900X-2CH" (BlackVue 2channel)
    /// - "Q800PRO" (Thinkware)
    /// - "X10" (IROAD)
    let model: String?

    /// Firmware version
    ///
    ///  .
    ///
    /// **example:**
    /// - "1.010"
    /// - "v2.5.3"
    /// - "20241012"
    let firmwareVersion: String?

    /// Device serial number
    ///
    ///  Unique  .
    ///
    /// **format example:**
    /// - "BV900X123456"
    /// - "TW-Q800-789012"
    let serialNumber: String?

    /// Recording settings/mode
    ///
    /// recording mode settings.
    ///
    /// **mode example:**
    /// - "Normal": normal driving recording
    /// - "Parking": Parking mode recording
    /// - "Event": event recording (impact detection)
    let recordingMode: String?
}

/*
 ───────────────────────────────────────────────────────────────────────────────
 MetadataSummary - metadata summary information
 ───────────────────────────────────────────────────────────────────────────────

 VideoMetadata  statistics  querydo number  ingone struct.

 【include statistics】

 GPS statistics:
 - hasGPS: GPS data availability
 - gpsPointCount: GPS points count
 - totalDistance: total driving distance ()
 - averageSpeed: average speed (km/h)
 - maximumSpeed: maximum speed (km/h)

 acceleration statistics:
 - hasAcceleration: G-sensor data availability
 - accelerationPointCount: acceleration data count
 - impactEventCount: Impact events number (2.5G or more)
 - maximumGForce: maximum G-Force

 【format property】

 - distanceString: distance    convert
 example: 450m → "450 m", 2500m → "2.5 km"

 - averageSpeedString: average speed string convert
 example: 45.3 → "45.3 km/h"

 - maximumSpeedString: maximum speed string convert
 example: 68.5 → "68.5 km/h"

 - maximumGForceString: maximum G-Force string convert
 example: 3.85 → "3.85 G"

 ───────────────────────────────────────────────────────────────────────────────
 */

/// @struct MetadataSummary
/// @brief metadata summary information
///
/// Metadata summary for quick overview
///
/// metadata  statistics summaryone struct.
/// UI display  query above  calculateed value include.
///
/// **use example:**
/// ```swift
/// let summary = metadata.summary
///
/// //  display
/// dashboardView.distanceLabel.text = summary.distanceString
/// dashboardView.avgSpeedLabel.text = summary.averageSpeedString ?? "N/A"
/// dashboardView.impactCountLabel.text = "\(summary.impactEventCount)"
/// ```
struct MetadataSummary: Codable, Equatable {
    /// GPS data availability
    let hasGPS: Bool

    /// GPS points count
    let gpsPointCount: Int

    /// total driving distance ()
    let totalDistance: Double

    /// average speed (km/h, nil data none)
    let averageSpeed: Double?

    /// maximum speed (km/h, nil data none)
    let maximumSpeed: Double?

    /// G-sensor data availability
    let hasAcceleration: Bool

    /// acceleration data points count
    let accelerationPointCount: Int

    /// Impact events number (2.5G or more)
    let impactEventCount: Int

    /// maximum G-Force (nil data none)
    let maximumGForce: Double?

    /// Format distance as human-readable string
    ///
    /// distance   string convert.
    ///
    /// **convert :**
    /// - 1000m or more:  unit convert (number 1er)
    /// - 1000m less than:  unit display (ingnumber)
    ///
    /// **example:**
    /// ```
    /// totalDistance: 450.0m    → "450 m"
    /// totalDistance: 999.9m    → "1000 m"
    /// totalDistance: 1000.0m   → "1.0 km"
    /// totalDistance: 2450.5m   → "2.5 km"
    /// totalDistance: 15832.0m  → "15.8 km"
    /// ```
    ///
    /// **format string:**
    /// - "%.1f km": number 1erto display (2.5 km)
    /// - "%.0f m": number not ingnumber display (450 m)
    ///
    /// **use example:**
    /// ```swift
    /// distanceLabel.text = "driving distance: \(summary.distanceString)"
    /// // output: "driving distance: 2.5 km"
    /// ```
    var distanceString: String {
        if totalDistance >= 1000 {
            // 1000m or more: km unit convert (number 1er)
            return String(format: "%.1f km", totalDistance / 1000)
        } else {
            // 1000m less than: m unit (ingnumber)
            return String(format: "%.0f m", totalDistance)
        }
    }

    /// Format average speed as string
    ///
    /// average speed string convert.
    ///
    /// **format:**
    /// - number 1erto display
    /// - unit: km/h
    /// - data notuh nil return
    ///
    /// **example:**
    /// ```
    /// averageSpeed: 45.3   → "45.3 km/h"
    /// averageSpeed: 68.0   → "68.0 km/h"
    /// averageSpeed: nil    → nil
    /// ```
    ///
    /// **use example:**
    /// ```swift
    /// if let avgSpeed = summary.averageSpeedString {
    ///     speedLabel.text = "average: \(avgSpeed)"
    /// } else {
    ///     speedLabel.text = "average: N/A"
    /// }
    /// ```
    var averageSpeedString: String? {
        guard let speed = averageSpeed else { return nil }
        return String(format: "%.1f km/h", speed)
    }

    /// Format maximum speed as string
    ///
    /// maximum speed string convert.
    ///
    /// **format:**
    /// - number 1erto display
    /// - unit: km/h
    /// - data notuh nil return
    ///
    /// **example:**
    /// ```
    /// maximumSpeed: 68.5   → "68.5 km/h"
    /// maximumSpeed: 120.0  → "120.0 km/h"
    /// maximumSpeed: nil    → nil
    /// ```
    var maximumSpeedString: String? {
        guard let speed = maximumSpeed else { return nil }
        return String(format: "%.1f km/h", speed)
    }

    /// Format maximum G-force as string
    ///
    /// maximum G-Force string convert.
    ///
    /// **format:**
    /// - number 2erto display (ing )
    /// - unit: G
    /// - data notuh nil return
    ///
    /// **example:**
    /// ```
    /// maximumGForce: 1.85   → "1.85 G"
    /// maximumGForce: 3.5    → "3.50 G"
    /// maximumGForce: nil    → nil
    /// ```
    ///
    /// **number 2erin :**
    /// - G-Force 0.01G   available
    /// - 1.85G vs 1.95G:   "one event"only   
    /// - impact minutefrom ing required
    var maximumGForceString: String? {
        guard let gForce = maximumGForce else { return nil }
        return String(format: "%.2f G", gForce)
    }
}

// MARK: - Sample Data

/*
 ───────────────────────────────────────────────────────────────────────────────
 Sample Data - Sample metadata
 ───────────────────────────────────────────────────────────────────────────────

 test, SwiftUI view,   UI check aboveone Sample data.

 【Sample type】

 1. sample: complete metadata
 - GPS data, acceleration data, device information  include
 - Commonin driving 

 2. empty: empty metadata
 - data none status test
 - UI "data none" processing check

 3. gpsOnly: GPSonly  metadata
 - G-Sensor not nine blackbox simulation
 - GPS  UI test

 4. accelerationOnly: G-Sensoronly  metadata
 - GPS number   (, ha etc) simulation
 - impact detection  UI test

 5. withImpact: Impact events include metadata
 - accident video simulation
 - impact detection UI test

 【Usage Example】

 SwiftUI view:
 ```swift
 struct MetadataView_Previews: PreviewProvider {
 static var previews: some View {
 Group {
 MetadataView(metadata: .sample)
 .previewDisplayName("Full Data")

 MetadataView(metadata: .empty)
 .previewDisplayName("No Data")

 MetadataView(metadata: .withImpact)
 .previewDisplayName("With Impact")
 }
 }
 }
 ```

 unit test:
 ```swift
 func testMetadataSummary() {
 let summary = VideoMetadata.sample.summary
 XCTAssertTrue(summary.hasGPS)
 XCTAssertTrue(summary.hasAcceleration)
 XCTAssertGreaterThan(summary.totalDistance, 0)
 }

 func testImpactDetection() {
 let metadata = VideoMetadata.withImpact
 XCTAssertTrue(metadata.hasImpactEvents)
 XCTAssertGreaterThanOrEqual(metadata.impactEvents.count, 1)
 }
 ```

 ───────────────────────────────────────────────────────────────────────────────
 */

extension VideoMetadata {
    /// Sample metadata with GPS and acceleration data
    ///
    /// complete metadata Sample.
    /// GPS data, G-sensor data, device information  include.
    ///
    /// **include data:**
    /// - GPS path (GPSPoint.sampleRoute)
    /// - acceleration data (AccelerationData.sampleData)
    /// - BlackVue DR900X-2CH device information
    static let sample = VideoMetadata(
        gpsPoints: GPSPoint.sampleRoute,
        accelerationData: AccelerationData.sampleData,
        deviceInfo: DeviceInfo(
            manufacturer: "BlackVue",
            model: "DR900X-2CH",
            firmwareVersion: "1.010",
            serialNumber: "BV900X123456",
            recordingMode: "Normal"
        )
    )

    /// Empty metadata (no GPS or acceleration data)
    ///
    /// empty metadata Sample.
    /// GPS G-sensor data  not status.
    ///
    /// **test :**
    /// - "data none" UI status check
    /// - empty array processing  test
    /// - nil processing check
    static let empty = VideoMetadata()

    /// Metadata with GPS only
    ///
    /// GPS dataonly  metadata Sample.
    /// G-sensor data not.
    ///
    /// **simulation :**
    /// - G-Sensor not nine blackbox
    /// - G-Sensor  also enabled
    static let gpsOnly = VideoMetadata(
        gpsPoints: GPSPoint.sampleRoute,
        accelerationData: []
    )

    /// Metadata with acceleration only
    ///
    /// G-sensor dataonly  metadata Sample.
    /// GPS data not.
    ///
    /// **simulation :**
    /// - GPS number   (, haparking)
    /// - GPS  
    /// - GPS enabled settings
    static let accelerationOnly = VideoMetadata(
        gpsPoints: [],
        accelerationData: AccelerationData.sampleData
    )

    /// Metadata with impact event
    ///
    /// Impact events includeed metadata Sample.
    ///
    /// **include event:**
    /// - normal: normal driving (0, 0, 1G)
    /// - braking:  (0, -1.8, 1G)
    /// - impact: Impact events (1.5, -3.5, 0.8G) ★
    /// - normal: impact  normal driving
    ///
    /// **test :**
    /// - impact detection UI display check
    /// - Impact events ingtimeline 
    /// - accident video minute 
    static let withImpact = VideoMetadata(
        gpsPoints: GPSPoint.sampleRoute,
        accelerationData: [
            AccelerationData.normal,
            AccelerationData.braking,
            AccelerationData.impact,
            AccelerationData.normal
        ]
    )
}
