/// @file VideoMetadata.swift
/// @brief 블랙박스 비디오 메타데이터 모델 (GPS 및 G-센서)
/// @author BlackboxPlayer Development Team
///
/// Model for video file metadata (GPS and G-Sensor data)

import Foundation

/*
 ═══════════════════════════════════════════════════════════════════════════════
 VideoMetadata - 비디오 메타데이터 컨테이너
 ═══════════════════════════════════════════════════════════════════════════════

 【개요】
 VideoMetadata는 블랙박스 영상 파일과 함께 기록된 GPS 위치 정보와 G-센서 가속도 데이터를
 통합 관리하는 컨테이너 구조체입니다. 영상 재생 중 실시간으로 위치와 충격 정보를 표시하고,
 주행 거리, 평균 속도, 최대 충격 등의 통계를 계산할 수 있습니다.

 【메타데이터(Metadata)란?】

 메타데이터는 "데이터에 관한 데이터"를 의미합니다.

 비유:
 - 책의 목차, 색인, ISBN 번호 → 책(데이터)에 대한 정보(메타데이터)
 - 사진의 EXIF 정보 → 촬영 일시, 카메라 모델, GPS 위치 등
 - 영상의 메타데이터 → 해상도, 길이, 코덱, GPS/센서 데이터 등

 블랙박스에서의 메타데이터:
 - 영상 파일(.mp4): 실제 동영상 데이터
 - GPS 데이터: 주행 경로, 속도 정보
 - G-센서 데이터: 충격, 급가속/급제동 정보
 - 장치 정보: 블랙박스 모델, 펌웨어 버전

 【시계열 데이터(Time-Series Data)】

 시계열 데이터는 시간 순서대로 기록된 데이터입니다.

 타임라인 구조:

 영상 시작                                                      영상 종료
 ├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
 0초  5초  10초 15초 20초 25초 30초 35초 40초 45초 50초

 GPS:  ●    ●    ●    ●    ●    ●    ●    ●    ●    ●
 (위치, 속도 기록 - 일반적으로 1초마다)

 G센서: ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
 (가속도 기록 - 일반적으로 0.1초마다, 10Hz)

 특징:
 1. 시간 순서 보존 (먼저 기록된 것이 배열 앞에 위치)
 2. 균일한 간격 또는 불균일한 간격 (GPS는 1초, 센서는 0.1초 등)
 3. 시간 기반 검색 (특정 시점의 데이터 찾기)
 4. 집계 연산 (평균, 최대값, 합계 등)

 【구조 다이어그램】

 VideoMetadata
 ├─ gpsPoints: [GPSPoint]           ← GPS 시계열 데이터
 │   ├─ GPSPoint(timestamp: 0초, lat: 37.5, lon: 127.0, speed: 30)
 │   ├─ GPSPoint(timestamp: 1초, lat: 37.501, lon: 127.001, speed: 35)
 │   └─ GPSPoint(timestamp: 2초, lat: 37.502, lon: 127.002, speed: 40)
 │
 ├─ accelerationData: [AccelerationData] ← G-센서 시계열 데이터
 │   ├─ AccelerationData(timestamp: 0.0초, x: 0, y: 0, z: 1)
 │   ├─ AccelerationData(timestamp: 0.1초, x: 0.1, y: 0, z: 1)
 │   └─ AccelerationData(timestamp: 0.2초, x: 0.2, y: -0.5, z: 1)
 │
 └─ deviceInfo: DeviceInfo?         ← 장치 정보
 ├─ manufacturer: "BlackVue"
 ├─ model: "DR900X-2CH"
 └─ firmwareVersion: "1.010"

 【사용 예시】

 1. GPS 데이터 조회:
 ```swift
 let metadata = VideoMetadata.sample

 // 특정 시점의 위치 찾기
 if let point = metadata.gpsPoint(at: 15.5) {
 print("15.5초 시점 위치: \(point.latitude), \(point.longitude)")
 print("속도: \(point.speedString)")
 }

 // 주행 거리 계산
 print("총 주행 거리: \(metadata.summary.distanceString)")  // "2.5 km"

 // 속도 통계
 print("평균 속도: \(metadata.summary.averageSpeedString ?? "N/A")")  // "45.3 km/h"
 print("최고 속도: \(metadata.summary.maximumSpeedString ?? "N/A")")  // "68.5 km/h"
 ```

 2. 충격 이벤트 분석:
 ```swift
 let metadata = VideoMetadata.withImpact

 // 충격 이벤트 존재 여부
 if metadata.hasImpactEvents {
 print("⚠️ 충격 이벤트 감지됨!")

 // 모든 충격 이벤트 조회
 for event in metadata.impactEvents {
 print("충격 시간: \(event.timestamp)")
 print("충격 강도: \(String(format: "%.2f G", event.magnitude))")
 print("충격 방향: \(event.primaryDirection.displayName)")
 print("심각도: \(event.severity.displayName)")
 }
 }

 // 최대 G-Force
 if let maxG = metadata.maximumGForce {
 print("최대 충격: \(String(format: "%.2f G", maxG))")
 }
 ```

 3. 통합 요약 정보:
 ```swift
 let summary = metadata.summary

 print("=== 메타데이터 요약 ===")
 print("GPS 데이터: \(summary.hasGPS ? "있음" : "없음") (\(summary.gpsPointCount)개 포인트)")
 print("주행 거리: \(summary.distanceString)")
 print("평균 속도: \(summary.averageSpeedString ?? "N/A")")
 print("가속도 데이터: \(summary.hasAcceleration ? "있음" : "없음") (\(summary.accelerationPointCount)개 포인트)")
 print("충격 이벤트: \(summary.impactEventCount)회")
 print("최대 G-Force: \(summary.maximumGForceString ?? "N/A")")
 ```

 【Codable 프로토콜】

 VideoMetadata는 Codable을 채택하여 JSON 형태로 저장/로드할 수 있습니다.

 JSON 구조 예시:
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

 저장/로드 예시:
 ```swift
 // JSON 파일로 저장
 let encoder = JSONEncoder()
 encoder.dateEncodingStrategy = .iso8601
 let jsonData = try encoder.encode(metadata)
 try jsonData.write(to: metadataFileURL)

 // JSON 파일에서 로드
 let decoder = JSONDecoder()
 decoder.dateDecodingStrategy = .iso8601
 let loadedData = try Data(contentsOf: metadataFileURL)
 let metadata = try decoder.decode(VideoMetadata.self, from: loadedData)
 ```

 【성능 고려사항】

 1. 메모리 사용량:
 - GPS 데이터: 1시간 녹화 = 약 3,600개 포인트 (1초당 1개)
 - G-센서 데이터: 1시간 녹화 = 약 36,000개 포인트 (10Hz 샘플링)
 - 예상 메모리: GPS 약 500KB, 센서 약 2MB (1시간 기준)

 2. 검색 최적화:
 - gpsPoint(at:)와 accelerationData(at:)는 O(n) 선형 검색 사용
 - 자주 조회하는 경우 이진 검색(Binary Search) 고려 가능
 - 배열이 이미 시간순 정렬되어 있으므로 이진 검색 적용 가능

 3. 필터링 최적화:
 - impactEvents는 매번 필터링하므로 캐싱 고려
 - 큰 데이터셋의 경우 lazy 연산 사용

 ═══════════════════════════════════════════════════════════════════════════════
 */

