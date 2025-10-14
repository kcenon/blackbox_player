/// @file GSensorService.swift
/// @brief Service for managing and querying G-Sensor data synchronized with video playback
/// @author BlackboxPlayer Development Team
/// @details
/// G-센서 데이터를 영상 재생 시간과 동기화하여 실시간 가속도, 충격 이벤트 정보를 제공합니다.

/**
 # GSensorService - G-센서 데이터 관리 서비스

 ## 📱 G-센서(G-Sensor)란?

 **G-센서**는 가속도를 측정하는 센서(가속도계, Accelerometer)입니다.

 ### G의 의미:
 - **G = 중력 가속도** (Gravity)
 - 1G = 9.8 m/s² (지구 중력 가속도)
 - 2G = 19.6 m/s² (중력의 2배 가속도)

 ### G-센서의 역할:
 ```
 차량 움직임 감지
 ↓
 3축 가속도 측정 (X, Y, Z)
 ↓
 충격/급정거/급가속 감지
 ```

 ## 🎯 블랙박스에서의 G-센서 활용

 ### 1. 사고 감지
 ```
 평상시:   0.5G ~ 1.5G (정상 주행)
 급정거:   2.0G ~ 3.0G
 경미 충격: 3.0G ~ 5.0G
 심각 충격: 5.0G 이상
 ```

 ### 2. 이벤트 자동 기록
 - 충격 감지 → 자동으로 이벤트 영상 저장
 - 주차 중 충격 → 주차 감시 모드 활성화

 ### 3. 충격 방향 분석
 ```
 X축: 좌우 (Left ←→ Right)
 Y축: 전후 (Forward ↑↓ Backward)
 Z축: 상하 (Up ↑↓ Down)

 예: 후방 추돌
 - Y축: -3.0G (후방에서 충격)
 - X축: 0.1G (좌우 흔들림 없음)
 - Z축: 0.2G (약간 위로 튐)
 ```

 ### 4. 운전 패턴 분석
 - 급가속/급정거 빈도
 - 급커브 빈도
 - 안전 운전 점수

 ## 💡 3축 가속도 측정

 ### 좌표계:
 ```
 Z (Up)
 ↑
 │
 │
 └────→ X (Right)
 ╱
 ╱
 Y (Forward)
 ```

 ### 정지 상태:
 ```
 X: 0G (좌우 움직임 없음)
 Y: 0G (전후 움직임 없음)
 Z: 1G (중력 영향)
 ```

 ### 가속 상태:
 ```
 급가속:
 - Y: +2.0G (전방 가속)

 급정거:
 - Y: -3.0G (후방으로 밀림)

 우회전:
 - X: +1.5G (우측으로 쏠림)
 ```

 ## 🔍 가속도 크기 계산

 ### 벡터 크기 (Magnitude):
 ```
 magnitude = √(X² + Y² + Z²)

 예: X=2.0, Y=1.0, Z=0.5
 magnitude = √(4 + 1 + 0.25)
 = √5.25
 = 2.29 G
 ```

 ### 유클리드 거리:
 3차원 공간에서 원점(0,0,0)에서 점(X,Y,Z)까지의 직선 거리입니다.

 ## 📊 충격 심각도 분류

 ```
 None (없음):        < 1.5G  정상 주행
 Low (경미):    1.5G ~ 2.5G  과속방지턱
 Moderate (보통): 2.5G ~ 4.0G  급정거, 경미한 접촉
 High (높음):   4.0G ~ 6.0G  중간 충격
 Severe (심각):      > 6.0G  심각한 사고
 ```

 ## 📚 사용 예제

 ```swift
 // 1. 서비스 생성
 let gsensorService = GSensorService()

 // 2. 영상 로드 시 G-센서 데이터 로드
 gsensorService.loadAccelerationData(
 from: videoFile.metadata,
 startTime: videoFile.timestamp
 )

 // 3. 재생 중 현재 가속도 조회
 if let accel = gsensorService.getCurrentAcceleration(at: currentTime) {
 print("현재 가속도: \(accel.magnitude) G")
 print("방향: \(accel.primaryDirection)")
 }

 // 4. 충격 이벤트 찾기
 let impacts = gsensorService.getImpacts(
 from: 0,
 to: videoDuration,
 minSeverity: .moderate
 )
 print("충격 이벤트: \(impacts.count)건")

 // 5. 충격 지점으로 이동
 if let nearest = gsensorService.nearestImpact(to: currentTime) {
 seekToTime(nearest.impact.timestamp)
 }
 ```

 ---

 이 서비스는 영상 재생과 G-센서 데이터를 동기화하여 실시간 충격 모니터링을 제공합니다.
 */

import Foundation
import Combine

// MARK: - G-Sensor Service

/// @class GSensorService
/// @brief G-센서 데이터 관리 서비스
/// @details
/// 영상 재생 시간과 G-센서 데이터를 동기화하여 실시간 가속도, 충격 이벤트 정보를 제공합니다.
///
/// ### 주요 기능:
/// 1. G-센서 데이터 로드 및 관리
/// 2. 재생 시간 기반 가속도 조회
/// 3. 충격 이벤트 감지 및 분류
/// 4. 충격 심각도별/방향별 그룹화
/// 5. 최대/평균 G-force 계산
///
/// ### ObservableObject란?
/// - Combine 프레임워크의 프로토콜
/// - @Published 프로퍼티가 변경되면 자동으로 알림
/// - SwiftUI View가 자동으로 업데이트됨
class GSensorService: ObservableObject {

    // MARK: - Published Properties

    /// @var currentAcceleration
    /// @brief 현재 가속도 데이터
    /// @details
    /// 영상 재생 시간에 해당하는 G-센서 측정값입니다.
    ///
    /// ### @Published private(set)이란?
    /// - **@Published**: 값이 변경되면 자동으로 View 업데이트
    /// - **private(set)**: 외부에서 읽기만 가능, 쓰기 불가 (이 클래스 내에서만 수정)
    ///
    /// ### 이유:
    /// ```swift
    /// // 외부에서:
    /// let accel = gsensorService.currentAcceleration  // OK (읽기)
    /// gsensorService.currentAcceleration = ...        // 컴파일 에러 (쓰기 불가)
    ///
    /// // 내부에서 (이 클래스):
    /// self.currentAcceleration = newData              // OK (쓰기 가능)
    /// ```
    ///
    /// ### AccelerationData란?
    /// ```swift
    /// struct AccelerationData {
    ///     let x: Double              // X축 가속도 (좌우)
    ///     let y: Double              // Y축 가속도 (전후)
    ///     let z: Double              // Z축 가속도 (상하)
    ///     let magnitude: Double      // 가속도 크기 (√(x²+y²+z²))
    ///     let timestamp: Date        // 측정 시각
    ///     let isImpact: Bool         // 충격 이벤트 여부
    ///     let impactSeverity: ImpactSeverity    // 충격 심각도
    ///     let primaryDirection: ImpactDirection  // 주요 충격 방향
    /// }
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// if let accel = gsensorService.currentAcceleration {
    ///     print("X: \(accel.x)G, Y: \(accel.y)G, Z: \(accel.z)G")
    ///     print("크기: \(accel.magnitude)G")
    ///
    ///     if accel.isImpact {
    ///         print("⚠️ 충격 감지! 심각도: \(accel.impactSeverity)")
    ///     }
    /// }
    /// ```
    @Published private(set) var currentAcceleration: AccelerationData?

