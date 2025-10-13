/// @file VideoPlayerViewModel.swift
/// @brief 비디오 플레이어 ViewModel
/// @author BlackboxPlayer Development Team
/// @details 비디오 플레이어의 상태와 재생 로직을 관리하는 ViewModel 클래스입니다.
///
/// ## MVVM 패턴이란?
/// Model-View-ViewModel 패턴은 UI(View)와 비즈니스 로직(ViewModel)을 분리하여 관리합니다.
///
/// ```
/// ┌─────────┐     @Published     ┌──────────────┐
/// │  Model  │ ──────────────────> │  ViewModel   │ (이 클래스)
/// │(데이터)  │                     │(비즈니스 로직)│
/// └─────────┘                     └──────────────┘
///                                        ↑ ↓ @Published
///                                  자동 업데이트 (Combine)
///                                        ↓ ↑
///                                 ┌──────────────┐
///                                 │     View     │
///                                 │     (UI)     │
///                                 └──────────────┘
/// ```
///
/// ## 주요 기능
/// - **비디오 로딩**: VideoFile → VideoDecoder 초기화 → 첫 프레임 로드
/// - **재생 제어**: play(), pause(), stop(), seek(), stepForward/Backward()
/// - **상태 관리**: playbackState, currentTime, playbackPosition, currentFrame 등 @Published로 자동 업데이트
/// - **오디오 동기화**: AudioPlayer와 연동하여 비디오/오디오 동기화 재생
/// - **타이머 기반 재생**: 프레임율(FPS)에 맞춰 주기적으로 프레임 디코딩
///
/// ## ObservableObject와 @Published란?
/// ### ObservableObject
/// - SwiftUI에서 관찰 가능한 객체를 정의하는 프로토콜
/// - @Published 속성이 변경되면 View에 자동으로 알림
///
/// ### @Published
/// - 속성 값이 변경될 때마다 SwiftUI에 알림
/// - View가 자동으로 재렌더링됨
///
/// **동작 흐름:**
/// ```swift
/// // ViewModel (이 클래스)
/// class VideoPlayerViewModel: ObservableObject {
///     @Published var currentTime: TimeInterval = 0.0  // 변경 감지
/// }
///
/// // View (SwiftUI)
/// struct PlayerView: View {
///     @ObservedObject var viewModel: VideoPlayerViewModel  // 관찰
///
///     var body: some View {
///         Text("\(viewModel.currentTime)")  // currentTime 변경 시 자동 재렌더링
///     }
/// }
///
/// // 동작 예시
/// viewModel.currentTime = 5.0  // 값 변경
///      ↓ @Published가 감지
/// Combine 프레임워크가 알림 전송
///      ↓
/// @ObservedObject가 알림 수신
///      ↓
/// View 자동 재렌더링 (Text가 "5.0"으로 업데이트)
/// ```
///
/// ## 재생 알고리즘
/// ### 타이머 기반 재생
/// ```
/// 1. play() 호출
///      ↓
/// 2. startPlaybackTimer() → Timer 생성
///      ↓ 주기: (1 / 프레임율) / 재생속도 초마다 실행
/// 3. updatePlayback() 반복 호출
///      ↓
/// 4. decoder.decodeNextFrame() → 다음 프레임 디코딩
///      ↓
/// 5. currentFrame, currentTime 업데이트 (@Published → View 자동 갱신)
///      ↓
/// 6. audioPlayer.enqueue(audioFrame) → 오디오 재생
///      ↓
/// 7. 파일 끝(EOF)에 도달하면 stop()
/// ```
///
/// **프레임율 계산 예시:**
/// ```swift
/// targetFrameRate = 30.0  // 30 FPS
/// playbackSpeed = 1.0     // 1배속
///
/// interval = (1.0 / 30.0) / 1.0 = 0.0333초 (약 33ms)
/// → 33ms마다 updatePlayback() 호출
///
/// playbackSpeed = 2.0     // 2배속
/// interval = (1.0 / 30.0) / 2.0 = 0.0167초 (약 17ms)
/// → 17ms마다 updatePlayback() 호출 (2배 빠름)
/// ```
///
/// ## Seek 알고리즘
/// ```
/// 1. seek(to: position) 호출
///      ↓ position을 0.0~1.0으로 clamp
/// 2. targetTime = position * duration 계산
///      ↓
/// 3. decoder.seek(to: targetTime) → 디코더 시크
///      ↓
/// 4. audioPlayer.flush() → 오디오 버퍼 비우기
///      ↓
/// 5. loadFrameAt(time:) → 해당 시간의 프레임 로드
///      ↓
/// 6. currentTime, playbackPosition 업데이트
/// ```
///
/// ## 사용 예시
/// ```swift
/// // 1. ViewModel 생성
/// let viewModel = VideoPlayerViewModel()
///
/// // 2. 비디오 로드
/// let videoFile = VideoFile(...)
/// viewModel.loadVideo(videoFile)
/// //   → decoder 초기화
/// //   → 첫 프레임 로드
/// //   → playbackState = .paused
///
/// // 3. 재생 시작
/// viewModel.play()
/// //   → playbackState = .playing
/// //   → Timer 시작 (프레임 단위로 updatePlayback 호출)
///
/// // 4. 특정 위치로 시크
/// viewModel.seek(to: 0.5)  // 50% 위치로 이동
/// //   → currentTime = duration * 0.5
/// //   → 해당 위치의 프레임 로드
///
/// // 5. 재생 속도 조절
/// viewModel.setPlaybackSpeed(2.0)  // 2배속
/// //   → Timer 간격 재조정 (2배 빠르게)
///
/// // 6. 일시정지
/// viewModel.pause()
/// //   → playbackState = .paused
/// //   → Timer 중지
///
/// // 7. 정지
/// viewModel.stop()
/// //   → playbackState = .stopped
/// //   → 모든 리소스 해제
/// ```
///
/// ## 실제 사용 시나리오
/// **시나리오 1: 비디오 로딩 및 재생**
/// ```
/// 1. loadVideo(videoFile) 호출
///      ↓
/// 2. VideoDecoder 초기화 (FFmpeg)
///      ↓
/// 3. 비디오 정보 가져오기 (duration, frameRate)
///      ↓
/// 4. AudioPlayer 초기화 (오디오 스트림 있을 경우)
///      ↓
/// 5. 첫 프레임 로드 (time: 0)
///      ↓
/// 6. playbackState = .paused (재생 준비 완료)
///      ↓ View에서 Play 버튼 활성화
/// 7. play() 호출 (사용자가 Play 버튼 클릭)
///      ↓
/// 8. Timer 시작 → 프레임 단위로 재생
/// ```
///
/// **시나리오 2: 특정 순간으로 이동 (Seek)**
/// ```
/// 1. 사용자가 타임라인 슬라이더를 드래그
///      ↓
/// 2. seek(to: 0.75) 호출 (75% 위치)
///      ↓
/// 3. targetTime = 90 * 0.75 = 67.5초 계산
///      ↓
/// 4. decoder.seek(to: 67.5) → FFmpeg seek 수행
///      ↓
/// 5. audioPlayer.flush() → 오디오 버퍼 비우기
///      ↓
/// 6. loadFrameAt(time: 67.5) → 67.5초의 프레임 디코딩
///      ↓
/// 7. currentTime = 67.5, playbackPosition = 0.75 업데이트
///      ↓ @Published → View 자동 갱신
/// 8. 타임라인 슬라이더가 75% 위치로 이동
/// ```
///
/// **시나리오 3: 프레임 단위 이동 (Step Forward)**
/// ```
/// 1. stepForward() 호출
///      ↓
/// 2. frameTime = 1.0 / 30.0 = 0.0333초 계산 (30 FPS)
///      ↓
/// 3. seekToTime(currentTime + frameTime) 호출
///      ↓ currentTime = 5.0초
/// 4. seekToTime(5.0333) → 다음 프레임으로 이동
///      ↓
/// 5. 해당 프레임 디코딩 및 표시
/// ```
//
//  VideoPlayerViewModel.swift
//  BlackboxPlayer
//
//  ViewModel for video player state management
//

import Foundation
import Combine
import SwiftUI

