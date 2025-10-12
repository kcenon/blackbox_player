/// @file MapOverlayView.swift
/// @brief GPS 경로를 미니맵 오버레이로 표시하는 View
/// @author BlackboxPlayer Development Team
/// @details
/// GPS 경로를 미니맵 오버레이로 표시하는 View입니다. NSViewRepresentable로 MapKit의
/// MKMapView를 SwiftUI에 통합하여 과거/미래 경로 분할, 실시간 위치 추적, 충격 이벤트 마커 기능을 제공합니다.

import SwiftUI
import MapKit

/// # MapOverlayView
///
/// GPS 경로를 미니맵 오버레이로 표시하는 View입니다.
///
/// ## 화면 구조
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │                                                  │
/// │                                                  │
/// │                                     ┌─────────┐ │
/// │                                     │  📍  🔍  │ │
/// │                                     │         │ │
/// │                                     │  ═══●━━ │ │
/// │                                     │ /       │ │
/// │                                     │/        │ │
/// │                                     └─────────┘ │
/// │                                     ^^미니맵^^  │
/// └─────────────────────────────────────────────────┘
/// ```
///
/// ## 주요 기능
/// - **경로 표시**: 과거 경로(파란색 실선) + 미래 경로(회색 점선)
/// - **현재 위치**: 위치 마커와 속도 표시
/// - **충격 이벤트**: 사고 지점에 경고 마커
/// - **컨트롤 버튼**: 위치 중앙 정렬, 경로 전체 보기
///
/// ## SwiftUI 핵심 개념
///
/// ### 1. NSViewRepresentable로 AppKit 통합
/// ```swift
/// struct EnhancedMapView: NSViewRepresentable {
///     func makeNSView(context: Context) -> MKMapView { ... }
///     func updateNSView(_ mapView: MKMapView, context: Context) { ... }
///     func makeCoordinator() -> Coordinator { ... }
/// }
/// ```
///
/// **NSViewRepresentable이란?**
/// - AppKit(macOS)의 NSView를 SwiftUI에서 사용할 수 있게 해주는 프로토콜
/// - iOS에서는 UIViewRepresentable 사용 (동일한 패턴)
/// - MapKit의 MKMapView는 SwiftUI 네이티브가 아니므로 래핑 필요
///
/// **3가지 필수 메서드:**
/// 1. **makeNSView**: NSView 생성 및 초기 설정 (한 번만 호출)
/// 2. **updateNSView**: SwiftUI 상태 변경 시 NSView 업데이트 (여러 번 호출)
/// 3. **makeCoordinator**: Delegate 처리를 위한 Coordinator 생성 (선택적)
///
/// **왜 필요한가?**
/// - MKMapView는 AppKit 컴포넌트 (SwiftUI가 아님)
/// - SwiftUI에서 직접 사용 불가
/// - NSViewRepresentable로 래핑하면 SwiftUI처럼 사용 가능
///
/// ### 2. Coordinator 패턴으로 Delegate 처리
/// ```swift
/// class Coordinator: NSObject, MKMapViewDelegate {
///     func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer { ... }
///     func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? { ... }
/// }
/// ```
///
/// **Coordinator란?**
/// - NSViewRepresentable과 Delegate 메서드를 연결하는 중개자
/// - MKMapViewDelegate를 채택하여 맵 이벤트 처리
/// - SwiftUI와 AppKit 간 통신 다리 역할
///
/// **왜 필요한가?**
/// - MKMapView는 Delegate 패턴 사용 (SwiftUI는 사용 안 함)
/// - Delegate 메서드를 처리할 객체 필요
/// - Coordinator가 이 역할을 담당
///
/// ### 3. @Binding으로 양방향 바인딩
/// ```swift
/// struct EnhancedMapView: NSViewRepresentable {
///     @Binding var region: MKCoordinateRegion
/// }
/// ```
///
/// **@Binding이란?**
/// - 부모 View의 @State를 참조하여 양방향 바인딩
/// - 값을 읽고 쓸 수 있음
/// - 부모와 자식이 같은 값을 공유
///
/// **사용 방식:**
/// ```swift
/// // 부모 View
/// @State private var region = MKCoordinateRegion(...)
/// EnhancedMapView(region: $region)  // $ 사용
///
/// // 자식 View (EnhancedMapView)
/// @Binding var region: MKCoordinateRegion  // $ 없이 선언
/// ```
///
/// ### 4. Route Segmentation (경로 분할)
/// ```swift
/// let segments = gpsService.getRouteSegments(at: currentTime)
/// EnhancedMapView(
///     pastRoute: segments.past,      // 지나온 경로 (파란색)
///     futureRoute: segments.future   // 앞으로 갈 경로 (회색)
/// )
/// ```
///
/// **경로 분할이란?**
/// - 전체 GPS 경로를 currentTime 기준으로 2개로 분할
/// - 과거 경로: 0초 ~ currentTime (이미 이동한 경로)
/// - 미래 경로: currentTime ~ 끝 (아직 이동 안 한 경로)
///
/// **시각적 표현:**
/// ```
/// currentTime = 30초
///
/// 전체 경로: [0초] ─────── [30초] ─────── [60초]
///                  ^과거^      ^미래^
///
/// 지도 표시:
/// ════════════●━━━━━━━━━━━
/// ^파란색 실선^ ^회색 점선^
///            ^현재 위치
/// ```
///
/// ### 5. Polyline 렌더링
/// ```swift
/// func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
///     if let polyline = overlay as? MKPolyline {
///         let renderer = MKPolylineRenderer(polyline: polyline)
///         renderer.strokeColor = NSColor.systemBlue
///         renderer.lineWidth = 4.0
///         return renderer
///     }
/// }
/// ```
///
/// **Polyline이란?**
/// - 여러 좌표를 연결한 선
/// - GPS 경로를 지도에 그릴 때 사용
/// - MKPolyline(coordinates:count:)로 생성
///
/// **Renderer란?**
/// - Overlay를 화면에 그리는 역할
/// - 색상, 두께, 점선 패턴 등 스타일 지정
/// - MKPolylineRenderer(polyline:)로 생성
///
/// ### 6. Bounding Box 계산
/// ```swift
/// let minLat = coordinates.map { $0.latitude }.min() ?? 0
/// let maxLat = coordinates.map { $0.latitude }.max() ?? 0
/// let minLon = coordinates.map { $0.longitude }.min() ?? 0
/// let maxLon = coordinates.map { $0.longitude }.max() ?? 0
///
/// let center = CLLocationCoordinate2D(
///     latitude: (minLat + maxLat) / 2,
///     longitude: (minLon + maxLon) / 2
/// )
/// ```
///
/// **Bounding Box란?**
/// - 모든 GPS 좌표를 포함하는 최소 사각형
/// - 경로 전체를 화면에 맞추기 위해 사용
///
/// **계산 과정:**
/// ```
/// GPS 좌표들:
/// (37.5665, 126.9780)
/// (37.5670, 126.9785)
/// (37.5660, 126.9775)
///
/// Bounding Box:
/// minLat = 37.5660
/// maxLat = 37.5670
/// minLon = 126.9775
/// maxLon = 126.9785
///
/// center = ((37.5660 + 37.5670) / 2, (126.9775 + 126.9785) / 2)
///        = (37.5665, 126.9780)
/// ```
///
/// ## 사용 예제
///
/// ### 예제 1: VideoPlayerView에서 사용
/// ```swift
/// struct VideoPlayerView: View {
///     @StateObject private var gpsService = GPSService()
///     @StateObject private var gsensorService = GSensorService()
///     @State private var currentTime: TimeInterval = 0.0
///
///     var body: some View {
///         ZStack {
///             // 비디오 화면
///             VideoFrameView(frame: currentFrame)
///
///             // 미니맵 오버레이
///             MapOverlayView(
///                 gpsService: gpsService,
///                 gsensorService: gsensorService,
///                 currentTime: currentTime
///             )
///         }
///     }
/// }
/// ```
///
/// ### 예제 2: 토글 가능한 미니맵
/// ```swift
/// @State private var showMiniMap = true
///
/// ZStack {
///     VideoFrameView(frame: currentFrame)
///
///     if showMiniMap {
///         MapOverlayView(
///             gpsService: gpsService,
///             gsensorService: gsensorService,
///             currentTime: currentTime
///         )
///         .transition(.move(edge: .trailing))
///     }
/// }
/// .toolbar {
///     Button("Toggle Map") {
///         withAnimation {
///             showMiniMap.toggle()
///         }
///     }
/// }
/// ```
///
/// ## 실무 응용
///
/// ### 크기 조절 가능한 미니맵
/// ```swift
/// @State private var mapSize: CGSize = CGSize(width: 250, height: 200)
///
/// MapOverlayView(...)
///     .frame(width: mapSize.width, height: mapSize.height)
///     .gesture(
///         DragGesture()
///             .onChanged { value in
///                 mapSize.width = max(200, min(400, mapSize.width + value.translation.width))
///                 mapSize.height = max(150, min(300, mapSize.height + value.translation.height))
///             }
///     )
/// ```
///
/// ### 맵 타입 변경 (일반/위성/하이브리드)
/// ```swift
/// @State private var mapType: MKMapType = .standard
///
/// func makeNSView(context: Context) -> MKMapView {
///     let mapView = MKMapView()
///     mapView.mapType = mapType  // .standard, .satellite, .hybrid
///     return mapView
/// }
/// ```
///
/// ### 속도 표시 애니메이션
/// ```swift
/// Text(String(format: "%.0f km/h", currentSpeed))
///     .font(.system(size: 14, weight: .bold, design: .rounded))
///     .foregroundColor(speedColor(currentSpeed))
///     .animation(.easeInOut(duration: 0.3), value: currentSpeed)
/// ```
///
/// ## 성능 최적화
///
/// ### 1. Polyline 업데이트 최소화
/// ```swift
/// // 현재: 매번 전체 경로 재생성 (비효율적)
/// mapView.removeOverlays(mapView.overlays)
/// mapView.addOverlay(polyline)
///
/// // 개선: 변경된 부분만 업데이트
/// if lastUpdateTime != currentTime {
///     updatePolyline(from: lastUpdateTime, to: currentTime)
///     lastUpdateTime = currentTime
/// }
/// ```
///
/// ### 2. Annotation 재사용
/// ```swift
/// var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
/// // ✅ 재사용: 메모리 효율적
/// ```
///
/// ### 3. Region 변경 애니메이션 제한
/// ```swift
/// // onChange에서 너무 자주 호출 방지
/// .onChange(of: currentTime) { newTime in
///     // 1초마다만 업데이트
///     if Int(newTime) != Int(oldTime) {
///         centerOnCurrentLocation()
///     }
/// }
/// ```
///
/// @struct MapOverlayView
/// @brief GPS 경로를 미니맵 오버레이로 표시하는 View
struct MapOverlayView: View {
    // MARK: - Properties