    /// @var allData
    /// @brief 전체 가속도 데이터
    /// @details
    /// 영상에 포함된 모든 G-센서 측정값 배열입니다.
    ///
    /// ### 용도:
    /// - 전체 주행 패턴 분석
    /// - 그래프 시각화 (가속도 vs 시간)
    /// - 통계 계산 (최대/평균/표준편차)
    ///
    /// ### 데이터 주기:
    /// ```
    /// 블랙박스 G-센서는 보통:
    /// - 10Hz (0.1초마다 1번)
    /// - 50Hz (0.02초마다 1번)
    /// - 100Hz (0.01초마다 1번)
    ///
    /// 1시간 영상 (10Hz):
    /// - 3,600초 × 10 = 36,000 데이터 점
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 그래프 그리기
    /// for data in gsensorService.allData {
    ///     chartView.addPoint(
    ///         x: data.timestamp,
    ///         y: data.magnitude
    ///     )
    /// }
    ///
    /// // 통계 계산
    /// let magnitudes = gsensorService.allData.map { $0.magnitude }
    /// let average = magnitudes.reduce(0, +) / Double(magnitudes.count)
    /// let max = magnitudes.max() ?? 0
    /// ```
    @Published private(set) var allData: [AccelerationData] = []

    /// @var impactEvents
    /// @brief 충격 이벤트 목록
    /// @details
    /// 전체 데이터 중 충격으로 분류된 이벤트들입니다.
    ///
    /// ### 충격 판정 기준:
    /// ```
    /// magnitude > 1.5G  →  충격으로 분류
    ///
    /// 예:
    /// - 1.0G: 정상 주행 → 충격 아님
    /// - 2.0G: 과속방지턱 → 충격 (Low)
    /// - 4.5G: 급정거 → 충격 (High)
    /// ```
    ///
    /// ### 필터링 과정:
    /// ```swift
    /// allData.filter { $0.isImpact }
    ///
    /// = allData 중 isImpact == true인 것만 추출
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 충격 마커 표시
    /// for impact in gsensorService.impactEvents {
    ///     timelineView.addMarker(
    ///         at: impact.timestamp,
    ///         color: severityColor(impact.impactSeverity),
    ///         icon: .warning
    ///     )
    /// }
    ///
    /// // 충격 목록 UI
    /// List(gsensorService.impactEvents) { impact in
    ///     HStack {
    ///         Image(systemName: "exclamationmark.triangle")
    ///         Text(impact.impactSeverity.displayName)
    ///         Text("\(impact.magnitude, specifier: "%.2f")G")
    ///     }
    /// }
    /// ```
    @Published private(set) var impactEvents: [AccelerationData] = []

    /// @var currentGForce
    /// @brief 현재 G-force 크기
    /// @details
    /// 현재 시점의 가속도 크기(magnitude)입니다.
    ///
    /// ### G-force란?
    /// - G-force = 중력 대비 가속도
    /// - 1G = 지구 중력 (9.8 m/s²)
    /// - 2G = 중력의 2배 가속도
    ///
    /// ### 느낌:
    /// ```
    /// 1.0G: 정상 (앉아있는 느낌)
    /// 2.0G: 과속방지턱 (살짝 튐)
    /// 3.0G: 급정거 (앞으로 쏠림)
    /// 5.0G: 충돌 (강한 충격)
    /// 10.0G: 심각한 사고 (생명 위협)
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 실시간 게이지 표시
    /// CircularGauge(
    ///     value: gsensorService.currentGForce,
    ///     minimum: 0,
    ///     maximum: 5,
    ///     warningThreshold: 2.0,
    ///     dangerThreshold: 4.0
    /// )
    ///
    /// // 색상 변경
    /// let color = gsensorService.currentGForce > 3.0 ? .red :
    ///             gsensorService.currentGForce > 1.5 ? .orange : .green
    /// ```
    @Published private(set) var currentGForce: Double = 0.0

    /// @var peakGForce
    /// @brief 최대 G-force (피크)
    /// @details
    /// 현재 세션에서 기록된 최대 가속도 크기입니다.
    ///
    /// ### 계산 시점:
    /// - 데이터 로드 시 전체 데이터에서 최대값 계산
    /// - 영상 전체에서 가장 큰 충격의 크기
    ///
    /// ### 용도:
    /// ```swift
    /// // 요약 정보 표시
    /// Text("최대 충격: \(gsensorService.peakGForce, specifier: "%.2f")G")
    ///
    /// // 위험 경고
    /// if gsensorService.peakGForce > 5.0 {
    ///     Text("⚠️ 심각한 충격이 기록되었습니다")
    ///         .foregroundColor(.red)
    /// }
    ///
    /// // 게이지 범위 조정
    /// let maxScale = max(5.0, gsensorService.peakGForce + 1.0)
    /// CircularGauge(value: current, maximum: maxScale)
    /// ```
    ///
    /// ### 예시:
    /// ```
    /// 영상 A: peakGForce = 2.1G (과속방지턱)
    /// 영상 B: peakGForce = 6.5G (사고 발생)
    /// ```
    @Published private(set) var peakGForce: Double = 0.0

    // MARK: - Private Properties

    /// @var metadata
    /// @brief 영상 메타데이터
    /// @details
    /// G-센서 데이터를 포함한 영상의 모든 메타데이터입니다.
    ///
    /// ### VideoMetadata란?
    /// ```swift
    /// struct VideoMetadata {
    ///     let accelerationData: [AccelerationData]  // G-센서 측정값들
    ///     let gpsPoints: [GPSPoint]                 // GPS 좌표 배열
    ///     let summary: MetadataSummary              // 요약 정보
    /// }
    /// ```
    ///
    /// ### private이란?
    /// - 이 클래스 내부에서만 접근 가능
    /// - 외부에서는 이 변수를 직접 볼 수 없음
    /// - 캡슐화 (Encapsulation)의 원칙
    private var metadata: VideoMetadata?

    /// @var videoStartTime
    /// @brief 영상 시작 시각
    /// @details
    /// 영상이 녹화를 시작한 절대 시각입니다.
    ///
    /// ### 용도:
    /// 시간 오프셋 계산에 사용됩니다.
    ///
    /// ```
    /// 영상 시작: 2024-10-12 15:00:00
    /// G-센서 측정: 2024-10-12 15:00:05
    ///
    /// 오프셋 = G-센서 시각 - 영상 시작
    ///        = 15:00:05 - 15:00:00
    ///        = 5초
    ///
    /// → 영상 재생 5초 시점에 이 G-센서 데이터 표시
    /// ```
    ///
    /// ### Date란?
    /// - Foundation의 날짜/시간 타입
    /// - 절대 시각을 표현 (Unix Epoch 1970-01-01 00:00:00 UTC 기준)
    /// - timeIntervalSince(_:) 메서드로 시간 차이 계산
    private var videoStartTime: Date?

    // MARK: - Public Methods

