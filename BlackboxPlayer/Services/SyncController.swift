/// @file SyncController.swift
/// @brief 멀티 채널 동기화 재생 컨트롤러
/// @author BlackboxPlayer Development Team
/// @details 여러 비디오 채널을 동기화하여 재생하는 컨트롤러입니다.
///          마스터 클록을 기준으로 모든 채널을 동기화하고, 드리프트 보정 및 버퍼 관리를 수행합니다.

import Foundation
import Combine
import QuartzCore

/// @class SyncController
/// @brief 멀티 채널 동기화 재생 컨트롤러 클래스
/// @details 여러 비디오 채널을 동기화하여 재생하는 컨트롤러입니다.

 ## 동기화(Synchronization)란?
 - 여러 개의 영상(전방, 후방, 좌측, 우측 카메라)을 같은 시간에 재생하는 것
 - 예: 5초 시점의 전방 영상과 5초 시점의 후방 영상을 동시에 표시
 - 마치 오케스트라 지휘자처럼 모든 악기(채널)의 박자를 맞춤

 ## 마스터 클록(Master Clock)이란?
 - 모든 채널이 참조하는 공통의 시간 기준
 - 시스템 시간(CACurrentMediaTime)을 사용
 - 각 채널은 이 클록에 맞춰 프레임을 표시

 ## 드리프트(Drift)란?
 - 채널 간의 시간 차이가 발생하는 현상
 - 예: 전방 카메라는 5.0초인데 후방 카메라는 5.1초
 - 원인: 디코딩 속도 차이, 버퍼링 지연 등
 - 해결: 드리프트가 50ms 이상이면 감지하여 보정

 ## 주요 기능:
 1. **멀티 채널 관리**: 여러 VideoChannel 객체를 생성하고 제어
 2. **동기화 재생**: 모든 채널을 같은 시간에 재생
 3. **마스터 클록**: CACurrentMediaTime()을 기준으로 시간 관리
 4. **드리프트 보정**: 채널 간 시간 차이 감지 및 보정
 5. **버퍼 모니터링**: 모든 채널의 버퍼 상태 확인
 6. **GPS/G-센서 동기화**: 영상과 센서 데이터 시간 맞춤
 7. **재생 제어**: 재생, 일시정지, 정지, 시크

 ## 사용 예제:
 ```swift
 // 1. 컨트롤러 생성
 let controller = SyncController()

 // 2. 비디오 파일 로드
 let videoFile = VideoFile(...)
 try controller.loadVideoFile(videoFile)

 // 3. 재생 시작
 controller.play()

 // 4. 동기화된 프레임 가져오기
 let frames = controller.getSynchronizedFrames()
 for (position, frame) in frames {
     print("\(position.displayName): \(frame.timestamp)초")
 }

 // 5. 시크
 controller.seekToTime(10.0)  // 10초로 이동

 // 6. 일시정지
 controller.pause()

 // 7. 정지
 controller.stop()
 ```

 ## 동기화 메커니즘:
 ```
 마스터 클록 (시스템 시간)
       ↓
 현재 재생 시간 계산
       ↓
 ┌─────┴─────┬─────────┬─────────┐
 ↓          ↓         ↓         ↓
 전방 채널   후방 채널  좌측 채널  우측 채널
 5.0초      4.98초    5.02초    5.01초
   ↓          ↓         ↓         ↓
 드리프트 감지 (0ms, 20ms, 20ms, 10ms)
   ↓
 50ms 이상이면 보정 필요
 ```

 ## 스레드 안전성:
 - NSLock으로 channels 배열 보호
 - Timer는 메인 스레드에서 실행
 - 각 채널은 자체적으로 스레드 안전
 */
class SyncController: ObservableObject {
    /*
     ObservableObject란?
     - Combine 프레임워크의 프로토콜
     - @Published 속성을 가질 수 있음
     - SwiftUI가 자동으로 UI 업데이트
     - 모든 @Published 속성이 변경되면 objectWillChange 신호 발생
     */

    // MARK: - Published Properties (공개 속성)

    /*
     @Published 속성들:
     - 값이 변경되면 자동으로 구독자들에게 알림
     - SwiftUI View가 자동으로 재렌더링
     - Combine의 Publisher로 동작
     */

    /// @var playbackState
    /// @brief 재생 상태 (Playback State)
    ///
    /// PlaybackState 종류:
    /// - .stopped: 정지됨 (영상 로드 안 됨 또는 재생 종료)
    /// - .playing: 재생 중
    /// - .paused: 일시정지
    ///
    /// 상태 전이:
    /// ```
    /// .stopped
    ///   ↓ loadVideoFile()
    /// .paused
    ///   ↓ play()
    /// .playing
    ///   ↓ pause()
    /// .paused
    ///   ↓ stop()
    /// .stopped
    /// ```
    ///
    /// private(set):
    /// - 외부에서 읽기만 가능
    /// - 이 클래스 내부에서만 변경 가능
    /// - controller.playbackState = .playing // 불가능
    @Published private(set) var playbackState: PlaybackState = .stopped

    /// @var currentTime
    /// @brief 현재 재생 시간 (Current Playback Time)
    ///
    /// TimeInterval = Double (초 단위)
    ///
    /// 모든 채널에 공통으로 적용되는 마스터 시간:
    /// - 0.0 ~ duration 범위
    /// - 마스터 클록으로부터 계산됨
    /// - 모든 채널이 이 시간에 맞춰 프레임 표시
    ///
    /// 계산 방식:
    /// ```
    /// 시작 시간: playbackStartTime = 0.0
    /// 마스터 클록 시작: masterClockStartTime = CACurrentMediaTime()
    ///
    /// 재생 중:
    /// 경과 시간 = CACurrentMediaTime() - masterClockStartTime
    /// 현재 시간 = playbackStartTime + (경과 시간 × 재생 속도)
    ///
    /// 예: 2배속으로 5초 경과
    /// currentTime = 0.0 + (5.0 × 2.0) = 10.0초
    /// ```
    @Published private(set) var currentTime: TimeInterval = 0.0

    /// **재생 위치 (Playback Position)**
    ///
    /// 0.0 ~ 1.0 범위 (비율)
    /// - 0.0 = 시작 (0%)
    /// - 0.5 = 중간 (50%)
    /// - 1.0 = 끝 (100%)
    ///
    /// 계산:
    /// playbackPosition = currentTime / duration
    ///
    /// 용도:
    /// - UI 진행 바(progress bar)에 표시
    /// - 시크 바를 드래그할 때 사용
    ///
    /// 예:
    /// - 10분 영상에서 5분 재생 중
    /// - currentTime = 300.0, duration = 600.0
    /// - playbackPosition = 300.0 / 600.0 = 0.5
    @Published private(set) var playbackPosition: Double = 0.0