    /// @var gpsService
    /// @brief GPS 서비스 (@ObservedObject)
    ///
    /// **GPSService란?**
    /// - GPS 데이터를 관리하는 서비스 클래스
    /// - 경로 포인트, 현재 위치, 경로 분할 기능 제공
    /// - @Published 속성 변경 시 View 자동 업데이트
    ///
    /// **주요 기능:**
    /// - `routePoints`: 전체 GPS 경로 포인트 배열
    /// - `currentLocation`: 현재 시간의 GPS 포인트
    /// - `getRouteSegments(at:)`: 경로를 과거/미래로 분할
    /// - `hasData`: GPS 데이터 존재 여부
    @ObservedObject var gpsService: GPSService

    /// @var gsensorService
    /// @brief G-Sensor 서비스 (@ObservedObject)
    ///
    /// **GSensorService란?**
    /// - 가속도 센서 데이터를 관리하는 서비스 클래스
    /// - 충격 이벤트 감지 및 관리
    /// - @Published 속성 변경 시 View 자동 업데이트
    ///
    /// **주요 기능:**
    /// - `impactEvents`: 충격 이벤트 배열 (4G 이상)
    /// - `accelerationData`: 전체 가속도 데이터
    @ObservedObject var gsensorService: GSensorService

    /// @var currentTime
    /// @brief 현재 재생 시간
    ///
    /// **용도:**
    /// - GPS 경로를 과거/미래로 분할하는 기준점
    /// - 현재 위치 계산에 사용
    /// - onChange로 변경 감지하여 맵 업데이트
    let currentTime: TimeInterval