    /// @brief G-센서 데이터 로드
    /// @param metadata G-센서 데이터를 포함한 영상 메타데이터
    /// @param startTime 영상 녹화 시작 시각
    /// @details
    /// VideoMetadata에서 G-센서 데이터를 추출하여 서비스에 로드합니다.
    ///
    /// ### 호출 시점:
    /// ```swift
    /// // 영상 파일 로드 직후:
    /// func loadVideo(_ file: VideoFile) {
    ///     // ... 영상 디코더 설정
    ///
    ///     gsensorService.loadAccelerationData(
    ///         from: file.metadata,
    ///         startTime: file.timestamp
    ///     )
    ///
    ///     // ... G-센서 UI 업데이트
    /// }
    /// ```
    ///
    /// ### 처리 과정:
    /// ```
    /// 1. metadata 저장 (G-센서 데이터 포함)
    /// 2. videoStartTime 저장 (시간 오프셋 계산용)
    /// 3. allData 설정 (@Published → UI 자동 업데이트)
    /// 4. impactEvents 필터링 (충격만)
    /// 5. peakGForce 계산 (최대값)
    /// 6. 로그 기록
    /// ```
    ///
    /// ### 충격 필터링:
    /// ```swift
    /// metadata.accelerationData.filter { $0.isImpact }
    ///
    /// = accelerationData 중 isImpact == true인 것만
    /// ```
    ///
    /// ### 최대값 계산:
    /// ```swift
    /// metadata.accelerationData.map { $0.magnitude }.max() ?? 0.0
    ///
    /// 단계:
    /// 1. map { $0.magnitude }: 모든 데이터의 magnitude만 추출
    ///    → [1.0, 2.5, 3.2, 1.8, ...]
    /// 2. .max(): 배열에서 최대값 찾기
    ///    → 3.2
    /// 3. ?? 0.0: nil이면 0.0 (데이터 없을 때)
    /// ```
    ///
    /// ### 메모리 영향:
    /// - 가속도 점 1개 ≈ 60 바이트
    /// - 1시간 영상 (36000초, 10Hz G-센서) ≈ 2.2 MB
    /// - 메모리에 안전하게 보관 가능
    func loadAccelerationData(from metadata: VideoMetadata, startTime: Date) {
        // ===== 1단계: 메타데이터 저장 =====
        self.metadata = metadata
        self.videoStartTime = startTime

        // ===== 2단계: 전체 데이터 설정 =====
        self.allData = metadata.accelerationData

        // ===== 3단계: 충격 이벤트 필터링 =====
        // isImpact == true인 데이터만 추출
        self.impactEvents = metadata.accelerationData.filter { $0.isImpact }

        // ===== 4단계: 최대 G-force 계산 =====
        // 모든 데이터 중 가장 큰 magnitude
        self.peakGForce = metadata.accelerationData.map { $0.magnitude }.max() ?? 0.0

        // ===== 5단계: 로그 기록 =====
        infoLog("[GSensorService] Loaded G-Sensor data: \(metadata.accelerationData.count) points, \(impactEvents.count) impacts")
    }

    /// @brief 특정 시간의 가속도 데이터 조회
    /// @param time 영상 재생 시간 (초 단위, 영상 시작부터의 경과 시간)
    /// @return 해당 시간의 가속도 데이터, 없으면 nil
    /// @details
    /// 영상 재생 시간에 해당하는 G-센서 측정값을 반환합니다.
    ///
    /// ### 시간 매칭 방법:
    ///
    /// 1. **정확히 일치하는 G-센서 점이 있는 경우:**
    /// ```
    /// G-센서 데이터: [0.0s, 0.1s, 0.2s, 0.3s, ...]
    /// 재생 시간: 0.2초
    /// → 0.2s 시점의 G-센서 점 반환
    /// ```
    ///
    /// 2. **중간 시간 (보간):**
    /// ```
    /// G-센서 데이터: 0.2초(x=1.0, y=0.5), 0.3초(x=1.2, y=0.6)
    /// 재생 시간: 0.25초
    ///
    /// 선형 보간:
    /// x = 1.0 + (1.2 - 1.0) × 0.5 = 1.1
    /// y = 0.5 + (0.6 - 0.5) × 0.5 = 0.55
    ///
    /// → AccelerationData(x=1.1, y=0.55, ...)
    /// ```
    ///
    /// 3. **G-센서 데이터 없는 경우:**
    /// ```
    /// metadata == nil → nil 반환
    /// ```
    ///
    /// ### weak self란?
    /// ```swift
    /// DispatchQueue.main.async { [weak self] in
    ///     self?.currentAcceleration = acceleration
    /// }
    /// ```
    ///
    /// - **weak**: 약한 참조 (메모리 누수 방지)
    /// - **self?**: self가 nil일 수 있음 (Optional)
    ///
    /// **왜 필요한가?**
    /// ```
    /// GSensorService가 해제됨
    ///   ↓
    /// 하지만 클로저가 아직 실행 대기 중
    ///   ↓
    /// weak self 덕분에 self는 nil
    ///   ↓
    /// self?.currentAcceleration → 안전하게 무시
    /// ```
    ///
    /// **strong 참조였다면:**
    /// ```
    /// GSensorService를 해제하려 함
    ///   ↓
    /// 클로저가 strong self를 붙잡고 있음
    ///   ↓
    /// GSensorService가 메모리에 남음 (메모리 누수!)
    /// ```
    ///
    /// ### DispatchQueue.main.async란?
    /// - **DispatchQueue.main**: 메인 스레드의 작업 큐
    /// - **async**: 비동기 실행 (바로 반환)
    ///
    /// **왜 메인 스레드?**
    /// - @Published 프로퍼티는 UI 업데이트 트리거
    /// - SwiftUI/AppKit은 메인 스레드에서만 UI 업데이트 가능
    ///
    /// ```
    /// 백그라운드 스레드 (이 메서드 호출)
    ///   ↓
    /// DispatchQueue.main.async
    ///   ↓
    /// 메인 스레드 (UI 업데이트 안전)
    ///   ↓
    /// currentAcceleration 변경
    ///   ↓
    /// SwiftUI View 자동 업데이트
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 재생 루프에서 호출
    /// func updatePlayback() {
    ///     let time = syncController.currentTime
    ///
    ///     if let accel = gsensorService.getCurrentAcceleration(at: time) {
    ///         // G-force 게이지 업데이트
    ///         gforceGauge.value = accel.magnitude
    ///
    ///         // 충격 경고
    ///         if accel.isImpact {
    ///             showImpactWarning(accel)
    ///         }
    ///
    ///         // 3축 그래프 업데이트
    ///         xAxisChart.addPoint(accel.x)
    ///         yAxisChart.addPoint(accel.y)
    ///         zAxisChart.addPoint(accel.z)
    ///     }
    /// }
    /// ```
    func getCurrentAcceleration(at time: TimeInterval) -> AccelerationData? {
        // ===== 1단계: 메타데이터 확인 =====
        guard let metadata = metadata else {
            return nil
        }

        // ===== 2단계: 시간 기반 가속도 데이터 조회 =====
        // VideoMetadata.accelerationData(at:)는 보간 처리
        let acceleration = metadata.accelerationData(at: time)

        // ===== 3단계: Published 프로퍼티 업데이트 (메인 스레드) =====
        DispatchQueue.main.async { [weak self] in
            self?.currentAcceleration = acceleration
            self?.currentGForce = acceleration?.magnitude ?? 0.0
        }

        return acceleration
    }