/// @class VideoPlayerViewModel
/// @brief 비디오 플레이어 상태 관리 ViewModel
/// @details MVVM 패턴을 사용하여 비디오 재생 로직과 상태를 관리합니다.
///
/// ## ObservableObject
/// - SwiftUI의 @ObservedObject, @StateObject와 함께 사용
/// - @Published 속성 변경 시 View에 자동 알림
///
/// **사용 예시:**
/// ```swift
/// struct PlayerView: View {
///     @StateObject private var viewModel = VideoPlayerViewModel()
///
///     var body: some View {
///         VStack {
///             // currentTime이 변경되면 자동으로 Text 업데이트
///             Text("\(viewModel.currentTimeString)")
///
///             Button("Play") {
///                 viewModel.play()  // 재생 시작
///             }
///         }
///     }
/// }
/// ```
class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties

    /// @var playbackState
    /// @brief 현재 재생 상태
    /// @details stopped, playing, paused 중 하나의 상태를 저장합니다.
    ///
    /// ## PlaybackState
    /// - .stopped: 정지 상태 (비디오 로드 전 또는 정지 후)
    /// - .playing: 재생 중 (Timer 동작 중)
    /// - .paused: 일시정지 (Timer 중지, 상태 유지)
    ///
    /// ## @Published
    /// - 값이 변경되면 View에 자동으로 알림
    /// - View가 재렌더링되어 UI 업데이트
    ///
    /// **상태 전환 예시:**
    /// ```
    /// loadVideo() → .paused   (로딩 완료, 재생 준비)
    /// play()      → .playing  (재생 시작)
    /// pause()     → .paused   (일시정지)
    /// stop()      → .stopped  (정지 및 리소스 해제)
    /// EOF 도달    → .stopped  (파일 끝)
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// if viewModel.playbackState == .playing {
    ///     Image(systemName: "pause.fill")  // 재생 중 → 일시정지 아이콘
    /// } else {
    ///     Image(systemName: "play.fill")   // 정지/일시정지 → 재생 아이콘
    /// }
    /// ```
    @Published var playbackState: PlaybackState = .stopped

    /// @var playbackPosition
    /// @brief 현재 재생 위치 (0.0 ~ 1.0)
    /// @details 비디오 재생 위치를 비율로 표현합니다.
    ///
    /// ## 비율 표현
    /// - 0.0: 시작 지점 (0%)
    /// - 0.5: 중간 지점 (50%)
    /// - 1.0: 끝 지점 (100%)
    ///
    /// ## 계산 공식
    /// ```swift
    /// playbackPosition = currentTime / duration
    /// ```
    ///
    /// **예시:**
    /// ```swift
    /// currentTime = 45초, duration = 90초
    /// playbackPosition = 45 / 90 = 0.5 (50%)
    ///
    /// currentTime = 90초, duration = 90초
    /// playbackPosition = 90 / 90 = 1.0 (100%)
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Slider(value: $viewModel.playbackPosition)  // 타임라인 슬라이더
    ///     .onChange(of: playbackPosition) { newValue in
    ///         viewModel.seek(to: newValue)  // 슬라이더 드래그 시 시크
    ///     }
    /// ```
    @Published var playbackPosition: Double = 0.0

    /// @var currentTime
    /// @brief 현재 재생 시간 (초 단위)
    /// @details Double 타입으로 소수점 이하 시간도 표현 가능합니다.
    ///
    /// ## TimeInterval
    /// - Double 타입 (소수점 가능)
    /// - 단위: 초 (seconds)
    ///
    /// **예시:**
    /// ```swift
    /// currentTime = 0.0    → 시작 지점
    /// currentTime = 45.5   → 45.5초 (0분 45.5초)
    /// currentTime = 125.0  → 125초 (2분 5초)
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Text(viewModel.currentTimeString)  // "02:05" 형태로 표시
    /// ```
    @Published var currentTime: TimeInterval = 0.0

    /// 전체 재생 시간 (초 단위)
    ///
    /// ## 비디오 길이
    /// - VideoDecoder.getDuration() 또는 VideoFile.duration에서 가져옴
    /// - 파일 전체 길이를 나타냄
    ///
    /// **예시:**
    /// ```swift
    /// duration = 90.0   → 1분 30초 길이 비디오
    /// duration = 600.0  → 10분 길이 비디오
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Text("\(viewModel.currentTimeString) / \(viewModel.durationString)")
    /// // "01:30 / 10:00" 형태로 표시
    /// ```
    @Published var duration: TimeInterval = 0.0

    /// @var currentFrame
    /// @brief 현재 비디오 프레임
    /// @details 디코딩된 VideoFrame 객체를 저장합니다.
    ///
    /// ## VideoFrame
    /// - 디코딩된 비디오 프레임 (이미지 + 타임스탬프)
    /// - updatePlayback()에서 decoder.decodeNextFrame()로 얻음
    ///
    /// ## Optional인 이유
    /// - 비디오 로드 전: nil
    /// - 디코딩 실패: nil
    /// - 정지 상태: nil
    ///
    /// **예시:**
    /// ```swift
    /// // 비디오 로드 전
    /// currentFrame = nil
    ///
    /// // 재생 중
    /// currentFrame = VideoFrame(image: CGImage(...), timestamp: 1.5)
    ///
    /// // View에서 사용
    /// if let frame = viewModel.currentFrame {
    ///     Image(frame.image, scale: 1.0, label: Text("Video"))
    /// }
    /// ```
    @Published var currentFrame: VideoFrame?

    /// 재생 속도 (0.5x ~ 4.0x)
    ///
    /// ## 배속
    /// - 0.5: 0.5배속 (느리게)
    /// - 1.0: 정상 속도 (기본)
    /// - 2.0: 2배속 (빠르게)
    ///
    /// ## 속도 조절 방식
    /// - Timer 간격을 조정하여 구현
    /// - interval = (1.0 / frameRate) / playbackSpeed
    ///
    /// **예시:**
    /// ```swift
    /// frameRate = 30.0, playbackSpeed = 1.0
    /// interval = (1.0 / 30.0) / 1.0 = 0.0333초 (33ms)
    ///
    /// frameRate = 30.0, playbackSpeed = 2.0
    /// interval = (1.0 / 30.0) / 2.0 = 0.0167초 (17ms) ← 2배 빠름
    ///
    /// frameRate = 30.0, playbackSpeed = 0.5
    /// interval = (1.0 / 30.0) / 0.5 = 0.0667초 (67ms) ← 2배 느림
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Menu {
    ///     Button("0.5x") { viewModel.setPlaybackSpeed(0.5) }
    ///     Button("1.0x") { viewModel.setPlaybackSpeed(1.0) }
    ///     Button("2.0x") { viewModel.setPlaybackSpeed(2.0) }
    /// } label: {
    ///     Text(viewModel.playbackSpeedString)  // "1.0x" 표시
    /// }
    /// ```
    @Published var playbackSpeed: Double = 1.0

    /// 음량 (0.0 ~ 1.0)
    ///
    /// ## 볼륨 범위
    /// - 0.0: 무음 (mute)
    /// - 0.5: 50% 볼륨
    /// - 1.0: 최대 볼륨 (100%)
    ///
    /// ## 오디오 플레이어 연동
    /// - audioPlayer.setVolume(Float(volume))로 전달
    ///
    /// **예시:**
    /// ```swift
    /// volume = 0.0   → audioPlayer.setVolume(0.0) → 무음
    /// volume = 0.75  → audioPlayer.setVolume(0.75) → 75% 볼륨
    /// volume = 1.0   → audioPlayer.setVolume(1.0) → 최대 볼륨
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Slider(value: $viewModel.volume, in: 0...1)
    ///     .onChange(of: volume) { newValue in
    ///         viewModel.setVolume(newValue)
    ///     }
    /// ```
    @Published var volume: Double = 1.0

    /// 버퍼링 중 여부
    ///
    /// ## 버퍼링 상태
    /// - true: 프레임 로딩 중 (loadFrameAt 실행 중)
    /// - false: 로딩 완료 또는 로딩 없음
    ///
    /// ## 사용 목적
    /// - UI에 로딩 인디케이터 표시
    /// - 시크 중임을 사용자에게 알림
    ///
    /// **동작 예시:**
    /// ```
    /// seekToTime(30.0) 호출
    ///      ↓
    /// isBuffering = true (버퍼링 시작)
    ///      ↓
    /// decoder.seek(to: 30.0) → FFmpeg seek 수행
    ///      ↓
    /// decoder.decodeNextFrame() → 프레임 디코딩
    ///      ↓
    /// isBuffering = false (버퍼링 완료)
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// if viewModel.isBuffering {
    ///     ProgressView()  // 로딩 인디케이터 표시
    /// }
    /// ```
    @Published var isBuffering: Bool = false

    /// 에러 메시지
    ///
    /// ## Optional인 이유
    /// - 에러 없음: nil
    /// - 에러 발생: 에러 메시지 문자열
    ///
    /// ## 에러 발생 시점
    /// - 비디오 로딩 실패
    /// - 디코딩 에러
    /// - 시크 실패
    ///
    /// **예시:**
    /// ```swift
    /// // 정상 상태
    /// errorMessage = nil
    ///
    /// // 에러 발생
    /// errorMessage = "Failed to load video: File not found"
    /// errorMessage = "Seek failed: Invalid timestamp"
    /// errorMessage = "Cannot play corrupted video file"
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// if let error = viewModel.errorMessage {
    ///     Text(error)
    ///         .foregroundColor(.red)  // 에러 메시지 빨간색 표시
    /// }
    /// ```
    @Published var errorMessage: String?

    /// 구간 시작점 (In Point)
    ///
    /// ## 구간 추출
    /// - 추출할 구간의 시작 시간 (초)
    /// - nil: 시작점 미설정
    /// - 0.0 ~ duration 범위
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.setInPoint()         // 현재 시간을 시작점으로
    /// viewModel.inPoint              // 5.0 (5초)
    /// viewModel.clearInPoint()       // nil로 초기화
    /// ```
    @Published var inPoint: TimeInterval?

    /// 구간 끝점 (Out Point)
    ///
    /// ## 구간 추출
    /// - 추출할 구간의 끝 시간 (초)
    /// - nil: 끝점 미설정
    /// - 0.0 ~ duration 범위
    /// - inPoint보다 커야 함
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.setOutPoint()        // 현재 시간을 끝점으로
    /// viewModel.outPoint             // 15.0 (15초)
    /// viewModel.clearOutPoint()      // nil로 초기화
    /// ```
    @Published var outPoint: TimeInterval?

    // MARK: - Private Properties

    /// 비디오 디코더 (FFmpeg wrapper)
    ///
    /// ## VideoDecoder
    /// - FFmpeg을 래핑한 비디오/오디오 디코더
    /// - 비디오 파일 디코딩, 시크, 프레임 추출 담당
    ///
    /// ## Optional인 이유
    /// - 비디오 로드 전: nil
    /// - 로딩 실패: nil
    /// - stop() 호출 시: nil로 초기화 (리소스 해제)
    private var decoder: VideoDecoder?

    /// 현재 로드된 비디오 파일 정보
    ///
    /// ## VideoFile
    /// - 파일 경로, 메타데이터, 채널 정보 등 포함
    /// - loadVideo()에서 전달받음
    ///
    /// ## 사용 목적
    /// - 비디오 정보 참조 (duration, channels 등)
    /// - 메타데이터 접근 (GPS, 가속도 데이터)
    /// - 구간 추출 시 채널 정보 접근
    ///
    /// ## 접근 제어
    /// - internal: PlayerControlsView에서 구간 추출 시 접근 필요
    var videoFile: VideoFile?

    /// 재생 타이머
    ///
    /// ## Timer
    /// - Foundation의 Timer 클래스
    /// - 일정 간격마다 updatePlayback() 호출
    ///
    /// ## 동작 원리
    /// ```
    /// startPlaybackTimer()
    ///      ↓
    /// Timer.scheduledTimer(withTimeInterval: 0.0333, repeats: true)
    ///      ↓ 33ms마다 반복 실행 (30 FPS)
    /// updatePlayback() 호출
    ///      ↓
    /// decoder.decodeNextFrame() → 프레임 디코딩
    ///      ↓
    /// currentFrame, currentTime 업데이트
    /// ```
    ///
    /// ## Optional인 이유
    /// - 정지/일시정지 상태: nil (타이머 없음)
    /// - 재생 중: Timer 객체 (타이머 동작)
    private var playbackTimer: Timer?

    /// 목표 프레임율 (FPS)
    ///
    /// ## 프레임율
    /// - VideoDecoder.videoInfo.frameRate에서 가져옴
    /// - 단위: fps (frames per second)
    ///
    /// **예시:**
    /// ```swift
    /// targetFrameRate = 30.0  → 30 FPS (1초에 30프레임)
    /// targetFrameRate = 60.0  → 60 FPS (1초에 60프레임)
    /// ```
    ///
    /// ## 사용 목적
    /// - Timer 간격 계산: interval = (1.0 / targetFrameRate) / playbackSpeed
    /// - stepForward/Backward: frameTime = 1.0 / targetFrameRate
    private var targetFrameRate: Double = 30.0

    /// 오디오 플레이어
    ///
    /// ## AudioPlayer
    /// - 오디오 프레임을 재생하는 플레이어
    /// - VideoDecoder에서 오디오 프레임을 받아 재생
    ///
    /// ## Optional인 이유
    /// - 오디오 스트림 없음: nil
    /// - 오디오 플레이어 초기화 실패: nil
    /// - 비디오만 재생할 경우: nil
    ///
    /// ## 동기화 방식
    /// ```
    /// updatePlayback()
    ///      ↓
    /// decoder.decodeNextFrame() → { video: VideoFrame, audio: AudioFrame }
    ///      ↓
    /// currentFrame = videoFrame (비디오 표시)
    /// audioPlayer.enqueue(audioFrame) (오디오 재생)
    ///      ↓
    /// 비디오와 오디오가 동기화되어 재생
    /// ```
    private var audioPlayer: AudioPlayer?

    // MARK: - Initialization

    /// ViewModel 초기화
    ///
    /// ## 빈 초기화
    /// - 모든 속성은 기본값으로 초기화됨
    /// - 비디오는 loadVideo()로 별도 로드
    ///
    /// **사용 예시:**
    /// ```swift
    /// let viewModel = VideoPlayerViewModel()
    /// viewModel.loadVideo(videoFile)  // 비디오 로드
    /// ```
    init() {
        // Empty initialization
    }

    /// ViewModel 메모리 해제 시 호출
    ///
    /// ## deinit
    /// - 객체가 메모리에서 해제될 때 자동 호출
    /// - 리소스 정리 (타이머, 디코더, 오디오 플레이어 등)
    ///
    /// **동작:**
    /// ```
    /// viewModel = nil (ViewModel 해제)
    ///      ↓
    /// deinit 자동 호출
    ///      ↓
    /// stop() → 타이머 중지, 오디오 정지, 디코더 해제
    /// ```
    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// 비디오 파일 로드
    ///
    /// ## 로딩 프로세스
    /// ```
    /// 1. 기존 재생 중지 (stop())
    ///      ↓
    /// 2. 파일 손상 여부 확인 (videoFile.isCorrupted)
    ///      ↓
    /// 3. 전면 카메라 채널 선택 (or 첫 번째 채널)
    ///      ↓
    /// 4. VideoDecoder 초기화 (FFmpeg)
    ///      ↓
    /// 5. duration, frameRate 가져오기
    ///      ↓
    /// 6. 첫 프레임 로드 (time: 0)
    ///      ↓
    /// 7. AudioPlayer 초기화 (오디오 스트림 있을 경우)
    ///      ↓
    /// 8. playbackState = .paused (재생 준비 완료)
    /// ```
    ///
    /// ## 에러 처리
    /// - 손상된 파일: errorMessage 설정, playbackState = .stopped
    /// - 채널 없음: errorMessage 설정
    /// - 디코더 초기화 실패: errorMessage 설정, playbackState = .stopped
    ///
    /// - Parameter videoFile: 로드할 비디오 파일
    ///
    /// **사용 예시:**
    /// ```swift
    /// let videoFile = VideoFile(filePath: "/path/to/video.mp4", ...)
    /// viewModel.loadVideo(videoFile)
    ///
    /// // 성공 시
    /// // playbackState = .paused
    /// // currentFrame = 첫 프레임
    /// // duration = 90.0 (90초)
    ///
    /// // 실패 시
    /// // playbackState = .stopped
    /// // errorMessage = "Failed to load video: ..."
    /// ```
    func loadVideo(_ videoFile: VideoFile) {
        /// 1단계: 기존 재생 중지
        ///
        /// ## stop()
        /// - 재생 중이던 비디오가 있다면 정리
        /// - 타이머, 디코더, 오디오 플레이어 해제
        stop()

        /// 2단계: 파일 정보 저장
        self.videoFile = videoFile

        /// 3단계: 파일 손상 여부 확인
        ///
        /// ## videoFile.isCorrupted
        /// - 파일 스캔 중 손상 감지된 경우 true
        /// - 손상된 파일은 재생 불가
        ///
        /// **손상 예시:**
        /// - 파일 헤더 손상
        /// - 불완전한 다운로드
        /// - 저장 중 에러
        if videoFile.isCorrupted {
            errorMessage = "Cannot play corrupted video file. The file may be damaged or incomplete."
            playbackState = .stopped
            return
        }

        /// 4단계: 전면 카메라 채널 선택
        ///
        /// ## 채널 선택 우선순위
        /// 1. 전면 카메라 (.front) - 기본 채널
        /// 2. 첫 번째 채널 (channels.first) - 전면 카메라 없을 경우
        ///
        /// **예시:**
        /// ```swift
        /// videoFile.channels = [
        ///     ChannelInfo(position: .front, filePath: "/front.mp4"),
        ///     ChannelInfo(position: .rear, filePath: "/rear.mp4")
        /// ]
        ///
        /// channel(for: .front) → /front.mp4 선택
        /// ```
        ///
        /// ## guard let
        /// - Optional Binding으로 안전하게 추출
        /// - nil일 경우 early return
        guard let frontChannel = videoFile.channel(for: .front) ?? videoFile.channels.first else {
            errorMessage = "No video channel available"
            return
        }

        /// 5단계: VideoDecoder 생성
        ///
        /// ## VideoDecoder
        /// - FFmpeg을 래핑한 비디오 디코더
        /// - filePath로 비디오 파일 열기
        let decoder = VideoDecoder(filePath: frontChannel.filePath)

        /// 6단계: 디코더 초기화 (do-catch)
        ///
        /// ## try decoder.initialize()
        /// - FFmpeg avformat_open_input, avformat_find_stream_info 호출
        /// - 비디오/오디오 스트림 정보 파싱
        /// - 코덱 초기화
        ///
        /// ## 에러 발생 시
        /// - catch 블록에서 errorMessage 설정
        /// - playbackState = .stopped
        do {
            try decoder.initialize()
            self.decoder = decoder

            /// 7단계: duration 설정
            ///
            /// ## duration 우선순위
            /// 1. decoder.getDuration() - FFmpeg에서 직접 가져온 값 (정확)
            /// 2. videoFile.duration - 파일 정보에서 가져온 값 (fallback)
            if let videoDuration = decoder.getDuration() {
                self.duration = videoDuration
            } else {
                self.duration = videoFile.duration
            }

            /// 8단계: 프레임율 가져오기
            ///
            /// ## videoInfo
            /// - 비디오 스트림 정보 (해상도, 프레임율, 코덱 등)
            /// - targetFrameRate에 저장하여 Timer 간격 계산에 사용
            if let videoInfo = decoder.videoInfo {
                self.targetFrameRate = videoInfo.frameRate
            }

            /// 9단계: 첫 프레임 로드
            ///
            /// ## loadFrameAt(time: 0)
            /// - time: 0초의 프레임 디코딩
            /// - currentFrame에 할당 → View에 표시
            loadFrameAt(time: 0)

            /// 10단계: AudioPlayer 초기화
            ///
            /// ## decoder.audioInfo
            /// - 오디오 스트림 정보 (샘플레이트, 채널 수, 코덱 등)
            /// - nil이면 오디오 없음 (비디오만 재생)
            ///
            /// **초기화 프로세스:**
            /// ```
            /// AudioPlayer() 생성
            ///      ↓
            /// audioPlayer.start() → 오디오 재생 준비
            ///      ↓
            /// audioPlayer.setVolume(volume) → 볼륨 설정
            ///      ↓
            /// self.audioPlayer = audioPlayer (저장)
            /// ```
            ///
            /// ## 실패 처리
            /// - print()로 경고 메시지 출력
            /// - audioPlayer = nil (비디오만 재생 계속)
            if decoder.audioInfo != nil {
                let audioPlayer = AudioPlayer()
                do {
                    try audioPlayer.start()
                    audioPlayer.setVolume(Float(volume))
                    self.audioPlayer = audioPlayer
                } catch {
                    print("Warning: Failed to start audio player: \(error.localizedDescription)")
                    // Continue without audio
                }
            }

            /// 11단계: 상태 업데이트
            playbackState = .paused  // 재생 준비 완료 (일시정지 상태)
            errorMessage = nil       // 에러 메시지 초기화

        } catch {
            /// 에러 처리
            ///
            /// ## catch 블록
            /// - decoder.initialize() 실패 시 실행
            /// - errorMessage에 에러 내용 저장
            /// - playbackState = .stopped
            ///
            /// **에러 예시:**
            /// ```
            /// "Failed to load video: File not found"
            /// "Failed to load video: Unsupported codec"
            /// "Failed to load video: Permission denied"
            /// ```
            errorMessage = "Failed to load video: \(error.localizedDescription)"
            playbackState = .stopped
        }
    }

    /// 재생 시작 또는 재개
    ///
    /// ## 동작 조건
    /// - playbackState != .playing (이미 재생 중이 아님)
    /// - decoder != nil (비디오 로드됨)
    ///
    /// ## 동작
    /// 1. playbackState = .playing
    /// 2. audioPlayer.resume() → 오디오 재생 시작
    /// 3. startPlaybackTimer() → 타이머 시작 (프레임 단위로 재생)
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 로딩 후 재생
    /// viewModel.loadVideo(videoFile)
    /// viewModel.play()  // 재생 시작
    ///
    /// // 일시정지 후 재개
    /// viewModel.pause()
    /// viewModel.play()  // 재생 재개
    /// ```
    func play() {
        /// guard 조건 체크
        ///
        /// ## playbackState != .playing
        /// - 이미 재생 중이면 실행 안 함 (중복 방지)
        ///
        /// ## decoder != nil
        /// - 비디오가 로드되지 않았으면 실행 안 함
        guard playbackState != .playing, decoder != nil else { return }

        playbackState = .playing
        audioPlayer?.resume()  // 오디오 재생 재개 (일시정지 상태였을 경우)
        startPlaybackTimer()   // Timer 시작 → 프레임 단위 재생
    }

    /// 재생 일시정지
    ///
    /// ## 동작 조건
    /// - playbackState == .playing (재생 중일 때만)
    ///
    /// ## 동작
    /// 1. playbackState = .paused
    /// 2. audioPlayer.pause() → 오디오 일시정지
    /// 3. stopPlaybackTimer() → 타이머 중지
    ///
    /// ## 상태 유지
    /// - currentTime, playbackPosition, currentFrame 유지
    /// - play() 호출 시 현재 위치에서 재개
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.play()   // 재생 시작
    /// // ... 재생 중 ...
    /// viewModel.pause()  // 일시정지
    /// // currentTime = 5.0 (유지됨)
    /// viewModel.play()   // 5.0초부터 재개
    /// ```
    func pause() {
        guard playbackState == .playing else { return }

        playbackState = .paused
        audioPlayer?.pause()  // 오디오 일시정지 (버퍼는 유지)
        stopPlaybackTimer()   // Timer 중지
    }

    /// 재생/일시정지 토글
    ///
    /// ## 토글 동작
    /// - .playing → pause() 호출
    /// - .paused 또는 .stopped → play() 호출
    ///
    /// **사용 예시:**
    /// ```swift
    /// // Play/Pause 버튼 구현
    /// Button(action: {
    ///     viewModel.togglePlayPause()
    /// }) {
    ///     Image(systemName: viewModel.playbackState == .playing ? "pause.fill" : "play.fill")
    /// }
    /// ```
    func togglePlayPause() {
        if playbackState == .playing {
            pause()
        } else {
            play()
        }
    }

    /// 재생 정지 및 리소스 해제
    ///
    /// ## 정지 프로세스
    /// ```
    /// 1. stopPlaybackTimer() → Timer 중지 및 해제
    ///      ↓
    /// 2. audioPlayer.stop() → 오디오 정지 및 버퍼 비우기
    ///      ↓
    /// 3. audioPlayer = nil → AudioPlayer 해제
    ///      ↓
    /// 4. 상태 초기화 (playbackState, currentTime, playbackPosition, currentFrame)
    ///      ↓
    /// 5. decoder = nil → VideoDecoder 해제 (FFmpeg 리소스 정리)
    ///      ↓
    /// 6. videoFile = nil → 파일 정보 해제
    /// ```
    ///
    /// ## 사용 시점
    /// - 사용자가 정지 버튼 클릭
    /// - 다른 비디오 로드 (loadVideo 시작 부분)
    /// - 파일 끝(EOF) 도달
    /// - ViewModel 메모리 해제 (deinit)
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.play()  // 재생 중
    /// viewModel.stop()  // 정지 → 모든 리소스 해제
    ///
    /// // 상태 확인
    /// viewModel.playbackState  // .stopped
    /// viewModel.currentTime    // 0.0
    /// viewModel.currentFrame   // nil
    /// ```
    func stop() {
        stopPlaybackTimer()       // Timer 중지
        audioPlayer?.stop()       // 오디오 정지
        audioPlayer = nil         // AudioPlayer 해제
        playbackState = .stopped  // 상태: 정지
        currentTime = 0.0         // 시간 초기화
        playbackPosition = 0.0    // 위치 초기화
        currentFrame = nil        // 프레임 초기화
        decoder = nil             // VideoDecoder 해제 (FFmpeg 정리)
        videoFile = nil           // 파일 정보 해제
    }

    /// 특정 위치로 시크 (비율 기반)
    ///
    /// ## 시크 알고리즘
    /// ```
    /// 1. position을 0.0~1.0으로 clamp
    ///      ↓
    /// 2. targetTime = position * duration 계산
    ///      ↓
    /// 3. seekToTime(targetTime) 호출
    /// ```
    ///
    /// - Parameter position: 시크 위치 (0.0 = 시작, 1.0 = 끝)
    ///
    /// **사용 예시:**
    /// ```swift
    /// // duration = 90초
    /// viewModel.seek(to: 0.0)   → seekToTime(0초)   (시작)
    /// viewModel.seek(to: 0.5)   → seekToTime(45초)  (중간)
    /// viewModel.seek(to: 1.0)   → seekToTime(90초)  (끝)
    /// viewModel.seek(to: 1.5)   → seekToTime(90초)  (clamp)
    /// viewModel.seek(to: -0.1)  → seekToTime(0초)   (clamp)
    /// ```
    ///
    /// **View에서 사용 (타임라인 슬라이더):**
    /// ```swift
    /// Slider(value: $viewModel.playbackPosition, in: 0...1)
    ///     .onChange(of: playbackPosition) { newPosition in
    ///         viewModel.seek(to: newPosition)
    ///     }
    /// ```
    func seek(to position: Double) {
        /// position을 0.0~1.0 범위로 제한
        ///
        /// ## max(0.0, min(1.0, position))
        /// - position < 0.0 → 0.0
        /// - position > 1.0 → 1.0
        /// - 0.0 <= position <= 1.0 → position (그대로)
        let clampedPosition = max(0.0, min(1.0, position))

        /// targetTime 계산
        ///
        /// ## position을 실제 시간으로 변환
        /// ```
        /// duration = 90초, position = 0.5
        /// targetTime = 0.5 * 90 = 45초
        /// ```
        let targetTime = clampedPosition * duration

        /// 실제 시크 수행
        seekToTime(targetTime)
    }

    /// 특정 시간으로 시크 (초 단위)
    ///
    /// ## 시크 프로세스
    /// ```
    /// 1. time을 0~duration 범위로 clamp
    ///      ↓
    /// 2. decoder.seek(to: time) → FFmpeg seek 수행
    ///      ↓
    /// 3. currentTime, playbackPosition 업데이트
    ///      ↓
    /// 4. audioPlayer.flush() → 오디오 버퍼 비우기
    ///      ↓
    /// 5. loadFrameAt(time:) → 해당 시간의 프레임 로드
    /// ```
    ///
    /// - Parameter time: 시크할 시간 (초)
    ///
    /// **사용 예시:**
    /// ```swift
    /// // duration = 90초
    /// viewModel.seekToTime(0.0)    → 시작으로 이동
    /// viewModel.seekToTime(45.0)   → 45초로 이동
    /// viewModel.seekToTime(90.0)   → 끝으로 이동
    /// viewModel.seekToTime(100.0)  → 90초로 clamp (끝)
    /// viewModel.seekToTime(-5.0)   → 0초로 clamp (시작)
    /// ```
    func seekToTime(_ time: TimeInterval) {
        guard let decoder = decoder else { return }

        /// time을 0~duration 범위로 제한
        ///
        /// ## max(0.0, min(duration, time))
        /// - time < 0.0 → 0.0 (시작)
        /// - time > duration → duration (끝)
        /// - 0.0 <= time <= duration → time (그대로)
        let clampedTime = max(0.0, min(duration, time))

        /// 시크 수행 (do-catch)
        do {
            /// 1. FFmpeg seek 수행
            ///
            /// ## decoder.seek(to: clampedTime)
            /// - av_seek_frame() 호출
            /// - 해당 시간의 keyframe으로 이동
            /// - 디코더 내부 버퍼 초기화
            try decoder.seek(to: clampedTime)

            /// 2. 상태 업데이트
            currentTime = clampedTime
            playbackPosition = duration > 0 ? clampedTime / duration : 0.0

            /// 3. 오디오 버퍼 비우기
            ///
            /// ## audioPlayer.flush()
            /// - 재생 대기 중인 오디오 프레임 제거
            /// - 시크 후 이전 오디오가 재생되는 것 방지
            audioPlayer?.flush()

            /// 4. 해당 시간의 프레임 로드
            ///
            /// ## loadFrameAt(time: clampedTime)
            /// - 시크한 위치의 비디오 프레임 디코딩
            /// - currentFrame 업데이트 → View에 표시
            loadFrameAt(time: clampedTime)

        } catch {
            /// 시크 실패 처리
            ///
            /// **실패 예시:**
            /// - 손상된 비디오 파일
            /// - 잘못된 timestamp
            /// - FFmpeg 내부 에러
            errorMessage = "Seek failed: \(error.localizedDescription)"
        }
    }

    /// 한 프레임 앞으로 이동
    ///
    /// ## 프레임 단위 이동
    /// - frameTime = 1.0 / targetFrameRate 계산
    /// - seekToTime(currentTime + frameTime) 호출
    ///
    /// **계산 예시:**
    /// ```swift
    /// targetFrameRate = 30.0
    /// frameTime = 1.0 / 30.0 = 0.0333초 (약 33ms)
    ///
    /// currentTime = 5.0초
    /// stepForward() → seekToTime(5.0333초) → 다음 프레임
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 한 프레임씩 이동 버튼
    /// Button(action: { viewModel.stepForward() }) {
    ///     Image(systemName: "forward.frame")  // ▶| 아이콘
    /// }
    /// ```
    func stepForward() {
        let frameTime = 1.0 / targetFrameRate
        seekToTime(currentTime + frameTime)
    }

    /// 한 프레임 뒤로 이동
    ///
    /// ## 프레임 단위 이동
    /// - frameTime = 1.0 / targetFrameRate 계산
    /// - seekToTime(currentTime - frameTime) 호출
    ///
    /// **계산 예시:**
    /// ```swift
    /// targetFrameRate = 30.0
    /// frameTime = 1.0 / 30.0 = 0.0333초 (약 33ms)
    ///
    /// currentTime = 5.0초
    /// stepBackward() → seekToTime(4.9667초) → 이전 프레임
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 한 프레임씩 이동 버튼
    /// Button(action: { viewModel.stepBackward() }) {
    ///     Image(systemName: "backward.frame")  // |◀ 아이콘
    /// }
    /// ```
    func stepBackward() {
        let frameTime = 1.0 / targetFrameRate
        seekToTime(currentTime - frameTime)
    }

    /// 재생 속도 설정
    ///
    /// ## 속도 범위
    /// - 최소: 0.1x (10배 느리게)
    /// - 최대: 4.0x (4배 빠르게)
    ///
    /// ## 속도 변경 동작
    /// 1. speed를 0.1~4.0으로 clamp
    /// 2. playbackSpeed에 저장
    /// 3. 재생 중이면 Timer 재시작 (새로운 간격 적용)
    ///
    /// - Parameter speed: 재생 속도 (0.5x, 1.0x, 2.0x 등)
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.setPlaybackSpeed(0.5)  // 0.5배속 (느리게)
    /// viewModel.setPlaybackSpeed(1.0)  // 정상 속도
    /// viewModel.setPlaybackSpeed(2.0)  // 2배속 (빠르게)
    /// viewModel.setPlaybackSpeed(5.0)  // 4.0으로 clamp (최대)
    /// ```
    func setPlaybackSpeed(_ speed: Double) {
        /// speed를 0.1~4.0 범위로 제한
        playbackSpeed = max(0.1, min(4.0, speed))

        /// 재생 중이면 Timer 재시작
        ///
        /// ## Timer 간격 재계산
        /// ```
        /// // 이전: speed = 1.0x, interval = 0.0333초
        /// // 변경: speed = 2.0x, interval = 0.0167초 (2배 빠름)
        /// ```
        ///
        /// **동작:**
        /// ```
        /// stopPlaybackTimer() → 기존 Timer 중지
        ///      ↓
        /// startPlaybackTimer() → 새로운 간격으로 Timer 시작
        /// ```
        if playbackState == .playing {
            stopPlaybackTimer()
            startPlaybackTimer()
        }
    }

    /// 음량 설정
    ///
    /// ## 음량 범위
    /// - 최소: 0.0 (무음)
    /// - 최대: 1.0 (최대 볼륨)
    ///
    /// ## 음량 변경 동작
    /// 1. volume을 0.0~1.0으로 clamp
    /// 2. self.volume에 저장
    /// 3. audioPlayer.setVolume() 호출
    ///
    /// - Parameter volume: 음량 (0.0 ~ 1.0)
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.setVolume(0.0)   // 무음
    /// viewModel.setVolume(0.5)   // 50% 볼륨
    /// viewModel.setVolume(1.0)   // 최대 볼륨
    /// viewModel.setVolume(1.5)   // 1.0으로 clamp (최대)
    /// ```
    func setVolume(_ volume: Double) {
        /// volume을 0.0~1.0 범위로 제한
        self.volume = max(0.0, min(1.0, volume))

        /// AudioPlayer에 볼륨 전달
        ///
        /// ## Float 변환
        /// - AudioPlayer는 Float 타입 사용
        /// - Double → Float 캐스팅 필요
        audioPlayer?.setVolume(Float(self.volume))
    }

    /// 상대적인 시간만큼 시크
    ///
    /// ## 상대 시크
    /// - 현재 시간 기준으로 앞/뒤로 이동
    /// - seconds > 0: 앞으로 (forward)
    /// - seconds < 0: 뒤로 (backward)
    ///
    /// - Parameter seconds: 이동할 시간 (초, 양수=앞으로, 음수=뒤로)
    ///
    /// **사용 예시:**
    /// ```swift
    /// // currentTime = 30초
    /// viewModel.seekBySeconds(10)   → seekToTime(40초)  (10초 앞으로)
    /// viewModel.seekBySeconds(-5)   → seekToTime(35초)  (5초 뒤로)
    /// viewModel.seekBySeconds(100)  → seekToTime(90초)  (clamp to duration)
    /// ```
    ///
    /// **View에서 사용 (키보드 단축키):**
    /// ```swift
    /// .onKeyPress(.rightArrow) { viewModel.seekBySeconds(5) }   // ← 5초 앞으로
    /// .onKeyPress(.leftArrow) { viewModel.seekBySeconds(-5) }   // → 5초 뒤로
    /// ```
    func seekBySeconds(_ seconds: Double) {
        seekToTime(currentTime + seconds)
    }

    /// 음량 조절 (상대값)
    ///
    /// ## 상대 음량 조절
    /// - 현재 음량 기준으로 증가/감소
    /// - delta > 0: 증가
    /// - delta < 0: 감소
    ///
    /// - Parameter delta: 음량 변화량 (-1.0 ~ 1.0)
    ///
    /// **사용 예시:**
    /// ```swift
    /// // volume = 0.5
    /// viewModel.adjustVolume(by: 0.1)   → setVolume(0.6)  (10% 증가)
    /// viewModel.adjustVolume(by: -0.2)  → setVolume(0.4)  (20% 감소)
    /// viewModel.adjustVolume(by: 0.8)   → setVolume(1.0)  (clamp to max)
    /// ```
    ///
    /// **View에서 사용 (키보드 단축키):**
    /// ```swift
    /// .onKeyPress(.upArrow) { viewModel.adjustVolume(by: 0.1) }     // ↑ 볼륨 증가
    /// .onKeyPress(.downArrow) { viewModel.adjustVolume(by: -0.1) }  // ↓ 볼륨 감소
    /// ```
    func adjustVolume(by delta: Double) {
        setVolume(volume + delta)
    }

    // MARK: - Segment Selection Methods

    /// 현재 시간을 In Point로 설정
    ///
    /// ## In Point 설정
    /// - 현재 재생 위치를 구간 시작점으로 저장
    /// - outPoint가 이미 설정되어 있고 currentTime보다 작으면 outPoint 제거
    ///
    /// **사용 예시:**
    /// ```swift
    /// // currentTime = 5.0
    /// viewModel.setInPoint()
    /// // inPoint = 5.0
    ///
    /// // 버튼 구현
    /// Button("Set In") {
    ///     viewModel.setInPoint()
    /// }
    /// ```
    func setInPoint() {
        inPoint = currentTime

        // Out Point가 In Point보다 앞에 있으면 제거
        if let out = outPoint, out <= currentTime {
            outPoint = nil
        }
    }

    /// 현재 시간을 Out Point로 설정
    ///
    /// ## Out Point 설정
    /// - 현재 재생 위치를 구간 끝점으로 저장
    /// - inPoint가 설정되어 있지 않거나 currentTime보다 크면 설정 불가
    ///
    /// **사용 예시:**
    /// ```swift
    /// // currentTime = 15.0, inPoint = 5.0
    /// viewModel.setOutPoint()
    /// // outPoint = 15.0
    ///
    /// // 버튼 구현
    /// Button("Set Out") {
    ///     viewModel.setOutPoint()
    /// }
    /// ```
    func setOutPoint() {
        // In Point가 설정되어 있고 현재 시간이 그보다 뒤일 때만 설정
        guard let inTime = inPoint, currentTime > inTime else {
            return
        }

        outPoint = currentTime
    }

    /// In Point 제거
    ///
    /// ## 초기화
    /// - inPoint를 nil로 초기화
    /// - outPoint도 함께 제거 (구간이 무효화됨)
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.clearInPoint()
    /// // inPoint = nil, outPoint = nil
    /// ```
    func clearInPoint() {
        inPoint = nil
        outPoint = nil  // Out Point도 함께 제거
    }

    /// Out Point 제거
    ///
    /// ## 초기화
    /// - outPoint를 nil로 초기화
    /// - inPoint는 유지 (다시 Out Point 설정 가능)
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.clearOutPoint()
    /// // outPoint = nil, inPoint는 유지
    /// ```
    func clearOutPoint() {
        outPoint = nil
    }

    /// 선택된 구간 초기화
    ///
    /// ## 전체 초기화
    /// - inPoint와 outPoint 모두 nil로 초기화
    ///
    /// **사용 예시:**
    /// ```swift
    /// viewModel.clearSegment()
    /// // inPoint = nil, outPoint = nil
    ///
    /// // 버튼 구현
    /// Button("Clear") {
    ///     viewModel.clearSegment()
    /// }
    /// ```
    func clearSegment() {
        inPoint = nil
        outPoint = nil
    }

    /// 선택된 구간이 유효한지 확인
    ///
    /// ## 유효성 검사
    /// - inPoint와 outPoint 모두 설정되어 있음
    /// - outPoint > inPoint (구간 길이 > 0)
    ///
    /// - Returns: 구간이 유효하면 true
    ///
    /// **사용 예시:**
    /// ```swift
    /// if viewModel.hasValidSegment {
    ///     // Export 버튼 활성화
    /// }
    /// ```
    var hasValidSegment: Bool {
        guard let inTime = inPoint, let outTime = outPoint else {
            return false
        }
        return outTime > inTime
    }

    /// 선택된 구간 길이 (초)
    ///
    /// ## 구간 길이 계산
    /// - segmentDuration = outPoint - inPoint
    /// - 유효하지 않으면 0.0 반환
    ///
    /// - Returns: 구간 길이 (초)
    ///
    /// **사용 예시:**
    /// ```swift
    /// // inPoint = 5.0, outPoint = 15.0
    /// viewModel.segmentDuration  // 10.0
    ///
    /// // UI 표시
    /// Text("Segment: \(formatTime(viewModel.segmentDuration))")
    /// // "Segment: 00:10"
    /// ```
    var segmentDuration: TimeInterval {
        guard let inTime = inPoint, let outTime = outPoint else {
            return 0.0
        }
        return outTime - inTime
    }

    // MARK: - Private Methods

    /// 재생 타이머 시작
    ///
    /// ## Timer 생성 및 시작
    /// ```
    /// 1. 기존 Timer 중지 (stopPlaybackTimer)
    ///      ↓
    /// 2. interval 계산: (1.0 / targetFrameRate) / playbackSpeed
    ///      ↓
    /// 3. Timer.scheduledTimer 생성 (repeats: true)
    ///      ↓ interval마다 반복 실행
    /// 4. updatePlayback() 호출 → 프레임 디코딩 및 표시
    /// ```
    ///
    /// ## interval 계산 예시
    /// ```swift
    /// // 30 FPS, 1.0x 속도
    /// targetFrameRate = 30.0, playbackSpeed = 1.0
    /// interval = (1.0 / 30.0) / 1.0 = 0.0333초 (33ms)
    ///
    /// // 30 FPS, 2.0x 속도 (2배 빠름)
    /// targetFrameRate = 30.0, playbackSpeed = 2.0
    /// interval = (1.0 / 30.0) / 2.0 = 0.0167초 (17ms)
    ///
    /// // 60 FPS, 0.5x 속도 (2배 느림)
    /// targetFrameRate = 60.0, playbackSpeed = 0.5
    /// interval = (1.0 / 60.0) / 0.5 = 0.0333초 (33ms)
    /// ```
    private func startPlaybackTimer() {
        /// 기존 Timer 정리
        stopPlaybackTimer()

        /// Timer 간격 계산
        ///
        /// ## (1.0 / targetFrameRate) / playbackSpeed
        /// - (1.0 / targetFrameRate): 한 프레임 시간 (초)
        /// - / playbackSpeed: 재생 속도 적용
        let interval = (1.0 / targetFrameRate) / playbackSpeed

        /// Timer 생성 및 시작
        ///
        /// ## Timer.scheduledTimer
        /// - withTimeInterval: interval초마다 실행
        /// - repeats: true → 계속 반복 (false면 한 번만 실행)
        /// - [weak self]: 순환 참조 방지 (메모리 누수 방지)
        ///
        /// **weak self 필요성:**
        /// ```
        /// Timer → closure → self (ViewModel)
        ///   ↑__________________________|
        /// 순환 참조 발생! (메모리 해제 안 됨)
        ///
        /// [weak self]로 해결:
        /// Timer → closure --weak--> self
        /// (Timer 해제 → closure 해제 → self 해제 가능)
        /// ```
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    /// 재생 타이머 중지
    ///
    /// ## Timer 정리
    /// ```
    /// 1. playbackTimer?.invalidate() → Timer 중지 및 해제
    ///      ↓
    /// 2. playbackTimer = nil → 참조 제거
    /// ```
    ///
    /// ## invalidate()
    /// - Timer를 RunLoop에서 제거
    /// - 더 이상 클로저가 호출되지 않음
    /// - Timer 메모리 해제
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    /// 재생 업데이트 (Timer 콜백)
    ///
    /// ## 호출 시점
    /// - playbackTimer가 주기적으로 호출 (프레임율 + 재생속도 기반)
    ///
    /// ## 업데이트 프로세스
    /// ```
    /// 1. decoder.decodeNextFrame() → 다음 프레임 디코딩
    ///      ↓
    /// 2. 비디오 프레임 처리
    ///    - currentFrame 업데이트 (@Published → View 갱신)
    ///    - currentTime 업데이트
    ///    - playbackPosition 업데이트
    ///      ↓
    /// 3. 오디오 프레임 처리
    ///    - audioPlayer.enqueue(audioFrame) → 오디오 재생
    ///      ↓
    /// 4. EOF 체크
    ///    - 파일 끝 도달 시 stop() 호출
    /// ```
    ///
    /// ## 에러 처리
    /// - EOF 에러: stop() 호출, currentTime/playbackPosition을 끝으로 설정
    /// - 기타 에러: errorMessage 설정, stop() 호출
    private func updatePlayback() {
        /// decoder 존재 확인
        ///
        /// ## guard let
        /// - decoder가 nil이면 stop() 호출 후 return
        /// - 비디오가 언로드된 상태
        guard let decoder = decoder else {
            stop()
            return
        }

        /// 프레임 디코딩 (do-catch)
        do {
            /// 다음 프레임 디코딩
            ///
            /// ## decoder.decodeNextFrame()
            /// - FFmpeg av_read_frame(), avcodec_send_packet(), avcodec_receive_frame() 호출
            /// - 반환: DecodeResult? (video: VideoFrame?, audio: AudioFrame?)
            /// - nil 반환: EOF (파일 끝)
            ///
            /// **반환 예시:**
            /// ```swift
            /// // 비디오 + 오디오
            /// DecodeResult(video: VideoFrame(...), audio: AudioFrame(...))
            ///
            /// // 비디오만
            /// DecodeResult(video: VideoFrame(...), audio: nil)
            ///
            /// // EOF
            /// nil
            /// ```
            if let result = try decoder.decodeNextFrame() {
                /// 비디오 프레임 처리
                if let videoFrame = result.video {
                    currentFrame = videoFrame  // @Published → View 자동 갱신
                    currentTime = videoFrame.timestamp
                    playbackPosition = duration > 0 ? currentTime / duration : 0.0
                }

                /// 오디오 프레임 처리
                ///
                /// ## audioPlayer.enqueue(audioFrame)
                /// - 오디오 프레임을 재생 큐에 추가
                /// - AudioPlayer가 자동으로 재생
                ///
                /// ## do-catch 내부 에러
                /// - 오디오 재생 실패 시 경고 메시지만 출력
                /// - 비디오 재생은 계속 진행 (오디오 없이)
                if let audioFrame = result.audio {
                    do {
                        try audioPlayer?.enqueue(audioFrame)
                    } catch {
                        // Log audio error but continue video playback
                        print("Warning: Failed to enqueue audio frame: \(error.localizedDescription)")
                    }
                }
            } else {
                /// EOF (파일 끝) 도달
                ///
                /// ## decodeNextFrame() 반환 nil
                /// - 더 이상 디코딩할 프레임 없음
                /// - 재생 종료
                stop()
                currentTime = duration        // 끝 시간으로 설정
                playbackPosition = 1.0        // 100% 위치
            }
        } catch {
            /// 디코딩 에러 처리
            ///
            /// ## DecoderError.endOfFile
            /// - EOF 에러 (파일 끝)
            /// - stop() 호출, 시간/위치를 끝으로 설정
            ///
            /// ## 기타 에러
            /// - 디코딩 실패, 손상된 프레임 등
            /// - errorMessage 설정, stop() 호출
            if case DecoderError.endOfFile = error {
                stop()
                currentTime = duration
                playbackPosition = 1.0
            } else {
                errorMessage = "Playback error: \(error.localizedDescription)"
                stop()
            }
        }
    }

    /// 특정 시간의 프레임 로드
    ///
    /// ## 사용 시점
    /// - 비디오 로딩 후 첫 프레임 표시 (loadVideo)
    /// - 시크 후 해당 위치 프레임 표시 (seekToTime)
    ///
    /// ## 로딩 프로세스
    /// ```
    /// 1. isBuffering = true (로딩 시작)
    ///      ↓
    /// 2. decoder.seek(to: time) → FFmpeg seek
    ///      ↓
    /// 3. decoder.decodeNextFrame() → 프레임 디코딩
    ///      ↓
    /// 4. currentFrame 업데이트 (@Published → View 갱신)
    ///      ↓
    /// 5. isBuffering = false (로딩 완료)
    /// ```
    ///
    /// - Parameter time: 로드할 시간 (초)
    private func loadFrameAt(time: TimeInterval) {
        guard let decoder = decoder else { return }

        /// 버퍼링 시작
        ///
        /// ## isBuffering = true
        /// - @Published → View에 로딩 인디케이터 표시
        isBuffering = true

        /// 프레임 로드 (do-catch)
        do {
            /// 1. 해당 시간으로 시크
            try decoder.seek(to: time)

            /// 2. 프레임 디코딩
            ///
            /// ## if let 중첩
            /// - result가 nil이 아니고
            /// - result.video가 nil이 아닐 때만 실행
            ///
            /// **조건 체크:**
            /// ```swift
            /// result = nil               → 실행 안 함 (EOF)
            /// result = DecodeResult(video: nil, ...) → 실행 안 함 (비디오 없음)
            /// result = DecodeResult(video: VideoFrame(...), ...) → 실행 ✅
            /// ```
            if let result = try decoder.decodeNextFrame(),
               let videoFrame = result.video {
                currentFrame = videoFrame  // @Published → View 갱신
            }

            /// 버퍼링 완료
            isBuffering = false
        } catch {
            /// 로드 실패 처리
            errorMessage = "Failed to load frame: \(error.localizedDescription)"
            isBuffering = false
        }
    }
}

// MARK: - Supporting Types

/// @enum PlaybackState
/// @brief 재생 상태 열거형
/// @details 비디오 플레이어의 재생 상태를 표현합니다.
///
/// ## 상태 종류
/// - .stopped: 정지 상태 (비디오 없음 또는 재생 종료)
/// - .playing: 재생 중 (Timer 동작)
/// - .paused: 일시정지 (상태 유지)
///
/// ## Equatable
/// - == 연산자로 비교 가능
/// - if문에서 상태 확인 가능
///
/// **상태 전환 다이어그램:**
/// ```
///          loadVideo()
///  .stopped ────────────> .paused
///     ↑                      ↓ play()
///     |                   .playing
///     |                      ↓ pause()
///     └────── stop() ────── .paused
/// ```
///
/// **사용 예시:**
/// ```swift
/// if viewModel.playbackState == .playing {
///     print("재생 중")
/// }
///
/// switch viewModel.playbackState {
/// case .stopped:
///     print("정지됨")
/// case .playing:
///     print("재생 중")
/// case .paused:
///     print("일시정지됨")
/// }
/// ```
enum PlaybackState: Equatable {
    /// 정지 상태
    ///
    /// ## 진입 시점
    /// - 초기 상태 (비디오 로드 전)
    /// - stop() 호출 후
    /// - EOF 도달 후
    /// - 로딩 실패 후
    case stopped

    /// 재생 중
    ///
    /// ## 진입 시점
    /// - play() 호출 후
    /// - togglePlayPause() 호출 시 (paused → playing)
    ///
    /// ## 특징
    /// - Timer 동작 중 (updatePlayback 반복 호출)
    /// - AudioPlayer 재생 중
    case playing

    /// 일시정지
    ///
    /// ## 진입 시점
    /// - loadVideo() 완료 후 (재생 준비 완료)
    /// - pause() 호출 후
    /// - togglePlayPause() 호출 시 (playing → paused)
    ///
    /// ## 특징
    /// - Timer 중지
    /// - AudioPlayer 일시정지
    /// - currentTime, playbackPosition, currentFrame 유지
    case paused

    /// 상태 표시 이름
    ///
    /// ## displayName
    /// - UI에 표시할 문자열 반환
    ///
    /// **예시:**
    /// ```swift
    /// PlaybackState.stopped.displayName  // "Stopped"
    /// PlaybackState.playing.displayName  // "Playing"
    /// PlaybackState.paused.displayName   // "Paused"
    /// ```
    var displayName: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        }
    }
}

