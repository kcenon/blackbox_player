/// @file AudioFrame.swift
/// @brief 디코딩된 오디오 프레임 데이터 모델
/// @author BlackboxPlayer Development Team
/// @details
/// FFmpeg에서 디코딩한 원시 오디오 데이터(PCM)를 담는 구조체입니다.
/// 비디오 파일의 MP3/AAC 등 압축된 오디오를 디코딩하면 PCM(Pulse Code Modulation) 형태의
/// 원시 오디오 데이터가 생성되는데, 이를 프레임 단위로 관리합니다.
///
/// [이 파일의 역할]
/// FFmpeg에서 디코딩한 원시 오디오 데이터(PCM)를 담는 구조체입니다.
/// 비디오 파일의 MP3/AAC 등 압축된 오디오를 디코딩하면 PCM(Pulse Code Modulation) 형태의
/// 원시 오디오 데이터가 생성되는데, 이를 프레임 단위로 관리합니다.
///
/// [오디오 프레임이란?]
/// 오디오도 비디오처럼 "프레임" 단위로 처리됩니다:
/// - 비디오 프레임 = 한 장의 이미지
/// - 오디오 프레임 = 일정 개수의 오디오 샘플 묶음 (보통 1024개)
///
/// 예시:
/// - 샘플레이트 48000Hz (1초에 48000개 샘플)
/// - 프레임당 1024 샘플
/// - 프레임 지속시간 = 1024 / 48000 = 약 21ms
///
/// [PCM (Pulse Code Modulation)이란?]
/// 아날로그 소리를 디지털로 변환한 가장 기본적인 형태:
///
/// 아날로그 소리파  →  샘플링  →  양자화  →  PCM 데이터
///  (연속 파형)      (1초에 N번)  (숫자로 변환)  ([-1.0, 0.5, -0.3, ...])
///
/// 음질을 결정하는 요소:
/// 1. 샘플레이트: 1초에 몇 번 측정하는가? (44.1kHz, 48kHz 등)
/// 2. 비트 깊이: 각 샘플을 몇 비트로 표현하는가? (16bit, 32bit 등)
/// 3. 채널 수: 모노(1)? 스테레오(2)? 5.1채널(6)?
///
/// [데이터 흐름]
/// 1. VideoDecoder가 FFmpeg로 MP3 디코딩 → PCM 데이터 생성
/// 2. AudioFrame 구조체에 PCM 데이터 + 메타정보 저장
/// 3. AudioPlayer가 AudioFrame을 AVAudioPCMBuffer로 변환
/// 4. AVAudioEngine이 스피커로 재생
///
/// MP3 파일 (압축) → FFmpeg 디코딩 → AudioFrame (PCM) → AVAudioPCMBuffer → 🔊 재생
///

import Foundation
import AVFoundation

// MARK: - AudioFrame 구조체

/// @struct AudioFrame
/// @brief 디코딩된 오디오 프레임 (PCM 샘플 데이터)
///
/// @details
/// FFmpeg에서 디코딩한 원시 오디오 데이터를 Swift에서 다루기 쉽게 포장한 구조체입니다.
/// 이 구조체는 다음 정보를 포함합니다:
/// - 타임스탬프: 이 오디오가 비디오의 몇 초 지점인가?
/// - 오디오 포맷: 샘플레이트, 채널 수, 데이터 형식
/// - PCM 데이터: 실제 오디오 샘플 값들
///
/// ## 사용 예시
/// ```swift
/// // FFmpeg에서 디코딩된 오디오 프레임 생성
/// let frame = AudioFrame(
///     timestamp: 1.5,              // 비디오 1.5초 지점
///     sampleRate: 48000,           // 48kHz (CD 품질)
///     channels: 2,                 // 스테레오
///     format: .floatPlanar,        // 32비트 float, planar 배치
///     data: pcmData,               // 실제 PCM 바이트
///     sampleCount: 1024            // 1024개 샘플
/// )
///
/// // 재생을 위해 AVAudioPCMBuffer로 변환
/// if let buffer = frame.toAudioBuffer() {
///     audioPlayer.enqueue(buffer)  // 재생 큐에 추가
/// }
/// ```
///
/// ## Planar vs Interleaved 배치
/// 스테레오(2채널) 오디오 데이터를 메모리에 배치하는 두 가지 방식:
///
/// **Interleaved (교차 배치)**: LRLRLRLR...
/// ```
/// [L0, R0, L1, R1, L2, R2, L3, R3, ...]
///  왼쪽0, 오른쪽0, 왼쪽1, 오른쪽1...
/// ```
/// - 장점: 메모리 연속성, 캐시 효율 좋음
/// - 단점: 채널별 처리 시 stride 필요
///
/// **Planar (평면 배치)**: LLL...RRR...
/// ```
/// [L0, L1, L2, L3, ...] [R0, R1, R2, R3, ...]
///  왼쪽 채널 전체        오른쪽 채널 전체
/// ```
/// - 장점: 채널별 처리 쉬움 (DSP, 이펙트)
/// - 단점: 메모리 분산
///
/// FFmpeg는 보통 Planar 형식으로 디코딩하고,
/// AVAudioEngine는 Interleaved를 선호합니다.
/// 이 구조체가 변환을 담당합니다.
struct AudioFrame {
    // MARK: - Properties