    /// @brief 시간 범위 내 가속도 데이터 조회
    /// @param startTime 시작 시간 (초 단위)
    /// @param endTime 종료 시간 (초 단위)
    /// @return 해당 시간 범위의 가속도 데이터 배열
    /// @details
    /// 특정 시간 구간의 모든 G-센서 측정값을 반환합니다.
    ///
    /// ### 사용 예시:
    ///
    /// 1. **구간 분석:**
    /// ```swift
    /// // 충격 전후 10초 데이터 분석
    /// let impactTime = 30.0
    /// let data = gsensorService.getData(from: impactTime - 10, to: impactTime + 10)
    /// analyzeAccelerationPattern(data)
    /// ```
    ///
    /// 2. **구간 그래프:**
    /// ```swift
    /// // 특정 구간 그래프 그리기
    /// let data = gsensorService.getData(from: 60, to: 120)
    /// for point in data {
    ///     chart.addPoint(x: point.timestamp, y: point.magnitude)
    /// }
    /// ```
    ///
    /// 3. **이벤트 검색:**
    /// ```swift
    /// // 2분~3분 사이 최대 가속도
    /// let data = gsensorService.getData(from: 120, to: 180)
    /// let maxAccel = data.map { $0.magnitude }.max() ?? 0
    /// ```
    ///
    /// ### 필터링 로직:
    /// ```swift
    /// metadata.accelerationData.filter { data in
    ///     let offset = data.timestamp.timeIntervalSince(videoStart)
    ///     return offset >= startTime && offset <= endTime
    /// }
    /// ```
    ///
    /// **단계별 설명:**
    /// ```
    /// 1. data.timestamp: G-센서 측정 절대 시각
    ///    예: 2024-10-12 15:00:05
    ///
    /// 2. videoStart: 영상 시작 절대 시각
    ///    예: 2024-10-12 15:00:00
    ///
    /// 3. timeIntervalSince: 시간 차이 계산
    ///    offset = 15:00:05 - 15:00:00 = 5초
    ///
    /// 4. 범위 확인: offset >= 10 && offset <= 20
    ///    → 10초~20초 범위면 포함
    /// ```
    ///
    /// ### 성능:
    /// - O(n) 시간 복잡도 (n = G-센서 점 개수)
    /// - 1시간 영상 (36000 점) → 매우 빠름
    /// - 필터링만 하므로 메모리 효율적
    func getData(from startTime: TimeInterval, to endTime: TimeInterval) -> [AccelerationData] {
        // ===== 1단계: 데이터 확인 =====
        guard let metadata = metadata,
              let videoStart = videoStartTime else {
            return []
        }

        // ===== 2단계: 시간 범위로 필터링 =====
        return metadata.accelerationData.filter { data in
            let offset = data.timestamp.timeIntervalSince(videoStart)
            return offset >= startTime && offset <= endTime
        }
    }

    /// @brief 시간 범위 내 충격 이벤트 조회
    /// @param startTime 시작 시간 (초 단위)
    /// @param endTime 종료 시간 (초 단위)
    /// @param minSeverity 최소 심각도 (기본값: .moderate)
    /// @return 필터링된 충격 이벤트 배열
    /// @details
    /// 특정 시간 구간의 충격 이벤트를 심각도로 필터링하여 반환합니다.
    ///
    /// ### 필터링 로직:
    /// ```
    /// 1. 시간 범위 필터링: startTime <= offset <= endTime
    /// 2. 심각도 필터링: severityLevel >= minSeverity
    /// ```
    ///
    /// ### severityLevel 함수:
    /// ```swift
    /// enum ImpactSeverity {
    ///     case none     // 0
    ///     case low      // 1
    ///     case moderate // 2
    ///     case high     // 3
    ///     case severe   // 4
    /// }
    ///
    /// severityLevel(impact.impactSeverity) >= severityLevel(minSeverity)
    ///
    /// 예: minSeverity = .moderate (2)
    /// - low (1) >= 2 → ❌ 제외
    /// - moderate (2) >= 2 → ✅ 포함
    /// - high (3) >= 2 → ✅ 포함
    /// - severe (4) >= 2 → ✅ 포함
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 1. 전체 심각한 충격만 조회
    /// let severeImpacts = gsensorService.getImpacts(
    ///     from: 0,
    ///     to: videoDuration,
    ///     minSeverity: .high
    /// )
    ///
    /// // 2. 1분~2분 사이 모든 충격
    /// let impacts = gsensorService.getImpacts(
    ///     from: 60,
    ///     to: 120,
    ///     minSeverity: .low
    /// )
    ///
    /// // 3. 충격 목록 UI
    /// ForEach(impacts) { impact in
    ///     ImpactRow(
    ///         time: impact.timestamp,
    ///         severity: impact.impactSeverity,
    ///         direction: impact.primaryDirection,
    ///         magnitude: impact.magnitude
    ///     )
    /// }
    /// ```
    func getImpacts(
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        minSeverity: ImpactSeverity = .moderate
    ) -> [AccelerationData] {
        // ===== 1단계: 데이터 확인 =====
        guard let videoStart = videoStartTime else {
            return []
        }

        // ===== 2단계: 시간 및 심각도로 필터링 =====
        return impactEvents.filter { impact in
            // 시간 오프셋 계산
            let offset = impact.timestamp.timeIntervalSince(videoStart)

            // 조건 확인:
            // 1. 시간 범위 내
            // 2. 심각도 >= minSeverity
            return offset >= startTime && offset <= endTime &&
                severityLevel(impact.impactSeverity) >= severityLevel(minSeverity)
        }
    }

    /// @brief 시간 범위 내 최대 G-force
    /// @param startTime 시작 시간 (초 단위)
    /// @param endTime 종료 시간 (초 단위)
    /// @return 최대 G-force 크기
    /// @details
    /// 특정 구간의 최대 가속도 크기를 반환합니다.
    ///
    /// ### 계산 과정:
    /// ```
    /// 1. getData(from:to:) 호출 → 구간 데이터 가져오기
    /// 2. map { $0.magnitude } → magnitude만 추출
    /// 3. max() → 최대값 찾기
    /// 4. ?? 0.0 → 데이터 없으면 0.0
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 1. 구간별 최대 가속도
    /// let max1min = gsensorService.maxGForce(from: 0, to: 60)
    /// let max2min = gsensorService.maxGForce(from: 60, to: 120)
    ///
    /// // 2. 충격 전후 최대값 비교
    /// let impactTime = 30.0
    /// let beforeMax = gsensorService.maxGForce(from: impactTime - 5, to: impactTime)
    /// let afterMax = gsensorService.maxGForce(from: impactTime, to: impactTime + 5)
    ///
    /// // 3. 그래프 스케일 결정
    /// let maxInView = gsensorService.maxGForce(from: viewStartTime, to: viewEndTime)
    /// chart.yAxisMax = maxInView + 1.0
    /// ```
    func maxGForce(from startTime: TimeInterval, to endTime: TimeInterval) -> Double {
        // 구간 데이터 가져오기
        let data = getData(from: startTime, to: endTime)

        // magnitude만 추출하고 최대값 반환
        return data.map { $0.magnitude }.max() ?? 0.0
    }

