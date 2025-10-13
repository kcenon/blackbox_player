/// @file PlayerControlsView.swift
/// @brief 비디오 플레이어의 재생 컨트롤 UI
/// @author BlackboxPlayer Development Team
/// @details
/// 비디오 플레이어의 재생 컨트롤을 제공하는 View입니다. 타임라인 슬라이더, 재생/일시정지,
/// 프레임 단위 이동, 시간 표시, 속도 조절, 볼륨 조절 기능을 포함합니다.

import SwiftUI

/// @struct PlayerControlsView
/// @brief 비디오 플레이어의 재생 컨트롤을 제공하는 View
///
/// @details
/// 비디오 플레이어의 재생 컨트롤을 제공하는 View입니다.
///
/// ## 기능 개요
/// ```
/// ┌──────────────────────────────────────────────────────┐
/// │  [========●================]  (타임라인 슬라이더)      │
/// │                                                       │
/// │  ▶  ⏮  ⏭     00:05 / 01:30    🏎 1.0x   🔊 ━━━━━    │
/// │  재생  프레임     시간 표시      속도     볼륨        │
/// └──────────────────────────────────────────────────────┘
/// ```
///
/// ## 주요 컴포넌트
/// - **타임라인 슬라이더**: 커스텀 드래그 제스처로 구현된 시간 탐색 바
/// - **재생 컨트롤**: 재생/일시정지, 프레임 단위 이동 버튼
/// - **시간 표시**: 현재 시간 / 전체 시간 (monospaced 폰트)
/// - **속도 조절**: Menu 컴포넌트로 재생 속도 선택 (0.5x ~ 2.0x)
/// - **볼륨 조절**: Slider 컴포넌트로 음량 조절 (0 ~ 1)
///
/// ## SwiftUI 핵심 개념
///
/// ### 1. @ObservedObject vs @State 역할 분리
/// ```swift
/// @ObservedObject var viewModel: VideoPlayerViewModel  // 외부 데이터 소스
/// @State private var isSeeking: Bool = false           // 내부 UI 상태
/// ```
///
/// **@ObservedObject (외부 상태):**
/// - ViewModel에서 관리하는 비디오 재생 상태
/// - 예: playbackState, playbackPosition, volume
/// - 다른 View와 공유됨
///
/// **@State (내부 상태):**
/// - 이 View에서만 사용하는 임시 UI 상태
/// - 예: isSeeking (드래그 중 여부), seekPosition (드래그 위치)
/// - 다른 View와 공유되지 않음
///
/// ### 2. GeometryReader로 동적 크기 계산
/// ```swift
/// GeometryReader { geometry in
///     // geometry.size.width를 사용해 슬라이더 크기 계산
///     let thumbX = geometry.size.width * playbackPosition - 8
/// }
/// ```
///
/// **GeometryReader란?**
/// - 부모 View의 크기와 위치 정보를 제공하는 컨테이너
/// - 자식 View가 동적으로 크기를 계산할 수 있게 해줌
/// - 타임라인 슬라이더처럼 화면 크기에 따라 길이가 변하는 UI에 필수
///
/// ### 3. DragGesture로 커스텀 슬라이더 구현
/// ```swift
/// .gesture(
///     DragGesture(minimumDistance: 0)
///         .onChanged { value in
///             // 드래그 중: 임시 위치 업데이트
///             isSeeking = true
///             seekPosition = value.location.x / geometry.size.width
///         }
///         .onEnded { _ in
///             // 드래그 끝: ViewModel에 최종 위치 전달
///             viewModel.seek(to: seekPosition)
///             isSeeking = false
///         }
/// )
/// ```
///
/// **DragGesture 작동 원리:**
/// 1. **onChanged**: 드래그 중 계속 호출됨 (손가락/마우스 이동 시마다)
/// 2. **onEnded**: 드래그가 끝났을 때 한 번 호출됨 (손가락/마우스 뗐을 때)
/// 3. **minimumDistance: 0**: 탭도 드래그로 인식 (클릭으로 위치 이동 가능)
///
/// **왜 isSeeking 상태가 필요한가?**
/// - 드래그 중에는 seekPosition을 표시
/// - 드래그 안 할 때는 viewModel.playbackPosition을 표시
/// - 이렇게 하면 드래그 중에도 부드럽게 UI가 움직임
///
/// ### 4. Binding(get:set:) 커스터마이징
/// ```swift
/// Slider(value: Binding(
///     get: { viewModel.volume },           // 값 읽기
///     set: { viewModel.setVolume($0) }     // 값 쓰기
/// ), in: 0...1)
/// ```
///
/// **Binding이란?**
/// - 양방향 데이터 바인딩을 제공하는 Property Wrapper
/// - Slider, TextField 등이 값을 읽고 쓸 수 있게 해줌
///
/// **왜 Binding(get:set:)을 사용하나?**
/// - 단순 @State는 직접 바인딩: `$volume`
/// - ViewModel의 메서드를 호출하려면: `Binding(get:set:)` 사용
/// - 이렇게 하면 값 변경 시 추가 로직 실행 가능 (예: 오디오 볼륨 설정)
///
/// ### 5. Menu 컴포넌트로 드롭다운 메뉴 구현
/// ```swift
/// Menu {
///     ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
///         Button(action: { viewModel.setPlaybackSpeed(speed) }) {
///             HStack {
///                 Text("\(speed)x")
///                 if speed == currentSpeed { Image(systemName: "checkmark") }
///             }
///         }
///     }
/// } label: {
///     Text("1.0x")
/// }
/// ```
///
/// **Menu 컴포넌트 구조:**
/// 1. **Menu { ... }**: 메뉴 항목들을 정의
/// 2. **label: { ... }**: 메뉴를 여는 버튼 UI
/// 3. **ForEach**: 배열을 순회하며 동적으로 메뉴 항목 생성
///
/// **id: \.self란?**
/// - ForEach는 각 항목을 구분할 ID가 필요
/// - `id: \.self`는 값 자체를 ID로 사용 (0.5, 0.75, 1.0 등)
/// - Double, String 등 Hashable 타입에서 사용 가능
///
/// ### 6. Computed Properties로 동적 아이콘
/// ```swift
/// private var playPauseIcon: String {
///     switch viewModel.playbackState {
///     case .stopped, .paused: return "play.fill"
///     case .playing: return "pause.fill"
///     }
/// }
///
/// private var volumeIcon: String {
///     if volume == 0 { return "speaker.slash.fill" }
///     else if volume < 0.33 { return "speaker.wave.1.fill" }
///     else if volume < 0.67 { return "speaker.wave.2.fill" }
///     else { return "speaker.wave.3.fill" }
/// }
/// ```
///
/// **Computed Properties란?**
/// - 저장하지 않고 계산해서 반환하는 속성
/// - 다른 속성(viewModel.playbackState)이 바뀌면 자동으로 재계산됨
/// - View의 body가 다시 그려질 때마다 호출됨
///
/// **왜 함수 대신 Computed Property를 사용하나?**
/// - 함수: `playPauseIcon()` - 호출할 때마다 괄호 필요
/// - Computed Property: `playPauseIcon` - 속성처럼 사용 (더 자연스러움)
///
/// ## 사용 예제
///
/// ### 예제 1: VideoPlayerView에서 사용
/// ```swift
/// struct VideoPlayerView: View {
///     @StateObject private var viewModel = VideoPlayerViewModel()
///
///     var body: some View {
///         VStack {
///             // 비디오 화면
///             VideoFrameView(frame: viewModel.currentFrame)
///
///             // 컨트롤 UI
///             PlayerControlsView(viewModel: viewModel)
///         }
///     }
/// }
/// ```
///
/// ### 예제 2: MultiChannelPlayerView에서 여러 플레이어 동시 사용
/// ```swift
/// struct MultiChannelPlayerView: View {
///     @StateObject private var frontViewModel = VideoPlayerViewModel()
///     @StateObject private var rearViewModel = VideoPlayerViewModel()
///
///     var body: some View {
///         VStack {
///             HStack {
///                 VideoFrameView(frame: frontViewModel.currentFrame)
///                 VideoFrameView(frame: rearViewModel.currentFrame)
///             }
///
///             // 전방 카메라 컨트롤
///             PlayerControlsView(viewModel: frontViewModel)
///
///             // 후방 카메라 컨트롤
///             PlayerControlsView(viewModel: rearViewModel)
///         }
///     }
/// }
/// ```
///
/// ## 실무 응용
///
/// ### 타임라인 슬라이더 정밀도 개선
/// ```swift
/// // 현재: 픽셀 단위 이동 (부정확할 수 있음)
/// let position = value.location.x / geometry.size.width
///
/// // 개선: 프레임 단위로 스냅
/// let totalFrames = viewModel.totalFrames
/// let framePosition = round(position * Double(totalFrames)) / Double(totalFrames)
/// seekPosition = framePosition
/// ```
///
/// ### 키보드 단축키 지원
/// ```swift
/// .onKeyPress(.space) {
///     viewModel.togglePlayPause()
///     return .handled
/// }
/// .onKeyPress(.leftArrow) {
///     viewModel.stepBackward()
///     return .handled
/// }
/// ```
///
/// ### 더블 탭으로 빠른 이동 (모바일)
/// ```swift
/// .gesture(
///     TapGesture(count: 2)
///         .onEnded { _ in
///             viewModel.seekBySeconds(10.0)  // 10초 앞으로
///         }
/// )
/// ```
///
/// ## 성능 최적화
///
/// ### 1. 드래그 중 ViewModel 업데이트 최소화
/// ```swift
/// // 나쁜 예: 드래그 중 계속 ViewModel 업데이트 (성능 저하)
/// .onChanged { value in
///     viewModel.seek(to: value.location.x / width)  // ❌ 너무 자주 호출
/// }
///
/// // 좋은 예: 드래그 중에는 로컬 상태만 업데이트
/// .onChanged { value in
///     isSeeking = true
///     seekPosition = value.location.x / width  // ✅ UI만 업데이트
/// }
/// .onEnded { _ in
///     viewModel.seek(to: seekPosition)  // ✅ 끝날 때만 ViewModel 업데이트
/// }
/// ```
///
/// ### 2. Monospaced 폰트로 시간 표시 깜빡임 방지
/// ```swift
/// Text(viewModel.currentTimeString)
///     .font(.system(.body, design: .monospaced))
///     // ✅ monospaced: 모든 숫자가 같은 너비 → 시간 변해도 레이아웃 안 변함
///     // ❌ 일반 폰트: "1"과 "0"의 너비가 달라 → 시간 변하면 UI 흔들림
/// ```
///
/// ## 테스트 데이터
///
/// ### Mock VideoPlayerViewModel 생성
/// ```swift
/// extension VideoPlayerViewModel {
///     static func mock() -> VideoPlayerViewModel {
///         let vm = VideoPlayerViewModel()
///         vm.playbackState = .paused
///         vm.playbackPosition = 0.3  // 30% 재생
///         vm.currentTimeString = "00:18"
///         vm.durationString = "01:00"
///         vm.playbackSpeed = 1.0
///         vm.volume = 0.7
///         return vm
///     }
/// }
/// ```
///
/// ### Preview 활성화
/// ```swift
/// struct PlayerControlsView_Previews: PreviewProvider {
///     static var previews: some View {
///         VStack {
///             // 재생 중 상태
///             PlayerControlsView(viewModel: {
///                 let vm = VideoPlayerViewModel.mock()
///                 vm.playbackState = .playing
///                 return vm
///             }())
///             .previewDisplayName("Playing")
///
///             // 일시정지 상태
///             PlayerControlsView(viewModel: {
///                 let vm = VideoPlayerViewModel.mock()
///                 vm.playbackState = .paused
///                 return vm
///             }())
///             .previewDisplayName("Paused")
///
///             // 음소거 상태
///             PlayerControlsView(viewModel: {
///                 let vm = VideoPlayerViewModel.mock()
///                 vm.volume = 0
///                 return vm
///             }())
///             .previewDisplayName("Muted")
///         }
///         .frame(height: 100)
///         .padding()
///     }
/// }
/// ```
///
struct PlayerControlsView: View {
    // MARK: - Properties

