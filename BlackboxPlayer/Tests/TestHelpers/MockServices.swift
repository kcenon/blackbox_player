/**
 * @file MockServices.swift
 * @brief Test용 Mock 서비스 구현
 * @author BlackboxPlayer Team
 *
 * @details
 * Integration test에서 사용할 Mock 서비스들을 제공합니다.
 * 실제 서비스의 의존성을 제거하여 테스트 안정성을 높입니다.
 */

import Foundation
import CoreLocation
import Combine
@testable import BlackboxPlayer

// ============================================================================
// MARK: - MockGPSService
// ============================================================================

/**
 * @class MockGPSService
 * @brief GPS 서비스 Mock 구현
 *
 * @details
 * 실제 GPS 데이터 로드 없이 테스트 데이터로 동작하는 Mock 서비스입니다.
 */
class MockGPSService: GPSService {

    // MARK: - Properties

    /// Mock GPS 포인트 저장소
    private var mockGPSPoints: [GPSPoint] = []

    /// Mock 경로 포인트
    private var mockRoutePoints: [CLLocationCoordinate2D] = []

    /// 시작 시간
    private var mockStartTime = Date()

    /// 로드 호출 횟수 (테스트 검증용)
    var loadCallCount: Int = 0

    /// 현재 위치 조회 호출 횟수
    var getCurrentLocationCallCount: Int = 0

    // MARK: - Override Properties

    override var hasData: Bool {
        return !mockGPSPoints.isEmpty
    }

    override var pointCount: Int {
        return mockGPSPoints.count
    }

    override var routePoints: [CLLocationCoordinate2D] {
        return mockRoutePoints
    }

    // MARK: - Mock Methods

    override func loadGPSData(from metadata: VideoMetadata, startTime: Date) {
        loadCallCount += 1
        mockStartTime = startTime
        mockGPSPoints = metadata.gpsPoints
        mockRoutePoints = metadata.gpsPoints.map { $0.coordinate }
    }

    override func getCurrentLocation(at time: TimeInterval) -> GPSPoint? {
        getCurrentLocationCallCount += 1

        guard !mockGPSPoints.isEmpty else { return nil }

        let targetTime = mockStartTime.addingTimeInterval(time)

        // 정확히 일치하는 포인트 찾기
        if let exactPoint = mockGPSPoints.first(where: { $0.timestamp == targetTime }) {
            return exactPoint
        }

        // 선형 보간
        for i in 0..<mockGPSPoints.count - 1 {
            let p1 = mockGPSPoints[i]
            let p2 = mockGPSPoints[i + 1]

            if p1.timestamp <= targetTime && targetTime <= p2.timestamp {
                let ratio = targetTime.timeIntervalSince(p1.timestamp) / p2.timestamp.timeIntervalSince(p1.timestamp)

                let lat = p1.coordinate.latitude + (p2.coordinate.latitude - p1.coordinate.latitude) * ratio
                let lon = p1.coordinate.longitude + (p2.coordinate.longitude - p1.coordinate.longitude) * ratio
                let speed = (p1.speed ?? 0) + ((p2.speed ?? 0) - (p1.speed ?? 0)) * ratio

                return GPSPoint(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    timestamp: targetTime,
                    speed: speed
                )
            }
        }

        // 범위 밖이면 가장 가까운 포인트 반환
        return mockGPSPoints.min(by: {
            abs($0.timestamp.timeIntervalSince(targetTime)) < abs($1.timestamp.timeIntervalSince(targetTime))
        })
    }

    override func clear() {
        mockGPSPoints.removeAll()
        mockRoutePoints.removeAll()
        loadCallCount = 0
        getCurrentLocationCallCount = 0
    }

    // MARK: - Test Helper Methods

    /// 테스트용 GPS 데이터 직접 설정
    func setMockData(points: [GPSPoint], startTime: Date) {
        mockGPSPoints = points
        mockRoutePoints = points.map { $0.coordinate }
        mockStartTime = startTime
    }
}

// ============================================================================
// MARK: - MockGSensorService
// ============================================================================

/**
 * @class MockGSensorService
 * @brief G-센서 서비스 Mock 구현
 */
class MockGSensorService: GSensorService {

    // MARK: - Properties

    /// Mock 가속도 데이터
    private var mockAccelData: [AccelerationData] = []

    /// 시작 시간
    private var mockStartTime = Date()

