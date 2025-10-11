//
//  AudioPlayer.swift
//  BlackboxPlayer
//
//  AVAudioEngine 기반 오디오 재생 서비스
//
//  [이 파일의 역할]
//  FFmpeg에서 디코딩된 AudioFrame을 실제 스피커로 재생하는 서비스입니다.
//  Apple의 AVAudioEngine를 사용하여 PCM 오디오 데이터를 실시간으로 재생합니다.
//
//  [AVAudioEngine란?]
//  macOS/iOS에서 저수준 오디오 처리를 위한 Apple의 프레임워크입니다.
//  여러 오디오 "노드"를 연결하여 복잡한 오디오 파이프라인을 구성할 수 있습니다.
//
//  AVAudioEngine의 노드 기반 아키텍처:
//
//  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
//  │ PlayerNode   │ ───▶ │  MixerNode   │ ───▶ │ Output (🔊) │
//  │ (재생)       │      │  (믹싱/볼륨)  │      │ (스피커)     │
//  └──────────────┘      └──────────────┘      └──────────────┘
//       ↑
//  PCM 버퍼 입력
//
//  [데이터 흐름]
//  1. VideoDecoder가 AudioFrame 생성 (FFmpeg 디코딩)
//  2. AudioPlayer.enqueue(frame) 호출
//  3. frame.toAudioBuffer() → AVAudioPCMBuffer 변환
//  4. playerNode.scheduleBuffer() → 재생 큐에 추가
//  5. AVAudioEngine가 자동으로 버퍼 재생
//  6. 스피커로 출력 🔊
//
//  [버퍼링 전략]
//  이 플레이어는 최대 30개의 오디오 프레임을 큐에 보관합니다.
//  - 각 프레임 ≈ 21ms (1024 샘플 / 48kHz)
//  - 30프레임 = 약 630ms (0.63초) 버퍼
//  - 네트워크 지연이나 디코딩 지연을 흡수할 수 있는 충분한 버퍼
//
//  [스레드 안전성]
//  여러 스레드에서 동시에 접근할 수 있으므로:
//  - frameQueue 접근 시 NSLock 사용
//  - 콜백에서 [weak self] 사용 (메모리 순환 참조 방지)
//
//  [사용 예시]
//  ```swift
//  // 초기화
//  let audioPlayer = AudioPlayer()
//  try audioPlayer.start()
//
//  // 프레임 재생
//  let frame = AudioFrame(...)
//  try audioPlayer.enqueue(frame)
//
//  // 볼륨 조절
//  audioPlayer.setVolume(0.5)  // 50%
//
//  // 일시정지
//  audioPlayer.pause()
//  audioPlayer.resume()
//
//  // 정지 및 정리
//  audioPlayer.stop()
//  ```
//

import Foundation
import AVFoundation

// MARK: - AudioPlayer 클래스

/// AVAudioEngine 기반 오디오 재생기
///
/// FFmpeg에서 디코딩된 AudioFrame을 AVAudioEngine를 통해 실시간 재생합니다.
/// 비디오 재생 시 오디오 트랙을 담당하는 핵심 컴포넌트입니다.
///
/// ## 아키텍처
/// ```
/// AudioPlayer (이 클래스)
///     │
///     ├─ AVAudioEngine: 전체 오디오 시스템 관리
///     │     │
///     │     ├─ AVAudioPlayerNode: PCM 버퍼 재생
///     │     │     └─ scheduleBuffer() → 큐에 버퍼 추가
///     │     │
///     │     ├─ AVAudioMixerNode: 볼륨 조절 및 믹싱
///     │     │     └─ outputVolume = 0.0 ~ 1.0
///     │     │
///     │     └─ Output Device: 시스템 스피커
///     │
///     └─ frameQueue: 재생 대기 중인 프레임들
///           └─ NSLock: 스레드 안전 보장
/// ```
///
/// ## 오디오 재생 파이프라인
/// ```
/// VideoDecoder (디코딩 스레드)
///     │
///     │ enqueue(AudioFrame)
///     ↓
/// [frameQueue] ← NSLock으로 보호
///     │
///     │ scheduleBuffer()
///     ↓
/// AVAudioPlayerNode
///     │
///     │ 자동 재생
///     ↓
/// AVAudioMixerNode (볼륨 적용)
///     │
///     ↓
/// 🔊 스피커
/// ```
///
/// ## 버퍼링 메커니즘
/// ```
/// maxQueueSize = 30 프레임
///
/// [Frame1][Frame2][Frame3]...[Frame30]
///   21ms   21ms    21ms  ...   21ms
///
/// 총 버퍼: 30 × 21ms = 630ms (0.63초)
///
/// 버퍼가 부족하면: 소리 끊김 (underrun)
/// 버퍼가 과도하면: 지연 증가, 메모리 낭비
/// 30프레임 = 적절한 균형
/// ```
///
/// ## 스레드 안전성
/// ```
/// 디코딩 스레드 ──┐
///                 ├─▶ [NSLock] ──▶ frameQueue ──┐
/// 콜백 스레드 ────┘                              ├─▶ 안전한 접근
/// 메인 스레드 ───────────────────────────────────┘
/// ```
///
/// ## 사용 예시
/// ```swift
/// // 1. AudioPlayer 초기화 및 시작
/// let player = AudioPlayer()
/// try player.start()
///
/// // 2. 오디오 프레임 큐잉 (디코딩 스레드에서)
/// for frame in decodedFrames {
///     try player.enqueue(frame)
/// }
///
/// // 3. 볼륨 조절 (메인 스레드에서)
/// player.setVolume(0.8)  // 80%
///
/// // 4. 재생 제어
/// player.pause()    // 일시정지
/// player.resume()   // 재개
/// player.flush()    // 큐 비우기 (Seek 시)
///
/// // 5. 정지 및 정리
/// player.stop()
/// ```
class AudioPlayer {
    // MARK: - Properties

