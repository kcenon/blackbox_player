/// @file MetadataOverlayView.swift
/// @brief 비디오 위에 실시간 메타데이터를 오버레이로 표시하는 View
/// @author BlackboxPlayer Development Team
/// @details
/// 비디오 위에 실시간 메타데이터(GPS, 속도, G-force)를 오버레이로 표시하는 View입니다.
/// 왼쪽 패널에 속도 게이지와 GPS 좌표, 오른쪽 패널에 타임스탬프와 G-Force 정보를 표시합니다.

import SwiftUI

/// @struct MetadataOverlayView
/// @brief 비디오 위에 실시간 메타데이터를 오버레이로 표시하는 View
///
/// @details
/// 비디오 위에 실시간 메타데이터를 오버레이로 표시하는 View입니다.
///
/// ## 화면 구조
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │  ┌─────────┐                    ┌─────────────┐ │
/// │  │ 85      │                    │ 14:23:45    │ │
/// │  │ km/h    │                    │ 2024-01-15  │ │
/// │  │         │                    │             │ │
/// │  │ GPS     │                    │ G-Force     │ │
/// │  │ 37.566° │                    │ 2.3G        │ │
/// │  │ 126.98° │                    │             │ │
/// │  │         │                    │ EVENT       │ │
/// │  │ Altitude│                    │             │ │
/// │  │ Heading │                    │             │ │
/// │  └─────────┘                    └─────────────┘ │
/// │                                                  │
/// │  [비디오 화면]                                   │
/// │                                                  │
/// └─────────────────────────────────────────────────┘
/// ```
///
/// ## 주요 기능
/// - **왼쪽 패널**: 속도 게이지, GPS 좌표, 고도, 방향
/// - **오른쪽 패널**: 타임스탬프, G-Force, 이벤트 타입 배지
/// - **반투명 배경**: `.opacity(0.6)`로 비디오가 비침
/// - **실시간 업데이트**: currentTime에 따라 메타데이터 자동 업데이트
///
/// ## SwiftUI 핵심 개념
///
/// ### 1. Optional Binding으로 조건부 렌더링
/// ```swift
/// if let gpsPoint = currentGPSPoint, let speed = gpsPoint.speed {
///     speedGauge(speed: speed)
/// }
/// ```
///
/// **Optional Binding이란?**
/// - Optional 값을 안전하게 unwrap하는 패턴
/// - 값이 있으면 (non-nil) 코드 블록 실행
/// - 값이 없으면 (nil) 코드 블록 건너뜀
///
/// **왜 필요한가?**
/// - GPS 데이터가 없을 수 있음 (터널, 실내 등)
/// - 속도 정보가 없을 수 있음 (정지 중, GPS 불량)
/// - nil 체크 없이 사용하면 크래시 발생
///
/// **다중 Optional Binding:**
/// ```swift
/// // 두 조건 모두 만족해야 실행
/// if let gpsPoint = currentGPSPoint,  // 1. GPS 데이터 있음
///    let speed = gpsPoint.speed {     // 2. 속도 데이터 있음
///     speedGauge(speed: speed)
/// }
/// ```
///
/// ### 2. 반투명 오버레이 배경
/// ```swift
/// .background(Color.black.opacity(0.6))
/// ```
///
/// **opacity(0.6)의 효과:**
/// - 0.0: 완전 투명 (보이지 않음)
/// - 0.6: 60% 불투명 (비디오가 40% 비침)
/// - 1.0: 완전 불투명 (비디오 완전히 가림)
///
/// **왜 반투명 배경을 사용하나?**
/// - 텍스트 가독성 확보 (흰 텍스트가 잘 보임)
/// - 비디오 내용도 희미하게 볼 수 있음
/// - 게임 HUD, 자막 등에서 많이 사용하는 패턴
///
/// ### 3. String Formatting
/// ```swift
/// String(format: "%.0f", speed)    // 85
/// String(format: "%.2f", value)    // 2.35
/// String(format: "%+.2f", value)   // +2.35 또는 -2.35
/// ```
///
/// **포맷 지정자:**
/// - `%`: 포맷 시작
/// - `.0f`: 소수점 이하 0자리 (정수로 표시)
/// - `.2f`: 소수점 이하 2자리
/// - `+`: 부호 항상 표시 (+/-)
/// - `f`: float/double 타입
///
/// **실제 예시:**
/// ```
/// speed = 85.7
/// String(format: "%.0f", speed) → "85" (반올림)
///
/// value = 2.3456
/// String(format: "%.2f", value) → "2.35" (반올림)
///
/// value = 1.5
/// String(format: "%+.2f", value) → "+1.50" (부호 포함)
///
/// value = -0.8
/// String(format: "%+.2f", value) → "-0.80" (음수 부호)
/// ```
///
/// ### 4. Text Style로 날짜/시간 포맷팅
/// ```swift
/// Text(date, style: .time)  // 14:23:45
/// Text(date, style: .date)  // 2024-01-15
/// ```
///
/// **Text(date, style:)의 장점:**
/// - 자동으로 현재 로케일에 맞게 포맷팅
/// - DateFormatter 없이 간단하게 사용
/// - 시스템 설정(12/24시간)에 자동 대응
///
/// **사용 가능한 스타일:**
/// ```swift
/// .time     → 14:23:45 (시간만)
/// .date     → 2024-01-15 (날짜만)
/// .timer    → 00:05:23 (타이머 형식)
/// .relative → 3 minutes ago (상대 시간)
/// ```
///
/// ### 5. Computed Properties로 현재 메타데이터 가져오기
/// ```swift
/// private var currentGPSPoint: GPSPoint? {
///     return videoFile.metadata.gpsPoint(at: currentTime)
/// }
/// ```
///
/// **Computed Property란?**
/// - 저장하지 않고 계산해서 반환하는 속성
/// - currentTime이 변경되면 자동으로 재계산됨
/// - View가 다시 그려질 때마다 호출됨
///
/// **왜 사용하나?**
/// - 중복 코드 제거 (여러 곳에서 같은 계산 반복 방지)
/// - 가독성 향상 (의미 있는 이름으로 추상화)
/// - 자동 업데이트 (currentTime 변경 시 자동 반영)
///
/// ### 6. VStack alignment
/// ```swift
/// VStack(alignment: .leading, spacing: 12) { ... }  // 왼쪽 정렬
/// VStack(alignment: .trailing, spacing: 12) { ... } // 오른쪽 정렬
/// ```
///
/// **alignment 옵션:**
/// - `.leading`: 왼쪽 정렬 (시작점)
/// - `.center`: 중앙 정렬 (기본값)
/// - `.trailing`: 오른쪽 정렬 (끝점)
///
/// **왜 다른 alignment를 사용하나?**
/// ```
/// 왼쪽 패널 (.leading):
/// 85
/// km/h
/// GPS
/// 37.566°  ← 모두 왼쪽 정렬
///
/// 오른쪽 패널 (.trailing):
///      14:23:45
///    2024-01-15
///       G-Force
///          2.3G  ← 모두 오른쪽 정렬
/// ```
///
/// ### 7. 동적 색상 로직
/// ```swift
/// private func gforceColor(magnitude: Double) -> Color {
///     if magnitude > 4.0 { return .red }
///     else if magnitude > 2.5 { return .orange }
///     else if magnitude > 1.5 { return .yellow }
///     else { return .green }
/// }
/// ```
///
/// **G-Force 임계값:**
/// ```
/// 0.0 ~ 1.5G  → 녹색 (정상)
/// 1.5 ~ 2.5G  → 노란색 (경고)
/// 2.5 ~ 4.0G  → 주황색 (주의)
/// 4.0G 이상   → 빨간색 (위험)
/// ```
///
/// **실제 시나리오:**
/// - 정상 주행: 0.5 ~ 1.0G (녹색)
/// - 급가속/급제동: 1.5 ~ 2.5G (노란색)
/// - 사고: 4.0G 이상 (빨간색)
///
/// ## 사용 예제
///
/// ### 예제 1: VideoPlayerView에서 사용
/// ```swift
/// struct VideoPlayerView: View {
///     let videoFile: VideoFile
///     @State private var currentTime: TimeInterval = 0.0
///
///     var body: some View {
///         ZStack {
///             // 비디오 화면
///             VideoFrameView(frame: currentFrame)
///
///             // 메타데이터 오버레이
///             MetadataOverlayView(
///                 videoFile: videoFile,
///                 currentTime: currentTime
///             )
///         }
///     }
/// }
/// ```
///
/// ### 예제 2: 토글 가능한 오버레이
/// ```swift
/// struct VideoPlayerView: View {
///     @State private var showMetadata = true
///
///     var body: some View {
///         ZStack {
///             VideoFrameView(frame: currentFrame)
///
///             // 메타데이터 표시 토글
///             if showMetadata {
///                 MetadataOverlayView(
///                     videoFile: videoFile,
///                     currentTime: currentTime
///                 )
///                 .transition(.opacity)
///             }
///         }
///         .toolbar {
///             Button("Toggle Metadata") {
///                 withAnimation {
///                     showMetadata.toggle()
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## 실무 응용
///
/// ### 커스터마이징 옵션 추가
/// ```swift
/// struct MetadataOverlayView: View {
///     let videoFile: VideoFile
///     let currentTime: TimeInterval
///
///     // 커스터마이징 옵션
///     var showSpeed: Bool = true
///     var showGPS: Bool = true
///     var showGForce: Bool = true
///     var overlayOpacity: Double = 0.6
///
///     var body: some View {
///         VStack(alignment: .leading, spacing: 0) {
///             HStack(alignment: .top) {
///                 if showSpeed || showGPS {
///                     leftPanel
///                 }
///
///                 Spacer()
///
///                 if showGForce {
///                     rightPanel
///                 }
///             }
///         }
///         .background(Color.black.opacity(overlayOpacity))
///     }
/// }
/// ```
///
/// ### 키보드 단축키로 표시/숨김
/// ```swift
/// .onKeyPress(.m) {
///     showMetadata.toggle()
///     return .handled
/// }
/// ```
///
/// ### 마우스 호버 시만 표시
/// ```swift
/// @State private var isHovering = false
///
/// ZStack {
///     VideoFrameView(frame: currentFrame)
///
///     if isHovering {
///         MetadataOverlayView(
///             videoFile: videoFile,
///             currentTime: currentTime
///         )
///     }
/// }
/// .onHover { hovering in
///     withAnimation {
///         isHovering = hovering
///     }
/// }
/// ```
///
/// ## 성능 최적화
///
/// ### 1. Computed Properties 대신 캐싱
/// ```swift
/// // 현재: 매번 계산 (비효율적)
/// private var currentGPSPoint: GPSPoint? {
///     return videoFile.metadata.gpsPoint(at: currentTime)
/// }
///
/// // 개선: onChange로 캐싱
/// @State private var cachedGPSPoint: GPSPoint?
///
/// .onChange(of: currentTime) { newTime in
///     cachedGPSPoint = videoFile.metadata.gpsPoint(at: newTime)
/// }
/// ```
///
/// ### 2. Monospaced 폰트로 레이아웃 안정화
/// ```swift
/// Text(value)
///     .font(.system(.caption, design: .monospaced))
///     // ✅ 숫자가 바뀌어도 너비 일정 → UI 안정적
/// ```
///
/// ## 테스트 데이터
///
/// ### Mock GPS Point
/// ```swift
/// extension GPSPoint {
///     static func mock() -> GPSPoint {
///         return GPSPoint(
///             latitude: 37.5665,
///             longitude: 126.9780,
///             speed: 85.0,
///             altitude: 35.0,
///             heading: 270.0,
///             satelliteCount: 12,
///             timestamp: Date()
///         )
///     }
/// }
/// ```
///
/// ### Mock Acceleration Data
/// ```swift
/// extension AccelerationData {
///     static func mock(magnitude: Double = 2.5) -> AccelerationData {
///         let x = magnitude * 0.6
///         let y = magnitude * 0.3
///         let z = magnitude * 0.1
///         return AccelerationData(
///             x: x,
///             y: y,
///             z: z,
///             timestamp: Date()
///         )
///     }
/// }
/// ```
///
/// ### Preview with Different States
/// ```swift
/// struct MetadataOverlayView_Previews: PreviewProvider {
///     static var previews: some View {
///         VStack(spacing: 20) {
///             // 정상 상태
///             ZStack {
///                 Color.black
///                 MetadataOverlayView(
///                     videoFile: videoFileWith(gforce: 1.0),
///                     currentTime: 10.0
///                 )
///             }
///             .previewDisplayName("Normal")
///
///             // 경고 상태
///             ZStack {
///                 Color.black
///                 MetadataOverlayView(
///                     videoFile: videoFileWith(gforce: 2.0),
///                     currentTime: 10.0
///                 )
///             }
///             .previewDisplayName("Warning")
///
///             // 위험 상태
///             ZStack {
///                 Color.black
///                 MetadataOverlayView(
///                     videoFile: videoFileWith(gforce: 5.0),
///                     currentTime: 10.0
///                 )
///             }
///             .previewDisplayName("Danger")
///         }
///         .frame(width: 800, height: 600)
///     }
/// }
/// ```
///
struct MetadataOverlayView: View {
    // MARK: - Properties