    /// 로드 호출 횟수
    var loadCallCount: Int = 0

    /// 현재 가속도 조회 호출 횟수
    var getCurrentAccelerationCallCount: Int = 0

    // MARK: - Override Properties

    override var hasData: Bool {
        return !mockAccelData.isEmpty
    }

    override var sampleCount: Int {
        return mockAccelData.count
    }

    // MARK: - Mock Methods

    override func loadAccelerationData(from metadata: VideoMetadata, startTime: Date) {
        loadCallCount += 1
        mockStartTime = startTime
        mockAccelData = metadata.accelerationData
    }

    override func getCurrentAcceleration(at time: TimeInterval) -> AccelerationData? {
        getCurrentAccelerationCallCount += 1

        guard !mockAccelData.isEmpty else { return nil }

        let targetTime = mockStartTime.addingTimeInterval(time)

        // 가장 가까운 샘플 찾기
        return mockAccelData.min(by: {
            abs($0.timestamp.timeIntervalSince(targetTime)) < abs($1.timestamp.timeIntervalSince(targetTime))
        })
    }

    override func clear() {
        mockAccelData.removeAll()
        loadCallCount = 0
        getCurrentAccelerationCallCount = 0
    }

    // MARK: - Test Helper Methods

    /// 테스트용 가속도 데이터 직접 설정
    func setMockData(data: [AccelerationData], startTime: Date) {
        mockAccelData = data
        mockStartTime = startTime
    }
}

// ============================================================================
// MARK: - MockVideoDecoder
// ============================================================================

/**
 * @class MockVideoDecoder
 * @brief 비디오 디코더 Mock 구현
 *
 * @details
 * 실제 비디오 파일 없이 테스트용 프레임을 생성합니다.
 */
class MockVideoDecoder {

    // MARK: - Properties

    /// Mock 비디오 duration
    var duration: TimeInterval = 10.0

    /// FPS
    var fps: Double = 30.0

    /// 디코딩 호출 횟수
    var decodeCallCount: Int = 0

    /// Seek 호출 횟수
    var seekCallCount: Int = 0

    // MARK: - Methods

    /// Mock 프레임 생성
    func createMockFrame(at time: TimeInterval) -> VideoFrame? {
        decodeCallCount += 1

        guard time >= 0 && time <= duration else { return nil }

        // Mock CVPixelBuffer 생성 (실제로는 더미)
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            1920, 1080,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        return VideoFrame(
            pixelBuffer: buffer,
            timestamp: time,
            duration: 1.0 / fps
        )
    }

    func seek(to time: TimeInterval) {
        seekCallCount += 1
    }
}

// ============================================================================
// MARK: - MockSyncController
// ============================================================================

/**
 * @class MockSyncController
 * @brief 동기화 컨트롤러 Mock 구현
 */
class MockSyncController {

    // MARK: - Properties

    /// 현재 재생 시간 (Published)
    @Published var currentTime: TimeInterval = 0.0

    /// 재생 중 여부
    @Published var isPlaying: Bool = false

    /// GPS 서비스
    var gpsService: MockGPSService

    /// G-센서 서비스
    var gsensorService: MockGSensorService

    /// 비디오 파일
    var videoFile: VideoFile?

    /// 로드 호출 횟수
    var loadCallCount: Int = 0

    /// Play 호출 횟수
    var playCallCount: Int = 0

    /// Seek 호출 횟수
    var seekCallCount: Int = 0

    // MARK: - Initialization

    init() {
        self.gpsService = MockGPSService()
        self.gsensorService = MockGSensorService()
    }

    // MARK: - Methods

    func loadVideoFile(_ file: VideoFile) throws {
        loadCallCount += 1
        videoFile = file

        if let metadata = file.metadata {
            gpsService.loadGPSData(from: metadata, startTime: file.timestamp)
            gsensorService.loadAccelerationData(from: metadata, startTime: file.timestamp)
        }
    }

    func play() {
        playCallCount += 1
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentTime = 0.0
    }

    func seekToTime(_ time: TimeInterval) {
        seekCallCount += 1
        currentTime = time
    }

    /// 테스트용 시간 시뮬레이션
    func simulateTimeProgress(to targetTime: TimeInterval, step: TimeInterval = 0.1) async {
        var time: TimeInterval = 0.0
        while time <= targetTime {
            currentTime = time
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
            time += step
        }
        currentTime = targetTime
    }
}