/// @struct VideoMetadata
/// @brief 블랙박스 영상 메타데이터 컨테이너
///
/// Metadata associated with a dashcam video file
///
/// 블랙박스 영상 파일에 포함된 메타데이터를 나타내는 구조체입니다.
/// GPS 위치 정보, G-센서 가속도 데이터, 장치 정보를 통합 관리하며,
/// 주행 분석과 충격 감지를 위한 다양한 메서드를 제공합니다.
///
/// **주요 기능:**
/// - GPS 시계열 데이터 관리 및 조회
/// - G-센서 가속도 데이터 관리 및 분석
/// - 주행 통계 계산 (거리, 속도)
/// - 충격 이벤트 검출
/// - 통합 요약 정보 생성
///
/// **데이터 구조:**
/// ```
/// VideoMetadata
///   ├─ gpsPoints: [GPSPoint]              (GPS 시계열)
///   ├─ accelerationData: [AccelerationData] (센서 시계열)
///   └─ deviceInfo: DeviceInfo?             (장치 정보)
/// ```
///
/// **사용 예시:**
/// ```swift
/// // 메타데이터 생성
/// let metadata = VideoMetadata(
///     gpsPoints: gpsArray,
///     accelerationData: sensorArray,
///     deviceInfo: device
/// )
///
/// // 특정 시점 데이터 조회
/// let gps = metadata.gpsPoint(at: 15.5)     // 15.5초 시점의 GPS
/// let acc = metadata.accelerationData(at: 15.5) // 15.5초 시점의 가속도
///
/// // 통계 조회
/// print("주행 거리: \(metadata.totalDistance)m")
/// print("평균 속도: \(metadata.averageSpeed ?? 0)km/h")
/// print("충격 횟수: \(metadata.impactEvents.count)회")
/// ```
struct VideoMetadata: Codable, Equatable, Hashable {
    /// @var gpsPoints
    /// @brief GPS 시계열 데이터 배열
    ///
    /// GPS data points throughout the recording
    ///
    /// 녹화 중 기록된 GPS 위치 정보 배열입니다.
    ///
    /// **시계열 데이터 특성:**
    /// - 시간 순서대로 정렬됨 (timestamp 기준 오름차순)
    /// - 일반적으로 1초 간격으로 기록 (1Hz 샘플링)
    /// - 각 포인트에는 위도, 경도, 속도, 고도 등이 포함
    ///
    /// **데이터 크기 예상:**
    /// - 1분 녹화: 약 60개 포인트
    /// - 1시간 녹화: 약 3,600개 포인트
    /// - 메모리: 1시간당 약 500KB
    ///
    /// **배열 예시:**
    /// ```
    /// [0] GPSPoint(timestamp: 2025-10-12 14:30:00, lat: 37.5665, lon: 126.9780, speed: 45.5)
    /// [1] GPSPoint(timestamp: 2025-10-12 14:30:01, lat: 37.5666, lon: 126.9781, speed: 46.0)
    /// [2] GPSPoint(timestamp: 2025-10-12 14:30:02, lat: 37.5667, lon: 126.9782, speed: 47.2)
    /// ...
    /// ```
    let gpsPoints: [GPSPoint]

    /// @var accelerationData
    /// @brief G-센서 시계열 데이터 배열
    ///
    /// G-Sensor acceleration data throughout the recording
    ///
    /// 녹화 중 기록된 G-센서 가속도 데이터 배열입니다.
    ///
    /// **시계열 데이터 특성:**
    /// - 시간 순서대로 정렬됨 (timestamp 기준 오름차순)
    /// - 일반적으로 0.1초 간격으로 기록 (10Hz 샘플링)
    /// - GPS보다 10배 높은 샘플링 레이트
    /// - 각 포인트에는 X, Y, Z 3축 가속도 값 포함
    ///
    /// **데이터 크기 예상:**
    /// - 1분 녹화: 약 600개 포인트 (10Hz × 60초)
    /// - 1시간 녹화: 약 36,000개 포인트
    /// - 메모리: 1시간당 약 2MB
    ///
    /// **샘플링 레이트 비교:**
    /// ```
    /// GPS:     ●     ●     ●     ●     ●  (1Hz, 1초 간격)
    /// G-센서: ●●●●●●●●●●●●●●●●●●●● (10Hz, 0.1초 간격)
    /// ```
    let accelerationData: [AccelerationData]

    /// @var deviceInfo
    /// @brief 블랙박스 장치 정보 (옵셔널)
    ///
    /// Device/dashcam information (optional)
    ///
    /// 블랙박스 장치 정보입니다.
    ///
    /// **포함 정보:**
    /// - manufacturer: 제조사 (예: "BlackVue", "Thinkware")
    /// - model: 모델명 (예: "DR900X-2CH")
    /// - firmwareVersion: 펌웨어 버전 (예: "1.010")
    /// - serialNumber: 시리얼 번호
    /// - recordingMode: 녹화 모드 (예: "Normal", "Parking")
    ///
    /// **옵셔널인 이유:**
    /// - 구형 블랙박스는 장치 정보를 기록하지 않을 수 있음
    /// - 파일 포맷에 따라 장치 정보가 없을 수 있음
    /// - 없어도 GPS/센서 데이터 분석에는 문제 없음
    ///
    /// **사용 예시:**
    /// ```swift
    /// if let device = metadata.deviceInfo {
    ///     print("제조사: \(device.manufacturer ?? "알 수 없음")")
    ///     print("모델: \(device.model ?? "알 수 없음")")
    ///     print("펌웨어: \(device.firmwareVersion ?? "알 수 없음")")
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

    /// @brief GPS 데이터 유무 확인
    /// @return GPS 데이터가 있으면 true
    ///
    /// Check if GPS data is available
    ///
    /// GPS 데이터가 있는지 확인합니다.
    ///
    /// **체크 로직:**
    /// - gpsPoints 배열이 비어있지 않으면 true
    /// - 배열이 비어있으면 false
    ///
    /// **isEmpty vs count == 0:**
    /// - isEmpty는 배열의 전용 프로퍼티로 가독성이 좋음
    /// - 내부적으로 count == 0과 동일하게 동작
    /// - Swift 컨벤션에서는 isEmpty 사용 권장
    ///
    /// **사용 예시:**
    /// ```swift
    /// if metadata.hasGPSData {
    ///     // GPS 관련 UI 표시
    ///     showMapView()
    ///     showSpeedInfo()
    /// } else {
    ///     // GPS 데이터 없음 안내
    ///     showNoGPSMessage()
    /// }
    /// ```
    var hasGPSData: Bool {
        return !gpsPoints.isEmpty
    }