    /// @var timestamp
    /// @brief 프레젠테이션 타임스탬프 (초 단위)
    ///
    /// @details
    /// 이 오디오 프레임이 비디오의 몇 초 지점에서 재생되어야 하는지를 나타냅니다.
    ///
    /// **왜 필요한가?**
    /// 오디오와 비디오의 동기화(Lip Sync)를 맞추기 위해 필수적입니다.
    ///
    /// **예시**:
    /// ```
    /// Frame 1: timestamp = 0.000초 (시작)
    /// Frame 2: timestamp = 0.021초 (21ms 후)
    /// Frame 3: timestamp = 0.043초 (43ms 후)
    /// ...
    /// ```
    ///
    /// 비디오 프레임의 타임스탬프와 오디오 프레임의 타임스탬프를 비교하여
    /// 동기화를 맞춥니다. 예를 들어:
    /// - 비디오 프레임: 1.500초
    /// - 오디오 프레임: 1.498초 → 거의 일치 (±2ms 이내)
    let timestamp: TimeInterval

    /// @var sampleRate
    /// @brief 샘플레이트 (초당 샘플 수)
    ///
    /// @details
    /// 1초에 몇 개의 오디오 샘플을 측정하는가를 나타냅니다.
    /// 높을수록 고음질이지만, 데이터 크기도 증가합니다.
    ///
    /// **일반적인 샘플레이트**:
    /// - 8000 Hz: 전화 품질 (낮은 음질, 음성 통화용)
    /// - 22050 Hz: 라디오 품질 (중간 음질)
    /// - 44100 Hz: CD 품질 (표준 음악 품질) ⭐
    /// - 48000 Hz: DVD/블루레이 품질 (비디오 표준) ⭐⭐
    /// - 96000 Hz: 고해상도 오디오 (스튜디오 품질)
    ///
    /// **나이퀴스트 정리**:
    /// 인간이 들을 수 있는 최고 주파수는 약 20kHz입니다.
    /// 이를 정확히 재현하려면 최소 40kHz의 샘플레이트가 필요합니다.
    /// (샘플레이트 ≥ 2 × 최대 주파수)
    /// 그래서 CD는 44.1kHz를 사용합니다.
    ///
    /// **예시**:
    /// ```
    /// sampleRate = 48000 Hz
    /// → 1초 = 48,000개 샘플
    /// → 1ms = 48개 샘플
    /// → 1개 샘플 = 0.0208ms
    /// ```
    let sampleRate: Int

    /// @var channels
    /// @brief 오디오 채널 수
    ///
    /// @details
    /// 오디오가 몇 개의 독립적인 신호 채널을 가지는가를 나타냅니다.
    ///
    /// **채널 구성**:
    /// - 1 채널 = Mono (모노): 단일 스피커, 음성 녹음
    /// - 2 채널 = Stereo (스테레오): 좌/우 분리, 음악/영화 표준 ⭐
    /// - 4 채널 = Quad (쿼드): 전/후 + 좌/우
    /// - 5.1 채널 = 홈시어터: 전방 3개 + 후방 2개 + 서브우퍼
    /// - 7.1 채널 = 고급 홈시어터: 전방 3개 + 측면 2개 + 후방 2개 + 서브우퍼
    ///
    /// 블랙박스는 보통 1채널(모노) 또는 2채널(스테레오)을 사용합니다.
    ///
    /// **메모리 계산**:
    /// ```
    /// channels = 2 (스테레오)
    /// sampleCount = 1024
    /// bytesPerSample = 4 (float32)
    /// → 총 크기 = 2 × 1024 × 4 = 8,192 bytes = 8KB
    /// ```
    let channels: Int

    /// @var format
    /// @brief 오디오 샘플 포맷 (데이터 타입)
    ///
    /// @details
    /// PCM 샘플 하나를 어떤 데이터 타입으로 표현하는가를 정의합니다.
    /// 포맷에 따라 음질, 메모리 크기, 처리 속도가 달라집니다.
    ///
    /// **주요 포맷**:
    /// - `.floatPlanar`: 32비트 float, planar 배치 (FFmpeg 기본값) ⭐
    /// - `.floatInterleaved`: 32비트 float, interleaved 배치
    /// - `.s16Planar`: 16비트 정수, planar 배치 (메모리 절약)
    /// - `.s16Interleaved`: 16비트 정수, interleaved 배치 (CD 형식)
    ///
    /// **Float vs Integer**:
    /// ```
    /// Float32 (32비트 부동소수점):
    /// - 범위: -1.0 ~ +1.0 (정규화된 값)
    /// - 장점: 처리 중 오버플로우 없음, 정밀도 높음
    /// - 단점: 메모리 2배 (4바이트)
    ///
    /// Int16 (16비트 정수):
    /// - 범위: -32768 ~ +32767
    /// - 장점: 메모리 절약 (2바이트), CD 표준
    /// - 단점: 처리 중 오버플로우 가능
    /// ```
    let format: AudioFormat

