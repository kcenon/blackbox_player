//
//  GPSService.swift
//  BlackboxPlayer
//
//  Service for managing and querying GPS data synchronized with video playback
//

/**
 # GPSService - GPS 데이터 관리 서비스

 ## 📍 GPS란?

 **GPS (Global Positioning System)**는 위성을 이용하여 현재 위치를 파악하는 시스템입니다.

 ### GPS의 구성:
 ```
 GPS 위성 (우주)
   ↓ 전파 송신
 GPS 수신기 (블랙박스)
   ↓ 위치 계산
 좌표 데이터 (위도, 경도, 고도)
 ```

 ### GPS 좌표:
 - **위도 (Latitude)**: 남북 위치 (-90° ~ +90°)
   - 적도: 0°
   - 북극: +90°
   - 남극: -90°

 - **경도 (Longitude)**: 동서 위치 (-180° ~ +180°)
   - 본초자오선: 0°
   - 동쪽: 양수
   - 서쪽: 음수

 예: 서울 = (37.5665° N, 126.9780° E)

 ## 🎯 블랙박스에서의 GPS 활용

 ### 1. 주행 경로 기록
 ```
 시간 |  위도    |  경도    | 속도
 -----+---------+---------+------
 0초  | 37.5665 | 126.978 | 30
 1초  | 37.5667 | 126.979 | 35
 2초  | 37.5669 | 126.980 | 40
 ...
 ```

 ### 2. 속도 측정
 - GPS 수신기가 직접 계산하는 속도
 - 또는: 위치 변화로 계산 (거리 / 시간)

 ### 3. 사고 위치 특정
 - 정확한 사고 지점 GPS 좌표 제공
 - 지도 앱에서 바로 확인 가능

 ### 4. 영상-위치 동기화
 ```
 영상 프레임          GPS 데이터
 ┌──────────┐         ┌──────────┐
 │ 00:00:05 │   ←→   │ 37.5669  │
 │          │         │ 126.980  │
 └──────────┘         └──────────┘
 ```

 ## 💡 GPSService의 역할

 ### 1. 데이터 로드
 ```swift
 service.loadGPSData(from: metadata, startTime: videoStart)
 // VideoMetadata에서 GPS 점들을 추출하여 메모리에 로드
 ```

 ### 2. 시간 기반 조회
 ```swift
 let location = service.getCurrentLocation(at: 5.0)
 // 영상 재생 5초 시점의 GPS 위치 반환
 ```

 ### 3. 거리 계산
 ```swift
 let distance = service.distanceTraveled(at: 60.0)
 // 영상 시작부터 1분까지 주행한 거리 (미터)
 ```

 ### 4. 경로 분할
 ```swift
 let (past, future) = service.getRouteSegments(at: 30.0)
 // 이미 지나간 경로 vs 앞으로 갈 경로
 // 지도에서 다른 색으로 표시
 ```

 ## 🔄 시간 동기화

 ### 원리:
 ```
 영상 시작 시각: 2024-10-12 15:00:00
 GPS 데이터 시각: 2024-10-12 15:00:03

 시간 오프셋 계산:
 offset = GPS 시각 - 영상 시작 시각
        = 15:00:03 - 15:00:00
        = 3초

 영상 재생 3초 → 이 GPS 데이터 표시
 ```

 ### 정확도:
 - GPS: 초 단위 (보통 1Hz = 1초마다 1번 측정)
 - 영상: 프레임 단위 (30fps = 초당 30프레임)
 - 보간: 두 GPS 점 사이를 선형 보간하여 부드럽게 표시

 ## 📚 사용 예제

 ```swift
 // 1. 서비스 생성
 let gpsService = GPSService()

 // 2. 영상 로드 시 GPS 데이터 로드
 gpsService.loadGPSData(
     from: videoFile.metadata,
     startTime: videoFile.timestamp
 )

 // 3. 재생 중 현재 위치 조회
 Timer.publish(every: 0.1, on: .main, in: .common)
     .sink { _ in
         if let location = gpsService.getCurrentLocation(at: currentTime) {
             updateMapMarker(location)
         }
     }

 // 4. 주행 거리 표시
 Text("주행 거리: \(gpsService.distanceTraveled(at: currentTime)) m")

 // 5. 평균 속도 표시
 if let speed = gpsService.averageSpeed(at: currentTime) {
     Text("평균 속도: \(speed) km/h")
 }
 ```

 ---

 이 서비스는 영상 재생과 GPS 데이터를 완벽하게 동기화하여 실시간 위치 추적을 제공합니다.
 */

