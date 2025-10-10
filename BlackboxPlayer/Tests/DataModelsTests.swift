//
//  DataModelsTests.swift
//  BlackboxPlayerTests
//
//  Unit tests for data models
//

import XCTest
@testable import BlackboxPlayer

final class DataModelsTests: XCTestCase {

    // MARK: - EventType Tests

    func testEventTypeDetection() {
        XCTAssertEqual(EventType.detect(from: "normal/video.mp4"), .normal)
        XCTAssertEqual(EventType.detect(from: "event/video.mp4"), .impact)
        XCTAssertEqual(EventType.detect(from: "parking/video.mp4"), .parking)
        XCTAssertEqual(EventType.detect(from: "manual/video.mp4"), .manual)
        XCTAssertEqual(EventType.detect(from: "emergency/video.mp4"), .emergency)
        XCTAssertEqual(EventType.detect(from: "unknown/video.mp4"), .unknown)
    }

    func testEventTypePriority() {
        XCTAssertTrue(EventType.emergency > EventType.impact)
        XCTAssertTrue(EventType.impact > EventType.normal)
        XCTAssertTrue(EventType.normal > EventType.unknown)
    }

    func testEventTypeDisplayNames() {
        XCTAssertEqual(EventType.normal.displayName, "Normal")
        XCTAssertEqual(EventType.impact.displayName, "Impact")
        XCTAssertEqual(EventType.parking.displayName, "Parking")
    }

    // MARK: - CameraPosition Tests

    func testCameraPositionDetection() {
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_F.mp4"), .front)
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_R.mp4"), .rear)
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_L.mp4"), .left)
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_Ri.mp4"), .right)
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_I.mp4"), .interior)
    }

    func testCameraPositionChannelIndex() {
        XCTAssertEqual(CameraPosition.front.channelIndex, 0)
        XCTAssertEqual(CameraPosition.rear.channelIndex, 1)
        XCTAssertEqual(CameraPosition.left.channelIndex, 2)
        XCTAssertEqual(CameraPosition.right.channelIndex, 3)
        XCTAssertEqual(CameraPosition.interior.channelIndex, 4)
    }

    func testCameraPositionFromChannelIndex() {
        XCTAssertEqual(CameraPosition.from(channelIndex: 0), .front)
        XCTAssertEqual(CameraPosition.from(channelIndex: 1), .rear)
        XCTAssertEqual(CameraPosition.from(channelIndex: 4), .interior)
        XCTAssertNil(CameraPosition.from(channelIndex: 99))
    }

    // MARK: - GPSPoint Tests

    func testGPSPointValidation() {
        let valid = GPSPoint.sample
        XCTAssertTrue(valid.isValid)

        let invalid = GPSPoint(
            timestamp: Date(),
            latitude: 91.0,  // Invalid
            longitude: 0.0
        )
        XCTAssertFalse(invalid.isValid)
    }

    func testGPSPointDistance() {
        let point1 = GPSPoint(timestamp: Date(), latitude: 37.5665, longitude: 126.9780)
        let point2 = GPSPoint(timestamp: Date(), latitude: 37.5667, longitude: 126.9782)

        let distance = point1.distance(to: point2)
        XCTAssertGreaterThan(distance, 0)
        XCTAssertLessThan(distance, 50)  // Should be less than 50 meters
    }

    func testGPSPointSignalStrength() {
        let strongSignal = GPSPoint(
            timestamp: Date(),
            latitude: 37.5665,
            longitude: 126.9780,
            horizontalAccuracy: 5.0,
            satelliteCount: 8
        )
        XCTAssertTrue(strongSignal.hasStrongSignal)

        let weakSignal = GPSPoint(
            timestamp: Date(),
            latitude: 37.5665,
            longitude: 126.9780,
            horizontalAccuracy: 100.0,
            satelliteCount: 3
        )
        XCTAssertFalse(weakSignal.hasStrongSignal)
    }

    // MARK: - AccelerationData Tests

    func testAccelerationMagnitude() {
        let data = AccelerationData(timestamp: Date(), x: 3.0, y: 4.0, z: 0.0)
        XCTAssertEqual(data.magnitude, 5.0, accuracy: 0.01)
    }

    func testAccelerationImpactDetection() {
        XCTAssertFalse(AccelerationData.normal.isImpact)
        XCTAssertFalse(AccelerationData.braking.isImpact)
        XCTAssertTrue(AccelerationData.impact.isImpact)
        XCTAssertTrue(AccelerationData.severeImpact.isSevereImpact)
    }

    func testAccelerationSeverity() {
        XCTAssertEqual(AccelerationData.normal.impactSeverity, .none)
        XCTAssertEqual(AccelerationData.braking.impactSeverity, .moderate)
        XCTAssertEqual(AccelerationData.impact.impactSeverity, .high)
        XCTAssertEqual(AccelerationData.severeImpact.impactSeverity, .severe)
    }

    func testAccelerationDirection() {
        let leftTurn = AccelerationData(timestamp: Date(), x: -2.0, y: 0.5, z: 1.0)
        XCTAssertEqual(leftTurn.primaryDirection, .left)

        let braking = AccelerationData(timestamp: Date(), x: 0.0, y: -3.0, z: 1.0)
        XCTAssertEqual(braking.primaryDirection, .backward)
    }

    // MARK: - ChannelInfo Tests

