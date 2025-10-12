/// @file VideoPlayerView.swift
/// @brief 메인 비디오 플레이어 View
/// @author BlackboxPlayer Development Team
/// @details 블랙박스 비디오를 재생하는 메인 플레이어 View를 구현합니다.
///          키보드 단축키, 전체화면 모드, 자동 컨트롤 숨김 기능을 제공합니다.

/*
 【VideoPlayerView 개요】

 이 파일은 블랙박스 비디오를 재생하는 메인 플레이어 View를 구현합니다.


 ┌──────────────────────────────────────────────────────┐
 │                                                      │
 │                                                      │
 │              📹 Video Display Area                   │ ← 비디오 프레임 표시
 │           (VideoFrameView)                           │
 │                                                      │
 │                                                      │
 ├──────────────────────────────────────────────────────┤
 │ ⏯️  ⏮️ ⏭️  [━━━━━━━━━━━━━━●─────]  2:34 / 5:00  🔊 │ ← 재생 컨트롤
 └──────────────────────────────────────────────────────┘
   (마우스 호버 시 표시, 3초 후 자동 숨김)


 【주요 기능】

 1. 비디오 재생
    - AVFoundation 기반 비디오 디코딩
    - 프레임별 렌더링
    - 다양한 코덱 지원

 2. 사용자 인터페이스
    - 마우스 호버 시 컨트롤 표시
    - 3초 후 자동 숨김 (재생 중일 때만)
    - 전체화면 모드

 3. 키보드 단축키
    - Space: 재생/일시정지
    - ←/→: 5초 앞뒤 이동
    - ↑/↓: 볼륨 조절
    - F: 전체화면 토글
    - ESC: 전체화면 종료

 4. 상태별 UI
    - 로딩 중: 스피너 표시
    - 에러 발생: 에러 메시지
    - 플레이스홀더: 비디오 없음


 【SwiftUI + AppKit 통합】

 이 파일은 SwiftUI와 macOS AppKit을 함께 사용합니다:

 **SwiftUI 사용:**
 - View 레이아웃과 렌더링
 - 상태 관리 (@State, @StateObject)
 - 애니메이션과 트랜지션

 **AppKit 사용:**
 - 키보드 이벤트 모니터링 (NSEvent)
 - 전체화면 윈도우 제어 (NSWindow)
 - 네이티브 macOS 기능 접근

 통합의 장점:
   ✓ SwiftUI의 선언적 UI
   ✓ AppKit의 강력한 시스템 접근
   ✓ 최고의 사용자 경험


 【MVVM 패턴】

 이 파일은 MVVM (Model-View-ViewModel) 패턴을 따릅니다:

 ```
 Model (VideoFile)
   ↓ 데이터
 ViewModel (VideoPlayerViewModel)
   ↓ 상태 & 비즈니스 로직
 View (VideoPlayerView)
   ↓ UI 렌더링
 ```

 역할 분담:
 - Model: 비디오 파일 데이터
 - ViewModel: 재생 로직, 상태 관리
 - View: UI 표시, 사용자 입력 전달


 【사용 예시】

 ```swift
 // 1. 단독으로 사용
 VideoPlayerView(videoFile: someVideoFile)

 // 2. Sheet로 표시
 .sheet(isPresented: $showPlayer) {
     VideoPlayerView(videoFile: selectedFile)
 }

 // 3. NavigationLink로 전환
 NavigationLink(destination: VideoPlayerView(videoFile: file)) {
     Text("Play Video")
 }
 ```


 【관련 파일】

 - VideoPlayerViewModel.swift: 재생 로직과 상태 관리
 - PlayerControlsView.swift: 재생 컨트롤 UI
 - VideoFrame.swift: 비디오 프레임 데이터 구조
 - VideoFile.swift: 비디오 파일 메타데이터

 */

import SwiftUI
import AppKit

/// @struct VideoPlayerView
/// @brief 메인 비디오 플레이어 View
/// @details 비디오 재생 기능을 제공하는 메인 플레이어입니다.
///          키보드 단축키, 전체화면 모드, 자동 컨트롤 숨김을 지원합니다.
///
/// **주요 기능:**
/// - 비디오 프레임 렌더링
/// - 재생 컨트롤 (자동 숨김)
/// - 키보드 단축키
/// - 전체화면 모드
///
/// **사용 예시:**
/// ```swift
/// VideoPlayerView(videoFile: selectedVideoFile)
/// ```
///
/// **연관 타입:**
/// - `VideoFile`: 재생할 비디오 파일
/// - `VideoPlayerViewModel`: 재생 로직 ViewModel
///
struct VideoPlayerView: View {
    // MARK: - Properties

    /// @var videoFile
    /// @brief 재생할 비디오 파일
    /// @details VideoFile 객체로 비디오 정보를 포함합니다.
    ///
    /// **let을 사용하는 이유:**
    ///
    /// 비디오 파일은 플레이어 생성 시 한 번 설정되고 변경되지 않습니다:
    ///   - 불변성 보장
    ///   - 의도 명확화
    ///   - 다른 비디오를 재생하려면 새 플레이어 생성
    ///
    let videoFile: VideoFile

    /// @var viewModel
    /// @brief 비디오 플레이어 ViewModel
    /// @details 비디오 재생 로직을 담당하는 ViewModel입니다.
    ///
    /// **@StateObject란?**
    ///
    /// @StateObject는 ObservableObject를 생성하고 소유하는 프로퍼티 래퍼입니다.
    ///
    /// **@StateObject vs @ObservedObject:**
    ///
    /// ```
    /// @StateObject:
    ///   - View가 객체를 생성하고 소유
    ///   - View가 재생성되어도 객체 유지
    ///   - 객체의 생명주기를 관리
    ///
    /// @ObservedObject:
    ///   - 외부에서 생성된 객체 관찰
    ///   - View가 재생성되면 객체도 재생성될 수 있음
    ///   - 생명주기를 관리하지 않음
    /// ```
    ///
    /// **왜 @StateObject를 사용하는가?**
    ///
    /// VideoPlayerViewModel은 이 View가 직접 생성하고 관리해야 합니다:
    ///   - 비디오 재생 상태는 View의 생명주기와 일치
    ///   - View가 사라지면 재생도 중지되어야 함
    ///   - View가 재렌더링되어도 재생 상태 유지
    ///
    /// **MVVM 패턴:**
    ///
    /// ```
    /// VideoPlayerView (View)
    ///       ↓ 사용자 입력 전달
    /// VideoPlayerViewModel (ViewModel)
    ///       ↓ 비즈니스 로직 실행
    ///       ↓ @Published 상태 변경
    ///       ↓
    /// VideoPlayerView 자동 재렌더링
    /// ```
    ///
    @StateObject private var viewModel = VideoPlayerViewModel()