    /// **재생 속도 (Playback Speed)**
    ///
    /// 배속 설정:
    /// - 0.5 = 0.5배속 (느림)
    /// - 1.0 = 정상 속도
    /// - 2.0 = 2배속 (빠름)
    /// - 4.0 = 4배속 (더 빠름)
    ///
    /// 주의:
    /// - var (변수): 외부에서 변경 가능
    /// - controller.playbackSpeed = 2.0 // 가능
    /// - 재생 중에도 변경 가능
    /// - 마스터 클록 계산에 바로 반영됨
    @Published var playbackSpeed: Double = 1.0

    /// **버퍼링 중 여부 (Is Buffering)**
    ///
    /// 버퍼링이란?
    /// - 프레임을 미리 디코딩하는 과정
    /// - 버퍼가 비었을 때 일시적으로 재생 멈춤
    ///
    /// true인 경우:
    /// - 하나 이상의 채널 버퍼가 20% 미만
    /// - UI에 "로딩 중" 표시 가능
    ///
    /// false인 경우:
    /// - 모든 채널 버퍼가 충분함
    /// - 정상 재생 중
    @Published private(set) var isBuffering: Bool = false

    // MARK: - Properties (비공개 속성)

    /// **비디오 채널 배열 (Video Channels)**
    ///
    /// [VideoChannel]: VideoChannel 객체들의 배열
    ///
    /// 각 카메라마다 하나의 채널:
    /// - channels[0]: 전방 카메라
    /// - channels[1]: 후방 카메라
    /// - channels[2]: 좌측 카메라
    /// - channels[3]: 우측 카메라
    ///
    /// 스레드 안전성:
    /// - channelsLock으로 보호
    /// - 접근 시 반드시 lock/unlock
    ///
    /// 라이프사이클:
    /// - loadVideoFile(): 채널 생성 및 초기화
    /// - stop(): 채널 제거 및 정리
    private var channels: [VideoChannel] = []

    /// **GPS 서비스 (GPS Service)**
    ///
    /// GPS란? (Global Positioning System)
    /// - 위성을 이용한 위치 측정 시스템
    /// - 위도(latitude), 경도(longitude), 고도(altitude)
    /// - 블랙박스는 주행 중 GPS 데이터 기록
    ///
    /// 역할:
    /// - 영상 메타데이터에서 GPS 데이터 로드
    /// - 현재 재생 시간에 맞는 위치 정보 제공
    /// - 지도 UI에 차량 위치 표시
    ///
    /// private(set):
    /// - 읽기는 public
    /// - 쓰기는 private
    /// - controller.gpsService.getCurrentLocation() // 가능
    private(set) var gpsService: GPSService = GPSService()

    /// **G-센서 서비스 (G-Sensor Service)**
    ///
    /// G-센서란? (Gravity Sensor = Accelerometer)
    /// - 가속도를 측정하는 센서
    /// - X, Y, Z 축의 가속도 값 (m/s²)
    /// - 급가속, 급정거, 급회전 감지
    ///
    /// 역할:
    /// - 영상 메타데이터에서 가속도 데이터 로드
    /// - 현재 재생 시간에 맞는 가속도 정보 제공
    /// - 사고 순간의 충격 강도 분석
    ///
    /// 예:
    /// - 정상 주행: X, Y, Z ≈ 0
    /// - 급정거: Y축 큰 음수 값
    /// - 급회전: X축 큰 값
    /// - 충돌: 모든 축에서 큰 값
    private(set) var gsensorService: GSensorService = GSensorService()

    /// **채널 배열 잠금 (Channels Lock)**
    ///
    /// NSLock으로 channels 배열 보호:
    ///
    /// 왜 필요한가?
    /// - Timer 스레드: channels를 읽음 (getSynchronizedFrames)
    /// - loadVideoFile: channels를 수정 (생성, 초기화)
    /// - stop: channels를 수정 (제거)
    /// - 동시 접근 시 크래시 방지
    ///
    /// 사용 패턴:
    /// ```swift
    /// channelsLock.lock()
    /// defer { channelsLock.unlock() }
    /// // channels 배열 사용...
    /// ```
    ///
    /// 주의:
    /// - lock과 unlock은 쌍으로
    /// - defer로 자동 unlock 권장
    /// - lock 중에 다른 lock 호출 금지 (데드락)
    private let channelsLock = NSLock()

    /// **총 재생 시간 (Total Duration)**
    ///
    /// TimeInterval = Double (초 단위)
    ///
    /// 가장 긴 채널의 길이:
    /// - 4개 채널 길이: 59.8초, 60.0초, 59.9초, 60.0초
    /// - duration = 60.0초 (최댓값)
    ///
    /// 용도:
    /// - currentTime의 최댓값
    /// - playbackPosition 계산 (currentTime / duration)
    /// - UI에 총 시간 표시 (예: "01:00")
    ///
    /// private(set):
    /// - 외부에서 읽기 가능
    /// - controller.duration // 가능
    private(set) var duration: TimeInterval = 0.0

    /// **마스터 클록 시작 시간 (Master Clock Start Time)**
    ///
    /// CFTimeInterval = Double (초 단위)
    ///
    /// CACurrentMediaTime()이란?
    /// - Core Animation의 절대 시간
    /// - 시스템 부팅 후 경과 시간
    /// - 정확하고 일정한 증가
    /// - 매우 정밀 (나노초 단위)
    ///
    /// 역할:
    /// - play() 호출 시 기록: masterClockStartTime = CACurrentMediaTime()
    /// - 현재 시간 계산: elapsedTime = CACurrentMediaTime() - masterClockStartTime
    ///
    /// 예:
    /// ```
    /// play() 호출 시점:
    /// masterClockStartTime = 12345.678 (시스템 시간)
    /// playbackStartTime = 0.0 (비디오 시간)
    ///
    /// 5초 후:
    /// CACurrentMediaTime() = 12350.678
    /// elapsedTime = 12350.678 - 12345.678 = 5.0초
    /// currentTime = 0.0 + (5.0 × 1.0) = 5.0초
    /// ```
    private var masterClockStartTime: CFTimeInterval = 0.0

    /// **재생 시작 시간 (Playback Start Time)**
    ///
    /// play()를 호출했을 때의 비디오 시간:
    ///
    /// 왜 필요한가?
    /// - 중간부터 재생할 수 있기 때문
    /// - 예: 10초에서 일시정지 → 20초로 시크 → 재생
    /// - playbackStartTime = 20.0
    ///
    /// 시간 계산:
    /// ```
    /// currentTime = playbackStartTime + (경과 시간 × 재생 속도)
    /// ```
    ///
    /// 예 1: 처음부터 재생
    /// - playbackStartTime = 0.0
    /// - 5초 경과 → currentTime = 0.0 + 5.0 = 5.0초
    ///
    /// 예 2: 10초에서 재생
    /// - playbackStartTime = 10.0
    /// - 5초 경과 → currentTime = 10.0 + 5.0 = 15.0초
    private var playbackStartTime: TimeInterval = 0.0