import Foundation
import Combine

// MARK: - GPS Service

/**
 ## GPSService - GPS 데이터 관리 서비스

 영상 재생 시간과 GPS 데이터를 동기화하여 실시간 위치, 경로, 속도 정보를 제공합니다.

 ### 주요 기능:
 1. GPS 데이터 로드 및 관리
 2. 재생 시간 기반 위치 조회
 3. 주행 거리 계산
 4. 평균 속도 계산
 5. 경로 세그먼트 분할 (이미 지나온 경로 vs 앞으로 갈 경로)

 ### ObservableObject란?
 - Combine 프레임워크의 프로토콜
 - @Published 프로퍼티가 변경되면 자동으로 알림
 - SwiftUI View가 자동으로 업데이트됨
 */
class GPSService: ObservableObject {

    // MARK: - Published Properties

    /**
     ## 현재 GPS 위치

     영상 재생 시간에 해당하는 GPS 좌표입니다.

     ### @Published private(set)이란?
     - **@Published**: 값이 변경되면 자동으로 View 업데이트
     - **private(set)**: 외부에서 읽기만 가능, 쓰기 불가 (이 클래스 내에서만 수정)

     ### 이유:
     ```swift
     // 외부에서:
     let location = gpsService.currentLocation  // OK (읽기)
     gpsService.currentLocation = ...           // 컴파일 에러 (쓰기 불가)

     // 내부에서 (이 클래스):
     self.currentLocation = newLocation         // OK (쓰기 가능)
     ```

     ### GPSPoint란?
     ```swift
     struct GPSPoint {
         let latitude: Double   // 위도
         let longitude: Double  // 경도
         let altitude: Double?  // 고도 (선택)
         let speed: Double?     // 속도 (선택)
         let timestamp: Date    // 측정 시각
     }
     ```

     ### 사용 예:
     ```swift
     if let location = gpsService.currentLocation {
         print("현재 위치: \(location.latitude), \(location.longitude)")
         print("속도: \(location.speed ?? 0) km/h")
     }
     ```
     */
    @Published private(set) var currentLocation: GPSPoint?

    /**
     ## 전체 경로 점들

     영상에 포함된 모든 GPS 좌표 배열입니다.

     ### 용도:
     - 지도에 전체 경로 그리기
     - 경로 미리보기
     - 경로 분석 (총 거리, 평균 속도 등)

     ### 예시 데이터:
     ```
     routePoints = [
         GPSPoint(lat: 37.5665, lon: 126.978, time: 0s),
         GPSPoint(lat: 37.5667, lon: 126.979, time: 1s),
         GPSPoint(lat: 37.5669, lon: 126.980, time: 2s),
         ...
     ]
     ```

     ### 사용 예:
     ```swift
     // 지도에 경로 그리기
     for point in gpsService.routePoints {
         mapView.addAnnotation(point)
     }
     ```
     */
    @Published private(set) var routePoints: [GPSPoint] = []

    /**
     ## 메타데이터 요약

     GPS 데이터의 통계 정보입니다.

     ### MetadataSummary란?
     ```swift
     struct MetadataSummary {
         let totalDistance: Double     // 총 주행 거리 (m)
         let maxSpeed: Double           // 최고 속도 (km/h)
         let averageSpeed: Double       // 평균 속도 (km/h)
         let startLocation: GPSPoint    // 출발 위치
         let endLocation: GPSPoint      // 도착 위치
     }
     ```

     ### 사용 예:
     ```swift
     if let summary = gpsService.summary {
         Text("총 거리: \(summary.totalDistance / 1000) km")
         Text("최고 속도: \(summary.maxSpeed) km/h")
         Text("평균 속도: \(summary.averageSpeed) km/h")
     }
     ```
     */
    @Published private(set) var summary: MetadataSummary?

    // MARK: - Private Properties

    /**
     ## 영상 메타데이터

     GPS 데이터를 포함한 영상의 모든 메타데이터입니다.

     ### VideoMetadata란?
     ```swift
     struct VideoMetadata {
         let gpsPoints: [GPSPoint]         // GPS 좌표 배열
         let routeCoordinates: [GPSPoint]  // 경로 좌표 (최적화된 버전)
         let gsensorData: [GSensorPoint]   // G-센서 데이터
         let summary: MetadataSummary      // 요약 정보
     }
     ```

     ### private이란?
     - 이 클래스 내부에서만 접근 가능
     - 외부에서는 이 변수를 직접 볼 수 없음
     - 캡슐화 (Encapsulation)의 원칙
     */
    private var metadata: VideoMetadata?