    /// Controls visibility state
    ///
    /// 재생 컨트롤의 표시 여부를 저장합니다.
    ///
    /// **@State란?**
    ///
    /// @State는 View 내부 상태를 저장하는 프로퍼티 래퍼입니다.
    ///
    /// **작동 원리:**
    /// ```
    /// 마우스 호버
    ///     ↓
    /// showControls = true
    ///     ↓
    /// SwiftUI가 변경 감지
    ///     ↓
    /// View 재렌더링
    ///     ↓
    /// PlayerControlsView 표시
    /// ```
    ///
    /// **기본값이 true인 이유:**
    ///
    /// 플레이어가 처음 열리면:
    ///   - 사용자가 컨트롤을 봐야 함
    ///   - 재생 버튼을 찾을 수 있어야 함
    ///   - 3초 후 자동으로 숨겨짐
    ///
    @State private var showControls = true

    /// Timer for auto-hiding controls
    ///
    /// 컨트롤을 자동으로 숨기기 위한 타이머입니다.
    ///
    /// **Timer?란?**
    ///
    /// Optional<Timer> 타입입니다:
    ///   - nil: 타이머가 없음 (일시정지 상태 등)
    ///   - Timer: 활성 타이머
    ///
    /// **타이머 작동 원리:**
    ///
    /// ```
    /// 1. 마우스 호버 또는 컨트롤 사용
    ///    ↓
    /// 2. resetControlsTimer() 호출
    ///    ↓
    /// 3. 기존 타이머 취소 (있다면)
    ///    ↓
    /// 4. 새 타이머 생성 (3초 후 실행)
    ///    ↓
    /// 5. 3초 경과
    ///    ↓
    /// 6. showControls = false (컨트롤 숨김)
    /// ```
    ///
    /// **왜 Optional인가?**
    ///
    /// 모든 상황에서 타이머가 필요한 것은 아닙니다:
    ///   - 일시정지 중: 타이머 불필요 (컨트롤 계속 표시)
    ///   - 재생 중: 타이머 필요 (3초 후 숨김)
    ///
    @State private var controlsTimer: Timer?

    /// Fullscreen state
    ///
    /// 전체화면 모드 여부를 저장합니다.
    ///
    /// **전체화면 모드:**
    ///
    /// false (일반 모드):
    ///   - 윈도우 타이틀 바 있음
    ///   - 메뉴 바 표시
    ///   - 크기 조절 가능
    ///
    /// true (전체화면 모드):
    ///   - 전체 화면 차지
    ///   - 타이틀 바/메뉴 바 숨김
    ///   - 몰입 경험
    ///
    @State private var isFullscreen = false

    /// Keyboard event monitor
    ///
    /// 키보드 이벤트를 감지하는 모니터입니다.
    ///
    /// **Any? 타입이란?**
    ///
    /// NSEvent.addLocalMonitorForEvents는 Any? 타입을 반환합니다:
    ///   - 실제로는 특별한 모니터 객체
    ///   - removeMonitor()로 제거할 때 필요
    ///   - 타입이 불분명하므로 Any로 저장
    ///
    /// **키보드 모니터링:**
    ///
    /// ```
    /// 1. setupKeyboardMonitor() 호출
    ///    ↓
    /// 2. NSEvent.addLocalMonitorForEvents 등록
    ///    ↓
    /// 3. 사용자가 키 입력
    ///    ↓
    /// 4. handleKeyEvent() 자동 호출
    ///    ↓
    /// 5. 키 코드에 따라 동작 실행
    /// ```
    ///
    /// **생명주기 관리:**
    ///
    /// ```
    /// onAppear:
    ///   → setupKeyboardMonitor() (모니터 등록)
    ///
    /// onDisappear:
    ///   → removeKeyboardMonitor() (모니터 제거)
    /// ```
    ///
    /// 모니터를 제거하지 않으면:
    ///   - 메모리 누수 발생
    ///   - 플레이어가 닫혀도 키 입력 계속 감지
    ///   - 앱 성능 저하
    ///
    @State private var keyMonitor: Any?

    // MARK: - Body