    /// @var videoFile
    /// @brief 비디오 파일
    ///
    /// **포함된 정보:**
    /// - metadata: GPS, 가속도 센서 등의 메타데이터
    /// - timestamp: 비디오 녹화 시작 시간
    /// - eventType: 이벤트 타입 (일반, 주차, 이벤트)
    let videoFile: VideoFile

    /// @var currentTime
    /// @brief 현재 재생 시간
    ///
    /// **TimeInterval이란?**
    /// - Double의 typealias (실제로는 Double 타입)
    /// - 초 단위로 시간을 표현 (예: 10.5초, 125.3초)
    ///
    /// **사용 방식:**
    /// ```
    /// currentTime = 0.0    → 비디오 시작
    /// currentTime = 10.5   → 10.5초 지점
    /// currentTime = 125.3  → 2분 5.3초 지점
    /// ```
    ///
    /// **왜 필요한가?**
    /// - 현재 시간에 해당하는 GPS 데이터 가져오기
    /// - 현재 시간에 해당하는 가속도 데이터 가져오기
    /// - 타임스탬프 계산 (녹화 시작 시간 + currentTime)
    let currentTime: TimeInterval

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // 왼쪽 패널: 속도와 GPS
                //
                // **표시 내용:**
                // - 속도 게이지 (큰 숫자)
                // - GPS 좌표
                // - 고도
                // - 방향 (heading)
                leftPanel

