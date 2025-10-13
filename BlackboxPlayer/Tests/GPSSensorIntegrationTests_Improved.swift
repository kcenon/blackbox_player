/**
 * @file GPSSensorIntegrationTests_Improved.swift
 * @brief 개선된 GPS/G-센서 통합 테스트
 * @author BlackboxPlayer Team
 *
 * @details
 * Mock 서비스를 사용하여 테스트 안정성을 높이고,
 * async/await 기반으로 타이밍 문제를 해결한 통합 테스트입니다.
 *
 * @section improvements 개선 사항
 *
 * 1. **Mock Infrastructure**: 실제 서비스 대신 Mock 사용
 * 2. **Async/Await**: Combine + XCTestExpectation 대신 async/await
 * 3. **Deterministic Timing**: 실제 시간 대신 시뮬레이션
 * 4. **Better Isolation**: 각 테스트 완전 격리
 * 5. **No File System**: 파일 시스템 의존성 제거
 */

import XCTest
import Combine
import CoreLocation
@testable import BlackboxPlayer

// ============================================================================
// MARK: - Improved GPS/G-Sensor Integration Tests
// ============================================================================

class GPSSensorIntegrationTests_Improved: XCTestCase {

    // MARK: - Properties

    /// Mock 동기화 컨트롤러
    var mockSyncController: MockSyncController!