    /// **동기화 타이머 (Sync Timer)**
    ///
    /// Timer란?
    /// - 일정 간격으로 반복 실행되는 타이머
    /// - 메인 스레드의 Run Loop에서 실행
    ///
    /// 역할:
    /// - 30fps (1초에 30번) 실행
    /// - updateSync() 호출
    /// - currentTime 업데이트
    /// - 드리프트 감지
    /// - 버퍼 상태 확인
    ///
    /// 라이프사이클:
    /// - play(): startSyncTimer() → 타이머 생성 및 시작
    /// - pause(): stopSyncTimer() → 타이머 중단
    /// - stop(): stopSyncTimer() → 타이머 제거
    ///
    /// Optional(?):
    /// - nil: 타이머 없음 (정지 또는 일시정지 중)
    /// - Timer: 타이머 실행 중 (재생 중)
    private var syncTimer: Timer?

    /// **드리프트 임계값 (Drift Threshold)**
    ///
    /// 50밀리초 = 0.050초
    ///
    /// 드리프트 감지 기준:
    /// - 채널의 프레임 시간과 마스터 시간의 차이
    /// - 50ms 이상이면 "드리프트 발생"으로 판단
    ///
    /// 왜 50ms인가?
    /// - 사람의 인지 한계: 약 50~100ms
    /// - 50ms 이하: 눈으로 구분 어려움
    /// - 50ms 이상: 싱크가 안 맞는 것처럼 보임
    ///
    /// 예:
    /// ```
    /// currentTime = 5.0초
    /// 전방 채널 프레임 = 5.0초 → 드리프트 0ms (OK)
    /// 후방 채널 프레임 = 5.06초 → 드리프트 60ms (NG)
    /// ```
    ///
    /// let (상수):
    /// - 변경 불가능
    /// - 컴파일 타임 최적화
    private let driftThreshold: TimeInterval = 0.050 // 50ms

    /// **동기화 확인 간격 (Sync Check Interval)**
    ///
    /// 100밀리초 = 0.1초
    ///
    /// 현재는 사용하지 않음 (targetFrameRate 사용):
    /// - 이전에는 이 간격으로 동기화 확인
    /// - 현재는 30fps (약 33ms 간격)으로 더 자주 확인
    ///
    /// 남겨둔 이유:
    /// - 향후 성능 최적화 시 사용 가능
    /// - 30fps가 너무 부담스러우면 10fps (100ms)로 변경 가능
    private let syncCheckInterval: TimeInterval = 0.1 // 100ms

    /// **목표 프레임 레이트 (Target Frame Rate)**
    ///
    /// 30.0 FPS (Frames Per Second)
    ///
    /// 프레임 레이트란?
    /// - 1초에 몇 번 화면을 업데이트하는가
    /// - 30fps = 1초에 30번 = 약 33ms마다 1번
    ///
    /// 타이머 간격 계산:
    /// ```
    /// interval = 1.0 / 30.0 = 0.0333...초 = 33.3ms
    /// ```
    ///
    /// 왜 30fps인가?
    /// - 일반 영상의 표준 프레임 레이트
    /// - 부드러운 재생과 성능의 균형
    /// - 60fps: 더 부드럽지만 CPU 부담 2배
    /// - 24fps: 영화 표준이지만 조금 덜 부드러움
    ///
    /// 용도:
    /// - syncTimer의 실행 간격 결정
    /// - updateSync() 호출 빈도
    private let targetFrameRate: Double = 30.0

    // MARK: - Initialization (초기화)

    /**
     동기화 컨트롤러를 생성합니다.

     빈 초기화:
     - 초기 설정 없음
     - 채널 배열은 비어있음
     - loadVideoFile()로 채널 로드 필요

     사용 예:
     ```swift
     let controller = SyncController()
     try controller.loadVideoFile(videoFile)
     controller.play()
     ```
     */
    init() {
        // 빈 초기화
        // 모든 속성은 선언 시 기본값이 있음
    }

    /**
     deinit (디이니셜라이저)

     메모리 해제 시 정리 작업:
     - stop() 호출
     - 타이머 중단
     - 채널 정리
     - 서비스 정리

     자동 호출:
     - controller = nil
     - 참조 카운트 0이 되면 자동 호출
     */
    deinit {
        stop()
    }

    // MARK: - Public Methods (공개 메서드)

    /**
     여러 채널을 가진 비디오 파일을 로드합니다.

     로드 과정:
     1. 현재 재생 중단 (stop)
     2. 각 채널에 대해 VideoChannel 생성
     3. 각 채널 초기화 (VideoDecoder 생성)
     4. 채널 배열에 저장
     5. 총 재생 시간 설정
     6. GPS, G-센서 데이터 로드
     7. 재생 상태를 .paused로 설정

     파라미터:
     - videoFile: 로드할 비디오 파일
       - channels: 채널 정보 배열
       - duration: 총 재생 시간
       - metadata: GPS, G-센서 데이터
       - timestamp: 녹화 시작 시간

     사용 예:
     ```swift
     let videoFile = VideoFile(
         name: "2025-01-12_14-30-00",
         channels: [
             ChannelInfo(position: .front, filePath: "front.mp4"),
             ChannelInfo(position: .rear, filePath: "rear.mp4")
         ],
         duration: 60.0,
         metadata: ...
     )

     do {
         try controller.loadVideoFile(videoFile)
         print("로드 성공!")
         print("채널 수: \(controller.channelCount)")
         print("재생 시간: \(controller.duration)초")
     } catch {
         print("로드 실패: \(error)")
     }
     ```

     채널 활성화:
     - isEnabled가 true인 채널만 로드
     - 사용자가 특정 채널을 비활성화할 수 있음
     - 예: 전방, 후방만 보고 싶을 때 좌우 비활성화

     에러:
     - ChannelError.invalidState: 활성화된 채널이 없음
     - DecoderError: 채널 초기화 실패

     - Throws: ChannelError 또는 DecoderError
     */
    func loadVideoFile(_ videoFile: VideoFile) throws {
        // 1. 현재 재생 중단
        // - 기존에 로드된 채널들 정리
        // - 타이머 중단
        // - 상태 초기화
        stop()

        // 2. 새 채널 배열 생성
        var newChannels: [VideoChannel] = []
        // 임시 배열: 모든 채널 초기화 성공 후 channels에 저장

        // 3. 각 채널 생성 및 초기화
        // for-in with where: 조건에 맞는 요소만 반복
        for channelInfo in videoFile.channels where channelInfo.isEnabled {
            // channelInfo.isEnabled가 true인 것만 처리

            // 3-1. VideoChannel 생성
            let channel = VideoChannel(channelInfo: channelInfo)
            // channelInfo: position, filePath, displayName

            // 3-2. 채널 초기화
            // - VideoDecoder 생성
            // - FFmpeg으로 파일 열기
            // - 스트림 찾기, 코덱 초기화
            try channel.initialize()
            // 에러 발생 시 함수 종료, 호출자에게 에러 전달

            // 3-3. 임시 배열에 추가
            newChannels.append(channel)
        }

        // 4. 채널이 하나도 없으면 에러
        guard !newChannels.isEmpty else {
            // 모든 채널이 비활성화되었거나
            // videoFile.channels가 비어있는 경우
            throw ChannelError.invalidState("No enabled channels found")
        }

        // 5. 채널 배열에 저장 (스레드 안전)
        channelsLock.lock()
        // 다른 스레드가 channels에 접근 못하도록 잠금
        self.channels = newChannels
        // 채널 배열 교체
        channelsLock.unlock()
        // 잠금 해제

        // 6. 총 재생 시간 설정
        self.duration = videoFile.duration
        // 가장 긴 채널의 길이

        // 7. GPS 데이터 로드
        // - metadata: GPS 좌표 배열 + 타임스탬프
        // - startTime: 녹화 시작 시간 (Date)
        // - GPS 데이터를 재생 시간과 매칭
        gpsService.loadGPSData(from: videoFile.metadata, startTime: videoFile.timestamp)

        // 8. G-센서 데이터 로드
        // - metadata: 가속도 값 배열 + 타임스탬프
        // - startTime: 녹화 시작 시간
        // - 가속도 데이터를 재생 시간과 매칭
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        // 9. 재생 상태 초기화
        currentTime = 0.0
        playbackPosition = 0.0
        playbackState = .paused
        // 로드 완료, 재생 준비됨

        // 성공적으로 로드 완료
        // play() 호출 가능
    }