    /// @var data
    /// @brief 원시 PCM 오디오 데이터 (바이트 배열)
    ///
    /// @details
    /// 실제 오디오 샘플 값들이 바이너리 형태로 저장된 Data입니다.
    /// 이 데이터의 해석 방법은 `format`, `channels`, `sampleCount`에 따라 달라집니다.
    ///
    /// **데이터 구조 예시 (스테레오 float planar)**:
    /// ```
    /// sampleCount = 4, channels = 2, format = .floatPlanar
    ///
    /// 메모리 레이아웃:
    /// [L0_bytes][L1_bytes][L2_bytes][L3_bytes]  ← 왼쪽 채널 (16바이트)
    /// [R0_bytes][R1_bytes][R2_bytes][R3_bytes]  ← 오른쪽 채널 (16바이트)
    /// 총 32바이트
    ///
    /// Float 해석:
    /// 왼쪽: [-0.5, 0.3, -0.8, 0.1]
    /// 오른쪽: [-0.4, 0.2, -0.7, 0.0]
    /// ```
    ///
    /// **데이터 크기 계산**:
    /// ```
    /// dataSize = sampleCount × channels × bytesPerSample
    ///          = 1024 × 2 × 4
    ///          = 8,192 bytes (8KB per frame)
    /// ```
    ///
    /// FFmpeg에서 디코딩 시 이 Data를 채웁니다.
    let data: Data

    /// @var sampleCount
    /// @brief 샘플 개수 (채널당)
    ///
    /// @details
    /// 이 프레임이 담고 있는 오디오 샘플의 개수입니다.
    /// 주의: 전체 샘플이 아니라 **채널당 샘플 개수**입니다!
    ///
    /// **예시**:
    /// ```
    /// sampleCount = 1024
    /// channels = 2 (스테레오)
    /// → 왼쪽 채널: 1024개 샘플
    /// → 오른쪽 채널: 1024개 샘플
    /// → 전체: 2048개 샘플 (하지만 sampleCount는 1024)
    /// ```
    ///
    /// **일반적인 프레임 크기**:
    /// - AAC: 1024 샘플 per frame
    /// - MP3: 1152 샘플 per frame
    /// - Opus: 120~960 샘플 (가변)
    ///
    /// **지속시간 계산**:
    /// ```
    /// duration = sampleCount / sampleRate
    ///          = 1024 / 48000
    ///          = 0.0213초 = 21.3ms
    /// ```
    let sampleCount: Int

    // MARK: - Initialization

    /// @brief 오디오 프레임 초기화
    ///
    /// @details
    /// FFmpeg에서 디코딩한 PCM 데이터로 AudioFrame을 생성합니다.
    /// 일반적으로 VideoDecoder 내부에서 호출되며, 직접 생성할 일은 드뭅니다.
    ///
    /// @param timestamp 비디오 타임라인 상의 위치 (초)
    /// @param sampleRate 샘플링 주파수 (Hz)
    /// @param channels 채널 수 (1=모노, 2=스테레오)
    /// @param format PCM 샘플 포맷
    /// @param data 원시 PCM 바이트 데이터
    /// @param sampleCount 채널당 샘플 개수
    ///
    /// ## 생성 예시 (VideoDecoder 내부)
    /// ```swift
    /// // FFmpeg에서 디코딩한 AVFrame을 AudioFrame으로 변환
    /// let pcmData = Data(bytes: avFrame.data[0], count: dataSize)
    ///
    /// let audioFrame = AudioFrame(
    ///     timestamp: avFrame.pts * timeBase,
    ///     sampleRate: avFrame.sample_rate,
    ///     channels: avFrame.channels,
    ///     format: .floatPlanar,
    ///     data: pcmData,
    ///     sampleCount: avFrame.nb_samples
    /// )
    /// ```
    init(
        timestamp: TimeInterval,
        sampleRate: Int,
        channels: Int,
        format: AudioFormat,
        data: Data,
        sampleCount: Int
    ) {
        self.timestamp = timestamp
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.data = data
        self.sampleCount = sampleCount
    }

    // MARK: - Computed Properties

    /// @brief 이 오디오 프레임의 지속시간 (초)
    ///
    /// @return 지속시간 (TimeInterval)
    ///
    /// @details
    /// 이 프레임을 재생하는 데 걸리는 시간을 계산합니다.
    ///
    /// **계산 공식**:
    /// ```
    /// duration = sampleCount / sampleRate
    /// ```
    ///
    /// **예시 계산**:
    /// ```
    /// // AAC 표준 프레임
    /// sampleCount = 1024
    /// sampleRate = 48000 Hz
    /// duration = 1024 / 48000 = 0.021333...초 = 21.33ms
    ///
    /// // MP3 표준 프레임
    /// sampleCount = 1152
    /// sampleRate = 44100 Hz
    /// duration = 1152 / 44100 = 0.026122...초 = 26.12ms
    /// ```
    ///
    /// **용도**:
    /// - 타임스탬프 계산: `nextTimestamp = currentTimestamp + duration`
    /// - 버퍼링 시간 계산: `totalBufferedTime = sum(frame.duration)`
    /// - 동기화 검증: 프레임 지속시간 vs 실제 재생 시간 비교
    var duration: TimeInterval {
        return Double(sampleCount) / Double(sampleRate)

        // 예시 결과:
        // sampleCount=1024, sampleRate=48000
        // → 1024.0 / 48000.0 = 0.0213초 = 21.3ms
    }