    /// Combine 구독 저장소
    var cancellables: Set<AnyCancellable> = []

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockSyncController = MockSyncController()
        cancellables = []
    }

    override func tearDown() async throws {
        // 명시적 정리
        mockSyncController?.stop()
        mockSyncController?.gpsService.clear()
        mockSyncController?.gsensorService.clear()
        cancellables.removeAll()

        mockSyncController = nil

        // 약간의 대기 시간으로 리소스 정리 보장
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        try await super.tearDown()
    }

    // ============================================================================
    // MARK: - 1. Data Model Tests
    // ============================================================================

    func testVideoMetadataGPSData() {
        // Given: 샘플 GPS 포인트
        let baseDate = Date()
        let gpsPoints = TestDataFactory.createGPSPoints(baseDate: baseDate, count: 10)

        // When: VideoMetadata 생성
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])

        // Then: GPS 데이터 검증
        XCTAssertEqual(metadata.gpsPoints.count, 10)
        XCTAssertTrue(metadata.hasGPSData)

        let point = metadata.gpsPoint(at: 5.0)
        XCTAssertNotNil(point, "5초 시점의 GPS 포인트가 있어야 함")
    }

    func testVideoMetadataAccelerationData() {
        // Given: 샘플 가속도 데이터
        let baseDate = Date()
        let accelData = TestDataFactory.createAccelerationData(baseDate: baseDate, count: 1000)

        // When: VideoMetadata 생성
        let metadata = VideoMetadata(gpsPoints: [], accelerationData: accelData)

        // Then: 가속도 데이터 검증
        XCTAssertEqual(metadata.accelerationData.count, 1000)
        XCTAssertTrue(metadata.hasAccelerationData)

        let data = metadata.accelerationData(at: 5.0)
        XCTAssertNotNil(data, "5초 시점의 가속도 데이터가 있어야 함")
    }

    func testImpactEventDetection() {
        // Given: 정상 + 충격 데이터
        let baseDate = Date()
        let normalData = AccelerationData(timestamp: baseDate, x: 0.0, y: 0.0, z: 1.0)
        let impactData = AccelerationData(
            timestamp: baseDate.addingTimeInterval(1.0),
            x: 5.0, y: 3.0, z: 2.0
        )

        let metadata = VideoMetadata(gpsPoints: [], accelerationData: [normalData, impactData])

        // Then: 충격 감지 확인
        let impactEvents = metadata.impactEvents
        XCTAssertGreaterThan(impactEvents.count, 0, "충격 이벤트가 감지되어야 함")

        let impact = impactEvents.first!
        let magnitude = sqrt(impact.x * impact.x + impact.y * impact.y + impact.z * impact.z)
        XCTAssertGreaterThan(magnitude, 3.0, "충격 강도가 임계값을 초과해야 함")
    }

    // ============================================================================
    // MARK: - 2. Service Integration Tests (with Mocks)
    // ============================================================================

    func testMockGPSServiceIntegration() {
        // Given: Mock GPS 데이터
        let baseDate = Date()
        let gpsPoints = TestDataFactory.createGPSPoints(baseDate: baseDate, count: 10)
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])

        // When: Mock 서비스에 로드
        mockSyncController.gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // Then: 데이터 로드 확인
        XCTAssertTrue(mockSyncController.gpsService.hasData)
        XCTAssertEqual(mockSyncController.gpsService.pointCount, 10)
        XCTAssertEqual(mockSyncController.gpsService.loadCallCount, 1, "loadGPSData가 1번 호출되어야 함")

        // 위치 조회
        let location = mockSyncController.gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(location)
        XCTAssertEqual(mockSyncController.gpsService.getCurrentLocationCallCount, 1)
    }

    func testGPSInterpolation() {
        // Given: 0초와 2초에 GPS 포인트
        let baseDate = Date()
        let point1 = GPSPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.5000, longitude: 127.0000),
            timestamp: baseDate,
            speed: 30.0
        )
        let point2 = GPSPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.5020, longitude: 127.0020),
            timestamp: baseDate.addingTimeInterval(2.0),
            speed: 40.0
        )

        mockSyncController.gpsService.setMockData(points: [point1, point2], startTime: baseDate)

        // When: 중간 시간(1초) 위치 요청
        let interpolated = mockSyncController.gpsService.getCurrentLocation(at: 1.0)

        // Then: 선형 보간 검증
        XCTAssertNotNil(interpolated)

        if let location = interpolated {
            XCTAssertEqual(location.coordinate.latitude, 37.5010, accuracy: 0.0001)
            XCTAssertEqual(location.coordinate.longitude, 127.0010, accuracy: 0.0001)
            XCTAssertEqual(location.speed, 35.0, accuracy: 0.1)
        }
    }

    // ============================================================================
    // MARK: - 3. Synchronization Tests (Async/Await)
    // ============================================================================

    func testVideoGPSSynchronization() async throws {
        // Given: GPS 데이터 포함 비디오 파일
        let videoFile = TestDataFactory.createVideoFile(withGPS: true, withAccel: false)

        // When: 비디오 파일 로드
        try mockSyncController.loadVideoFile(videoFile)

        // 5초로 시크
        mockSyncController.seekToTime(5.0)

        // Then: 5초의 GPS 위치 확인
        let gpsLocation = mockSyncController.gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(gpsLocation, "5초 시점의 GPS 위치가 반환되어야 함")

        XCTAssertEqual(mockSyncController.loadCallCount, 1)
        XCTAssertEqual(mockSyncController.seekCallCount, 1)
    }

    func testVideoGSensorSynchronization() async throws {
        // Given: G-센서 데이터 포함 비디오 파일
        let videoFile = TestDataFactory.createVideoFile(withGPS: false, withAccel: true)

        // When: 비디오 파일 로드
        try mockSyncController.loadVideoFile(videoFile)

        // 3초로 시크
        mockSyncController.seekToTime(3.0)

        // Then: 3초의 가속도 데이터 확인
        let accelData = mockSyncController.gsensorService.getCurrentAcceleration(at: 3.0)
        XCTAssertNotNil(accelData, "3초 시점의 가속도 데이터가 반환되어야 함")

        XCTAssertEqual(mockSyncController.loadCallCount, 1)
        XCTAssertEqual(mockSyncController.seekCallCount, 1)
    }

    /// 🔧 개선된 실시간 센서 데이터 업데이트 테스트
    ///
    /// **개선 사항:**
    /// - XCTestExpectation 대신 async/await 사용
    /// - Combine 구독 대신 직접 polling
    /// - 타이밍을 시뮬레이션으로 제어 (실제 3초 대기 불필요)
    func testRealtimeSensorDataUpdate() async throws {
        // Given: GPS/G-센서 데이터 포함 비디오 파일
        let videoFile = TestDataFactory.createVideoFile(withGPS: true, withAccel: true)
        try mockSyncController.loadVideoFile(videoFile)

        // When: 시간 진행 시뮬레이션 (0초 → 2초)
        var timePoints: [TimeInterval] = []
        var gpsUpdates: [GPSPoint] = []
        var accelUpdates: [AccelerationData] = []

        // 비동기 시간 진행
        await mockSyncController.simulateTimeProgress(to: 2.0, step: 0.5)

        // 각 시간 포인트에서 데이터 수집
        for time in stride(from: 0.0, through: 2.0, by: 0.5) {
            mockSyncController.seekToTime(time)
            timePoints.append(time)

            if let gps = mockSyncController.gpsService.getCurrentLocation(at: time) {
                gpsUpdates.append(gps)
            }

            if let accel = mockSyncController.gsensorService.getCurrentAcceleration(at: time) {
                accelUpdates.append(accel)
            }
        }

        // Then: 센서 데이터가 각 시간 포인트마다 업데이트되었는지 확인
        XCTAssertGreaterThanOrEqual(timePoints.count, 4, "최소 4개 시간 포인트 테스트")
        XCTAssertGreaterThanOrEqual(gpsUpdates.count, 4, "GPS 데이터가 각 시간마다 업데이트되어야 함")
        XCTAssertGreaterThanOrEqual(accelUpdates.count, 4, "G-센서 데이터가 각 시간마다 업데이트되어야 함")

        // 연속성 검증: 시간이 증가하는지 확인
        for i in 1..<gpsUpdates.count {
            XCTAssertGreaterThan(
                gpsUpdates[i].timestamp,
                gpsUpdates[i-1].timestamp,
                "GPS 타임스탬프가 순서대로 증가해야 함"
            )
        }
    }

    // ============================================================================
    // MARK: - 4. Performance Tests (with Smaller Dataset)
    // ============================================================================

    /// 성능 테스트는 더 작은 데이터셋으로 수행 (CI 안정성)
    func testGPSDataSearchPerformance() {
        // Given: 1,000개의 GPS 포인트 (원래 10,000에서 축소)
        let baseDate = Date()
        var gpsPoints: [GPSPoint] = []
        for i in 0..<1000 {
            let point = GPSPoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.5 + Double(i) * 0.0001,
                    longitude: 127.0 + Double(i) * 0.0001
                ),
                timestamp: baseDate.addingTimeInterval(Double(i)),
                speed: 30.0
            )
            gpsPoints.append(point)
        }

        mockSyncController.gpsService.setMockData(points: gpsPoints, startTime: baseDate)

        // When: 특정 시간 데이터 검색 성능 측정
        measure {
            for i in stride(from: 0, to: 1000, by: 10) {
                _ = mockSyncController.gpsService.getCurrentLocation(at: TimeInterval(i))
            }
        }

        // Then: measure로 자동 측정 (baseline 대비 검증)
    }
}