    /**
     동기화된 재생을 시작합니다.

     재생 시작 과정:
     1. 이미 재생 중이면 무시
     2. 채널이 있는지 확인
     3. 모든 채널의 디코딩 시작
     4. 마스터 클록 시작 시간 기록
     5. 재생 시작 시간 기록
     6. 상태를 .playing으로 변경
     7. 동기화 타이머 시작

     마스터 클록 설정:
     ```
     masterClockStartTime = CACurrentMediaTime()
     playbackStartTime = currentTime

     예: currentTime = 10.0초에서 재생 시작
     - masterClockStartTime = 12345.678 (시스템 시간)
     - playbackStartTime = 10.0 (비디오 시간)

     3초 후:
     - CACurrentMediaTime() = 12348.678
     - elapsedTime = 12348.678 - 12345.678 = 3.0
     - currentTime = 10.0 + 3.0 = 13.0초
     ```

     사용 예:
     ```swift
     // 처음부터 재생
     try controller.loadVideoFile(videoFile)
     controller.play()

     // 중간부터 재생
     controller.seekToTime(30.0)  // 30초로 이동
     controller.play()            // 30초부터 재생 시작

     // 일시정지 후 재개
     controller.pause()
     // ... 잠시 후 ...
     controller.play()  // 멈췄던 위치부터 재생
     ```

     동기화 메커니즘:
     - 모든 채널은 독립적으로 디코딩
     - syncTimer가 주기적으로 currentTime 업데이트
     - 각 채널은 getFrame(at: currentTime) 호출
     - 마스터 시간에 가장 가까운 프레임 표시

     주의사항:
     - loadVideoFile()을 먼저 호출해야 함
     - 채널이 없으면 재생 안 됨
     - 이미 재생 중이면 무시됨
     */
    func play() {
        // 1. 이미 재생 중이면 무시
        guard playbackState != .playing else {
            return
        }

        // 2. 채널 확인 (스레드 안전)
        channelsLock.lock()
        // 잠금

        let isEmpty = channels.isEmpty
        // 채널이 있는지 확인

        let channelsCopy = channels
        // 배열 복사: lock 해제 후 사용하기 위해
        // 참조 복사 (얕은 복사): 같은 VideoChannel 객체를 가리킴
        // lock 해제 후 안전하게 사용 가능

        channelsLock.unlock()
        // 잠금 해제 (최대한 빨리)

        // 3. 채널이 없으면 경고 후 종료
        guard !isEmpty else {
            warningLog("[SyncController] Cannot play: no channels loaded")
            // 로그 출력: 채널이 로드되지 않음
            return
        }

        // 4. 재생 시작 로그
        infoLog("[SyncController] Starting playback with \(channelsCopy.count) channels")
        // 예: "Starting playback with 4 channels"

        // 5. 모든 채널의 디코딩 시작
        for channel in channelsCopy {
            infoLog("[SyncController] Starting decoding for channel: \(channel.channelInfo.position.displayName)")
            // 예: "Starting decoding for channel: 전방 카메라"

            channel.startDecoding()
            // 백그라운드에서 프레임 디코딩 시작
            // 각 채널은 독립적으로 디코딩
            // 버퍼에 프레임 쌓임
        }

        // 6. 마스터 클록 설정
        masterClockStartTime = CACurrentMediaTime()
        // 시스템 시간 기록
        // 예: 12345.678초 (시스템 부팅 후 경과 시간)

        playbackStartTime = currentTime
        // 현재 비디오 시간 기록
        // 처음: 0.0, 중간부터: 시크한 위치

        // 7. 상태 변경
        playbackState = .playing
        // @Published이므로 UI 자동 업데이트
        // SwiftUI에서 재생 버튼 → 일시정지 버튼으로 변경

        // 8. 동기화 타이머 시작
        startSyncTimer()
        // 30fps로 updateSync() 반복 호출
        // currentTime 업데이트
        // 드리프트 감지
        // 버퍼 상태 확인

        // 재생 시작 완료
        // Timer가 백그라운드에서 계속 실행 중
    }

    /**
     동기화된 재생을 일시정지합니다.

     일시정지 과정:
     1. 재생 중이 아니면 무시
     2. 상태를 .paused로 변경
     3. 동기화 타이머 중단

     주의:
     - 채널의 디코딩은 계속됨 (중단 안 함)
     - 버퍼는 계속 채워짐
     - 타이머만 멈춰서 currentTime이 증가 안 함
     - 화면은 마지막 프레임에 멈춤

     재개:
     - play() 다시 호출
     - 멈췄던 위치부터 재생

     사용 예:
     ```swift
     controller.play()   // 재생 시작
     // ... 재생 중 ...
     controller.pause()  // 일시정지
     // ... 멈춤 ...
     controller.play()   // 재개 (멈췄던 위치부터)
     ```
     */
    func pause() {
        // 1. 재생 중이 아니면 무시
        guard playbackState == .playing else {
            return
        }

        // 2. 상태 변경
        playbackState = .paused
        // @Published이므로 UI 자동 업데이트

        // 3. 타이머 중단
        stopSyncTimer()
        // Timer 무효화 및 제거
        // updateSync() 호출 중단
        // currentTime 증가 멈춤

        // 일시정지 완료
        // 채널 디코딩은 계속됨 (버퍼링 계속)
        // 화면은 현재 프레임에 멈춤
    }