    /// @var viewModel
    /// @brief ViewModel 참조 (@ObservedObject)
    ///
    /// **@ObservedObject란?**
    /// - 외부에서 전달받은 ObservableObject를 관찰하는 Property Wrapper
    /// - ViewModel의 @Published 속성이 변경되면 자동으로 View 업데이트
    /// - 부모 View가 ViewModel의 생명주기를 관리함
    ///
    /// **@StateObject와의 차이:**
    /// ```
    /// @StateObject  → 이 View에서 ViewModel 생성 및 소유
    /// @ObservedObject → 부모 View에서 전달받은 ViewModel 사용
    /// ```
    ///
    /// **예제:**
    /// ```swift
    /// // 부모 View
    /// struct VideoPlayerView: View {
    ///     @StateObject private var viewModel = VideoPlayerViewModel()  // 생성
    ///
    ///     var body: some View {
    ///         PlayerControlsView(viewModel: viewModel)  // 전달
    ///     }
    /// }
    ///
    /// // 자식 View
    /// struct PlayerControlsView: View {
    ///     @ObservedObject var viewModel: VideoPlayerViewModel  // 수신
    /// }
    /// ```
    @ObservedObject var viewModel: VideoPlayerViewModel

    /// @var eventMarkers
    /// @brief 이벤트 마커 배열
    ///
    /// @details
    /// 타임라인에 표시될 이벤트 마커들입니다.
    /// GPS 데이터 분석으로 감지된 급가속, 급감속, 급회전 등의 이벤트를 표시합니다.
    var eventMarkers: [EventMarker] = []