    /// @brief 특정 시점의 GPS 포인트 검색
    /// @param timeOffset 영상 시작부터의 시간 오프셋 (초)
    /// @return 가장 가까운 GPS 포인트 또는 nil
    ///
    /// Get GPS point at specific time offset
    /// - Parameter timeOffset: Time offset in seconds from start of video
    /// - Returns: Closest GPS point or nil
    ///
    /// 영상의 특정 시점에 해당하는 GPS 포인트를 찾습니다.
    ///
    /// **알고리즘: 최근접 포인트 검색 (Nearest Point Search)**
    ///
    /// 단계:
    /// 1. gpsPoints가 비어있으면 nil 반환 (데이터 없음)
    /// 2. 첫 번째 GPS 포인트의 타임스탬프를 기준점(t0)으로 설정
    /// 3. 각 포인트의 상대 시간 계산: (포인트 타임스탬프 - t0)
    /// 4. 요청한 timeOffset과의 시간 차이 계산: |상대 시간 - timeOffset|
    /// 5. 시간 차이가 가장 작은 포인트 반환
    ///
    /// **시간 차이 계산 예시:**
    /// ```
    /// gpsPoints:
    ///   [0] timestamp: 14:30:00 (t0) → 상대 시간: 0초
    ///   [1] timestamp: 14:30:01      → 상대 시간: 1초
    ///   [2] timestamp: 14:30:02      → 상대 시간: 2초
    ///   [3] timestamp: 14:30:03      → 상대 시간: 3초
    ///
    /// 요청: timeOffset = 2.3초
    ///
    /// 시간 차이 계산:
    ///   [0] |0 - 2.3| = 2.3초
    ///   [1] |1 - 2.3| = 1.3초
    ///   [2] |2 - 2.3| = 0.3초  ← 최소! (가장 가까움)
    ///   [3] |3 - 2.3| = 0.7초
    ///
    /// 결과: gpsPoints[2] 반환
    /// ```
    ///
    /// **시간 복잡도:**
    /// - O(n): 모든 포인트를 순회하며 최소값 탐색
    /// - n = gpsPoints.count
    ///
    /// **최적화 가능성:**
    /// - 배열이 시간순 정렬되어 있으므로 이진 검색(Binary Search) 가능 → O(log n)
    /// - 자주 호출되는 경우 이진 검색으로 최적화 고려
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 영상 15.5초 시점의 위치 찾기
    /// if let gps = metadata.gpsPoint(at: 15.5) {
    ///     print("위치: \(gps.latitude), \(gps.longitude)")
    ///     print("속도: \(gps.speedString)")
    ///
    ///     // 지도에 마커 표시
    ///     mapView.showMarker(at: gps.coordinate)
    /// }
    ///
    /// // 영상 재생 중 실시간 위치 업데이트
    /// func updateGPSDisplay(currentTime: TimeInterval) {
    ///     if let gps = metadata.gpsPoint(at: currentTime) {
    ///         speedLabel.text = gps.speedString
    ///         mapView.centerCoordinate = gps.coordinate
    ///     }
    /// }
    /// ```
    func gpsPoint(at timeOffset: TimeInterval) -> GPSPoint? {
        // 1. GPS 데이터가 없으면 nil 반환
        guard !gpsPoints.isEmpty else { return nil }

        // 2. 포인트가 하나만 있으면 그것을 반환
        guard gpsPoints.count > 1 else { return gpsPoints.first }

        let baseTime = gpsPoints[0].timestamp

        // 3. timeOffset에 해당하는 두 포인트 찾기 (선형 보간용)
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

        // 4. 보간 수행
        if let before = beforePoint, let after = afterPoint {
            // 두 포인트 사이 - 선형 보간
            let t1 = before.timestamp.timeIntervalSince(baseTime)
            let t2 = after.timestamp.timeIntervalSince(baseTime)
            let ratio = (timeOffset - t1) / (t2 - t1)

            // 위도, 경도, 속도 보간
            let lat = before.latitude + (after.latitude - before.latitude) * ratio
            let lon = before.longitude + (after.longitude - before.longitude) * ratio
            let speed = (before.speed ?? 0) + ((after.speed ?? 0) - (before.speed ?? 0)) * ratio

            // 보간된 타임스탬프
            let interpolatedTime = baseTime.addingTimeInterval(timeOffset)

            return GPSPoint(
                timestamp: interpolatedTime,
                latitude: lat,
                longitude: lon,
                speed: speed
            )
        } else if let before = beforePoint {
            // timeOffset이 마지막 포인트 이후 - 마지막 포인트 반환
            return before
        } else if let after = afterPoint {
            // timeOffset이 첫 포인트 이전 - 첫 포인트 반환
            return after
        }

        return nil
    }

    /// @brief 총 주행 거리 계산
    /// @return 총 주행 거리 (미터)
    ///
    /// Calculate total distance traveled
    ///
    /// GPS 데이터를 기반으로 총 주행 거리를 계산합니다.
    ///
    /// **알고리즘: 연속 포인트 간 거리 합산**
    ///
    /// 단계:
    /// 1. GPS 포인트가 2개 미만이면 0 반환 (거리 계산 불가)
    /// 2. 인접한 두 포인트 간 거리를 순차적으로 계산
    /// 3. 모든 구간 거리를 합산하여 총 거리 산출
    ///
    /// **거리 계산 방식:**
    /// ```
    /// GPS 경로:  A ─────▶ B ─────▶ C ─────▶ D
    ///           (100m)   (150m)   (200m)
    ///
    /// 총 거리 = distance(A→B) + distance(B→C) + distance(C→D)
    ///        = 100 + 150 + 200
    ///        = 450m
    /// ```
    ///
    /// **Haversine 공식 사용:**
    /// - GPSPoint.distance(to:) 메서드는 Haversine 공식 사용
    /// - 지구를 구체로 가정하여 두 좌표 간 최단 거리 계산
    /// - 결과는 미터(m) 단위
    ///
    /// **루프 구조:**
    /// ```swift
    /// // 배열 인덱스: 0, 1, 2, 3, ..., n-1
    /// // 구간: (0→1), (1→2), (2→3), ..., (n-2→n-1)
    /// // 총 n-1개 구간
    ///
    /// for i in 0..<(gpsPoints.count - 1) {
    ///     // i번째와 i+1번째 포인트 간 거리 계산
    ///     total += gpsPoints[i].distance(to: gpsPoints[i + 1])
    /// }
    /// ```
    ///
    /// **정확도 고려사항:**
    /// - GPS 샘플링 주기: 1초 간격 (일반적)
    /// - 속도 60km/h일 때 1초에 약 16.7m 이동
    /// - 급커브에서는 실제 주행 거리보다 약간 짧게 측정될 수 있음
    /// - 직선 거리 합산이므로 도로의 세밀한 굴곡은 반영 안 됨
    ///
    /// **사용 예시:**
    /// ```swift
    /// let distance = metadata.totalDistance
    /// print("총 주행 거리: \(distance)m")  // 예: 2450.5m
    ///
    /// // 킬로미터 변환
    /// let km = distance / 1000.0
    /// print("총 주행 거리: \(String(format: "%.1f", km))km")  // 예: 2.5km
    ///
    /// // MetadataSummary에서 포맷된 문자열 사용
    /// print(metadata.summary.distanceString)  // "2.5 km"
    /// ```
    var totalDistance: Double {
        // 1. GPS 포인트가 2개 미만이면 거리 계산 불가 → 0 반환
        guard gpsPoints.count >= 2 else { return 0 }

        // 2. 누적 거리를 저장할 변수 초기화
        var total: Double = 0

        // 3. 인접한 두 포인트 간 거리를 순차적으로 합산
        // i는 0부터 (count - 2)까지 순회
        // 예: count가 5이면 i는 0, 1, 2, 3 (총 4개 구간)
        for i in 0..<(gpsPoints.count - 1) {
            // i번째 포인트에서 i+1번째 포인트까지의 거리 계산 후 누적
            total += gpsPoints[i].distance(to: gpsPoints[i + 1])
        }

        // 4. 총 거리 반환 (단위: 미터)
        return total
    }