    /// @brief PCM 데이터의 총 바이트 크기
    ///
    /// @return 데이터 크기 (바이트)
    ///
    /// @details
    /// `data` 프로퍼티에 저장된 바이트 배열의 크기를 반환합니다.
    ///
    /// **크기 계산 예시**:
    /// ```
    /// // 스테레오 float planar
    /// sampleCount = 1024
    /// channels = 2
    /// bytesPerSample = 4 (float32)
    ///
    /// dataSize = 1024 × 2 × 4 = 8,192 bytes = 8KB
    ///
    /// // 초당 데이터량 (48kHz 스테레오 float)
    /// sampleRate = 48000
    /// frames_per_second = 48000 / 1024 ≈ 47 frames
    /// data_per_second = 8192 × 47 ≈ 385KB/s
    /// data_per_minute = 385KB × 60 ≈ 22.6MB/min
    /// ```
    ///
    /// **포맷별 크기 비교 (1024 샘플, 스테레오 기준)**:
    /// - Float32: 1024 × 2 × 4 = 8,192 bytes
    /// - Int16: 1024 × 2 × 2 = 4,096 bytes (절반!)
    var dataSize: Int {
        return data.count
    }

    /// @brief 샘플 하나당 바이트 크기 (모든 채널 포함)
    ///
    /// @return 바이트 크기
    ///
    /// @details
    /// 하나의 "시점"에서 모든 채널의 샘플을 저장하는 데 필요한 바이트 수입니다.
    ///
    /// **계산 공식**:
    /// ```
    /// bytesPerSample = format.bytesPerSample × channels
    /// ```
    ///
    /// **예시 계산**:
    /// ```
    /// // Float32 스테레오
    /// format.bytesPerSample = 4 bytes (float32)
    /// channels = 2
    /// → bytesPerSample = 4 × 2 = 8 bytes
    ///   (왼쪽 4바이트 + 오른쪽 4바이트)
    ///
    /// // Int16 모노
    /// format.bytesPerSample = 2 bytes (int16)
    /// channels = 1
    /// → bytesPerSample = 2 × 1 = 2 bytes
    /// ```
    ///
    /// **Interleaved 포맷에서의 메모리 레이아웃**:
    /// ```
    /// bytesPerSample = 8 (Float32 Stereo)
    ///
    /// [L0: 4바이트][R0: 4바이트] ← 샘플 0 (8바이트)
    /// [L1: 4바이트][R1: 4바이트] ← 샘플 1 (8바이트)
    /// [L2: 4바이트][R2: 4바이트] ← 샘플 2 (8바이트)
    /// ...
    /// ```
    var bytesPerSample: Int {
        return format.bytesPerSample * channels
    }

    // MARK: - Audio Buffer Conversion

    /// @brief AVAudioPCMBuffer로 변환 (재생용)
    ///
    /// @return 변환된 AVAudioPCMBuffer, 실패 시 nil
    ///
    /// @details
    /// FFmpeg의 PCM 데이터를 Apple의 AVAudioEngine에서 재생 가능한
    /// AVAudioPCMBuffer 형식으로 변환합니다.
    ///
    /// **변환 과정**:
    /// ```
    /// 1. AVAudioFormat 생성
    ///    - 샘플레이트, 채널 수, 포맷 정보 설정
    ///
    /// 2. AVAudioPCMBuffer 할당
    ///    - 필요한 메모리 공간 확보
    ///
    /// 3. PCM 데이터 복사
    ///    - Planar → Planar: 채널별 복사
    ///    - Interleaved → Interleaved: 전체 복사
    ///
    /// 4. frameLength 설정
    ///    - 실제 사용된 샘플 개수 표시
    /// ```
    ///
    /// **Planar vs Interleaved 변환**:
    /// ```
    /// Planar 입력 (FFmpeg 기본):
    /// data = [L0,L1,L2,L3][R0,R1,R2,R3]
    ///         ↓ 채널별로 복사
    /// AVAudioPCMBuffer (Planar):
    /// channelData[0] = [L0,L1,L2,L3]
    /// channelData[1] = [R0,R1,R2,R3]
    ///
    /// Interleaved 입력:
    /// data = [L0,R0,L1,R1,L2,R2,L3,R3]
    ///         ↓ 전체 복사
    /// AVAudioPCMBuffer (Interleaved):
    /// channelData[0] = [L0,R0,L1,R1,L2,R2,L3,R3]
    /// ```
    ///
    /// **실제 사용 예시**:
    /// ```swift
    /// // AudioPlayer에서 재생
    /// func playFrame(_ frame: AudioFrame) {
    ///     guard let buffer = frame.toAudioBuffer() else {
    ///         print("버퍼 변환 실패")
    ///         return
    ///     }
    ///
    ///     // AVAudioPlayerNode에 스케줄링
    ///     playerNode.scheduleBuffer(buffer) {
    ///         print("재생 완료")
    ///     }
    /// }
    /// ```
    ///
    /// **실패 케이스**:
    /// - 지원하지 않는 오디오 포맷
    /// - 잘못된 샘플레이트 또는 채널 수
    /// - 메모리 부족
    func toAudioBuffer() -> AVAudioPCMBuffer? {
        // 1단계: AVAudioFormat 생성
        // Apple의 오디오 시스템이 이해할 수 있는 포맷 객체 생성
        guard let audioFormat = AVAudioFormat(
            commonFormat: format.commonFormat,      // 샘플 타입 (.pcmFormatFloat32 등)
            sampleRate: Double(sampleRate),         // 48000.0 Hz
            channels: AVAudioChannelCount(channels), // 2 (스테레오)
            interleaved: format.isInterleaved       // false (planar)
        ) else {
            // 포맷 생성 실패 = 지원하지 않는 조합
            return nil
        }

        // 2단계: AVAudioPCMBuffer 할당
        // 실제 PCM 데이터를 담을 메모리 버퍼 생성
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,                        // 위에서 생성한 포맷
            frameCapacity: AVAudioFrameCount(sampleCount) // 최대 1024개 샘플
        ) else {
            // 버퍼 할당 실패 = 메모리 부족
            return nil
        }

