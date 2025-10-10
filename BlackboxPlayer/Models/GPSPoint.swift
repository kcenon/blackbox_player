//
//  GPSPoint.swift
//  BlackboxPlayer
//
//  Model for GPS location data point
//

import Foundation
import CoreLocation

/// GPS location data point from dashcam recording
struct GPSPoint: Codable, Equatable, Hashable {
    /// Timestamp of this GPS reading
    let timestamp: Date

    /// Latitude in degrees (-90 to 90)
    let latitude: Double

    /// Longitude in degrees (-180 to 180)
    let longitude: Double

    /// Altitude in meters (optional)
    let altitude: Double?

    /// Speed in kilometers per hour (optional)
    let speed: Double?

    /// Heading/bearing in degrees (0-360, where 0 is North) (optional)
    let heading: Double?

    /// Horizontal accuracy in meters (optional)
    let horizontalAccuracy: Double?

    /// Number of satellites used for this reading (optional)
    let satelliteCount: Int?

    // MARK: - Initialization

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

    /// Convert to CLLocationCoordinate2D for MapKit
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Convert to CLLocation for full location information
    var clLocation: CLLocation {
        return CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy ?? -1,
            verticalAccuracy: -1,
            course: heading ?? -1,
            speed: (speed ?? 0) / 3.6,  // Convert km/h to m/s
            timestamp: timestamp
        )
    }

    /// Create GPSPoint from CLLocation
    /// - Parameter location: CoreLocation CLLocation object
    /// - Returns: GPSPoint instance
    static func from(_ location: CLLocation) -> GPSPoint {
        return GPSPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: location.speed * 3.6,  // Convert m/s to km/h
            heading: location.course >= 0 ? location.course : nil,
            horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            satelliteCount: nil
        )
    }

    // MARK: - Validation

    /// Check if this GPS point has valid coordinates
    var isValid: Bool {
        return latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }

    /// Check if GPS signal is strong (based on accuracy and satellite count)
    var hasStrongSignal: Bool {
        if let accuracy = horizontalAccuracy, accuracy > 50 {
            return false
        }
        if let satellites = satelliteCount, satellites < 4 {
            return false
        }
        return true
    }

    // MARK: - Calculations

    /// Calculate distance to another GPS point in meters
    /// - Parameter other: Another GPS point
    /// - Returns: Distance in meters
    func distance(to other: GPSPoint) -> Double {
        let location1 = clLocation
        let location2 = other.clLocation
        return location1.distance(from: location2)
    }

    /// Calculate bearing to another GPS point in degrees (0-360)
    /// - Parameter other: Another GPS point
    /// - Returns: Bearing in degrees
    func bearing(to other: GPSPoint) -> Double {
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let lon2 = other.longitude * .pi / 180

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Formatting

    /// Format latitude/longitude as DMS (Degrees, Minutes, Seconds)
    var dmsString: String {
        let latDirection = latitude >= 0 ? "N" : "S"
        let lonDirection = longitude >= 0 ? "E" : "W"

        let latDMS = Self.toDMS(abs(latitude))
        let lonDMS = Self.toDMS(abs(longitude))

        return "\(latDMS)\(latDirection), \(lonDMS)\(lonDirection)"
    }

    /// Format as decimal degrees string
    var decimalString: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    /// Format speed with unit
    var speedString: String? {
        guard let speed = speed else { return nil }
        return String(format: "%.1f km/h", speed)
    }

    // MARK: - Private Helpers

    private static func toDMS(_ decimal: Double) -> String {
        let degrees = Int(decimal)
        let minutesDecimal = (decimal - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60

        return String(format: "%d°%d'%.1f\"", degrees, minutes, seconds)
    }
}

// MARK: - Identifiable

extension GPSPoint: Identifiable {
    var id: Date { timestamp }
}

// MARK: - Sample Data

extension GPSPoint {
    /// Sample GPS point for testing (Seoul City Hall)
    static let sample = GPSPoint(
        timestamp: Date(),
        latitude: 37.5665,
        longitude: 126.9780,
        altitude: 15.0,
        speed: 45.0,
        heading: 90.0,
        horizontalAccuracy: 5.0,
        satelliteCount: 8
    )

    /// Array of sample GPS points forming a route
    static let sampleRoute: [GPSPoint] = [
        GPSPoint(timestamp: Date(), latitude: 37.5665, longitude: 126.9780, altitude: 15, speed: 30, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(1), latitude: 37.5667, longitude: 126.9782, altitude: 15, speed: 35, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(2), latitude: 37.5669, longitude: 126.9784, altitude: 16, speed: 40, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(3), latitude: 37.5671, longitude: 126.9786, altitude: 16, speed: 45, heading: 50),
        GPSPoint(timestamp: Date().addingTimeInterval(4), latitude: 37.5673, longitude: 126.9788, altitude: 17, speed: 50, heading: 50)
    ]
}