    /// @brief 평균 속도 계산
    /// @return 평균 속도 (km/h) 또는 nil
    ///
    /// Calculate average speed from GPS data
    ///
    /// GPS 데이터를 기반으로 평균 속도를 계산합니다.
    ///
    /// **알고리즘: 산술 평균 (Arithmetic Mean)**
    ///
    /// 공식:
    /// ```
    /// 평균 속도 = (v1 + v2 + v3 + ... + vn) / n
    ///
    /// v1, v2, v3, ..., vn: 각 GPS 포인트의 속도
    /// n: 속도 데이터가 있는 포인트 개수
    /// ```
    ///
    /// **compactMap 사용:**
    /// - GPS 포인트의 speed는 옵셔널 (Double?)
    /// - compactMap은 nil을 제외하고 값이 있는 것만 배열로 변환
    /// - 예: [30.5, nil, 45.2, nil, 50.0] → [30.5, 45.2, 50.0]
    ///
    /// **옵셔널 반환:**
    /// - 속도 데이터가 하나도 없으면 nil 반환
    /// - 평균 계산이 불가능한 경우 (0으로 나누기 방지)
    ///
    /// **reduce 함수:**
    /// ```swift
    /// speeds.reduce(0, +)
    ///   = speeds[0] + speeds[1] + speeds[2] + ...
    ///   = 모든 속도의 합
    ///
    /// 초기값: 0
    /// 연산: + (덧셈)
    /// ```
    ///
    /// **계산 예시:**
    /// ```
    /// GPS 포인트:
    ///   [0] speed: 30.5 km/h
    ///   [1] speed: nil (GPS 신호 약함)
    ///   [2] speed: 45.2 km/h
    ///   [3] speed: nil
    ///   [4] speed: 50.0 km/h
    ///   [5] speed: 42.8 km/h
    ///
    /// compactMap 후: [30.5, 45.2, 50.0, 42.8]
    ///
    /// 합계: 30.5 + 45.2 + 50.0 + 42.8 = 168.5
    /// 평균: 168.5 / 4 = 42.125 km/h
    /// ```
    ///
    /// **주의사항:**
    /// - 정차 시간도 평균에 포함됨 (속도 0 포함)
    /// - 실제 "주행 평균 속도"를 원한다면 속도 > 0인 것만 필터링 필요
    /// - 신호등 대기, 정체 구간이 많으면 평균 속도 낮아짐
    ///
    /// **사용 예시:**
    /// ```swift
    /// if let avgSpeed = metadata.averageSpeed {
    ///     print("평균 속도: \(String(format: "%.1f", avgSpeed))km/h")
    ///
    ///     // UI에 표시
    ///     averageSpeedLabel.text = metadata.summary.averageSpeedString  // "42.1 km/h"
    /// } else {
    ///     print("속도 데이터 없음")
    /// }
    ///
    /// // 이동 중 평균 속도 (정차 제외)
    /// let movingAverage = gpsPoints
    ///     .compactMap { $0.speed }
    ///     .filter { $0 > 5.0 }  // 5km/h 이상만 (정차 제외)
    ///     .reduce(0, +) / Double(movingAverage.count)
    /// ```
    var averageSpeed: Double? {
        // 1. GPS 포인트에서 nil이 아닌 속도 값만 추출
        let speeds = gpsPoints.compactMap { $0.speed }

        // 2. 속도 데이터가 없으면 nil 반환
        guard !speeds.isEmpty else { return nil }

        // 3. 모든 속도의 합을 구하고 개수로 나누어 평균 계산
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    /// @brief 최고 속도 계산
    /// @return 최고 속도 (km/h) 또는 nil
    ///
    /// Calculate maximum speed from GPS data
    ///
    /// GPS 데이터에서 최고 속도를 찾습니다.
    ///
    /// **알고리즘: 최대값 탐색**
    ///
    /// 단계:
    /// 1. GPS 포인트에서 nil이 아닌 속도 값만 추출 (compactMap)
    /// 2. 속도 배열에서 최대값 찾기 (max())
    /// 3. 속도 데이터가 없으면 nil 반환
    ///
    /// **max() 메서드:**
    /// - 배열의 최대값을 반환하는 표준 메서드
    /// - 배열이 비어있으면 nil 반환
    /// - 시간 복잡도: O(n) - 모든 요소를 한 번씩 순회
    ///
    /// **옵셔널 체이닝:**
    /// ```swift
    /// compactMap { $0.speed }.max()
    ///                         ↑
    ///                     이 부분이 옵셔널 반환
    ///
    /// 결과:
    /// - 속도 데이터 있음 → Double? (최대값)
    /// - 속도 데이터 없음 → nil
    /// ```
    ///
    /// **계산 예시:**
    /// ```
    /// GPS 포인트:
    ///   [0] speed: 30.5 km/h
    ///   [1] speed: nil
    ///   [2] speed: 68.5 km/h  ← 최대!
    ///   [3] speed: 45.2 km/h
    ///   [4] speed: 55.0 km/h
    ///
    /// compactMap 후: [30.5, 68.5, 45.2, 55.0]
    ///
    /// max() 결과: 68.5 km/h
    /// ```
    ///
    /// **실제 활용:**
    /// - 과속 경고: 최고 속도가 제한 속도 초과 시 알림
    /// - 주행 패턴 분석: 최고 속도로 운전 스타일 파악
    /// - 통계 대시보드: 최고 속도 표시
    ///
    /// **사용 예시:**
    /// ```swift
    /// if let maxSpeed = metadata.maximumSpeed {
    ///     print("최고 속도: \(String(format: "%.1f", maxSpeed))km/h")
    ///
    ///     // 과속 체크 (제한 속도 80km/h)
    ///     if maxSpeed > 80.0 {
    ///         print("⚠️ 과속 구간 감지: \(String(format: "%.1f", maxSpeed))km/h")
    ///     }
    ///
    ///     // UI에 표시
    ///     maxSpeedLabel.text = metadata.summary.maximumSpeedString  // "68.5 km/h"
    /// }
    /// ```
    var maximumSpeed: Double? {
        // GPS 포인트에서 nil이 아닌 속도만 추출 후 최대값 반환
        return gpsPoints.compactMap { $0.speed }.max()
    }

    /// @brief 지도 표시용 주행 경로 좌표 배열
    /// @return 유효한 GPS 좌표 배열
    ///
    /// Get route as array of coordinates for map display
    ///
    /// 지도에 표시할 주행 경로를 반환합니다.
    ///
    /// **필터링 기준:**
    /// - 유효한 GPS 좌표만 포함 (isValid == true)
    /// - 유효하지 않은 좌표 제외 (위도/경도 범위 벗어남)
    ///
    /// **isValid 체크:**
    /// - 위도: -90° ~ +90° 범위 내
    /// - 경도: -180° ~ +180° 범위 내
    /// - 범위를 벗어나면 잘못된 GPS 데이터
    ///
    /// **filter 메서드:**
    /// ```swift
    /// gpsPoints.filter { $0.isValid }
    ///
    /// // 클로저 축약 전:
    /// gpsPoints.filter { point in
    ///     return point.isValid
    /// }
    ///
    /// // 동작:
    /// - 각 요소에 대해 클로저 실행
    /// - 클로저가 true 반환하면 결과 배열에 포함
    /// - 클로저가 false 반환하면 제외
    /// ```
    ///
    /// **필터링 예시:**
    /// ```
    /// 원본 gpsPoints:
    ///   [0] GPSPoint(lat: 37.5665, lon: 126.9780)     ✓ 유효
    ///   [1] GPSPoint(lat: 999.0, lon: 126.9781)       ✗ 위도 범위 초과
    ///   [2] GPSPoint(lat: 37.5667, lon: 126.9782)     ✓ 유효
    ///   [3] GPSPoint(lat: 0.0, lon: 0.0)              ✗ GPS 미수신 (0,0은 대서양 한가운데)
    ///   [4] GPSPoint(lat: 37.5669, lon: 126.9784)     ✓ 유효
    ///
    /// 필터링 후 routeCoordinates:
    ///   [0] GPSPoint(lat: 37.5665, lon: 126.9780)
    ///   [1] GPSPoint(lat: 37.5667, lon: 126.9782)
    ///   [2] GPSPoint(lat: 37.5669, lon: 126.9784)
    /// ```
    ///
    /// **지도 표시 활용:**
    /// - MapKit의 MKPolyline으로 경로 그리기
    /// - 각 좌표를 연결하여 주행 경로 시각화
    /// - 잘못된 좌표는 자동으로 제외
    ///
    /// **사용 예시:**
    /// ```swift
    /// // MapKit에서 경로 그리기
    /// let coordinates = metadata.routeCoordinates.map { $0.coordinate }
    /// let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    /// mapView.addOverlay(polyline)
    ///
    /// // 경로 범위에 맞게 지도 확대/축소
    /// let rect = polyline.boundingMapRect
    /// mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
    ///
    /// // 경로 시작/종료 지점에 마커 표시
    /// if let start = metadata.routeCoordinates.first {
    ///     addMarker(at: start.coordinate, title: "시작 지점")
    /// }
    /// if let end = metadata.routeCoordinates.last {
    ///     addMarker(at: end.coordinate, title: "종료 지점")
    /// }
    /// ```
    var routeCoordinates: [GPSPoint] {
        // 유효한 GPS 좌표만 필터링하여 반환
        return gpsPoints.filter { $0.isValid }
    }

    // MARK: - Acceleration Methods

    /// @brief G-센서 데이터 유무 확인
    /// @return G-센서 데이터가 있으면 true
    ///
    /// Check if G-Sensor data is available
    ///
    /// G-센서 가속도 데이터가 있는지 확인합니다.
    ///
    /// **체크 로직:**
    /// - accelerationData 배열이 비어있지 않으면 true
    /// - 배열이 비어있으면 false
    ///
    /// **사용 예시:**
    /// ```swift
    /// if metadata.hasAccelerationData {
    ///     // 충격 감지 UI 표시
    ///     showImpactDetectionView()
    ///     showGForceGraph()
    /// } else {
    ///     // G-센서 데이터 없음 안내
    ///     showNoAccelerationMessage()
    /// }
    /// ```
    var hasAccelerationData: Bool {
        return !accelerationData.isEmpty
    }

    /// @brief 특정 시점의 가속도 데이터 검색
    /// @param timeOffset 영상 시작부터의 시간 오프셋 (초)
    /// @return 가장 가까운 가속도 데이터 또는 nil
    ///
    /// Get acceleration data at specific time offset
    /// - Parameter timeOffset: Time offset in seconds from start of video
    /// - Returns: Closest acceleration data or nil
    ///
    /// 영상의 특정 시점에 해당하는 가속도 데이터를 찾습니다.
    ///
    /// **알고리즘: 최근접 포인트 검색 (Nearest Point Search)**
    ///
    /// - gpsPoint(at:)와 동일한 알고리즘 사용
    /// - G-센서는 10Hz 샘플링으로 GPS보다 10배 많은 데이터
    ///
    /// 단계:
    /// 1. accelerationData가 비어있으면 nil 반환
    /// 2. 첫 번째 데이터 포인트의 타임스탬프를 기준점(t0)으로 설정
    /// 3. 각 데이터의 상대 시간 계산: (데이터 타임스탬프 - t0)
    /// 4. 요청한 timeOffset과의 시간 차이 계산: |상대 시간 - timeOffset|
    /// 5. 시간 차이가 가장 작은 데이터 반환
    ///
    /// **시간 차이 계산 예시:**
    /// ```
    /// accelerationData:
    ///   [0] timestamp: 14:30:00.0 (t0) → 상대 시간: 0.0초
    ///   [1] timestamp: 14:30:00.1      → 상대 시간: 0.1초
    ///   [2] timestamp: 14:30:00.2      → 상대 시간: 0.2초
    ///   [3] timestamp: 14:30:00.3      → 상대 시간: 0.3초
    ///
    /// 요청: timeOffset = 0.25초
    ///
    /// 시간 차이 계산:
    ///   [0] |0.0 - 0.25| = 0.25초
    ///   [1] |0.1 - 0.25| = 0.15초
    ///   [2] |0.2 - 0.25| = 0.05초  ← 최소! (가장 가까움)
    ///   [3] |0.3 - 0.25| = 0.05초  (동일하지만 [2]가 먼저)
    ///
    /// 결과: accelerationData[2] 반환
    /// ```
    ///
    /// **GPS vs G-센서 샘플링 비교:**
    /// ```
    /// GPS (1Hz):        ●        ●        ●        ●
    /// G-센서 (10Hz):   ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
    ///
    /// timeOffset = 0.25초:
    /// - GPS: 0초 또는 1초 중 선택 (정확도 낮음)
    /// - G-센서: 0.2초 또는 0.3초 중 선택 (정확도 높음)
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 영상 15.5초 시점의 G-Force 표시
    /// if let acc = metadata.accelerationData(at: 15.5) {
    ///     print("G-Force: \(String(format: "%.2f", acc.magnitude))G")
    ///     print("방향: \(acc.primaryDirection.displayName)")
    ///     print("심각도: \(acc.severity.displayName)")
    ///
    ///     // UI 업데이트
    ///     gForceLabel.text = "\(String(format: "%.2f", acc.magnitude))G"
    ///     directionImageView.image = UIImage(systemName: acc.primaryDirection.iconName)
    /// }
    ///
    /// // 영상 재생 중 실시간 G-Force 그래프
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
        // 1. G-센서 데이터가 없으면 nil 반환
        guard !accelerationData.isEmpty else { return nil }

        // 2. 첫 번째 데이터 포인트의 타임스탬프를 기준점(t0)으로 사용
        // 3. min(by:) 클로저로 각 데이터의 시간 차이 계산 후 최소값 찾기
        return accelerationData.min(by: { data1, data2 in
            // data1의 시간 차이 계산
            let diff1 = abs(data1.timestamp.timeIntervalSince(accelerationData[0].timestamp) - timeOffset)
            // data2의 시간 차이 계산
            let diff2 = abs(data2.timestamp.timeIntervalSince(accelerationData[0].timestamp) - timeOffset)
            // 시간 차이가 작은 것이 "더 가까운" 데이터
            return diff1 < diff2
        })
    }