    /**
     재생과 일시정지를 토글합니다.

     토글(Toggle)이란?
     - 두 상태를 번갈아 전환
     - 스위치를 켜고 끄는 것

     동작:
     - .playing → pause() → .paused
     - .paused → play() → .playing
     - .stopped → play() → .playing

     사용 예:
     ```swift
     // 스페이스바 키 누름
     controller.togglePlayPause()
     ```

     UI 버튼:
     - 재생/일시정지 버튼 하나로 양쪽 기능
     - 클릭 시 togglePlayPause() 호출
     */
    func togglePlayPause() {
        if playbackState == .playing {
            // 재생 중이면 → 일시정지
            pause()
        } else {
            // 일시정지 또는 정지 중이면 → 재생
            play()
        }
    }

    /**
     재생을 중단하고 모든 상태를 초기화합니다.

     정지 과정:
     1. 동기화 타이머 중단
     2. 모든 채널 중단 및 제거
     3. GPS, G-센서 데이터 정리
     4. 재생 상태 초기화

     stop() vs pause():
     - pause: 일시정지, 재개 가능
     - stop: 완전 중단, 처음부터 다시 시작

     메모리 정리:
     - 모든 채널의 디코더 해제
     - 버퍼 비우기
     - 서비스 데이터 정리

     사용 시점:
     - 영상 종료
     - 다른 영상 로드
     - 앱 종료 준비

     사용 예:
     ```swift
     controller.play()
     // ... 재생 중 ...
     controller.stop()  // 정지

     // 상태 확인
     print(controller.playbackState)     // .stopped
     print(controller.currentTime)       // 0.0
     print(controller.channelCount)      // 0
     ```
     */
    func stop() {
        // 1. 타이머 중단
        stopSyncTimer()
        // Timer 무효화 및 제거
        // updateSync() 호출 중단

        // 2. 채널 배열 복사 및 제거 (스레드 안전)
        channelsLock.lock()

        let channelsCopy = channels
        // 배열 복사: lock 해제 후 사용

        channels.removeAll()
        // 배열 비우기
        // 참조 카운트 감소
        // 다른 참조가 없으면 메모리 해제 시작

        channelsLock.unlock()

        // 3. 각 채널 중단 (lock 밖에서)
        for channel in channelsCopy {
            channel.stop()
            // - 디코딩 중단
            // - 버퍼 비우기
            // - 디코더 해제
            // - 메모리 정리
        }

        // 4. GPS, G-센서 데이터 정리
        gpsService.clear()
        // GPS 데이터 배열 비우기

        gsensorService.clear()
        // 가속도 데이터 배열 비우기

        // 5. 재생 상태 초기화
        playbackState = .stopped
        currentTime = 0.0
        playbackPosition = 0.0
        duration = 0.0
        // @Published 속성들: UI 자동 업데이트

        // 정지 완료
        // 메모리 사용량 최소화
        // 다시 loadVideoFile() 호출 가능
    }

    /**
     모든 채널을 특정 시간으로 이동합니다.

     시크(Seek)란?
     - 영상의 특정 위치로 점프
     - 진행 바를 드래그하는 것

     시크 과정:
     1. 시간을 유효한 범위로 제한 (0 ~ duration)
     2. 재생 중이면 일시정지
     3. 모든 채널을 새 위치로 시크
     4. currentTime, playbackPosition 업데이트
     5. GPS, G-센서 데이터도 새 위치로 업데이트
     6. 원래 재생 중이었으면 재개

     시간 제한 (Clamping):
     ```
     입력 시간: -5.0  → 제한: 0.0 (음수 불가)
     입력 시간: 30.0  → 제한: 30.0 (정상)
     입력 시간: 100.0 → 제한: 60.0 (duration 초과 불가)
     ```

     파라미터:
     - time: 이동할 시간 (초 단위)

     사용 예:
     ```swift
     // 10초로 이동
     controller.seekToTime(10.0)

     // 처음으로 이동
     controller.seekToTime(0.0)

     // 끝으로 이동
     controller.seekToTime(controller.duration)

     // 중간으로 이동
     controller.seekToTime(controller.duration / 2)
     ```

     UI 연동:
     ```swift
     // Slider (진행 바)
     Slider(value: $seekPosition, in: 0...controller.duration)
         .onChange(of: seekPosition) { newValue in
             controller.seekToTime(newValue)
         }
     ```

     채널 시크:
     - 각 채널은 독립적으로 시크
     - VideoDecoder의 av_seek_frame() 호출
     - 키프레임(I-frame)으로 이동
     - 버퍼 비우고 새 위치부터 디코딩

     주의:
     - 시크는 키프레임 단위로만 가능
     - 정확히 원하는 시간이 아닐 수 있음
     - ±1초 정도 오차 가능
     */
    func seekToTime(_ time: TimeInterval) {
        // 1. 시간을 유효한 범위로 제한
        let clampedTime = max(0.0, min(duration, time))
        // max(0.0, time): 0 이상
        // min(duration, time): duration 이하
        // 결과: 0 ~ duration 범위

        // 2. 재생 상태 저장 및 일시정지
        let wasPlaying = playbackState == .playing
        // 재생 중이었는지 기억

        if wasPlaying {
            pause()
            // 시크 중에는 일시정지
            // 타이머 중단
        }

        // 3. 채널 배열 복사 (스레드 안전)
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        // 4. 모든 채널 시크
        for channel in channelsCopy {
            do {
                try channel.seek(to: clampedTime)
                // VideoDecoder.seek() 호출
                // FFmpeg av_seek_frame()
                // 버퍼 비우기
                // 새 위치부터 디코딩 준비
            } catch {
                // 시크 실패 (파일 손상 등)
                print("Failed to seek channel \(channel.channelInfo.position.displayName): \(error)")
                // 에러 로그만 출력, 계속 진행
            }
        }

        // 5. 현재 시간 업데이트
        currentTime = clampedTime
        playbackPosition = duration > 0 ? clampedTime / duration : 0.0
        // 예: 30초 / 60초 = 0.5 (50%)

        // 6. GPS, G-센서 데이터 업데이트
        gpsService.getCurrentLocation(at: clampedTime)
        // 새 시간의 GPS 위치
        // 지도에 차량 위치 업데이트

        gsensorService.getCurrentAcceleration(at: clampedTime)
        // 새 시간의 가속도 값
        // G-센서 그래프 업데이트

        // 7. 재생 재개 (필요한 경우)
        if wasPlaying {
            // 원래 재생 중이었으면
            play()
            // 새 위치부터 재생 시작
            // 마스터 클록 재설정
        }

        // 시크 완료
        // 화면에 새 시간의 프레임 표시
    }

