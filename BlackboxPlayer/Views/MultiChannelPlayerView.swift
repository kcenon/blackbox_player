/// @file MultiChannelPlayerView.swift
/// @brief 다중 채널 동기화 비디오 플레이어 View
/// @author BlackboxPlayer Development Team
/// @details 4개 카메라(Front, Rear, Left, Right)를 동시에 재생하는 플레이어입니다.
///          Metal 렌더링, GPS/G-Sensor 오버레이, 전체화면 모드, 스크린샷 캡처 기능을 제공합니다.
///
/// ## 주요 기능
/// - **다중 채널 동기화 재생**: 4개 카메라(Front, Rear, Left, Right) 동시 재생
/// - **Metal 렌더링**: MTKView와 MultiChannelRenderer로 고성능 렌더링
/// - **레이아웃 모드**: Grid (2x2), Focus (1개 크게), Horizontal (가로 나열)
/// - **비디오 변환**: 밝기, 줌, 가로/세로 플립 실시간 조정
/// - **GPS/G-Sensor 오버레이**: 지도와 가속도 그래프 실시간 표시
/// - **전체화면 모드**: 자동 컨트롤 숨김 (3초 후)
/// - **스크린샷 캡처**: 현재 프레임 PNG 저장
///
/// ## 레이아웃 구조
/// ```
/// ┌────────────────────────────────────────────────┐
/// │ [Grid][Focus][Horizontal]  [Transform]  [F][R] │ ← 상단 바 (레이아웃 + 채널 선택)
/// ├────────────────────────────────────────────────┤
/// │                                                │
/// │   ┌──────────┬──────────┐                     │
/// │   │  Front   │   Rear   │  (Grid 모드)        │
/// │   ├──────────┼──────────┤                     │ ← Metal 렌더링 영역
/// │   │  Left    │  Right   │                     │
/// │   └──────────┴──────────┘                     │
/// │                                                │
/// │   GPS 지도 (좌측 하단)  G-Sensor 그래프 (우측) │ ← 오버레이
/// ├────────────────────────────────────────────────┤
/// │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ ← 타임라인
/// │ 00:30 / 01:30                                  │
/// │ [▶] [⏪10] [⏩10]  [1.0x]  [📷] [⛶]           │ ← 재생 컨트롤
/// └────────────────────────────────────────────────┘
/// ```
///
/// ## 핵심 개념
/// ### 1. 다중 채널 동기화 재생
/// 4개의 독립적인 비디오 파일을 동시에 재생하며, SyncController가 동기화를 담당합니다.
///
/// **동기화 원리:**
/// ```
/// SyncController
///     ├─ FrontDecoder (decoder1)
///     ├─ RearDecoder (decoder2)
///     ├─ LeftDecoder (decoder3)
///     └─ RightDecoder (decoder4)
///
/// 재생 시:
/// 1. SyncController.play() 호출
///      ↓
/// 2. 모든 decoder가 동일한 시간(currentTime)의 프레임 디코딩
///      ↓
/// 3. getSynchronizedFrames() → [FrontFrame, RearFrame, LeftFrame, RightFrame]
///      ↓
/// 4. MultiChannelRenderer가 4개 프레임을 동시에 렌더링
///      ↓
/// 5. 화면에 4개 영상이 동기화되어 표시
/// ```
///
/// ### 2. Metal 렌더링
/// Metal은 Apple의 고성능 그래픽 API로, 다중 비디오를 효율적으로 렌더링합니다.
///
/// **렌더링 파이프라인:**
/// ```
/// MTKView (60 FPS 렌더링)
///     ↓
/// draw(in view:) 호출 (60Hz)
///     ↓
/// getSynchronizedFrames() → [VideoFrame, VideoFrame, ...]
///     ↓
/// MultiChannelRenderer.render() → Metal Shader 실행
///     ↓
/// GPU가 4개 영상을 텍스처로 렌더링
///     ↓
/// 화면에 표시 (vsync 동기화)
/// ```
///
/// ### 3. 레이아웃 모드
/// - **Grid (2x2)**: 4개 영상을 2x2 격자로 배치
/// - **Focus**: 선택한 1개 영상만 크게 표시
/// - **Horizontal**: 4개 영상을 가로로 나열
///
/// **레이아웃 변환:**
/// ```swift
/// layoutMode = .grid        // 2x2 격자
/// layoutMode = .focus       // 1개 크게
/// layoutMode = .horizontal  // 가로 나열
/// ```
///
/// ### 4. 자동 숨김 컨트롤 (Auto-hide)
/// 전체화면 모드에서 마우스 움직임이 없으면 3초 후 컨트롤이 자동으로 사라집니다.
///
/// **동작 흐름:**
/// ```
/// 전체화면 진입
///      ↓
/// 마우스 움직임 감지 → resetControlsTimer() 호출
///      ↓
/// Timer 시작 (3초)
///      ↓ 3초 동안 마우스 움직임 없음
/// showControls = false → 컨트롤 숨김
///      ↓ 마우스 다시 움직임
/// showControls = true → 컨트롤 표시
/// ```
///
/// ## 사용 예시
/// ```swift
/// // 1. VideoFile 전달하여 플레이어 생성
/// let videoFile = VideoFile(...)
/// MultiChannelPlayerView(videoFile: videoFile)
///
/// // 2. 플레이어가 자동으로:
/// //    - videoFile.channels에서 4개 채널 로드
/// //    - SyncController로 동기화 재생
/// //    - Metal로 렌더링
/// //    - GPS/G-Sensor 오버레이 표시
///
/// // 3. 사용자 인터랙션:
/// //    - [Grid] 버튼 → 2x2 레이아웃
/// //    - [F] 버튼 → Front 채널만 크게 표시
/// //    - [▶] 버튼 → 재생/일시정지
/// //    - [1.0x] 메뉴 → 재생 속도 조절
/// //    - [📷] 버튼 → 스크린샷 캡처
/// //    - [⛶] 버튼 → 전체화면 전환
/// ```
///
/// ## 실제 사용 시나리오
/// **시나리오 1: 블랙박스 영상 재생**
/// ```
/// 1. 사용자가 FileListView에서 비디오 파일 선택
///      ↓
/// 2. MultiChannelPlayerView(videoFile: file) 생성
///      ↓
/// 3. loadVideoFile() → syncController.loadVideoFile(videoFile)
///      ↓
/// 4. 4개 채널 (Front, Rear, Left, Right) 디코더 초기화
///      ↓
/// 5. MetalVideoView에서 Metal 렌더링 시작
///      ↓
/// 6. GPS 지도 + G-Sensor 그래프 오버레이 표시
///      ↓
/// 7. 사용자가 Play 버튼 클릭 → 4개 영상 동기화 재생
/// ```
///
/// **시나리오 2: 레이아웃 변경**
/// ```
/// 1. 초기 상태: Grid 모드 (2x2)
///      ┌──────┬──────┐
///      │Front │Rear  │
///      ├──────┼──────┤
///      │Left  │Right │
///      └──────┴──────┘
///
/// 2. [F] 버튼 클릭 → Focus 모드로 전환
///      ┌────────────────┐
///      │                │
///      │     Front      │
///      │                │
///      └────────────────┘
///
/// 3. [Horizontal] 버튼 클릭 → 가로 나열
///      ┌────┬────┬────┬────┐
///      │Fron│Rear│Left│Righ│
///      └────┴────┴────┴────┘
/// ```
///
/// **시나리오 3: 비디오 변환 (밝기 조절)**
/// ```
/// 1. [Transform] 버튼 클릭 → 변환 컨트롤 표시
///      ↓
/// 2. Brightness 슬라이더를 0.5로 조정
///      ↓
/// 3. transformationService.setBrightness(0.5)
///      ↓
/// 4. Metal Shader에서 밝기 증가 효과 적용
///      ↓
/// 5. 4개 영상 모두 밝아짐 (실시간)
/// ```
//
//  MultiChannelPlayerView.swift
//  BlackboxPlayer
//
//  Multi-channel synchronized video player view
//