    /**
     ## 영상 시작 시각

     영상이 녹화를 시작한 절대 시각입니다.

     ### 용도:
     시간 오프셋 계산에 사용됩니다.

     ```
     영상 시작: 2024-10-12 15:00:00
     GPS 시각:  2024-10-12 15:00:05

     오프셋 = GPS 시각 - 영상 시작
            = 15:00:05 - 15:00:00
            = 5초

     → 영상 재생 5초 시점에 이 GPS 데이터 표시
     ```

     ### Date란?
     - Foundation의 날짜/시간 타입
     - 절대 시각을 표현 (Unix Epoch 1970-01-01 00:00:00 UTC 기준)
     - timeIntervalSince(_:) 메서드로 시간 차이 계산
     */
    private var videoStartTime: Date?

    // MARK: - Public Methods

    /**
     ## GPS 데이터 로드

     VideoMetadata에서 GPS 데이터를 추출하여 서비스에 로드합니다.

     ### 호출 시점:
     ```swift
     // 영상 파일 로드 직후:
     func loadVideo(_ file: VideoFile) {
         // ... 영상 디코더 설정

         gpsService.loadGPSData(
             from: file.metadata,
             startTime: file.timestamp
         )

         // ... GPS 지도 UI 업데이트
     }
     ```

     ### 처리 과정:
     ```
     1. metadata 저장 (GPS 점들 포함)
     2. videoStartTime 저장 (시간 오프셋 계산용)
     3. routePoints 설정 (@Published → UI 자동 업데이트)
     4. summary 설정 (통계 정보)
     5. 로그 기록
     ```

     ### 메모리 영향:
     - GPS 점 1개 ≈ 50 바이트
     - 1시간 영상 (3600초, 1Hz GPS) ≈ 180 KB
     - 메모리에 안전하게 보관 가능

     - Parameters:
       - metadata: GPS 데이터를 포함한 영상 메타데이터
       - startTime: 영상 녹화 시작 시각
     */
    func loadGPSData(from metadata: VideoMetadata, startTime: Date) {
        // ===== 1단계: 메타데이터 저장 =====
        self.metadata = metadata
        self.videoStartTime = startTime

        // ===== 2단계: 경로 점들 설정 =====
        // @Published이므로 자동으로 UI 업데이트
        self.routePoints = metadata.routeCoordinates

        // ===== 3단계: 요약 정보 설정 =====
        self.summary = metadata.summary

        // ===== 4단계: 로그 기록 =====
        infoLog("[GPSService] Loaded GPS data: \(metadata.gpsPoints.count) points")
    }

    /**
     ## 특정 시간의 GPS 위치 조회

     영상 재생 시간에 해당하는 GPS 좌표를 반환합니다.

     ### 시간 매칭 방법:

     1. **정확히 일치하는 GPS 점이 있는 경우:**
     ```
     GPS 데이터: [0s, 1s, 2s, 3s, ...]
     재생 시간: 2.0초
     → 2s 시점의 GPS 점 반환
     ```

     2. **중간 시간 (보간):**
     ```
     GPS 데이터: 5초(37.5665, 126.978), 6초(37.5667, 126.980)
     재생 시간: 5.5초

     선형 보간:
     lat = 37.5665 + (37.5667 - 37.5665) × 0.5
         = 37.5666
     lon = 126.978 + (126.980 - 126.978) × 0.5
         = 126.979

     → GPSPoint(37.5666, 126.979)
     ```

     3. **GPS 데이터 없는 경우:**
     ```
     metadata == nil → nil 반환
     ```

     ### weak self란?
     ```swift
     DispatchQueue.main.async { [weak self] in
         self?.currentLocation = location
     }
     ```

     - **weak**: 약한 참조 (메모리 누수 방지)
     - **self?**: self가 nil일 수 있음 (Optional)

     **왜 필요한가?**
     ```
     GPSService가 해제됨
       ↓
     하지만 클로저가 아직 실행 대기 중
       ↓
     weak self 덕분에 self는 nil
       ↓
     self?.currentLocation → 안전하게 무시
     ```

     **strong 참조였다면:**
     ```
     GPSService를 해제하려 함
       ↓
     클로저가 strong self를 붙잡고 있음
       ↓
     GPSService가 메모리에 남음 (메모리 누수!)
     ```

     ### DispatchQueue.main.async란?
     - **DispatchQueue.main**: 메인 스레드의 작업 큐
     - **async**: 비동기 실행 (바로 반환)

     **왜 메인 스레드?**
     - @Published 프로퍼티는 UI 업데이트 트리거
     - SwiftUI/AppKit은 메인 스레드에서만 UI 업데이트 가능

     ```
     백그라운드 스레드 (이 메서드 호출)
       ↓
     DispatchQueue.main.async
       ↓
     메인 스레드 (UI 업데이트 안전)
       ↓
     currentLocation 변경
       ↓
     SwiftUI View 자동 업데이트
     ```

     - Parameter time: 영상 재생 시간 (초 단위, 영상 시작부터의 경과 시간)
     - Returns: 해당 시간의 GPS 좌표, 없으면 nil

     ### 사용 예:
     ```swift
     // 재생 루프에서 호출
     func updatePlayback() {
         let time = syncController.currentTime

         if let location = gpsService.getCurrentLocation(at: time) {
             // 지도 마커 업데이트
             mapView.updateMarker(location)

             // 속도 표시
             speedLabel.text = "\(location.speed ?? 0) km/h"
         }
     }
     ```
     */
    func getCurrentLocation(at time: TimeInterval) -> GPSPoint? {
        // ===== 1단계: 메타데이터 확인 =====
        guard let metadata = metadata else {
            // GPS 데이터가 로드되지 않음
            return nil
        }

        // ===== 2단계: 시간 기반 GPS 점 조회 =====
        // VideoMetadata.gpsPoint(at:)는 보간도 처리
        let location = metadata.gpsPoint(at: time)

        // ===== 3단계: Published 프로퍼티 업데이트 (메인 스레드) =====
        // weak self: 메모리 누수 방지
        // main.async: UI 업데이트는 메인 스레드에서만
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location
        }

