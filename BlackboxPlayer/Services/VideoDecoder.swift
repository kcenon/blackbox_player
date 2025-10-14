/// @file VideoDecoder.swift
/// @brief FFmpeg-based video/audio decoder
/// @author BlackboxPlayer Development Team
/// @details
/// 이 파일은 FFmpeg 라이브러리를 사용하여 비디오와 오디오를 디코딩하는 클래스를 정의합니다.
/// FFmpeg은 C 언어로 작성된 강력한 멀티미디어 프레임워크입니다.

import Foundation       // Swift 기본 기능 (String, Data 등)
import CoreGraphics     // 그래픽 관련 타입 (CGSize, CGRect 등)

/// @class VideoDecoder
/// @brief 블랙박스 영상 파일을 디코딩하는 클래스입니다.
///
/// @details
/// ## 주요 기능:
/// - H.264 비디오 디코딩 (압축된 영상을 화면에 표시할 수 있는 형태로 변환)
/// - MP3 오디오 디코딩 (압축된 음성을 재생할 수 있는 형태로 변환)
/// - 비디오 탐색 (특정 시간으로 이동)
/// - 프레임 단위 디코딩 (한 장씩 영상 프레임 추출)
///
/// ## 디코딩이란?
/// - 압축된 영상 파일(예: MP4)을 압축 해제하여 화면에 표시할 수 있는 형태로 변환하는 과정
/// - 예: H.264로 압축된 데이터 → RGB 픽셀 데이터
///
/// ## 사용 예:
/// ```swift
/// let decoder = VideoDecoder(filePath: "/path/to/video.mp4")
/// try decoder.initialize()
///
/// while let frames = try decoder.decodeNextFrame() {
///     if let videoFrame = frames.video {
///         // 비디오 프레임 처리
///     }
/// }
/// ```
class VideoDecoder {

    // MARK: - Properties (속성)
    // 클래스의 데이터를 저장하는 변수들입니다

    // ============================================
    // MARK: 파일 정보
    // ============================================

    /// @var filePath
    /// @brief 디코딩할 비디오 파일의 경로
    /// @details
    /// - 예: "/Users/username/Videos/blackbox.mp4"
    /// - private: 외부에서 직접 수정할 수 없음 (초기화 시에만 설정)
    private let filePath: String

    // ============================================
    // MARK: FFmpeg 컨텍스트 (Context)
    // ============================================

    /*
     FFmpeg의 "컨텍스트(Context)"란?
     - 디코딩에 필요한 모든 정보와 상태를 담고 있는 구조체
     - C 언어로 작성되어 있어 Swift에서는 포인터로 접근
     - UnsafeMutablePointer: C의 포인터를 Swift에서 사용하는 타입
     */

    /// @var formatContext
    /// @brief FormatContext - 파일의 전체 구조 정보를 담는 컨테이너
    /// @details
    /// - 어떤 스트림들이 있는지 (비디오, 오디오, 자막 등)
    /// - 파일 포맷이 무엇인지 (MP4, AVI, MKV 등)
    /// - 전체 재생 시간이 얼마인지
    /// - Optional(?): 초기화 전에는 nil (없는 상태)
    private var formatContext: UnsafeMutablePointer<AVFormatContext>?

    /// @var videoCodecContext
    /// @brief Video Codec Context - 비디오 디코딩 정보
    /// @details
    /// - 코덱(Codec): 압축/압축해제 방식 (H.264, H.265 등)
    /// - 해상도 (width, height)
    /// - 프레임레이트 (초당 프레임 수)
    /// - 픽셀 포맷 (YUV420P, RGB 등)
    private var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?

    /// @var audioCodecContext
    /// @brief Audio Codec Context - 오디오 디코딩 정보
    /// @details
    /// - 샘플레이트 (44100Hz, 48000Hz 등)
    /// - 채널 수 (모노=1, 스테레오=2)
    /// - 오디오 포맷 (PCM, AAC 등)
    private var audioCodecContext: UnsafeMutablePointer<AVCodecContext>?

    /// @var scalerContext
    /// @brief Scaler Context - 픽셀 포맷 변환기
    /// @details
    /// - SwScale(Software Scale): 픽셀 포맷을 변환하는 FFmpeg 컴포넌트
    /// - 예: YUV420P(비디오 인코딩 표준) → BGRA(화면 표시용)
    /// - 해상도 변경도 가능 (예: 1080p → 720p)
    private var scalerContext: UnsafeMutablePointer<SwsContext>?

    // ============================================
    // MARK: 스트림 인덱스
    // ============================================

    /*
     스트림(Stream)이란?
     - 비디오 파일 안에는 여러 개의 독립적인 데이터 흐름이 있음
     - 예: 스트림#0=비디오, 스트림#1=오디오, 스트림#2=자막
     - 각 스트림은 고유한 인덱스 번호를 가짐
     */

    /// @var videoStreamIndex
    /// @brief 비디오 스트림의 인덱스 번호
    /// @details
    /// - -1: 아직 찾지 못함 (초기값)
    /// - 0 이상: 찾은 비디오 스트림의 인덱스
    private var videoStreamIndex: Int = -1

    /// @var audioStreamIndex
    /// @brief 오디오 스트림의 인덱스 번호
    /// @details
    /// - -1: 아직 찾지 못함 또는 오디오 없음
    /// - 0 이상: 찾은 오디오 스트림의 인덱스
    private var audioStreamIndex: Int = -1

    // ============================================
    // MARK: 디코딩 상태
    // ============================================