    var body: some View {
        // **VStack으로 비디오와 컨트롤 배치:**
        //
        // VStack(spacing: 0):
        //   - 비디오 영역과 컨트롤 영역을 세로로 배치
        //   - spacing: 0 → 간격 없이 딱 붙임
        //
        // 레이아웃:
        // ```
        // ┌─────────────────────┐
        // │                     │
        // │   Video Display     │ ← 가변 크기 (maxHeight: .infinity)
        // │                     │
        // ├─────────────────────┤ ← 간격 0
        // │ [Player Controls]   │ ← 고정 높이
        // └─────────────────────┘
        // ```
        //
        VStack(spacing: 0) {
            // MARK: Video Display Area

            // Video display area
            //
            // 비디오 프레임을 표시하는 영역입니다.
            //
            // videoDisplay는 아래에 정의된 computed property입니다.
            //
            videoDisplay
                // **.frame(maxWidth: .infinity, maxHeight: .infinity):**
                //
                // 가능한 모든 공간을 차지하도록 설정합니다.
                //
                // maxWidth: .infinity
                //   - 부모의 가로 폭 전체 사용
                //   - 윈도우 크기에 따라 자동 조정
                //
                // maxHeight: .infinity
                //   - 부모의 세로 높이 전체 사용
                //   - 컨트롤을 제외한 나머지 공간 모두 차지
                //
                // 결과:
                // ```
                // 작은 윈도우:
                // ┌────────┐
                // │ Video  │
                // └────────┘
                //
                // 큰 윈도우:
                // ┌────────────────────┐
                // │                    │
                // │       Video        │
                // │                    │
                // └────────────────────┘
                // ```
                //
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // **.background(Color.black):**
                //
                // 배경을 검은색으로 설정합니다.
                //
                // 검은 배경을 사용하는 이유:
                //   ✓ 비디오 플레이어의 표준 (YouTube, Netflix 등)
                //   ✓ 비디오가 화면보다 작을 때 주변이 어두움
                //   ✓ 몰입감 향상
                //   ✓ 레터박스(letterbox) 효과
                //
                // 레터박스 예시:
                // ```
                // ┌─────────────────────┐
                // │■■■■■■■■■■■■■■■■■■■■■│ ← 검은색 여백
                // │┌───────────────────┐│
                // ││   16:9 Video      ││
                // │└───────────────────┘│
                // │■■■■■■■■■■■■■■■■■■■■■│ ← 검은색 여백
                // └─────────────────────┘
                // ```
                //
                .background(Color.black)

                // **.onHover { isHovering in ... }:**
                //
                // 마우스 호버 상태를 감지하는 모디파이어입니다.
                //
                // **작동 원리:**
                //
                // ```
                // 마우스가 비디오 영역으로 들어옴
                //     ↓
                // onHover 클로저 호출 (isHovering = true)
                //     ↓
                // showControls = true (컨트롤 표시)
                //     ↓
                // resetControlsTimer() (3초 타이머 시작)
                // ```
                //
                // ```
                // 마우스가 비디오 영역을 벗어남
                //     ↓
                // onHover 클로저 호출 (isHovering = false)
                //     ↓
                // 타이머가 계속 실행 중...
                //     ↓
                // 3초 후 showControls = false (컨트롤 숨김)
                // ```
                //
                // **왜 isHovering이 false일 때 컨트롤을 즉시 숨기지 않는가?**
                //
                // 사용자가 마우스를 약간 움직여도:
                //   - 컨트롤이 깜빡거리지 않음
                //   - 부드러운 사용자 경험
                //   - 타이머를 통한 지연 숨김
                //
                .onHover { isHovering in
                    if isHovering {
                        // 마우스가 들어오면 컨트롤 표시
                        showControls = true
                        // 타이머 재설정 (3초 카운트다운 다시 시작)
                        resetControlsTimer()
                    }
                }

            // MARK: Player Controls

            // Controls (shown at bottom)
            //
            // 재생 컨트롤을 조건부로 표시합니다.
            //
            // **조건부 렌더링:**
            //
            // if showControls:
            //   - showControls가 true일 때만 PlayerControlsView 렌더링
            //   - false이면 이 블록 전체가 렌더링 안 됨
            //
            // **PlayerControlsView:**
            //
            // 재생, 일시정지, 탐색, 볼륨 등의 컨트롤을 제공하는 별도의 View입니다.
            //
            // viewModel 전달:
            //   - PlayerControlsView가 viewModel의 메서드를 호출
            //   - 예: viewModel.play(), viewModel.pause() 등
            //
            if showControls {
                PlayerControlsView(viewModel: viewModel)
                    // **.transition(.move(edge: .bottom)):**
                    //
                    // 컨트롤이 나타나고 사라질 때의 애니메이션을 정의합니다.
                    //
                    // **.move(edge: .bottom):**
                    //   - 아래쪽에서 위로 슬라이드 인
                    //   - 위에서 아래로 슬라이드 아웃
                    //
                    // 애니메이션 효과:
                    // ```
                    // 컨트롤 표시 (showControls = true):
                    // ┌─────────────────┐
                    // │     Video       │
                    // ├─────────────────┤
                    // │ [Controls] ↑    │ ← 아래에서 위로 슬라이드
                    // └─────────────────┘
                    //
                    // 컨트롤 숨김 (showControls = false):
                    // ┌─────────────────┐
                    // │     Video       │
                    // └─────────────────┘
                    //   [Controls] ↓      ← 아래로 슬라이드 아웃
                    // ```
                    //
                    // **왜 애니메이션을 사용하는가?**
                    //
                    // ✓ 부드러운 전환
                    //   → 갑자기 나타나거나 사라지지 않음
                    //
                    // ✓ 시각적 피드백
                    //   → 사용자가 상태 변화를 인식
                    //
                    // ✓ 전문적인 느낌
                    //   → 완성도 높은 앱 경험
                    //
                    .transition(.move(edge: .bottom))
            }
        }
        // **.onAppear { ... }:**
        //
        // View가 화면에 나타날 때 실행되는 클로저입니다.
        //
        // **View 생명주기:**
        //
        // ```
        // 1. View 생성
        //    ↓
        // 2. body 렌더링
        //    ↓
        // 3. onAppear 실행 ← 여기
        //    ↓
        // 4. View 표시 중...
        //    ↓
        // 5. onDisappear 실행
        //    ↓
        // 6. View 제거
        // ```
        //
        // **이 코드의 onAppear에서 하는 일:**
        //
        .onAppear {
            // 1. 비디오 로드
            //
            // viewModel.loadVideo(videoFile):
            //   - VideoFile 데이터를 ViewModel에 전달
            //   - 비디오 디코더 초기화
            //   - 첫 프레임 로드
            //
            viewModel.loadVideo(videoFile)

            // 2. 컨트롤 타이머 시작
            //
            // resetControlsTimer():
            //   - 3초 후 컨트롤 자동 숨김 타이머 시작
            //   - 사용자가 컨트롤을 볼 시간 제공
            //
            resetControlsTimer()

            // 3. 키보드 모니터 설정
            //
            // setupKeyboardMonitor():
            //   - NSEvent 모니터 등록
            //   - 키보드 단축키 활성화
            //   - Space, 화살표, F, ESC 등 감지
            //
            setupKeyboardMonitor()
        }

        // **.onDisappear { ... }:**
        //
        // View가 화면에서 사라질 때 실행되는 클로저입니다.
        //
        // **정리 작업 (Cleanup):**
        //
        // onDisappear는 리소스 정리를 위해 매우 중요합니다.
        // 정리하지 않으면:
        //   - 메모리 누수
        //   - 백그라운드에서 계속 실행
        //   - 앱 성능 저하
        //
        .onDisappear {
            // 1. 비디오 재생 중지
            //
            // viewModel.stop():
            //   - 비디오 디코더 정지
            //   - 리소스 해제
            //   - 오디오 출력 중지
            //
            viewModel.stop()

            // 2. 타이머 무효화
            //
            // controlsTimer?.invalidate():
            //   - 타이머 취소
            //   - 메모리 해제
            //   - ?.는 Optional chaining (nil이면 무시)
            //
            controlsTimer?.invalidate()

            // 3. 키보드 모니터 제거
            //
            // removeKeyboardMonitor():
            //   - NSEvent 모니터 등록 해제
            //   - 메모리 누수 방지
            //   - 다른 View의 키보드 입력 방해 안 함
            //
            removeKeyboardMonitor()
        }
    }