    func testChannelInfoResolution() {
        let hd = ChannelInfo.frontHD
        XCTAssertEqual(hd.resolutionString, "1920x1080")
        XCTAssertEqual(hd.resolutionName, "Full HD")
        XCTAssertTrue(hd.isHighResolution)
    }

    func testChannelInfoAspectRatio() {
        let hd = ChannelInfo.frontHD
        XCTAssertEqual(hd.aspectRatioString, "16:9")
        XCTAssertEqual(hd.aspectRatio, 16.0/9.0, accuracy: 0.01)
    }

    func testChannelInfoValidation() {
        let valid = ChannelInfo.frontHD
        XCTAssertTrue(valid.isValid)

        let invalid = ChannelInfo(
            position: .front,
            filePath: "",  // Empty path
            width: 0,      // Invalid width
            height: 0,
            frameRate: 0
        )
        XCTAssertFalse(invalid.isValid)
    }

    // MARK: - VideoMetadata Tests

    func testVideoMetadataGPSData() {
        let metadata = VideoMetadata.sample
        XCTAssertTrue(metadata.hasGPSData)
        XCTAssertGreaterThan(metadata.totalDistance, 0)
        XCTAssertNotNil(metadata.averageSpeed)
        XCTAssertNotNil(metadata.maximumSpeed)
    }

    func testVideoMetadataAccelerationData() {
        let metadata = VideoMetadata.sample
        XCTAssertTrue(metadata.hasAccelerationData)
        XCTAssertNotNil(metadata.maximumGForce)
    }

    func testVideoMetadataImpactDetection() {
        let noImpact = VideoMetadata.gpsOnly
        XCTAssertFalse(noImpact.hasImpactEvents)

        let withImpact = VideoMetadata.withImpact
        XCTAssertTrue(withImpact.hasImpactEvents)
        XCTAssertGreaterThan(withImpact.impactEvents.count, 0)
    }

    func testVideoMetadataPointRetrieval() {
        let metadata = VideoMetadata.sample

        // Test GPS point retrieval
        let gpsPoint = metadata.gpsPoint(at: 1.0)
        XCTAssertNotNil(gpsPoint)

        // Test acceleration data retrieval
        let accelData = metadata.accelerationData(at: 1.0)
        XCTAssertNotNil(accelData)
    }

    // MARK: - VideoFile Tests

    func testVideoFileChannelAccess() {
        let video = VideoFile.normal5Channel
        XCTAssertEqual(video.channelCount, 5)
        XCTAssertTrue(video.isMultiChannel)

        XCTAssertNotNil(video.frontChannel)
        XCTAssertNotNil(video.rearChannel)
        XCTAssertTrue(video.hasChannel(.front))
        XCTAssertTrue(video.hasChannel(.rear))
    }

    func testVideoFileProperties() {
        let video = VideoFile.normal5Channel
        XCTAssertEqual(video.eventType, .normal)
        XCTAssertEqual(video.duration, 60.0)
        XCTAssertGreaterThan(video.totalFileSize, 0)
        XCTAssertFalse(video.isFavorite)
    }

    func testVideoFileValidation() {
        let valid = VideoFile.normal5Channel
        XCTAssertTrue(valid.isValid)
        XCTAssertTrue(valid.isPlayable)

        let corrupted = VideoFile.corruptedFile
        XCTAssertFalse(corrupted.isPlayable)
    }

    func testVideoFileMutations() {
        let original = VideoFile.normal5Channel
        XCTAssertFalse(original.isFavorite)

        let favorited = original.withFavorite(true)
        XCTAssertTrue(favorited.isFavorite)
        XCTAssertEqual(favorited.id, original.id)  // Should maintain same ID

        let withNotes = original.withNotes("Test note")
        XCTAssertEqual(withNotes.notes, "Test note")
    }

    func testVideoFileMetadata() {
        let video = VideoFile.normal5Channel
        XCTAssertTrue(video.hasGPSData)
        XCTAssertTrue(video.hasAccelerationData)

        let impactVideo = VideoFile.impact2Channel
        XCTAssertTrue(impactVideo.hasImpactEvents)
    }

    func testVideoFileFormatting() {
        let video = VideoFile.normal5Channel
        XCTAssertFalse(video.durationString.isEmpty)
        XCTAssertFalse(video.timestampString.isEmpty)
        XCTAssertFalse(video.totalFileSizeString.isEmpty)
    }

    // MARK: - Codable Tests

    func testGPSPointCodable() throws {
        let original = GPSPoint.sample
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GPSPoint.self, from: encoded)

        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
    }

    func testAccelerationDataCodable() throws {
        let original = AccelerationData.impact
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AccelerationData.self, from: encoded)

        XCTAssertEqual(decoded.x, original.x)
        XCTAssertEqual(decoded.y, original.y)
        XCTAssertEqual(decoded.z, original.z)
    }

    func testVideoFileCodable() throws {
        let original = VideoFile.normal5Channel
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VideoFile.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.eventType, original.eventType)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.channelCount, original.channelCount)
    }

    // MARK: - Performance Tests

    func testGPSDistanceCalculationPerformance() {
        let points = GPSPoint.sampleRoute

        measure {
            for i in 0..<(points.count - 1) {
                _ = points[i].distance(to: points[i + 1])
            }
        }
    }

    func testVideoMetadataSummaryPerformance() {
        let metadata = VideoMetadata.sample

        measure {
            _ = metadata.summary
        }
    }
}