    /// @var region
    /// @brief 맵 영역 (@State)
    ///
    /// **MKCoordinateRegion이란?**
    /// - 지도에 표시할 영역을 정의
    /// - center: 중심 좌표 (위도, 경도)
    /// - span: 보이는 범위 (latitudeDelta, longitudeDelta)
    ///
    /// **span 값의 의미:**
    /// ```
    /// latitudeDelta: 0.01  → 약 1.1km 높이
    /// longitudeDelta: 0.01 → 약 1.1km 너비 (위도에 따라 다름)
    ///
    /// latitudeDelta: 0.1   → 약 11km 높이
    /// latitudeDelta: 1.0   → 약 111km 높이
    /// ```
    ///
    /// **초기값 (서울시청):**
    /// - center: (37.5665, 126.9780)
    /// - span: (0.01, 0.01) → 약 1.1km × 1.1km 영역
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                // GPS 데이터가 있을 때만 미니맵 표시
                //
                // gpsService.hasData: GPS 포인트가 1개 이상 있는지 확인
                if gpsService.hasData {
                    miniMap
                        .frame(width: 250, height: 200)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding()
                }
            }
        }
    }

    // MARK: - Mini Map

    /// @brief 미니맵
    ///
    /// ## 구조
    /// ```
    /// ┌──────────────┐
    /// │  📍  🔍      │  ← 컨트롤 버튼 (topTrailing)
    /// │              │
    /// │  ═══●━━━━━  │  ← 경로 (파란색 실선 + 회색 점선)
    /// │ /            │
    /// │/             │
    /// └──────────────┘
    /// ```
    ///
    /// ## 레이어 구조 (ZStack)
    /// 1. **EnhancedMapView**: MKMapView 래핑 (지도, 경로, 마커)
    /// 2. **컨트롤 버튼**: 위치 중앙, 경로 전체 보기 (topTrailing)
    ///
    /// ## Route Segments
    /// ```swift
    /// let segments = gpsService.getRouteSegments(at: currentTime)
    /// ```
    ///
    /// **getRouteSegments란?**
    /// - currentTime 기준으로 경로를 2개로 분할
    /// - segments.past: 0초 ~ currentTime (이동한 경로)
    /// - segments.future: currentTime ~ 끝 (아직 이동 안 한 경로)
    ///
    /// **예시:**
    /// ```
    /// currentTime = 30초
    /// 전체 경로: 60초 분량
    ///
    /// segments.past = [0초 ~ 30초 GPS 포인트들]
    /// segments.future = [30초 ~ 60초 GPS 포인트들]
    /// ```
    ///
    /// ## onChange(of: currentTime)
    /// ```swift
    /// .onChange(of: currentTime) { _ in
    ///     if let point = gpsService.currentLocation {
    ///         centerOnCoordinate(point.coordinate)
    ///     }
    /// }
    /// ```
    ///
    /// **onChange란?**
    /// - 특정 값이 변경될 때마다 클로저 실행
    /// - currentTime이 바뀔 때마다 맵 중심 이동
    /// - 실시간으로 현재 위치 추적
    ///
    /// **작동 방식:**
    /// ```
    /// currentTime: 0 → 5 → 10 → 15 → ...
    ///                  ↓   ↓    ↓
    ///              centerOnCoordinate 호출
    /// ```
    private var miniMap: some View {
        ZStack(alignment: .topTrailing) {
            // Enhanced map view with route segmentation
            //
            // 경로를 과거/미래로 분할하여 표시
            let segments = gpsService.getRouteSegments(at: currentTime)
            EnhancedMapView(
                region: $region,
                pastRoute: segments.past,
                futureRoute: segments.future,
                currentPoint: gpsService.currentLocation,
                impactEvents: gsensorService.impactEvents
            )

            // 맵 컨트롤 버튼
            //
            // topTrailing 정렬: 오른쪽 위에 배치
            VStack(spacing: 8) {
                /// @brief 현재 위치 중앙 정렬 버튼
                ///
                /// **동작:**
                /// - 현재 위치를 맵 중앙으로 이동
                /// - withAnimation으로 부드럽게 애니메이션
                Button(action: centerOnCurrentLocation) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                }

                /// @brief 경로 전체 보기 버튼
                ///
                /// **동작:**
                /// - 모든 경로가 보이도록 맵 영역 조정
                /// - Bounding Box 계산하여 최적 영역 설정
                Button(action: fitRouteToView) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                }
            }
            .padding(8)
        }
        .onAppear {
            /// @brief View가 나타날 때 맵 영역 초기화
            ///
            /// **동작:**
            /// - 현재 위치 또는 첫 GPS 포인트로 맵 중심 설정
            /// - 최초 1회만 호출됨
            updateMapRegion()
        }
        .onChange(of: currentTime) { _ in
            /// @brief currentTime 변경 시 맵 중심 이동
            ///
            /// **동작:**
            /// - 현재 위치로 맵 중심 이동
            /// - 실시간으로 위치 추적
            if let point = gpsService.currentLocation {
                centerOnCoordinate(point.coordinate)
            }
        }
    }

    // MARK: - Helper Methods

    /// @brief 맵 영역 초기화
    ///
    /// ## 동작 순서
    /// 1. 현재 위치가 있으면 → 현재 위치 중심으로 설정
    /// 2. 현재 위치 없으면 → 첫 GPS 포인트 중심으로 설정
    /// 3. GPS 데이터 없으면 → 기본값 유지 (서울시청)
    ///
    /// ## 사용 시점
    /// - onAppear: View가 처음 나타날 때
    /// - 맵 초기화 시
    ///
    /// ## 코드 흐름
    /// ```swift
    /// if let point = gpsService.currentLocation {
    ///     // 현재 위치로 설정
    /// } else if let firstPoint = gpsService.routePoints.first {
    ///     // 첫 포인트로 설정
    /// }
    /// // 둘 다 없으면 기본값 유지
    /// ```
    private func updateMapRegion() {
        if let point = gpsService.currentLocation {
            region = MKCoordinateRegion(
                center: point.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else if let firstPoint = gpsService.routePoints.first {
            region = MKCoordinateRegion(
                center: firstPoint.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    /// @brief 현재 위치를 맵 중앙으로 이동
    ///
    /// ## withAnimation
    /// ```swift
    /// withAnimation {
    ///     centerOnCoordinate(point.coordinate)
    /// }
    /// ```
    ///
    /// **withAnimation이란?**
    /// - 블록 내부의 상태 변경을 애니메이션으로 표현
    /// - region 변경이 부드럽게 애니메이션됨
    /// - 기본 duration: 0.35초
    ///
    /// **애니메이션 효과:**
    /// - 맵이 부드럽게 이동 (갑자기 점프하지 않음)
    /// - 사용자 경험 향상
    ///
    /// ## 사용 시점
    /// - 사용자가 📍 버튼 클릭 시
    /// - 현재 위치로 빠르게 이동하고 싶을 때
    private func centerOnCurrentLocation() {
        if let point = gpsService.currentLocation {
            withAnimation {
                centerOnCoordinate(point.coordinate)
            }
        }
    }

    /// @brief 특정 좌표를 맵 중앙으로 이동
    ///
    /// ## 동작
    /// ```swift
    /// region = MKCoordinateRegion(
    ///     center: coordinate,  // 새 중심 좌표
    ///     span: region.span    // 기존 확대 레벨 유지
    /// )
    /// ```
    ///
    /// **span을 유지하는 이유:**
    /// - 확대 레벨을 그대로 유지
    /// - 중심만 이동, 줌 레벨은 변경 안 함
    ///
    /// **예시:**
    /// ```
    /// 현재 region:
    ///   center: (37.5665, 126.9780)
    ///   span: (0.01, 0.01)
    ///
    /// centerOnCoordinate((37.5670, 126.9785)) 호출 후:
    ///   center: (37.5670, 126.9785)  ← 변경됨
    ///   span: (0.01, 0.01)           ← 유지됨
    /// ```
    private func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: region.span
        )
    }

    /// @brief 전체 경로를 맵에 맞춤
    ///
    /// ## Bounding Box 계산
    /// ```swift
    /// let minLat = coordinates.map { $0.latitude }.min() ?? 0
    /// let maxLat = coordinates.map { $0.latitude }.max() ?? 0
    /// ```
    ///
    /// **Bounding Box란?**
    /// - 모든 GPS 좌표를 포함하는 최소 사각형
    /// - min/max 위도/경도로 정의됨
    ///
    /// **계산 예시:**
    /// ```
    /// GPS 좌표들:
    /// (37.5665, 126.9780)
    /// (37.5670, 126.9785)
    /// (37.5660, 126.9775)
    ///
    /// minLat = 37.5660  (가장 남쪽)
    /// maxLat = 37.5670  (가장 북쪽)
    /// minLon = 126.9775 (가장 서쪽)
    /// maxLon = 126.9785 (가장 동쪽)
    /// ```
    ///
    /// ## 중심 좌표 계산
    /// ```swift
    /// let center = CLLocationCoordinate2D(
    ///     latitude: (minLat + maxLat) / 2,
    ///     longitude: (minLon + maxLon) / 2
    /// )
    /// ```
    ///
    /// **왜 평균을 사용하나?**
    /// - Bounding Box의 정확한 중심
    /// - 경로가 고르게 보임
    ///
    /// **계산:**
    /// ```
    /// center.latitude = (37.5660 + 37.5670) / 2 = 37.5665
    /// center.longitude = (126.9775 + 126.9785) / 2 = 126.9780
    /// ```
    ///
    /// ## Span 계산
    /// ```swift
    /// let span = MKCoordinateSpan(
    ///     latitudeDelta: (maxLat - minLat) * 1.2,
    ///     longitudeDelta: (maxLon - minLon) * 1.2
    /// )
    /// ```
    ///
    /// **왜 1.2를 곱하나?**
    /// - 20% 여유 공간 추가
    /// - 경로가 화면 끝에 딱 붙지 않음
    /// - 시각적으로 더 편안함
    ///
    /// **예시:**
    /// ```
    /// latitudeDelta = (37.5670 - 37.5660) * 1.2 = 0.001 * 1.2 = 0.0012
    /// longitudeDelta = (126.9785 - 126.9775) * 1.2 = 0.001 * 1.2 = 0.0012
    /// ```
    ///
    /// ## 사용 시점
    /// - 사용자가 🔍 버튼 클릭 시
    /// - 전체 경로를 한눈에 보고 싶을 때
    private func fitRouteToView() {
        let coordinates = gpsService.routePoints.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }

        // Bounding Box 계산
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.min() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        withAnimation {
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

// MARK: - Enhanced MapKit View Wrapper

/// # EnhancedMapView
///
/// NSViewRepresentable로 MKMapView를 SwiftUI에 통합한 래퍼입니다.
///
/// ## NSViewRepresentable이란?
///
/// **정의:**
/// - AppKit(macOS)의 NSView를 SwiftUI에서 사용할 수 있게 해주는 프로토콜
/// - iOS에서는 UIViewRepresentable 사용 (동일한 패턴)
///
/// **왜 필요한가?**
/// - MKMapView는 AppKit 컴포넌트 (SwiftUI 네이티브가 아님)
/// - SwiftUI에서 직접 사용 불가
/// - NSViewRepresentable로 래핑하면 SwiftUI처럼 사용 가능
///
/// ## 3가지 필수 메서드
///
/// ### 1. makeNSView(context:)
/// ```swift
/// func makeNSView(context: Context) -> MKMapView {
///     let mapView = MKMapView()
///     mapView.delegate = context.coordinator
///     return mapView
/// }
/// ```
///
/// **언제 호출되나?**
/// - View가 처음 생성될 때 한 번만 호출됨
/// - NSView 인스턴스를 만들고 초기 설정
///
/// **주요 작업:**
/// - NSView 생성
/// - Delegate 설정
/// - 초기 스타일 적용
///
/// ### 2. updateNSView(_:context:)
/// ```swift
/// func updateNSView(_ mapView: MKMapView, context: Context) {
///     mapView.setRegion(region, animated: true)
///     // Overlay, Annotation 업데이트
/// }
/// ```
///
/// **언제 호출되나?**
/// - @Binding, @State 등이 변경될 때마다 호출됨
/// - currentTime, region 등이 바뀔 때마다 실행
///
/// **주요 작업:**
/// - NSView 상태 업데이트
/// - Overlay 재설정
/// - Annotation 재설정
///
/// ### 3. makeCoordinator()
/// ```swift
/// func makeCoordinator() -> Coordinator {
///     Coordinator(self)
/// }
/// ```
///
/// **언제 호출되나?**
/// - makeNSView 전에 한 번만 호출됨
/// - Coordinator 인스턴스 생성
///
/// **주요 작업:**
/// - Delegate 객체 생성
/// - Parent View 참조 전달
///
/// ## Coordinator 패턴
///
/// **Coordinator란?**
/// - NSViewRepresentable과 Delegate 메서드를 연결하는 중개자
/// - MKMapViewDelegate를 채택하여 맵 이벤트 처리
/// - SwiftUI와 AppKit 간 통신 다리 역할
///
/// **왜 필요한가?**
/// - MKMapView는 Delegate 패턴 사용 (SwiftUI는 사용 안 함)
/// - Delegate 메서드를 처리할 객체 필요
/// - Coordinator가 이 역할을 담당
///
/// **호출 흐름:**
/// ```
/// SwiftUI → NSViewRepresentable → Coordinator → MKMapViewDelegate
///                                      ↓
///                                  mapView 이벤트
/// ```
///
/// @struct EnhancedMapView
/// @brief NSViewRepresentable로 MKMapView를 SwiftUI에 통합한 래퍼
struct EnhancedMapView: NSViewRepresentable {
    // MARK: - Properties

    /// @var region
    /// @brief 맵 영역 (@Binding)
    ///
    /// **@Binding이란?**
    /// - 부모 View의 @State를 참조하여 양방향 바인딩
    /// - 값을 읽고 쓸 수 있음
    /// - 부모와 자식이 같은 값을 공유
    ///
    /// **사용 방식:**
    /// ```swift
    /// // 부모 View (MapOverlayView)
    /// @State private var region = MKCoordinateRegion(...)
    /// EnhancedMapView(region: $region)  // $ 사용
    ///
    /// // 자식 View (EnhancedMapView)
    /// @Binding var region: MKCoordinateRegion  // $ 없이 선언
    /// ```
    @Binding var region: MKCoordinateRegion

    /// @var pastRoute
    /// @brief 과거 경로 (이동한 경로)
    ///
    /// **표시 스타일:**
    /// - 색상: 파란색 (NSColor.systemBlue)
    /// - 두께: 4.0
    /// - 패턴: 실선
    let pastRoute: [GPSPoint]

    /// @var futureRoute
    /// @brief 미래 경로 (아직 이동 안 한 경로)
    ///
    /// **표시 스타일:**
    /// - 색상: 회색 (NSColor.systemGray)
    /// - 두께: 3.0
    /// - 패턴: 점선 [2, 4] (2px 선, 4px 공백)
    let futureRoute: [GPSPoint]

    /// @var currentPoint
    /// @brief 현재 위치
    ///
    /// **표시 스타일:**
    /// - 아이콘: "location.circle.fill" (📍)
    /// - 크기: 24pt
    /// - 캘아웃: 속도 정보 표시
    let currentPoint: GPSPoint?

    /// @var impactEvents
    /// @brief 충격 이벤트 (4G 이상)
    ///
    /// **표시 스타일:**
    /// - 아이콘: "exclamationmark.triangle.fill" (⚠️)
    /// - 크기: 18pt
    /// - 캘아웃: 충격 강도 표시
    let impactEvents: [AccelerationData]

    // MARK: - NSViewRepresentable Methods

    /// @brief NSView 생성 및 초기 설정
    ///
    /// ## 호출 시점
    /// - View가 처음 생성될 때 한 번만 호출됨
    /// - SwiftUI 생명주기에서 최초 1회 실행
    ///
    /// ## 초기 설정
    /// ```swift
    /// mapView.delegate = context.coordinator
    /// mapView.mapType = .standard
    /// mapView.showsCompass = true
    /// mapView.showsScale = true
    /// ```
    ///
    /// **context.coordinator란?**
    /// - makeCoordinator()에서 생성된 Coordinator 인스턴스
    /// - MKMapViewDelegate 역할 수행
    /// - mapView의 이벤트를 처리
    ///
    /// **mapType 옵션:**
    /// - `.standard`: 일반 지도 (기본값)
    /// - `.satellite`: 위성 사진
    /// - `.hybrid`: 위성 + 도로명
    ///
    /// **showsCompass:**
    /// - true: 나침반 표시 (오른쪽 위)
    /// - false: 나침반 숨김
    ///
    /// **showsScale:**
    /// - true: 축척 표시 (왼쪽 위)
    /// - false: 축척 숨김
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true

        return mapView
    }

    /// @brief NSView 업데이트
    ///
    /// ## 호출 시점
    /// - @Binding, @State 등이 변경될 때마다 호출됨
    /// - region, pastRoute, futureRoute 등이 바뀔 때마다 실행
    ///
    /// ## 업데이트 순서
    /// 1. region 설정 (맵 영역 이동)
    /// 2. 기존 Overlay, Annotation 제거
    /// 3. 새로운 Overlay 추가 (과거/미래 경로)
    /// 4. 새로운 Annotation 추가 (현재 위치, 충격 이벤트)
    ///
    /// ## Overlay vs Annotation
    ///
    /// **Overlay (오버레이):**
    /// - 지도 위에 그려지는 도형 (선, 다각형 등)
    /// - 예: Polyline (경로), Circle (영역), Polygon (구역)
    /// - rendererFor overlay: Delegate 메서드로 렌더링
    ///
    /// **Annotation (주석):**
    /// - 지도 위의 마커/핀
    /// - 예: 현재 위치, 충격 지점, 관심 장소
    /// - viewFor annotation: Delegate 메서드로 렌더링
    ///
    /// ## 왜 매번 제거하고 다시 추가하나?
    /// ```swift
    /// mapView.removeOverlays(mapView.overlays)
    /// mapView.removeAnnotations(mapView.annotations)
    /// ```
    ///
    /// **이유:**
    /// - 이전 상태를 완전히 초기화
    /// - 중복 표시 방지
    /// - 단순하고 명확한 업데이트
    ///
    /// **단점:**
    /// - 매번 재생성으로 성능 저하 가능
    /// - 많은 데이터일 때 최적화 필요
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Update region
        //
        // animated: true로 부드럽게 이동
        mapView.setRegion(region, animated: true)

        // Remove existing overlays and annotations
        //
        // 기존 Overlay, Annotation 모두 제거
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Add past route polyline (traveled path - blue)
        //
        // 과거 경로: 파란색 실선
        if !pastRoute.isEmpty {
            let coordinates = pastRoute.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "past"  // Renderer에서 구분하기 위한 식별자
            mapView.addOverlay(polyline)
        }

        // Add future route polyline (not yet traveled - gray)
        //
        // 미래 경로: 회색 점선
        if !futureRoute.isEmpty {
            let coordinates = futureRoute.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "future"  // Renderer에서 구분하기 위한 식별자
            mapView.addOverlay(polyline)
        }

        // Add impact event markers
        //
        // 충격 이벤트: ⚠️ 마커
        for impact in impactEvents {
            // Find GPS point closest to impact timestamp
            // For now, we'll use a simple approach - in production, we'd query GPSService
            let annotation = MKPointAnnotation()
            // Note: We need to convert impact timestamp to coordinate
            // This would require GPSService integration - placeholder for now
            annotation.title = "Impact"
            annotation.subtitle = impact.impactSeverity.displayName
            // mapView.addAnnotation(annotation)  // Commented out until we have proper coordinate mapping
        }

        // Add current location annotation
        //
        // 현재 위치: 📍 마커
        if let currentPoint = currentPoint {
            let annotation = MKPointAnnotation()
            annotation.coordinate = currentPoint.coordinate
            annotation.title = "Current Position"
            if let speed = currentPoint.speed {
                annotation.subtitle = String(format: "%.1f km/h", speed)
            }
            mapView.addAnnotation(annotation)
        }
    }

    /// @brief Coordinator 생성
    ///
    /// ## 호출 시점
    /// - makeNSView 전에 한 번만 호출됨
    /// - View 생명주기에서 최초 1회 실행
    ///
    /// ## Coordinator(self)
    /// ```swift
    /// Coordinator(self)
    /// ```
    ///
    /// **self란?**
    /// - EnhancedMapView 인스턴스
    /// - parent로 저장되어 Coordinator에서 접근 가능
    ///
    /// **왜 parent가 필요한가?**
    /// - Coordinator에서 EnhancedMapView의 속성에 접근
    /// - 예: parent.pastRoute, parent.futureRoute
    /// - Delegate 메서드에서 SwiftUI 상태 읽기
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    /// @class Coordinator
    /// @brief Coordinator 클래스
    ///
    /// ## 역할
    /// - MKMapViewDelegate 구현
    /// - Overlay 렌더링 (경로 선)
    /// - Annotation 렌더링 (마커)
    /// - SwiftUI와 AppKit 간 중개자
    ///
    /// ## 구조
    /// ```
    /// EnhancedMapView (SwiftUI)
    ///        ↓
    ///   Coordinator (중개자)
    ///        ↓
    /// MKMapViewDelegate (AppKit)
    /// ```
    ///
    /// ## parent 속성
    /// ```swift
    /// var parent: EnhancedMapView
    /// ```
    ///
    /// **용도:**
    /// - EnhancedMapView의 속성에 접근
    /// - SwiftUI 상태와 연동
    ///
    /// **예시:**
    /// ```swift
    /// // Coordinator에서 사용
    /// if parent.pastRoute.isEmpty { ... }
    /// ```
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: EnhancedMapView

        init(_ parent: EnhancedMapView) {
            self.parent = parent
        }

        /// @brief Overlay 렌더링
        ///
        /// ## 호출 시점
        /// - mapView.addOverlay()가 호출될 때마다 실행
        /// - Overlay를 화면에 그릴 Renderer 반환
        ///
        /// ## Polyline 렌더링
        /// ```swift
        /// if let polyline = overlay as? MKPolyline {
        ///     let renderer = MKPolylineRenderer(polyline: polyline)
        ///     renderer.strokeColor = NSColor.systemBlue
        ///     renderer.lineWidth = 4.0
        ///     return renderer
        /// }
        /// ```
        ///
        /// **MKPolylineRenderer란?**
        /// - Polyline을 화면에 그리는 객체
        /// - 색상, 두께, 패턴 등 스타일 지정
        ///
        /// ## polyline.title로 구분
        /// ```swift
        /// if polyline.title == "past" {
        ///     // 과거 경로: 파란색 실선
        /// } else if polyline.title == "future" {
        ///     // 미래 경로: 회색 점선
        /// }
        /// ```
        ///
        /// **title 속성:**
        /// - Polyline을 식별하기 위한 문자열
        /// - updateNSView에서 설정
        /// - Renderer에서 스타일 분기에 사용
        ///
        /// ## lineDashPattern
        /// ```swift
        /// renderer.lineDashPattern = [2, 4]
        /// ```
        ///
        /// **점선 패턴:**
        /// - [2, 4]: 2px 선 → 4px 공백 → 반복
        /// - [5, 5]: 5px 선 → 5px 공백 → 반복
        /// - [10, 5, 2, 5]: 복잡한 패턴 가능
        ///
        /// **시각적 효과:**
        /// ```
        /// [2, 4]: ══ ══ ══ ══
        /// [5, 5]: ═════ ═════ ═════
        /// ```
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // Different colors for past and future routes
                if polyline.title == "past" {
                    renderer.strokeColor = NSColor.systemBlue
                    renderer.lineWidth = 4.0
                } else if polyline.title == "future" {
                    renderer.strokeColor = NSColor.systemGray
                    renderer.lineWidth = 3.0
                    renderer.lineDashPattern = [2, 4]  // Dashed line for future route
                } else {
                    renderer.strokeColor = NSColor.systemBlue
                    renderer.lineWidth = 3.0
                }

                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// @brief Annotation 렌더링
        ///
        /// ## 호출 시점
        /// - mapView.addAnnotation()이 호출될 때마다 실행
        /// - Annotation을 화면에 그릴 View 반환
        ///
        /// ## dequeueReusableAnnotationView
        /// ```swift
        /// var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        /// ```
        ///
        /// **dequeue란?**
        /// - 재사용 가능한 AnnotationView를 큐에서 가져옴
        /// - UITableView의 dequeueReusableCell과 동일한 패턴
        /// - 메모리 효율적 (매번 새로 생성 안 함)
        ///
        /// **작동 방식:**
        /// ```
        /// 1. 화면 밖으로 나간 AnnotationView → 큐에 추가
        /// 2. 새 Annotation 필요 → 큐에서 꺼내서 재사용
        /// 3. 큐가 비었으면 → 새로 생성
        /// ```
        ///
        /// ## Annotation 타입별 처리
        ///
        /// ### Impact Marker (충격 마커)
        /// ```swift
        /// if annotation.title == "Impact" {
        ///     let image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", ...)
        ///     annotationView?.image = image?.withSymbolConfiguration(config)
        /// }
        /// ```
        ///
        /// **SF Symbols 설정:**
        /// - systemSymbolName: SF Symbols 이름
        /// - NSImage.SymbolConfiguration: 크기, 두께 설정
        /// - withSymbolConfiguration: 설정 적용
        ///
        /// ### Current Position (현재 위치)
        /// ```swift
        /// else {
        ///     let image = NSImage(systemSymbolName: "location.circle.fill", ...)
        ///     annotationView?.image = image?.withSymbolConfiguration(config)
        /// }
        /// ```
        ///
        /// ## canShowCallout
        /// ```swift
        /// annotationView?.canShowCallout = true
        /// ```
        ///
        /// **Callout이란?**
        /// - 마커 클릭 시 나타나는 말풍선
        /// - title, subtitle 표시
        /// - 추가 정보 제공
        ///
        /// **예시:**
        /// ```
        /// 📍
        /// ┌─────────────────┐
        /// │ Current Position│  ← title
        /// │ 85.0 km/h       │  ← subtitle
        /// └─────────────────┘
        /// ```
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation.title == "Impact" {
                // Impact marker
                //
                // 충격 이벤트: ⚠️
                let identifier = "ImpactMarker"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                let image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
                let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
                annotationView?.image = image?.withSymbolConfiguration(config)

                return annotationView
            } else {
                // Current position marker
                //
                // 현재 위치: 📍
                let identifier = "CurrentPosition"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                let image = NSImage(systemSymbolName: "location.circle.fill", accessibilityDescription: nil)
                let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .bold)
                annotationView?.image = image?.withSymbolConfiguration(config)

                return annotationView
            }
        }
    }
}