    /// @var frameNumber
    /// @brief 현재 디코딩한 프레임 번호
    /// @details
    /// - 0부터 시작하여 1씩 증가
    /// - 디버깅 및 진행 상황 추적에 사용
    /// - private(set): 외부에서 읽기는 가능, 수정은 불가
    private(set) var frameNumber: Int = 0

    /// @var currentTimestamp
    /// @brief 현재 프레임의 타임스탬프 (초 단위)
    /// @details
    /// - 마지막으로 디코딩된 프레임의 시간
    /// - seek 및 동기화에 사용
    private(set) var currentTimestamp: TimeInterval = 0

    /// @var isInitialized
    /// @brief 디코더가 초기화되었는지 여부
    /// @details
    /// - false: 아직 initialize() 호출 안 함
    /// - true: initialize() 완료, 디코딩 가능
    /// - private(set): 외부에서 읽을 수만 있고 수정은 불가
    private(set) var isInitialized: Bool = false

    // ============================================
    // MARK: 스트림 정보
    // ============================================

    /// @var videoInfo
    /// @brief 비디오 스트림의 상세 정보
    /// @details
    /// - Optional(?): 초기화 전에는 nil
    /// - VideoStreamInfo 구조체에는 해상도, 프레임레이트 등이 담김
    private(set) var videoInfo: VideoStreamInfo?

    /// @var audioInfo
    /// @brief 오디오 스트림의 상세 정보
    /// @details
    /// - Optional(?): 오디오가 없으면 nil
    /// - AudioStreamInfo 구조체에는 샘플레이트, 채널 수 등이 담김
    private(set) var audioInfo: AudioStreamInfo?

    // MARK: - Initialization (초기화)

    /// @brief 디코더 객체를 생성합니다.
    ///
    /// @param filePath 디코딩할 비디오 파일의 전체 경로
    ///
    /// @details
    /// 주의사항:
    /// - 이 메서드는 객체만 생성하고, 실제 디코딩 준비는 하지 않습니다
    /// - 디코딩을 시작하려면 반드시 `initialize()` 메서드를 호출해야 합니다
    ///
    /// 예제:
    /// ```swift
    /// let decoder = VideoDecoder(filePath: "/path/to/video.mp4")
    /// // 아직 디코딩할 수 없는 상태
    /// try decoder.initialize()  // 이제 디코딩 가능
    /// ```
    init(filePath: String) {
        self.filePath = filePath
    }

    /// @brief 객체가 메모리에서 해제될 때 자동으로 호출됩니다.
    ///
    /// @details
    /// 메모리 누수 방지:
    /// - FFmpeg의 C 라이브러리는 Swift의 자동 메모리 관리(ARC)를 사용하지 않음
    /// - 따라서 수동으로 메모리를 해제해야 함
    /// - cleanup()을 호출하여 모든 FFmpeg 리소스를 정리
    deinit {
        cleanup()
    }

    // MARK: - Public Methods (공개 메서드)
    // 외부에서 호출할 수 있는 메서드들

    /// @brief 디코더를 초기화하고 비디오 파일을 엽니다.
    ///
    /// @details
    /// 초기화 과정:
    /// 1. 파일 존재 확인
    /// 2. FFmpeg으로 파일 열기
    /// 3. 비디오/오디오 스트림 찾기
    /// 4. 각 스트림의 디코더 초기화
    ///
    /// @throws DecoderError
    ///   - `.alreadyInitialized`: 이미 초기화됨
    ///   - `.cannotOpenFile`: 파일을 열 수 없음
    ///   - `.cannotFindStreamInfo`: 스트림 정보를 찾을 수 없음
    ///   - `.noVideoStream`: 비디오 스트림이 없음
    ///
    /// 사용 예:
    /// ```swift
    /// do {
    ///     try decoder.initialize()
    ///     print("디코더 초기화 성공!")
    /// } catch {
    ///     print("초기화 실패: \(error)")
    /// }
    /// ```
    func initialize() throws {
        // 1. 중복 초기화 방지
        // - 이미 초기화된 디코더를 다시 초기화하면 메모리 누수 발생 가능
        guard !isInitialized else {
            throw DecoderError.alreadyInitialized
        }

        // 2. 파일 존재 확인
        // - FileManager: iOS/macOS의 파일 시스템 관리자
        // - fileExists(atPath:): 해당 경로에 파일이 있는지 확인
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DecoderError.cannotOpenFile("File not found: \(filePath)")
        }

        // 3. FFmpeg으로 파일 열기
        // withCString: Swift String을 C 문자열(char*)로 변환
        // - FFmpeg은 C 라이브러리이므로 C 문자열 필요
        // - cString을 클로저 안에서만 사용 가능 (메모리 안전성)
        var formatCtx: UnsafeMutablePointer<AVFormatContext>?
        let openResult = filePath.withCString { cString in
            // avformat_open_input: FFmpeg 함수, 파일을 열어 포맷 정보를 읽음
            // &formatCtx: 결과를 저장할 변수의 포인터
            // nil: 특정 포맷 지정 안 함 (자동 감지)
            // nil: 추가 옵션 없음
            return avformat_open_input(&formatCtx, cString, nil, nil)
        }