// MARK: - Computed Properties

/// VideoPlayerViewModel 확장 - 시간 포맷팅 Computed Properties
///
/// ## Extension
/// - 기존 클래스에 기능 추가
/// - 원본 코드 수정 없이 메서드/속성 추가
///
/// **이 Extension의 목적:**
/// - 시간(TimeInterval)을 "MM:SS" 형식 문자열로 변환
/// - View에서 직접 사용 가능한 문자열 제공
extension VideoPlayerViewModel {
    /// 현재 시간을 포맷팅한 문자열 (MM:SS)
    ///
    /// ## 포맷 예시
    /// ```swift
    /// currentTime = 0.0    → "00:00"
    /// currentTime = 5.5    → "00:05"
    /// currentTime = 65.0   → "01:05"
    /// currentTime = 125.0  → "02:05"
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Text(viewModel.currentTimeString)  // "02:05"
    /// ```
    var currentTimeString: String {
        return formatTime(currentTime)
    }

    /// 전체 재생 시간을 포맷팅한 문자열 (MM:SS)
    ///
    /// ## 포맷 예시
    /// ```swift
    /// duration = 90.0   → "01:30"
    /// duration = 600.0  → "10:00"
    /// duration = 3665.0 → "61:05" (1시간 1분 5초)
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Text("\(viewModel.currentTimeString) / \(viewModel.durationString)")
    /// // "02:05 / 10:00"
    /// ```
    var durationString: String {
        return formatTime(duration)
    }