    /// AVAudioEngine 인스턴스
    ///
    /// Apple의 저수준 오디오 프레임워크의 핵심 클래스입니다.
    /// 여러 오디오 노드(PlayerNode, MixerNode, EffectNode 등)를 연결하여
    /// 복잡한 오디오 파이프라인을 구성할 수 있습니다.
    ///
    /// **주요 역할**:
    /// - 오디오 그래프 관리: 노드들의 연결 관계 유지
    /// - 오디오 스트림 제어: start(), stop()
    /// - 하드웨어 추상화: 다양한 오디오 장치 지원
    ///
    /// **라이프사이클**:
    /// ```
    /// 1. 초기화: AVAudioEngine()
    /// 2. 노드 연결: connect(playerNode, to: mixer, format: format)
    /// 3. 시작: try engine.start()
    /// 4. 실행: 자동으로 오디오 처리
    /// 5. 종료: engine.stop()
    /// ```
    ///
    /// **예시**:
    /// ```swift
    /// let engine = AVAudioEngine()
    ///
    /// // 노드 추가 및 연결
    /// engine.attach(playerNode)
    /// engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
    ///
    /// // 엔진 시작
    /// try engine.start()
    ///
    /// // 이제 playerNode.scheduleBuffer()로 오디오 재생 가능
    /// ```
    private let audioEngine: AVAudioEngine

    /// AVAudioPlayerNode 인스턴스
    ///
    /// PCM 오디오 버퍼를 재생하는 노드입니다.
    /// 여러 버퍼를 큐에 추가하면 자동으로 순서대로 재생합니다.
    ///
    /// **주요 기능**:
    /// - `scheduleBuffer()`: 버퍼를 재생 큐에 추가
    /// - `play()`: 재생 시작
    /// - `pause()`: 일시정지 (큐는 유지)
    /// - `stop()`: 정지 (큐 비우기)
    ///
    /// **버퍼 스케줄링 방식**:
    /// ```
    /// playerNode.scheduleBuffer(buffer1)  ← 첫 번째 버퍼
    /// playerNode.scheduleBuffer(buffer2)  ← 두 번째 버퍼
    /// playerNode.scheduleBuffer(buffer3)  ← 세 번째 버퍼
    ///
    /// 재생 순서: buffer1 → buffer2 → buffer3 → (끝)
    ///
    /// 각 버퍼 재생 완료 시 completion 핸들러 호출:
    /// scheduleBuffer(buffer1) { print("buffer1 완료!") }
    /// ```
    ///
    /// **동작 원리**:
    /// ```
    /// [Internal Queue]
    /// ┌───────┬───────┬───────┬───────┐
    /// │ Buf1  │ Buf2  │ Buf3  │ Buf4  │
    /// └───────┴───────┴───────┴───────┘
    ///    ↑ 현재 재생 중
    ///
    /// 재생 완료 → 자동으로 다음 버퍼로 이동
    /// Buf1 완료 → Buf2 재생 시작
    /// ```
    ///
    /// **Underrun (버퍼 부족) 방지**:
    /// ```
    /// 큐가 비면 → 소리 끊김!
    ///
    /// 해결책: 항상 충분한 버퍼 유지
    /// 권장: 최소 3~5개 버퍼 (약 100~200ms)
    /// 현재 구현: 최대 30개 버퍼 (약 630ms)
    /// ```
    private let playerNode: AVAudioPlayerNode

    /// AVAudioMixerNode 인스턴스
    ///
    /// 여러 오디오 스트림을 믹싱하고 볼륨을 조절하는 노드입니다.
    /// AVAudioEngine는 기본적으로 mainMixerNode를 제공합니다.
    ///
    /// **주요 기능**:
    /// - 볼륨 조절: `outputVolume = 0.0 ~ 1.0`
    /// - 여러 입력 믹싱: 여러 PlayerNode를 하나로 합침
    /// - 최종 출력: 스피커 또는 다른 노드로 전송
    ///
    /// **볼륨 스케일**:
    /// ```
    /// outputVolume = 0.0  → 무음 (mute)
    /// outputVolume = 0.5  → 50% 볼륨
    /// outputVolume = 1.0  → 100% 볼륨 (원본)
    /// outputVolume > 1.0  → 증폭 (클리핑 가능)
    /// ```
    ///
    /// **믹싱 예시**:
    /// ```
    /// PlayerNode1 (음악)  ──┐
    ///                        ├─▶ MixerNode ──▶ 🔊
    /// PlayerNode2 (효과음) ──┘     ↑
    ///                           outputVolume
    /// ```
    ///
    /// **사용 예시**:
    /// ```swift
    /// // 볼륨 조절
    /// mixer.outputVolume = 0.8  // 80%
    ///
    /// // 여러 소스 연결
    /// engine.connect(playerNode1, to: mixer, format: format1)
    /// engine.connect(playerNode2, to: mixer, format: format2)
    /// engine.connect(mixer, to: engine.outputNode, format: nil)
    /// ```
    private let mixer: AVAudioMixerNode

    /// 현재 볼륨 레벨 (0.0 ~ 1.0)
    ///
    /// 외부에서 읽기 가능하지만, 쓰기는 `setVolume()` 메서드를 통해서만 가능합니다.
    /// 이는 볼륨 값의 유효성을 보장하기 위함입니다.
    ///
    /// **범위 제한**:
    /// ```
    /// 입력: -5.0 → 실제 적용: 0.0 (최소값)
    /// 입력:  0.5 → 실제 적용: 0.5
    /// 입력:  2.0 → 실제 적용: 1.0 (최대값)
    /// ```
    ///
    /// **dB(데시벨) 변환**:
    /// ```
    /// 볼륨 0.0  = -∞ dB (무음)
    /// 볼륨 0.1  = -20 dB
    /// 볼륨 0.5  = -6 dB (절반 크기)
    /// 볼륨 1.0  = 0 dB (원본)
    ///
    /// dB = 20 × log₁₀(volume)
    /// ```
    ///
    /// **private(set)**의 의미:
    /// ```swift
    /// // 클래스 내부: 읽기/쓰기 가능
    /// self.volume = 0.8  // ✅ OK
    ///
    /// // 클래스 외부: 읽기만 가능
    /// let vol = player.volume     // ✅ OK (읽기)
    /// player.volume = 0.8         // ❌ Error (직접 쓰기 불가)
    /// player.setVolume(0.8)       // ✅ OK (메서드를 통한 쓰기)
    /// ```
    private(set) var volume: Float = 1.0

    /// 오디오 엔진 실행 중 여부
    ///
    /// 엔진이 start()된 상태인지 확인하는 플래그입니다.
    /// 이 값에 따라 pause/resume 동작이 달라집니다.
    ///
    /// **상태 전이**:
    /// ```
    /// [Stopped] ──start()──▶ [Playing]
    ///              ↑              │
    ///              │              │ pause()
    ///              │              ↓
    ///              └───stop()──[Paused]
    ///                             │
    ///                             │ resume()
    ///                             ↓
    ///                          [Playing]
    /// ```
    ///
    /// **사용 예시**:
    /// ```swift
    /// if player.isPlaying {
    ///     player.pause()
    /// } else {
    ///     try player.start()
    /// }
    /// ```
    private(set) var isPlaying: Bool = false