    // MARK: - Video Display

    /// Video display area
    ///
    /// 비디오 프레임과 상태를 표시하는 영역입니다.
    ///
    /// **Computed Property란?**
    ///
    /// ```swift
    /// private var videoDisplay: some View {
    ///     // View를 반환
    /// }
    /// ```
    ///
    /// 저장하지 않고 매번 계산하여 반환합니다.
    ///
    /// **왜 Computed Property를 사용하는가?**
    ///
    /// ✓ body를 간결하게 유지
    ///   → body가 너무 길어지지 않음
    ///
    /// ✓ 재사용 가능
    ///   → 여러 곳에서 호출 가능 (현재는 한 곳)
    ///
    /// ✓ 가독성 향상
    ///   → videoDisplay라는 의미 있는 이름
    ///
    private var videoDisplay: some View {
        // **ZStack - 레이어 쌓기:**
        //
        // ZStack은 자식 View들을 Z축(깊이)으로 쌓습니다.
        //
        // Z축 순서 (뒤 → 앞):
        // ```
        // 1. 검은 배경 (기본)
        //    ↓
        // 2. VideoFrameView (프레임이 있으면)
        //    또는 ProgressView (버퍼링 중)
        //    또는 Error View (에러 발생)
        //    또는 Placeholder (비디오 없음)
        // ```
        //
        // **왜 ZStack을 사용하는가?**
        //
        // 여러 상태에 따라 다른 View를 같은 위치에 표시하기 위해:
        //   - 프레임 표시
        //   - 로딩 스피너
        //   - 에러 메시지
        //   - 플레이스홀더
        //
        // 모두 중앙에 표시되어야 하므로 ZStack이 적합합니다.
        //
        ZStack {
            // **상태에 따른 조건부 렌더링:**
            //
            // if-else if-else 체인으로 우선순위에 따라 하나만 표시합니다.

            // Case 1: Video frame available
            //
            // 비디오 프레임이 있으면 표시합니다.
            //
            // **Optional Binding:**
            //
            // if let frame = viewModel.currentFrame:
            //   - viewModel.currentFrame은 Optional<VideoFrame>
            //   - nil이 아니면 frame 변수에 언래핑된 값 저장
            //   - 블록 내에서 frame 사용 가능
            //
            if let frame = viewModel.currentFrame {
                // **VideoFrameView:**
                //
                // VideoFrame을 CGImage로 변환하여 화면에 표시하는 서브 View입니다.
                //
                // 작동 과정:
                // ```
                // VideoFrame (픽셀 데이터)
                //     ↓
                // frame.toCGImage() (CGImage 변환)
                //     ↓
                // Image(cgImage) (SwiftUI Image)
                //     ↓
                // 화면에 렌더링
                // ```
                //
                VideoFrameView(frame: frame)

            // Case 2: Buffering
            //
            // 버퍼링 중이면 로딩 스피너를 표시합니다.
            //
            // viewModel.isBuffering:
            //   - 비디오 데이터를 읽는 중
            //   - 네트워크 또는 디스크에서 로딩 중
            //   - 디코딩 준비 중
            //
            } else if viewModel.isBuffering {
                // **ProgressView:**
                //
                // macOS/iOS의 표준 로딩 인디케이터입니다.
                //
                // ProgressView("Loading..."):
                //   - 회전하는 스피너 + 텍스트
                //   - 시스템 기본 스타일
                //
                // macOS에서의 모양:
                // ```
                //     ⟳
                //  Loading...
                // ```
                //
                ProgressView("Loading...")
                    // 흰색 텍스트 (검은 배경에서 보이도록)
                    .foregroundColor(.white)

            // Case 3: Error
            //
            // 에러가 발생하면 에러 메시지를 표시합니다.
            //
            // **Optional Binding:**
            //
            // if let errorMessage = viewModel.errorMessage:
            //   - errorMessage가 nil이 아니면 (에러 있음)
            //   - 언래핑된 문자열을 errorMessage에 저장
            //   - 에러 UI 표시
            //
            } else if let errorMessage = viewModel.errorMessage {
                // **에러 UI:**
                //
                // 사용자 친화적인 에러 표시:
                //   - 아이콘 (경고 삼각형)
                //   - 제목 ("Error")
                //   - 상세 메시지 (errorMessage)
                //
                VStack(spacing: 16) {
                    // **경고 아이콘:**
                    //
                    // exclamationmark.triangle.fill:
                    //   - 채워진 경고 삼각형
                    //   - 보편적인 경고/오류 심볼
                    //
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))  // 큰 크기로 강조
                        .foregroundColor(.yellow)  // 노란색 경고

                    // **에러 제목:**
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.bold)

                    // **에러 상세 메시지:**
                    //
                    // errorMessage 예시:
                    //   - "Failed to load video file"
                    //   - "Unsupported codec"
                    //   - "File not found"
                    //
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)  // 부차적 색상
                        // **.multilineTextAlignment(.center):**
                        //
                        // 여러 줄 텍스트를 중앙 정렬합니다.
                        //
                        // 예시:
                        // ```
                        // Failed to decode video.
                        //    Codec not supported.
                        // ```
                        //
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)  // 전체 텍스트 흰색
                .padding()  // 여백 추가

            // Case 4: Placeholder
            //
            // 그 외의 경우 (비디오 없음) 플레이스홀더를 표시합니다.
            //
            // 이 경우는 언제 발생하는가?
            //   - 비디오가 아직 로드되지 않음
            //   - 로드 완료되었지만 프레임이 없음
            //   - 초기 상태
            //
            } else {
                // **플레이스홀더 UI:**
                //
                // 비디오가 없음을 나타내는 기본 UI:
                //   - 비디오 아이콘
                //   - "No video loaded" 메시지
                //
                VStack(spacing: 16) {
                    // **비디오 아이콘:**
                    //
                    // video.fill:
                    //   - 채워진 비디오 카메라 아이콘
                    //   - "비디오"를 상징하는 일반적인 심볼
                    //
                    Image(systemName: "video.fill")
                        .font(.system(size: 64))  // 매우 큰 크기
                        .foregroundColor(.secondary)  // 연한 회색

                    Text("No video loaded")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Reset controls auto-hide timer
    ///
    /// 컨트롤 자동 숨김 타이머를 재설정합니다.
    ///
    /// **작동 원리:**
    ///
    /// 1. 기존 타이머 취소 (있다면)
    /// 2. 재생 중이면 새 타이머 생성
    /// 3. 3초 후 컨트롤 숨김
    ///
    /// **언제 호출되는가?**
    ///
    /// - 마우스 호버 시
    /// - 컨트롤 사용 시 (재생 버튼 클릭 등)
    /// - View가 나타날 때
    ///
    private func resetControlsTimer() {
        // **기존 타이머 무효화:**
        //
        // controlsTimer?.invalidate():
        //   - ?.는 Optional chaining
        //   - nil이 아니면 invalidate() 호출
        //   - 타이머 취소 및 메모리 해제
        //
        // 왜 기존 타이머를 취소하는가?
        //   - 사용자가 마우스를 계속 움직이면
        //   - 3초 카운트다운을 계속 재설정
        //   - 타이머가 여러 개 생기는 것을 방지
        //
        controlsTimer?.invalidate()

        // Auto-hide controls after 3 seconds of inactivity (only when playing)
        //
        // 재생 중일 때만 자동 숨김 타이머를 시작합니다.
        //
        // **왜 재생 중일 때만 숨기는가?**
        //
        // 일시정지 중:
        //   - 사용자가 컨트롤을 봐야 함
        //   - 다음 액션을 선택 중
        //   - 컨트롤을 계속 표시
        //
        // 재생 중:
        //   - 비디오 시청에 집중
        //   - 컨트롤이 방해됨
        //   - 3초 후 자동 숨김
        //
        if viewModel.playbackState == .playing {
            // **Timer.scheduledTimer:**
            //
            // 일정 시간 후 실행되는 타이머를 생성합니다.
            //
            // 파라미터:
            //   - withTimeInterval: 3.0 (3초)
            //   - repeats: false (한 번만 실행)
            //   - 클로저: { _ in ... } (실행할 코드)
            //
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                // **withAnimation:**
                //
                // 상태 변경을 애니메이션과 함께 수행합니다.
                //
                // withAnimation 없이:
                //   → showControls = false → 컨트롤이 즉시 사라짐
                //
                // withAnimation 있으면:
                //   → showControls = false → 컨트롤이 부드럽게 슬라이드 아웃
                //
                // .transition(.move(edge: .bottom))과 함께 작동:
                //   → 아래로 슬라이드하며 사라짐
                //
                withAnimation {
                    showControls = false
                }
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    /// Setup keyboard event monitor
    ///
    /// 키보드 이벤트 모니터를 설정합니다.
    ///
    /// **NSEvent란?**
    ///
    /// NSEvent는 macOS AppKit의 이벤트 시스템입니다.
    ///   - 키보드 입력
    ///   - 마우스 클릭
    ///   - 스크롤 등
    ///
    /// **Event Monitor:**
    ///
    /// 이벤트 모니터는 특정 이벤트를 "감청"합니다:
    ///   - 앱 전체의 이벤트 캐치
    ///   - 특정 이벤트만 필터링
    ///   - 이벤트 처리 후 전달 또는 차단
    ///
    private func setupKeyboardMonitor() {
        // **NSEvent.addLocalMonitorForEvents:**
        //
        // 로컬 이벤트 모니터를 등록합니다.
        //
        // **로컬 vs 글로벌 모니터:**
        //
        // 로컬 (Local):
        //   - 현재 앱 내의 이벤트만 감지
        //   - 다른 앱의 키 입력은 무시
        //   - 권한 필요 없음
        //
        // 글로벌 (Global):
        //   - 시스템 전체의 이벤트 감지
        //   - 다른 앱의 키 입력도 감지
        //   - Accessibility 권한 필요
        //
        // 파라미터:
        //   - matching: .keyDown (키를 눌렀을 때)
        //   - handler: 이벤트 처리 클로저
        //
        // 반환값:
        //   - Any? 타입의 모니터 객체
        //   - 나중에 removeMonitor()로 제거할 때 사용
        //
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // **[self] 캡처 리스트:**
            //
            // 클로저가 self를 캡처합니다.
            //
            // 일반적으로 [weak self]를 사용하지만:
            //   - 여기서는 [self]를 사용 (strong reference)
            //   - View가 살아있는 동안 모니터도 유지
            //   - onDisappear에서 명시적으로 제거
            //
            // 메모리 관리:
            // ```
            // View 생성
            //   ↓
            // setupKeyboardMonitor() (모니터 등록)
            //   ↓
            // View 살아있음 (모니터 활성)
            //   ↓
            // View 사라짐 (onDisappear)
            //   ↓
            // removeKeyboardMonitor() (모니터 제거)
            // ```
            //
            // **handleKeyEvent(event):**
            //
            // 실제 키 처리 로직은 별도 메서드로 분리되어 있습니다.
            //
            // 반환값:
            //   - NSEvent?: 처리된 이벤트 또는 nil
            //   - nil 반환 시 이벤트 소비 (다른 곳으로 전달 안 됨)
            //   - event 반환 시 이벤트 계속 전달
            //
            handleKeyEvent(event)
        }
    }

    /// Remove keyboard event monitor
    ///
    /// 키보드 이벤트 모니터를 제거합니다.
    ///
    /// **왜 모니터를 제거해야 하는가?**
    ///
    /// 제거하지 않으면:
    ///   - 메모리 누수 발생
    ///   - 플레이어가 닫혀도 키 입력 계속 감지
    ///   - 다른 View의 키보드 동작 방해
    ///   - 앱 성능 저하
    ///
    /// **생명주기:**
    ///
    /// ```
    /// onAppear:
    ///   → setupKeyboardMonitor() 호출
    ///
    /// onDisappear:
    ///   → removeKeyboardMonitor() 호출 ← 여기
    /// ```
    ///
    private func removeKeyboardMonitor() {
        // **Optional Binding:**
        //
        // if let monitor = keyMonitor:
        //   - keyMonitor가 nil이 아니면
        //   - monitor 변수에 언래핑된 값 저장
        //   - 블록 실행
        //
        if let monitor = keyMonitor {
            // **NSEvent.removeMonitor:**
            //
            // 등록된 이벤트 모니터를 제거합니다.
            //
            // 파라미터:
            //   - monitor: setupKeyboardMonitor()에서 반환받은 객체
            //
            NSEvent.removeMonitor(monitor)

            // **keyMonitor를 nil로 설정:**
            //
            // 모니터를 제거한 후 nil로 설정합니다.
            //
            // 이유:
            //   - 이미 제거된 모니터를 다시 제거하지 않도록
            //   - Optional 상태를 정확히 반영
            //   - 메모리 해제 확인
            //
            keyMonitor = nil
        }
    }

    /// Handle keyboard event
    ///
    /// 키보드 이벤트를 처리하고 적절한 동작을 실행합니다.
    ///
    /// **파라미터:**
    /// - event: NSEvent 객체 (키 정보 포함)
    ///
    /// **반환값:**
    /// - NSEvent?: 이벤트를 계속 전달할지 결정
    ///   - nil: 이벤트 소비 (더 이상 전달 안 됨)
    ///   - event: 이벤트 계속 전달
    ///
    /// **지원하는 단축키:**
    ///
    /// | 키         | 기능            | 동작                |
    /// |-----------|----------------|---------------------|
    /// | Space     | 재생/일시정지   | togglePlayPause()   |
    /// | ←         | 5초 뒤로        | seekBySeconds(-5.0) |
    /// | →         | 5초 앞으로      | seekBySeconds(5.0)  |
    /// | ↑         | 볼륨 up         | adjustVolume(+0.1)  |
    /// | ↓         | 볼륨 down       | adjustVolume(-0.1)  |
    /// | F         | 전체화면 토글   | toggleFullscreen()  |
    /// | ESC       | 전체화면 종료   | toggleFullscreen()  |
    ///
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Get the key code
        //
        // **키 코드(Key Code)란?**
        //
        // macOS는 각 키에 고유한 숫자를 할당합니다:
        //   - 49: Space
        //   - 123: Left arrow (←)
        //   - 124: Right arrow (→)
        //   - 126: Up arrow (↑)
        //   - 125: Down arrow (↓)
        //   - 3: F 키
        //   - 53: ESC
        //
        // **왜 문자가 아닌 숫자를 사용하는가?**
        //
        // 키 코드는 물리적 키 위치를 나타냅니다:
        //   - 키보드 레이아웃에 독립적
        //   - 영어, 한글 등 입력 소스와 무관
        //   - 화살표, Space 등 특수 키도 처리 가능
        //
        let keyCode = event.keyCode

        // **switch문으로 키별 처리:**
        //
        // 각 키 코드에 대해 다른 동작을 실행합니다.
        //
        switch keyCode {
        case 49: // Space
            // **재생/일시정지 토글:**
            //
            // Space는 대부분의 비디오 플레이어에서 재생/일시정지를 담당합니다:
            //   - YouTube
            //   - VLC
            //   - QuickTime
            //   - Netflix
            //
            viewModel.togglePlayPause()
            // **return nil:**
            //
            // 이벤트를 소비합니다.
            //
            // nil을 반환하면:
            //   - Space 키가 다른 곳으로 전달되지 않음
            //   - 예: 텍스트 필드에 공백 입력 방지
            //
            return nil

        case 123: // Left arrow
            // **5초 뒤로 이동:**
            //
            // seekBySeconds(-5.0):
            //   - 현재 재생 위치에서 5초 뒤로
            //   - 음수 값 = 역방향
            //
            // 5초를 선택한 이유:
            //   - 너무 짧지 않음 (의미 있는 탐색)
            //   - 너무 길지 않음 (정밀한 탐색 가능)
            //   - 업계 표준 (YouTube 등)
            //
            viewModel.seekBySeconds(-5.0)
            return nil

        case 124: // Right arrow
            // **5초 앞으로 이동:**
            //
            // seekBySeconds(5.0):
            //   - 현재 재생 위치에서 5초 앞으로
            //   - 양수 값 = 정방향
            //
            viewModel.seekBySeconds(5.0)
            return nil

        case 126: // Up arrow
            // **볼륨 증가:**
            //
            // adjustVolume(by: 0.1):
            //   - 볼륨을 0.1 (10%) 증가
            //   - 0.0 (무음) ~ 1.0 (최대)
            //
            // 10%씩 조절하는 이유:
            //   - 세밀한 조절 가능
            //   - 10번 누르면 최대/최소
            //   - 사용자 친화적
            //
            viewModel.adjustVolume(by: 0.1)
            return nil

        case 125: // Down arrow
            // **볼륨 감소:**
            //
            // adjustVolume(by: -0.1):
            //   - 볼륨을 0.1 (10%) 감소
            //   - 음수 값 = 감소
            //
            viewModel.adjustVolume(by: -0.1)
            return nil

        case 3: // F key
            // **전체화면 토글:**
            //
            // F 키는 많은 비디오 플레이어에서 전체화면 단축키로 사용됩니다:
            //   - YouTube: F
            //   - VLC: F
            //   - QuickTime: Cmd+Ctrl+F (하지만 F도 지원)
            //
            toggleFullscreen()
            return nil

        case 53: // ESC
            // **전체화면 종료:**
            //
            // ESC는 일반적으로 "종료" 또는 "취소"를 의미합니다.
            //
            // 조건부 처리:
            //   - 전체화면 모드일 때만 처리
            //   - 일반 모드에서는 이벤트 전달 (다른 용도로 사용 가능)
            //
            if isFullscreen {
                toggleFullscreen()
                return nil  // 이벤트 소비
            }
            // **ESC를 전체화면 종료 외에 다른 용도로 사용할 수 있도록:**
            //
            // 전체화면이 아니면 이벤트를 계속 전달합니다.
            // 예: Sheet나 Alert를 닫는 데 사용

        default:
            // **처리하지 않는 키:**
            //
            // 위의 case에 해당하지 않는 모든 키는 여기로 옵니다.
            //
            // break:
            //   - 아무것도 하지 않음
            //   - 다음 코드로 진행 (return event)
            //
            break
        }

        // **이벤트 계속 전달:**
        //
        // return event:
        //   - 처리하지 않은 이벤트를 다음 핸들러로 전달
        //   - 예: 텍스트 입력, 다른 단축키 등
        //
        return event
    }

    // MARK: - Fullscreen

    /// Toggle fullscreen mode
    ///
    /// 전체화면 모드를 토글합니다.
    ///
    /// **전체화면 모드란?**
    ///
    /// 일반 모드:
    ///   - 윈도우 타이틀 바 있음
    ///   - 메뉴 바 표시
    ///   - Dock 표시
    ///   - 크기 조절 가능
    ///
    /// 전체화면 모드:
    ///   - 전체 화면 차지
    ///   - 타이틀 바/메뉴 바 숨김
    ///   - Dock 자동 숨김
    ///   - 몰입 경험
    ///
    private func toggleFullscreen() {
        // **NSApplication.shared.keyWindow:**
        //
        // 현재 활성화된 윈도우를 가져옵니다.
        //
        // NSApplication.shared:
        //   - 앱의 싱글톤 인스턴스
        //   - 앱 전체 상태 관리
        //
        // keyWindow:
        //   - 현재 키보드 입력을 받는 윈도우
        //   - 일반적으로 사용자가 보고 있는 윈도우
        //
        // **guard let ... else { return }:**
        //
        // Optional Binding으로 안전하게 언래핑:
        //   - window가 nil이면 (윈도우 없음) return
        //   - nil이 아니면 계속 진행
        //
        guard let window = NSApplication.shared.keyWindow else { return }

        // **상태 토글:**
        //
        // isFullscreen.toggle():
        //   - true → false
        //   - false → true
        //
        // 상태를 먼저 토글하는 이유:
        //   - 다음 토글 호출 시 올바른 동작
        //   - UI 상태 동기화
        //
        isFullscreen.toggle()

        // **전체화면 전환:**
        //
        if isFullscreen {
            // **전체화면 모드로 전환:**
            //
            // window.toggleFullScreen(nil):
            //   - nil: sender 파라미터 (사용 안 함)
            //   - 윈도우를 전체화면으로 전환
            //   - 애니메이션과 함께 부드럽게 전환
            //
            // 효과:
            // ```
            // 일반 윈도우
            //     ↓
            // 화면 전체로 확대
            //     ↓
            // 타이틀 바/메뉴 바 숨김
            //     ↓
            // 전체화면 모드
            // ```
            //
            window.toggleFullScreen(nil)
        } else {
            // **일반 모드로 복귀:**
            //
            // 이미 전체화면인지 확인:
            //   - window.styleMask.contains(.fullScreen)
            //   - .fullScreen 플래그 체크
            //
            // 왜 확인하는가?
            //   - toggleFullScreen()을 중복 호출 방지
            //   - 애니메이션 충돌 방지
            //   - 안전한 상태 관리
            //
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
}

// MARK: - Video Frame View

/// @struct VideoFrameView
/// @brief 개별 비디오 프레임 표시 View
/// @details VideoFrame을 CGImage로 변환하여 화면에 표시합니다.
///
/// **역할:**
/// - VideoFrame (픽셀 데이터) → CGImage 변환
/// - CGImage → SwiftUI Image 표시
/// - 화면 크기에 맞게 조정
///
/// **사용 예시:**
/// ```swift
/// if let frame = viewModel.currentFrame {
///     VideoFrameView(frame: frame)
/// }
/// ```
///
struct VideoFrameView: View {
    // MARK: - Properties

    /// @var frame
    /// @brief 비디오 프레임 데이터
    /// @details 표시할 VideoFrame 객체입니다.
    ///
    /// **VideoFrame이란?**
    ///
    /// VideoFrame은 비디오의 한 프레임을 나타냅니다:
    /// ```swift
    /// struct VideoFrame {
    ///     let pixelBuffer: CVPixelBuffer  // 픽셀 데이터
    ///     let timestamp: CMTime           // 시간 정보
    ///     let width: Int                  // 가로 크기
    ///     let height: Int                 // 세로 크기
    ///
    ///     func toCGImage() -> CGImage? {
    ///         // CVPixelBuffer → CGImage 변환
    ///     }
    /// }
    /// ```
    ///
    let frame: VideoFrame

    // MARK: - Body

    var body: some View {
        // **GeometryReader:**
        //
        // GeometryReader는 부모로부터 할당받은 공간의 크기를 측정합니다.
        //
        // **왜 필요한가?**
        //
        // 비디오 프레임을 화면에 맞게 표시하려면:
        //   - 현재 화면(부모 View)의 크기를 알아야 함
        //   - 프레임의 가로세로 비율 유지
        //   - 화면 크기에 따라 조정
        //
        // **작동 원리:**
        //
        // ```
        // GeometryReader { geometry in
        //     // geometry.size.width
        //     // geometry.size.height
        //     // 부모로부터 할당받은 공간
        // }
        // ```
        //
        // **클로저 파라미터:**
        //
        // geometry: GeometryProxy
        //   - .size: 부모가 제공한 크기 (CGSize)
        //   - .frame(in:): 좌표계 내 위치
        //   - .safeAreaInsets: 안전 영역 정보
        //
        GeometryReader { geometry in
            // **Optional Binding:**
            //
            // if let cgImage = frame.toCGImage():
            //   - VideoFrame을 CGImage로 변환 시도
            //   - 성공하면 cgImage에 저장
            //   - 실패하면 (nil) else 블록 실행
            //
            // **변환 실패 사유:**
            //   - 픽셀 버퍼 형식 불일치
            //   - 메모리 부족
            //   - 손상된 프레임 데이터
            //
            if let cgImage = frame.toCGImage() {
                // **Image(decorative:scale:):**
                //
                // CGImage를 SwiftUI Image로 변환합니다.
                //
                // **decorative란?**
                //
                // Image(decorative: cgImage, scale: 1.0):
                //   - decorative: 접근성 레이블 없음
                //   - VoiceOver가 "이미지"라고 읽지 않음
                //   - 장식용 이미지로 간주
                //
                // 왜 decorative를 사용하는가?
                //   - 비디오 프레임은 연속적으로 빠르게 변경됨
                //   - 각 프레임을 읽으면 VoiceOver가 혼란스러움
                //   - 접근성 측면에서 불필요한 정보
                //
                // scale: 1.0:
                //   - 이미지 스케일 (Retina 디스플레이 등)
                //   - 1.0 = 1:1 픽셀 매핑
                //   - 2.0 = @2x (Retina)
                //
                Image(decorative: cgImage, scale: 1.0)
                    // **.resizable():**
                    //
                    // 이미지를 리사이즈 가능하게 만듭니다.
                    //
                    // resizable() 없이:
                    //   - 이미지가 원본 크기로 표시됨
                    //   - 화면보다 크거나 작을 수 있음
                    //   - 크기 조절 불가
                    //
                    // resizable() 있으면:
                    //   - .frame() 모디파이어로 크기 조절 가능
                    //   - aspectRatio()로 비율 유지 가능
                    //   - 화면에 맞게 조정 가능
                    //
                    .resizable()

                    // **.aspectRatio(contentMode:):**
                    //
                    // 이미지의 가로세로 비율을 유지하며 크기를 조절합니다.
                    //
                    // **contentMode: .fit:**
                    //
                    // .fit:
                    //   - 이미지 전체가 보이도록 조정
                    //   - 한쪽에 여백 생길 수 있음 (레터박스)
                    //   - 이미지 잘림 없음
                    //
                    // .fill:
                    //   - 공간을 전부 채움
                    //   - 이미지가 잘릴 수 있음
                    //   - 여백 없음
                    //
                    // 예시:
                    // ```
                    // 16:9 비디오를 4:3 화면에 표시
                    //
                    // .fit:
                    // ┌─────────────────┐
                    // │■■■■■■■■■■■■■■■■■│ ← 검은 여백
                    // │┌───────────────┐│
                    // ││   16:9 Video  ││
                    // │└───────────────┘│
                    // │■■■■■■■■■■■■■■■■■│ ← 검은 여백
                    // └─────────────────┘
                    //
                    // .fill:
                    // ┌─────────────────┐
                    // ││   16:9 Video  ││ ← 좌우가 잘림
                    // └─────────────────┘
                    // ```
                    //
                    .aspectRatio(contentMode: .fit)

                    // **.frame(width:height:):**
                    //
                    // 이미지를 특정 크기로 설정합니다.
                    //
                    // geometry.size.width:
                    //   - 부모(GeometryReader)가 제공한 가로 크기
                    //   - 화면 또는 윈도우 크기에 따라 변함
                    //
                    // geometry.size.height:
                    //   - 부모가 제공한 세로 크기
                    //
                    // 이 조합의 효과:
                    // ```
                    // resizable() + aspectRatio(.fit) + frame(geometry.size)
                    //     ↓
                    // 비디오가 화면 크기에 맞게 조정되되
                    //     ↓
                    // 가로세로 비율은 유지
                    // ```
                    //
                    .frame(width: geometry.size.width, height: geometry.size.height)

            } else {
                // **CGImage 변환 실패 시:**
                //
                // 검은 화면을 표시합니다.
                //
                // 검은 화면을 보여주는 이유:
                //   - 에러를 명시적으로 표시하지 않음 (프레임 단위 실패는 흔함)
                //   - 플레이어가 다음 프레임을 시도
                //   - 일시적인 문제일 수 있음
                //   - 사용자 경험 방해 최소화
                //
                Color.black
            }
        }
    }
}

// MARK: - Preview

// Preview temporarily disabled - requires sample data
//
// **프리뷰가 비활성화된 이유:**
//
// VideoPlayerView는 실제 VideoFile 데이터가 필요합니다:
//   - 비디오 디코더 초기화
//   - AVFoundation 리소스
//   - 실제 비디오 파일 경로
//
// Xcode 프리뷰에서는:
//   - 샘플 데이터 준비가 복잡
//   - 리소스 접근 제한
//   - 퍼포먼스 문제
//
// **프리뷰를 활성화하려면:**
//
// 1. 샘플 VideoFile 준비
// 2. 간단한 테스트 비디오 파일 포함
// 3. Mock VideoPlayerViewModel 사용
//
// 예시:
// ```swift
// struct VideoPlayerView_Previews: PreviewProvider {
//     static var previews: some View {
//         VideoPlayerView(videoFile: .testVideo)
//             .frame(width: 800, height: 600)
//     }
// }
// ```
//
// struct VideoPlayerView_Previews: PreviewProvider {
//     static var previews: some View {
//         VideoPlayerView(videoFile: sampleVideoFile)
//             .frame(width: 800, height: 600)
//     }
// }