import SwiftUI
import MetalKit

/// @struct MultiChannelPlayerView
/// @brief 다중 채널 동기화 비디오 플레이어 메인 View
/// @details 4개 카메라를 동시 재생하고 Metal로 고성능 렌더링합니다.
struct MultiChannelPlayerView: View {
    // MARK: - Properties

    /// @var syncController
    /// @brief 동기화 컨트롤러
    /// @details 4개의 VideoDecoder를 관리하여 동기화된 프레임을 제공합니다.
    ///
    /// ## SyncController
    /// - 다중 채널 동기화 재생을 담당하는 ObservableObject
    /// - 4개의 VideoDecoder를 관리하여 동기화된 프레임 제공
    ///
    /// ## @StateObject
    /// - View의 생명주기 동안 단일 인스턴스 유지
    /// - View가 재생성되어도 syncController는 유지됨
    ///
    /// **동기화 역할:**
    /// ```
    /// syncController
    ///     ├─ play() → 4개 decoder 동시 재생
    ///     ├─ pause() → 4개 decoder 동시 일시정지
    ///     ├─ seekToTime() → 4개 decoder 동시 시크
    ///     └─ getSynchronizedFrames() → [Front, Rear, Left, Right] 프레임 반환
    /// ```
    @StateObject private var syncController = SyncController()

    /// @var videoFile
    /// @brief 재생할 비디오 파일
    /// @details 4개 채널 정보를 포함하는 VideoFile 객체입니다.
    ///
    /// ## VideoFile
    /// - 4개 채널 (Front, Rear, Left, Right) 정보 포함
    /// - channels 배열에서 각 카메라 위치별 filePath 가져옴
    ///
    /// **예시:**
    /// ```swift
    /// videoFile.channels = [
    ///     ChannelInfo(position: .front, filePath: "/front.mp4"),
    ///     ChannelInfo(position: .rear, filePath: "/rear.mp4"),
    ///     ChannelInfo(position: .left, filePath: "/left.mp4"),
    ///     ChannelInfo(position: .right, filePath: "/right.mp4")
    /// ]
    /// ```
    let videoFile: VideoFile

    /// @var layoutMode
    /// @brief 현재 레이아웃 모드
    /// @details Grid, Focus, Horizontal 중 하나의 레이아웃 모드를 저장합니다.
    ///
    /// ## LayoutMode
    /// - .grid: 2x2 격자 레이아웃 (4개 균등 분할)
    /// - .focus: 선택한 1개 채널만 크게 표시
    /// - .horizontal: 가로 나열 (1x4)
    ///
    /// **레이아웃 변환 예시:**
    /// ```swift
    /// layoutMode = .grid  // Grid 버튼 클릭
    ///      ↓
    /// MetalVideoView가 updateNSView 호출받음
    ///      ↓
    /// renderer.setLayoutMode(.grid) → Metal Shader에 전달
    ///      ↓
    /// 2x2 레이아웃으로 렌더링
    /// ```
    @State private var layoutMode: LayoutMode = .grid

    /// 포커스 모드에서 선택된 카메라 위치
    ///
    /// ## CameraPosition
    /// - .front, .rear, .left, .right
    /// - Focus 모드일 때 어떤 채널을 크게 보여줄지 결정
    ///
    /// **동작:**
    /// ```swift
    /// layoutMode = .focus
    /// focusedPosition = .front  // Front 카메라만 크게 표시
    /// ```
    @State private var focusedPosition: CameraPosition = .front

    /// 컨트롤 오버레이 표시 여부
    ///
    /// ## 표시 조건
    /// - true: 컨트롤 표시 (Play/Pause, Timeline, 레이아웃 버튼 등)
    /// - false: 컨트롤 숨김 (전체화면 모드에서 3초 후)
    ///
    /// **동작:**
    /// ```swift
    /// if showControls || isHovering {
    ///     controlsOverlay  // 컨트롤 표시
    /// }
    /// ```
    @State private var showControls = true

    /// 마우스 호버 상태
    ///
    /// ## .onHover { hovering in ... }
    /// - hovering == true: 마우스가 View 위에 있음
    /// - hovering == false: 마우스가 View 밖으로 나감
    ///
    /// **역할:**
    /// - 마우스가 View 안에 있으면 컨트롤 표시
    /// - 전체화면 모드에서 컨트롤 자동 숨김 방지
    @State private var isHovering = false

    /// Renderer 참조 (스크린샷 캡처용)
    ///
    /// ## MultiChannelRenderer
    /// - Metal 기반 비디오 렌더러
    /// - captureAndSave() 메서드로 스크린샷 저장
    ///
    /// **스크린샷 캡처:**
    /// ```swift
    /// renderer?.captureAndSave(format: .png, timestamp: Date(), ...)
    /// ```
    @State private var renderer: MultiChannelRenderer?

    /// 비디오 변환 서비스
    ///
    /// ## VideoTransformationService
    /// - 싱글톤 서비스 (.shared)
    /// - 밝기, 줌, 플립 등 비디오 변환 파라미터 관리
    ///
    /// ## @ObservedObject
    /// - transformationService의 변경사항 관찰
    /// - transformations 값이 변경되면 View 자동 재렌더링
    ///
    /// **변환 적용:**
    /// ```swift
    /// transformationService.setBrightness(0.5)  // 밝기 증가
    ///      ↓
    /// Metal Shader가 transformations.brightness 읽음
    ///      ↓
    /// 비디오에 밝기 효과 적용
    /// ```
    @ObservedObject private var transformationService = VideoTransformationService.shared

    /// 변환 컨트롤 표시 여부
    ///
    /// ## showTransformControls
    /// - true: Brightness, Zoom, Flip 슬라이더 표시
    /// - false: 슬라이더 숨김 (기본값)
    ///
    /// **토글:**
    /// ```swift
    /// Button(action: { showTransformControls.toggle() }) {
    ///     Image(systemName: "slider.horizontal.3")
    /// }
    /// ```
    @State private var showTransformControls = false

    /// 전체화면 모드 상태
    ///
    /// ## isFullscreen
    /// - true: 전체화면 모드 (컨트롤 자동 숨김 활성화)
    /// - false: 일반 모드 (컨트롤 항상 표시)
    ///
    /// **전체화면 진입/종료:**
    /// ```swift
    /// toggleFullscreen()
    ///      ↓
    /// window.toggleFullScreen(nil)  // macOS API
    ///      ↓
    /// isFullscreen.toggle()
    /// ```
    @State private var isFullscreen = false

    /// 컨트롤 자동 숨김 타이머
    ///
    /// ## Timer
    /// - 전체화면 모드에서 3초 후 컨트롤 자동 숨김
    /// - 마우스 움직임 감지 시 타이머 리셋
    ///
    /// **동작:**
    /// ```swift
    /// resetControlsTimer()
    ///      ↓
    /// Timer.scheduledTimer(withTimeInterval: 3.0) {
    ///     showControls = false  // 3초 후 숨김
    /// }
    /// ```
    @State private var controlsTimer: Timer?

    /// 사용 가능한 디스플레이 목록
    ///
    /// ## NSScreen.screens
    /// - macOS의 모든 연결된 디스플레이 배열
    /// - 멀티 모니터 환경에서 전체화면 대상 선택
    ///
    /// **예시:**
    /// ```swift
    /// availableDisplays = [
    ///     NSScreen(main display, 1920x1080),
    ///     NSScreen(external display, 2560x1440)
    /// ]
    /// ```
    @State private var availableDisplays: [NSScreen] = []

    /// 전체화면에 선택된 디스플레이
    ///
    /// ## selectedDisplay
    /// - 기본값: NSScreen.main (메인 디스플레이)
    /// - 사용자가 다른 디스플레이 선택 가능
    @State private var selectedDisplay: NSScreen?