    /// 현재 세션의 오디오 포맷
    ///
    /// 첫 번째 프레임이 큐잉될 때 설정되며, 이후 모든 프레임은 같은 포맷이어야 합니다.
    /// 포맷이 다른 프레임이 들어오면 `formatMismatch` 에러가 발생합니다.
    ///
    /// **포맷 구성 요소**:
    /// ```
    /// AVAudioFormat {
    ///     sampleRate: 48000.0 Hz
    ///     channels: 2 (스테레오)
    ///     commonFormat: .pcmFormatFloat32
    ///     interleaved: false (planar)
    /// }
    /// ```
    ///
    /// **포맷 검증**:
    /// ```swift
    /// // 첫 번째 프레임
    /// currentFormat = nil
    /// enqueue(frame1)  // currentFormat 설정
    ///
    /// // 이후 프레임
    /// enqueue(frame2)  // currentFormat과 비교
    /// - 포맷 일치: ✅ 재생
    /// - 포맷 불일치: ❌ formatMismatch 에러
    /// ```
    ///
    /// **포맷 변경이 필요한 경우**:
    /// ```swift
    /// // 비디오 파일 변경 시
    /// player.stop()           // currentFormat = nil
    /// player.start()          // 새 포맷으로 재설정
    /// ```
    ///
    /// **nil인 경우**:
    /// - 초기화 직후
    /// - stop() 호출 후
    /// - 아직 프레임이 큐잉되지 않음
    private var currentFormat: AVAudioFormat?

    /// 재생 대기 중인 프레임 큐
    ///
    /// enqueue()로 추가된 프레임들을 추적합니다.
    /// 프레임 재생 완료 시 onBufferFinished()에서 제거됩니다.
    ///
    /// **큐의 역할**:
    /// 1. 버퍼 추적: 현재 몇 개의 프레임이 재생 대기 중인가?
    /// 2. 메모리 관리: 재생 완료된 프레임 정리
    /// 3. 오버플로우 방지: maxQueueSize 체크
    ///
    /// **큐 동작 예시**:
    /// ```
    /// 초기: frameQueue = []
    ///
    /// enqueue(frame1) → frameQueue = [frame1]
    /// enqueue(frame2) → frameQueue = [frame1, frame2]
    /// enqueue(frame3) → frameQueue = [frame1, frame2, frame3]
    ///
    /// frame1 재생 완료 → frameQueue = [frame2, frame3]
    /// frame2 재생 완료 → frameQueue = [frame3]
    /// frame3 재생 완료 → frameQueue = []
    /// ```
    ///
    /// **주의사항**:
    /// - 이 큐는 추적용입니다. 실제 재생은 AVAudioPlayerNode 내부 큐에서 발생합니다.
    /// - frameQueue.count != playerNode의 실제 버퍼 개수 (약간의 차이 가능)
    private var frameQueue: [AudioFrame] = []

    /// frameQueue 접근용 락 (Lock)
    ///
    /// 여러 스레드에서 frameQueue에 동시 접근하는 것을 방지합니다.
    ///
    /// **왜 Lock이 필요한가?**
    /// ```
    /// 스레드 A (디코딩 스레드):
    ///     enqueue() → frameQueue.append()
    ///
    /// 스레드 B (콜백 스레드):
    ///     onBufferFinished() → frameQueue.remove()
    ///
    /// 스레드 C (메인 스레드):
    ///     queueSize() → frameQueue.count
    ///
    /// Lock 없으면: Race Condition! (데이터 손상, 크래시)
    /// Lock 있으면: 한 번에 한 스레드만 접근 ✅
    /// ```
    ///
    /// **NSLock 사용법**:
    /// ```swift
    /// queueLock.lock()         // 🔒 잠금 (다른 스레드는 대기)
    /// frameQueue.append(frame) // 안전한 수정
    /// queueLock.unlock()       // 🔓 해제 (다른 스레드 진입 가능)
    /// ```
    ///
    /// **defer를 사용한 안전한 패턴**:
    /// ```swift
    /// func queueSize() -> Int {
    ///     queueLock.lock()
    ///     defer { queueLock.unlock() }  // 함수 종료 시 자동 해제
    ///     return frameQueue.count
    ///     // defer 덕분에 return 전에 unlock 보장
    /// }
    /// ```
    ///
    /// **Lock vs DispatchQueue**:
    /// ```
    /// NSLock:
    /// ✅ 빠름 (저수준 락)
    /// ✅ 간단한 사용법
    /// ❌ 데드락 주의 필요
    ///
    /// DispatchQueue (Serial):
    /// ✅ 데드락 위험 적음
    /// ✅ GCD 통합
    /// ❌ 약간 느림 (컨텍스트 스위칭)
    ///
    /// 여기서는 성능상 NSLock 선택
    /// ```
    private let queueLock = NSLock()

    /// 최대 큐 크기 (프레임 개수)
    ///
    /// 큐에 보관할 수 있는 최대 프레임 수입니다.
    /// 이 값을 초과하면 새 프레임은 조용히 버려집니다 (스킵).
    ///
    /// **왜 30개인가?**
    /// ```
    /// 1개 프레임 = 1024 샘플 / 48000 Hz ≈ 21ms
    /// 30개 프레임 = 30 × 21ms = 630ms (0.63초)
    ///
    /// 장점:
    /// - 충분한 버퍼: 디코딩 지연 흡수
    /// - 부드러운 재생: underrun 방지
    ///
    /// 단점:
    /// - 메모리 사용: 30 × 8KB = 240KB (괜찮은 수준)
    /// - 지연 증가: 최대 630ms (비디오 동기화에 영향)
    /// ```
    ///
    /// **버퍼 크기 조정 가이드**:
    /// ```
    /// 작은 값 (예: 5):
    /// ✅ 낮은 지연 (105ms)
    /// ❌ 소리 끊김 위험 (underrun)
    ///
    /// 큰 값 (예: 100):
    /// ✅ 매우 안정적
    /// ❌ 높은 지연 (2100ms = 2.1초)
    /// ❌ 메모리 낭비 (800KB)
    ///
    /// 중간 값 (30):
    /// ✅ 균형잡힌 선택 ⭐
    /// ```
    ///
    /// **오버플로우 동작**:
    /// ```swift
    /// enqueue(frame31)  // 큐가 가득 찬 상태
    /// → guard queueSize < maxQueueSize else { return }
    /// → 프레임 버려짐 (조용히 스킵)
    /// → 에러 없음, 로그 없음
    ///
    /// 결과: 오디오 일부 누락 (하지만 크래시는 방지)
    /// ```
    private let maxQueueSize = 30