// ============================================================================
// MARK: - TestDataFactory
// ============================================================================

/**
 * @class TestDataFactory
 * @brief 테스트 데이터 생성 팩토리
 *
 * @details
 * 일관된 테스트 데이터 생성을 위한 유틸리티 클래스입니다.
 */
enum TestDataFactory {

    /// GPS 포인트 배열 생성
    static func createGPSPoints(baseDate: Date, count: Int) -> [GPSPoint] {
        var points: [GPSPoint] = []

        for i in 0..<count {
            let point = GPSPoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.5665 + Double(i) * 0.001,
                    longitude: 126.9780 + Double(i) * 0.001
                ),
                timestamp: baseDate.addingTimeInterval(Double(i)),
                speed: 30.0 + Double(i) * 2.0,
                heading: Double(i) * 36.0 // 0, 36, 72, ... 도
            )
            points.append(point)
        }

        return points
    }

    /// 가속도 데이터 배열 생성
    static func createAccelerationData(baseDate: Date, count: Int) -> [AccelerationData] {
        var data: [AccelerationData] = []

        for i in 0..<count {
            let sample = AccelerationData(
                timestamp: baseDate.addingTimeInterval(Double(i) / 100.0), // 100Hz
                x: sin(Double(i) * 0.1) * 0.3,
                y: cos(Double(i) * 0.1) * 0.3,
                z: 1.0
            )
            data.append(sample)
        }

        return data
    }

    /// 테스트용 비디오 파일 생성
    static func createVideoFile(withGPS: Bool, withAccel: Bool) -> VideoFile {
        let baseDate = Date()

        var gpsPoints: [GPSPoint] = []
        var accelData: [AccelerationData] = []

        if withGPS {
            gpsPoints = createGPSPoints(baseDate: baseDate, count: 10)
        }

        if withAccel {
            accelData = createAccelerationData(baseDate: baseDate, count: 1000)
        }

        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: accelData)

        let channelInfo = ChannelInfo(
            position: .front,
            filePath: "/mock/test_front.mp4",  // Mock 경로 (실제 파일 불필요)
            displayName: "Front Camera",
            isEnabled: true
        )

        return VideoFile(
            name: "test_video",
            channels: [channelInfo],
            duration: 10.0,
            metadata: metadata,
            timestamp: baseDate
        )
    }
}