    /// @brief 유의미한 가속도 이벤트 검색 (> 1.5G)
    /// @return 유의미한 가속도 이벤트 배열
    ///
    /// Find all significant acceleration events
    ///
    /// 유의미한 가속도 이벤트를 모두 찾습니다.
    ///
    /// **유의미한 이벤트 (Significant Event):**
    /// - AccelerationData.isSignificant == true
    /// - 가속도 크기가 1.5G 이상인 경우
    /// - 일반 주행보다 강한 가속/감속/회전을 의미
    ///
    /// **1.5G 기준의 의미:**
    /// ```
    /// 가속도 범위:
    ///   0.0 ~ 1.0G: 일반 주행 (정상)
    ///   1.0 ~ 1.5G: 약간 강한 가속/감속 (경미)
    ///   1.5 ~ 2.5G: 유의미한 이벤트 ★
    ///   2.5 ~ 4.0G: 충격 이벤트
    ///   4.0G 이상: 심각한 충격
    /// ```
    ///
    /// **실제 예시:**
    /// - 1.0G: 일반 출발/정지
    /// - 1.5G: 급제동, 급출발, 급회전
    /// - 2.0G: 사고 직전 급브레이크
    /// - 3.0G: 경미한 충돌
    ///
    /// **filter 메서드:**
    /// ```swift
    /// accelerationData.filter { $0.isSignificant }
    ///
    /// // 동작:
    /// - 각 AccelerationData를 순회
    /// - isSignificant가 true인 것만 결과 배열에 포함
    /// - 시간 복잡도: O(n)
    /// ```
    ///
    /// **필터링 예시:**
    /// ```
    /// accelerationData:
    ///   [0] magnitude: 0.8G  (정상 주행)       ✗ 제외
    ///   [1] magnitude: 1.2G  (가벼운 가속)      ✗ 제외
    ///   [2] magnitude: 1.8G  (급제동)          ✓ 포함
    ///   [3] magnitude: 1.0G  (정상 주행)       ✗ 제외
    ///   [4] magnitude: 2.3G  (급회전)          ✓ 포함
    ///   [5] magnitude: 3.5G  (충격)            ✓ 포함
    ///
    /// 결과 significantEvents: [1.8G, 2.3G, 3.5G]
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// let events = metadata.significantEvents
    /// print("유의미한 이벤트: \(events.count)회")
    ///
    /// // 타임라인에 마커 표시
    /// for event in events {
    ///     let time = event.timestamp.timeIntervalSince(metadata.accelerationData[0].timestamp)
    ///     addTimelineMarker(at: time, severity: event.severity)
    /// }
    ///
    /// // 이벤트 목록 표시
    /// for (index, event) in events.enumerated() {
    ///     print("\(index + 1). \(event.timestamp.formatted())")
    ///     print("   강도: \(String(format: "%.2f", event.magnitude))G")
    ///     print("   방향: \(event.primaryDirection.displayName)")
    /// }
    /// ```
    var significantEvents: [AccelerationData] {
        // isSignificant가 true인 데이터만 필터링
        return accelerationData.filter { $0.isSignificant }
    }

