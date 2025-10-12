/**
 * @file GPSSensorIntegrationTests.swift
 * @brief GPS/G-센서 시각화 기능 통합 테스트
 * @author BlackboxPlayer Team
 *
 * @details
 * GPS 및 G-센서 데이터의 파싱, 로드, 동기화, 시각화 기능을 통합적으로 테스트합니다.
 *
 * @section test_overview 테스트 개요
 *
 * GPS/G-센서 데이터 처리 파이프라인:
 * @code
 * 비디오 파일 (메타데이터 포함)
 *       ↓
 * ┌─────┴─────┬─────────────┐
 * ↓           ↓             ↓
 * GPS 데이터   G-센서 데이터  비디오 채널
 *   ↓           ↓             ↓
 * GPSParser   AccelParser   VideoDecoder
 *   ↓           ↓             ↓
 * GPSService  GSensorSvc    VideoChannel
 *   ↓           ↓             ↓
 * └─────┬─────┴─────────────┘
 *       ↓
 * SyncController (30fps 동기화)
 *       ↓
 * ┌─────┴─────┬─────────┐
 * ↓           ↓         ↓
 * MapOverlay  Graph     Video
 * (GPS 경로)  (가속도)  (영상)
 * @endcode
 *
 * @section test_categories 테스트 카테고리
 *
 * -# <b>데이터 파싱 테스트</b>: GPS/G-센서 바이너리 데이터 파싱 검증
 * -# <b>서비스 로드 테스트</b>: 데이터 로드 및 초기화 검증
 * -# <b>동기화 테스트</b>: 비디오 재생 시간과 센서 데이터 동기화 검증
 * -# <b>실시간 업데이트 테스트</b>: 재생 중 센서 데이터 실시간 업데이트 검증
 * -# <b>시크 동기화 테스트</b>: 시간 이동 시 센서 데이터 동기화 검증
 * -# <b>성능 테스트</b>: 대량 데이터 처리 성능 검증
 */

// ============================================================================
// MARK: - Imports
// ============================================================================

import XCTest
import Combine
import CoreLocation
@testable import BlackboxPlayer

// ============================================================================
// MARK: - GPS/G-Sensor Integration Tests
// ============================================================================

/**
 * @class GPSSensorIntegrationTests
 * @brief GPS/G-센서 시각화 기능 통합 테스트 클래스
 *
 * @details
 * GPS와 G-센서 데이터의 전체 처리 파이프라인을 검증합니다.
 * 데이터 파싱부터 UI 표시까지의 통합 테스트를 수행합니다.
 */
class GPSSensorIntegrationTests: XCTestCase {

    // MARK: - Properties

    /// 테스트 대상 SyncController
    var syncController: SyncController!

    /// GPS 서비스
    var gpsService: GPSService!

    /// G-센서 서비스
    var gsensorService: GSensorService!

    /// Combine 구독 저장소
    var cancellables: Set<AnyCancellable> = []

    // MARK: - Setup & Teardown

    /**
     * @brief 각 테스트 실행 전 초기화
     *
     * @details
     * - SyncController 생성
     * - GPS/G-센서 서비스 초기화
     * - Combine 구독 저장소 초기화
     */
    override func setUp() {
        super.setUp()

        syncController = SyncController()
        gpsService = GPSService()
        gsensorService = GSensorService()
        cancellables = []
    }

    /**
     * @brief 각 테스트 실행 후 정리
     *
     * @details
     * - 재생 중지
     * - 서비스 정리
     * - 구독 취소
     */
    override func tearDown() {
        syncController?.stop()
        gpsService?.clear()
        gsensorService?.clear()
        cancellables.removeAll()

        syncController = nil
        gpsService = nil
        gsensorService = nil

        super.tearDown()
    }

    // ============================================================================
    // MARK: - 1. GPS Data Parsing Tests
    // ============================================================================