    /**
     상대적인 시간만큼 이동합니다.

     상대 시크 (Relative Seek):
     - 현재 위치에서 앞뒤로 이동
     - seekToTime(currentTime + seconds)

     파라미터:
     - seconds: 이동할 초
       - 양수: 앞으로 (빨리감기)
       - 음수: 뒤로 (되감기)

     사용 예:
     ```swift
     // 10초 앞으로
     controller.seekBySeconds(10.0)

     // 5초 뒤로
     controller.seekBySeconds(-5.0)

     // 키보드 단축키
     // 방향키 →: seekBySeconds(10.0)
     // 방향키 ←: seekBySeconds(-10.0)
     ```

     UI 버튼:
     ```
     [<<] [-10초] [재생/정지] [+10초] [>>]
     ```
     */
    func seekBySeconds(_ seconds: Double) {
        seekToTime(currentTime + seconds)
        // 현재 시간 + 초 = 새 시간
        // seekToTime()이 자동으로 범위 제한
    }

    /**
     현재 시간의 모든 채널 프레임을 가져옵니다.

     동기화된 프레임:
     - currentTime에 가장 가까운 프레임들
     - 각 채널마다 하나씩
     - 딕셔너리로 반환 (카메라 위치 → 프레임)

     반환값:
     - [CameraPosition: VideoFrame]
     - 키: .front, .rear, .left, .right, .interior
     - 값: VideoFrame (픽셀 데이터, 타임스탬프 등)

     사용 예:
     ```swift
     let frames = controller.getSynchronizedFrames()

     // 전방 카메라 프레임
     if let frontFrame = frames[.front] {
         print("전방: \(frontFrame.timestamp)초")
         // frontFrame.pixelBuffer로 화면에 그리기
     }

     // 모든 채널 순회
     for (position, frame) in frames {
         print("\(position.displayName): \(frame.timestamp)초")
     }
     ```

     렌더링 파이프라인:
     ```
     getSynchronizedFrames()
       ↓
     [.front: Frame(5.0s), .rear: Frame(5.02s)]
       ↓
     MultiChannelRenderer
       ↓
     Metal 렌더링
       ↓
     화면 표시
     ```

     빈 딕셔너리 반환:
     - 채널이 없음
     - 버퍼가 비어있음 (아직 디코딩 안 됨)

     - Returns: 카메라 위치별 프레임 딕셔너리
     */
    func getSynchronizedFrames() -> [CameraPosition: VideoFrame] {
        // 1. 채널 배열 복사 (스레드 안전)
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        // 2. 결과 딕셔너리 생성
        var frames: [CameraPosition: VideoFrame] = [:]
        // 빈 딕셔너리로 시작

        // 3. 각 채널에서 프레임 가져오기
        for channel in channelsCopy {
            // getFrame(at:): currentTime에 가장 가까운 프레임
            if let frame = channel.getFrame(at: currentTime) {
                // 프레임을 찾았으면
                frames[channel.channelInfo.position] = frame
                // 딕셔너리에 추가
                // 예: frames[.front] = frontFrame
            }
            // 프레임 없으면 (버퍼 비어있음) 무시
        }

        // 4. 결과 반환
        return frames
        // 예: [.front: Frame1, .rear: Frame2]

        // 렌더러가 이 프레임들을 화면에 그림
    }

    /**
     모든 채널의 버퍼 상태를 가져옵니다.

     버퍼 상태 정보:
     - current: 현재 버퍼에 있는 프레임 수
     - max: 최대 버퍼 크기 (30)
     - fillPercentage: 채움 비율 (0.0 ~ 1.0)

     반환값:
     - [CameraPosition: (current, max, fillPercentage)]
     - 카메라 위치별 버퍼 상태 튜플

     사용 예:
     ```swift
     let status = controller.getBufferStatus()

     // 전방 카메라 버퍼 상태
     if let frontStatus = status[.front] {
         print("전방 버퍼: \(frontStatus.current)/\(frontStatus.max)")
         print("채움율: \(frontStatus.fillPercentage * 100)%")

         if frontStatus.fillPercentage < 0.2 {
             print("버퍼 부족!")
         }
     }

     // 모든 채널 확인
     for (position, bufferStatus) in status {
         print("\(position.displayName): \(Int(bufferStatus.fillPercentage * 100))%")
     }
     ```

     UI 표시:
     ```
     전방: ████████░░ 80%
     후방: ██████████ 100%
     좌측: ████░░░░░░ 40%
     우측: ██████░░░░ 60%
     ```

     버퍼 부족 감지:
     - 20% 미만: 로딩 표시
     - 100%: 정상 재생
     - 0%: 버퍼 비어있음 (초기 상태)

     - Returns: 카메라 위치별 버퍼 상태 딕셔너리
     */
    func getBufferStatus() -> [CameraPosition: (current: Int, max: Int, fillPercentage: Double)] {
        // 1. 채널 배열 복사 (스레드 안전)
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        // 2. 결과 딕셔너리 생성
        var status: [CameraPosition: (current: Int, max: Int, fillPercentage: Double)] = [:]

        // 3. 각 채널의 버퍼 상태 가져오기
        for channel in channelsCopy {
            status[channel.channelInfo.position] = channel.getBufferStatus()
            // VideoChannel.getBufferStatus() 호출
            // 튜플 반환: (current, max, fillPercentage)
        }

        // 4. 결과 반환
        return status
    }

    /// **채널 수 (Channel Count)**
    ///
    /// computed property (계산 속성):
    /// - 값을 저장하지 않음
    /// - 호출 시마다 계산
    ///
    /// 스레드 안전:
    /// - lock/unlock 사용
    /// - defer로 자동 unlock
    ///
    /// 사용 예:
    /// ```swift
    /// print("채널 수: \(controller.channelCount)")
    /// // 4
    /// ```
    var channelCount: Int {
        channelsLock.lock()
        defer { channelsLock.unlock() }
        return channels.count
    }