    /// @brief 시간 범위 내 평균 G-force
    /// @param startTime 시작 시간 (초 단위)
    /// @param endTime 종료 시간 (초 단위)
    /// @return 평균 G-force 크기
    /// @details
    /// 특정 구간의 평균 가속도 크기를 반환합니다.
    ///
    /// ### 계산 과정:
    /// ```
    /// 1. getData(from:to:) → 구간 데이터
    /// 2. map { $0.magnitude } → magnitude 배열
    /// 3. reduce(0, +) → 모두 더하기
    /// 4. / count → 개수로 나누기
    /// ```
    ///
    /// ### 예시 계산:
    /// ```
    /// data magnitudes = [1.0, 2.0, 1.5, 3.0, 2.5]
    ///
    /// total = 1.0 + 2.0 + 1.5 + 3.0 + 2.5 = 10.0
    /// average = 10.0 / 5 = 2.0G
    /// ```
    ///
    /// ### reduce란?
    ///
    /// 배열의 모든 요소를 하나의 값으로 축약합니다.
    ///
    /// ```swift
    /// magnitudes.reduce(0, +)
    ///
    /// = magnitudes.reduce(0) { total, magnitude in
    ///     return total + magnitude
    /// }
    /// ```
    ///
    /// **단계별 실행:**
    /// ```
    /// magnitudes = [1.0, 2.0, 1.5]
    ///
    /// 초기값 = 0
    /// step 1: 0 + 1.0 = 1.0
    /// step 2: 1.0 + 2.0 = 3.0
    /// step 3: 3.0 + 1.5 = 4.5
    /// 최종 = 4.5
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 1. 주행 구간 평균 가속도
    /// let avgNormal = gsensorService.averageGForce(from: 0, to: 600)  // 10분
    ///
    /// // 2. 충격 전후 비교
    /// let avgBefore = gsensorService.averageGForce(from: 20, to: 30)
    /// let avgImpact = gsensorService.averageGForce(from: 30, to: 40)
    ///
    /// // 3. 안전 운전 점수
    /// let avgGforce = gsensorService.averageGForce(from: 0, to: duration)
    /// let safetyScore = calculateSafetyScore(avgGforce)
    /// // 낮을수록 안전 운전
    /// ```
    func averageGForce(from startTime: TimeInterval, to endTime: TimeInterval) -> Double {
        // ===== 1단계: 구간 데이터 가져오기 =====
        let data = getData(from: startTime, to: endTime)

        // ===== 2단계: 데이터 없으면 0.0 반환 =====
        guard !data.isEmpty else { return 0.0 }

        // ===== 3단계: 평균 계산 =====
        // magnitude들을 모두 더함
        let total = data.map { $0.magnitude }.reduce(0, +)

        // 개수로 나누어 평균 반환
        return total / Double(data.count)
    }

    /// @brief 충격 이벤트를 심각도별로 그룹화
    /// @return 심각도별로 그룹화된 충격 이벤트 딕셔너리
    /// @details
    /// 모든 충격 이벤트를 심각도(ImpactSeverity)로 분류하여 딕셔너리로 반환합니다.
    ///
    /// ### 반환 형식:
    /// ```swift
    /// [ImpactSeverity: [AccelerationData]]
    ///
    /// 예:
    /// {
    ///     .low: [impact1, impact2],
    ///     .moderate: [impact3, impact4, impact5],
    ///     .high: [impact6],
    ///     .severe: []
    /// }
    /// ```
    ///
    /// ### 그룹화 과정:
    /// ```
    /// for impact in impactEvents {
    ///     severity = impact.impactSeverity
    ///
    ///     if grouped[severity] == nil {
    ///         grouped[severity] = []  // 빈 배열 생성
    ///     }
    ///
    ///     grouped[severity]?.append(impact)  // 추가
    /// }
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 1. 심각도별 카운트
    /// let grouped = gsensorService.impactsBySeverity()
    ///
    /// print("경미: \(grouped[.low]?.count ?? 0)건")
    /// print("보통: \(grouped[.moderate]?.count ?? 0)건")
    /// print("높음: \(grouped[.high]?.count ?? 0)건")
    /// print("심각: \(grouped[.severe]?.count ?? 0)건")
    ///
    /// // 2. 섹션별 UI
    /// ForEach(ImpactSeverity.allCases) { severity in
    ///     Section(header: Text(severity.displayName)) {
    ///         ForEach(grouped[severity] ?? []) { impact in
    ///             ImpactRow(impact: impact)
    ///         }
    ///     }
    /// }
    ///
    /// // 3. 통계 차트
    /// PieChart(data: [
    ///     ("Low", grouped[.low]?.count ?? 0),
    ///     ("Moderate", grouped[.moderate]?.count ?? 0),
    ///     ("High", grouped[.high]?.count ?? 0),
    ///     ("Severe", grouped[.severe]?.count ?? 0)
    /// ])
    /// ```
    func impactsBySeverity() -> [ImpactSeverity: [AccelerationData]] {
        // 빈 딕셔너리 생성
        var grouped: [ImpactSeverity: [AccelerationData]] = [:]

        // 모든 충격 이벤트 순회
        for impact in impactEvents {
            let severity = impact.impactSeverity

            // 해당 severity 키가 없으면 빈 배열 생성
            if grouped[severity] == nil {
                grouped[severity] = []
            }

            // 충격 이벤트 추가
            grouped[severity]?.append(impact)
        }

        return grouped
    }

    /// @brief 충격 이벤트를 방향별로 그룹화
    /// @return 방향별로 그룹화된 충격 이벤트 딕셔너리
    /// @details
    /// 모든 충격 이벤트를 충격 방향(ImpactDirection)으로 분류하여 딕셔너리로 반환합니다.
    ///
    /// ### ImpactDirection:
    /// ```swift
    /// enum ImpactDirection {
    ///     case front      // 전방 충격 (급정거)
    ///     case rear       // 후방 충격 (추돌)
    ///     case left       // 좌측 충격
    ///     case right      // 우측 충격
    ///     case top        // 상단 충격 (위에서 낙하물)
    ///     case bottom     // 하단 충격 (과속방지턱)
    ///     case multiple   // 복합 방향
    /// }
    /// ```
    ///
    /// ### 반환 형식:
    /// ```swift
    /// [ImpactDirection: [AccelerationData]]
    ///
    /// 예:
    /// {
    ///     .front: [impact1, impact2, impact3],
    ///     .rear: [impact4],
    ///     .left: [],
    ///     .right: [impact5, impact6],
    ///     ...
    /// }
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 1. 방향별 카운트
    /// let grouped = gsensorService.impactsByDirection()
    ///
    /// print("전방: \(grouped[.front]?.count ?? 0)건")
    /// print("후방: \(grouped[.rear]?.count ?? 0)건")
    /// print("좌측: \(grouped[.left]?.count ?? 0)건")
    /// print("우측: \(grouped[.right]?.count ?? 0)건")
    ///
    /// // 2. 방향별 화살표 표시
    /// for (direction, impacts) in grouped {
    ///     let arrow = directionArrow(direction)
    ///     Text("\(arrow) \(impacts.count)건")
    /// }
    ///
    /// // 3. 사고 패턴 분석
    /// let rearImpacts = grouped[.rear]?.count ?? 0
    /// if rearImpacts > 0 {
    ///     Text("⚠️ 후방 충격 감지: 추돌 사고 가능성")
    /// }
    /// ```
    func impactsByDirection() -> [ImpactDirection: [AccelerationData]] {
        // 빈 딕셔너리 생성
        var grouped: [ImpactDirection: [AccelerationData]] = [:]

        // 모든 충격 이벤트 순회
        for impact in impactEvents {
            let direction = impact.primaryDirection

            // 해당 direction 키가 없으면 빈 배열 생성
            if grouped[direction] == nil {
                grouped[direction] = []
            }

            // 충격 이벤트 추가
            grouped[direction]?.append(impact)
        }

        return grouped
    }