    // MARK: - Initialization

    /// AudioPlayer 초기화
    ///
    /// AVAudioEngine, AVAudioPlayerNode, AVAudioMixerNode를 설정하고
    /// 노드를 엔진에 연결합니다.
    ///
    /// **초기화 단계**:
    /// ```
    /// 1. AVAudioEngine 생성
    /// 2. AVAudioPlayerNode 생성
    /// 3. MixerNode 가져오기 (engine.mainMixerNode)
    /// 4. PlayerNode를 Engine에 연결 (attach)
    /// ```
    ///
    /// **주의**: 이 단계에서는 노드 간 연결이 이루어지지 않습니다!
    /// 실제 연결은 첫 번째 프레임 큐잉 시 setupAudioSession()에서 발생합니다.
    ///
    /// ## 초기화 후 상태
    /// ```
    /// AudioEngine: 생성됨, 정지 상태
    /// PlayerNode: 생성됨, 연결 안 됨
    /// MixerNode: 준비됨
    /// currentFormat: nil
    /// frameQueue: []
    /// isPlaying: false
    /// ```
    ///
    /// ## 사용 예시
    /// ```swift
    /// // 1. 초기화
    /// let player = AudioPlayer()
    ///
    /// // 2. 시작 (엔진 가동)
    /// try player.start()
    ///
    /// // 3. 프레임 큐잉 (첫 프레임 시 자동으로 노드 연결)
    /// try player.enqueue(frame)
    /// ```
    init() {
        // AVAudioEngine 생성
        audioEngine = AVAudioEngine()

        // PlayerNode 생성 (PCM 버퍼 재생용)
        playerNode = AVAudioPlayerNode()

        // MixerNode 가져오기 (볼륨 조절용)
        // mainMixerNode는 AVAudioEngine가 자동으로 제공
        mixer = audioEngine.mainMixerNode

        // PlayerNode를 Engine에 추가
        // 주의: 아직 mixer와 연결하지 않음!
        // 연결은 setupAudioSession()에서 발생
        audioEngine.attach(playerNode)

        // 이유: 오디오 포맷을 알아야 연결 가능
        // 포맷은 첫 프레임 큐잉 시 결정됨
    }

    /// 소멸자 (메모리 해제 시 호출)
    ///
    /// AudioPlayer 객체가 메모리에서 제거될 때 자동으로 호출됩니다.
    /// 오디오 엔진을 정리하여 리소스 누수를 방지합니다.
    ///
    /// **정리 순서**:
    /// ```
    /// 1. playerNode.stop() → 재생 중단
    /// 2. audioEngine.stop() → 엔진 종료
    /// 3. frameQueue.removeAll() → 큐 비우기
    /// 4. currentFormat = nil → 포맷 리셋
    /// ```
    ///
    /// **왜 필요한가?**
    /// ```swift
    /// // ARC (Automatic Reference Counting):
    /// var player: AudioPlayer? = AudioPlayer()
    /// try player?.start()
    /// player = nil  // ← deinit 호출!
    ///
    /// deinit 없으면:
    /// → audioEngine.stop() 호출 안 됨
    /// → 백그라운드에서 계속 실행
    /// → CPU/메모리 낭비
    /// ```
    ///
    /// **자동 호출 시점**:
    /// ```swift
    /// class VideoPlayer {
    ///     let audioPlayer = AudioPlayer()
    ///     // ...
    /// }  // ← VideoPlayer 소멸 시 audioPlayer.deinit 자동 호출
    /// ```
    deinit {
        stop()  // 모든 정리 작업 수행
    }

    // MARK: - Public Methods

    /// 오디오 엔진 시작
    ///
    /// AVAudioEngine를 가동하여 오디오 재생 준비를 완료합니다.
    /// 이 메서드를 호출하지 않으면 프레임을 큐잉해도 소리가 나지 않습니다!
    ///
    /// **동작**:
    /// ```
    /// 1. 엔진이 이미 실행 중이면 early return (중복 시작 방지)
    /// 2. audioEngine.start() → 엔진 가동
    /// 3. playerNode.play() → PlayerNode 재생 모드 전환
    /// 4. isPlaying = true → 상태 업데이트
    /// ```
    ///
    /// **엔진 시작 프로세스**:
    /// ```
    /// audioEngine.start():
    /// - 오디오 하드웨어 초기화
    /// - 버퍼 크기 설정 (기본: ~512 샘플)
    /// - 샘플레이트 협상 (일반적으로 48kHz)
    /// - Audio Unit 초기화
    ///
    /// 소요 시간: 일반적으로 10~50ms
    /// ```
    ///
    /// **throws**: 엔진 시작 실패 시 AudioPlayerError.engineStartFailed 발생
    ///
    /// ## 에러 발생 케이스
    /// ```
    /// 1. 오디오 장치 없음 (headless 서버)
    /// 2. 오디오 장치 사용 중 (다른 앱이 독점)
    /// 3. 권한 없음 (샌드박스 제약)
    /// 4. 시스템 리소스 부족
    /// ```
    ///
    /// ## 사용 예시
    /// ```swift
    /// let player = AudioPlayer()
    ///
    /// do {
    ///     try player.start()
    ///     print("오디오 엔진 시작 성공")
    /// } catch AudioPlayerError.engineStartFailed(let error) {
    ///     print("시작 실패: \(error)")
    /// }
    ///
    /// // 이제 프레임 큐잉 가능
    /// try player.enqueue(frame)
    /// ```
    ///
    /// ## 주의사항
    /// ```swift
    /// // ❌ 잘못된 사용: start() 없이 enqueue
    /// let player = AudioPlayer()
    /// try player.enqueue(frame)  // 소리 안 남!
    ///
    /// // ✅ 올바른 사용: start() 후 enqueue
    /// let player = AudioPlayer()
    /// try player.start()         // 엔진 시작
    /// try player.enqueue(frame)  // 소리 남 🔊
    /// ```
    func start() throws {
        // 중복 시작 방지
        guard !audioEngine.isRunning else { return }

        do {
            // AVAudioEngine 시작
            // - 오디오 하드웨어 초기화
            // - 버퍼 할당
            // - 샘플레이트 설정
            try audioEngine.start()

            // PlayerNode 재생 시작
            // 주의: 실제로 소리가 나려면 scheduleBuffer()로 버퍼 추가 필요
            playerNode.play()

            // 상태 업데이트
            isPlaying = true

        } catch {
            // 시작 실패 시 우리만의 에러로 래핑
            throw AudioPlayerError.engineStartFailed(error)
        }
    }