    /// @brief 충격 이벤트 검색 (> 2.5G)
    /// @return 충격 이벤트 배열
    ///
    /// Find all impact events
    ///
    /// 충격 이벤트를 모두 찾습니다.
    ///
    /// **충격 이벤트 (Impact Event):**
    /// - AccelerationData.isImpact == true
    /// - 가속도 크기가 2.5G 이상인 경우
    /// - 사고, 충돌, 심각한 충격을 의미
    ///
    /// **2.5G 기준의 의미:**
    /// ```
    /// 가속도 범위:
    ///   0.0 ~ 1.5G: 일반/유의미한 가속
    ///   1.5 ~ 2.5G: 강한 가속 (Moderate)
    ///   2.5 ~ 4.0G: 충격 이벤트 ★
    ///   4.0G 이상: 심각한 충격
    /// ```
    ///
    /// **실제 예시:**
    /// - 2.5G: 사고 충격, 큰 턱 통과
    /// - 3.0G: 경미한 충돌
    /// - 5.0G: 심각한 충돌
    /// - 10G+: 매우 심각한 사고
    ///
    /// **블랙박스 활용:**
    /// - 충격 이벤트 발생 시 자동으로 파일 보호
    /// - 이벤트 폴더(/event/)에 별도 저장
    /// - 사고 증거 자료로 활용
    ///
    /// **사용 예시:**
    /// ```swift
    /// let impacts = metadata.impactEvents
    ///
    /// if !impacts.isEmpty {
    ///     print("⚠️ 충격 이벤트 \(impacts.count)회 감지!")
    ///
    ///     for (index, impact) in impacts.enumerated() {
    ///         print("\n[\(index + 1)] 충격 이벤트")
    ///         print("시간: \(impact.timestamp.formatted())")
    ///         print("강도: \(String(format: "%.2f", impact.magnitude))G")
    ///         print("방향: \(impact.primaryDirection.displayName)")
    ///         print("심각도: \(impact.severity.displayName)")
    ///         print("색상: \(impact.severity.colorHex)")
    ///     }
    ///
    ///     // 가장 강한 충격 찾기
    ///     if let strongest = impacts.max(by: { $0.magnitude < $1.magnitude }) {
    ///         print("\n가장 강한 충격: \(String(format: "%.2f", strongest.magnitude))G")
    ///     }
    /// } else {
    ///     print("✓ 충격 이벤트 없음 (안전 주행)")
    /// }
    /// ```
    var impactEvents: [AccelerationData] {
        // isImpact가 true인 데이터만 필터링
        return accelerationData.filter { $0.isImpact }
    }

    /// @brief 최대 G-Force 계산
    /// @return 최대 G-Force 또는 nil
    ///
    /// Calculate maximum G-force experienced
    ///
    /// 경험한 최대 G-Force를 계산합니다.
    ///
    /// **알고리즘:**
    /// 1. 모든 가속도 데이터의 magnitude(크기) 추출
    /// 2. 그 중 최대값 반환
    ///
    /// **map 메서드:**
    /// ```swift
    /// accelerationData.map { $0.magnitude }
    ///
    /// // 변환:
    /// AccelerationData → Double
    /// [AccelerationData] → [Double]
    ///
    /// // 예시:
    /// [AccelerationData(x:0, y:0, z:1), AccelerationData(x:1.5, y:-3.5, z:0.8)]
    ///   ↓ map { $0.magnitude }
    /// [1.0, 3.85]
    /// ```
    ///
    /// **max() 메서드:**
    /// - 배열의 최대값 반환
    /// - 배열이 비어있으면 nil 반환
    ///
    /// **계산 예시:**
    /// ```
    /// accelerationData:
    ///   [0] AccelerationData(x: 0.0, y: 0.0, z: 1.0)   → magnitude: 1.0G
    ///   [1] AccelerationData(x: 0.0, y: -1.8, z: 1.0)  → magnitude: 2.06G
    ///   [2] AccelerationData(x: 2.2, y: 0.5, z: 1.0)   → magnitude: 2.45G
    ///   [3] AccelerationData(x: 1.5, y: -3.5, z: 0.8)  → magnitude: 3.85G ← 최대!
    ///
    /// map 후: [1.0, 2.06, 2.45, 3.85]
    /// max() 결과: 3.85G
    /// ```
    ///
    /// **활용:**
    /// - 전체 주행 중 가장 강한 충격 확인
    /// - 사고 심각도 평가
    /// - 보험 처리 시 증거 자료
    ///
    /// **사용 예시:**
    /// ```swift
    /// if let maxG = metadata.maximumGForce {
    ///     print("최대 G-Force: \(String(format: "%.2f", maxG))G")
    ///
    ///     // 심각도 평가
    ///     if maxG > 4.0 {
    ///         print("🚨 심각한 충격 감지! 사고 가능성 높음")
    ///     } else if maxG > 2.5 {
    ///         print("⚠️ 충격 감지! 주의 필요")
    ///     } else if maxG > 1.5 {
    ///         print("⚡ 강한 가속/감속 감지")
    ///     } else {
    ///         print("✓ 정상 주행")
    ///     }
    ///
    ///     // UI에 표시
    ///     maxGForceLabel.text = metadata.summary.maximumGForceString  // "3.85 G"
    /// }
    /// ```
    var maximumGForce: Double? {
        // 모든 가속도 데이터의 magnitude를 추출한 후 최대값 반환
        return accelerationData.map { $0.magnitude }.max()
    }

    /// @brief 충격 이벤트 존재 여부 확인
    /// @return 충격 이벤트가 있으면 true
    ///
    /// Check if video contains impact events
    ///
    /// 영상에 충격 이벤트가 있는지 확인합니다.
    ///
    /// **체크 로직:**
    /// - impactEvents 배열이 비어있지 않으면 true
    /// - 2.5G 이상의 충격이 하나라도 있으면 true
    ///
    /// **활용:**
    /// - 사고 영상 자동 분류
    /// - 이벤트 파일 우선순위 지정
    /// - UI에 경고 표시
    ///
    /// **사용 예시:**
    /// ```swift
    /// if metadata.hasImpactEvents {
    ///     // 사고 영상으로 분류
    ///     fileCategory = .accident
    ///
    ///     // 빨간색 경고 표시
    ///     thumbnailBadge.backgroundColor = .red
    ///     thumbnailBadge.text = "⚠️ 충격"
    ///
    ///     // 자동 백업 트리거
    ///     backupManager.backupImmediately(videoFile)
    /// } else {
    ///     // 일반 주행 영상
    ///     fileCategory = .normal
    ///     thumbnailBadge.isHidden = true
    /// }
    /// ```
    var hasImpactEvents: Bool {
        return !impactEvents.isEmpty
    }