    /// @brief 현재 시간에 유의미한 가속도가 있는지 확인
    /// @param time 재생 시간 (초 단위)
    /// @return 유의미한 가속도 여부 (true/false)
    /// @details
    /// 현재 시점의 가속도가 임계값(1.5G)을 초과하는지 확인합니다.
    ///
    /// ### 판정 기준:
    /// ```
    /// isSignificant = magnitude > 1.5G
    ///
    /// 예:
    /// - 1.0G → false (정상)
    /// - 1.8G → true (유의미)
    /// - 3.0G → true (충격)
    /// ```
    ///
    /// ### AccelerationData.isSignificant:
    /// ```swift
    /// var isSignificant: Bool {
    ///     return magnitude > 1.5
    /// }
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 1. 경고 표시
    /// if gsensorService.hasSignificantAcceleration(at: currentTime) {
    ///     warningIcon.isHidden = false
    ///     warningIcon.startAnimating()
    /// }
    ///
    /// // 2. 이벤트 마커
    /// if gsensorService.hasSignificantAcceleration(at: time) {
    ///     timeline.addMarker(at: time, color: .orange)
    /// }
    ///
    /// // 3. 통계
    /// var significantCount = 0
    /// for time in stride(from: 0, to: duration, by: 1.0) {
    ///     if gsensorService.hasSignificantAcceleration(at: time) {
    ///         significantCount += 1
    ///     }
    /// }
    /// print("유의미한 가속도 지점: \(significantCount)초")
    /// ```
    func hasSignificantAcceleration(at time: TimeInterval) -> Bool {
        // 현재 시간의 가속도 데이터 가져오기
        guard let acceleration = getCurrentAcceleration(at: time) else {
            return false
        }

        // isSignificant 프로퍼티 확인 (magnitude > 1.5G)
        return acceleration.isSignificant
    }

    /// @brief 지정 시간에 가장 가까운 충격 이벤트 찾기
    /// @param time 목표 시간 (초 단위)
    /// @return (충격 이벤트, 시간 차이) 튜플, 충격 없으면 nil
    /// @details
    /// 주어진 시간에서 가장 가까운 충격 이벤트와 그 시간 차이를 반환합니다.
    ///
    /// ### 알고리즘:
    /// ```
    /// 1. 모든 충격 이벤트의 시간 오프셋 계산
    /// 2. 목표 시간과의 차이(절대값) 계산
    /// 3. 차이가 가장 작은 것 선택
    /// ```
    ///
    /// ### 예시:
    /// ```
    /// 충격 이벤트: [10초, 25초, 50초, 75초]
    /// 목표 시간: 30초
    ///
    /// 차이 계산:
    /// - 10초: |10 - 30| = 20초
    /// - 25초: |25 - 30| = 5초  ← 최소
    /// - 50초: |50 - 30| = 20초
    /// - 75초: |75 - 30| = 45초
    ///
    /// 결과: 25초 충격 이벤트 (차이 5초)
    /// ```
    ///
    /// ### map 사용:
    /// ```swift
    /// impactEvents.map { impact -> (AccelerationData, TimeInterval) in
    ///     let offset = impact.timestamp.timeIntervalSince(videoStart)
    ///     return (impact, abs(offset - time))
    /// }
    ///
    /// = 각 충격 이벤트를 (충격 데이터, 시간 차이) 튜플로 변환
    /// ```
    ///
    /// ### min(by:) 사용:
    /// ```swift
    /// .min(by: { $0.1 < $1.1 })
    ///
    /// = 튜플의 두 번째 요소($0.1, $1.1 = 시간 차이)를 비교하여 최소값 찾기
    /// ```
    ///
    /// ### 튜플이란?
    /// ```swift
    /// // 여러 값을 하나로 묶어서 반환
    /// let result = nearestImpact(to: 30)
    ///
    /// // 접근 방법 1: 튜플 레이블
    /// let impact = result.impact
    /// let offset = result.offset
    ///
    /// // 접근 방법 2: 분해 (Destructuring)
    /// let (impact, offset) = nearestImpact(to: 30)
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 1. "가장 가까운 충격으로 이동" 버튼
    /// Button("충격 지점으로 이동") {
    ///     if let (impact, offset) = gsensorService.nearestImpact(to: currentTime) {
    ///         let impactTime = impact.timestamp.timeIntervalSince(videoStart)
    ///         seekToTime(impactTime)
    ///     }
    /// }
    ///
    /// // 2. 충격 시간 표시
    /// if let (impact, offset) = gsensorService.nearestImpact(to: currentTime) {
    ///     Text("가장 가까운 충격: \(offset, specifier: "%.1f")초 \(offset > 0 ? "후" : "전")")
    /// }
    ///
    /// // 3. 자동 재생
    /// func autoPlayImpacts() {
    ///     if let (impact, _) = gsensorService.nearestImpact(to: currentTime) {
    ///         seekTo(impact.timestamp)
    ///         Timer.scheduledTimer(withTimeInterval: 10.0) { _ in
    ///             autoPlayImpacts()  // 다음 충격으로
    ///         }
    ///     }
    /// }
    /// ```
    func nearestImpact(to time: TimeInterval) -> (impact: AccelerationData, offset: TimeInterval)? {
        // ===== 1단계: 데이터 확인 =====
        guard let videoStart = videoStartTime,
              !impactEvents.isEmpty else {
            return nil
        }

        // ===== 2단계: 각 충격 이벤트와 목표 시간의 차이 계산 =====
        let impactsWithOffsets = impactEvents.map { impact -> (AccelerationData, TimeInterval) in
            // 충격 발생 시간 (영상 시작부터의 오프셋)
            let offset = impact.timestamp.timeIntervalSince(videoStart)

            // 목표 시간과의 차이 (절대값)
            let difference = abs(offset - time)

            return (impact, difference)
        }

        // ===== 3단계: 차이가 가장 작은 것 찾기 =====
        // min(by:): 비교 함수로 최소값 선택
        // $0.1, $1.1: 튜플의 두 번째 요소 (TimeInterval = 차이)
        guard let nearest = impactsWithOffsets.min(by: { $0.1 < $1.1 }) else {
            return nil
        }

        return nearest
    }