        // 실제 사용할 프레임 개수 설정 (중요!)
        // frameCapacity는 "최대 용량", frameLength는 "실제 사용량"
        buffer.frameLength = AVAudioFrameCount(sampleCount)

        // 예시:
        // frameCapacity = 1024 (할당된 공간)
        // frameLength = 512 (실제 사용된 공간)
        // → 512개만 재생됨

        // 3단계: PCM 데이터 복사
        // self.data (Data) → buffer.floatChannelData (UnsafeMutablePointer)

        if format.isInterleaved {
            // ═══════════════════════════════════════════════════════════
            // Interleaved 포맷: LRLRLR... 형식
            // ═══════════════════════════════════════════════════════════
            //
            // 데이터 레이아웃 (스테레오):
            // [L0, R0, L1, R1, L2, R2, ...]
            //
            // AVAudioPCMBuffer (Interleaved):
            // channelData[0] = 모든 데이터 (L과 R 섞여있음)
            //
            // 복사 방법: 전체를 한 번에 memcpy
            //
            if let channelData = buffer.floatChannelData {
                // Data를 unsafe bytes로 접근
                data.withUnsafeBytes { dataBytes in
                    // baseAddress = Data의 시작 포인터
                    if let sourcePtr = dataBytes.baseAddress {
                        // 전체 데이터를 channelData[0]으로 복사
                        memcpy(
                            channelData[0],   // 목적지: buffer의 첫 번째 채널
                            sourcePtr,        // 소스: self.data의 시작
                            data.count        // 크기: 전체 바이트
                        )

                        // 예시: 8바이트 복사 (Float32 스테레오, 1샘플)
                        // sourcePtr:      [L0:4byte][R0:4byte]
                        //                    ↓ memcpy
                        // channelData[0]: [L0:4byte][R0:4byte]
                    }
                }
            }

        } else {
            // ═══════════════════════════════════════════════════════════
            // Planar 포맷: LLL...RRR... 형식 (FFmpeg 기본)
            // ═══════════════════════════════════════════════════════════
            //
            // 데이터 레이아웃 (스테레오):
            // [L0, L1, L2, ...] [R0, R1, R2, ...]
            //  왼쪽 채널 전체    오른쪽 채널 전체
            //
            // AVAudioPCMBuffer (Planar):
            // channelData[0] = [L0, L1, L2, ...]
            // channelData[1] = [R0, R1, R2, ...]
            //
            // 복사 방법: 채널별로 나눠서 memcpy
            //
            if let channelData = buffer.floatChannelData {
                // 채널 하나당 바이트 크기 계산
                let bytesPerChannel = sampleCount * format.bytesPerSample
                // 예: 1024 샘플 × 4바이트(float32) = 4096바이트

                data.withUnsafeBytes { dataBytes in
                    if let sourcePtr = dataBytes.baseAddress {
                        // 각 채널을 순회하며 복사
                        for channel in 0..<channels {
                            // 이 채널의 데이터 시작 위치 계산
                            let offset = channel * bytesPerChannel

                            // 예시 (스테레오):
                            // channel 0 (왼쪽): offset = 0 × 4096 = 0
                            // channel 1 (오른쪽): offset = 1 × 4096 = 4096
                            //
                            // 메모리 맵:
                            // sourcePtr + 0    : [L0,L1,L2,L3,...] (4096바이트)
                            // sourcePtr + 4096 : [R0,R1,R2,R3,...] (4096바이트)

                            // 이 채널의 데이터를 버퍼로 복사
                            memcpy(
                                channelData[channel],  // 목적지: 채널별 버퍼
                                sourcePtr + offset,    // 소스: 채널 시작 위치
                                bytesPerChannel        // 크기: 4096바이트
                            )

                            // 결과:
                            // channelData[0] ← [L0,L1,L2,L3,...]
                            // channelData[1] ← [R0,R1,R2,R3,...]
                        }
                    }
                }
            }
        }

