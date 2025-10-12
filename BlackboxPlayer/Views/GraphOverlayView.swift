/// @file GraphOverlayView.swift
/// @brief Graph overlay showing acceleration data
/// @author BlackboxPlayer Development Team
/// @details 가속도 센서 데이터를 실시간 그래프로 표시하는 오버레이 View입니다.

import SwiftUI

/// # GraphOverlayView
///
/// 가속도 센서 데이터를 실시간 그래프로 표시하는 오버레이 View입니다.
///
/// ## 화면 구조
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │                                                  │
/// │                                                  │
/// │  ┌────────────────────────────────────────┐     │
/// │  │ 📊 G-Force         2.3G    X Y Z       │     │
/// │  │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│     │
/// │  │        ╱╲              ⚠                │     │
/// │  │ ━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│     │
/// │  │       ╲ ╱                               │     │
/// │  │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│     │
/// │  └────────────────────────────────────────┘     │
/// │  ^X(빨강), Y(초록), Z(파랑) 축 + 충격 마커^     │
/// └─────────────────────────────────────────────────┘
/// ```
///
/// ## 주요 기능
/// - **3축 그래프**: X, Y, Z 축 데이터를 각각 빨강, 초록, 파랑 선으로 표시
/// - **시간 윈도우**: 최근 10초 데이터만 표시 (슬라이딩 윈도우)
/// - **충격 이벤트**: 4G 이상 충격 지점에 배경 하이라이트 + 점선 마커
/// - **현재 시간**: 노란색 점선으로 현재 재생 위치 표시
/// - **그리드**: 배경 격자로 가독성 향상
///
/// ## SwiftUI 핵심 개념
///
/// ### 1. GeometryReader로 동적 그래프 그리기
/// ```swift
/// GeometryReader { geometry in
///     Path { path in
///         let x = geometry.size.width * ratio
///         let y = geometry.size.height * (1 - ratio)
///         path.addLine(to: CGPoint(x: x, y: y))
///     }
/// }
/// ```
///
/// **GeometryReader란?**
/// - 부모 View의 크기와 위치 정보를 제공
/// - 자식 View가 동적으로 크기를 계산할 수 있게 해줌
/// - 그래프처럼 화면 크기에 따라 변하는 UI에 필수
///
/// **왜 필요한가?**
/// - 그래프는 고정 크기가 아님
/// - 화면 크기에 맞춰 점의 위치를 계산해야 함
/// - geometry.size를 사용해 픽셀 좌표 계산
///
/// ### 2. Path로 라인 그래프 그리기
/// ```swift
/// Path { path in
///     path.move(to: CGPoint(x: x1, y: y1))  // 시작점
///     path.addLine(to: CGPoint(x: x2, y: y2))  // 다음 점
///     path.addLine(to: CGPoint(x: x3, y: y3))  // 다음 점
/// }
/// .stroke(Color.red, lineWidth: 2)
/// ```
///
/// **Path란?**
/// - SwiftUI에서 커스텀 도형을 그리는 방법
/// - move(to:): 펜을 이동 (그리지 않음)
/// - addLine(to:): 선을 그으며 이동
///
/// **그래프 그리는 과정:**
/// 1. 첫 데이터 포인트로 move
/// 2. 나머지 포인트들로 addLine
/// 3. stroke로 선 그리기
///
/// ### 3. KeyPath로 동적 속성 접근
/// ```swift
/// func linePath(for keyPath: KeyPath<AccelerationData, Double>, ...) {
///     let value = data[keyPath: keyPath]  // \.x, \.y, \.z
/// }
///
/// // 사용 예:
/// linePath(for: \.x, color: .red)    // X축 그래프
/// linePath(for: \.y, color: .green)  // Y축 그래프
/// linePath(for: \.z, color: .blue)   // Z축 그래프
/// ```
///
/// **KeyPath란?**
/// - 타입의 속성을 참조하는 방법
/// - `\.x`는 AccelerationData의 x 속성을 가리킴
/// - 동적으로 속성에 접근 가능
///
/// **왜 사용하나?**
/// - 중복 코드 제거
/// - X, Y, Z 축 그래프를 하나의 함수로 처리
/// - 같은 로직을 다른 속성에 적용
///
/// ### 4. Time Window 패턴 (슬라이딩 윈도우)
/// ```swift
/// private let timeWindow: TimeInterval = 10.0
///
/// var visibleAccelerationData: [AccelerationData] {
///     let startTime = max(0, currentTime - timeWindow)
///     let endTime = currentTime
///     return gsensorService.getData(from: startTime, to: endTime)
/// }
/// ```
///
/// **Time Window란?**
/// - 일정 시간 범위의 데이터만 표시
/// - 10초 윈도우: 현재 시간 기준 최근 10초
/// - 슬라이딩: currentTime이 증가하면 윈도우도 이동
///
/// **시각적 표현:**
/// ```
/// 전체 데이터: [0초──────30초──────60초──────90초]
///
/// currentTime = 30초, timeWindow = 10초
/// visibleData: [20초──────30초]
///                ^startTime ^endTime
///
/// currentTime = 40초 (1초 후)
/// visibleData:    [30초──────40초]
///                   ^윈도우가 오른쪽으로 이동
/// ```
///
/// ### 5. 좌표 변환 (데이터 → 픽셀)
/// ```swift
/// func xPosition(for time: TimeInterval, startTime: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
///     let relativeTime = time - startTime
///     let ratio = relativeTime / timeWindow
///     return CGFloat(ratio) * geometry.size.width
/// }
///
/// func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
///     let maxValue: Double = 3.0
///     let ratio = (value + maxValue) / (maxValue * 2)
///     return geometry.size.height * (1.0 - CGFloat(ratio))
/// }
/// ```
///
/// **X 좌표 변환 (시간 → 픽셀):**
/// ```
/// timeWindow = 10초
/// geometry.size.width = 400px
///
/// time = 25초, startTime = 20초
/// relativeTime = 25 - 20 = 5초
/// ratio = 5 / 10 = 0.5 (50% 위치)
/// x = 0.5 * 400 = 200px (중앙)
/// ```
///
/// **Y 좌표 변환 (값 → 픽셀):**
/// ```
/// maxValue = 3.0 (±3G 범위)
/// geometry.size.height = 120px
///
/// value = 1.5G
/// ratio = (1.5 + 3) / 6 = 0.75
/// y = 120 * (1 - 0.75) = 30px (위쪽)
///
/// value = 0G
/// ratio = (0 + 3) / 6 = 0.5
/// y = 120 * (1 - 0.5) = 60px (중앙)
///
/// value = -3G
/// ratio = (-3 + 3) / 6 = 0
/// y = 120 * (1 - 0) = 120px (아래쪽)
/// ```
///
/// ### 6. ForEach로 동적 요소 그리기
/// ```swift
/// ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
///     let y = yPosition(for: Double(value), in: geometry)
///     Path { path in
///         path.move(to: CGPoint(x: 0, y: y))
///         path.addLine(to: CGPoint(x: geometry.size.width, y: y))
///     }
///     .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
/// }
/// ```
///
/// **ForEach의 활용:**
/// - 배열의 각 요소에 대해 View 생성
/// - 그리드 선 5개를 동적으로 생성 (-2G, -1G, 0G, 1G, 2G)
/// - id: \.self로 값 자체를 식별자로 사용
///
/// ## 사용 예제
///
/// ### 예제 1: VideoPlayerView에서 사용
/// ```swift
/// struct VideoPlayerView: View {
///     @StateObject private var gsensorService = GSensorService()
///     @State private var currentTime: TimeInterval = 0.0
///
///     var body: some View {
///         ZStack {
///             VideoFrameView(frame: currentFrame)
///
///             GraphOverlayView(
///                 gsensorService: gsensorService,
///                 currentTime: currentTime
///             )
///         }
///     }
/// }
/// ```
///
/// ### 예제 2: 토글 가능한 그래프
/// ```swift
/// @State private var showGraph = true
///
/// ZStack {
///     VideoFrameView(frame: currentFrame)
///
///     if showGraph {
///         GraphOverlayView(
///             gsensorService: gsensorService,
///             currentTime: currentTime
///         )
///         .transition(.move(edge: .bottom))
///     }
/// }
/// .toolbar {
///     Button("Toggle Graph") {
///         withAnimation {
///             showGraph.toggle()
///         }
///     }
/// }
/// ```
///
/// ## 실무 응용
///
/// ### 시간 윈도우 조절 기능
/// ```swift
/// @State private var timeWindow: TimeInterval = 10.0
///
/// VStack {
///     GraphOverlayView(
///         gsensorService: gsensorService,
///         currentTime: currentTime,
///         timeWindow: timeWindow
///     )
///
///     Picker("Time Window", selection: $timeWindow) {
///         Text("5s").tag(5.0)
///         Text("10s").tag(10.0)
///         Text("20s").tag(20.0)
///     }
/// }
/// ```
///
/// ### 축 선택 기능 (X, Y, Z 개별 표시)
/// ```swift
/// @State private var showX = true
/// @State private var showY = true
/// @State private var showZ = true
///
/// if showX {
///     linePath(for: \.x, in: geometry, color: .red)
/// }
/// if showY {
///     linePath(for: \.y, in: geometry, color: .green)
/// }
/// if showZ {
///     linePath(for: \.z, in: geometry, color: .blue)
/// }
/// ```
///
/// ### 줌 기능 (Y축 범위 조절)
/// ```swift
/// @State private var yAxisRange: Double = 3.0
///
/// func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
///     let ratio = (value + yAxisRange) / (yAxisRange * 2)
///     return geometry.size.height * (1.0 - CGFloat(ratio))
/// }
/// ```
///
/// ## 성능 최적화
///
/// ### 1. 데이터 샘플링 (너무 많은 점 방지)
/// ```swift
/// var visibleAccelerationData: [AccelerationData] {
///     let allData = gsensorService.getData(from: startTime, to: endTime)
///     // 최대 100개 포인트로 제한
///     let stride = max(1, allData.count / 100)
///     return Array(allData.enumerated().filter { $0.offset % stride == 0 }.map { $0.element })
/// }
/// ```
///
/// ### 2. DrawingGroup으로 Metal 렌더링
/// ```swift
/// ZStack {
///     // 그래프 요소들
/// }
/// .drawingGroup()  // ✅ Metal로 렌더링 (성능 향상)
/// ```
///
/// ### 3. 변경되지 않는 요소 캐싱
/// ```swift
/// // 그리드는 변하지 않으므로 한 번만 그리기
/// @State private var gridView: some View = gridLines()
///
/// ZStack {
///     gridView  // ✅ 캐시된 그리드
///     // 동적 그래프들
/// }
/// ```
///
/// @struct GraphOverlayView
/// @brief 가속도 센서 데이터를 그래프로 표시하는 View
struct GraphOverlayView: View {
    // MARK: - Properties