        // 4. 파일 열기 결과 확인
        // - FFmpeg 함수는 성공 시 0, 실패 시 음수 에러 코드 반환
        if openResult != 0 {
            // 에러 메시지를 사람이 읽을 수 있는 형태로 변환
            var errorBuffer = [Int8](repeating: 0, count: 256)  // C 문자열 버퍼
            av_strerror(openResult, &errorBuffer, 256)  // 에러 코드를 문자열로 변환
            let errorString = String(cString: errorBuffer)  // Swift String으로 변환
            throw DecoderError.cannotOpenFile("Failed to open \(filePath): \(errorString)")
        }
        self.formatContext = formatCtx

        // 5. 스트림 정보 찾기
        // avformat_find_stream_info: 파일을 분석하여 스트림 정보 추출
        // - 비디오/오디오 코덱, 해상도, 샘플레이트 등을 파악
        // - 실패 시 음수 반환
        if avformat_find_stream_info(formatContext, nil) < 0 {
            cleanup()  // 실패 시 메모리 정리
            throw DecoderError.cannotFindStreamInfo(filePath)
        }

        // 6. 포맷 컨텍스트 안전성 확인
        guard let formatCtx = formatContext else {
            throw DecoderError.cannotOpenFile(filePath)
        }

        // 7. 파일 내의 모든 스트림 검색
        // nb_streams: 스트림 개수 (Number of Streams)
        let numStreams = Int(formatCtx.pointee.nb_streams)
        let streams = formatCtx.pointee.streams  // 스트림 배열

        // 각 스트림을 순회하며 비디오/오디오 스트림 찾기
        for i in 0..<numStreams {
            guard let stream = streams?[i] else { continue }

            // codecpar: 코덱 파라미터 (해상도, 샘플레이트 등)
            let codecType = stream.pointee.codecpar.pointee.codec_type

            // 비디오 스트림 찾기
            if codecType == AVMEDIA_TYPE_VIDEO && videoStreamIndex == -1 {
                videoStreamIndex = i
                try initializeVideoStream(stream: stream)
            }
            // 오디오 스트림 찾기
            else if codecType == AVMEDIA_TYPE_AUDIO && audioStreamIndex == -1 {
                audioStreamIndex = i
                try initializeAudioStream(stream: stream)
            }
        }

        // 8. 필수 스트림 확인
        // - 최소한 비디오 스트림은 반드시 있어야 함
        // - 오디오는 선택사항 (오디오 없는 영상도 재생 가능)
        guard videoStreamIndex >= 0 else {
            cleanup()
            throw DecoderError.noVideoStream
        }