    /// **모든 채널이 준비되었는지 확인**
    ///
    /// 준비된 상태:
    /// - .ready: 초기화 완료, 디코딩 시작 가능
    /// - .decoding: 디코딩 중
    ///
    /// 준비 안 된 상태:
    /// - .idle: 초기화 안 됨
    /// - .error: 에러 발생
    /// - .completed: 완료 (파일 끝)
    ///
    /// allSatisfy:
    /// - 모든 요소가 조건을 만족하는지 확인
    /// - true: 모든 채널이 .ready 또는 .decoding
    /// - false: 하나라도 다른 상태
    ///
    /// 사용 예:
    /// ```swift
    /// if controller.allChannelsReady {
    ///     print("재생 가능!")
    ///     controller.play()
    /// } else {
    ///     print("준비 중...")
    /// }
    /// ```
    var allChannelsReady: Bool {
        channelsLock.lock()
        defer { channelsLock.unlock() }

        // 채널이 하나라도 있어야 하고
        // 모든 채널이 .ready 또는 .decoding 상태여야 함
        return !channels.isEmpty && channels.allSatisfy { channel in
            channel.state == .ready || channel.state == .decoding
        }
    }

    // MARK: - Private Methods (비공개 메서드)

    /**
     동기화 타이머를 시작합니다.

     타이머 생성:
     - 30fps = 1초에 30번 = 약 33.3ms마다
     - updateSync() 반복 호출
     - 메인 스레드의 Run Loop에서 실행

     Timer.scheduledTimer:
     - withTimeInterval: 실행 간격
     - repeats: true = 반복 실행
     - [weak self]: 순환 참조 방지

     동작 순서:
     1. 기존 타이머 중단 (있으면)
     2. 간격 계산 (1.0 / 30.0)
     3. 타이머 생성 및 시작
     4. 자동으로 Run Loop에 추가됨
     */
    private func startSyncTimer() {
        // 1. 기존 타이머 중단
        stopSyncTimer()
        // 이미 실행 중인 타이머가 있으면 중단
        // 중복 방지

        // 2. 간격 계산
        let interval = 1.0 / targetFrameRate
        // 1.0 / 30.0 = 0.0333...초 = 33.3ms

        // 3. 타이머 생성
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // [weak self]: 순환 참조 방지
            // Timer가 self를 약하게 참조
            // self가 해제되면 Timer도 자동 정리

            self?.updateSync()
            // updateSync() 호출
            // currentTime 업데이트
            // 드리프트 감지
            // 버퍼 상태 확인
        }

        // 타이머가 자동으로 메인 Run Loop에 추가됨
        // 백그라운드에서 계속 실행
    }

    /**
     동기화 타이머를 중단합니다.

     타이머 정리:
     - invalidate(): 타이머 무효화
     - nil: 메모리 해제

     호출 시점:
     - pause()
     - stop()
     - startSyncTimer() (새 타이머 생성 전)

     주의:
     - invalidate() 후에는 재사용 불가
     - 다시 시작하려면 새 Timer 생성 필요
     */
    private func stopSyncTimer() {
        // 1. 타이머 무효화
        syncTimer?.invalidate()
        // Timer 중단
        // Run Loop에서 제거
        // 더 이상 updateSync() 호출 안 됨

        // 2. nil로 설정
        syncTimer = nil
        // Optional을 nil로
        // 메모리 해제
    }

    /**
     동기화 상태를 업데이트합니다.

     타이머가 30fps로 호출:
     - 약 33ms마다 실행
     - 재생 중일 때만 동작

     업데이트 과정:
     1. 마스터 클록에서 현재 시간 계산
     2. currentTime, playbackPosition 업데이트
     3. GPS, G-센서 데이터 업데이트
     4. 파일 끝 도달 확인
     5. 드리프트 감지 및 보정
     6. 버퍼 상태 확인

     마스터 클록 계산:
     ```
     elapsedTime = CACurrentMediaTime() - masterClockStartTime
     videoTime = playbackStartTime + (elapsedTime × playbackSpeed)

     예: 2배속으로 5초 경과
     - masterClockStartTime = 12345.0
     - playbackStartTime = 0.0
     - CACurrentMediaTime() = 12350.0
     - elapsedTime = 5.0
     - videoTime = 0.0 + (5.0 × 2.0) = 10.0초
     ```

     자동 정지:
     - currentTime >= duration이면 stop() 호출
     - 파일 끝에 도달
     */
    private func updateSync() {
        // 1. 재생 중인지 확인
        guard playbackState == .playing else {
            return  // 재생 중이 아니면 무시
        }

        // 2. 마스터 클록에서 현재 시간 계산
        let elapsedTime = CACurrentMediaTime() - masterClockStartTime
        // 재생 시작부터 지금까지 경과 시간 (초)

        let videoTime = playbackStartTime + (elapsedTime * playbackSpeed)
        // 재생 시작 시간 + (경과 시간 × 재생 속도)
        // playbackSpeed가 2.0이면 2배 빠르게 증가

        // 3. 현재 시간 업데이트
        currentTime = videoTime
        playbackPosition = duration > 0 ? currentTime / duration : 0.0
        // @Published 속성: UI 자동 업데이트

        // 4. GPS, G-센서 데이터 업데이트
        gpsService.getCurrentLocation(at: currentTime)
        // 현재 시간의 GPS 위치
        // 지도에 차량 위치 업데이트

        gsensorService.getCurrentAcceleration(at: currentTime)
        // 현재 시간의 가속도 값
        // G-센서 그래프 업데이트

        // 5. 파일 끝 도달 확인
        if currentTime >= duration {
            // 영상 끝에 도달
            stop()
            // 재생 중단
            // 타이머 중단
            // 채널 정리

            currentTime = duration
            playbackPosition = 1.0
            // 정확히 끝 위치로 설정
            return
        }

        // 6. 드리프트 감지 및 보정
        checkAndCorrectDrift()
        // 채널 간 시간 차이 확인
        // 50ms 이상이면 로그 출력

        // 7. 버퍼 상태 확인
        checkBufferStatus()
        // 버퍼가 20% 미만이면 isBuffering = true
    }

    /**
     채널 간 드리프트를 감지하고 보정합니다.

     드리프트(Drift)란?
     - 채널의 프레임 시간과 마스터 시간의 차이
     - 디코딩 속도 차이로 발생
     - 50ms 이상이면 감지

     감지 과정:
     1. 모든 채널의 현재 프레임 가져오기
     2. 각 프레임의 타임스탬프와 currentTime 비교
     3. 차이가 driftThreshold(50ms) 이상이면 로그

     보정 (현재는 로그만):
     - 프로덕션에서는 프레임 스킵/대기 로직 구현
     - 드리프트가 크면 채널 재시크
     - 버퍼 관리 개선

     예:
     ```
     currentTime = 5.0초
     전방 프레임 = 5.0초 → 드리프트 0ms (OK)
     후방 프레임 = 5.06초 → 드리프트 60ms (NG)
     "Channel 후방 카메라 drift detected: 60ms"
     ```
     */
    private func checkAndCorrectDrift() {
        // 1. 모든 채널의 프레임 가져오기
        let frames = getSynchronizedFrames()
        // 각 채널의 currentTime에 가장 가까운 프레임

        // 2. 각 채널의 드리프트 계산
        for (position, frame) in frames {
            // position: 카메라 위치
            // frame: 해당 채널의 프레임

            let drift = abs(frame.timestamp - currentTime)
            // abs: 절댓값
            // 프레임 시간과 마스터 시간의 차이

            // 3. 드리프트가 임계값 초과하면 로그
            if drift > driftThreshold {
                // 50ms 초과
                print("Channel \(position.displayName) drift detected: \(Int(drift * 1000))ms")
                // 밀리초로 변환하여 표시
                // 예: "Channel 후방 카메라 drift detected: 60ms"

                // TODO: 프로덕션에서는 보정 로직 구현
                // - 프레임 스킵: 너무 느린 채널
                // - 프레임 대기: 너무 빠른 채널
                // - 재시크: 드리프트가 너무 큰 경우
            }
        }
    }

    /**
     모든 채널의 버퍼 상태를 확인합니다.

     버퍼 부족 감지:
     - 하나 이상의 채널 버퍼가 20% 미만
     - isBuffering = true 설정
     - UI에 "로딩 중" 표시 가능

     버퍼 정상:
     - 모든 채널 버퍼가 20% 이상
     - isBuffering = false 설정
     - 정상 재생 중

     버퍼가 부족한 원인:
     - 디코딩 속도가 재생 속도를 따라가지 못함
     - 파일 읽기 지연 (HDD, 네트워크 드라이브)
     - CPU 과부하

     해결 방법:
     - 일시적으로 재생 멈춤 (버퍼 채울 때까지)
     - 재생 속도 낮춤
     - 버퍼 크기 증가
     */
    private func checkBufferStatus() {
        // 1. 모든 채널의 버퍼 상태 가져오기
        let bufferStatus = getBufferStatus()
        // [CameraPosition: (current, max, fillPercentage)]

        // 2. 버퍼가 부족한 채널이 있는지 확인
        let isAnyBufferLow = bufferStatus.values.contains { status in
            // values: 딕셔너리의 값들 (튜플들)
            // contains: 조건에 맞는 요소가 하나라도 있는지

            status.fillPercentage < 0.2
            // 20% 미만이면 true
        }

        // 3. 버퍼링 상태 업데이트
        if isAnyBufferLow && !isBuffering {
            // 버퍼가 부족한데 아직 isBuffering이 false
            print("Warning: Low buffer detected in some channels")
            isBuffering = true
            // @Published: UI에 "로딩 중" 표시
        } else if !isAnyBufferLow && isBuffering {
            // 버퍼가 충분한데 isBuffering이 true
            isBuffering = false
            // @Published: "로딩 중" 숨김
        }
    }
}