    /// @var isSeeking
    /// @brief 시킹 중 여부 (@State)
    ///
    /// **언제 true가 되나?**
    /// - 사용자가 타임라인 슬라이더를 드래그하는 동안
    ///
    /// **언제 false가 되나?**
    /// - 드래그를 끝냈을 때 (onEnded)
    ///
    /// **왜 필요한가?**
    /// - 드래그 중에는 seekPosition 값을 표시
    /// - 드래그 안 할 때는 viewModel.playbackPosition 값을 표시
    /// - 이렇게 분리해야 드래그 중에도 UI가 부드럽게 움직임
    ///
    /// **예제 시나리오:**
    /// ```
    /// 1. 재생 중 (isSeeking = false)
    ///    → 슬라이더 위치 = viewModel.playbackPosition (자동 증가)
    ///
    /// 2. 사용자가 드래그 시작 (isSeeking = true)
    ///    → 슬라이더 위치 = seekPosition (드래그 위치)
    ///    → viewModel.playbackPosition은 무시됨
    ///
    /// 3. 드래그 끝 (isSeeking = false)
    ///    → viewModel.seek(to: seekPosition) 호출
    ///    → 다시 viewModel.playbackPosition 값 표시
    /// ```
    @State private var isSeeking: Bool = false

    /// @var seekPosition
    /// @brief 시킹 위치 (0.0 ~ 1.0) (@State)
    ///
    /// **값의 범위:**
    /// - 0.0: 비디오 시작 (0%)
    /// - 0.5: 비디오 중간 (50%)
    /// - 1.0: 비디오 끝 (100%)
    ///
    /// **언제 업데이트되나?**
    /// - DragGesture의 onChanged에서 드래그 위치에 따라 계산됨
    /// - 공식: `seekPosition = dragX / sliderWidth`
    ///
    /// **왜 Double 타입인가?**
    /// - CGFloat보다 Double이 더 정밀함 (비디오 시간 계산에 유리)
    /// - ViewModel의 seek(to:) 메서드도 Double을 받음
    ///
    /// **계산 예제:**
    /// ```swift
    /// // 슬라이더 너비: 400px
    /// // 드래그 위치: 120px
    /// seekPosition = 120.0 / 400.0 = 0.3  // 30% 위치
    ///
    /// // 비디오 길이: 60초
    /// seekTime = 0.3 * 60 = 18초
    /// ```
    @State private var seekPosition: Double = 0.0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // 타임라인 슬라이더
            //
            // 커스텀 드래그 제스처로 구현된 시간 탐색 바입니다.
            // GeometryReader를 사용해 슬라이더 너비를 동적으로 계산합니다.
            timelineSlider