        // 9. 초기화 완료 표시
        isInitialized = true
    }

    /// @brief 다음 프레임을 디코딩합니다.
    ///
    /// @details
    /// 디코딩 과정:
    /// 1. 파일에서 압축된 패킷 읽기
    /// 2. 패킷이 비디오인지 오디오인지 확인
    /// 3. 해당 디코더로 압축 해제
    /// 4. 프레임 데이터 반환
    ///
    /// @return (video: VideoFrame?, audio: AudioFrame?) 튜플
    ///   - 비디오 프레임이면 video에 데이터, audio는 nil
    ///   - 오디오 프레임이면 audio에 데이터, video는 nil
    ///   - 파일 끝에 도달하면 nil 반환
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: 초기화 안 됨
    ///   - `.readFrameError`: 프레임 읽기 실패
    ///   - 기타 디코딩 관련 에러
    ///
    /// 사용 예:
    /// ```swift
    /// while let frames = try decoder.decodeNextFrame() {
    ///     if let videoFrame = frames.video {
    ///         print("비디오 프레임: \(videoFrame.timestamp)초")
    ///     }
    ///     if let audioFrame = frames.audio {
    ///         print("오디오 프레임: \(audioFrame.timestamp)초")
    ///     }
    /// }
    /// print("파일 끝")
    /// ```
    func decodeNextFrame() throws -> (video: VideoFrame?, audio: AudioFrame?)? {
        // 1. 초기화 확인
        guard isInitialized else {
            throw DecoderError.notInitialized
        }

        guard let formatCtx = formatContext else {
            throw DecoderError.notInitialized
        }

        // 2. 패킷 메모리 할당
        // 패킷(Packet): 압축된 데이터의 작은 조각
        // - 비디오/오디오 데이터는 패킷 단위로 저장됨
        // - 각 패킷을 디코딩하면 하나 이상의 프레임이 나옴
        guard let packet = av_packet_alloc() else {
            throw DecoderError.cannotAllocatePacket
        }
        var packetPtr: UnsafeMutablePointer<AVPacket>? = packet
        // defer: 이 함수가 끝나면 자동으로 실행 (메모리 해제)
        defer { av_packet_free(&packetPtr) }

        // 3. 파일에서 다음 패킷 읽기
        let readResult = av_read_frame(formatCtx, packet)

        // 4. 파일 끝(EOF) 확인
        // -541478725: AVERROR_EOF 에러 코드
        if readResult == -541478725 {
            return nil  // 더 이상 읽을 데이터 없음
        } else if readResult < 0 {
            throw DecoderError.readFrameError(readResult)
        }

        // 5. 패킷의 스트림 타입 확인
        // stream_index: 이 패킷이 어느 스트림에서 왔는지
        let streamIndex = Int(packet.pointee.stream_index)

        // 6. 스트림 타입에 따라 디코딩
        if streamIndex == videoStreamIndex {
            // 비디오 패킷 디코딩
            let videoFrame = try decodeVideoPacket(packet: packet)
            return (video: videoFrame, audio: nil)
        } else if streamIndex == audioStreamIndex {
            // 오디오 패킷 디코딩
            let audioFrame = try decodeAudioPacket(packet: packet)
            return (video: nil, audio: audioFrame)
        }

        // 7. 알 수 없는 스트림 (자막 등)
        // - 무시하고 다음 패킷으로 넘어감
        return (video: nil, audio: nil)
    }

    /// @brief 특정 시간으로 이동(시크)합니다.
    ///
    /// @param timestamp 이동할 시간 (초 단위)
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: 초기화 안 됨
    ///   - `.unknown`: 시크 실패
    ///
    /// @details
    /// 시크(Seek)란?
    /// - 영상의 특정 시점으로 빠르게 이동하는 기능
    /// - 예: 10초 → 60초로 건너뛰기
    ///
    /// 키프레임(Keyframe)이란?
    /// - 독립적으로 디코딩 가능한 프레임
    /// - 정확한 시크를 위해 키프레임부터 디코딩 시작
    /// - AVSEEK_FLAG_BACKWARD: 목표 시점 이전의 키프레임으로 이동
    ///
    /// 사용 예:
    /// ```swift
    /// try decoder.seek(to: 30.0)  // 30초 위치로 이동
    /// ```
    func seek(to timestamp: TimeInterval) throws {
        guard isInitialized else {
            throw DecoderError.notInitialized
        }

        guard let formatCtx = formatContext else {
            throw DecoderError.notInitialized
        }

        // 1. 타임스탬프를 스트림의 시간 단위로 변환
        // Time Base: 스트림마다 다른 시간 단위
        // - 예: 1/30000 (30fps 영상의 경우)
        // - PTS(Presentation Time Stamp) = 실제 시간 / time_base
        let timeBase = formatCtx.pointee.streams[videoStreamIndex]!.pointee.time_base
        let targetPTS = Int64(timestamp * Double(timeBase.den) / Double(timeBase.num))

        // 2. 키프레임으로 시크
        // av_seek_frame: 지정된 PTS로 이동
        // AVSEEK_FLAG_BACKWARD: 목표 시점 이전의 가장 가까운 키프레임으로
        let seekResult = av_seek_frame(formatCtx, Int32(videoStreamIndex), targetPTS, AVSEEK_FLAG_BACKWARD)
        if seekResult < 0 {
            throw DecoderError.unknown("Seek failed")
        }

        // 3. 코덱 버퍼 플러시
        // - 시크하면 기존에 디코딩 중이던 데이터는 버려야 함
        // - 버퍼를 비우고 새로운 위치에서 다시 디코딩 시작
        if let videoCtx = videoCodecContext {
            avcodec_flush_buffers(videoCtx)
        }
        if let audioCtx = audioCodecContext {
            avcodec_flush_buffers(audioCtx)
        }

        // 4. 프레임 번호 초기화
        frameNumber = 0
    }

    /// @brief 영상의 전체 재생 시간을 반환합니다.
    ///
    /// @return 재생 시간 (초), 정보가 없으면 nil
    ///
    /// @details
    /// AV_NOPTS_VALUE:
    /// - FFmpeg에서 "시간 정보 없음"을 나타내는 특수 값
    /// - 일부 스트리밍 파일은 전체 길이를 모를 수 있음
    ///
    /// 사용 예:
    /// ```swift
    /// if let duration = decoder.getDuration() {
    ///     print("영상 길이: \(duration)초")
    /// } else {
    ///     print("길이 정보 없음 (라이브 스트림?)")
    /// }
    /// ```
    func getDuration() -> TimeInterval? {
        guard let formatCtx = formatContext else { return nil }

        let duration = formatCtx.pointee.duration

        // AV_NOPTS_VALUE 확인 (시간 정보 없음)
        if duration == Int64(bitPattern: 0x8000000000000001) {
            return nil
        }

        // AV_TIME_BASE: FFmpeg의 기본 시간 단위 (1,000,000 = 1초)
        // duration을 AV_TIME_BASE로 나누면 초 단위로 변환
        return Double(duration) / Double(AV_TIME_BASE)
    }

    /// @brief 현재 프레임의 타임스탬프를 반환합니다.
    ///
    /// @return 현재 타임스탬프 (초 단위)
    ///
    /// @details
    /// 사용 예:
    /// ```swift
    /// let currentTime = decoder.getCurrentTimestamp()
    /// print("현재 재생 위치: \(currentTime)초")
    /// ```
    func getCurrentTimestamp() -> TimeInterval {
        return currentTimestamp
    }

    /// @brief 특정 프레임 번호로 이동합니다.
    ///
    /// @param targetFrame 이동할 프레임 번호 (0부터 시작)
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: 초기화 안 됨
    ///   - `.unknown`: 시크 실패
    ///
    /// @details
    /// 프레임 번호를 타임스탬프로 변환하여 seek합니다.
    /// - 프레임 번호 = 타임스탬프 × 프레임레이트
    /// - 예: 30fps 영상의 60번 프레임 = 2초
    ///
    /// 사용 예:
    /// ```swift
    /// try decoder.seekToFrame(120)  // 120번 프레임으로 이동
    /// ```
    func seekToFrame(_ targetFrame: Int) throws {
        guard isInitialized, let videoInfo = videoInfo else {
            throw DecoderError.notInitialized
        }

        // 프레임 번호를 타임스탬프로 변환
        let timestamp = Double(targetFrame) / videoInfo.frameRate
        try seek(to: timestamp)
    }

    /// @brief 다음 프레임으로 이동합니다.
    ///
    /// @return 디코딩된 비디오 프레임
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: 초기화 안 됨
    ///   - 기타 디코딩 관련 에러
    ///
    /// @details
    /// 현재 위치에서 다음 비디오 프레임을 디코딩합니다.
    /// 오디오 프레임은 건너뜁니다.
    ///
    /// 사용 예:
    /// ```swift
    /// if let frame = try decoder.stepForward() {
    ///     print("다음 프레임: \(frame.timestamp)초")
    /// }
    /// ```
    func stepForward() throws -> VideoFrame? {
        // 비디오 프레임을 찾을 때까지 계속 디코딩
        while let frames = try decodeNextFrame() {
            if let videoFrame = frames.video {
                return videoFrame
            }
            // 오디오 프레임은 건너뜀
        }
        return nil
    }

    /// @brief 이전 프레임으로 이동합니다.
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: 초기화 안 됨
    ///   - `.unknown`: 시크 실패
    ///
    /// @details
    /// 프레임 단위로 뒤로 이동:
    /// 1. 현재 타임스탬프에서 프레임 1개 시간만큼 뺌
    /// 2. 해당 타임스탬프로 seek
    /// 3. 0초 미만으로는 이동하지 않음
    ///
    /// 주의사항:
    /// - seek는 키프레임 단위로 동작하므로 정확히 이전 프레임으로
    ///   이동하지 않을 수 있습니다
    /// - 정확한 프레임 탐색이 필요한 경우 seekToFrame()을 사용하세요
    ///
    /// 사용 예:
    /// ```swift
    /// try decoder.stepBackward()
    /// if let frame = try decoder.stepForward() {
    ///     print("이전 프레임: \(frame.timestamp)초")
    /// }
    /// ```
    func stepBackward() throws {
        guard isInitialized, let videoInfo = videoInfo else {
            throw DecoderError.notInitialized
        }

        // 프레임 1개의 시간 계산
        let frameDuration = 1.0 / videoInfo.frameRate

        // 이전 프레임의 타임스탬프 계산 (0초 미만으로 가지 않음)
        let previousTimestamp = max(0, currentTimestamp - frameDuration)

        // 이전 타임스탬프로 seek
        try seek(to: previousTimestamp)
    }

    // MARK: - Private Methods (내부 메서드)
    // 클래스 내부에서만 사용하는 헬퍼 메서드들

    /// @brief 비디오 스트림을 초기화합니다.
    ///
    /// @param stream FFmpeg 스트림 포인터
    ///
    /// @throws DecoderError (코덱 관련 에러)
    ///
    /// @details
    /// 초기화 단계:
    /// 1. 코덱 찾기 (H.264, H.265 등)
    /// 2. 코덱 컨텍스트 생성
    /// 3. 코덱 파라미터 복사
    /// 4. 코덱 열기
    /// 5. 스트림 정보 추출
    private func initializeVideoStream(stream: UnsafeMutablePointer<AVStream>) throws {
        // 1. 코덱 파라미터 가져오기
        guard let codecPar = stream.pointee.codecpar else {
            throw DecoderError.codecNotFound("video")
        }

        // 2. 코덱 찾기
        // avcodec_find_decoder: 코덱 ID로 디코더 찾기
        // - codec_id: 코덱 종류 (H.264 = AV_CODEC_ID_H264)
        guard let codec = avcodec_find_decoder(codecPar.pointee.codec_id) else {
            throw DecoderError.codecNotFound("video")
        }

        // 3. 코덱 컨텍스트 할당
        // - 컨텍스트: 디코딩에 필요한 상태와 설정을 담는 구조체
        guard let codecCtx = avcodec_alloc_context3(codec) else {
            throw DecoderError.cannotAllocateCodecContext
        }

        // 4. 파라미터 복사
        // - 파일에서 읽은 코덱 파라미터를 컨텍스트에 복사
        // - 해상도, 프레임레이트, 픽셀 포맷 등
        if avcodec_parameters_to_context(codecCtx, codecPar) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)  // 실패 시 메모리 해제
            throw DecoderError.cannotCopyCodecParameters
        }

        // 5. 코덱 열기
        // - 디코더를 실제로 사용할 수 있는 상태로 초기화
        if avcodec_open2(codecCtx, codec, nil) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotOpenCodec("video")
        }

        self.videoCodecContext = codecCtx

        // 6. 비디오 정보 추출
        let width = Int(codecCtx.pointee.width)
        let height = Int(codecCtx.pointee.height)
        let timeBase = stream.pointee.time_base
        // av_q2d: AVRational을 double로 변환
        let frameRate = av_q2d(stream.pointee.r_frame_rate)

        self.videoInfo = VideoStreamInfo(
            width: width,
            height: height,
            frameRate: frameRate,
            codecName: String(cString: avcodec_get_name(codecPar.pointee.codec_id)),
            bitrate: Int(codecPar.pointee.bit_rate),
            timeBase: timeBase
        )
    }

    /// @brief 오디오 스트림을 초기화합니다.
    ///
    /// @param stream FFmpeg 스트림 포인터
    ///
    /// @throws DecoderError (코덱 관련 에러)
    ///
    /// @details
    /// 비디오 스트림 초기화와 유사하지만 오디오 관련 정보를 추출합니다.
    private func initializeAudioStream(stream: UnsafeMutablePointer<AVStream>) throws {
        guard let codecPar = stream.pointee.codecpar else {
            throw DecoderError.codecNotFound("audio")
        }

        // 오디오 디코더 찾기 (MP3, AAC 등)
        guard let codec = avcodec_find_decoder(codecPar.pointee.codec_id) else {
            throw DecoderError.codecNotFound("audio")
        }

        guard let codecCtx = avcodec_alloc_context3(codec) else {
            throw DecoderError.cannotAllocateCodecContext
        }

        if avcodec_parameters_to_context(codecCtx, codecPar) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotCopyCodecParameters
        }

        if avcodec_open2(codecCtx, codec, nil) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotOpenCodec("audio")
        }

        self.audioCodecContext = codecCtx

        // 오디오 정보 추출
        let sampleRate = Int(codecCtx.pointee.sample_rate)  // 샘플레이트: 초당 샘플 수
        let channels = Int(codecCtx.pointee.ch_layout.nb_channels)  // 채널: 모노=1, 스테레오=2
        let timeBase = stream.pointee.time_base

        self.audioInfo = AudioStreamInfo(
            sampleRate: sampleRate,
            channels: channels,
            codecName: String(cString: avcodec_get_name(codecPar.pointee.codec_id)),
            bitrate: Int(codecPar.pointee.bit_rate),
            timeBase: timeBase
        )
    }

    /// @brief 압축된 비디오 패킷을 디코딩합니다.
    ///
    /// @param packet 압축된 비디오 패킷
    ///
    /// @return 디코딩된 VideoFrame, EAGAIN이면 nil
    ///
    /// @throws DecoderError
    ///
    /// @details
    /// 디코딩 2단계:
    /// 1. Send: 압축된 패킷을 디코더에 전송
    /// 2. Receive: 디코딩된 프레임 받기
    ///
    /// EAGAIN 에러:
    /// - 디코더가 더 많은 패킷을 필요로 함
    /// - 정상적인 상황, 다음 패킷 계속 전송
    private func decodeVideoPacket(packet: UnsafeMutablePointer<AVPacket>) throws -> VideoFrame? {
        guard let codecCtx = videoCodecContext else {
            throw DecoderError.notInitialized
        }

        // 1. 패킷을 디코더에 전송
        let sendResult = avcodec_send_packet(codecCtx, packet)
        if sendResult < 0 {
            throw DecoderError.sendPacketError(sendResult)
        }

        // 2. 프레임 메모리 할당
        guard let frame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var framePtr: UnsafeMutablePointer<AVFrame>? = frame
        defer { av_frame_free(&framePtr) }

        // 3. 디코딩된 프레임 받기
        let receiveResult = avcodec_receive_frame(codecCtx, frame)

        // EAGAIN 처리: 더 많은 패킷 필요
        // -541478725: AVERROR_EOF
        // -11: AVERROR(EAGAIN) on Linux
        // -35: AVERROR(EAGAIN) on macOS
        if receiveResult == -541478725 || receiveResult == -11 || receiveResult == -35 {
            return nil  // 다음 패킷 필요
        } else if receiveResult < 0 {
            throw DecoderError.receiveFrameError(receiveResult)
        }

        // 4. 프레임을 RGB 포맷으로 변환
        guard let videoFrame = try convertFrameToRGB(frame: frame) else {
            return nil
        }

        frameNumber += 1
        return videoFrame
    }

    /// @brief 압축된 오디오 패킷을 디코딩합니다.
    ///
    /// @param packet 압축된 오디오 패킷
    ///
    /// @return 디코딩된 AudioFrame, EAGAIN이면 nil
    ///
    /// @throws DecoderError
    ///
    /// @details
    /// 비디오 디코딩과 동일한 2단계 프로세스:
    /// 1. Send packet
    /// 2. Receive frame
    private func decodeAudioPacket(packet: UnsafeMutablePointer<AVPacket>) throws -> AudioFrame? {
        guard let codecCtx = audioCodecContext else {
            throw DecoderError.notInitialized
        }

        let sendResult = avcodec_send_packet(codecCtx, packet)
        if sendResult < 0 {
            throw DecoderError.sendPacketError(sendResult)
        }

        guard let frame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var framePtr: UnsafeMutablePointer<AVFrame>? = frame
        defer { av_frame_free(&framePtr) }

        let receiveResult = avcodec_receive_frame(codecCtx, frame)
        if receiveResult == -541478725 || receiveResult == -11 || receiveResult == -35 {
            return nil
        } else if receiveResult < 0 {
            throw DecoderError.receiveFrameError(receiveResult)
        }

        return convertFrameToAudio(frame: frame)
    }

    /// @brief FFmpeg 프레임을 RGB 포맷으로 변환합니다.
    ///
    /// @param frame FFmpeg 원본 프레임
    ///
    /// @return 변환된 VideoFrame
    ///
    /// @throws DecoderError
    ///
    /// @details
    /// 변환 과정:
    /// 1. 스케일러 초기화 (처음 한 번만)
    /// 2. RGB 프레임 메모리 할당
    /// 3. 픽셀 포맷 변환 (YUV → RGB)
    /// 4. Swift Data 객체로 복사
    ///
    /// YUV란?
    /// - 비디오 압축에 최적화된 색 공간
    /// - Y: 밝기, U/V: 색상 정보
    /// - RGB보다 데이터 양이 적음
    ///
    /// BGRA vs RGB:
    /// - Metal (GPU)은 BGRA 포맷 선호
    /// - B: Blue, G: Green, R: Red, A: Alpha (투명도)
    private func convertFrameToRGB(frame: UnsafeMutablePointer<AVFrame>) throws -> VideoFrame? {
        guard let codecCtx = videoCodecContext, let videoInfo = videoInfo else {
            throw DecoderError.notInitialized
        }

        let width = Int(frame.pointee.width)
        let height = Int(frame.pointee.height)

        // 1. 스케일러 초기화 (최초 한 번만)
        if scalerContext == nil {
            // sws_getContext: 픽셀 포맷 변환기 생성
            // 원본: YUV 포맷
            // 목표: BGRA 포맷 (Metal 호환)
            // SWS_BILINEAR: 고품질 보간 알고리즘
            scalerContext = sws_getContext(
                Int32(width),                    // 원본 너비
                Int32(height),                   // 원본 높이
                codecCtx.pointee.pix_fmt,       // 원본 픽셀 포맷
                Int32(width),                    // 목표 너비
                Int32(height),                   // 목표 높이
                AV_PIX_FMT_BGRA,                // 목표 픽셀 포맷
                Int32(SWS_BILINEAR.rawValue),   // 변환 알고리즘
                nil, nil, nil
            )
        }

        guard let swsCtx = scalerContext else {
            throw DecoderError.scalerInitError
        }

        // 2. RGB 프레임 메모리 할당
        guard let rgbFrame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var rgbFramePtr: UnsafeMutablePointer<AVFrame>? = rgbFrame
        defer { av_frame_free(&rgbFramePtr) }

        rgbFrame.pointee.format = AV_PIX_FMT_BGRA.rawValue
        rgbFrame.pointee.width = Int32(width)
        rgbFrame.pointee.height = Int32(height)

        // av_frame_get_buffer: 프레임 데이터 버퍼 할당
        // 32: 메모리 정렬 (성능 최적화)
        if av_frame_get_buffer(rgbFrame, 32) < 0 {
            throw DecoderError.cannotAllocateFrame
        }

        // 3. 픽셀 포맷 변환
        // sws_scale: 실제 픽셀 데이터 변환
        // withUnsafePointer: 안전한 포인터 접근
        _ = withUnsafePointer(to: &frame.pointee.data) { srcDataPtr in
            withUnsafePointer(to: &frame.pointee.linesize) { srcLinesizePtr in
                withUnsafePointer(to: &rgbFrame.pointee.data) { dstDataPtr in
                    withUnsafePointer(to: &rgbFrame.pointee.linesize) { dstLinesizePtr in
                        sws_scale(
                            swsCtx,
                            UnsafeRawPointer(srcDataPtr).assumingMemoryBound(to: UnsafePointer<UInt8>?.self),
                            UnsafeRawPointer(srcLinesizePtr).assumingMemoryBound(to: Int32.self),
                            0,
                            Int32(height),
                            UnsafeMutableRawPointer(mutating: dstDataPtr).assumingMemoryBound(to: UnsafeMutablePointer<UInt8>?.self),
                            UnsafeMutableRawPointer(mutating: dstLinesizePtr).assumingMemoryBound(to: Int32.self)
                        )
                    }
                }
            }
        }

        // 4. RGB 데이터를 Swift Data로 복사
        // linesize: 한 줄의 바이트 수 (폭 × 픽셀당 바이트)
        let lineSize = Int(rgbFrame.pointee.linesize.0)
        let dataSize = lineSize * height
        let data = Data(bytes: rgbFrame.pointee.data.0!, count: dataSize)

        // 5. 타임스탬프 계산
        // PTS (Presentation Time Stamp): 프레임을 표시할 시간
        let pts = frame.pointee.pts
        let timeBase = videoInfo.timeBase
        let timestamp = Double(pts) * Double(timeBase.num) / Double(timeBase.den)

        // currentTimestamp 업데이트 (동기화에 사용)
        self.currentTimestamp = timestamp

        // 6. 키프레임 확인
        // AV_FRAME_FLAG_KEY: 이 프레임이 키프레임인지
        let isKeyFrame = (frame.pointee.flags & Int32(AV_FRAME_FLAG_KEY)) != 0

        return VideoFrame(
            timestamp: timestamp,
            width: width,
            height: height,
            pixelFormat: .rgba,
            data: data,
            lineSize: lineSize,
            frameNumber: frameNumber,
            isKeyFrame: isKeyFrame
        )
    }

    /// @brief FFmpeg 오디오 프레임을 AudioFrame으로 변환합니다.
    ///
    /// @param frame FFmpeg 오디오 프레임
    ///
    /// @return 변환된 AudioFrame
    ///
    /// @details
    /// 오디오 포맷 종류:
    /// - Planar: 각 채널의 샘플이 분리됨 (L L L... R R R...)
    /// - Interleaved: 채널이 섞여 있음 (L R L R L R...)
    private func convertFrameToAudio(frame: UnsafeMutablePointer<AVFrame>) -> AudioFrame? {
        guard let audioInfo = audioInfo else {
            return nil
        }

        let sampleCount = Int(frame.pointee.nb_samples)  // 샘플 개수
        let channels = Int(frame.pointee.ch_layout.nb_channels)  // 채널 수

        // 1. 오디오 포맷 결정
        let format: AudioFormat
        switch frame.pointee.format {
        case AV_SAMPLE_FMT_FLTP.rawValue:
            format = .floatPlanar  // 32비트 float, planar
        case AV_SAMPLE_FMT_FLT.rawValue:
            format = .floatInterleaved  // 32비트 float, interleaved
        case AV_SAMPLE_FMT_S16P.rawValue:
            format = .s16Planar  // 16비트 정수, planar
        case AV_SAMPLE_FMT_S16.rawValue:
            format = .s16Interleaved  // 16비트 정수, interleaved
        default:
            return nil  // 지원하지 않는 포맷
        }

        // 2. 데이터 크기 계산
        let bytesPerSample = format.bytesPerSample
        let dataSize = sampleCount * channels * bytesPerSample
        var data = Data(count: dataSize)

        // 3. 포맷에 따라 데이터 복사
        if format.isInterleaved {
            // Interleaved: 한 번에 복사
            data.withUnsafeMutableBytes { (destBytes: UnsafeMutableRawBufferPointer) in
                if let destPtr = destBytes.baseAddress {
                    memcpy(destPtr, frame.pointee.data.0, dataSize)
                }
            }
        } else {
            // Planar: 각 채널을 따로 복사
            let bytesPerChannel = sampleCount * bytesPerSample
            let dataPointers = [frame.pointee.data.0, frame.pointee.data.1, frame.pointee.data.2, frame.pointee.data.3,
                                frame.pointee.data.4, frame.pointee.data.5, frame.pointee.data.6, frame.pointee.data.7]
            data.withUnsafeMutableBytes { (destBytes: UnsafeMutableRawBufferPointer) in
                if let destPtr = destBytes.baseAddress {
                    for ch in 0..<channels {
                        if let srcPtr = dataPointers[ch] {
                            let offset = ch * bytesPerChannel
                            memcpy(destPtr + offset, srcPtr, bytesPerChannel)
                        }
                    }
                }
            }
        }

        // 4. 타임스탬프 계산
        let pts = frame.pointee.pts
        let timeBase = audioInfo.timeBase
        let timestamp = Double(pts) * Double(timeBase.num) / Double(timeBase.den)

        return AudioFrame(
            timestamp: timestamp,
            sampleRate: audioInfo.sampleRate,
            channels: channels,
            format: format,
            data: data,
            sampleCount: sampleCount
        )
    }

    /// @brief 모든 FFmpeg 리소스를 정리합니다.
    ///
    /// @details
    /// 메모리 누수 방지:
    /// - C 라이브러리는 자동 메모리 관리 없음
    /// - 사용한 모든 리소스를 수동으로 해제해야 함
    /// - 해제 순서: 스케일러 → 코덱 컨텍스트 → 포맷 컨텍스트
    ///
    /// 주의:
    /// - 포인터를 nil로 설정하여 중복 해제 방지
    /// - deinit에서 자동 호출됨
    private func cleanup() {
        // 1. 스케일러 정리
        if let swsCtx = scalerContext {
            sws_freeContext(swsCtx)
            scalerContext = nil
        }

        // 2. 비디오 코덱 컨텍스트 정리
        if videoCodecContext != nil {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = videoCodecContext
            avcodec_free_context(&ctx)
            videoCodecContext = nil
        }

        // 3. 오디오 코덱 컨텍스트 정리
        if audioCodecContext != nil {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = audioCodecContext
            avcodec_free_context(&ctx)
            audioCodecContext = nil
        }

        // 4. 포맷 컨텍스트 정리
        if formatContext != nil {
            var ctx: UnsafeMutablePointer<AVFormatContext>? = formatContext
            avformat_close_input(&ctx)
            formatContext = nil
        }

        // 5. 상태 초기화
        isInitialized = false
    }
}