    /// @brief G-센서 데이터 제거
    /// @details
    /// 모든 G-센서 데이터를 메모리에서 제거하고 초기 상태로 되돌립니다.
    ///
    /// ### 호출 시점:
    ///
    /// 1. **영상 종료 시:**
    /// ```swift
    /// func stopPlayback() {
    ///     syncController.stop()
    ///     gpsService.clear()
    ///     gsensorService.clear()
    /// }
    /// ```
    ///
    /// 2. **새 영상 로드 전:**
    /// ```swift
    /// func loadNewVideo(_ file: VideoFile) {
    ///     gsensorService.clear()  // 이전 데이터 제거
    ///     gsensorService.loadAccelerationData(from: file.metadata, startTime: file.timestamp)
    /// }
    /// ```
    ///
    /// 3. **메모리 정리:**
    /// ```swift
    /// func didReceiveMemoryWarning() {
    ///     if !isPlaying {
    ///         gsensorService.clear()
    ///     }
    /// }
    /// ```
    ///
    /// ### 제거되는 것:
    /// - metadata: 전체 메타데이터 (nil)
    /// - videoStartTime: 시작 시각 (nil)
    /// - allData: 전체 가속도 데이터 (빈 배열)
    /// - impactEvents: 충격 이벤트 목록 (빈 배열)
    /// - currentAcceleration: 현재 가속도 (nil)
    /// - currentGForce: 현재 G-force (0.0)
    /// - peakGForce: 최대 G-force (0.0)
    ///
    /// ### @Published 프로퍼티 효과:
    /// ```
    /// clear() 호출
    ///   ↓
    /// allData = []
    ///   ↓
    /// @Published가 감지
    ///   ↓
    /// SwiftUI View 자동 업데이트
    ///   ↓
    /// 그래프/게이지에서 데이터 사라짐
    /// ```
    func clear() {
        // ===== 모든 데이터 초기화 =====
        metadata = nil
        videoStartTime = nil
        allData = []                  // @Published → UI 업데이트
        impactEvents = []             // @Published → UI 업데이트
        currentAcceleration = nil     // @Published → UI 업데이트
        currentGForce = 0.0           // @Published → UI 업데이트
        peakGForce = 0.0              // @Published → UI 업데이트

        // ===== 로그 기록 =====
        debugLog("[GSensorService] G-Sensor data cleared")
    }

    // MARK: - Computed Properties

    /// @var hasData
    /// @brief G-센서 데이터 존재 여부
    /// @return G-센서 데이터가 있으면 true, 없으면 false
    /// @details
    /// G-센서 데이터가 로드되어 있고, 최소 1개 이상의 측정값이 있는지 확인합니다.
    ///
    /// ### 계산 로직:
    /// ```swift
    /// metadata?.accelerationData.isEmpty ?? true
    ///
    /// = if let metadata = metadata {
    ///     return metadata.accelerationData.isEmpty
    /// } else {
    ///     return true  // metadata가 nil이면 "비어있음"으로 간주
    /// }
    ///
    /// hasData = !isEmpty  // 비어있지 않으면 데이터 있음
    /// ```
    ///
    /// ### nil-coalescing operator (??):
    /// ```swift
    /// optional ?? defaultValue
    ///
    /// 예:
    /// metadata?.accelerationData.isEmpty ?? true
    ///
    /// metadata가 nil이면:     true 반환
    /// metadata가 있으면:       isEmpty 값 반환
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// if gsensorService.hasData {
    ///     // G-센서 그래프 표시
    ///     chartView.isHidden = false
    ///     chartView.showGraph()
    /// } else {
    ///     // "G-센서 데이터 없음" 메시지
    ///     chartView.isHidden = true
    ///     showAlert("이 영상에는 G-센서 데이터가 없습니다")
    /// }
    /// ```
    var hasData: Bool {
        // metadata가 nil이거나 accelerationData가 비어있으면 false
        return !(metadata?.accelerationData.isEmpty ?? true)
    }

    /// @var dataPointCount
    /// @brief 데이터 점 개수
    /// @return 로드된 G-센서 데이터의 총 점 개수
    /// @details
    /// 로드된 G-센서 측정값의 총 개수를 반환합니다.
    ///
    /// ### 계산 로직:
    /// ```swift
    /// metadata?.accelerationData.count ?? 0
    ///
    /// = if let metadata = metadata {
    ///     return metadata.accelerationData.count
    /// } else {
    ///     return 0  // metadata가 nil이면 0개
    /// }
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 정보 표시
    /// Text("G-센서 데이터: \(gsensorService.dataPointCount)개 점")
    ///
    /// // 샘플링 레이트 계산
    /// if let duration = videoDuration {
    ///     let sampleRate = Double(gsensorService.dataPointCount) / duration
    ///     print("G-센서 샘플링: \(sampleRate) Hz")
    ///     // 예: 36000 점 / 3600 초 = 10 Hz (0.1초에 1번)
    /// }
    ///
    /// // 메모리 사용량 추정
    /// let memoryUsage = gsensorService.dataPointCount * 60  // 점당 ~60 바이트
    /// print("G-센서 메모리: \(memoryUsage / 1024) KB")
    /// ```
    ///
    /// ### 샘플링 레이트 예시:
    /// ```
    /// 1시간 영상:
    /// - 36000 점 → 10 Hz (0.1초마다 1번)
    /// - 180000 점 → 50 Hz (0.02초마다 1번)
    /// - 360000 점 → 100 Hz (0.01초마다 1번)
    /// ```
    var dataPointCount: Int {
        // metadata가 nil이면 0 반환
        return metadata?.accelerationData.count ?? 0
    }

    /// @var impactCount
    /// @brief 충격 이벤트 개수
    /// @return 감지된 충격 이벤트의 총 개수
    /// @details
    /// 감지된 충격 이벤트의 총 개수를 반환합니다.
    ///
    /// ### 사용 예:
    /// ```swift
    /// // 충격 카운트 표시
    /// Text("충격 감지: \(gsensorService.impactCount)건")
    ///
    /// // 조건부 UI
    /// if gsensorService.impactCount > 0 {
    ///     ImpactListView(impacts: gsensorService.impactEvents)
    /// } else {
    ///     Text("충격 이벤트 없음")
    ///         .foregroundColor(.gray)
    /// }
    ///
    /// // 위험도 평가
    /// let riskLevel = gsensorService.impactCount > 10 ? "높음" :
    ///                 gsensorService.impactCount > 5 ? "보통" : "낮음"
    /// ```
    var impactCount: Int {
        return impactEvents.count
    }

    // MARK: - Private Helpers

    /// @brief 심각도를 비교 가능한 수준으로 변환
    /// @param severity 심각도 enum
    /// @return 정수 레벨 (0~4)
    /// @details
    /// ImpactSeverity enum을 정수로 변환하여 크기 비교를 가능하게 합니다.
    ///
    /// ### 변환 표:
    /// ```
    /// .none     → 0
    /// .low      → 1
    /// .moderate → 2
    /// .high     → 3
    /// .severe   → 4
    /// ```
    ///
    /// ### 사용 예:
    /// ```swift
    /// severityLevel(.high) >= severityLevel(.moderate)
    /// → 3 >= 2
    /// → true
    ///
    /// severityLevel(.low) >= severityLevel(.moderate)
    /// → 1 >= 2
    /// → false
    /// ```
    ///
    /// ### 왜 필요한가?
    /// ```swift
    /// // enum은 직접 비교 불가
    /// if impact.impactSeverity >= .moderate  // 컴파일 에러!
    ///
    /// // 정수로 변환하면 비교 가능
    /// if severityLevel(impact.impactSeverity) >= severityLevel(.moderate)  // OK
    /// ```
    private func severityLevel(_ severity: ImpactSeverity) -> Int {
        switch severity {
        case .none: return 0
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .severe: return 4
        }
    }
}