        return location
    }

    /**
     ## 시간 범위 내 GPS 점들 조회

     특정 시간 구간의 모든 GPS 좌표를 반환합니다.

     ### 사용 예시:

     1. **특정 구간 경로 하이라이트:**
     ```swift
     // 10초~20초 구간을 빨간색으로 표시
     let points = gpsService.getPoints(from: 10, to: 20)
     mapView.drawRoute(points, color: .red)
     ```

     2. **구간 거리 계산:**
     ```swift
     let points = gpsService.getPoints(from: 60, to: 120)
     let distance = calculateDistance(points)
     print("1분~2분 사이 주행 거리: \(distance) m")
     ```

     3. **구간 최고 속도:**
     ```swift
     let points = gpsService.getPoints(from: 0, to: 60)
     let maxSpeed = points.compactMap { $0.speed }.max() ?? 0
     print("첫 1분간 최고 속도: \(maxSpeed) km/h")
     ```

     ### 필터링 로직:
     ```swift
     metadata.gpsPoints.filter { point in
         let offset = point.timestamp.timeIntervalSince(videoStart)
         return offset >= startTime && offset <= endTime
     }
     ```

     **단계별 설명:**
     ```
     1. point.timestamp: GPS 측정 절대 시각
        예: 2024-10-12 15:00:05

     2. videoStart: 영상 시작 절대 시각
        예: 2024-10-12 15:00:00

     3. timeIntervalSince: 시간 차이 계산
        offset = 15:00:05 - 15:00:00 = 5초

     4. 범위 확인: offset >= 10 && offset <= 20
        → 10초~20초 범위면 포함
     ```

     - Parameters:
       - startTime: 시작 시간 (초 단위)
       - endTime: 종료 시간 (초 단위)

     - Returns: 해당 시간 범위의 GPS 점 배열

     ### 성능:
     - O(n) 시간 복잡도 (n = GPS 점 개수)
     - 1시간 영상 (3600 점) → 매우 빠름
     - 필터링만 하므로 메모리 효율적
     */
    func getPoints(from startTime: TimeInterval, to endTime: TimeInterval) -> [GPSPoint] {
        // ===== 1단계: 데이터 확인 =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return []
        }

        // ===== 2단계: 시간 범위로 필터링 =====
        return metadata.gpsPoints.filter { point in
            // GPS 점의 시간 오프셋 계산
            let offset = point.timestamp.timeIntervalSince(videoStart)

            // 범위 내에 있는지 확인
            return offset >= startTime && offset <= endTime
        }
    }

    /**
     ## 경로 세그먼트 분할

     현재 시간 기준으로 경로를 두 부분으로 나눕니다.
     - **Past**: 이미 지나온 경로
     - **Future**: 앞으로 갈 경로

     ### 시각화 예시:

     ```
     전체 경로:
     A ━━━━ B ━━━━ C ━━━━ D ━━━━ E

     현재 위치: C (30초)

     분할 결과:
     Past:   A ━━━━ B ━━━━ C  (파란색으로 표시)
     Future:             C ━━━━ D ━━━━ E  (회색으로 표시)
     ```

     ### 지도 표시 예:
     ```swift
     let (past, future) = gpsService.getRouteSegments(at: currentTime)

     // 이미 지나온 경로: 파란색 굵은 선
     mapView.drawRoute(past, color: .blue, width: 5)

     // 앞으로 갈 경로: 회색 얇은 선
     mapView.drawRoute(future, color: .gray, width: 2)

     // 현재 위치: 빨간 마커
     if let current = past.last {
         mapView.addMarker(current, color: .red)
     }
     ```

     ### 필터링 로직:

     **Past (이미 지나온 경로):**
     ```swift
     offset <= time

     예: time = 30초
     - 0초 점: 0 <= 30 → ✅ 포함
     - 15초 점: 15 <= 30 → ✅ 포함
     - 30초 점: 30 <= 30 → ✅ 포함
     - 45초 점: 45 <= 30 → ❌ 제외
     ```

     **Future (앞으로 갈 경로):**
     ```swift
     offset > time

     예: time = 30초
     - 30초 점: 30 > 30 → ❌ 제외
     - 45초 점: 45 > 30 → ✅ 포함
     - 60초 점: 60 > 30 → ✅ 포함
     ```

     - Parameter time: 현재 재생 시간 (초 단위)
     - Returns: (past: 지나온 경로, future: 앞으로 갈 경로) 튜플

     ### 튜플이란?
     ```swift
     // 여러 값을 하나로 묶어서 반환
     let result = getRouteSegments(at: 30)

     // 접근 방법 1: 튜플 레이블
     let past = result.past
     let future = result.future

     // 접근 방법 2: 분해 (Destructuring)
     let (past, future) = getRouteSegments(at: 30)
     ```
     */
    func getRouteSegments(at time: TimeInterval) -> (past: [GPSPoint], future: [GPSPoint]) {
        // ===== 1단계: 데이터 확인 =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return ([], [])  // 빈 튜플 반환
        }

        // ===== 2단계: Past 경로 필터링 (이미 지나온 경로) =====
        let past = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        // ===== 3단계: Future 경로 필터링 (앞으로 갈 경로) =====
        let future = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset > time
        }

        // ===== 4단계: 튜플로 반환 =====
        return (past, future)
    }

    /**
     ## 주행 거리 계산

     영상 시작부터 현재 시간까지 주행한 총 거리를 계산합니다.

     ### Haversine Formula

     지구 표면의 두 GPS 좌표 사이 거리를 계산하는 공식입니다.

     ```
     a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
     c = 2 × atan2(√a, √(1−a))
     d = R × c

     여기서:
     - R = 지구 반지름 (6,371 km)
     - lat = 위도 (라디안)
     - lon = 경도 (라디안)
     - Δlat = lat2 - lat1
     - Δlon = lon2 - lon1
     ```

     ### 거리 계산 과정:

     ```
     GPS 점: A(0s) → B(10s) → C(20s) → D(30s)

     거리 AB = A.distance(to: B) = 100m
     거리 BC = B.distance(to: C) = 150m
     거리 CD = C.distance(to: D) = 120m

     time = 30초일 때:
     총 거리 = 100 + 150 + 120 = 370m
     ```

     ### 누적 계산:
     ```swift
     var distance: Double = 0
     for i in 0..<(points.count - 1) {
         distance += points[i].distance(to: points[i + 1])
     }
     ```

     **단계별:**
     ```
     points = [A, B, C, D]

     i = 0: distance += A.distance(to: B)  → 100
     i = 1: distance += B.distance(to: C)  → 250
     i = 2: distance += C.distance(to: D)  → 370
     ```

     - Parameter time: 현재 재생 시간 (초 단위)
     - Returns: 주행 거리 (미터 단위)

     ### 사용 예:
     ```swift
     let distance = gpsService.distanceTraveled(at: currentTime)

     // 킬로미터로 변환
     let km = distance / 1000.0

     // UI 표시
     Text(String(format: "주행 거리: %.2f km", km))
     ```

     ### 정확도:
     - GPS 오차: ±5~10m
     - 계산 오차: 0.1m 이내
     - 실용적으로 충분히 정확
     */
    func distanceTraveled(at time: TimeInterval) -> Double {
        // ===== 1단계: 데이터 확인 =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return 0
        }

        // ===== 2단계: 현재 시간까지의 GPS 점들 필터링 =====
        let points = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        // ===== 3단계: 최소 2개 점 필요 (거리 = 점 사이 간격) =====
        guard points.count >= 2 else {
            // 점이 0~1개면 거리 계산 불가
            return 0
        }

        // ===== 4단계: 누적 거리 계산 =====
        var distance: Double = 0

        // 인접한 점들 사이의 거리를 모두 더함
        for i in 0..<(points.count - 1) {
            // Haversine formula로 두 점 사이 거리 계산
            distance += points[i].distance(to: points[i + 1])
        }

        return distance
    }

    /**
     ## 평균 속도 계산

     영상 시작부터 현재 시간까지의 평균 속도를 계산합니다.

     ### 계산 방법:

     **방법 1: GPS 속도 데이터 사용 (채택됨)**
     ```
     speeds = [30, 35, 40, 45, 40] km/h
     averageSpeed = (30 + 35 + 40 + 45 + 40) / 5
                  = 190 / 5
                  = 38 km/h
     ```

     **방법 2: 거리/시간 (대안)**
     ```
     distance = 1000m
     time = 60s
     speed = (1000 / 60) × 3.6
           = 60 km/h

     × 3.6: m/s → km/h 변환
     ```

     ### compactMap이란?

     `compactMap`은 `map` + `nil 제거`입니다.

     ```swift
     let speeds = points.map { $0.speed }
     // [30, nil, 35, nil, 40]

     let speeds = points.compactMap { $0.speed }
     // [30, 35, 40]  ← nil이 자동 제거됨
     ```

     **동작 원리:**
     ```swift
     points = [
         GPSPoint(speed: 30),
         GPSPoint(speed: nil),
         GPSPoint(speed: 35)
     ]

     compactMap { $0.speed }
     → [30?, nil, 35?]     (map 결과)
     → [30, 35]            (nil 제거)
     ```

     ### reduce란?

     배열의 모든 요소를 하나의 값으로 축약합니다.

     ```swift
     speeds.reduce(0, +)

     = speeds.reduce(0) { total, speed in
         return total + speed
     }
     ```

     **단계별 실행:**
     ```
     speeds = [30, 35, 40]

     초기값 = 0
     step 1: 0 + 30 = 30
     step 2: 30 + 35 = 65
     step 3: 65 + 40 = 105
     최종 = 105
     ```

     **다른 reduce 예시:**
     ```swift
     [1, 2, 3, 4].reduce(0, +)  → 10 (합계)
     [1, 2, 3, 4].reduce(1, *)  → 24 (곱)
     ["a", "b"].reduce("", +)   → "ab" (문자열 결합)
     ```

     - Parameter time: 현재 재생 시간 (초 단위)
     - Returns: 평균 속도 (km/h), 데이터 없으면 nil

     ### 사용 예:
     ```swift
     if let avgSpeed = gpsService.averageSpeed(at: currentTime) {
         Text(String(format: "평균 속도: %.1f km/h", avgSpeed))
     } else {
         Text("속도 데이터 없음")
     }
     ```

     ### nil을 반환하는 경우:
     - GPS 데이터 없음
     - 해당 시간까지 속도 데이터 없음 (GPS에 속도 필드가 없는 경우)
     */
    func averageSpeed(at time: TimeInterval) -> Double? {
        // ===== 1단계: 데이터 확인 =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return nil
        }

        // ===== 2단계: 현재 시간까지의 GPS 점들 필터링 =====
        let points = metadata.gpsPoints.filter { point in
            let offset = point.timestamp.timeIntervalSince(videoStart)
            return offset <= time
        }

        // ===== 3단계: 속도 데이터 추출 (nil 제거) =====
        // compactMap: nil이 아닌 속도만 추출
        let speeds = points.compactMap { $0.speed }

        // ===== 4단계: 속도 데이터 없으면 nil 반환 =====
        guard !speeds.isEmpty else {
            return nil
        }

        // ===== 5단계: 평균 계산 =====
        // reduce(0, +): 모든 속도를 더함
        let sum = speeds.reduce(0, +)

        // 평균 = 총합 / 개수
        return sum / Double(speeds.count)
    }

    /**
     ## GPS 데이터 제거

     모든 GPS 데이터를 메모리에서 제거하고 초기 상태로 되돌립니다.

     ### 호출 시점:

     1. **영상 종료 시:**
     ```swift
     func stopPlayback() {
         syncController.stop()
         gpsService.clear()
         gsensorService.clear()
     }
     ```

     2. **새 영상 로드 전:**
     ```swift
     func loadNewVideo(_ file: VideoFile) {
         gpsService.clear()  // 이전 데이터 제거
         gpsService.loadGPSData(from: file.metadata, startTime: file.timestamp)
     }
     ```

     3. **메모리 정리:**
     ```swift
     func didReceiveMemoryWarning() {
         if !isPlaying {
             gpsService.clear()
         }
     }
     ```

     ### 제거되는 것:
     - metadata: 전체 메타데이터 (nil)
     - videoStartTime: 시작 시각 (nil)
     - routePoints: 경로 점들 (빈 배열)
     - currentLocation: 현재 위치 (nil)
     - summary: 요약 정보 (nil)

     ### @Published 프로퍼티 효과:
     ```
     clear() 호출
       ↓
     routePoints = []
       ↓
     @Published가 감지
       ↓
     SwiftUI View 자동 업데이트
       ↓
     지도에서 경로 사라짐
     ```
     */
    func clear() {
        // ===== 모든 데이터 초기화 =====
        metadata = nil
        videoStartTime = nil
        routePoints = []          // @Published → UI 업데이트
        currentLocation = nil     // @Published → UI 업데이트
        summary = nil             // @Published → UI 업데이트

        // ===== 로그 기록 =====
        debugLog("[GPSService] GPS data cleared")
    }

    // MARK: - Computed Properties

    /**
     ## GPS 데이터 존재 여부

     GPS 데이터가 로드되어 있고, 최소 1개 이상의 GPS 점이 있는지 확인합니다.

     ### 계산 로직:
     ```swift
     metadata?.gpsPoints.isEmpty ?? true

     = if let metadata = metadata {
         return metadata.gpsPoints.isEmpty
     } else {
         return true  // metadata가 nil이면 "비어있음"으로 간주
     }

     hasData = !isEmpty  // 비어있지 않으면 데이터 있음
     ```

     ### nil-coalescing operator (??):
     ```swift
     optional ?? defaultValue

     예:
     metadata?.gpsPoints.isEmpty ?? true

     metadata가 nil이면:     true 반환
     metadata가 있으면:       isEmpty 값 반환
     ```

     ### 사용 예:
     ```swift
     if gpsService.hasData {
         // GPS 지도 표시
         mapView.isHidden = false
         mapView.showRoute()
     } else {
         // "GPS 데이터 없음" 메시지
         mapView.isHidden = true
         showAlert("이 영상에는 GPS 데이터가 없습니다")
     }
     ```

     ### UI 조건부 표시:
     ```swift
     // SwiftUI
     if gpsService.hasData {
         MapView(points: gpsService.routePoints)
     } else {
         Text("GPS 데이터 없음")
             .foregroundColor(.gray)
     }
     ```
     */
    var hasData: Bool {
        // metadata가 nil이거나 gpsPoints가 비어있으면 false
        return !(metadata?.gpsPoints.isEmpty ?? true)
    }

    /**
     ## GPS 점 개수

     로드된 GPS 데이터의 총 점 개수를 반환합니다.

     ### 계산 로직:
     ```swift
     metadata?.gpsPoints.count ?? 0

     = if let metadata = metadata {
         return metadata.gpsPoints.count
     } else {
         return 0  // metadata가 nil이면 0개
     }
     ```

     ### 사용 예:
     ```swift
     // 정보 표시
     Text("GPS 데이터: \(gpsService.pointCount)개 점")

     // 샘플링 레이트 계산
     if let duration = videoDuration {
         let sampleRate = Double(gpsService.pointCount) / duration
         print("GPS 샘플링: \(sampleRate) Hz")
         // 예: 3600 점 / 3600 초 = 1 Hz (1초에 1번)
     }

     // 메모리 사용량 추정
     let memoryUsage = gpsService.pointCount * 50  // 점당 ~50 바이트
     print("GPS 메모리: \(memoryUsage / 1024) KB")
     ```

     ### 샘플링 레이트 예시:
     ```
     1시간 영상:
     - 3600 점 → 1 Hz (1초마다 1번)
     - 7200 점 → 2 Hz (0.5초마다 1번)
     - 1800 점 → 0.5 Hz (2초마다 1번)
     ```
     */
    var pointCount: Int {
        // metadata가 nil이면 0 반환
        return metadata?.gpsPoints.count ?? 0
    }
}