    /// @var gsensorService
    /// @brief G-Sensor 서비스 (@ObservedObject)
    ///
    /// **GSensorService란?**
    /// - 가속도 센서 데이터를 관리하는 서비스 클래스
    /// - 충격 이벤트 감지 및 관리
    /// - @Published 속성 변경 시 View 자동 업데이트
    ///
    /// **주요 기능:**
    /// - `hasData`: 가속도 데이터 존재 여부
    /// - `currentAcceleration`: 현재 시간의 가속도 데이터
    /// - `getData(from:to:)`: 특정 시간 범위의 데이터 가져오기
    /// - `getImpacts(from:to:minSeverity:)`: 충격 이벤트 가져오기
    @ObservedObject var gsensorService: GSensorService

    /// @var currentTime
    /// @brief 현재 재생 시간
    ///
    /// **용도:**
    /// - 시간 윈도우의 끝점 (endTime = currentTime)
    /// - 현재 시간 인디케이터 표시 위치
    /// - 보이는 데이터 범위 계산
    let currentTime: TimeInterval

    /// @var timeWindow
    /// @brief 시간 윈도우 (표시할 시간 범위)
    ///
    /// **TimeInterval이란?**
    /// - Double의 typealias (초 단위)
    /// - 10.0 = 10초
    ///
    /// **Time Window란?**
    /// - 그래프에 표시할 시간 범위
    /// - 10초: 최근 10초 데이터만 표시
    /// - 슬라이딩 윈도우: currentTime이 증가하면 함께 이동
    ///
    /// **예시:**
    /// ```
    /// timeWindow = 10.0
    /// currentTime = 30.0
    /// → 표시 범위: 20.0초 ~ 30.0초
    ///
    /// currentTime = 35.0 (5초 후)
    /// → 표시 범위: 25.0초 ~ 35.0초
    /// ```
    private let timeWindow: TimeInterval = 10.0

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()