    /// 오디오 엔진 정지 및 정리
    ///
    /// 재생을 완전히 중단하고 모든 큐를 비웁니다.
    /// 다시 재생하려면 start()를 호출해야 합니다.
    ///
    /// **정지 순서**:
    /// ```
    /// 1. playerNode.stop() → 재생 중단, 내부 큐 비우기
    /// 2. audioEngine.stop() → 엔진 종료, 하드웨어 해제
    /// 3. isPlaying = false → 상태 업데이트
    /// 4. currentFormat = nil → 포맷 리셋
    /// 5. frameQueue.removeAll() → 추적 큐 비우기
    /// ```
    ///
    /// **pause() vs stop() 차이**:
    /// ```
    /// pause():
    /// - 엔진 계속 실행
    /// - 큐 유지
    /// - resume()으로 즉시 재개 가능
    ///
    /// stop():
    /// - 엔진 완전 종료
    /// - 큐 비우기
    /// - start() 후 다시 큐잉 필요
    /// ```
    ///
    /// **메모리 정리**:
    /// ```
    /// stop() 전:
    /// - frameQueue: [frame1, frame2, ..., frame30] (240KB)
    /// - playerNode 내부 큐: 수 MB
    ///
    /// stop() 후:
    /// - frameQueue: [] (거의 0KB)
    /// - playerNode 내부 큐: 해제됨
    /// ```
    ///
    /// ## 사용 시나리오
    /// ```swift
    /// // 1. 비디오 재생 종료
    /// videoPlayer.stop()
    /// audioPlayer.stop()  // 완전 정리
    ///
    /// // 2. 다른 비디오 로드
    /// audioPlayer.stop()  // 이전 포맷 리셋
    /// try audioPlayer.start()  // 새 비디오용 재시작
    ///
    /// // 3. 앱 종료 시
    /// audioPlayer.stop()  // 리소스 해제
    /// ```
    func stop() {
        // PlayerNode 정지 (내부 큐도 비워짐)
        playerNode.stop()

        // AudioEngine 종료 (하드웨어 해제)
        audioEngine.stop()

        // 상태 업데이트
        isPlaying = false

        // 포맷 리셋 (다음 start 시 새 포맷 허용)
        currentFormat = nil

        // 추적 큐 비우기 (thread-safe)
        queueLock.lock()
        frameQueue.removeAll()
        queueLock.unlock()
    }

    /// 오디오 재생 일시정지
    ///
    /// 현재 재생 위치와 큐를 유지한 채 일시정지합니다.
    /// resume()을 호출하면 정확히 멈춘 위치부터 재개됩니다.
    ///
    /// **동작**:
    /// ```
    /// playerNode.pause():
    /// - 현재 버퍼의 재생 위치 기억
    /// - 큐에 있는 나머지 버퍼 유지
    /// - 오디오 출력만 중단
    ///
    /// 엔진은 계속 실행 중!
    /// ```
    ///
    /// **내부 상태**:
    /// ```
    /// pause() 전:
    /// [Buf1▶][Buf2][Buf3][Buf4]
    ///   ↑ 재생 중 (50% 위치)
    ///
    /// pause() 후:
    /// [Buf1⏸][Buf2][Buf3][Buf4]
    ///   ↑ 일시정지 (50% 위치 기억)
    ///
    /// resume() 후:
    /// [Buf1▶][Buf2][Buf3][Buf4]
    ///   ↑ 50%부터 재개
    /// ```
    ///
    /// ## 사용 예시
    /// ```swift
    /// // 재생 중
    /// player.isPlaying  // true
    ///
    /// // 일시정지
    /// player.pause()
    /// player.isPlaying  // false
    ///
    /// // 1초 대기...
    /// sleep(1)
    ///
    /// // 재개 (정확히 멈춘 곳부터)
    /// player.resume()
    /// player.isPlaying  // true
    /// ```
    func pause() {
        // PlayerNode 일시정지
        // 주의: 엔진은 계속 실행 중
        playerNode.pause()

        // 상태 업데이트
        isPlaying = false
    }

    /// 일시정지된 오디오 재생 재개
    ///
    /// pause()로 멈춘 재생을 정확히 멈춘 위치부터 계속합니다.
    ///
    /// **동작**:
    /// ```
    /// playerNode.play():
    /// - 기억한 재생 위치부터 재개
    /// - 큐에 있는 버퍼들 순서대로 재생
    /// ```
    ///
    /// **주의**: 엔진이 stop()된 상태라면 아무 효과 없음!
    /// ```swift
    /// player.stop()    // 엔진 종료
    /// player.resume()  // ❌ 효과 없음! start() 필요
    /// ```
    ///
    /// ## 올바른 사용
    /// ```swift
    /// // ✅ pause → resume
    /// player.pause()
    /// player.resume()  // OK
    ///
    /// // ❌ stop → resume
    /// player.stop()
    /// player.resume()  // 효과 없음!
    ///
    /// // ✅ stop → start
    /// player.stop()
    /// try player.start()  // OK
    /// ```
    func resume() {
        // PlayerNode 재생 재개
        playerNode.play()

        // 상태 업데이트
        isPlaying = true
    }