    // MARK: - Combined Analysis

    /// @brief 메타데이터 분석 및 요약 정보 생성
    /// @return MetadataSummary 구조체
    ///
    /// Analyze metadata and provide summary
    ///
    /// 메타데이터를 분석하여 요약 정보를 생성합니다.
    ///
    /// **MetadataSummary 구조:**
    /// - GPS 관련: hasGPS, gpsPointCount, totalDistance, averageSpeed, maximumSpeed
    /// - 가속도 관련: hasAcceleration, accelerationPointCount, impactEventCount, maximumGForce
    ///
    /// **통합 분석:**
    /// - GPS와 G-센서 데이터를 종합적으로 분석
    /// - 주행 패턴과 충격 이벤트를 통합 평가
    /// - UI 표시용 포맷된 문자열 제공
    ///
    /// **계산되는 통계:**
    /// 1. GPS 통계:
    ///    - 총 주행 거리 (미터 단위, 자동으로 km 변환)
    ///    - 평균 속도 (km/h)
    ///    - 최고 속도 (km/h)
    ///
    /// 2. 가속도 통계:
    ///    - 충격 이벤트 횟수
    ///    - 최대 G-Force
    ///
    /// **사용 예시:**
    /// ```swift
    /// let summary = metadata.summary
    ///
    /// // 통합 대시보드 표시
    /// print("=== 주행 요약 ===")
    /// print("📍 GPS: \(summary.hasGPS ? "있음" : "없음")")
    /// print("   포인트: \(summary.gpsPointCount)개")
    /// print("   거리: \(summary.distanceString)")
    /// print("   평균 속도: \(summary.averageSpeedString ?? "N/A")")
    /// print("   최고 속도: \(summary.maximumSpeedString ?? "N/A")")
    /// print("")
    /// print("📊 G-센서: \(summary.hasAcceleration ? "있음" : "없음")")
    /// print("   포인트: \(summary.accelerationPointCount)개")
    /// print("   충격 이벤트: \(summary.impactEventCount)회")
    /// print("   최대 G-Force: \(summary.maximumGForceString ?? "N/A")")
    ///
    /// // SwiftUI View에서 사용
    /// struct MetadataSummaryView: View {
    ///     let summary: MetadataSummary
    ///
    ///     var body: some View {
    ///         VStack(alignment: .leading) {
    ///             Text("주행 거리: \(summary.distanceString)")
    ///             Text("평균 속도: \(summary.averageSpeedString ?? "N/A")")
    ///             if summary.impactEventCount > 0 {
    ///                 Text("⚠️ 충격: \(summary.impactEventCount)회")
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
 DeviceInfo - 블랙박스 장치 정보
 ───────────────────────────────────────────────────────────────────────────────

 블랙박스 하드웨어와 펌웨어 정보를 저장하는 구조체입니다.

 【포함 정보】
 - manufacturer: 제조사 (예: BlackVue, Thinkware, IROAD)
 - model: 모델명 (예: DR900X-2CH, Q800PRO)
 - firmwareVersion: 펌웨어 버전 (예: 1.010, v2.5.3)
 - serialNumber: 시리얼 번호 (제품 고유 식별자)
 - recordingMode: 녹화 모드 (Normal, Parking, Event)

 【활용】
 - 버그 리포트 시 장치 정보 첨부
 - 펌웨어 업데이트 체크
 - 제조사별 특수 기능 지원
 - 파일 포맷 호환성 확인

 ───────────────────────────────────────────────────────────────────────────────
 */

/// @struct DeviceInfo
/// @brief 블랙박스 장치 정보
///
/// Device/dashcam information
///
/// 블랙박스 장치의 하드웨어와 펌웨어 정보를 나타냅니다.
///
/// **사용 예시:**
/// ```swift
/// let device = DeviceInfo(
///     manufacturer: "BlackVue",
///     model: "DR900X-2CH",
///     firmwareVersion: "1.010",
///     serialNumber: "BV900X123456",
///     recordingMode: "Normal"
/// )
///
/// // 장치 정보 표시
/// print("\(device.manufacturer ?? "Unknown") \(device.model ?? "Unknown")")
/// print("Firmware: \(device.firmwareVersion ?? "Unknown")")
/// ```
struct DeviceInfo: Codable, Equatable, Hashable {
    /// Device manufacturer
    ///
    /// 블랙박스 제조사입니다.
    ///
    /// **예시:**
    /// - "BlackVue"
    /// - "Thinkware"
    /// - "IROAD"
    /// - "Nextbase"
    let manufacturer: String?

    /// Device model name
    ///
    /// 블랙박스 모델명입니다.
    ///
    /// **예시:**
    /// - "DR900X-2CH" (BlackVue 2채널)
    /// - "Q800PRO" (Thinkware)
    /// - "X10" (IROAD)
    let model: String?

    /// Firmware version
    ///
    /// 펌웨어 버전입니다.
    ///
    /// **예시:**
    /// - "1.010"
    /// - "v2.5.3"
    /// - "20241012"
    let firmwareVersion: String?

    /// Device serial number
    ///
    /// 제품 고유 시리얼 번호입니다.
    ///
    /// **형식 예시:**
    /// - "BV900X123456"
    /// - "TW-Q800-789012"
    let serialNumber: String?

    /// Recording settings/mode
    ///
    /// 녹화 모드 설정입니다.
    ///
    /// **모드 예시:**
    /// - "Normal": 일반 주행 녹화
    /// - "Parking": 주차 모드 녹화
    /// - "Event": 이벤트 녹화 (충격 감지)
    let recordingMode: String?
}

/*
 ───────────────────────────────────────────────────────────────────────────────
 MetadataSummary - 메타데이터 요약 정보
 ───────────────────────────────────────────────────────────────────────────────

 VideoMetadata의 주요 통계를 빠르게 조회할 수 있도록 정리한 구조체입니다.

 【포함 통계】

 GPS 통계:
 - hasGPS: GPS 데이터 유무
 - gpsPointCount: GPS 포인트 개수
 - totalDistance: 총 주행 거리 (미터)
 - averageSpeed: 평균 속도 (km/h)
 - maximumSpeed: 최고 속도 (km/h)

 가속도 통계:
 - hasAcceleration: G-센서 데이터 유무
 - accelerationPointCount: 가속도 데이터 개수
 - impactEventCount: 충격 이벤트 횟수 (2.5G 이상)
 - maximumGForce: 최대 G-Force

 【포맷팅 프로퍼티】

 - distanceString: 거리를 읽기 쉬운 형태로 변환
 예: 450m → "450 m", 2500m → "2.5 km"

 - averageSpeedString: 평균 속도를 문자열로 변환
 예: 45.3 → "45.3 km/h"

 - maximumSpeedString: 최고 속도를 문자열로 변환
 예: 68.5 → "68.5 km/h"

 - maximumGForceString: 최대 G-Force를 문자열로 변환
 예: 3.85 → "3.85 G"

 ───────────────────────────────────────────────────────────────────────────────
 */

/// @struct MetadataSummary
/// @brief 메타데이터 요약 정보
///
/// Metadata summary for quick overview
///
/// 메타데이터의 주요 통계를 요약한 구조체입니다.
/// UI 표시와 빠른 조회를 위해 사전 계산된 값들을 포함합니다.
///
/// **사용 예시:**
/// ```swift
/// let summary = metadata.summary
///
/// // 대시보드 표시
/// dashboardView.distanceLabel.text = summary.distanceString
/// dashboardView.avgSpeedLabel.text = summary.averageSpeedString ?? "N/A"
/// dashboardView.impactCountLabel.text = "\(summary.impactEventCount)"
/// ```
struct MetadataSummary: Codable, Equatable {
    /// GPS 데이터 유무
    let hasGPS: Bool