            HStack {
                // 가속도 데이터가 있을 때만 그래프 표시
                //
                // gsensorService.hasData: 가속도 데이터 1개 이상 있는지 확인
                if gsensorService.hasData {
                    accelerationGraph
                        .frame(width: 400, height: 180)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding()
                }

                Spacer()
            }
        }
    }

    // MARK: - Acceleration Graph

    /// @var accelerationGraph
    /// @brief 가속도 그래프
    ///
    /// ## 구조
    /// ```
    /// ┌────────────────────────────────────────┐
    /// │ 📊 G-Force         2.3G    X Y Z       │  ← 헤더
    /// │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│  ← 그리드
    /// │        ╱╲              ⚠                │  ← 그래프
    /// │ ━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│  ← 0G 라인
    /// │       ╲ ╱                               │  ← 그래프
    /// │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│  ← 그리드
    /// └────────────────────────────────────────┘
    /// ```
    ///
    /// ## 헤더 구성
    /// - **왼쪽**: 📊 아이콘 + "G-Force" 라벨
    /// - **중앙**: 현재 G-Force 값 + 충격 정도
    /// - **오른쪽**: X, Y, Z 축 범례 (빨강, 초록, 파랑)
    ///
    /// ## EnhancedAccelerationGraphView
    /// ```swift
    /// EnhancedAccelerationGraphView(
    ///     accelerationData: visibleAccelerationData,
    ///     impactEvents: visibleImpactEvents,
    ///     currentTime: currentTime,
    ///     timeWindow: timeWindow
    /// )
    /// ```
    ///
    /// **전달하는 데이터:**
    /// - visibleAccelerationData: 보이는 범위의 가속도 데이터
    /// - visibleImpactEvents: 보이는 범위의 충격 이벤트
    /// - currentTime: 현재 재생 시간
    /// - timeWindow: 시간 윈도우 (10초)
    private var accelerationGraph: some View {
        VStack(spacing: 8) {
            // Title and Current G-Force
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
                Text("G-Force")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                // Current G-Force Display
                //
                // 현재 시간의 G-Force 크기와 충격 정도 표시
                if let currentAccel = gsensorService.currentAcceleration {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currentAccel.magnitudeString)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(gforceColor(for: currentAccel.magnitude))

                        // 충격 이벤트일 때만 표시
                        if currentAccel.isImpact {
                            Text(currentAccel.impactSeverity.displayName)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Legend (범례)
                //
                // X, Y, Z 축 색상 안내
                HStack(spacing: 12) {
                    legendItem(color: .red, label: "X")
                    legendItem(color: .green, label: "Y")
                    legendItem(color: .blue, label: "Z")
                }
                .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal)
            .padding(.top, 8)

            // Graph
            //
            // 실제 그래프를 그리는 View
            EnhancedAccelerationGraphView(
                accelerationData: visibleAccelerationData,
                impactEvents: visibleImpactEvents,
                currentTime: currentTime,
                timeWindow: timeWindow
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
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
    /// **사용 위치:**
    /// - 현재 G-Force 값 표시 색상
    ///
    /// **MetadataOverlayView의 gforceColor와 동일:**
    /// - 일관된 색상 체계 유지
    /// - 사용자에게 익숙한 시각적 피드백
    private func gforceColor(for magnitude: Double) -> Color {
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

    /// @brief 범례 항목
    ///
    /// ## 구조
    /// ```
    /// ● X
    /// ^  ^
    /// │  └─ 라벨 (X, Y, Z)
    /// └──── 색상 원 (빨강, 초록, 파랑)
    /// ```
    ///
    /// **Circle().fill(color):**
    /// - 색상으로 채워진 원
    /// - .frame(width: 6, height: 6): 작은 점
    ///
    /// **사용 예:**
    /// ```swift
    /// legendItem(color: .red, label: "X")   → ● X (빨간 점)
    /// legendItem(color: .green, label: "Y") → ● Y (초록 점)
    /// legendItem(color: .blue, label: "Z")  → ● Z (파란 점)
    /// ```
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Helper Methods

    /// @var visibleAccelerationData
    /// @brief 보이는 범위의 가속도 데이터
    ///
    /// ## Computed Property
    /// - currentTime이 변경되면 자동으로 재계산
    /// - View 업데이트 시마다 호출됨
    ///
    /// ## 시간 범위 계산
    /// ```swift
    /// let startTime = max(0, currentTime - timeWindow)
    /// let endTime = currentTime
    /// ```
    ///
    /// **max(0, ...)를 사용하는 이유:**
    /// - currentTime이 10초 미만일 때 음수 방지
    /// - 예: currentTime = 5초, timeWindow = 10초
    ///   → startTime = max(0, 5 - 10) = max(0, -5) = 0초
    ///
    /// **예시:**
    /// ```
    /// currentTime = 30초, timeWindow = 10초
    /// startTime = max(0, 30 - 10) = 20초
    /// endTime = 30초
    /// → getData(from: 20, to: 30) 호출
    /// → 20초~30초 데이터 반환
    /// ```
    ///
    /// ## getData(from:to:)
    /// - GSensorService의 메서드
    /// - 특정 시간 범위의 가속도 데이터 반환
    /// - 필터링 + 정렬된 배열 반환
    private var visibleAccelerationData: [AccelerationData] {
        let startTime = max(0, currentTime - timeWindow)
        let endTime = currentTime
        return gsensorService.getData(from: startTime, to: endTime)
    }

    /// @var visibleImpactEvents
    /// @brief 보이는 범위의 충격 이벤트
    ///
    /// ## Computed Property
    /// - currentTime이 변경되면 자동으로 재계산
    /// - 충격 이벤트만 필터링
    ///
    /// ## getImpacts(from:to:minSeverity:)
    /// ```swift
    /// gsensorService.getImpacts(from: startTime, to: endTime, minSeverity: .moderate)
    /// ```
    ///
    /// **minSeverity: .moderate란?**
    /// - 최소 충격 강도 필터링
    /// - .moderate 이상만 표시 (보통, 높음, 심각)
    /// - .low는 제외 (너무 많은 마커 방지)
    ///
    /// **ImpactSeverity 레벨:**
    /// ```
    /// .none     → 충격 없음 (4G 미만)
    /// .low      → 경미 (4~6G) ← 제외
    /// .moderate → 보통 (6~8G) ← 포함
    /// .high     → 높음 (8~10G) ← 포함
    /// .severe   → 심각 (10G 이상) ← 포함
    /// ```
    ///
    /// **왜 .moderate 이상만?**
    /// - 그래프가 너무 복잡해지는 것 방지
    /// - 중요한 충격만 강조
    /// - 시각적 노이즈 감소
    private var visibleImpactEvents: [AccelerationData] {
        let startTime = max(0, currentTime - timeWindow)
        let endTime = currentTime
        return gsensorService.getImpacts(from: startTime, to: endTime, minSeverity: .moderate)
    }
}

// MARK: - Enhanced Acceleration Graph View

/// # EnhancedAccelerationGraphView
///
/// 가속도 데이터를 그래프로 렌더링하는 View입니다.
///
/// ## 그래프 요소
/// 1. **배경 그리드**: 가로/세로 격자선 (0.1 opacity)
/// 2. **0G 라인**: 중앙 수평선 (0.3 opacity)
/// 3. **충격 배경**: 충격 지점에 반투명 배경
/// 4. **X, Y, Z 축 선**: 각각 빨강, 초록, 파랑
/// 5. **충격 마커**: 점선 수직선
/// 6. **현재 시간**: 노란색 점선 (오른쪽 끝)
///
/// ## Path로 그래프 그리기
/// ```swift
/// Path { path in
///     path.move(to: CGPoint(x: x1, y: y1))
///     path.addLine(to: CGPoint(x: x2, y: y2))
///     path.addLine(to: CGPoint(x: x3, y: y3))
/// }
/// .stroke(Color.red, lineWidth: 2)
/// ```
///
/// **작동 방식:**
/// 1. move(to:): 시작점으로 이동 (선 그리지 않음)
/// 2. addLine(to:): 현재 위치에서 새 위치까지 선 그리기
/// 3. stroke: 선의 색상과 두께 지정
///
/// @struct EnhancedAccelerationGraphView
/// @brief 가속도 데이터 그래프 렌더링 View
struct EnhancedAccelerationGraphView: View {
    // MARK: - Properties

    /// @var accelerationData
    /// @brief 가속도 데이터 배열
    ///
    /// **보이는 범위의 데이터:**
    /// - visibleAccelerationData에서 전달됨
    /// - 최근 10초 (timeWindow) 범위
    /// - 시간순으로 정렬됨
    let accelerationData: [AccelerationData]

    /// @var impactEvents
    /// @brief 충격 이벤트 배열
    ///
    /// **충격만 필터링:**
    /// - visibleImpactEvents에서 전달됨
    /// - .moderate 이상 충격만 포함
    /// - 배경 하이라이트 + 점선 마커로 표시
    let impactEvents: [AccelerationData]

    /// @var currentTime
    /// @brief 현재 재생 시간
    ///
    /// **용도:**
    /// - 현재 시간 인디케이터 위치 계산
    /// - X 좌표 변환의 기준점
    let currentTime: TimeInterval

    /// @var timeWindow
    /// @brief 시간 윈도우
    ///
    /// **용도:**
    /// - X 좌표 변환 시 사용
    /// - 시간 → 픽셀 비율 계산
    let timeWindow: TimeInterval

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                //
                // 배경 격자선 (가로/세로)
                gridLines(in: geometry)

                // Zero line
                //
                // 0G 기준선 (중앙 수평선)
                Path { path in
                    let y = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)

                // Impact event background highlights
                //
                // 충격 이벤트 배경 하이라이트
                impactHighlights(in: geometry)

                // X axis line (빨강)
                linePath(for: \.x, in: geometry, color: .red)

                // Y axis line (초록)
                linePath(for: \.y, in: geometry, color: .green)

                // Z axis line (파랑)
                linePath(for: \.z, in: geometry, color: .blue)

                // Impact markers
                //
                // 충격 이벤트 점선 마커
                impactMarkers(in: geometry)

                // Current time indicator
                //
                // 현재 시간 인디케이터 (노란색 점선)
                currentTimeIndicator(in: geometry)
            }
        }
        .frame(height: 120)
    }

    // MARK: - Grid Lines

    /// @brief 배경 그리드 선
    ///
    /// ## 가로 격자선
    /// ```swift
    /// ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
    ///     let y = yPosition(for: Double(value), in: geometry)
    ///     // 수평선 그리기
    /// }
    /// ```
    ///
    /// **그려지는 선:**
    /// - -2G 위치 (위쪽)
    /// - -1G 위치
    /// - 0G 위치 (중앙)
    /// - 1G 위치
    /// - 2G 위치 (아래쪽)
    ///
    /// ## 세로 격자선
    /// ```swift
    /// ForEach(0..<Int(timeWindow / 2), id: \.self) { index in
    ///     let x = CGFloat(index) * (geometry.size.width / CGFloat(timeWindow / 2))
    ///     // 수직선 그리기
    /// }
    /// ```
    ///
    /// **그려지는 선:**
    /// - timeWindow = 10초
    /// - 2초마다 선 그리기
    /// - 0초, 2초, 4초, 6초, 8초 위치
    ///
    /// **계산:**
    /// ```
    /// timeWindow = 10초
    /// timeWindow / 2 = 5초 간격으로 나눔
    /// geometry.size.width = 400px
    ///
    /// index = 0: x = 0 * (400 / 5) = 0px
    /// index = 1: x = 1 * (400 / 5) = 80px
    /// index = 2: x = 2 * (400 / 5) = 160px
    /// ...
    /// ```
    ///
    /// ## opacity(0.1)
    /// - 매우 투명한 흰색
    /// - 배경 역할 (눈에 거슬리지 않음)
    /// - 그래프 가독성 향상
    private func gridLines(in geometry: GeometryProxy) -> some View {
        let gridColor = Color.white.opacity(0.1)

        return ZStack {
            // Horizontal grid lines
            //
            // 가로 격자선 (-2G, -1G, 0G, 1G, 2G)
            ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
                let y = yPosition(for: Double(value), in: geometry)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(gridColor, lineWidth: 0.5)
            }

            // Vertical grid lines (every 2 seconds)
            //
            // 세로 격자선 (2초마다)
            ForEach(0..<Int(timeWindow / 2), id: \.self) { index in
                let x = CGFloat(index) * (geometry.size.width / CGFloat(timeWindow / 2))
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(gridColor, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Line Path

    /// @brief 라인 그래프 경로
    ///
    /// ## KeyPath로 동적 속성 접근
    /// ```swift
    /// func linePath(for keyPath: KeyPath<AccelerationData, Double>, ...)
    /// ```
    ///
    /// **KeyPath란?**
    /// - 타입의 속성을 참조하는 방법
    /// - `\.x`, `\.y`, `\.z`로 각 축 지정
    /// - data[keyPath: keyPath]로 값 접근
    ///
    /// **사용 예:**
    /// ```swift
    /// linePath(for: \.x, color: .red)    // X축 그래프
    /// linePath(for: \.y, color: .green)  // Y축 그래프
    /// linePath(for: \.z, color: .blue)   // Z축 그래프
    /// ```
    ///
    /// ## 그래프 그리기 과정
    /// ```swift
    /// for (index, data) in accelerationData.enumerated() {
    ///     let x = xPosition(for: dataTime, startTime: startTime, in: geometry)
    ///     let y = yPosition(for: data[keyPath: keyPath], in: geometry)
    ///
    ///     if index == 0 {
    ///         path.move(to: point)  // 첫 점: 이동만
    ///     } else {
    ///         path.addLine(to: point)  // 이후: 선 그리기
    ///     }
    /// }
    /// ```
    ///
    /// **왜 index == 0일 때 move를 사용하나?**
    /// - 첫 점은 시작점일 뿐
    /// - 이전 점이 없으므로 선을 그릴 수 없음
    /// - move로 펜을 위치시킨 후 addLine 시작
    ///
    /// ## 시간 계산
    /// ```swift
    /// let dataTime = data.timestamp.timeIntervalSince1970
    ///                - accelerationData.first!.timestamp.timeIntervalSince1970
    ///                + startTime
    /// ```
    ///
    /// **왜 이렇게 복잡하게 계산하나?**
    /// - data.timestamp: 절대 시간 (1970년 1월 1일 기준)
    /// - 상대 시간으로 변환 필요 (첫 데이터 기준)
    /// - startTime을 더해 윈도우 내 위치 계산
    ///
    /// **예시:**
    /// ```
    /// first.timestamp: 2024-01-15 14:23:20 (1705303400초)
    /// data.timestamp:  2024-01-15 14:23:25 (1705303405초)
    /// startTime: 20초
    ///
    /// 상대 시간 = 1705303405 - 1705303400 = 5초
    /// dataTime = 5 + 20 = 25초
    /// ```
    private func linePath(for keyPath: KeyPath<AccelerationData, Double>, in geometry: GeometryProxy, color: Color) -> some View {
        Path { path in
            guard !accelerationData.isEmpty else { return }

            let startTime = currentTime - timeWindow

            for (index, data) in accelerationData.enumerated() {
                let dataTime = data.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
                let x = xPosition(for: dataTime, startTime: startTime, in: geometry)
                let y = yPosition(for: data[keyPath: keyPath], in: geometry)

                let point = CGPoint(x: x, y: y)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: 2)
    }

    // MARK: - Current Time Indicator

    /// @brief 현재 시간 인디케이터
    ///
    /// ## 노란색 점선
    /// ```swift
    /// Path { path in
    ///     let x = geometry.size.width  // 오른쪽 끝
    ///     path.move(to: CGPoint(x: x, y: 0))
    ///     path.addLine(to: CGPoint(x: x, y: geometry.size.height))
    /// }
    /// .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    /// ```
    ///
    /// **왜 오른쪽 끝인가?**
    /// - 그래프는 과거 → 현재 방향 (왼쪽 → 오른쪽)
    /// - 현재 시간은 항상 오른쪽 끝
    /// - x = geometry.size.width (최대 X 좌표)
    ///
    /// ## StrokeStyle(dash:)
    /// ```swift
    /// dash: [5, 3]
    /// ```
    ///
    /// **점선 패턴:**
    /// - [5, 3]: 5px 선 → 3px 공백 → 반복
    /// - [10, 5]: 10px 선 → 5px 공백 → 반복
    ///
    /// **시각적 효과:**
    /// ```
    /// [5, 3]: ━━━━━   ━━━━━   ━━━━━
    /// ```
    private func currentTimeIndicator(in geometry: GeometryProxy) -> some View {
        Path { path in
            let x = geometry.size.width
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
        }
        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    }

    // MARK: - Impact Highlights

    /// @brief 충격 이벤트 배경 하이라이트
    ///
    /// ## ForEach로 각 충격 이벤트 처리
    /// ```swift
    /// ForEach(impactEvents, id: \.timestamp) { impact in
    ///     // 충격 위치에 반투명 배경 사각형
    /// }
    /// ```
    ///
    /// **id: \.timestamp:**
    /// - 각 충격을 timestamp로 구분
    /// - 같은 timestamp는 같은 이벤트
    ///
    /// ## Rectangle 배치
    /// ```swift
    /// Rectangle()
    ///     .fill(impactColor(for: impact).opacity(0.2))
    ///     .frame(width: 20)
    ///     .position(x: x, y: geometry.size.height / 2)
    /// ```
    ///
    /// **.fill(color.opacity(0.2)):**
    /// - 충격 강도에 따른 색상
    /// - 20% 불투명도 (배경 역할)
    ///
    /// **.frame(width: 20):**
    /// - 20px 너비의 수직 띠
    /// - 충격 지점 강조
    ///
    /// **.position(x:y:):**
    /// - x: 충격 시간의 X 좌표
    /// - y: 그래프 중앙 (height / 2)
    private func impactHighlights(in geometry: GeometryProxy) -> some View {
        ForEach(impactEvents, id: \.timestamp) { impact in
            let startTime = currentTime - timeWindow
            let impactTime = impact.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
            let x = xPosition(for: impactTime, startTime: startTime, in: geometry)

            Rectangle()
                .fill(impactColor(for: impact).opacity(0.2))
                .frame(width: 20)
                .position(x: x, y: geometry.size.height / 2)
        }
    }

    /// @brief 충격 이벤트 마커 (점선)
    ///
    /// ## ForEach로 각 충격 이벤트 처리
    /// ```swift
    /// ForEach(impactEvents, id: \.timestamp) { impact in
    ///     // 충격 위치에 점선 수직선
    /// }
    /// ```
    ///
    /// ## Path로 수직선 그리기
    /// ```swift
    /// Path { path in
    ///     path.move(to: CGPoint(x: x, y: 0))  // 위
    ///     path.addLine(to: CGPoint(x: x, y: geometry.size.height))  // 아래
    /// }
    /// .stroke(impactColor(for: impact), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
    /// ```
    ///
    /// **StrokeStyle(dash: [3, 2]):**
    /// - 3px 선 → 2px 공백 → 반복
    /// - 짧은 점선 (충격 지점 강조)
    ///
    /// **impactColor(for:):**
    /// - .severe: 빨간색
    /// - .high: 주황색
    /// - .moderate: 노란색
    private func impactMarkers(in geometry: GeometryProxy) -> some View {
        ForEach(impactEvents, id: \.timestamp) { impact in
            let startTime = currentTime - timeWindow
            let impactTime = impact.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
            let x = xPosition(for: impactTime, startTime: startTime, in: geometry)

            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(impactColor(for: impact), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
        }
    }

    /// @brief 충격 강도에 따른 색상
    ///
    /// ## ImpactSeverity별 색상
    /// ```
    /// .severe   → 빨간색 (10G 이상)
    /// .high     → 주황색 (8~10G)
    /// .moderate → 노란색 (6~8G)
    /// .low      → 청록색 (4~6G)
    /// .none     → 흰색 (4G 미만)
    /// ```
    ///
    /// **사용 위치:**
    /// - 충격 배경 하이라이트
    /// - 충격 마커 점선
    ///
    /// **일관성:**
    /// - 충격 강도별 색상은 전체 앱에서 동일
    /// - MetadataOverlayView, GraphOverlayView 모두 같은 체계
    private func impactColor(for impact: AccelerationData) -> Color {
        switch impact.impactSeverity {
        case .severe:
            return .red
        case .high:
            return .orange
        case .moderate:
            return .yellow
        case .low:
            return .cyan
        case .none:
            return .white
        }
    }

    // MARK: - Position Calculations

    /// @brief X 좌표 계산 (시간 → 픽셀)
    ///
    /// ## 변환 공식
    /// ```swift
    /// let relativeTime = time - startTime
    /// let ratio = relativeTime / timeWindow
    /// return CGFloat(ratio) * geometry.size.width
    /// ```
    ///
    /// **단계별 계산:**
    /// 1. **상대 시간 계산**: time - startTime
    ///    - 윈도우 시작점 기준 상대 위치
    /// 2. **비율 계산**: relativeTime / timeWindow
    ///    - 0.0 ~ 1.0 범위로 정규화
    /// 3. **픽셀 변환**: ratio * width
    ///    - 0 ~ width 범위의 픽셀 좌표
    ///
    /// **계산 예시:**
    /// ```
    /// timeWindow = 10초
    /// geometry.size.width = 400px
    /// startTime = 20초
    ///
    /// time = 25초
    /// relativeTime = 25 - 20 = 5초
    /// ratio = 5 / 10 = 0.5 (50% 위치)
    /// x = 0.5 * 400 = 200px (중앙)
    ///
    /// time = 20초 (시작)
    /// relativeTime = 20 - 20 = 0초
    /// ratio = 0 / 10 = 0.0
    /// x = 0.0 * 400 = 0px (왼쪽 끝)
    ///
    /// time = 30초 (끝)
    /// relativeTime = 30 - 20 = 10초
    /// ratio = 10 / 10 = 1.0
    /// x = 1.0 * 400 = 400px (오른쪽 끝)
    /// ```
    private func xPosition(for time: TimeInterval, startTime: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
        let relativeTime = time - startTime
        let ratio = relativeTime / timeWindow
        return CGFloat(ratio) * geometry.size.width
    }

    /// @brief Y 좌표 계산 (값 → 픽셀)
    ///
    /// ## 변환 공식
    /// ```swift
    /// let maxValue: Double = 3.0
    /// let ratio = (value + maxValue) / (maxValue * 2)
    /// return geometry.size.height * (1.0 - CGFloat(ratio))
    /// ```
    ///
    /// **단계별 계산:**
    /// 1. **범위 이동**: value + maxValue
    ///    - -3 ~ 3 → 0 ~ 6으로 이동
    /// 2. **비율 계산**: (value + maxValue) / (maxValue * 2)
    ///    - 0 ~ 6 → 0.0 ~ 1.0으로 정규화
    /// 3. **픽셀 변환**: height * (1 - ratio)
    ///    - Y축은 위가 0, 아래가 height
    ///    - 1 - ratio로 반전 (값이 클수록 위쪽)
    ///
    /// **계산 예시:**
    /// ```
    /// maxValue = 3.0
    /// geometry.size.height = 120px
    ///
    /// value = 3G (최대)
    /// ratio = (3 + 3) / 6 = 1.0
    /// y = 120 * (1 - 1.0) = 0px (맨 위)
    ///
    /// value = 0G (중앙)
    /// ratio = (0 + 3) / 6 = 0.5
    /// y = 120 * (1 - 0.5) = 60px (중앙)
    ///
    /// value = -3G (최소)
    /// ratio = (-3 + 3) / 6 = 0.0
    /// y = 120 * (1 - 0.0) = 120px (맨 아래)
    /// ```
    ///
    /// **왜 1 - ratio를 사용하나?**
    /// - SwiftUI의 Y축: 위쪽이 0, 아래쪽이 양수
    /// - 가속도 값: 위쪽이 양수, 아래쪽이 음수
    /// - 1 - ratio로 반전하여 직관적으로 표시
    ///
    /// ## ±3G 범위
    /// ```
    /// maxValue = 3.0
    /// ```
    ///
    /// **왜 3G인가?**
    /// - 일반 주행: ±1G 이내
    /// - 급가속/급제동: ±2G
    /// - 사고: ±3G 이상
    /// - ±3G 범위면 대부분 상황 커버
    private func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
        // Map value range [-3, 3] to geometry height
        let maxValue: Double = 3.0
        let ratio = (value + maxValue) / (maxValue * 2)
        return geometry.size.height * (1.0 - CGFloat(ratio))
    }
}

// MARK: - Preview

/// @brief Preview Provider
///
/// ## Mock 데이터 설정
/// ```swift
/// let gsensorService = GSensorService()
/// let videoFile = VideoFile.allSamples.first!
///
/// gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)
/// ```
///
/// **loadAccelerationData란?**
/// - VideoMetadata에서 가속도 데이터를 추출
/// - GSensorService에 로드하여 그래프 데이터 준비
/// - startTime: 비디오 시작 시간 (타임스탬프 계산용)
///
/// ## ZStack으로 검은 배경
/// ```swift
/// ZStack {
///     Color.black
///     GraphOverlayView(...)
/// }
/// ```
///
/// **왜 검은 배경을 사용하나?**
/// - 실제 비디오 화면을 시뮬레이션
/// - 그래프가 오버레이로 표시되는 효과 확인
/// - 그래프 선 색상 대비 테스트
///
/// ## currentTime: 10.0
/// - 비디오 시작 후 10초 지점
/// - 0~10초 범위의 그래프 표시
/// - 다양한 시간대 테스트하려면 값 변경
struct GraphOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let gsensorService = GSensorService()
        let videoFile = VideoFile.allSamples.first!

        // Load sample data
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        return ZStack {
            Color.black

            GraphOverlayView(
                gsensorService: gsensorService,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