    /// 오디오 프레임을 재생 큐에 추가
    ///
    /// FFmpeg에서 디코딩된 AudioFrame을 AVAudioPCMBuffer로 변환하여
    /// PlayerNode의 재생 큐에 추가합니다. 이 메서드는 스레드 안전합니다.
    ///
    /// **처리 흐름**:
    /// ```
    /// 1. 큐 크기 체크 (최대 30개)
    /// 2. AudioFrame → AVAudioPCMBuffer 변환
    /// 3. 첫 프레임이면 setupAudioSession() 호출
    /// 4. 포맷 일치 확인
    /// 5. playerNode.scheduleBuffer() 호출
    /// 6. frameQueue에 추가 (추적용)
    /// ```
    ///
    /// **버퍼 변환 과정**:
    /// ```
    /// AudioFrame (FFmpeg):
    /// - format: .floatPlanar
    /// - data: Data (원시 바이트)
    /// - sampleCount: 1024
    ///
    ///      ↓ frame.toAudioBuffer()
    ///
    /// AVAudioPCMBuffer (Apple):
    /// - format: AVAudioFormat
    /// - floatChannelData: UnsafeMutablePointer
    /// - frameLength: 1024
    /// ```
    ///
    /// **스케줄링**:
    /// ```
    /// playerNode.scheduleBuffer(buffer) { [weak self] in
    ///     // 이 버퍼 재생 완료 시 호출됨
    ///     self?.onBufferFinished(frame)
    /// }
    ///
    /// 호출 스레드: AVAudioEngine 내부 스레드
    /// 호출 시점: 버퍼의 마지막 샘플 재생 직후
    /// ```
    ///
    /// **[weak self]의 이유**:
    /// ```
    /// strong reference cycle 방지:
    ///
    /// AudioPlayer → scheduleBuffer → closure → self (strong) → AudioPlayer
    /// └───────────────────────────────────────────────────────────────┘
    ///                     ↑ 순환 참조! 메모리 누수!
    ///
    /// [weak self] 사용:
    /// AudioPlayer → scheduleBuffer → closure → self (weak) → AudioPlayer
    ///                                               ↓
    ///                                              nil (AudioPlayer 해제 시)
    /// ```
    ///
    /// - Parameter frame: 재생할 오디오 프레임
    /// - Throws: AudioPlayerError (버퍼 변환 실패, 포맷 불일치)
    ///
    /// ## 오버플로우 동작
    /// ```swift
    /// // 큐가 가득 찬 상태 (30개)
    /// try player.enqueue(frame31)
    /// → guard queueSize < maxQueueSize else { return }
    /// → 조용히 스킵 (에러 없음)
    ///
    /// 결과: frame31은 재생되지 않음 (오디오 누락)
    /// ```
    ///
    /// ## 에러 케이스
    /// ```swift
    /// // 1. 버퍼 변환 실패
    /// let invalidFrame = AudioFrame(...)  // 잘못된 포맷
    /// try player.enqueue(invalidFrame)
    /// → throws AudioPlayerError.bufferConversionFailed
    ///
    /// // 2. 포맷 불일치
    /// try player.enqueue(frame1)  // 48kHz 스테레오
    /// try player.enqueue(frame2)  // 44.1kHz 모노 ❌
    /// → throws AudioPlayerError.formatMismatch
    /// ```
    ///
    /// ## 사용 예시
    /// ```swift
    /// // 디코딩 스레드에서
    /// for frame in decoder.decodeAudio() {
    ///     do {
    ///         try audioPlayer.enqueue(frame)
    ///     } catch AudioPlayerError.bufferConversionFailed {
    ///         print("버퍼 변환 실패: \(frame)")
    ///     } catch AudioPlayerError.formatMismatch {
    ///         print("포맷 불일치: \(frame.format)")
    ///     }
    /// }
    /// ```
    func enqueue(_ frame: AudioFrame) throws {
        // 1단계: 큐 크기 확인 (thread-safe)
        queueLock.lock()
        let queueSize = frameQueue.count
        queueLock.unlock()

        // 오버플로우 방지: 큐가 가득 차면 스킵
        guard queueSize < maxQueueSize else {
            // 조용히 리턴 (프레임 버려짐)
            return
        }

        // 2단계: AVAudioPCMBuffer로 변환
        guard let buffer = frame.toAudioBuffer() else {
            // 변환 실패 (잘못된 포맷, 메모리 부족 등)
            throw AudioPlayerError.bufferConversionFailed
        }

        // 3단계: 첫 프레임이면 오디오 세션 설정
        if currentFormat == nil {
            // 포맷 기억 (이후 프레임들과 비교용)
            currentFormat = buffer.format

            // 노드 연결: playerNode → mixer
            setupAudioSession(format: buffer.format)
        }

        // 4단계: 포맷 일치 확인
        guard buffer.format == currentFormat else {
            // 포맷이 다르면 에러
            // 예: 첫 프레임 48kHz, 두 번째 프레임 44.1kHz
            throw AudioPlayerError.formatMismatch
        }

        // 5단계: PlayerNode에 버퍼 스케줄링
        playerNode.scheduleBuffer(buffer) { [weak self] in
            // 이 클로저는 버퍼 재생 완료 시 호출됨
            // 호출 스레드: AVAudioEngine 내부 스레드

            // [weak self]: AudioPlayer가 이미 해제되었을 수 있음
            self?.onBufferFinished(frame)
        }

        // 6단계: 추적 큐에 추가 (thread-safe)
        queueLock.lock()
        frameQueue.append(frame)
        queueLock.unlock()
    }

    /// 볼륨 설정
    ///
    /// 오디오 출력 볼륨을 0.0 (무음) ~ 1.0 (최대) 범위로 조절합니다.
    /// 범위를 벗어난 값은 자동으로 클램핑됩니다.
    ///
    /// **클램핑 (Clamping)**:
    /// ```
    /// 입력 → 실제 적용
    /// -5.0 → 0.0 (최소값)
    ///  0.3 → 0.3 (그대로)
    ///  2.0 → 1.0 (최대값)
    /// ```
    ///
    /// **볼륨 스케일**:
    /// ```
    /// 0.0 = 무음 (mute)
    /// 0.5 = 50% 볼륨 (약 -6dB)
    /// 1.0 = 100% 볼륨 (원본, 0dB)
    /// ```
    ///
    /// **즉시 적용**:
    /// ```
    /// setVolume(0.8)
    /// → self.volume = 0.8
    /// → mixer.outputVolume = 0.8
    /// → 재생 중인 오디오에 즉시 반영 (부드럽게)
    /// ```
    ///
    /// - Parameter volume: 볼륨 레벨 (0.0 ~ 1.0)
    ///
    /// ## 사용 예시
    /// ```swift
    /// // 볼륨 50%
    /// player.setVolume(0.5)
    ///
    /// // 무음
    /// player.setVolume(0.0)
    ///
    /// // 최대
    /// player.setVolume(1.0)
    ///
    /// // 범위 초과 → 자동 클램핑
    /// player.setVolume(5.0)  // → 1.0으로 조정됨
    /// ```
    ///
    /// ## UI 슬라이더 연동
    /// ```swift
    /// // SwiftUI
    /// Slider(value: $volume, in: 0...1) { _ in
    ///     audioPlayer.setVolume(Float(volume))
    /// }
    ///
    /// // UIKit
    /// @IBAction func volumeChanged(_ sender: UISlider) {
    ///     audioPlayer.setVolume(sender.value)
    /// }
    /// ```
    func setVolume(_ volume: Float) {
        // 값 검증 및 클램핑
        // max(0.0, min(1.0, volume)):
        // 1. min(1.0, volume) → 1.0보다 크면 1.0
        // 2. max(0.0, ...) → 0.0보다 작으면 0.0
        self.volume = max(0.0, min(1.0, volume))

        // MixerNode에 즉시 적용
        mixer.outputVolume = self.volume
    }