        // 4단계: 변환 완료된 버퍼 반환
        // 이제 AVAudioPlayerNode.scheduleBuffer()로 재생 가능
        return buffer
    }
}

// MARK: - Supporting Types

/// @enum AudioFormat
/// @brief 오디오 샘플 포맷 정의
///
/// @details
/// PCM(Pulse Code Modulation) 샘플을 메모리에 저장하는 방식을 정의합니다.
/// 포맷 선택은 음질, 메모리 크기, 처리 속도에 영향을 줍니다.
///
/// ## 포맷 선택 가이드
///
/// **Float (부동소수점) vs Integer (정수)**:
/// ```
/// Float 형식 (권장):
/// ✅ 처리 중 오버플로우 없음 (-1.0 ~ +1.0 정규화)
/// ✅ 정밀도 높음 (32비트 = 약 150dB 다이내믹 레인지)
/// ✅ DSP 연산 간편 (증폭, 믹싱 등)
/// ❌ 메모리 2배 (4바이트)
/// ❌ 디스크 저장 시 비효율
///
/// Integer 형식:
/// ✅ 메모리 절약 (2바이트)
/// ✅ CD 표준 (Int16)
/// ✅ 디스크 저장 효율
/// ❌ 처리 중 오버플로우 주의
/// ❌ 정밀도 제한 (16비트 = 96dB)
/// ```
///
/// **Planar vs Interleaved**:
/// ```
/// Planar (채널 분리):
/// ✅ 채널별 처리 쉬움 (볼륨, 이펙트)
/// ✅ FFmpeg 기본 출력
/// ❌ 캐시 효율 낮음
/// ❌ 메모리 분산
///
/// Interleaved (채널 교차):
/// ✅ 메모리 연속성
/// ✅ 캐시 효율 높음
/// ✅ CD/파일 저장 표준
/// ❌ 채널별 처리 시 stride 필요
/// ```
///
/// ## 포맷별 메모리 크기 비교
/// (1024 샘플, 스테레오, 48kHz 기준)
///
/// | 포맷 | 1프레임 | 1초 | 1분 |
/// |------|---------|-----|-----|
/// | Float32 | 8KB | 375KB | 22MB |
/// | Int16 | 4KB | 188KB | 11MB |
///
/// ## 사용 예시
/// ```swift
/// // FFmpeg 디코딩 결과 (일반적으로 Planar)
/// let format: AudioFormat = .floatPlanar
///
/// // AVAudioEngine 재생 시 자동 변환
/// if format.isInterleaved {
///     // 그대로 사용
/// } else {
///     // Planar → Interleaved 변환 (toAudioBuffer 내부)
/// }
/// ```
enum AudioFormat: String, Codable {
    // ═══════════════════════════════════════════════════════
    // Float 형식 (32비트 부동소수점)
    // ═══════════════════════════════════════════════════════

    /// @brief 32비트 Float (Planar 배치)
    ///
    /// @details
    /// FFmpeg의 기본 오디오 출력 형식입니다.
    /// 각 채널의 샘플이 메모리에서 분리되어 연속으로 배치됩니다.
    ///
    /// **메모리 레이아웃 (스테레오, 4샘플)**:
    /// ```
    /// Offset 0~15:  [L0][L1][L2][L3]  ← 왼쪽 채널 (16바이트)
    /// Offset 16~31: [R0][R1][R2][R3]  ← 오른쪽 채널 (16바이트)
    /// ```
    ///
    /// **샘플 값 범위**: -1.0 ~ +1.0
    /// - -1.0 = 최대 음압 (음)
    /// -  0.0 = 무음
    /// - +1.0 = 최대 음압 (양)
    ///
    /// **특징**:
    /// - FFmpeg: `AV_SAMPLE_FMT_FLTP`
    /// - CoreAudio: `kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved`
    /// - 크기: 4바이트 × 샘플 수 × 채널 수
    case floatPlanar = "fltp"

    /// @brief 32비트 Float (Interleaved 배치)
    ///
    /// @details
    /// 스테레오의 경우 좌우 샘플이 번갈아 나타납니다.
    /// 일부 오디오 처리 라이브러리가 선호하는 형식입니다.
    ///
    /// **메모리 레이아웃 (스테레오, 4샘플)**:
    /// ```
    /// [L0][R0][L1][R1][L2][R2][L3][R3]
    ///  ↑   ↑   ↑   ↑   ...
    ///  좌  우  좌  우
    /// ```
    ///
    /// **특징**:
    /// - FFmpeg: `AV_SAMPLE_FMT_FLT`
    /// - CoreAudio: `kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked`
    /// - 크기: 4바이트 × 샘플 수 × 채널 수
    case floatInterleaved = "flt"

    // ═══════════════════════════════════════════════════════
    // Integer 형식 (16비트/32비트 정수)
    // ═══════════════════════════════════════════════════════