// MARK: - Preview

/// @brief Preview Provider
///
/// ## Mock 데이터 설정
/// ```swift
/// let gpsService = GPSService()
/// let gsensorService = GSensorService()
/// let videoFile = VideoFile.allSamples.first!
///
/// gpsService.loadGPSData(from: videoFile.metadata, startTime: videoFile.timestamp)
/// gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)
/// ```
///
/// **loadGPSData란?**
/// - VideoMetadata에서 GPS 데이터를 추출
/// - GPSService에 로드하여 경로 생성
/// - startTime: 비디오 시작 시간 (타임스탬프 계산용)
///
/// **loadAccelerationData란?**
/// - VideoMetadata에서 가속도 데이터를 추출
/// - GSensorService에 로드하여 충격 이벤트 감지
/// - startTime: 비디오 시작 시간 (타임스탬프 계산용)
///
/// ## ZStack으로 검은 배경
/// ```swift
/// ZStack {
///     Color.black
///     MapOverlayView(...)
/// }
/// ```
///
/// **왜 검은 배경을 사용하나?**
/// - 실제 비디오 화면을 시뮬레이션
/// - 미니맵이 오버레이로 표시되는 효과 확인
/// - 그림자 효과 테스트
struct MapOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let gpsService = GPSService()
        let gsensorService = GSensorService()
        let videoFile = VideoFile.allSamples.first!

        // Load sample data
        gpsService.loadGPSData(from: videoFile.metadata, startTime: videoFile.timestamp)
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        return ZStack {
            Color.black

            MapOverlayView(
                gpsService: gpsService,
                gsensorService: gsensorService,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