    /// GPS 포인트 개수
    let gpsPointCount: Int

    /// 총 주행 거리 (미터)
    let totalDistance: Double

    /// 평균 속도 (km/h, nil이면 데이터 없음)
    let averageSpeed: Double?

    /// 최고 속도 (km/h, nil이면 데이터 없음)
    let maximumSpeed: Double?

    /// G-센서 데이터 유무
    let hasAcceleration: Bool

    /// 가속도 데이터 포인트 개수
    let accelerationPointCount: Int

    /// 충격 이벤트 횟수 (2.5G 이상)
    let impactEventCount: Int

    /// 최대 G-Force (nil이면 데이터 없음)
    let maximumGForce: Double?

    /// Format distance as human-readable string
    ///
    /// 거리를 읽기 쉬운 문자열로 변환합니다.
    ///
    /// **변환 규칙:**
    /// - 1000m 이상: 킬로미터 단위로 변환 (소수점 1자리)
    /// - 1000m 미만: 미터 단위로 표시 (정수)
    ///
    /// **예시:**
    /// ```
    /// totalDistance: 450.0m    → "450 m"
    /// totalDistance: 999.9m    → "1000 m"
    /// totalDistance: 1000.0m   → "1.0 km"
    /// totalDistance: 2450.5m   → "2.5 km"
    /// totalDistance: 15832.0m  → "15.8 km"
    /// ```
    ///
    /// **포맷 문자열:**
    /// - "%.1f km": 소수점 1자리까지 표시 (2.5 km)
    /// - "%.0f m": 소수점 없이 정수로 표시 (450 m)
    ///
    /// **사용 예시:**
    /// ```swift
    /// distanceLabel.text = "주행 거리: \(summary.distanceString)"
    /// // 출력: "주행 거리: 2.5 km"
    /// ```
    var distanceString: String {
        if totalDistance >= 1000 {
            // 1000m 이상: km 단위로 변환 (소수점 1자리)
            return String(format: "%.1f km", totalDistance / 1000)
        } else {
            // 1000m 미만: m 단위 (정수)
            return String(format: "%.0f m", totalDistance)
        }
    }

    /// Format average speed as string
    ///
    /// 평균 속도를 문자열로 변환합니다.
    ///
    /// **포맷:**
    /// - 소수점 1자리까지 표시
    /// - 단위: km/h
    /// - 데이터 없으면 nil 반환
    ///
    /// **예시:**
    /// ```
    /// averageSpeed: 45.3   → "45.3 km/h"
    /// averageSpeed: 68.0   → "68.0 km/h"
    /// averageSpeed: nil    → nil
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// if let avgSpeed = summary.averageSpeedString {
    ///     speedLabel.text = "평균: \(avgSpeed)"
    /// } else {
    ///     speedLabel.text = "평균: N/A"
    /// }
    /// ```
    var averageSpeedString: String? {
        guard let speed = averageSpeed else { return nil }
        return String(format: "%.1f km/h", speed)
    }

    /// Format maximum speed as string
    ///
    /// 최고 속도를 문자열로 변환합니다.
    ///
    /// **포맷:**
    /// - 소수점 1자리까지 표시
    /// - 단위: km/h
    /// - 데이터 없으면 nil 반환
    ///
    /// **예시:**
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
    /// 최대 G-Force를 문자열로 변환합니다.
    ///
    /// **포맷:**
    /// - 소수점 2자리까지 표시 (정밀도 중요)
    /// - 단위: G
    /// - 데이터 없으면 nil 반환
    ///
    /// **예시:**
    /// ```
    /// maximumGForce: 1.85   → "1.85 G"
    /// maximumGForce: 3.5    → "3.50 G"
    /// maximumGForce: nil    → nil
    /// ```
    ///
    /// **소수점 2자리인 이유:**
    /// - G-Force는 0.01G 차이도 의미가 있음
    /// - 1.85G vs 1.95G: 둘 다 "유의미한 이벤트"지만 강도 차이 존재
    /// - 충격 분석에서 정밀도 필요
    var maximumGForceString: String? {
        guard let gForce = maximumGForce else { return nil }
        return String(format: "%.2f G", gForce)
    }
}

// MARK: - Sample Data

/*
 ───────────────────────────────────────────────────────────────────────────────
 Sample Data - 샘플 메타데이터
 ───────────────────────────────────────────────────────────────────────────────

 테스트, SwiftUI 프리뷰, 개발 중 UI 확인을 위한 샘플 데이터입니다.

 【샘플 종류】

 1. sample: 완전한 메타데이터
 - GPS 데이터, 가속도 데이터, 장치 정보 모두 포함
 - 일반적인 주행 시나리오

 2. empty: 빈 메타데이터
 - 데이터 없음 상태 테스트
 - UI의 "데이터 없음" 처리 확인

 3. gpsOnly: GPS만 있는 메타데이터
 - G-센서 없는 구형 블랙박스 시뮬레이션
 - GPS 전용 UI 테스트

 4. accelerationOnly: G-센서만 있는 메타데이터
 - GPS 수신 불가 환경 (터널, 지하 등) 시뮬레이션
 - 충격 감지 전용 UI 테스트

 5. withImpact: 충격 이벤트 포함 메타데이터
 - 사고 영상 시뮬레이션
 - 충격 감지 UI 테스트

 【사용 예시】

 SwiftUI 프리뷰:
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

 단위 테스트:
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
    /// 완전한 메타데이터 샘플입니다.
    /// GPS 데이터, G-센서 데이터, 장치 정보를 모두 포함합니다.
    ///
    /// **포함 데이터:**
    /// - GPS 경로 (GPSPoint.sampleRoute)
    /// - 가속도 데이터 (AccelerationData.sampleData)
    /// - BlackVue DR900X-2CH 장치 정보
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
    /// 빈 메타데이터 샘플입니다.
    /// GPS와 G-센서 데이터가 모두 없는 상태입니다.
    ///
    /// **테스트 용도:**
    /// - "데이터 없음" UI 상태 확인
    /// - 빈 배열 처리 로직 테스트
    /// - nil 처리 확인
    static let empty = VideoMetadata()

    /// Metadata with GPS only
    ///
    /// GPS 데이터만 있는 메타데이터 샘플입니다.
    /// G-센서 데이터는 없습니다.
    ///
    /// **시뮬레이션 상황:**
    /// - G-센서가 없는 구형 블랙박스
    /// - G-센서 고장 또는 비활성화
    static let gpsOnly = VideoMetadata(
        gpsPoints: GPSPoint.sampleRoute,
        accelerationData: []
    )

    /// Metadata with acceleration only
    ///
    /// G-센서 데이터만 있는 메타데이터 샘플입니다.
    /// GPS 데이터는 없습니다.
    ///
    /// **시뮬레이션 상황:**
    /// - GPS 수신 불가 환경 (터널, 지하주차장)
    /// - GPS 모듈 고장
    /// - GPS 비활성화 설정
    static let accelerationOnly = VideoMetadata(
        gpsPoints: [],
        accelerationData: AccelerationData.sampleData
    )

    /// Metadata with impact event
    ///
    /// 충격 이벤트가 포함된 메타데이터 샘플입니다.
    ///
    /// **포함 이벤트:**
    /// - normal: 정상 주행 (0, 0, 1G)
    /// - braking: 급제동 (0, -1.8, 1G)
    /// - impact: 충격 이벤트 (1.5, -3.5, 0.8G) ★
    /// - normal: 충격 후 정상 주행
    ///
    /// **테스트 용도:**
    /// - 충격 감지 UI 표시 확인
    /// - 충격 이벤트 타임라인 마커
    /// - 사고 영상 분류 로직
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