    /// @brief 16비트 Signed Integer (Planar 배치)
    ///
    /// @details
    /// 메모리를 절약하면서도 CD 품질을 제공합니다.
    /// 채널별로 분리되어 저장됩니다.
    ///
    /// **메모리 레이아웃 (스테레오, 4샘플)**:
    /// ```
    /// Offset 0~7:  [L0][L1][L2][L3]  ← 왼쪽 채널 (8바이트)
    /// Offset 8~15: [R0][R1][R2][R3]  ← 오른쪽 채널 (8바이트)
    /// ```
    ///
    /// **샘플 값 범위**: -32768 ~ +32767
    /// - -32768 = 최대 음압 (음)
    /// -      0 = 무음
    /// - +32767 = 최대 음압 (양)
    ///
    /// **Float 변환**:
    /// ```
    /// intValue → floatValue:
    /// floatValue = intValue / 32768.0
    ///
    /// 예:
    /// 32767 → 32767 / 32768.0 = +0.999969... ≈ +1.0
    /// -16384 → -16384 / 32768.0 = -0.5
    /// 0 → 0 / 32768.0 = 0.0
    /// ```
    ///
    /// **특징**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S16P`
    /// - CD 표준 (CD-DA)
    /// - 크기: Float의 절반 (2바이트 × 샘플 수 × 채널 수)
    case s16Planar = "s16p"

    /// @brief 16비트 Signed Integer (Interleaved 배치)
    ///
    /// @details
    /// CD 오디오 표준 형식입니다.
    /// WAV 파일의 기본 포맷이기도 합니다.
    ///
    /// **메모리 레이아웃 (스테레오, 4샘플)**:
    /// ```
    /// [L0][R0][L1][R1][L2][R2][L3][R3]
    /// 각 샘플 2바이트, 총 16바이트
    /// ```
    ///
    /// **특징**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S16`
    /// - CD 표준, WAV 표준
    /// - 크기: 2바이트 × 샘플 수 × 채널 수
    case s16Interleaved = "s16"

    /// @brief 32비트 Signed Integer (Planar 배치)
    ///
    /// @details
    /// 고음질이 필요하지만 부동소수점 연산을 피하고 싶을 때 사용합니다.
    /// DVD-Audio, 일부 고급 오디오 장비에서 사용됩니다.
    ///
    /// **샘플 값 범위**: -2,147,483,648 ~ +2,147,483,647
    ///
    /// **특징**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S32P`
    /// - 크기: 4바이트 × 샘플 수 × 채널 수 (Float와 동일)
    case s32Planar = "s32p"

    /// @brief 32비트 Signed Integer (Interleaved 배치)
    ///
    /// @details
    /// **특징**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S32`
    /// - 크기: 4바이트 × 샘플 수 × 채널 수
    case s32Interleaved = "s32"

    /// @brief 샘플 하나당 바이트 크기
    ///
    /// @return 바이트 크기
    ///
    /// @details
    /// 채널 수를 제외한, 순수하게 하나의 샘플 값을 저장하는 데 필요한 바이트 수입니다.
    ///
    /// **반환값**:
    /// ```
    /// Float32 / Int32: 4바이트
    /// Int16:           2바이트
    /// ```
    var bytesPerSample: Int {
        switch self {
        case .floatPlanar, .floatInterleaved, .s32Planar, .s32Interleaved:
            return 4  // 32비트 = 4바이트
        case .s16Planar, .s16Interleaved:
            return 2  // 16비트 = 2바이트
        }
    }

    /// @brief Interleaved 형식인가?
    ///
    /// @return Interleaved이면 true, Planar이면 false
    ///
    /// @details
    /// 채널들이 교차(Interleaved)되어 있는지, 분리(Planar)되어 있는지 반환합니다.
    ///
    /// **반환값**:
    /// ```
    /// Interleaved 포맷: true  (flt, s16, s32)
    /// Planar 포맷:      false (fltp, s16p, s32p)
    /// ```
    var isInterleaved: Bool {
        switch self {
        case .floatInterleaved, .s16Interleaved, .s32Interleaved:
            return true  // 교차 배치
        case .floatPlanar, .s16Planar, .s32Planar:
            return false // 평면 배치
        }
    }

    /// @brief AVAudioCommonFormat으로 변환
    ///
    /// @return AVAudioCommonFormat
    ///
    /// @details
    /// Apple의 AVFoundation에서 사용하는 표준 포맷 enum으로 변환합니다.
    /// toAudioBuffer() 메서드에서 AVAudioFormat 생성 시 사용됩니다.
    ///
    /// **매핑**:
    /// ```
    /// Float (32비트) → .pcmFormatFloat32
    /// Int16 (16비트) → .pcmFormatInt16
    /// Int32 (32비트) → .pcmFormatInt32
    /// ```
    var commonFormat: AVAudioCommonFormat {
        switch self {
        case .floatPlanar, .floatInterleaved:
            return .pcmFormatFloat32
        case .s16Planar, .s16Interleaved:
            return .pcmFormatInt16
        case .s32Planar, .s32Interleaved:
            return .pcmFormatInt32
        }
    }
}

// MARK: - Equatable