    /// 큐에 있는 모든 프레임 제거
    ///
    /// PlayerNode의 재생 큐와 추적 큐를 모두 비웁니다.
    /// Seek 동작 시 호출하여 이전 오디오를 정리합니다.
    ///
    /// **동작**:
    /// ```
    /// 1. playerNode.stop() → 재생 중단, 내부 큐 비우기
    /// 2. frameQueue.removeAll() → 추적 큐 비우기
    /// 3. 재생 중이었다면 playerNode.play() → 재생 모드 복원
    /// ```
    ///
    /// **재생 중단 없이 큐만 비우기**:
    /// ```
    /// flush() 전:
    /// [재생중▶][Buf2][Buf3]...[Buf30]
    ///
    /// flush() 중:
    /// playerNode.stop() → 모두 제거
    /// frameQueue.removeAll()
    ///
    /// flush() 후:
    /// [] ← 빈 큐
    /// playerNode.play() ← 재생 모드 (버퍼 없음)
    /// ```
    ///
    /// **Seek 시나리오**:
    /// ```swift
    /// // 사용자가 10초 → 60초로 Seek
    /// 1. decoder.seek(to: 60.0)
    /// 2. audioPlayer.flush()        // 이전 10초 구간 오디오 제거
    /// 3. 새로운 60초 구간 프레임 큐잉
    /// 4. 깔끔하게 60초부터 재생
    /// ```
    ///
    /// ## 사용 예시
    /// ```swift
    /// // Seek 처리
    /// func seekTo(time: TimeInterval) {
    ///     // 1. 비디오 디코더 Seek
    ///     videoDecoder.seek(to: time)
    ///
    ///     // 2. 오디오 큐 비우기
    ///     audioPlayer.flush()
    ///
    ///     // 3. 새 위치부터 디코딩 시작
    ///     startDecoding()
    /// }
    /// ```
    func flush() {
        // PlayerNode 정지 (내부 큐도 비워짐)
        playerNode.stop()

        // 추적 큐 비우기 (thread-safe)
        queueLock.lock()
        frameQueue.removeAll()
        queueLock.unlock()

        // 재생 중이었다면 재생 모드 복원
        if isPlaying {
            playerNode.play()
        }

        // 주의: 새 프레임을 enqueue()하지 않으면 소리 없음
    }

    /// 현재 큐 크기 조회
    ///
    /// 재생 대기 중인 프레임 개수를 반환합니다.
    /// 이 값은 버퍼링 상태를 모니터링하는 데 유용합니다.
    ///
    /// **defer를 사용한 안전한 unlock**:
    /// ```swift
    /// func queueSize() -> Int {
    ///     queueLock.lock()
    ///     defer { queueLock.unlock() }  // 함수 종료 시 자동 해제
    ///
    ///     return frameQueue.count
    ///     // return 전에 defer 블록 실행 → unlock 보장
    /// }
    /// ```
    ///
    /// **defer 없이 구현하면?**
    /// ```swift
    /// // ❌ 위험한 코드
    /// func queueSize() -> Int {
    ///     queueLock.lock()
    ///     let count = frameQueue.count
    ///     queueLock.unlock()  // 까먹으면 데드락!
    ///     return count
    /// }
    /// ```
    ///
    /// - Returns: 큐에 있는 프레임 개수 (0 ~ maxQueueSize)
    ///
    /// ## 버퍼링 모니터링
    /// ```swift
    /// // 버퍼 상태 체크
    /// let queueSize = audioPlayer.queueSize()
    ///
    /// if queueSize < 5 {
    ///     print("⚠️ 버퍼 부족 (underrun 위험)")
    /// } else if queueSize > 25 {
    ///     print("📊 버퍼 충분")
    /// }
    /// ```
    ///
    /// ## UI 표시
    /// ```swift
    /// // 버퍼 진행률 표시
    /// let bufferLevel = Double(player.queueSize()) / Double(player.maxQueueSize)
    /// ProgressView(value: bufferLevel)
    ///     .progressViewStyle(.linear)
    /// ```
    func queueSize() -> Int {
        queueLock.lock()
        defer { queueLock.unlock() }  // 자동 해제 보장
        return frameQueue.count
    }

    // MARK: - Private Methods

    /// 오디오 세션 설정 (노드 연결)
    ///
    /// PlayerNode와 MixerNode를 연결하여 오디오 파이프라인을 완성합니다.
    /// 이 메서드는 첫 번째 프레임이 큐잉될 때 자동으로 호출됩니다.
    ///
    /// **연결 과정**:
    /// ```
    /// audioEngine.connect(
    ///     source: playerNode,    // PCM 버퍼 재생
    ///     destination: mixer,    // 볼륨 조절
    ///     format: audioFormat    // 48kHz 스테레오 등
    /// )
    ///
    /// 결과:
    /// [PlayerNode] ───format──▶ [MixerNode] ───▶ 🔊
    /// ```
    ///
    /// **포맷의 역할**:
    /// ```
    /// format 지정:
    /// - PlayerNode와 MixerNode가 같은 포맷으로 통신
    /// - 샘플레이트 일치 (48kHz)
    /// - 채널 수 일치 (2채널)
    /// - 비트 깊이 일치 (Float32)
    ///
    /// format = nil:
    /// - 자동 포맷 협상 (권장하지 않음)
    /// ```
    ///
    /// **볼륨 초기화**:
    /// ```
    /// mixer.outputVolume = self.volume
    /// → 사용자가 start() 전에 setVolume()을 호출했을 수 있음
    /// → 저장된 볼륨 값 적용
    /// ```
    ///
    /// - Parameter format: 오디오 포맷 (샘플레이트, 채널, 비트 깊이)
    private func setupAudioSession(format: AVAudioFormat) {
        // PlayerNode를 Mixer에 연결
        // 이제 playerNode.scheduleBuffer()로 추가한 버퍼가
        // mixer를 거쳐 스피커로 출력됩니다.
        audioEngine.connect(playerNode, to: mixer, format: format)

        // 초기 볼륨 적용
        // (사용자가 start() 전에 setVolume()을 호출했을 수 있음)
        mixer.outputVolume = volume
    }