    /// 남은 시간을 포맷팅한 문자열 (-MM:SS)
    ///
    /// ## 계산
    /// - remaining = duration - currentTime
    /// - 음수 방지: max(0, remaining)
    /// - "-" 접두사 추가
    ///
    /// **포맷 예시:**
    /// ```swift
    /// duration = 90초, currentTime = 30초
    /// remaining = 90 - 30 = 60초
    /// → "-01:00"
    ///
    /// duration = 90초, currentTime = 85초
    /// remaining = 90 - 85 = 5초
    /// → "-00:05"
    ///
    /// duration = 90초, currentTime = 90초
    /// remaining = 90 - 90 = 0초
    /// → "-00:00"
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Text(viewModel.remainingTimeString)  // "-01:00" (남은 시간)
    /// ```
    var remainingTimeString: String {
        let remaining = max(0, duration - currentTime)
        return "-\(formatTime(remaining))"
    }

    /// 재생 속도를 포맷팅한 문자열 (예: "1.0x")
    ///
    /// ## 포맷
    /// - String(format: "%.1fx", playbackSpeed)
    /// - 소수점 1자리 + "x" 접미사
    ///
    /// **포맷 예시:**
    /// ```swift
    /// playbackSpeed = 0.5  → "0.5x"
    /// playbackSpeed = 1.0  → "1.0x"
    /// playbackSpeed = 2.0  → "2.0x"
    /// playbackSpeed = 1.75 → "1.8x" (반올림)
    /// ```
    ///
    /// **View에서 사용:**
    /// ```swift
    /// Menu {
    ///     Button("0.5x") { ... }
    ///     Button("1.0x") { ... }
    ///     Button("2.0x") { ... }
    /// } label: {
    ///     Text(viewModel.playbackSpeedString)  // "1.0x"
    /// }
    /// ```
    var playbackSpeedString: String {
        return String(format: "%.1fx", playbackSpeed)
    }