/// @brief AudioFrame 동등성 비교
///
/// @details
/// 두 AudioFrame이 "같은" 프레임인지 판단합니다.
/// 주로 디버깅, 테스트, 중복 제거 등에 사용됩니다.
///
/// **비교 기준**:
/// - timestamp: 같은 시점인가?
/// - sampleCount: 같은 개수의 샘플인가?
/// - sampleRate: 같은 샘플레이트인가?
/// - channels: 같은 채널 수인가?
///
/// **주의**: `data`는 비교하지 않습니다!
/// 실제 PCM 바이트 데이터가 달라도, 메타정보가 같으면 "같은 프레임"으로 간주합니다.
/// 이는 성능상의 이유입니다. (data는 수천 바이트일 수 있음)
///
/// ## 사용 예시
/// ```swift
/// let frame1 = AudioFrame(timestamp: 1.0, ...)
/// let frame2 = AudioFrame(timestamp: 1.0, ...)
/// let frame3 = AudioFrame(timestamp: 2.0, ...)
///
/// frame1 == frame2  // true (같은 타임스탬프)
/// frame1 == frame3  // false (다른 타임스탬프)
///
/// // 중복 프레임 제거
/// let frames = [frame1, frame2, frame3]
/// let uniqueFrames = Array(Set(frames))  // [frame1, frame3]
/// ```
extension AudioFrame: Equatable {
    /// @brief 두 AudioFrame 비교
    /// @param lhs 왼쪽 피연산자
    /// @param rhs 오른쪽 피연산자
    /// @return 동등하면 true
    static func == (lhs: AudioFrame, rhs: AudioFrame) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
            lhs.sampleCount == rhs.sampleCount &&
            lhs.sampleRate == rhs.sampleRate &&
            lhs.channels == rhs.channels

        // data는 비교하지 않음 (성능상 이유)
        // 필요시 data 비교 추가 가능:
        // && lhs.data == rhs.data
    }
}

// MARK: - CustomStringConvertible

/// @brief AudioFrame 디버그 문자열 표현
///
/// @details
/// print() 또는 디버거에서 AudioFrame을 출력할 때 보기 좋은 형태로 변환합니다.
///
/// **출력 예시**:
/// ```
/// Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes
///
/// 해석:
/// - 타임스탬프: 1.500초
/// - 샘플레이트: 48000 Hz
/// - 채널: stereo (2채널)
/// - 포맷: fltp (Float32 Planar)
/// - 샘플 개수: 1024개
/// - 데이터 크기: 8192바이트 (8KB)
/// ```
///
/// **채널 표시**:
/// ```
/// channels = 1 → "mono"
/// channels = 2 → "stereo"
/// channels = 6 → "6ch" (5.1 서라운드)
/// ```
///
/// ## 사용 예시
/// ```swift
/// let frame = AudioFrame(...)
///
/// // 직접 출력
/// print(frame)
/// // 출력: Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes
///
/// // 로그에 포함
/// print("재생 중: \(frame)")
/// // 출력: 재생 중: Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes
/// ```
extension AudioFrame: CustomStringConvertible {
    /// @brief 디버그 문자열
    var description: String {
        // 채널 수를 사람이 읽기 좋은 문자열로 변환
        let channelStr: String
        if channels == 1 {
            channelStr = "mono"      // 모노
        } else if channels == 2 {
            channelStr = "stereo"    // 스테레오
        } else {
            channelStr = "\(channels)ch"  // "6ch", "8ch" 등
        }

        // 포맷된 문자열 생성
        return String(
            format: "Audio @ %.3fs (%d Hz, %@, %@ format) %d samples, %d bytes",
            timestamp,              // 타임스탬프 (소수점 3자리)
            sampleRate,            // 샘플레이트
            channelStr,            // 채널 문자열
            format.rawValue,       // 포맷 ("fltp", "s16" 등)
            sampleCount,           // 샘플 개수
            dataSize               // 바이트 크기
        )

        // 예시 결과:
        // "Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes"
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// 통합 가이드: AudioFrame 사용 플로우
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ 디코딩 (VideoDecoder)
// ────────────────────────────────────────────────
// MP3/AAC 파일 → FFmpeg 디코딩 → PCM 데이터
//
// let audioFrame = AudioFrame(
//     timestamp: pts,
//     sampleRate: 48000,
//     channels: 2,
//     format: .floatPlanar,
//     data: pcmData,
//     sampleCount: 1024
// )
//
// 2️⃣ 큐잉 (VideoChannel)
// ────────────────────────────────────────────────
// 디코딩된 프레임을 버퍼에 저장
//
// audioBuffer.append(audioFrame)
//
// 3️⃣ 동기화 (SyncController)
// ────────────────────────────────────────────────
// 비디오 프레임과 타임스탬프 비교
//
// if abs(videoFrame.timestamp - audioFrame.timestamp) < 0.05 {
//     // 동기화 OK (±50ms 이내)
// }
//
// 4️⃣ 재생 (AudioPlayer)
// ────────────────────────────────────────────────
// AVAudioPCMBuffer로 변환 후 재생
//
// if let buffer = audioFrame.toAudioBuffer() {
//     playerNode.scheduleBuffer(buffer)
// }
//
// 5️⃣ 스피커 출력
// ────────────────────────────────────────────────
// AVAudioEngine → 시스템 오디오 → 🔊
//
// ═══════════════════════════════════════════════════════════════════════════