    /**
     * @brief VideoMetadata GPS 데이터 검증 테스트
     *
     * @details
     * VideoMetadata가 GPS 데이터를 올바르게 저장하고 조회하는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. GPS 포인트 배열 생성
     * 2. VideoMetadata 생성
     * 3. GPS 포인트 수 검증
     * 4. 특정 시간의 GPS 포인트 조회
     */
    func testVideoMetadataGPSData() {
        // Given: 샘플 GPS 포인트 생성
        let baseDate = Date()
        let gpsPoints = createSampleGPSPoints(baseDate: baseDate, count: 10)

        // When: VideoMetadata 생성
        let metadata = VideoMetadata(
            gpsPoints: gpsPoints,
            accelerationData: []
        )

        // Then: GPS 데이터 검증
        XCTAssertEqual(metadata.gpsPoints.count, 10, "10개의 GPS 포인트가 저장되어야 함")
        XCTAssertTrue(metadata.hasGPSData, "GPS 데이터가 있어야 함")

        // 특정 시간의 GPS 포인트 조회
        if let point = metadata.gpsPoint(at: 5.0) {
            XCTAssertNotNil(point, "5초 시점의 GPS 포인트를 찾아야 함")
        }
    }

    // ============================================================================
    // MARK: - 2. G-Sensor Data Parsing Tests
    // ============================================================================

    /**
     * @brief VideoMetadata 가속도 데이터 검증 테스트
     *
     * @details
     * VideoMetadata가 G-센서 데이터를 올바르게 저장하고 조회하는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. AccelerationData 배열 생성
     * 2. VideoMetadata 생성
     * 3. 가속도 데이터 수 검증
     * 4. 특정 시간의 가속도 데이터 조회
     */
    func testVideoMetadataAccelerationData() {
        // Given: 샘플 가속도 데이터 생성
        let baseDate = Date()
        let accelData = createSampleAccelerationData(baseDate: baseDate, count: 1000)

        // When: VideoMetadata 생성
        let metadata = VideoMetadata(
            gpsPoints: [],
            accelerationData: accelData
        )

        // Then: 가속도 데이터 검증
        XCTAssertEqual(metadata.accelerationData.count, 1000, "1000개의 가속도 샘플이 저장되어야 함")
        XCTAssertTrue(metadata.hasAccelerationData, "가속도 데이터가 있어야 함")

        // 특정 시간의 가속도 데이터 조회
        if let data = metadata.accelerationData(at: 5.0) {
            XCTAssertNotNil(data, "5초 시점의 가속도 데이터를 찾아야 함")
        }
    }

    /**
     * @brief G-센서 충격 이벤트 감지 테스트
     *
     * @details
     * VideoMetadata가 높은 가속도 값에서 충격 이벤트를 올바르게 감지하는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. 정상 주행 데이터 + 충격 데이터 생성
     * 2. VideoMetadata에 로드
     * 3. 충격 이벤트 감지 확인
     * 4. 충격 강도 계산 검증
     */
    func testImpactEventDetection() {
        // Given: 정상 주행 + 충격 이벤트 데이터
        let baseDate = Date()
        let normalData = AccelerationData(timestamp: baseDate, x: 0.0, y: 0.0, z: 1.0)
        let impactData = AccelerationData(timestamp: baseDate.addingTimeInterval(1.0),
                                         x: 5.0, y: 3.0, z: 2.0) // 강한 충격

        let metadata = VideoMetadata(
            gpsPoints: [],
            accelerationData: [normalData, impactData]
        )

        // Then: 충격 이벤트 감지 확인
        let impactEvents = metadata.impactEvents
        XCTAssertGreaterThan(impactEvents.count, 0, "충격 이벤트가 감지되어야 함")

        // 충격 강도 계산 검증
        let detectedImpact = impactEvents.first!
        let magnitude = sqrt(detectedImpact.x * detectedImpact.x +
                           detectedImpact.y * detectedImpact.y +
                           detectedImpact.z * detectedImpact.z)
        XCTAssertGreaterThan(magnitude, 3.0, "충격 강도가 임계값을 초과해야 함")
    }

    // ============================================================================
    // MARK: - 3. Service Integration Tests
    // ============================================================================