    /// 시간(TimeInterval)을 "MM:SS" 형식 문자열로 변환
    ///
    /// ## 변환 알고리즘
    /// ```
    /// 1. TimeInterval(Double) → Int 변환 (소수점 버림)
    ///      ↓
    /// 2. 분(minutes) = totalSeconds / 60
    ///      ↓
    /// 3. 초(seconds) = totalSeconds % 60
    ///      ↓
    /// 4. String(format: "%02d:%02d", minutes, seconds)
    /// ```
    ///
    /// ## 포맷 설명
    /// - %02d: 2자리 정수, 앞자리는 0으로 채움
    /// - 예: 5 → "05", 12 → "12"
    ///
    /// - Parameter time: 변환할 시간 (초 단위)
    /// - Returns: "MM:SS" 형식 문자열
    ///
    /// **변환 예시:**
    /// ```swift
    /// formatTime(0.0)    → "00:00"
    /// formatTime(5.7)    → "00:05" (소수점 버림)
    /// formatTime(65.0)   → "01:05" (1분 5초)
    /// formatTime(125.0)  → "02:05" (2분 5초)
    /// formatTime(3665.0) → "61:05" (61분 5초)
    /// ```
    private func formatTime(_ time: TimeInterval) -> String {
        /// 1. TimeInterval(Double) → Int 변환
        ///
        /// ## Int(time)
        /// - 소수점 버림 (truncate)
        /// - 5.7 → 5, 125.9 → 125
        let totalSeconds = Int(time)

        /// 2. 분 계산
        ///
        /// ## totalSeconds / 60
        /// - 정수 나눗셈 (몫만)
        /// - 65 / 60 = 1 (1분)
        /// - 125 / 60 = 2 (2분)
        let minutes = totalSeconds / 60

        /// 3. 초 계산
        ///
        /// ## totalSeconds % 60
        /// - 나머지 연산
        /// - 65 % 60 = 5 (5초)
        /// - 125 % 60 = 5 (5초)
        let seconds = totalSeconds % 60

        /// 4. 포맷팅
        ///
        /// ## String(format: "%02d:%02d", minutes, seconds)
        /// - %02d: 2자리 정수, 앞자리 0 채움
        /// - minutes=1, seconds=5 → "01:05"
        /// - minutes=2, seconds=5 → "02:05"
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