            HStack(spacing: 20) {
                // 재생/일시정지 버튼
                //
                // togglePlayPause() 호출
                // 아이콘은 playbackState에 따라 변경됨
                playPauseButton

                // 프레임 단위 이동 버튼
                //
                // stepBackward(), stepForward() 호출
                // 정밀한 프레임 분석에 유용
                frameStepButtons

                // 이벤트 네비게이션 버튼
                //
                // 이전/다음 이벤트로 이동
                // 급가속, 급감속, 급회전 등의 이벤트 위치로 즉시 이동
                if !eventMarkers.isEmpty {
                    eventNavigationButtons
                }

                Spacer()

                // 시간 표시
                //
                // "00:18 / 01:00" 형식
                // monospaced 폰트로 깜빡임 방지
                timeDisplay

                Spacer()

                // 재생 속도 조절
                //
                // Menu 컴포넌트로 0.5x ~ 2.0x 선택
                // 현재 속도에 체크마크 표시
                speedControl

                // 볼륨 조절
                //
                // Slider 컴포넌트로 0 ~ 1 범위
                // Binding(get:set:)으로 커스터마이징
                volumeControl
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
        // ✅ opacity(0.95): 약간 투명하게 → 비디오가 살짝 비침 (macOS 스타일)
    }

    // MARK: - Timeline Slider

    /// @brief 타임라인 슬라이더
    ///
    /// ## 구조
    /// ```
    /// ┌──────────────────────────────────────┐
    /// │  [==========●==================]     │
    /// │   ^재생된 부분  ^Thumb  ^전체 트랙   │
    /// └──────────────────────────────────────┘
    /// ```
    ///
    /// ## 레이어 구조 (아래부터 위로)
    /// 1. **Track Background**: 회색 바탕 (전체 길이)
    /// 2. **Played Portion**: 파란색 바 (재생된 부분)
    /// 3. **Thumb**: 흰색 원 (현재 위치 표시)
    ///
    /// ## DragGesture 작동 방식
    ///
    /// ### 1. onChanged (드래그 중)
    /// ```swift
    /// .onChanged { value in
    ///     isSeeking = true
    ///     let x = value.location.x              // 드래그 X 좌표
    ///     let width = geometry.size.width       // 슬라이더 너비
    ///     seekPosition = max(0, min(1, x / width))  // 0~1 범위로 제한
    /// }
    /// ```
    ///
    /// **계산 과정:**
    /// ```
    /// 슬라이더 너비: 400px
    /// 드래그 X: 120px
    /// → seekPosition = 120 / 400 = 0.3 (30%)
    ///
    /// 드래그 X: -50px (슬라이더 왼쪽 밖)
    /// → seekPosition = max(0, -50 / 400) = 0.0 (0%)
    ///
    /// 드래그 X: 500px (슬라이더 오른쪽 밖)
    /// → seekPosition = min(1, 500 / 400) = 1.0 (100%)
    /// ```
    ///
    /// ### 2. onEnded (드래그 끝)
    /// ```swift
    /// .onEnded { _ in
    ///     viewModel.seek(to: seekPosition)  // ViewModel에 최종 위치 전달
    ///     isSeeking = false
    /// }
    /// ```
    ///
    /// ## minimumDistance: 0의 의미
    /// ```swift
    /// DragGesture(minimumDistance: 0)
    /// ```
    ///
    /// - **0**: 탭도 드래그로 인식 (클릭으로 즉시 이동 가능)
    /// - **기본값 (10)**: 10px 이상 드래그해야 인식
    ///
    /// **사용자 경험:**
    /// ```
    /// minimumDistance: 0  → 클릭만 해도 해당 위치로 이동 (YouTube 스타일)
    /// minimumDistance: 10 → 드래그해야만 이동 (실수 방지)
    /// ```
    ///
    /// ## Thumb 위치 계산
    /// ```swift
    /// .offset(x: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition) - 8)
    /// ```
    ///
    /// **왜 -8을 빼나?**
    /// - Thumb의 너비가 16px
    /// - 중앙 정렬하려면 반(8px)만큼 왼쪽으로 이동
    ///
    /// **계산 예제:**
    /// ```
    /// 슬라이더 너비: 400px
    /// playbackPosition: 0.3 (30%)
    /// Thumb 중심 X = 400 * 0.3 = 120px
    /// Thumb 왼쪽 X = 120 - 8 = 112px (중앙 정렬됨)
    /// ```
    private var timelineSlider: some View {
        VStack(spacing: 4) {
            /// 커스텀 슬라이더 with 프레임 마커
            ///
            /// GeometryReader를 사용해 부모 View의 너비를 얻습니다.
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 트랙 배경 (회색 바탕)
                    //
                    // 전체 비디오 길이를 나타내는 회색 바입니다.
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    // 재생된 부분 (파란색 바)
                    //
                    // 현재까지 재생된 부분을 파란색으로 표시합니다.
                    //
                    // **너비 계산:**
                    // - 드래그 중: geometry.size.width * seekPosition
                    // - 일반 재생: geometry.size.width * viewModel.playbackPosition
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition),
                            height: 4
                        )
                        .cornerRadius(2)