    // MARK: - Body

    /// MultiChannelPlayerView의 메인 레이아웃
    ///
    /// ## ZStack 구조
    /// - 여러 View를 겹쳐서 배치 (z-index 순서)
    /// - 맨 아래: MetalVideoView (비디오 렌더링)
    /// - 중간: GPS 지도, G-Sensor 그래프 오버레이
    /// - 맨 위: 컨트롤 UI (재생 버튼, 타임라인 등)
    ///
    /// **레이어 구조:**
    /// ```
    /// ┌─────────────────────────────┐
    /// │  controlsOverlay (맨 위)     │ ← 반투명 컨트롤
    /// ├─────────────────────────────┤
    /// │  GraphOverlayView (중간2)   │ ← G-Sensor 그래프
    /// ├─────────────────────────────┤
    /// │  MapOverlayView (중간1)     │ ← GPS 지도
    /// ├─────────────────────────────┤
    /// │  MetalVideoView (맨 아래)   │ ← 비디오 렌더링
    /// └─────────────────────────────┘
    /// ```
    var body: some View {
        ZStack {
            /// Metal 기반 비디오 렌더링 View
            ///
            /// ## MetalVideoView
            /// - NSViewRepresentable로 MTKView 래핑
            /// - Metal GPU를 사용한 고성능 렌더링
            /// - syncController에서 동기화된 프레임 가져와 표시
            ///
            /// **렌더링 흐름:**
            /// ```
            /// MTKView.draw(in:) 호출 (60 FPS)
            ///      ↓
            /// syncController.getSynchronizedFrames()
            ///      ↓
            /// renderer.render(frames: [...], to: drawable)
            ///      ↓
            /// Metal Shader 실행 → GPU 렌더링
            ///      ↓
            /// 화면에 표시
            /// ```
            MetalVideoView(
                syncController: syncController,
                layoutMode: layoutMode,
                focusedPosition: focusedPosition,
                onRendererCreated: { renderer = $0 }  // renderer 참조 저장
            )

            /// GPS 지도 오버레이
            ///
            /// ## MapOverlayView
            /// - 좌측 하단에 미니맵 표시
            /// - GPS 경로를 실시간으로 그림 (파란색 선)
            /// - 현재 위치를 표시 (빨간 점)
            MapOverlayView(
                gpsService: syncController.gpsService,
                gsensorService: syncController.gsensorService,
                currentTime: syncController.currentTime
            )

            /// G-Sensor 그래프 오버레이
            ///
            /// ## GraphOverlayView
            /// - 우측 하단에 가속도 그래프 표시
            /// - X/Y/Z축 데이터를 실시간 그래프로 표시
            /// - 충격 이벤트 감지 시 하이라이트
            GraphOverlayView(
                gsensorService: syncController.gsensorService,
                currentTime: syncController.currentTime
            )

            /// 컨트롤 오버레이 (조건부 렌더링)
            ///
            /// ## 표시 조건
            /// - showControls == true OR isHovering == true
            /// - 전체화면 모드: 3초 후 자동 숨김
            /// - 일반 모드: 항상 표시
            ///
            /// ## .transition(.opacity)
            /// - 컨트롤 표시/숨김 시 페이드 인/아웃 애니메이션
            if showControls || isHovering {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        /// ## .onAppear
        /// - View가 화면에 나타날 때 한 번 호출
        /// - 비디오 파일 로드 및 디스플레이 감지
        .onAppear {
            loadVideoFile()            // 비디오 파일 로드
            detectAvailableDisplays()  // 연결된 디스플레이 감지
        }
        /// ## .onDisappear
        /// - View가 화면에서 사라질 때 호출
        /// - 리소스 정리 (재생 중지, 타이머 해제)
        .onDisappear {
            syncController.stop()      // 재생 중지
            controlsTimer?.invalidate()  // 타이머 해제
        }
        /// ## .onHover { hovering in ... }
        /// - 마우스가 View 위에 있는지 감지
        /// - hovering == true: 마우스가 View 안에 들어옴
        /// - hovering == false: 마우스가 View 밖으로 나감
        ///
        /// **동작:**
        /// ```
        /// 마우스가 View 안으로 이동
        ///      ↓
        /// isHovering = true
        ///      ↓
        /// showControls = true (컨트롤 표시)
        ///      ↓
        /// resetControlsTimer() (자동 숨김 타이머 리셋)
        /// ```
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                // Show controls when mouse enters
                showControls = true
                resetControlsTimer()
            }
        }
        /// ## .gesture(DragGesture(minimumDistance: 0))
        /// - minimumDistance: 0 → 클릭만으로도 감지 (드래그 불필요)
        /// - 마우스 움직임을 감지하여 컨트롤 표시
        ///
        /// **동작:**
        /// ```
        /// 마우스 이동 (또는 클릭)
        ///      ↓
        /// .onChanged { _ in ... } 호출
        ///      ↓
        /// showControls = true
        ///      ↓
        /// resetControlsTimer() (3초 타이머 리셋)
        /// ```
        .gesture(
            // Track mouse movement to show controls
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    showControls = true
                    resetControlsTimer()
                }
        )
        /// ## .onReceive(NotificationCenter...)
        /// - macOS 시스템 이벤트를 구독
        /// - 전체화면 진입/종료, 디스플레이 변경 감지
        ///
        /// ### NSWindow.willEnterFullScreenNotification
        /// - 전체화면 모드 진입 직전 알림
        /// - isFullscreen = true 설정
        /// - 컨트롤 자동 숨김 타이머 시작
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
            infoLog("[MultiChannelPlayerView] Entering fullscreen mode")
            resetControlsTimer()
        }
        /// ### NSWindow.willExitFullScreenNotification
        /// - 전체화면 모드 종료 직전 알림
        /// - isFullscreen = false 설정
        /// - 컨트롤 항상 표시 (자동 숨김 비활성화)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
            showControls = true
            controlsTimer?.invalidate()
            infoLog("[MultiChannelPlayerView] Exiting fullscreen mode")
        }
        /// ### NSApplication.didChangeScreenParametersNotification
        /// - 디스플레이 구성 변경 알림
        /// - 모니터 연결/해제, 해상도 변경 등
        /// - availableDisplays 재감지
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            detectAvailableDisplays()
            infoLog("[MultiChannelPlayerView] Screen configuration changed")
        }
    }

    // MARK: - Controls Overlay

    /// 컨트롤 오버레이 View
    ///
    /// ## 구조
    /// - 상단 바: 레이아웃 버튼 + 변환 버튼 + 채널 인디케이터
    /// - (조건부) 변환 컨트롤: 밝기/줌/플립 슬라이더
    /// - 하단 바: 타임라인 + 재생 컨트롤
    ///
    /// **레이아웃:**
    /// ```
    /// ┌────────────────────────────────────────────────┐
    /// │ [Grid][Focus][Horizontal]  [Transform]  [F][R] │ ← 상단 바
    /// │ [Brightness ━━━━] [Zoom ━━━━] [Flip H] [Reset]│ ← 변환 컨트롤 (showTransformControls)
    /// │                                                │
    /// │                 (비디오)                       │
    /// │                                                │
    /// │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ ← 타임라인
    /// │ [▶] [⏪10] [⏩10]  [1.0x]  [📷] [⛶]           │ ← 재생 컨트롤
    /// └────────────────────────────────────────────────┘
    /// ```
    private var controlsOverlay: some View {
        VStack {
            /// 상단 바: 레이아웃 및 변환 컨트롤
            VStack(spacing: 8) {
                HStack {
                    /// 레이아웃 버튼 (Grid, Focus, Horizontal)
                    layoutControls

                    Spacer()

                    /// 변환 토글 버튼
                    ///
                    /// ## 동작
                    /// - 클릭 시 showTransformControls 토글
                    /// - true: 변환 슬라이더 표시 (밝기, 줌, 플립)
                    /// - false: 변환 슬라이더 숨김
                    ///
                    /// **아이콘 색상:**
                    /// - showTransformControls == true: 흰색 + 파란 배경
                    /// - showTransformControls == false: 반투명 흰색
                    Button(action: { showTransformControls.toggle() }) {
                        Image(systemName: showTransformControls ? "slider.horizontal.3" : "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(showTransformControls ? .white : .white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(showTransformControls ? Color.accentColor : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Video Transformations")

                    Spacer()
                        .frame(width: 12)

                    /// 채널 인디케이터 (F, R, L, R 버튼)
                    channelIndicators
                }

                /// 변환 컨트롤 (조건부 렌더링)
                ///
                /// ## showTransformControls == true일 때만 표시
                /// - Brightness 슬라이더 (-1.0 ~ 1.0)
                /// - Zoom 슬라이더 (1.0x ~ 5.0x)
                /// - Flip Horizontal/Vertical 버튼
                /// - Reset 버튼 (모든 변환 초기화)
                if showTransformControls {
                    transformationControls
                }
            }
            .padding()
            /// ## LinearGradient 배경
            /// - 상단이 어두운 그라데이션 (반투명)
            /// - 하단으로 갈수록 투명해짐
            /// - 비디오 위에 컨트롤이 겹쳐도 가독성 유지
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            /// 하단 바: 타임라인 및 재생 컨트롤
            VStack(spacing: 12) {
                /// 타임라인 슬라이더
                timelineView

                /// 재생 컨트롤 버튼들
                HStack(spacing: 20) {
                    playbackControls
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding()
            /// ## LinearGradient 배경
            /// - 하단이 어두운 그라데이션 (반투명)
            /// - 상단으로 갈수록 투명해짐
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Layout Controls

    /// 레이아웃 모드 선택 버튼
    ///
    /// ## 레이아웃 모드
    /// - Grid: 2x2 격자 (4개 균등 분할)
    /// - Focus: 선택한 1개 채널만 크게
    /// - Horizontal: 가로 나열 (1x4)
    ///
    /// **버튼 동작:**
    /// ```swift
    /// ForEach(LayoutMode.allCases) { mode in
    ///     Button { layoutMode = mode }  // 모드 변경
    /// }
    /// ```
    ///
    /// **렌더링 반영:**
    /// ```
    /// layoutMode 변경
    ///      ↓ @State → View 재렌더링
    /// MetalVideoView.updateNSView() 호출
    ///      ↓
    /// renderer.setLayoutMode(layoutMode)
    ///      ↓
    /// Metal Shader에서 레이아웃 재계산
    ///      ↓
    /// 화면에 새 레이아웃으로 표시
    /// ```
    private var layoutControls: some View {
        HStack(spacing: 12) {
            ForEach(LayoutMode.allCases, id: \.self) { mode in
                Button(action: { layoutMode = mode }) {
                    Image(systemName: iconName(for: mode))
                        .font(.system(size: 18))
                        .foregroundColor(layoutMode == mode ? .white : .white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(layoutMode == mode ? Color.accentColor : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(mode.displayName)
            }
        }
    }

    /// 채널 인디케이터 버튼 (F, R, L, R)
    ///
    /// ## 역할
    /// - 각 카메라 위치를 버튼으로 표시
    /// - 클릭 시 해당 채널로 Focus 모드 전환
    ///
    /// **버튼 생성:**
    /// ```swift
    /// videoFile.channels.filter(\.isEnabled)  // 활성화된 채널만
    ///      ↓
    /// ForEach { channel in
    ///     Button(action: {
    ///         focusedPosition = channel.position  // 포커스 설정
    ///         layoutMode = .focus                 // Focus 모드로 전환
    ///     }) { ... }
    /// }
    /// ```
    ///
    /// **버튼 예시:**
    /// ```
    /// [F] [R] [L] [R]  ← Front, Rear, Left, Right
    ///  ↑ 선택됨 (파란 배경)
    /// ```
    private var channelIndicators: some View {
        HStack(spacing: 8) {
            ForEach(videoFile.channels.filter(\.isEnabled), id: \.position) { channel in
                Button(action: {
                    focusedPosition = channel.position
                    if layoutMode != .focus {
                        layoutMode = .focus
                    }
                }) {
                    Text(channel.position.shortName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            focusedPosition == channel.position && layoutMode == .focus
                                ? Color.accentColor
                                : Color.white.opacity(0.3)
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(channel.position.displayName)
            }
        }
    }

    // MARK: - Transformation Controls

    /// 비디오 변환 컨트롤 (Brightness, Zoom, Flip)
    ///
    /// ## 변환 종류
    /// - **Brightness**: -1.0 (어둡게) ~ 1.0 (밝게)
    /// - **Zoom**: 1.0x (원본) ~ 5.0x (5배 확대)
    /// - **Flip Horizontal**: 좌우 반전
    /// - **Flip Vertical**: 상하 반전
    ///
    /// ## VideoTransformationService
    /// - 싱글톤 서비스로 변환 파라미터 관리
    /// - Metal Shader에서 transformations 읽어 실시간 적용
    ///
    /// **변환 적용 흐름:**
    /// ```
    /// 사용자가 Brightness 슬라이더 조정
    ///      ↓
    /// transformationService.setBrightness(0.5)
    ///      ↓
    /// transformationService.transformations.brightness = 0.5
    ///      ↓ @Published → View 재렌더링
    /// Metal Shader가 transformations.brightness 읽음
    ///      ↓
    /// GPU에서 밝기 효과 적용 (모든 픽셀에 +0.5)
    ///      ↓
    /// 화면에 밝아진 영상 표시
    /// ```
    private var transformationControls: some View {
        VStack(spacing: 12) {
            /// 첫 번째 줄: Brightness와 Zoom
            HStack(spacing: 20) {
                /// Brightness 컨트롤
                ///
                /// ## Slider + Binding
                /// - Binding(get:, set:)으로 양방향 바인딩
                /// - get: transformationService.transformations.brightness 읽기
                /// - set: transformationService.setBrightness($0) 호출
                ///
                /// **동작:**
                /// ```swift
                /// 슬라이더 드래그
                ///      ↓
                /// set: { transformationService.setBrightness($0) } 호출
                ///      ↓
                /// transformations.brightness 업데이트
                ///      ↓
                /// Metal Shader에 즉시 반영
                /// ```
                HStack(spacing: 8) {
                    /// 어두운 해 아이콘 (최소값 표시)
                    Image(systemName: "sun.min")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// Brightness 슬라이더 (-1.0 ~ 1.0)
                    Slider(
                        value: Binding(
                            get: { transformationService.transformations.brightness },
                            set: { transformationService.setBrightness($0) }
                        ),
                        in: -1.0...1.0
                    )
                    .frame(width: 120)

                    /// 밝은 해 아이콘 (최대값 표시)
                    Image(systemName: "sun.max")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// 현재 밝기 값 텍스트
                    ///
                    /// ## String(format: "%.2f", ...)
                    /// - 소수점 2자리까지 표시
                    /// - 예: 0.50, -0.75
                    Text(String(format: "%.2f", transformationService.transformations.brightness))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40)
                }

                /// Zoom 컨트롤
                ///
                /// ## Zoom 범위
                /// - 1.0x: 원본 크기
                /// - 5.0x: 5배 확대
                ///
                /// **확대 원리:**
                /// ```
                /// zoomLevel = 2.0x
                ///      ↓
                /// Metal Shader에서 텍스처 좌표 조정
                ///      ↓
                /// 중심을 기준으로 2배 확대
                ///      ↓
                /// 화면에 확대된 영상 표시
                /// ```
                HStack(spacing: 8) {
                    /// 축소 아이콘 (최소값 표시)
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// Zoom 슬라이더 (1.0 ~ 5.0)
                    Slider(
                        value: Binding(
                            get: { transformationService.transformations.zoomLevel },
                            set: { transformationService.setZoomLevel($0) }
                        ),
                        in: 1.0...5.0
                    )
                    .frame(width: 120)

                    /// 확대 아이콘 (최대값 표시)
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// 현재 줌 레벨 텍스트
                    ///
                    /// ## String(format: "%.1fx", ...)
                    /// - 소수점 1자리 + "x" 접미사
                    /// - 예: 1.0x, 2.5x
                    Text(String(format: "%.1fx", transformationService.transformations.zoomLevel))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40)
                }
            }

            /// 두 번째 줄: Flip 버튼과 Reset
            HStack(spacing: 12) {
                /// Flip Horizontal 버튼
                ///
                /// ## 좌우 반전
                /// - toggleFlipHorizontal() 호출
                /// - flipHorizontal == true: 좌우 반전 활성화 (파란 배경)
                /// - flipHorizontal == false: 반전 비활성화 (회색 배경)
                ///
                /// **반전 원리:**
                /// ```
                /// flipHorizontal = true
                ///      ↓
                /// Metal Shader에서 텍스처 좌표 반전 (u = 1.0 - u)
                ///      ↓
                /// 좌우가 뒤바뀐 영상 표시
                /// ```
                Button(action: { transformationService.toggleFlipHorizontal() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 14))
                        Text("Flip H")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(
                        transformationService.transformations.flipHorizontal
                            ? Color.accentColor
                            : Color.white.opacity(0.2)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Flip Horizontal")

                /// Flip Vertical 버튼
                ///
                /// ## 상하 반전
                /// - toggleFlipVertical() 호출
                /// - flipVertical == true: 상하 반전 활성화 (파란 배경)
                /// - flipVertical == false: 반전 비활성화 (회색 배경)
                ///
                /// **반전 원리:**
                /// ```
                /// flipVertical = true
                ///      ↓
                /// Metal Shader에서 텍스처 좌표 반전 (v = 1.0 - v)
                ///      ↓
                /// 상하가 뒤바뀐 영상 표시
                /// ```
                Button(action: { transformationService.toggleFlipVertical() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 14))
                        Text("Flip V")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(
                        transformationService.transformations.flipVertical
                            ? Color.accentColor
                            : Color.white.opacity(0.2)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Flip Vertical")

                Spacer()

                /// Reset 버튼
                ///
                /// ## 모든 변환 초기화
                /// - resetTransformations() 호출
                /// - brightness = 0.0
                /// - zoomLevel = 1.0
                /// - flipHorizontal = false
                /// - flipVertical = false
                Button(action: { transformationService.resetTransformations() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                        Text("Reset")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Reset all transformations")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    // MARK: - Timeline

    /// 타임라인 View (재생 진행 바 + 시간 표시)
    ///
    /// ## 구성 요소
    /// - Progress bar: 현재 재생 위치 표시 (파란색 바)
    /// - 시간 레이블: 현재 시간 / 남은 시간
    ///
    /// **타임라인 동작:**
    /// ```
    /// 사용자가 타임라인 드래그
    ///      ↓
    /// DragGesture.onChanged { value in
    ///     position = value.location.x / geometry.size.width
    ///     time = position * syncController.duration
    ///     syncController.seekToTime(time)
    /// }
    ///      ↓
    /// 4개 채널이 동시에 해당 시간으로 시크
    ///      ↓
    /// 화면에 시크한 위치의 프레임 표시
    /// ```
    private var timelineView: some View {
        VStack(spacing: 4) {
            /// Progress bar (클릭/드래그 가능)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    /// 배경 (회색, 전체 길이)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)

                    /// Progress (파란색, 재생 위치까지)
                    ///
                    /// ## width 계산
                    /// ```swift
                    /// width = geometry.size.width * syncController.playbackPosition
                    /// ```
                    ///
                    /// **예시:**
                    /// ```
                    /// geometry.size.width = 800px
                    /// playbackPosition = 0.5 (50%)
                    ///      ↓
                    /// width = 800 * 0.5 = 400px (절반까지 파란색)
                    /// ```
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * syncController.playbackPosition, height: 4)
                }
                .cornerRadius(2)
                /// ## DragGesture(minimumDistance: 0)
                /// - minimumDistance: 0 → 클릭만으로도 시크 가능 (드래그 불필요)
                /// - .onChanged: 드래그 중 계속 호출됨
                ///
                /// **시크 계산:**
                /// ```swift
                /// // 사용자가 타임라인의 75% 위치 클릭
                /// value.location.x = 600px
                /// geometry.size.width = 800px
                ///      ↓
                /// position = 600 / 800 = 0.75 (75%)
                ///      ↓
                /// time = 0.75 * 90 = 67.5초
                ///      ↓
                /// syncController.seekToTime(67.5) → 67.5초로 시크
                /// ```
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let position = Double(value.location.x / geometry.size.width)
                            let time = position * syncController.duration
                            syncController.seekToTime(time)
                        }
                )
            }
            .frame(height: 4)

            /// 시간 레이블
            HStack {
                /// 현재 시간 (예: "01:30")
                Text(syncController.currentTimeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                /// 남은 시간 (예: "-00:30")
                Text(syncController.remainingTimeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Playback Controls

    /// 재생 컨트롤 버튼들
    ///
    /// ## 버튼 목록
    /// - Play/Pause: 재생/일시정지 토글
    /// - Seek backward: 10초 뒤로
    /// - Seek forward: 10초 앞으로
    /// - Speed: 재생 속도 메뉴 (0.25x ~ 2.0x)
    /// - Buffer indicator: 버퍼링 중 표시
    /// - Channel count: 채널 개수 표시
    /// - Screenshot: 스크린샷 캡처
    /// - Fullscreen: 전체화면 토글
    private var playbackControls: some View {
        HStack(spacing: 20) {
            /// Play/Pause 버튼
            ///
            /// ## 아이콘 선택
            /// - .playing: "pause.fill" (일시정지 아이콘)
            /// - .paused 또는 .stopped: "play.fill" (재생 아이콘)
            ///
            /// **동작:**
            /// ```
            /// togglePlayPause() 호출
            ///      ↓
            /// syncController.togglePlayPause()
            ///      ↓
            /// 4개 decoder 동시 재생/일시정지
            /// ```
            Button(action: { syncController.togglePlayPause() }) {
                Image(systemName: syncController.playbackState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .help(syncController.playbackState == .playing ? "Pause" : "Play")

            /// Seek backward 버튼 (10초 뒤로)
            ///
            /// ## seekBySeconds(-10)
            /// - 현재 시간에서 10초 빼기
            /// - 음수 값으로 뒤로 이동
            ///
            /// **예시:**
            /// ```
            /// currentTime = 30초
            ///      ↓
            /// seekBySeconds(-10)
            ///      ↓
            /// seekToTime(20초) → 20초로 시크
            /// ```
            Button(action: { syncController.seekBySeconds(-10) }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Seek backward 10 seconds")

            /// Seek forward 버튼 (10초 앞으로)
            ///
            /// ## seekBySeconds(10)
            /// - 현재 시간에서 10초 더하기
            /// - 양수 값으로 앞으로 이동
            ///
            /// **예시:**
            /// ```
            /// currentTime = 30초
            ///      ↓
            /// seekBySeconds(10)
            ///      ↓
            /// seekToTime(40초) → 40초로 시크
            /// ```
            Button(action: { syncController.seekBySeconds(10) }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Seek forward 10 seconds")

            Spacer()

            /// 재생 속도 메뉴
            speedControl

            /// 버퍼링 인디케이터
            ///
            /// ## isBuffering
            /// - true: ProgressView 표시 (로딩 스피너)
            /// - false: 표시 안 함
            ///
            /// **버퍼링 시점:**
            /// - 시크 중
            /// - 프레임 디코딩 지연
            /// - 디스크 I/O 대기
            if syncController.isBuffering {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            }

            /// 채널 개수 표시
            ///
            /// ## channelCount
            /// - syncController가 관리하는 채널 개수
            /// - 예: "4 channels"
            Text("\(syncController.channelCount) channels")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
                .frame(width: 20)

            /// 스크린샷 버튼
            ///
            /// ## captureScreenshot()
            /// - 현재 렌더링 중인 프레임을 PNG로 저장
            /// - 파일명: Blackbox_YYYYMMdd_HHmmss.png
            /// - 저장 위치: 사용자 선택 (Save Panel)
            Button(action: captureScreenshot) {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Capture Screenshot")

            /// 전체화면 토글 버튼
            ///
            /// ## toggleFullscreen()
            /// - window.toggleFullScreen(nil) 호출
            /// - isFullscreen 토글
            /// - 전체화면 모드에서 컨트롤 자동 숨김 활성화
            ///
            /// **아이콘:**
            /// - isFullscreen == true: "arrow.down.right.and.arrow.up.left" (축소)
            /// - isFullscreen == false: "arrow.up.left.and.arrow.down.right" (확대)
            Button(action: toggleFullscreen) {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help(isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen")
        }
    }

    // MARK: - Fullscreen

    /// 전체화면 토글 함수
    ///
    /// ## 동작 과정
    /// ```
    /// 1. NSApplication.shared.keyWindow 가져오기
    ///      ↓
    /// 2. window.toggleFullScreen(nil) 호출 (macOS API)
    ///      ↓
    /// 3. isFullscreen 토글 (true ↔ false)
    ///      ↓
    /// 4. 전체화면 모드 진입/종료
    /// ```
    ///
    /// **전체화면 모드 특징:**
    /// - 컨트롤 자동 숨김 (3초 후)
    /// - 마우스 움직임 시 컨트롤 표시
    /// - Escape 키로 종료 가능
    private func toggleFullscreen() {
        /// 현재 활성화된 윈도우 가져오기
        ///
        /// ## NSApplication.shared.keyWindow
        /// - macOS의 현재 활성 윈도우
        /// - nil일 경우: 윈도우가 없거나 비활성 상태
        guard let window = NSApplication.shared.keyWindow else {
            warningLog("[MultiChannelPlayerView] No key window available for fullscreen toggle")
            return
        }

        /// 전체화면 토글
        ///
        /// ## window.toggleFullScreen(nil)
        /// - macOS API로 전체화면 전환
        /// - nil: sender 파라미터 (보통 nil 전달)
        ///
        /// **전환 과정:**
        /// ```
        /// 일반 모드 (800x600 윈도우)
        ///      ↓
        /// toggleFullScreen(nil) 호출
        ///      ↓
        /// 전체화면 모드 (1920x1080 화면 전체)
        /// ```
        window.toggleFullScreen(nil)
        isFullscreen.toggle()

        infoLog("[MultiChannelPlayerView] Fullscreen mode: \(isFullscreen)")
    }

    // MARK: - Auto-hide Controls

    /// 컨트롤 자동 숨김 타이머 리셋
    ///
    /// ## 동작 과정
    /// ```
    /// 1. 기존 타이머 무효화 (invalidate)
    ///      ↓
    /// 2. 전체화면 모드가 아니면 종료 (일반 모드는 자동 숨김 안 함)
    ///      ↓
    /// 3. 3초 타이머 생성
    ///      ↓ 3초 후 (마우스 움직임 없음)
    /// 4. showControls = false (컨트롤 숨김)
    /// ```
    ///
    /// **호출 시점:**
    /// - 마우스 움직임 감지
    /// - 마우스 호버 (View 안으로 들어옴)
    /// - 전체화면 진입
    private func resetControlsTimer() {
        /// 기존 타이머 무효화
        ///
        /// ## controlsTimer?.invalidate()
        /// - 이전 타이머를 중지하고 해제
        /// - 타이머가 nil이면 아무 동작 안 함 (?. 연산자)
        controlsTimer?.invalidate()

        /// 전체화면 모드가 아니면 자동 숨김 안 함
        ///
        /// ## guard isFullscreen
        /// - 일반 모드에서는 컨트롤 항상 표시
        /// - 전체화면 모드에서만 자동 숨김 활성화
        guard isFullscreen else {
            return
        }

        /// 3초 타이머 생성
        ///
        /// ## Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false)
        /// - 3.0초 후 클로저 실행
        /// - repeats: false → 한 번만 실행 (반복 안 함)
        ///
        /// **타이머 동작:**
        /// ```
        /// resetControlsTimer() 호출
        ///      ↓
        /// 3초 대기
        ///      ↓ 마우스 움직임 없음
        /// showControls = false (페이드 아웃 애니메이션)
        ///      ↓
        /// 컨트롤 숨김
        ///      ↓ 마우스 다시 움직임
        /// resetControlsTimer() 호출 → 타이머 리셋
        /// ```
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
    }

    // MARK: - Screenshot

    /// 스크린샷 캡처 함수
    ///
    /// ## 캡처 과정
    /// ```
    /// 1. renderer 존재 확인
    ///      ↓
    /// 2. 파일명 생성 (Blackbox_YYYYMMdd_HHmmss)
    ///      ↓
    /// 3. renderer.captureAndSave() 호출
    ///      ↓
    /// 4. Metal에서 현재 렌더링 프레임을 PNG로 변환
    ///      ↓
    /// 5. Save Panel 표시 → 사용자가 저장 위치 선택
    ///      ↓
    /// 6. PNG 파일 저장
    /// ```
    ///
    /// **캡처 내용:**
    /// - 현재 렌더링 중인 4개 채널 영상
    /// - 레이아웃 모드 적용 (Grid/Focus/Horizontal)
    /// - 비디오 변환 적용 (Brightness/Zoom/Flip)
    /// - 타임스탬프 오버레이 (선택적)
    private func captureScreenshot() {
        /// renderer 존재 확인
        ///
        /// ## guard let renderer
        /// - renderer가 nil이면 경고 로그 출력 후 종료
        /// - Metal 렌더러가 초기화되지 않은 상태
        guard let renderer = renderer else {
            warningLog("[MultiChannelPlayerView] Renderer not available for screenshot")
            return
        }

        infoLog("[MultiChannelPlayerView] Capturing screenshot")

        /// 파일명 생성 (타임스탬프 포함)
        ///
        /// ## DateFormatter
        /// - dateFormat: "yyyyMMdd_HHmmss" (예: 20240115_143015)
        /// - 현재 시각으로 고유한 파일명 생성
        ///
        /// **파일명 예시:**
        /// ```
        /// Date() = 2024-01-15 14:30:15
        ///      ↓
        /// dateString = "20240115_143015"
        ///      ↓
        /// filename = "Blackbox_20240115_143015"
        ///      ↓
        /// 저장: Blackbox_20240115_143015.png
        /// ```
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "Blackbox_\(dateString)"

        /// 스크린샷 캡처 및 저장
        ///
        /// ## renderer.captureAndSave()
        /// - format: .png (PNG 형식으로 저장)
        /// - timestamp: Date() (캡처 시각)
        /// - videoTimestamp: syncController.currentTime (비디오 재생 시간)
        /// - defaultFilename: filename (기본 파일명)
        ///
        /// **캡처 프로세스:**
        /// ```
        /// Metal에서 현재 drawable 가져오기
        ///      ↓
        /// drawable.texture를 CGImage로 변환
        ///      ↓
        /// CGImage를 PNG 데이터로 인코딩
        ///      ↓
        /// NSSavePanel 표시 (사용자가 저장 위치 선택)
        ///      ↓
        /// 선택한 경로에 PNG 파일 저장
        /// ```
        renderer.captureAndSave(
            format: .png,
            timestamp: Date(),
            videoTimestamp: syncController.currentTime,
            defaultFilename: filename
        )
    }

    /// 재생 속도 메뉴
    ///
    /// ## 속도 옵션
    /// - 0.25x, 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
    ///
    /// **속도 변경 동작:**
    /// ```
    /// Menu에서 1.5x 선택
    ///      ↓
    /// syncController.playbackSpeed = 1.5
    ///      ↓
    /// 4개 decoder의 Timer 간격 재조정
    ///      ↓
    /// interval = (1.0 / frameRate) / 1.5 (1.5배 빠르게)
    ///      ↓
    /// 1.5배속으로 재생
    /// ```
    private var speedControl: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: { syncController.playbackSpeed = speed }) {
                    HStack {
                        Text(String(format: "%.2fx", speed))
                        /// 현재 선택된 속도에 체크마크 표시
                        if syncController.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(syncController.playbackSpeedString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 28)
                .background(Color.white.opacity(0.2))
                .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .help("Playback speed")
    }

    // MARK: - Helper Methods

    /// 레이아웃 모드에 맞는 아이콘 이름 반환
    ///
    /// ## SF Symbols
    /// - .grid: "square.grid.2x2" (2x2 격자)
    /// - .focus: "rectangle.inset.filled.and.person.filled" (사람 포커스)
    /// - .horizontal: "rectangle.split.3x1" (가로 분할)
    private func iconName(for mode: LayoutMode) -> String {
        switch mode {
        case .grid:
            return "square.grid.2x2"
        case .focus:
            return "rectangle.inset.filled.and.person.filled"
        case .horizontal:
            return "rectangle.split.3x1"
        }
    }

    /// 비디오 파일 로드 함수
    ///
    /// ## 로딩 과정
    /// ```
    /// 1. syncController.loadVideoFile(videoFile) 호출
    ///      ↓
    /// 2. videoFile.channels에서 4개 채널 가져오기
    ///      ↓
    /// 3. 각 채널마다 VideoDecoder 생성 및 초기화
    ///      ↓
    /// 4. GPS/G-Sensor 서비스 초기화
    ///      ↓
    /// 5. 첫 프레임 로드 (모든 채널)
    ///      ↓
    /// 6. 재생 준비 완료 (playbackState = .paused)
    /// ```
    ///
    /// **에러 처리:**
    /// - 파일 없음: errorLog 출력
    /// - 디코더 초기화 실패: errorLog 출력
    /// - 채널 개수 부족: errorLog 출력
    private func loadVideoFile() {
        do {
            infoLog("[MultiChannelPlayerView] Loading video file: \(videoFile.baseFilename)")
            try syncController.loadVideoFile(videoFile)
            infoLog("[MultiChannelPlayerView] Video file loaded successfully. Channels: \(syncController.channelCount)")
        } catch {
            errorLog("[MultiChannelPlayerView] Failed to load video file: \(error)")
        }
    }

    // MARK: - Display Management

    /// 사용 가능한 디스플레이 감지
    ///
    /// ## NSScreen.screens
    /// - macOS의 모든 연결된 디스플레이 배열
    /// - main, external, airplay 등 모든 디스플레이 포함
    ///
    /// **디스플레이 정보:**
    /// - frame: 화면 크기 및 위치 (CGRect)
    /// - localizedName: 디스플레이 이름 (예: "Built-in Retina Display")
    ///
    /// **예시:**
    /// ```
    /// Display 1: Built-in Retina Display, frame: (0.0, 0.0, 2560.0, 1600.0)
    /// Display 2: LG UltraWide, frame: (2560.0, 0.0, 3440.0, 1440.0)
    /// ```
    private func detectAvailableDisplays() {
        availableDisplays = NSScreen.screens
        selectedDisplay = NSScreen.main

        let displayCount = availableDisplays.count
        infoLog("[MultiChannelPlayerView] Detected \(displayCount) display(s)")

        /// 각 디스플레이 정보 로깅
        for (index, screen) in availableDisplays.enumerated() {
            let frame = screen.frame
            let name = screen.localizedName
            debugLog("[MultiChannelPlayerView] Display \(index + 1): \(name), frame: \(frame)")
        }
    }
}

// MARK: - Metal Video View

/// Metal 기반 비디오 렌더링 View
///
/// ## NSViewRepresentable
/// - AppKit의 NSView (MTKView)를 SwiftUI에 통합
/// - makeNSView: MTKView 생성 및 초기 설정 (한 번만 호출)
/// - updateNSView: SwiftUI 상태 변경 시 NSView 업데이트 (여러 번 호출)
/// - makeCoordinator: Delegate 처리를 위한 Coordinator 생성
///
/// ## MTKView
/// - Metal Kit의 View 클래스
/// - Metal GPU를 사용한 고성능 렌더링
/// - 60 FPS 렌더링 가능
///
/// **렌더링 파이프라인:**
/// ```
/// MTKView
///     ↓ draw(in:) 호출 (60 FPS)
/// Coordinator (MTKViewDelegate)
///     ↓
/// syncController.getSynchronizedFrames()
///     ↓ [FrontFrame, RearFrame, LeftFrame, RightFrame]
/// MultiChannelRenderer.render()
///     ↓ Metal Shader 실행
/// GPU 렌더링
///     ↓
/// drawable에 렌더링 결과 저장
///     ↓
/// 화면에 표시 (vsync 동기화)
/// ```
private struct MetalVideoView: NSViewRepresentable {
    // MARK: - Properties

    /// 동기화 컨트롤러
    ///
    /// ## @ObservedObject
    /// - syncController의 변경사항 관찰
    /// - currentTime, playbackState 등 변경 시 View 업데이트
    @ObservedObject var syncController: SyncController

    /// 레이아웃 모드
    ///
    /// ## LayoutMode
    /// - .grid, .focus, .horizontal
    /// - updateNSView에서 Coordinator에 전달
    let layoutMode: LayoutMode

    /// 포커스된 카메라 위치
    ///
    /// ## CameraPosition
    /// - Focus 모드일 때 어떤 채널을 크게 보여줄지 결정
    let focusedPosition: CameraPosition

    /// Renderer 생성 콜백
    ///
    /// ## (MultiChannelRenderer) -> Void
    /// - Renderer가 생성되면 부모 View에 전달
    /// - 스크린샷 캡처 시 사용
    let onRendererCreated: (MultiChannelRenderer) -> Void

    // MARK: - NSViewRepresentable

    /// MTKView 생성 및 초기 설정
    ///
    /// ## makeNSView
    /// - View 생명주기 동안 한 번만 호출
    /// - MTKView 생성 및 Metal 디바이스 설정
    ///
    /// **MTKView 설정:**
    /// - device: Metal 디바이스 (GPU)
    /// - delegate: Coordinator (렌더링 로직)
    /// - preferredFramesPerSecond: 30 FPS 목표
    /// - framebufferOnly: true (최적화)
    /// - clearColor: 검정색 (0, 0, 0, 1)
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()

        /// Metal 디바이스 생성
        ///
        /// ## MTLCreateSystemDefaultDevice()
        /// - 시스템 기본 GPU 디바이스 가져오기
        /// - M1/M2 Mac: Apple Silicon GPU
        /// - Intel Mac: AMD/Intel GPU
        mtkView.device = MTLCreateSystemDefaultDevice()

        /// Delegate 설정
        ///
        /// ## mtkView.delegate = context.coordinator
        /// - Coordinator가 draw(in:) 메서드 구현
        /// - MTKView가 렌더링 준비되면 draw(in:) 호출
        mtkView.delegate = context.coordinator

        /// 렌더링 모드 설정
        ///
        /// ## enableSetNeedsDisplay = false
        /// - false: 자동 렌더링 모드 (preferredFramesPerSecond에 따라)
        /// - true: 수동 렌더링 모드 (setNeedsDisplay() 호출 필요)
        mtkView.enableSetNeedsDisplay = false

        /// 일시정지 설정
        ///
        /// ## isPaused = false
        /// - false: 렌더링 활성화 (계속 draw 호출)
        /// - true: 렌더링 일시정지
        mtkView.isPaused = false

        /// 목표 프레임율 설정
        ///
        /// ## preferredFramesPerSecond = 30
        /// - 30 FPS로 렌더링 (1초에 30번 draw 호출)
        /// - 60 FPS도 가능하지만 비디오는 보통 30 FPS
        mtkView.preferredFramesPerSecond = 30  // Set target frame rate

        /// Framebuffer 최적화
        ///
        /// ## framebufferOnly = true
        /// - true: Framebuffer를 화면 표시만 사용 (읽기 안 함)
        /// - 성능 향상 (GPU 메모리 최적화)
        mtkView.framebufferOnly = true

        /// 배경색 설정
        ///
        /// ## clearColor = MTLClearColor(r: 0, g: 0, b: 0, a: 1)
        /// - 검정색 배경 (비디오 로드 전 표시)
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        return mtkView
    }

    /// NSView 업데이트 (SwiftUI 상태 변경 시)
    ///
    /// ## updateNSView
    /// - SwiftUI의 @State, @Binding 변경 시 호출
    /// - layoutMode, focusedPosition 변경 → Coordinator에 전달
    ///
    /// **호출 시점:**
    /// ```
    /// layoutMode = .focus  // @State 변경
    ///      ↓
    /// SwiftUI가 updateNSView 호출
    ///      ↓
    /// context.coordinator.layoutMode = .focus
    ///      ↓
    /// 다음 draw(in:) 호출 시 새로운 레이아웃으로 렌더링
    /// ```
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.layoutMode = layoutMode
        context.coordinator.focusedPosition = focusedPosition
    }

    /// Coordinator 생성
    ///
    /// ## makeCoordinator
    /// - MTKViewDelegate를 구현하는 Coordinator 생성
    /// - View 생명주기 동안 단일 인스턴스 유지
    ///
    /// **Coordinator 역할:**
    /// - MTKView의 렌더링 로직 구현 (draw(in:))
    /// - MultiChannelRenderer 생성 및 관리
    /// - 동기화된 프레임 가져와 렌더링
    func makeCoordinator() -> Coordinator {
        Coordinator(
            syncController: syncController,
            layoutMode: layoutMode,
            focusedPosition: focusedPosition,
            onRendererCreated: onRendererCreated
        )
    }

    // MARK: - Coordinator

    /// MTKViewDelegate를 구현하는 Coordinator 클래스
    ///
    /// ## Coordinator 패턴
    /// - SwiftUI View와 AppKit Delegate를 연결하는 브릿지
    /// - NSObject 상속 (Objective-C 호환성)
    /// - MTKViewDelegate 프로토콜 구현
    ///
    /// **역할:**
    /// - draw(in:) 메서드로 렌더링 로직 구현
    /// - MultiChannelRenderer로 Metal 렌더링 수행
    /// - SyncController에서 동기화된 프레임 가져오기
    class Coordinator: NSObject, MTKViewDelegate {
        /// 동기화 컨트롤러 참조
        let syncController: SyncController

        /// 현재 레이아웃 모드
        var layoutMode: LayoutMode

        /// 포커스된 카메라 위치
        var focusedPosition: CameraPosition

        /// Metal 렌더러
        var renderer: MultiChannelRenderer?

        /// Coordinator 초기화
        ///
        /// ## init
        /// - syncController, layoutMode, focusedPosition 저장
        /// - MultiChannelRenderer 생성
        /// - onRendererCreated 콜백 호출 (부모 View에 renderer 전달)
        init(
            syncController: SyncController,
            layoutMode: LayoutMode,
            focusedPosition: CameraPosition,
            onRendererCreated: @escaping (MultiChannelRenderer) -> Void
        ) {
            self.syncController = syncController
            self.layoutMode = layoutMode
            self.focusedPosition = focusedPosition
            super.init()

            /// MultiChannelRenderer 생성
            ///
            /// ## MultiChannelRenderer()
            /// - Metal 렌더링 엔진 초기화
            /// - Shader 로드 및 컴파일
            /// - 렌더링 파이프라인 구성
            if let renderer = MultiChannelRenderer() {
                self.renderer = renderer
                onRendererCreated(renderer)  // 부모 View에 전달
            }
        }

        /// MTKView 크기 변경 시 호출
        ///
        /// ## mtkView(_:drawableSizeWillChange:)
        /// - 윈도우 리사이즈, 전체화면 전환 시 호출
        /// - 필요 시 렌더링 리소스 재구성
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes if needed
        }

        /// 렌더링 함수 (60 FPS 호출)
        ///
        /// ## draw(in view:)
        /// - MTKView가 렌더링 준비되면 자동 호출
        /// - preferredFramesPerSecond에 따라 호출 빈도 결정 (30 FPS)
        ///
        /// **렌더링 프로세스:**
        /// ```
        /// 1. drawable 가져오기 (렌더링 대상)
        ///      ↓
        /// 2. renderer 설정 (layoutMode, focusedPosition)
        ///      ↓
        /// 3. syncController.getSynchronizedFrames() → 동기화된 프레임 가져오기
        ///      ↓
        /// 4. renderer.render(frames, to: drawable) → Metal 렌더링
        ///      ↓
        /// 5. drawable.present() → 화면에 표시 (vsync 동기화)
        /// ```
        func draw(in view: MTKView) {
            /// drawable과 renderer 존재 확인
            ///
            /// ## guard let drawable, renderer
            /// - drawable: 렌더링 결과를 저장할 버퍼
            /// - renderer: Metal 렌더링 엔진
            /// - 둘 중 하나라도 nil이면 렌더링 스킵
            guard let drawable = view.currentDrawable,
                  let renderer = renderer else {
                debugLog("[MetalVideoView] Draw skipped: drawable or renderer is nil")
                return
            }

            /// Renderer 설정 업데이트
            ///
            /// ## setLayoutMode, setFocusedPosition
            /// - 현재 레이아웃 모드를 renderer에 전달
            /// - Metal Shader가 이 설정을 읽어 렌더링
            renderer.setLayoutMode(layoutMode)
            renderer.setFocusedPosition(focusedPosition)

            /// 동기화된 프레임 가져오기
            ///
            /// ## getSynchronizedFrames()
            /// - 4개 채널의 현재 시간 프레임 반환
            /// - [FrontFrame, RearFrame, LeftFrame, RightFrame]
            let frames = syncController.getSynchronizedFrames()

            /// 프레임 없으면 렌더링 스킵
            ///
            /// ## frames.isEmpty
            /// - 비디오 로드 전
            /// - 디코딩 지연
            /// - EOF 도달
            if frames.isEmpty {
                // No frames available yet, just return (black screen will be shown)
                return
            }

            debugLog("[MetalVideoView] Rendering \(frames.count) frames at time \(String(format: "%.2f", syncController.currentTime))")

            /// Metal 렌더링 수행
            ///
            /// ## renderer.render(frames:to:drawableSize:)
            /// - frames: 동기화된 프레임 배열
            /// - drawable: 렌더링 결과 저장 버퍼
            /// - drawableSize: 렌더링 크기
            ///
            /// **렌더링 내부:**
            /// ```
            /// 1. 각 프레임을 Metal Texture로 변환
            ///      ↓
            /// 2. Vertex Shader 실행 (화면 좌표 계산)
            ///      ↓
            /// 3. Fragment Shader 실행 (픽셀 색상 계산)
            ///      ↓ Brightness, Zoom, Flip 적용
            /// 4. drawable.texture에 렌더링 결과 저장
            ///      ↓
            /// 5. drawable.present() → 화면에 표시
            /// ```
            renderer.render(
                frames: frames,
                to: drawable,
                drawableSize: view.drawableSize
            )
        }
    }
}

// MARK: - Preview

// Preview temporarily disabled - requires sample data
// struct MultiChannelPlayerView_Previews: PreviewProvider {
//     static var previews: some View {
//         MultiChannelPlayerView(videoFile: sampleVideoFile)
//             .frame(width: 1280, height: 720)
//     }
// }