/**
 # GPSService 통합 가이드

 ## 지도 연동 예제:

 ```swift
 import MapKit

 class VideoMapView: UIView, MKMapViewDelegate {
     let gpsService = GPSService()
     let mapView = MKMapView()

     // GPS 데이터 로드 및 지도 초기화
     func setupMap(with videoFile: VideoFile) {
         // GPS 데이터 로드
         gpsService.loadGPSData(
             from: videoFile.metadata,
             startTime: videoFile.timestamp
         )

         guard gpsService.hasData else {
             showNoDataMessage()
             return
         }

         // 전체 경로 표시
         drawFullRoute()

         // 지도 영역 설정 (전체 경로가 보이도록)
         zoomToRoute()
     }

     // 전체 경로 그리기
     func drawFullRoute() {
         let coordinates = gpsService.routePoints.map {
             CLLocationCoordinate2D(
                 latitude: $0.latitude,
                 longitude: $0.longitude
             )
         }

         let polyline = MKPolyline(
             coordinates: coordinates,
             count: coordinates.count
         )

         mapView.addOverlay(polyline)
     }

     // 재생 중 업데이트
     func updateForPlayback(time: TimeInterval) {
         // 현재 위치 마커
         if let location = gpsService.getCurrentLocation(at: time) {
             updateMarker(location)
         }

         // 지나온 경로 vs 앞으로 갈 경로
         let (past, future) = gpsService.getRouteSegments(at: time)
         updateRouteColors(past: past, future: future)

         // 정보 표시
         updateInfoPanel(time: time)
     }

     // 정보 패널 업데이트
     func updateInfoPanel(time: TimeInterval) {
         let distance = gpsService.distanceTraveled(at: time)
         let avgSpeed = gpsService.averageSpeed(at: time) ?? 0

         infoLabel.text = """
         주행 거리: \(String(format: "%.2f", distance / 1000)) km
         평균 속도: \(String(format: "%.1f", avgSpeed)) km/h
         GPS 점: \(gpsService.pointCount)개
         """
     }
 }
 ```

 ## SwiftUI 예제:

 ```swift
 import SwiftUI
 import MapKit

 struct VideoMapView: View {
     @ObservedObject var gpsService: GPSService
     @Binding var currentTime: TimeInterval

     @State private var region = MKCoordinateRegion()

     var body: some View {
         VStack {
             if gpsService.hasData {
                 // 지도
                 Map(coordinateRegion: $region, annotationItems: [gpsService.currentLocation].compactMap { $0 }) { location in
                     MapMarker(
                         coordinate: CLLocationCoordinate2D(
                             latitude: location.latitude,
                             longitude: location.longitude
                         ),
                         tint: .red
                     )
                 }

                 // 정보 패널
                 InfoPanel(
                     distance: gpsService.distanceTraveled(at: currentTime),
                     avgSpeed: gpsService.averageSpeed(at: currentTime),
                     pointCount: gpsService.pointCount
                 )
             } else {
                 Text("GPS 데이터 없음")
                     .foregroundColor(.gray)
             }
         }
         .onChange(of: currentTime) { _ in
             // 현재 위치 업데이트
             _ = gpsService.getCurrentLocation(at: currentTime)
         }
     }
 }

 struct InfoPanel: View {
     let distance: Double
     let avgSpeed: Double?
     let pointCount: Int

     var body: some View {
         HStack(spacing: 20) {
             VStack {
                 Text("주행 거리")
                 Text(String(format: "%.2f km", distance / 1000))
                     .bold()
             }

             if let speed = avgSpeed {
                 VStack {
                     Text("평균 속도")
                     Text(String(format: "%.1f km/h", speed))
                         .bold()
                 }
             }

             VStack {
                 Text("GPS 점")
                 Text("\(pointCount)개")
                     .bold()
             }
         }
         .padding()
         .background(Color.black.opacity(0.7))
         .cornerRadius(10)
     }
 }
 ```

 ## 성능 최적화 팁:

 1. **업데이트 빈도 조절**
    ```swift
    // 너무 자주 업데이트하지 않기
    var lastUpdateTime: TimeInterval = 0

    func updateIfNeeded(time: TimeInterval) {
        if abs(time - lastUpdateTime) > 0.5 {  // 0.5초마다
            _ = gpsService.getCurrentLocation(at: time)
            lastUpdateTime = time
        }
    }
    ```

 2. **경로 간소화 (Douglas-Peucker)**
    ```swift
    // 표시용 경로는 점 개수 줄이기
    let simplifiedRoute = simplifyRoute(
        gpsService.routePoints,
        tolerance: 0.0001  // 약 10m
    )
    ```

 3. **메모리 모니터링**
    ```swift
    // 매우 긴 영상 (10시간+)의 경우
    if gpsService.pointCount > 100000 {
        // 샘플링하여 메모리 절약
        let sampledPoints = samplePoints(gpsService.routePoints, every: 10)
    }
    ```
 */