    /// 버퍼 재생 완료 콜백
    ///
    /// playerNode.scheduleBuffer()의 completion 핸들러로 호출됩니다.
    /// 재생이 완료된 프레임을 추적 큐에서 제거합니다.
    ///
    /// **호출 시점**:
    /// ```
    /// 버퍼의 마지막 샘플이 스피커로 출력된 직후
    ///
    /// 타임라인:
    /// [Frame1 재생] ─────▶ 마지막 샘플 ─▶ onBufferFinished(Frame1) 호출
    /// ```
    ///
    /// **호출 스레드**: AVAudioEngine 내부 스레드 (not main thread!)
    ///
    /// **큐 정리**:
    /// ```
    /// frameQueue = [Frame1, Frame2, Frame3]
    ///                 ↑ 재생 완료
    ///
    /// onBufferFinished(Frame1) 호출
    /// → firstIndex(where: { $0 == Frame1 }) → 0
    /// → frameQueue.remove(at: 0)
    ///
    /// frameQueue = [Frame2, Frame3]
    /// ```
    ///
    /// **defer를 사용한 안전한 unlock**:
    /// ```swift
    /// queueLock.lock()
    /// defer { queueLock.unlock() }  // 함수 종료 시 자동 해제
    ///
    /// // 복잡한 로직...
    /// if condition { return }  // ← defer가 unlock 보장
    /// // ...
    /// // 함수 끝 ← defer가 unlock 보장
    /// ```
    ///
    /// - Parameter frame: 재생이 완료된 프레임
    private func onBufferFinished(_ frame: AudioFrame) {
        queueLock.lock()
        defer { queueLock.unlock() }

        // 완료된 프레임을 큐에서 찾아 제거
        if let index = frameQueue.firstIndex(where: { $0 == frame }) {
            frameQueue.remove(at: index)
        }

        // 주의: index를 못 찾을 수도 있음 (flush() 호출 시)
        // 이 경우 조용히 무시 (에러 없음)
    }
}

// MARK: - Error Types

/// AudioPlayer 에러 타입
///
/// AudioPlayer에서 발생할 수 있는 에러들을 정의합니다.
/// LocalizedError 프로토콜을 구현하여 사용자 친화적인 에러 메시지를 제공합니다.
///
/// ## 에러 종류
/// ```
/// 1. engineStartFailed: 엔진 시작 실패
///    - 원인: 오디오 장치 없음, 권한 없음, 리소스 부족
///
/// 2. bufferConversionFailed: 버퍼 변환 실패
///    - 원인: 잘못된 AudioFrame 포맷, 메모리 부족
///
/// 3. formatMismatch: 오디오 포맷 불일치
///    - 원인: 첫 프레임과 다른 포맷의 프레임 큐잉
/// ```
///
/// ## 사용 예시
/// ```swift
/// do {
///     try audioPlayer.start()
/// } catch AudioPlayerError.engineStartFailed(let underlyingError) {
///     print("엔진 시작 실패: \(underlyingError.localizedDescription)")
/// } catch {
///     print("알 수 없는 에러: \(error)")
/// }
/// ```
enum AudioPlayerError: LocalizedError {
    /// 오디오 엔진 시작 실패
    ///
    /// AVAudioEngine.start() 호출 시 발생한 에러를 래핑합니다.
    ///
    /// **일반적인 원인**:
    /// - 오디오 출력 장치 없음 (headless 서버)
    /// - 다른 앱이 오디오 장치 독점 중
    /// - 샌드박스 권한 부족
    /// - 시스템 리소스 부족
    ///
    /// - Parameter error: 원본 에러
    case engineStartFailed(Error)

    /// 오디오 버퍼 변환 실패
    ///
    /// AudioFrame을 AVAudioPCMBuffer로 변환하는 중 발생한 에러입니다.
    ///
    /// **일반적인 원인**:
    /// - AudioFrame의 포맷이 잘못됨 (지원하지 않는 포맷)
    /// - 메모리 부족 (버퍼 할당 실패)
    /// - AudioFrame.data가 손상됨
    case bufferConversionFailed

    /// 오디오 포맷 불일치
    ///
    /// 큐잉하려는 프레임의 포맷이 currentFormat과 다를 때 발생합니다.
    ///
    /// **예시**:
    /// ```
    /// Frame1: 48000 Hz, 2채널, Float32 ✅
    /// Frame2: 44100 Hz, 2채널, Float32 ❌ formatMismatch!
    /// ```
    ///
    /// **해결 방법**:
    /// ```swift
    /// // 포맷이 변경되면 플레이어 재시작
    /// audioPlayer.stop()
    /// try audioPlayer.start()
    /// try audioPlayer.enqueue(newFormatFrame)
    /// ```
    case formatMismatch

    /// 사용자 친화적인 에러 설명
    ///
    /// 각 에러 케이스에 대한 설명 문자열을 반환합니다.
    /// UI에서 사용자에게 보여줄 메시지를 제공합니다.
    var errorDescription: String? {
        switch self {
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .bufferConversionFailed:
            return "Failed to convert audio frame to buffer"
        case .formatMismatch:
            return "Audio format mismatch"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// 통합 가이드: AudioPlayer 사용 플로우
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ 초기화 및 시작
// ────────────────────────────────────────────────
// let audioPlayer = AudioPlayer()
// try audioPlayer.start()  // 엔진 가동
//
// 2️⃣ 프레임 큐잉 (디코딩 루프)
// ────────────────────────────────────────────────
// for frame in decoder.decodeAudio() {
//     try audioPlayer.enqueue(frame)
//     // 자동으로 스피커로 재생됨
// }
//
// 3️⃣ 재생 제어 (사용자 입력)
// ────────────────────────────────────────────────
// // 일시정지
// audioPlayer.pause()
//
// // 재개
// audioPlayer.resume()
//
// // 볼륨 조절
// audioPlayer.setVolume(0.7)  // 70%
//
// 4️⃣ Seek 처리
// ────────────────────────────────────────────────
// // 사용자가 타임라인 이동
// decoder.seek(to: 60.0)       // 60초로 이동
// audioPlayer.flush()          // 이전 오디오 제거
// // 새로운 60초 구간 프레임 큐잉 시작
//
// 5️⃣ 종료 및 정리
// ────────────────────────────────────────────────
// audioPlayer.stop()  // 엔진 종료, 큐 비우기
//
// ═══════════════════════════════════════════════════════════════════════════