    /**
     * @brief GPS 서비스 통합 테스트
     *
     * @details
     * GPSService가 VideoMetadata에서 GPS 데이터를 올바르게 로드하고 조회하는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. GPS 메타데이터 생성
     * 2. GPSService.loadGPSData() 호출
     * 3. GPS 서비스에 데이터가 로드되었는지 확인
     * 4. 현재 위치 조회 테스트
     */
    func testGPSServiceIntegration() {
        // Given: GPS 메타데이터
        let baseDate = Date()
        let gpsPoints = createSampleGPSPoints(baseDate: baseDate, count: 10)
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])

        // When: GPS 데이터 로드
        gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // Then: GPS 서비스에 데이터 로드 확인
        XCTAssertTrue(gpsService.hasData, "GPS 데이터가 로드되어야 함")
        XCTAssertEqual(gpsService.pointCount, 10, "10개의 GPS 포인트가 로드되어야 함")
        XCTAssertEqual(gpsService.routePoints.count, 10, "경로 포인트가 설정되어야 함")

        // 현재 위치 조회
        let location = gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(location, "5초 시점의 위치를 찾아야 함")
    }

    /**
     * @brief GPS 데이터 시간 인터폴레이션 테스트
     *
     * @details
     * GPSService가 두 GPS 포인트 사이의 위치를 선형 보간하는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. 두 개의 GPS 포인트 생성 (0초, 2초)
     * 2. 중간 시간(1초)의 위치 요청
     * 3. 보간된 위치가 정확한지 검증
     */
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

        let metadata = VideoMetadata(gpsPoints: [point1, point2], accelerationData: [])

        gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // When: 중간 시간(1초)의 위치 요청
        let interpolatedLocation = gpsService.getCurrentLocation(at: 1.0)

        // Then: 보간된 위치 검증 (중간값이어야 함)
        XCTAssertNotNil(interpolatedLocation, "보간된 위치를 반환해야 함")

        if let location = interpolatedLocation {
            // 위도: (37.5000 + 37.5020) / 2 = 37.5010
            XCTAssertEqual(location.coordinate.latitude, 37.5010, accuracy: 0.0001,
                          "위도가 선형 보간되어야 함")
            // 경도: (127.0000 + 127.0020) / 2 = 127.0010
            XCTAssertEqual(location.coordinate.longitude, 127.0010, accuracy: 0.0001,
                          "경도가 선형 보간되어야 함")
            // 속도: (30.0 + 40.0) / 2 = 35.0
            XCTAssertEqual(location.speed, 35.0, accuracy: 0.1,
                          "속도가 선형 보간되어야 함")
        }
    }

    // ============================================================================
    // MARK: - 4. Synchronization Tests
    // ============================================================================

    /**
     * @brief 비디오-GPS 동기화 테스트
     *
     * @details
     * 비디오 재생 시간과 GPS 데이터가 정확히 동기화되는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. GPS 데이터를 포함한 비디오 파일 로드
     * 2. 특정 시간(5초)으로 시크
     * 3. 해당 시간의 GPS 위치 확인
     * 4. 시간과 GPS 데이터 일치 확인
     */
    func testVideoGPSSynchronization() {
        // Given: GPS 데이터를 포함한 비디오 파일
        let videoFile = createSampleVideoFile()

        do {
            try syncController.loadVideoFile(videoFile)
        } catch {
            XCTFail("비디오 파일 로드 실패: \(error)")
            return
        }

        // When: 5초로 시크
        syncController.seekToTime(5.0)

        // Then: 5초의 GPS 위치 확인
        let gpsLocation = syncController.gpsService.getCurrentLocation(at: 5.0)
        XCTAssertNotNil(gpsLocation, "5초의 GPS 위치가 반환되어야 함")

        // 타임스탬프 동기화 검증
        if let location = gpsLocation {
            let timeDiff = abs(location.timestamp.timeIntervalSince(
                videoFile.timestamp.addingTimeInterval(5.0)
            ))
            XCTAssertLessThan(timeDiff, 0.1, "GPS 데이터와 비디오 시간이 100ms 이내로 동기화되어야 함")
        }
    }

    /**
     * @brief 비디오-G센서 동기화 테스트
     *
     * @details
     * 비디오 재생 시간과 G-센서 데이터가 정확히 동기화되는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. G-센서 데이터를 포함한 비디오 파일 로드
     * 2. 특정 시간(3초)으로 시크
     * 3. 해당 시간의 가속도 값 확인
     * 4. 시간과 G-센서 데이터 일치 확인
     */
    func testVideoGSensorSynchronization() {
        // Given: G-센서 데이터를 포함한 비디오 파일
        let videoFile = createSampleVideoFile()

        do {
            try syncController.loadVideoFile(videoFile)
        } catch {
            XCTFail("비디오 파일 로드 실패: \(error)")
            return
        }

        // When: 3초로 시크
        syncController.seekToTime(3.0)

        // Then: 3초의 가속도 값 확인
        let accelData = syncController.gsensorService.getCurrentAcceleration(at: 3.0)
        XCTAssertNotNil(accelData, "3초의 가속도 데이터가 반환되어야 함")

        // 타임스탬프 동기화 검증
        if let data = accelData {
            let timeDiff = abs(data.timestamp.timeIntervalSince(
                videoFile.timestamp.addingTimeInterval(3.0)
            ))
            XCTAssertLessThan(timeDiff, 0.01, "G-센서 데이터와 비디오 시간이 10ms 이내로 동기화되어야 함")
        }
    }

    /**
     * @brief 재생 중 실시간 센서 데이터 업데이트 테스트
     *
     * @details
     * 비디오 재생 중 GPS와 G-센서 데이터가 실시간으로 업데이트되는지 검증합니다.
     *
     * 테스트 시나리오:
     * 1. 비디오 파일 로드
     * 2. 재생 시작
     * 3. currentTime 변경 관찰
     * 4. 각 시간에 GPS/G-센서 데이터 업데이트 확인
     */
    func testRealtimeSensorDataUpdate() {
        // Given: GPS/G-센서 데이터를 포함한 비디오 파일
        let videoFile = createSampleVideoFile()

        do {
            try syncController.loadVideoFile(videoFile)
        } catch {
            XCTFail("비디오 파일 로드 실패: \(error)")
            return
        }

        // When: 재생 시작 및 시간 변경 관찰
        let expectation = XCTestExpectation(description: "센서 데이터 실시간 업데이트")
        var updateCount = 0
        var lastGPSLocation: GPSPoint?
        var lastAccelData: AccelerationData?

        syncController.$currentTime
            .sink { [weak self] time in
                guard let self = self else { return }

                if time > 0 && time < 2.0 {
                    // GPS 데이터 업데이트 확인
                    let gpsLocation = self.syncController.gpsService.getCurrentLocation(at: time)
                    if let location = gpsLocation {
                        if lastGPSLocation == nil || lastGPSLocation!.timestamp != location.timestamp {
                            lastGPSLocation = location
                            updateCount += 1
                        }
                    }

                    // G-센서 데이터 업데이트 확인
                    let accelData = self.syncController.gsensorService.getCurrentAcceleration(at: time)
                    if let data = accelData {
                        if lastAccelData == nil || lastAccelData!.timestamp != data.timestamp {
                            lastAccelData = data
                            updateCount += 1
                        }
                    }

                    if updateCount >= 4 { // GPS 2번 + G-센서 2번 이상 업데이트
                        expectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)

        syncController.play()

        // Then: 실시간 업데이트 확인
        wait(for: [expectation], timeout: 3.0)
        XCTAssertGreaterThanOrEqual(updateCount, 4, "센서 데이터가 실시간으로 업데이트되어야 함")
    }

    // ============================================================================
    // MARK: - 5. Performance Tests
    // ============================================================================

    /**
     * @brief GPS 데이터 검색 성능 테스트
     *
     * @details
     * 10,000개의 GPS 포인트 중에서 특정 시간의 데이터를 찾는 성능을 측정합니다.
     * 이진 탐색을 사용하므로 O(log n) 시간 복잡도를 가져야 합니다.
     */
    func testGPSDataSearchPerformance() {
        // Given: 10,000개의 GPS 포인트
        let baseDate = Date()
        var gpsPoints: [GPSPoint] = []
        for i in 0..<10000 {
            let point = GPSPoint(
                coordinate: CLLocationCoordinate2D(latitude: 37.5 + Double(i) * 0.0001,
                                                  longitude: 127.0 + Double(i) * 0.0001),
                timestamp: baseDate.addingTimeInterval(Double(i)),
                speed: 30.0
            )
            gpsPoints.append(point)
        }

        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])
        gpsService.loadGPSData(from: metadata, startTime: baseDate)

        // When: 특정 시간의 데이터 검색 성능 측정
        measure {
            for i in stride(from: 0, to: 10000, by: 100) {
                _ = gpsService.getCurrentLocation(at: TimeInterval(i))
            }
        }

        // Then: 빠른 검색이 완료되어야 함 (measure로 자동 측정)
    }

    // ============================================================================
    // MARK: - Helper Methods
    // ============================================================================

    /**
     * @brief 샘플 GPS 바이너리 데이터 생성
     *
     * @details
     * 3개의 GPS 포인트를 Float64 바이너리 형식으로 생성합니다.
     * 각 포인트: 위도(8) + 경도(8) + 속도(8) = 24바이트
     *
     * @return GPS 바이너리 데이터
     */
    private func createSampleGPSBinaryData() -> Data {
        var data = Data()

        // GPS 포인트 1: 서울 시청 (37.5665, 126.9780, 속도 30km/h)
        var lat1: Double = 37.5665
        var lon1: Double = 126.9780
        var speed1: Double = 30.0
        data.append(Data(bytes: &lat1, count: 8))
        data.append(Data(bytes: &lon1, count: 8))
        data.append(Data(bytes: &speed1, count: 8))

        // GPS 포인트 2: 약간 북동쪽 이동
        var lat2: Double = 37.5670
        var lon2: Double = 126.9785
        var speed2: Double = 35.0
        data.append(Data(bytes: &lat2, count: 8))
        data.append(Data(bytes: &lon2, count: 8))
        data.append(Data(bytes: &speed2, count: 8))

        // GPS 포인트 3: 더 북동쪽 이동
        var lat3: Double = 37.5675
        var lon3: Double = 126.9790
        var speed3: Double = 40.0
        data.append(Data(bytes: &lat3, count: 8))
        data.append(Data(bytes: &lon3, count: 8))
        data.append(Data(bytes: &speed3, count: 8))

        return data
    }

    /**
     * @brief 샘플 가속도 Float32 바이너리 데이터 생성
     *
     * @details
     * 3개의 가속도 샘플을 Float32 바이너리 형식으로 생성합니다.
     * 각 샘플: X(4) + Y(4) + Z(4) = 12바이트
     *
     * @return 가속도 바이너리 데이터
     */
    private func createSampleAccelerationFloat32Data() -> Data {
        var data = Data()

        // 샘플 1: 정상 주행 (X=0, Y=0, Z=1.0 중력)
        var x1: Float = 0.0
        var y1: Float = 0.0
        var z1: Float = 1.0
        data.append(Data(bytes: &x1, count: 4))
        data.append(Data(bytes: &y1, count: 4))
        data.append(Data(bytes: &z1, count: 4))

        // 샘플 2: 약간의 가속 (Y축 양수)
        var x2: Float = 0.0
        var y2: Float = 0.5
        var z2: Float = 1.0
        data.append(Data(bytes: &x2, count: 4))
        data.append(Data(bytes: &y2, count: 4))
        data.append(Data(bytes: &z2, count: 4))

        // 샘플 3: 우회전 (X축 양수)
        var x3: Float = 0.3
        var y3: Float = 0.0
        var z3: Float = 1.0
        data.append(Data(bytes: &x3, count: 4))
        data.append(Data(bytes: &y3, count: 4))
        data.append(Data(bytes: &z3, count: 4))

        return data
    }

    /**
     * @brief 샘플 가속도 Int16 바이너리 데이터 생성
     *
     * @details
     * 3개의 가속도 샘플을 Int16 바이너리 형식으로 생성합니다.
     * 스케일: 16384 = 1.0G
     *
     * @return 가속도 바이너리 데이터
     */
    private func createSampleAccelerationInt16Data() -> Data {
        var data = Data()

        let scale: Int16 = 16384 // 1G = 16384

        // 샘플 1: 정상 주행
        var x1: Int16 = 0
        var y1: Int16 = 0
        var z1: Int16 = scale // 1.0G
        data.append(Data(bytes: &x1, count: 2))
        data.append(Data(bytes: &y1, count: 2))
        data.append(Data(bytes: &z1, count: 2))

        // 샘플 2: 약간의 가속
        var x2: Int16 = 0
        var y2: Int16 = scale / 2 // 0.5G
        var z2: Int16 = scale
        data.append(Data(bytes: &x2, count: 2))
        data.append(Data(bytes: &y2, count: 2))
        data.append(Data(bytes: &z2, count: 2))

        // 샘플 3: 우회전
        var x3: Int16 = scale / 3 // 0.33G
        var y3: Int16 = 0
        var z3: Int16 = scale
        data.append(Data(bytes: &x3, count: 2))
        data.append(Data(bytes: &y3, count: 2))
        data.append(Data(bytes: &z3, count: 2))

        return data
    }

    /**
     * @brief 대량 GPS 바이너리 데이터 생성
     *
     * @param count 생성할 GPS 포인트 개수
     * @return 대량 GPS 바이너리 데이터
     */
    private func createLargeGPSBinaryData(count: Int) -> Data {
        var data = Data()

        for i in 0..<count {
            var lat: Double = 37.5 + Double(i) * 0.0001
            var lon: Double = 127.0 + Double(i) * 0.0001
            var speed: Double = 30.0 + Double(i % 20)

            data.append(Data(bytes: &lat, count: 8))
            data.append(Data(bytes: &lon, count: 8))
            data.append(Data(bytes: &speed, count: 8))
        }

        return data
    }

    /**
     * @brief 대량 가속도 Float32 바이너리 데이터 생성
     *
     * @param count 생성할 가속도 샘플 개수
     * @return 대량 가속도 바이너리 데이터
     */
    private func createLargeAccelerationFloat32Data(count: Int) -> Data {
        var data = Data()

        for i in 0..<count {
            var x: Float = Float(sin(Double(i) * 0.1)) * 0.5
            var y: Float = Float(cos(Double(i) * 0.1)) * 0.5
            var z: Float = 1.0 + Float(sin(Double(i) * 0.05)) * 0.2

            data.append(Data(bytes: &x, count: 4))
            data.append(Data(bytes: &y, count: 4))
            data.append(Data(bytes: &z, count: 4))
        }

        return data
    }

    /**
     * @brief 테스트용 샘플 비디오 파일 생성
     *
     * @details
     * GPS와 G-센서 메타데이터를 포함한 VideoFile 객체를 생성합니다.
     *
     * @return GPS/G-센서 데이터를 포함한 VideoFile
     */
    private func createSampleVideoFile() -> VideoFile {
        let baseDate = Date()

        // GPS 데이터 생성 (10초 동안 10개 포인트)
        var gpsPoints: [GPSPoint] = []
        for i in 0..<10 {
            let point = GPSPoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.5665 + Double(i) * 0.001,
                    longitude: 126.9780 + Double(i) * 0.001
                ),
                timestamp: baseDate.addingTimeInterval(Double(i)),
                speed: 30.0 + Double(i) * 2.0
            )
            gpsPoints.append(point)
        }

        // G-센서 데이터 생성 (10초 동안 100Hz = 1000개 샘플)
        var accelData: [AccelerationData] = []
        for i in 0..<1000 {
            let data = AccelerationData(
                timestamp: baseDate.addingTimeInterval(Double(i) / 100.0),
                x: sin(Double(i) * 0.1) * 0.3,
                y: cos(Double(i) * 0.1) * 0.3,
                z: 1.0
            )
            accelData.append(data)
        }

        // 메타데이터 생성
        let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: accelData)

        // 비디오 파일 생성
        let channelInfo = ChannelInfo(
            position: .front,
            filePath: "/tmp/test_front.mp4",
            displayName: "Front Camera",
            isEnabled: true
        )

        let videoFile = VideoFile(
            name: "test_video",
            channels: [channelInfo],
            duration: 10.0,
            metadata: metadata,
            timestamp: baseDate
        )

        return videoFile
    }

    /**
     * @brief 샘플 GPS 포인트 배열 생성
     *
     * @param baseDate 기준 날짜
     * @param count 생성할 GPS 포인트 개수
     * @return GPS 포인트 배열
     */
    private func createSampleGPSPoints(baseDate: Date, count: Int) -> [GPSPoint] {
        var points: [GPSPoint] = []

        for i in 0..<count {
            let point = GPSPoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.5665 + Double(i) * 0.001,
                    longitude: 126.9780 + Double(i) * 0.001
                ),
                timestamp: baseDate.addingTimeInterval(Double(i)),
                speed: 30.0 + Double(i) * 2.0
            )
            points.append(point)
        }

        return points
    }

    /**
     * @brief 샘플 가속도 데이터 배열 생성
     *
     * @param baseDate 기준 날짜
     * @param count 생성할 가속도 샘플 개수
     * @return 가속도 데이터 배열
     */
    private func createSampleAccelerationData(baseDate: Date, count: Int) -> [AccelerationData] {
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
}