                    // 이벤트 마커들 (색상 코딩된 원)
                    //
                    // 급가속, 급감속, 급회전 등의 이벤트를 타임라인에 표시합니다.
                    // duration이 0보다 클 때만 표시 (비디오 로드됨)
                    if viewModel.duration > 0 {
                        ForEach(eventMarkers) { marker in
                            eventMarkerView(marker: marker, width: geometry.size.width)
                        }
                    }

                    // Thumb (흰색 원)
                    //
                    // 현재 재생 위치를 나타내는 원형 인디케이터입니다.
                    //
                    // **위치 계산:**
                    // 1. 기본 X = width * position
                    // 2. 중앙 정렬 = X - (thumbWidth / 2) = X - 8
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(
                            x: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition) - 8
                        )
                }
                .gesture(
                    /// DragGesture로 슬라이더 드래그 구현
                    ///
                    /// **minimumDistance: 0의 효과:**
                    /// - 탭만 해도 해당 위치로 즉시 이동
                    /// - 드래그 없이 클릭만으로 시간 탐색 가능
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            /// 드래그 중 호출됨 (손가락/마우스 이동 시마다)
                            ///
                            /// **동작:**
                            /// 1. isSeeking = true (드래그 모드 활성화)
                            /// 2. seekPosition 계산 (0~1 범위로 제한)
                            isSeeking = true
                            let position = max(0, min(1, value.location.x / geometry.size.width))
                            seekPosition = position
                        }
                        .onEnded { _ in
                            /// 드래그 끝났을 때 호출됨 (손가락/마우스 뗐을 때)
                            ///
                            /// **동작:**
                            /// 1. ViewModel에 최종 위치 전달
                            /// 2. isSeeking = false (일반 모드로 복귀)
                            viewModel.seek(to: seekPosition)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 16)
            .padding(.horizontal)
        }
    }

    // MARK: - Play/Pause Button

    /// @brief 재생/일시정지 버튼
    ///
    /// ## 동작
    /// - 클릭 시: `viewModel.togglePlayPause()` 호출
    /// - 아이콘: `playPauseIcon` computed property에서 결정
    ///
    /// ## 상태별 아이콘
    /// ```
    /// .stopped, .paused → "play.fill"  (▶ 재생 아이콘)
    /// .playing         → "pause.fill" (❚❚ 일시정지 아이콘)
    /// ```
    ///
    /// ## .buttonStyle(.plain)의 효과
    /// ```swift
    /// // 기본 버튼 스타일
    /// Button { } → 파란색 배경, 흰색 텍스트
    ///
    /// // .plain 스타일
    /// Button { }.buttonStyle(.plain) → 배경 없음, 아이콘만 표시
    /// ```
    ///
    /// ## .help() modifier
    /// ```swift
    /// .help("Pause")  // 마우스 오버 시 툴팁 표시
    /// ```
    ///
    /// **macOS 전용:**
    /// - macOS에서만 작동 (iOS에서는 무시됨)
    /// - 접근성(Accessibility)에도 도움이 됨
    private var playPauseButton: some View {
        Button(action: {
            viewModel.togglePlayPause()
        }) {
            Image(systemName: playPauseIcon)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .help(viewModel.playbackState == .playing ? "Pause" : "Play")
    }

    /// @brief 재생/일시정지 아이콘 (Computed Property)
    ///
    /// ## Computed Property란?
    /// - 저장하지 않고 계산해서 반환하는 속성
    /// - `viewModel.playbackState`가 변경되면 자동으로 재계산됨
    /// - View의 body가 다시 그려질 때마다 호출됨
    ///
    /// ## 왜 함수 대신 Computed Property를 사용하나?
    /// ```swift
    /// // 함수 방식
    /// func playPauseIcon() -> String { ... }
    /// Image(systemName: playPauseIcon())  // 괄호 필요
    ///
    /// // Computed Property 방식
    /// var playPauseIcon: String { ... }
    /// Image(systemName: playPauseIcon)  // 괄호 불필요 (더 자연스러움)
    /// ```
    ///
    /// ## SF Symbols 아이콘
    /// - **play.fill**: 채워진 재생 아이콘 (▶)
    /// - **pause.fill**: 채워진 일시정지 아이콘 (❚❚)
    /// - macOS/iOS에 기본 내장 (30,000개 이상)
    private var playPauseIcon: String {
        switch viewModel.playbackState {
        case .stopped, .paused:
            return "play.fill"
        case .playing:
            return "pause.fill"
        }
    }

    // MARK: - Frame Step Buttons

    /// @brief 프레임 단위 이동 버튼
    ///
    /// ## 기능
    /// - **이전 프레임**: `viewModel.stepBackward()` 호출
    /// - **다음 프레임**: `viewModel.stepForward()` 호출
    ///
    /// ## 사용 시나리오
    /// ```
    /// 1. 사고 순간 정밀 분석
    ///    → 프레임 단위로 넘기며 정확한 시점 파악
    ///
    /// 2. 번호판 확인
    ///    → 정지된 상태에서 한 프레임씩 넘기며 선명한 순간 찾기
    ///
    /// 3. 이벤트 시작점 찾기
    ///    → 충격 센서가 작동한 정확한 프레임 찾기
    /// ```
    ///
    /// ## SF Symbols 아이콘
    /// - **backward.frame.fill**: 이전 프레임 (⏮)
    /// - **forward.frame.fill**: 다음 프레임 (⏭)
    ///
    /// ## HStack spacing: 8
    /// - 두 버튼 사이 간격 8px
    /// - 너무 붙어있지 않고 적당히 떨어짐
    private var frameStepButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                viewModel.stepBackward()
            }) {
                Image(systemName: "backward.frame.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Previous frame")

            Button(action: {
                viewModel.stepForward()
            }) {
                Image(systemName: "forward.frame.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Next frame")
        }
    }

    // MARK: - Event Navigation Buttons

    /// @brief 이벤트 네비게이션 버튼
    ///
    /// ## 기능
    /// - **이전 이벤트**: 현재 시간 이전의 가장 가까운 이벤트로 이동
    /// - **다음 이벤트**: 현재 시간 이후의 가장 가까운 이벤트로 이동
    ///
    /// ## 사용 시나리오
    /// ```
    /// 1. 급감속 이벤트 순회
    ///    → 다음 이벤트 버튼으로 모든 급감속 구간 확인
    ///
    /// 2. 사고 후 분석
    ///    → 사고 전후의 이벤트들을 빠르게 확인
    ///
    /// 3. 이벤트 비교
    ///    → 여러 이벤트를 연속으로 확인하며 패턴 분석
    /// ```
    ///
    /// ## SF Symbols 아이콘
    /// - **chevron.backward.circle.fill**: 이전 이벤트
    /// - **chevron.forward.circle.fill**: 다음 이벤트
    ///
    /// ## 색상
    /// - 주황색 배경: 이벤트 마커와 같은 계열
    /// - 흰색 아이콘: 명확한 대비
    private var eventNavigationButtons: some View {
        HStack(spacing: 8) {
            // 이전 이벤트
            Button(action: {
                seekToPreviousEvent()
            }) {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Previous event")
            .disabled(getPreviousEvent() == nil)

            // 다음 이벤트
            Button(action: {
                seekToNextEvent()
            }) {
                Image(systemName: "chevron.forward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Next event")
            .disabled(getNextEvent() == nil)
        }
    }

    // MARK: - Event Marker View

    /// @brief 이벤트 마커 뷰
    /// @param marker 이벤트 마커 데이터
    /// @param width 타임라인 전체 너비
    /// @return 마커 뷰
    ///
    /// @details
    /// 타임라인에 표시되는 개별 이벤트 마커입니다.
    ///
    /// ## 색상 코딩
    /// - 급감속 (hardBraking): 빨간색
    /// - 급가속 (rapidAcceleration): 주황색
    /// - 급회전 (sharpTurn): 노란색
    ///
    /// ## 크기
    /// - 직경: 10px
    /// - 강도(magnitude)에 따라 불투명도 조절
    private func eventMarkerView(marker: EventMarker, width: CGFloat) -> some View {
        // 마커 위치 계산
        let position = marker.timestamp / viewModel.duration
        let xOffset = width * position - 5  // 중앙 정렬 (-5 = 직경/2)

        // 이벤트 타입에 따른 색상
        let markerColor: Color = {
            switch marker.type {
            case .hardBraking:
                return .red
            case .rapidAcceleration:
                return .orange
            case .sharpTurn:
                return .yellow
            }
        }()

        return Circle()
            .fill(markerColor)
            .frame(width: 10, height: 10)
            .opacity(0.5 + marker.magnitude * 0.5)  // 강도에 따라 불투명도 조절
            .offset(x: xOffset, y: 0)
            .onTapGesture {
                // 마커 클릭 시 해당 시간으로 이동
                seekToEvent(marker)
            }
            .help("\(marker.displayName) - \(marker.timeString)")
    }

    // MARK: - Event Navigation Methods

    /// @brief 이전 이벤트 가져오기
    /// @return 이전 이벤트 마커 (없으면 nil)
    private func getPreviousEvent() -> EventMarker? {
        let currentTime = viewModel.currentTime
        // 현재 시간 이전의 이벤트들 중 가장 가까운 것
        return eventMarkers
            .filter { $0.timestamp < currentTime }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// @brief 다음 이벤트 가져오기
    /// @return 다음 이벤트 마커 (없으면 nil)
    private func getNextEvent() -> EventMarker? {
        let currentTime = viewModel.currentTime
        // 현재 시간 이후의 이벤트들 중 가장 가까운 것
        return eventMarkers
            .filter { $0.timestamp > currentTime }
            .min(by: { $0.timestamp < $1.timestamp })
    }

    /// @brief 이전 이벤트로 이동
    private func seekToPreviousEvent() {
        guard let event = getPreviousEvent() else { return }
        seekToEvent(event)
    }

    /// @brief 다음 이벤트로 이동
    private func seekToNextEvent() {
        guard let event = getNextEvent() else { return }
        seekToEvent(event)
    }

    /// @brief 특정 이벤트로 이동
    /// @param event 이동할 이벤트 마커
    private func seekToEvent(_ event: EventMarker) {
        viewModel.seek(to: event.timestamp / viewModel.duration)
    }

    // MARK: - Time Display

    /// @brief 시간 표시
    ///
    /// ## 표시 형식
    /// ```
    /// 00:18 / 01:00
    /// ^현재  ^전체
    /// ```
    ///
    /// ## Monospaced 폰트의 중요성
    /// ```swift
    /// .font(.system(.body, design: .monospaced))
    /// ```
    ///
    /// **일반 폰트 (Proportional):**
    /// ```
    /// "1"의 너비: 좁음
    /// "0"의 너비: 넓음
    /// → 시간이 바뀔 때마다 너비 변함 → UI 흔들림 ❌
    /// ```
    ///
    /// **Monospaced 폰트:**
    /// ```
    /// 모든 숫자의 너비: 동일
    /// → 시간이 바뀌어도 너비 일정 → UI 안정적 ✅
    /// ```
    ///
    /// **실제 예시:**
    /// ```
    /// 일반 폰트:
    /// 00:01 (좁음)
    /// 11:11 (넓음) → 너비 변화로 주변 UI 밀림
    ///
    /// Monospaced:
    /// 00:01 (고정)
    /// 11:11 (고정) → 너비 일정, UI 안정
    /// ```
    ///
    /// ## .foregroundColor(.secondary)
    /// - 전체 시간을 약간 어둡게 표시
    /// - 현재 시간(primary)보다 덜 중요함을 시각적으로 표현
    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Text(viewModel.currentTimeString)
                .font(.system(.body, design: .monospaced))

            Text("/")
                .foregroundColor(.secondary)

            Text(viewModel.durationString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Speed Control

    /// @brief 재생 속도 조절
    ///
    /// ## Menu 컴포넌트 구조
    /// ```swift
    /// Menu {
    ///     // 메뉴 항목들 (클릭 시 나타남)
    ///     Button("0.5x") { ... }
    ///     Button("0.75x") { ... }
    /// } label: {
    ///     // 메뉴를 여는 버튼 (항상 보임)
    ///     Text("1.0x")
    /// }
    /// ```
    ///
    /// ## ForEach로 동적 메뉴 생성
    /// ```swift
    /// ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
    ///     Button(action: { viewModel.setPlaybackSpeed(speed) }) {
    ///         HStack {
    ///             Text(String(format: "%.2fx", speed))
    ///             if abs(viewModel.playbackSpeed - speed) < 0.01 {
    ///                 Image(systemName: "checkmark")
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// **id: \.self의 의미:**
    /// - ForEach는 각 항목을 구분할 ID가 필요
    /// - `\.self`는 값 자체를 ID로 사용 (0.5, 0.75, 1.0 등)
    /// - Double은 Hashable이므로 ID로 사용 가능
    ///
    /// ## 체크마크 표시 로직
    /// ```swift
    /// if abs(viewModel.playbackSpeed - speed) < 0.01 {
    ///     Image(systemName: "checkmark")
    /// }
    /// ```
    ///
    /// **왜 abs()를 사용하나?**
    /// - Double 비교는 부동소수점 오차 때문에 ==를 쓰면 안 됨
    /// - 예: `1.0 == 1.0000000001` → false (오차)
    /// - 해결: `abs(1.0 - 1.0000000001) < 0.01` → true (충분히 가까움)
    ///
    /// ## String.format() 사용법
    /// ```swift
    /// String(format: "%.2fx", 0.5)   → "0.50x"
    /// String(format: "%.2fx", 1.0)   → "1.00x"
    /// String(format: "%.2fx", 1.25)  → "1.25x"
    ///
    /// // %.2f의 의미
    /// %     → 포맷 지정자 시작
    /// .2    → 소수점 이하 2자리
    /// f     → float/double 타입
    /// x     → 일반 텍스트 (속도 단위)
    /// ```
    ///
    /// ## .menuStyle(.borderlessButton)
    /// - macOS 전용 스타일
    /// - 버튼 테두리 없이 깔끔하게 표시
    private var speedControl: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: {
                    viewModel.setPlaybackSpeed(speed)
                }) {
                    HStack {
                        Text(String(format: "%.2fx", speed))
                        if abs(viewModel.playbackSpeed - speed) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge")
                Text(viewModel.playbackSpeedString)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
        .help("Playback speed")
    }

    // MARK: - Volume Control

    /// @brief 볼륨 조절
    ///
    /// ## Binding(get:set:) 패턴
    /// ```swift
    /// Slider(value: Binding(
    ///     get: { viewModel.volume },           // 값 읽기
    ///     set: { viewModel.setVolume($0) }     // 값 쓰기
    /// ), in: 0...1)
    /// ```
    ///
    /// ## Binding이란?
    /// - 양방향 데이터 바인딩을 제공하는 Property Wrapper
    /// - Slider, TextField 등이 값을 읽고 쓸 수 있게 해줌
    ///
    /// ## 왜 Binding(get:set:)을 사용하나?
    ///
    /// ### 방법 1: @State 직접 바인딩 (간단한 경우)
    /// ```swift
    /// @State private var volume: Double = 0.5
    /// Slider(value: $volume, in: 0...1)
    /// // ✅ 간단하지만, 값 변경 시 추가 로직 실행 불가
    /// ```
    ///
    /// ### 방법 2: Binding(get:set:) (추가 로직 필요한 경우)
    /// ```swift
    /// Slider(value: Binding(
    ///     get: { viewModel.volume },
    ///     set: { viewModel.setVolume($0) }  // 오디오 볼륨도 함께 설정
    /// ), in: 0...1)
    /// // ✅ 값 변경 시 setVolume() 메서드 호출 → 오디오 출력 조절
    /// ```
    ///
    /// ## setVolume(_:)에서 하는 일
    /// ```swift
    /// func setVolume(_ newVolume: Double) {
    ///     volume = newVolume                // 1. 프로퍼티 업데이트
    ///     audioPlayer.setVolume(newVolume)  // 2. 오디오 출력 조절
    ///     UserDefaults.save(volume: newVolume)  // 3. 설정 저장 (선택적)
    /// }
    /// ```
    ///
    /// ## HStack spacing: 8
    /// - 아이콘과 슬라이더 사이 간격 8px
    /// - 시각적으로 연결되어 보이면서도 붙지 않음
    ///
    /// ## .frame(width: 80)
    /// - 슬라이더 너비 고정
    /// - 볼륨 아이콘이 변해도 레이아웃 유지
    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Slider(value: Binding(
                get: { viewModel.volume },
                set: { viewModel.setVolume($0) }
            ), in: 0...1)
            .frame(width: 80)
        }
    }

    /// @brief 볼륨 아이콘 (Computed Property)
    ///
    /// ## 볼륨 레벨별 아이콘
    /// ```
    /// 볼륨 = 0.00       → "speaker.slash.fill"   (🔇 음소거)
    /// 볼륨 = 0.01~0.32  → "speaker.wave.1.fill"  (🔈 작음)
    /// 볼륨 = 0.33~0.66  → "speaker.wave.2.fill"  (🔉 중간)
    /// 볼륨 = 0.67~1.00  → "speaker.wave.3.fill"  (🔊 큼)
    /// ```
    ///
    /// ## 범위 분할 로직
    /// ```swift
    /// if volume == 0 { ... }         // 정확히 0
    /// else if volume < 0.33 { ... }  // 0.01 ~ 0.32
    /// else if volume < 0.67 { ... }  // 0.33 ~ 0.66
    /// else { ... }                   // 0.67 ~ 1.00
    /// ```
    ///
    /// **왜 1/3씩 나누나?**
    /// - 4단계로 나누면 사용자가 직관적으로 이해
    /// - 3개의 파동 아이콘 (1파, 2파, 3파)에 대응
    ///
    /// ## SF Symbols 스피커 아이콘
    /// - **speaker.slash.fill**: 빗금 그어진 스피커 (음소거)
    /// - **speaker.wave.1.fill**: 1개 파동 (작은 소리)
    /// - **speaker.wave.2.fill**: 2개 파동 (중간 소리)
    /// - **speaker.wave.3.fill**: 3개 파동 (큰 소리)
    ///
    /// ## .frame(width: 20)의 효과
    /// - 아이콘 너비를 20px로 고정
    /// - 아이콘이 바뀌어도 레이아웃이 흔들리지 않음
    ///
    /// **예시:**
    /// ```
    /// 아이콘 너비 고정 없이:
    /// 🔇 (좁음)
    /// 🔊 (넓음) → 아이콘 바뀔 때마다 슬라이더 위치 변함 ❌
    ///
    /// .frame(width: 20) 적용:
    /// 🔇 (20px)
    /// 🔊 (20px) → 항상 같은 너비, 슬라이더 위치 고정 ✅
    /// ```
    private var volumeIcon: String {
        if viewModel.volume == 0 {
            return "speaker.slash.fill"
        } else if viewModel.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if viewModel.volume < 0.67 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Preview

/// @brief Preview (temporarily disabled - requires sample data)
//
// Preview를 활성화하려면 다음과 같이 Mock ViewModel을 생성하세요:
//
// ```swift
// extension VideoPlayerViewModel {
//     static func mock() -> VideoPlayerViewModel {
//         let vm = VideoPlayerViewModel()
//         vm.playbackState = .paused
//         vm.playbackPosition = 0.3  // 30% 재생
//         vm.currentTimeString = "00:18"
//         vm.durationString = "01:00"
//         vm.playbackSpeed = 1.0
//         vm.volume = 0.7
//         return vm
//     }
// }
//
// struct PlayerControlsView_Previews: PreviewProvider {
//     static var previews: some View {
//         VStack(spacing: 20) {
//             // 재생 중 상태
//             PlayerControlsView(viewModel: {
//                 let vm = VideoPlayerViewModel.mock()
//                 vm.playbackState = .playing
//                 return vm
//             }())
//             .previewDisplayName("Playing")
//
//             // 일시정지 상태
//             PlayerControlsView(viewModel: {
//                 let vm = VideoPlayerViewModel.mock()
//                 vm.playbackState = .paused
//                 return vm
//             }())
//             .previewDisplayName("Paused")
//
//             // 음소거 상태
//             PlayerControlsView(viewModel: {
//                 let vm = VideoPlayerViewModel.mock()
//                 vm.volume = 0
//                 return vm
//             }())
//             .previewDisplayName("Muted")
//         }
//         .frame(height: 100)
//         .padding()
//     }
// }
// ```
//
// struct PlayerControlsView_Previews: PreviewProvider {
//     static var previews: some View {
//         PlayerControlsView(viewModel: VideoPlayerViewModel())
//             .frame(height: 100)
//     }
// }