/**
 # GSensorService 통합 가이드

 ## 충격 감지 알고리즘:

 ```swift
 extension AccelerationData {
 // 가속도 크기 계산 (벡터 크기)
 var magnitude: Double {
 return sqrt(x * x + y * y + z * z)
 }

 // 충격 여부 판정
 var isImpact: Bool {
 return magnitude > 1.5  // 1.5G 초과 → 충격
 }

 // 심각도 분류
 var impactSeverity: ImpactSeverity {
 if magnitude < 1.5 {
 return .none
 } else if magnitude < 2.5 {
 return .low
 } else if magnitude < 4.0 {
 return .moderate
 } else if magnitude < 6.0 {
 return .high
 } else {
 return .severe
 }
 }

 // 주요 충격 방향 결정
 var primaryDirection: ImpactDirection {
 let absX = abs(x)
 let absY = abs(y)
 let absZ = abs(z)

 // 가장 큰 축 찾기
 let maxAxis = max(absX, absY, absZ)

 if maxAxis == absX {
 return x > 0 ? .right : .left
 } else if maxAxis == absY {
 return y > 0 ? .front : .rear
 } else {
 return z > 0 ? .top : .bottom
 }
 }
 }
 ```

 ## 실시간 G-force 게이지 UI:

 ```swift
 struct GForceGaugeView: View {
 @ObservedObject var gsensorService: GSensorService

 var body: some View {
 VStack {
 // 원형 게이지
 ZStack {
 // 배경 원
 Circle()
 .stroke(Color.gray.opacity(0.3), lineWidth: 20)

 // G-force 게이지
 Circle()
 .trim(from: 0, to: CGFloat(min(gsensorService.currentGForce / 5.0, 1.0)))
 .stroke(
 gforceColor(gsensorService.currentGForce),
 style: StrokeStyle(lineWidth: 20, lineCap: .round)
 )
 .rotationEffect(.degrees(-90))

 // 수치 표시
 VStack {
 Text(String(format: "%.2f", gsensorService.currentGForce))
 .font(.system(size: 48, weight: .bold))
 Text("G")
 .font(.system(size: 24))
 .foregroundColor(.gray)
 }
 }
 .frame(width: 200, height: 200)

 // 최대값
 Text("Peak: \(String(format: "%.2f", gsensorService.peakGForce))G")
 .font(.caption)
 .foregroundColor(.secondary)
 }
 }

 func gforceColor(_ gforce: Double) -> Color {
 if gforce < 1.5 {
 return .green
 } else if gforce < 3.0 {
 return .orange
 } else {
 return .red
 }
 }
 }
 ```

 ## 3축 가속도 그래프:

 ```swift
 struct AccelerationChartView: View {
 @ObservedObject var gsensorService: GSensorService
 let timeRange: ClosedRange<TimeInterval>

 var body: some View {
 Chart {
 // X축 (좌우)
 ForEach(gsensorService.allData) { data in
 LineMark(
 x: .value("Time", data.timestamp),
 y: .value("X", data.x)
 )
 .foregroundStyle(.red)
 }

 // Y축 (전후)
 ForEach(gsensorService.allData) { data in
 LineMark(
 x: .value("Time", data.timestamp),
 y: .value("Y", data.y)
 )
 .foregroundStyle(.green)
 }

 // Z축 (상하)
 ForEach(gsensorService.allData) { data in
 LineMark(
 x: .value("Time", data.timestamp),
 y: .value("Z", data.z)
 )
 .foregroundStyle(.blue)
 }

 // 충격 이벤트 마커
 ForEach(gsensorService.impactEvents) { impact in
 RuleMark(x: .value("Impact", impact.timestamp))
 .foregroundStyle(.red.opacity(0.5))
 .annotation(position: .top) {
 Image(systemName: "exclamationmark.triangle.fill")
 .foregroundColor(.red)
 }
 }
 }
 .chartXScale(domain: timeRange)
 .chartYScale(domain: -6...6)
 .chartYAxis {
 AxisMarks(position: .leading)
 }
 .chartLegend(position: .bottom) {
 HStack {
 LegendItem(color: .red, label: "X (Left/Right)")
 LegendItem(color: .green, label: "Y (Forward/Backward)")
 LegendItem(color: .blue, label: "Z (Up/Down)")
 }
 }
 }
 }
 ```

 ## 충격 이벤트 목록 UI:

 ```swift
 struct ImpactEventsListView: View {
 @ObservedObject var gsensorService: GSensorService
 let onSelectImpact: (AccelerationData) -> Void

 var body: some View {
 List {
 // 심각도별 섹션
 ForEach(ImpactSeverity.allCases, id: \.self) { severity in
 let impacts = gsensorService.impactsBySeverity()[severity] ?? []

 if !impacts.isEmpty {
 Section(header: Text(severity.displayName)) {
 ForEach(impacts) { impact in
 ImpactRow(impact: impact)
 .onTapGesture {
 onSelectImpact(impact)
 }
 }
 }
 }
 }
 }
 .navigationTitle("충격 이벤트 (\(gsensorService.impactCount))")
 }
 }

 struct ImpactRow: View {
 let impact: AccelerationData

 var body: some View {
 HStack {
 // 심각도 아이콘
 Image(systemName: severityIcon(impact.impactSeverity))
 .foregroundColor(severityColor(impact.impactSeverity))

 VStack(alignment: .leading) {
 // 시간
 Text(formatTime(impact.timestamp))
 .font(.headline)

 // 방향
 Text(directionText(impact.primaryDirection))
 .font(.caption)
 .foregroundColor(.secondary)
 }

 Spacer()

 // G-force
 VStack(alignment: .trailing) {
 Text(String(format: "%.2f", impact.magnitude))
 .font(.title3)
 .bold()
 Text("G")
 .font(.caption)
 .foregroundColor(.secondary)
 }
 }
 }

 func severityIcon(_ severity: ImpactSeverity) -> String {
 switch severity {
 case .none: return "checkmark.circle"
 case .low: return "info.circle"
 case .moderate: return "exclamationmark.circle"
 case .high: return "exclamationmark.triangle"
 case .severe: return "xmark.octagon"
 }
 }

 func severityColor(_ severity: ImpactSeverity) -> Color {
 switch severity {
 case .none: return .green
 case .low: return .blue
 case .moderate: return .orange
 case .high: return .red
 case .severe: return .purple
 }
 }

 func directionText(_ direction: ImpactDirection) -> String {
 switch direction {
 case .front: return "↑ 전방 충격"
 case .rear: return "↓ 후방 충격"
 case .left: return "← 좌측 충격"
 case .right: return "→ 우측 충격"
 case .top: return "⬆ 상단 충격"
 case .bottom: return "⬇ 하단 충격"
 case .multiple: return "⊕ 복합 충격"
 }
 }
 }
 ```

 ## 타임라인 충격 마커:

 ```swift
 struct TimelineWithImpactsView: View {
 @ObservedObject var gsensorService: GSensorService
 @Binding var currentTime: TimeInterval
 let duration: TimeInterval

 var body: some View {
 GeometryReader { geometry in
 ZStack(alignment: .leading) {
 // 타임라인 배경
 Rectangle()
 .fill(Color.gray.opacity(0.3))
 .frame(height: 40)

 // 충격 마커
 ForEach(gsensorService.impactEvents) { impact in
 let offset = impact.timestamp.timeIntervalSince(videoStart)
 let x = (offset / duration) * geometry.size.width

 Rectangle()
 .fill(severityColor(impact.impactSeverity))
 .frame(width: 3, height: 40)
 .offset(x: x)
 }

 // 재생 헤드
 Rectangle()
 .fill(Color.white)
 .frame(width: 2, height: 50)
 .offset(x: (currentTime / duration) * geometry.size.width)
 }
 }
 }
 }
 ```
 */