                Spacer()

                // 오른쪽 패널: G-Force와 타임스탬프
                //
                // **표시 내용:**
                // - 타임스탬프 (시간 + 날짜)
                // - G-Force 크기
                // - X, Y, Z 축 값
                // - 이벤트 타입 배지
                rightPanel
            }
            .padding()

            Spacer()
        }
    }

    // MARK: - Left Panel

    /// @brief 왼쪽 패널
    ///
    /// ## 구조
    /// ```
    /// ┌─────────┐
    /// │ 85      │  ← 속도 게이지
    /// │ km/h    │
    /// │         │
    /// │ GPS     │  ← GPS 좌표
    /// │ 37.566° │
    /// │ 126.98° │
    /// │ 12 sats │
    /// │         │
    /// │ Altitude│  ← 고도
    /// │ 35 m    │
    /// │         │
    /// │ Heading │  ← 방향
    /// │ 270°    │
    /// └─────────┘
    /// ```
    ///
    /// ## Optional Binding 패턴
    /// ```swift
    /// if let gpsPoint = currentGPSPoint, let speed = gpsPoint.speed {
    ///     speedGauge(speed: speed)
    /// }
    /// ```
    ///
    /// **왜 이렇게 하나?**
    /// - GPS 데이터가 없을 수 있음 (currentGPSPoint가 nil)
    /// - 속도 정보가 없을 수 있음 (gpsPoint.speed가 nil)
    /// - 두 조건 모두 만족할 때만 speedGauge 표시
    ///
    /// **실제 시나리오:**
    /// ```
    /// 터널 진입: currentGPSPoint = nil → 속도 게이지 숨김
    /// GPS 수신 중: currentGPSPoint ≠ nil, speed = 85.0 → 속도 게이지 표시
    /// 정지 상태: speed = 0.0 → "0 km/h" 표시
    /// ```
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 속도 게이지
            //
            // GPS 데이터와 속도 정보가 모두 있을 때만 표시
            if let gpsPoint = currentGPSPoint, let speed = gpsPoint.speed {
                speedGauge(speed: speed)
            }

            // GPS 좌표
            //
            // GPS 데이터가 있을 때만 표시
            if let gpsPoint = currentGPSPoint {
                gpsCoordinates(gpsPoint: gpsPoint)
            }

            // 고도
            //
            // GPS 데이터와 고도 정보가 모두 있을 때만 표시
            if let gpsPoint = currentGPSPoint, let altitude = gpsPoint.altitude {
                metadataRow(
                    icon: "arrow.up.arrow.down",
                    label: "Altitude",
                    value: String(format: "%.0f m", altitude)
                )
            }

            // 방향 (Heading)
            //
            // GPS 데이터와 방향 정보가 모두 있을 때만 표시
            if let gpsPoint = currentGPSPoint, let heading = gpsPoint.heading {
                metadataRow(
                    icon: "location.north.fill",
                    label: "Heading",
                    value: String(format: "%.0f°", heading)
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        // ✅ opacity(0.6): 60% 불투명 → 비디오가 40% 비침
        .cornerRadius(8)
    }

    // MARK: - Right Panel

    /// @brief 오른쪽 패널
    ///
    /// ## 구조
    /// ```
    /// ┌─────────────┐
    /// │   14:23:45  │  ← 타임스탬프 (시간)
    /// │ 2024-01-15  │  ← 타임스탬프 (날짜)
    /// │             │
    /// │   G-Force   │  ← G-Force 크기
    /// │     2.3G    │
    /// │   X: +1.2   │
    /// │   Y: +0.8   │
    /// │   Z: -0.3   │
    /// │             │
    /// │ ⚠️ IMPACT   │  ← 충격 경고 (4G 이상일 때)
    /// │             │
    /// │   EVENT     │  ← 이벤트 타입 배지
    /// └─────────────┘
    /// ```
    ///
    /// ## alignment: .trailing
    /// ```swift
    /// VStack(alignment: .trailing, spacing: 12) { ... }
    /// ```
    ///
    /// **왜 .trailing을 사용하나?**
    /// - 오른쪽 정렬로 깔끔하게 정리됨
    /// - 숫자가 오른쪽으로 정렬되어 읽기 쉬움
    /// - 왼쪽 패널(.leading)과 대칭을 이룸
    private var rightPanel: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // 타임스탬프
            //
            // 비디오 시작 시간 + currentTime
            timestampDisplay

            // G-Force
            //
            // 가속도 데이터가 있을 때만 표시
            if let accelData = currentAccelerationData {
                gforceDisplay(accelData: accelData)
            }

            // 이벤트 타입 배지
            //
            // 일반/주차/이벤트 구분
            EventBadge(eventType: videoFile.eventType)
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    // MARK: - Speed Gauge

    /// @brief 속도 게이지
    ///
    /// ## 구조
    /// ```
    /// ┌─────────┐
    /// │   85    │  ← 큰 숫자 (48pt, bold)
    /// │  km/h   │  ← 단위 (작은 글씨, 반투명)
    /// └─────────┘
    /// ```
    ///
    /// ## .rounded 디자인
    /// ```swift
    /// .font(.system(size: 48, weight: .bold, design: .rounded))
    /// ```
    ///
    /// **design 옵션:**
    /// - `.default`: 일반 시스템 폰트
    /// - `.serif`: 세리프 폰트 (장식 있음)
    /// - `.rounded`: 둥근 폰트 (부드러운 느낌)
    /// - `.monospaced`: 고정폭 폰트 (숫자 정렬)
    ///
    /// **왜 .rounded를 사용하나?**
    /// - 숫자가 부드럽고 읽기 쉬움
    /// - 현대적이고 친근한 느낌
    /// - 대시보드, 게이지에 적합
    ///
    /// ## 시각적 게이지 추가
    /// - SpeedometerGaugeView: 반원형 속도계
    /// - 속도 범위별 색상 코딩
    /// - 부드러운 애니메이션
    private func speedGauge(speed: Double) -> some View {
        VStack(spacing: 8) {
            // 시각적 속도계 게이지
            SpeedometerGaugeView(speed: speed)
                .frame(width: 140, height: 90)

            Divider()
                .background(Color.white.opacity(0.3))
        }
    }

    // MARK: - GPS Coordinates

    /// @brief GPS 좌표 표시
    ///
    /// ## 구조
    /// ```
    /// ┌─────────────┐
    /// │ 📍 GPS      │  ← 아이콘 + 라벨
    /// │ 37.5665°    │  ← 위도
    /// │ 126.9780°   │  ← 경도
    /// │ 📡 12 sats  │  ← 위성 개수
    /// └─────────────┘
    /// ```
    ///
    /// ## gpsPoint.decimalString
    /// ```swift
    /// Text(gpsPoint.decimalString)
    ///     .font(.system(.caption, design: .monospaced))
    /// ```
    ///
    /// **decimalString이란?**
    /// - GPSPoint에서 제공하는 Computed Property
    /// - 위도/경도를 소수점 형식으로 반환
    /// - 예: "37.5665°, 126.9780°"
    ///
    /// **왜 monospaced 폰트를 사용하나?**
    /// - 숫자의 너비가 일정 → 정렬이 깔끔함
    /// - 좌표 값이 바뀌어도 레이아웃 안정적
    ///
    /// ## 위성 개수 표시
    /// ```swift
    /// if let satelliteCount = gpsPoint.satelliteCount {
    ///     HStack(spacing: 4) {
    ///         Image(systemName: "antenna.radiowaves.left.and.right")
    ///         Text("\(satelliteCount) satellites")
    ///     }
    ///     .foregroundColor(.white.opacity(0.6))
    /// }
    /// ```
    ///
    /// **위성 개수의 의미:**
    /// - 3개 이하: GPS 불량 (정확도 낮음)
    /// - 4~8개: 보통 (일반 주행 가능)
    /// - 9개 이상: 양호 (높은 정확도)
    /// - 12개 이상: 매우 양호 (최고 정확도)
    private func gpsCoordinates(gpsPoint: GPSPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text("GPS")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white.opacity(0.8))

            Text(gpsPoint.decimalString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)

            // 위성 개수
            //
            // 위성 개수가 있을 때만 표시
            if let satelliteCount = gpsPoint.satelliteCount {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("\(satelliteCount) satellites")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - G-Force Display

    /// @brief G-Force 표시
    ///
    /// ## 구조
    /// ```
    /// ┌─────────────┐
    /// │  G-Force 📈 │  ← 라벨 + 아이콘
    /// │    2.3G     │  ← 크기 (동적 색상)
    /// │   X: +1.2   │  ← X축 값
    /// │   Y: +0.8   │  ← Y축 값
    /// │   Z: -0.3   │  ← Z축 값
    /// │             │
    /// │ ⚠️ IMPACT   │  ← 충격 경고 (4G 이상)
    /// └─────────────┘
    /// ```
    ///
    /// ## 동적 색상
    /// ```swift
    /// .foregroundColor(gforceColor(magnitude: accelData.magnitude))
    /// ```
    ///
    /// **색상 임계값:**
    /// ```
    /// 0.0 ~ 1.5G  → 녹색 (정상)
    /// 1.5 ~ 2.5G  → 노란색 (경고)
    /// 2.5 ~ 4.0G  → 주황색 (주의)
    /// 4.0G 이상   → 빨간색 (위험)
    /// ```
    ///
    /// ## X, Y, Z 축 값
    /// ```swift
    /// axisValue(label: "X", value: accelData.x)
    /// axisValue(label: "Y", value: accelData.y)
    /// axisValue(label: "Z", value: accelData.z)
    /// ```
    ///
    /// **각 축의 의미:**
    /// - **X축**: 좌우 방향 (차선 변경, 커브)
    /// - **Y축**: 앞뒤 방향 (가속, 제동)
    /// - **Z축**: 상하 방향 (과속방지턱, 점프)
    ///
    /// **실제 예시:**
    /// ```
    /// 급제동:
    /// X: +0.3 (약간 흔들림)
    /// Y: -3.2 (뒤로 강하게 밀림)
    /// Z: +0.5 (약간 들림)
    ///
    /// 좌회전:
    /// X: +2.1 (오른쪽으로 밀림)
    /// Y: +0.8 (속도 감소)
    /// Z: -0.2 (약간 기울어짐)
    /// ```
    ///
    /// ## 충격 경고
    /// ```swift
    /// if accelData.isImpact {
    ///     HStack {
    ///         Image(systemName: "exclamationmark.triangle.fill")
    ///         Text(accelData.impactSeverity.displayName.uppercased())
    ///     }
    ///     .foregroundColor(.red)
    ///     .background(Color.red.opacity(0.2))
    /// }
    /// ```
    ///
    /// **isImpact란?**
    /// - AccelerationData의 Computed Property
    /// - magnitude가 임계값(4.0G) 이상이면 true
    /// - 사고 순간을 자동으로 감지
    ///
    /// **impactSeverity:**
    /// - `.minor`: 경미한 충격 (4~6G)
    /// - `.moderate`: 중간 충격 (6~8G)
    /// - `.severe`: 심각한 충격 (8G 이상)
    private func gforceDisplay(accelData: AccelerationData) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Text("G-Force")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.8))

            // 크기 (Magnitude)
            //
            // accelData.magnitudeString: "2.3G" 형식
            // 색상은 크기에 따라 동적으로 변경
            Text(accelData.magnitudeString)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(gforceColor(magnitude: accelData.magnitude))

            // X, Y, Z 값
            VStack(alignment: .trailing, spacing: 2) {
                axisValue(label: "X", value: accelData.x)
                axisValue(label: "Y", value: accelData.y)
                axisValue(label: "Z", value: accelData.z)
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))

            // 충격 경고
            //
            // isImpact = true일 때만 표시 (4G 이상)
            if accelData.isImpact {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(accelData.impactSeverity.displayName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
            }
        }
    }

    /// @brief 축 값 표시
    ///
    /// ## 구조
    /// ```
    /// X: +1.23
    /// ^  ^
    /// │  └─ 값 (부호 포함, 소수점 2자리)
    /// └──── 라벨
    /// ```
    ///
    /// ## String(format: "%+.2f", value)
    /// ```swift
    /// Text(String(format: "%+.2f", value))
    /// ```
    ///
    /// **%+.2f의 의미:**
    /// - `%`: 포맷 시작
    /// - `+`: 부호 항상 표시 (+/-)
    /// - `.2`: 소수점 이하 2자리
    /// - `f`: float/double 타입
    ///
    /// **실제 예시:**
    /// ```
    /// value = 1.234   → "+1.23"
    /// value = -0.567  → "-0.57"
    /// value = 0.0     → "+0.00"
    /// ```
    ///
    /// **왜 부호를 항상 표시하나?**
    /// - 방향을 명확하게 알 수 있음
    /// - +: 양의 방향 (오른쪽, 앞, 위)
    /// - -: 음의 방향 (왼쪽, 뒤, 아래)
    private func axisValue(label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundColor(.white.opacity(0.6))
            Text(String(format: "%+.2f", value))
                .foregroundColor(.white)
        }
    }

    /// @brief G-Force 크기에 따른 색상
    ///
    /// ## 색상 임계값
    /// ```
    /// 0.0 ~ 1.5G  → 녹색 (정상)
    /// 1.5 ~ 2.5G  → 노란색 (경고)
    /// 2.5 ~ 4.0G  → 주황색 (주의)
    /// 4.0G 이상   → 빨간색 (위험)
    /// ```
    ///
    /// ## 실제 시나리오
    ///
    /// ### 정상 주행 (0.5 ~ 1.0G) - 녹색
    /// ```
    /// - 직선 도로 정속 주행
    /// - 완만한 커브
    /// - 부드러운 가속/감속
    /// ```
    ///
    /// ### 경고 (1.5 ~ 2.5G) - 노란색
    /// ```
    /// - 급가속 (신호 출발)
    /// - 급제동 (갑작스런 정지)
    /// - 급격한 차선 변경
    /// ```
    ///
    /// ### 주의 (2.5 ~ 4.0G) - 주황색
    /// ```
    /// - 매우 급격한 제동 (돌발 상황)
    /// - 고속 회전
    /// - 과속방지턱 고속 통과
    /// ```
    ///
    /// ### 위험 (4.0G 이상) - 빨간색
    /// ```
    /// - 충돌 사고
    /// - 급격한 전복
    /// - 심각한 충격
    /// ```
    ///
    /// ## if-else 연쇄
    /// ```swift
    /// if magnitude > 4.0 { return .red }
    /// else if magnitude > 2.5 { return .orange }
    /// else if magnitude > 1.5 { return .yellow }
    /// else { return .green }
    /// ```
    ///
    /// **왜 4.0부터 확인하나?**
    /// - 큰 값부터 확인해야 정확함
    /// - 역순으로 하면 잘못된 결과:
    ///   ```
    ///   magnitude = 5.0
    ///   if magnitude > 1.5 { return .yellow }  // ❌ 노란색 반환 (잘못됨)
    ///   ```
    private func gforceColor(magnitude: Double) -> Color {
        if magnitude > 4.0 {
            return .red
        } else if magnitude > 2.5 {
            return .orange
        } else if magnitude > 1.5 {
            return .yellow
        } else {
            return .green
        }
    }

    // MARK: - Timestamp Display

    /// @brief 타임스탬프 표시
    ///
    /// ## 구조
    /// ```
    /// ┌─────────────┐
    /// │  14:23:45   │  ← 시간 (큰 글씨)
    /// │ 2024-01-15  │  ← 날짜 (작은 글씨)
    /// └─────────────┘
    /// ```
    ///
    /// ## 시간 계산
    /// ```swift
    /// videoFile.timestamp.addingTimeInterval(currentTime)
    /// ```
    ///
    /// **계산 과정:**
    /// ```
    /// videoFile.timestamp: 2024-01-15 14:23:00 (녹화 시작 시간)
    /// currentTime: 45.0 (45초)
    /// → 결과: 2024-01-15 14:23:45
    /// ```
    ///
    /// **addingTimeInterval이란?**
    /// - Date 타입의 메서드
    /// - 현재 날짜/시간에 초 단위로 시간을 더함
    /// - TimeInterval은 Double의 typealias
    ///
    /// ## Text(date, style:) 사용법
    /// ```swift
    /// Text(date, style: .time)  // 14:23:45
    /// Text(date, style: .date)  // 2024-01-15
    /// ```
    ///
    /// **장점:**
    /// - DateFormatter 없이 간단하게 사용
    /// - 자동으로 로케일에 맞게 포맷팅
    /// - 시스템 설정(12/24시간)에 자동 대응
    ///
    /// **다른 스타일:**
    /// ```swift
    /// .time       → 14:23:45
    /// .date       → 2024-01-15
    /// .timer      → 00:45:23 (타이머 형식)
    /// .relative   → 45 seconds ago
    /// ```
    ///
    /// ## .rounded 디자인
    /// - 시간 표시에 부드러운 느낌
    /// - 숫자가 읽기 쉬움
    private var timestampDisplay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(videoFile.timestamp.addingTimeInterval(currentTime), style: .time)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.white)

            Text(videoFile.timestamp.addingTimeInterval(currentTime), style: .date)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Metadata Row

    /// @brief 메타데이터 행
    ///
    /// ## 구조
    /// ```
    /// ┌──────────────────┐
    /// │ 🧭 Heading   270° │
    /// │ ^  ^         ^    │
    /// │ │  │         └─ 값
    /// │ │  └─────────── 라벨
    /// │ └──────────────── 아이콘
    /// └──────────────────┘
    /// ```
    ///
    /// ## 사용 예제
    /// ```swift
    /// metadataRow(
    ///     icon: "arrow.up.arrow.down",
    ///     label: "Altitude",
    ///     value: String(format: "%.0f m", 35.0)
    /// )
    /// // 결과: "🔼 Altitude    35 m"
    ///
    /// metadataRow(
    ///     icon: "location.north.fill",
    ///     label: "Heading",
    ///     value: String(format: "%.0f°", 270.0)
    /// )
    /// // 결과: "🧭 Heading    270°"
    /// ```
    ///
    /// ## .frame(width: 16)
    /// ```swift
    /// Image(systemName: icon)
    ///     .frame(width: 16)
    /// ```
    ///
    /// **왜 아이콘 너비를 고정하나?**
    /// - 아이콘마다 너비가 다름
    /// - 고정하지 않으면 텍스트 위치가 들쭉날쭉
    /// - 16px로 고정하면 정렬이 깔끔함
    ///
    /// **예시:**
    /// ```
    /// 너비 고정 안 함:
    /// 🔼 Altitude    35 m
    /// 🧭 Heading   270°  ← 텍스트 위치 불일치 ❌
    ///
    /// 너비 고정:
    /// 🔼 Altitude    35 m
    /// 🧭 Heading    270°  ← 텍스트 위치 일치 ✅
    /// ```
    ///
    /// ## Spacer()의 역할
    /// ```swift
    /// HStack {
    ///     Image(...)
    ///     Text(label)
    ///     Spacer()  // 여기서 공간 확장
    ///     Text(value)
    /// }
    /// ```
    ///
    /// **Spacer()가 하는 일:**
    /// - 남은 공간을 모두 차지함
    /// - 값(value)을 오른쪽 끝으로 밀어냄
    /// - 라벨과 값 사이에 적절한 간격 형성
    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    // MARK: - Helper Methods

    /// @brief 현재 시간의 GPS 포인트
    ///
    /// ## Computed Property란?
    /// ```swift
    /// private var currentGPSPoint: GPSPoint? {
    ///     return videoFile.metadata.gpsPoint(at: currentTime)
    /// }
    /// ```
    ///
    /// **특징:**
    /// - 값을 저장하지 않고 계산해서 반환
    /// - currentTime이 변경되면 자동으로 재계산됨
    /// - View가 다시 그려질 때마다 호출됨
    ///
    /// **왜 함수 대신 Computed Property를 사용하나?**
    /// ```swift
    /// // 함수 방식
    /// func currentGPSPoint() -> GPSPoint? { ... }
    /// if let gpsPoint = currentGPSPoint() { ... }  // 괄호 필요
    ///
    /// // Computed Property 방식
    /// var currentGPSPoint: GPSPoint? { ... }
    /// if let gpsPoint = currentGPSPoint { ... }  // 괄호 불필요 (더 자연스러움)
    /// ```
    ///
    /// ## videoFile.metadata.gpsPoint(at:)
    /// ```swift
    /// videoFile.metadata.gpsPoint(at: currentTime)
    /// ```
    ///
    /// **gpsPoint(at:) 메서드:**
    /// - VideoMetadata의 메서드
    /// - 주어진 시간(TimeInterval)에 해당하는 GPS 데이터 반환
    /// - 보간(interpolation)으로 정확한 위치 계산
    ///
    /// **작동 방식:**
    /// ```
    /// GPS 데이터:
    /// [0.0초: (37.5665, 126.9780)]
    /// [5.0초: (37.5670, 126.9785)]
    ///
    /// currentTime = 2.5초 (중간)
    /// → 보간 계산: (37.5667, 126.9782)
    /// ```
    ///
    /// ## Optional 반환 타입
    /// ```swift
    /// var currentGPSPoint: GPSPoint?  // nil일 수 있음
    /// ```
    ///
    /// **nil이 되는 경우:**
    /// - GPS 데이터가 전혀 없음
    /// - 해당 시간에 GPS 수신 안 됨 (터널, 실내)
    /// - 메타데이터 파싱 실패
    private var currentGPSPoint: GPSPoint? {
        return videoFile.metadata.gpsPoint(at: currentTime)
    }

    /// @brief 현재 시간의 가속도 데이터
    ///
    /// ## Computed Property
    /// ```swift
    /// private var currentAccelerationData: AccelerationData? {
    ///     return videoFile.metadata.accelerationData(at: currentTime)
    /// }
    /// ```
    ///
    /// **특징:**
    /// - currentTime이 변경되면 자동으로 재계산됨
    /// - View 업데이트 시마다 호출됨
    /// - 중복 코드 제거 (여러 곳에서 사용)
    ///
    /// ## videoFile.metadata.accelerationData(at:)
    /// ```swift
    /// videoFile.metadata.accelerationData(at: currentTime)
    /// ```
    ///
    /// **accelerationData(at:) 메서드:**
    /// - VideoMetadata의 메서드
    /// - 주어진 시간에 해당하는 가속도 데이터 반환
    /// - 보간(interpolation)으로 정확한 값 계산
    ///
    /// **작동 방식:**
    /// ```
    /// 가속도 데이터:
    /// [0.0초: (x:0.5, y:0.8, z:-0.1)]
    /// [1.0초: (x:1.5, y:1.8, z:0.1)]
    ///
    /// currentTime = 0.5초 (중간)
    /// → 보간 계산:
    ///   x = 0.5 + (1.5-0.5)*0.5 = 1.0
    ///   y = 0.8 + (1.8-0.8)*0.5 = 1.3
    ///   z = -0.1 + (0.1-(-0.1))*0.5 = 0.0
    ///   → (x:1.0, y:1.3, z:0.0)
    /// ```
    ///
    /// ## Optional 반환 타입
    /// ```swift
    /// var currentAccelerationData: AccelerationData?  // nil일 수 있음
    /// ```
    ///
    /// **nil이 되는 경우:**
    /// - 가속도 센서 데이터가 없음
    /// - 해당 시간에 센서 오류
    /// - 메타데이터 파싱 실패
    private var currentAccelerationData: AccelerationData? {
        return videoFile.metadata.accelerationData(at: currentTime)
    }
}