// MARK: - Supporting Types (보조 타입)

/// @struct VideoStreamInfo
/// @brief 비디오 스트림의 상세 정보를 담는 구조체
///
/// @details
/// 프로퍼티 설명:
/// - width/height: 영상의 가로/세로 픽셀 수 (예: 1920×1080)
/// - frameRate: 초당 프레임 수 (예: 30fps, 60fps)
/// - codecName: 코덱 이름 (예: "h264", "hevc")
/// - bitrate: 초당 비트 수, 화질 지표 (높을수록 고화질)
/// - timeBase: 시간 단위 (분수 형태: 1/30000)
struct VideoStreamInfo {
    /// @var width
    /// @brief 영상 가로 픽셀 수
    let width: Int

    /// @var height
    /// @brief 영상 세로 픽셀 수
    let height: Int

    /// @var frameRate
    /// @brief 초당 프레임 수
    let frameRate: Double

    /// @var codecName
    /// @brief 코덱 이름
    let codecName: String

    /// @var bitrate
    /// @brief 초당 비트 수
    let bitrate: Int

    /// @var timeBase
    /// @brief 시간 단위
    let timeBase: AVRational
}

/// @struct AudioStreamInfo
/// @brief 오디오 스트림의 상세 정보를 담는 구조체
///
/// @details
/// 프로퍼티 설명:
/// - sampleRate: 샘플레이트, 음질 지표 (44100Hz = CD 품질)
/// - channels: 채널 수 (1=모노, 2=스테레오, 6=5.1 서라운드)
/// - codecName: 코덱 이름 (예: "mp3", "aac")
/// - bitrate: 초당 비트 수
/// - timeBase: 시간 단위
struct AudioStreamInfo {
    /// @var sampleRate
    /// @brief 샘플레이트 (초당 샘플 수)
    let sampleRate: Int

    /// @var channels
    /// @brief 채널 수
    let channels: Int

    /// @var codecName
    /// @brief 코덱 이름
    let codecName: String

    /// @var bitrate
    /// @brief 초당 비트 수
    let bitrate: Int

    /// @var timeBase
    /// @brief 시간 단위
    let timeBase: AVRational
}