// MARK: - Computed Properties (계산 속성)

/**
 시간 포맷팅 관련 계산 속성들

 computed property란?
 - 값을 저장하지 않고 계산하여 반환
 - 호출 시마다 재계산
 - UI에서 직접 사용 가능

 시간 포맷:
 - MM:SS 형식 (분:초)
 - 00:00 ~ 99:59 범위
 - 항상 2자리 (앞에 0 붙임)
 */
extension SyncController {
    /// **현재 시간 문자열 (Current Time String)**
    ///
    /// currentTime을 "MM:SS" 형식으로 변환
    ///
    /// 예:
    /// - currentTime = 65.0 → "01:05"
    /// - currentTime = 5.0 → "00:05"
    /// - currentTime = 125.0 → "02:05"
    ///
    /// 사용 예:
    /// ```swift
    /// Text(controller.currentTimeString)  // "01:30"
    /// ```
    var currentTimeString: String {
        return formatTime(currentTime)
    }

    /// **총 재생 시간 문자열 (Duration String)**
    ///
    /// duration을 "MM:SS" 형식으로 변환
    ///
    /// 예:
    /// - duration = 60.0 → "01:00"
    /// - duration = 600.0 → "10:00"
    ///
    /// 사용 예:
    /// ```swift
    /// Text(controller.durationString)  // "05:30"
    /// ```
    var durationString: String {
        return formatTime(duration)
    }

    /// **남은 시간 문자열 (Remaining Time String)**
    ///
    /// 남은 시간 = duration - currentTime
    /// 앞에 "-" 붙임 (관례)
    ///
    /// 예:
    /// - currentTime = 30, duration = 60 → "-00:30"
    /// - currentTime = 50, duration = 60 → "-00:10"
    ///
    /// 사용 예:
    /// ```swift
    /// Text(controller.remainingTimeString)  // "-02:15"
    /// ```
    var remainingTimeString: String {
        let remaining = max(0, duration - currentTime)
        // 음수 방지 (파일 끝에서)
        return "-\(formatTime(remaining))"
        // "-" 붙여서 반환
    }

    /// **재생 속도 문자열 (Playback Speed String)**
    ///
    /// playbackSpeed를 "X.Xx" 형식으로 변환
    /// 소수점 1자리
    ///
    /// 예:
    /// - playbackSpeed = 1.0 → "1.0x"
    /// - playbackSpeed = 2.0 → "2.0x"
    /// - playbackSpeed = 0.5 → "0.5x"
    ///
    /// 사용 예:
    /// ```swift
    /// Text(controller.playbackSpeedString)  // "2.0x"
    /// ```
    var playbackSpeedString: String {
        return String(format: "%.1fx", playbackSpeed)
        // %.1f: 소수점 1자리
        // x: 배속 표시
    }

    /**
     시간을 "MM:SS" 형식으로 변환합니다.

     변환 과정:
     1. TimeInterval(Double)을 Int로 변환
     2. 분 = 총 초 / 60
     3. 초 = 총 초 % 60 (나머지)
     4. "%02d:%02d" 형식으로 포맷

     포맷 설명:
     - %02d: 2자리 정수, 앞에 0 붙임
     - 예: 5 → "05", 12 → "12"

     예:
     - 65초 → 1분 5초 → "01:05"
     - 125초 → 2분 5초 → "02:05"
     - 5초 → 0분 5초 → "00:05"

     파라미터:
     - time: 변환할 시간 (초)

     반환:
     - "MM:SS" 형식 문자열

     - Returns: 포맷된 시간 문자열
     */
    private func formatTime(_ time: TimeInterval) -> String {
        // 1. 정수로 변환
        let totalSeconds = Int(time)
        // Double → Int
        // 소수점 버림

        // 2. 분 계산
        let minutes = totalSeconds / 60
        // 나눗셈 (몫)
        // 65 / 60 = 1

        // 3. 초 계산
        let seconds = totalSeconds % 60
        // 나머지 연산
        // 65 % 60 = 5

        // 4. 포맷팅
        return String(format: "%02d:%02d", minutes, seconds)
        // %02d: 2자리, 앞에 0 붙임
        // 예: (1, 5) → "01:05"
    }
}