// MARK: - Preview

/// @brief Preview Provider
///
/// ## ZStack으로 검은 배경 추가
/// ```swift
/// ZStack {
///     Color.black          // 배경 (비디오 대신)
///     MetadataOverlayView  // 오버레이
/// }
/// ```
///
/// **왜 ZStack을 사용하나?**
/// - 실제 비디오 화면에 오버레이되는 것을 시뮬레이션
/// - 검은 배경으로 텍스트 가독성 확인
/// - 반투명 배경(.opacity(0.6))의 효과 확인
///
/// ## VideoFile.allSamples.first!
/// ```swift
/// videoFile: VideoFile.allSamples.first!
/// ```
///
/// **allSamples란?**
/// - VideoFile에서 제공하는 static 샘플 데이터
/// - 테스트/Preview용 Mock 데이터
/// - GPS, 가속도 센서 데이터 포함
///
/// **!를 사용하는 이유:**
/// - Preview는 개발 환경에서만 실행됨
/// - 샘플 데이터는 항상 존재함이 보장됨
/// - 프로덕션 코드가 아니므로 강제 unwrap 허용
///
/// ## currentTime: 10.0
/// - 비디오 시작 후 10초 지점
/// - 해당 시간의 GPS, 가속도 데이터 표시
/// - 다양한 시간대를 테스트하려면 값 변경
struct MetadataOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            MetadataOverlayView(
                videoFile: VideoFile.allSamples.first!,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
