/// @file DecoderError.swift
/// @brief Error types for video/audio decoder
/// @author BlackboxPlayer Development Team
/// @details
/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                    DecoderError - 비디오/오디오 디코더 에러 타입                ║
 ║                                                                              ║
 ║  목적:                                                                        ║
 ║    FFmpeg 기반 비디오/오디오 디코더에서 발생할 수 있는 모든 에러를 정의합니다.     ║
 ║    명확한 에러 타입으로 문제 진단과 해결을 용이하게 합니다.                       ║
 ║                                                                              ║
 ║  핵심 기능:                                                                   ║
 ║    • 18개의 구체적인 에러 케이스 정의                                           ║
 ║    • Associated Values로 추가 정보 전달                                        ║
 ║    • LocalizedError로 사용자 친화적 메시지 제공                                 ║
 ║    • FFmpeg 에러 코드를 Swift Error로 변환                                     ║
 ║                                                                              ║
 ║  에러 분류:                                                                   ║
 ║    1. 파일 관련 (cannotOpenFile, cannotFindStreamInfo)                        ║
 ║    2. 스트림 관련 (noVideoStream, noAudioStream)                              ║
 ║    3. 코덱 관련 (codecNotFound, cannotOpenCodec)                              ║
 ║    4. 메모리 할당 (cannotAllocateFrame, cannotAllocatePacket)                 ║
 ║    5. 디코딩 프로세스 (readFrameError, sendPacketError, receiveFrameError)   ║
 ║    6. 스케일링 (scalerInitError, scaleFrameError)                             ║
 ║    7. 상태 관련 (alreadyInitialized, notInitialized, endOfFile)               ║
 ║                                                                              ║
 ║  사용 예:                                                                     ║
 ║    ```swift                                                                  ║
 ║    // 에러 던지기                                                             ║
 ║    throw DecoderError.cannotOpenFile(filePath)                               ║
 ║                                                                              ║
 ║    // 에러 처리                                                               ║
 ║    do {                                                                      ║
 ║        try decoder.initialize()                                              ║
 ║    } catch DecoderError.codecNotFound(let name) {                            ║
 ║        print("Missing codec: \(name)")                                       ║
 ║    } catch DecoderError.cannotOpenFile(let path) {                           ║
 ║        print("File error: \(path)")                                          ║
 ║    } catch {                                                                 ║
 ║        print("Other error: \(error.localizedDescription)")                   ║
 ║    }                                                                         ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ Swift Error 프로토콜이란?                                                       │
 └──────────────────────────────────────────────────────────────────────────────┘

 Error는 Swift의 에러 처리 시스템의 핵심 프로토콜입니다.

 ┌───────────────────────────────────────────────────────────────────────────┐
 │ Error 프로토콜의 특징                                                       │
 ├───────────────────────────────────────────────────────────────────────────┤
 │                                                                           │
 │ 1. 프로토콜 요구사항 없음                                                   │
 │    - protocol Error {} (비어있음)                                          │
 │    - 타입 마커 역할만 수행                                                  │
 │                                                                           │
 │ 2. throw/catch 시스템과 통합                                               │
 │    - throw로 에러 던지기                                                   │
 │    - do-catch로 에러 잡기                                                  │
 │    - try로 에러 전파                                                       │
 │                                                                           │
 │ 3. 타입 안전성                                                             │
 │    - 컴파일 타임에 에러 타입 검사                                            │
 │    - 누락된 에러 처리 경고                                                  │
 │                                                                           │
 │ 4. Associated Values 지원                                                 │
 │    - enum case에 데이터 첨부 가능                                           │
 │    - 에러 발생 시 컨텍스트 정보 전달                                         │
 │                                                                           │
 └───────────────────────────────────────────────────────────────────────────┘


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ Associated Values란?                                                         │
 └──────────────────────────────────────────────────────────────────────────────┘

 enum의 각 case에 추가 데이터를 첨부할 수 있는 기능입니다.

 기본 enum (Associated Values 없음):
 ```swift
 enum TrafficLight {
 case red
 case yellow
 case green
 }
 let light = TrafficLight.red  // 추가 정보 없음
 ```

 Associated Values 있는 enum:
 ```swift
 enum DecoderError: Error {
 case cannotOpenFile(String)  // 파일 경로 저장
 case readFrameError(Int32)   // 에러 코드 저장
 }

 // 사용
 let error1 = DecoderError.cannotOpenFile("/path/to/video.mp4")
 let error2 = DecoderError.readFrameError(-11)  // AVERROR(EAGAIN)

 // 값 추출
 switch error1 {
 case .cannotOpenFile(let path):
 print("Failed to open: \(path)")  // "Failed to open: /path/to/video.mp4"
 case .readFrameError(let code):
 print("Error code: \(code)")
 default:
 break
 }
 ```

 장점:
 1. 에러 발생 시 컨텍스트 정보 전달
 2. 디버깅 용이
 3. 사용자에게 구체적인 에러 메시지 제공
 4. 타입 안전성 유지


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ FFmpeg 디코딩 프로세스 개요                                                     │
 └──────────────────────────────────────────────────────────────────────────────┘

 FFmpeg는 비디오/오디오를 디코딩하기 위해 다음 단계를 거칩니다:

 ┌────────────────────────────────────────────────────────────────────────┐
 │                         FFmpeg Decoding Pipeline                       │
 ├────────────────────────────────────────────────────────────────────────┤
 │                                                                        │
 │  1. 파일 열기 (Open File)                                               │
 │     └─ avformat_open_input()                                           │
 │     └─ 에러: cannotOpenFile                                             │
 │                                                                        │
 │  2. 스트림 정보 찾기 (Find Stream Info)                                  │
 │     └─ avformat_find_stream_info()                                     │
 │     └─ 에러: cannotFindStreamInfo                                       │
 │                                                                        │
 │  3. 비디오/오디오 스트림 선택                                             │
 │     └─ av_find_best_stream()                                           │
 │     └─ 에러: noVideoStream, noAudioStream                               │
 │                                                                        │
 │  4. 코덱 찾기 (Find Codec)                                              │
 │     └─ avcodec_find_decoder()                                          │
 │     └─ 에러: codecNotFound                                              │
 │                                                                        │
 │  5. 코덱 컨텍스트 할당                                                   │
 │     └─ avcodec_alloc_context3()                                        │
 │     └─ 에러: cannotAllocateCodecContext                                 │
 │                                                                        │
 │  6. 코덱 파라미터 복사                                                   │
 │     └─ avcodec_parameters_to_context()                                 │
 │     └─ 에러: cannotCopyCodecParameters                                  │
 │                                                                        │
 │  7. 코덱 열기 (Open Codec)                                              │
 │     └─ avcodec_open2()                                                 │
 │     └─ 에러: cannotOpenCodec                                            │
 │                                                                        │
 │  8. 프레임/패킷 할당                                                     │
 │     └─ av_frame_alloc(), av_packet_alloc()                             │
 │     └─ 에러: cannotAllocateFrame, cannotAllocatePacket                  │
 │                                                                        │
 │  [디코딩 루프 시작]                                                      │
 │                                                                        │
 │  9. 패킷 읽기 (Read Packet)                                             │
 │     └─ av_read_frame()                                                 │
 │     └─ 에러: readFrameError, endOfFile                                  │
 │                                                                        │
 │  10. 디코더에 패킷 전송                                                  │
 │      └─ avcodec_send_packet()                                          │
 │      └─ 에러: sendPacketError                                           │
 │                                                                        │
 │  11. 디코더에서 프레임 수신                                              │
 │      └─ avcodec_receive_frame()                                        │
 │      └─ 에러: receiveFrameError                                         │
 │                                                                        │
 │  12. 프레임 스케일링/변환                                                │
 │      └─ sws_scale() (비디오), swr_convert() (오디오)                    │
 │      └─ 에러: scalerInitError, scaleFrameError                          │
 │                                                                        │
 │  [9-12 반복]                                                            │
 │                                                                        │
 └────────────────────────────────────────────────────────────────────────┘


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ AVERROR 코드 설명                                                              │
 └──────────────────────────────────────────────────────────────────────────────┘

 FFmpeg는 음수 에러 코드를 사용합니다. 주요 코드:

 • AVERROR_EOF = -541478725 (파일 끝)
 • AVERROR(EAGAIN) = -11 (다시 시도 필요)
 • AVERROR(EINVAL) = -22 (잘못된 인자)
 • AVERROR(ENOMEM) = -12 (메모리 부족)
 • AVERROR_DECODER_NOT_FOUND = -1094995529 (디코더 없음)

 사용 예:
 ```swift
 let ret = av_read_frame(formatContext, packet)
 if ret < 0 {
 if ret == AVERROR_EOF {
 throw DecoderError.endOfFile
 } else {
 throw DecoderError.readFrameError(ret)
 }
 }
 ```
 */

import Foundation

// MARK: - DecoderError 열거형

/// @enum DecoderError
/// @brief 비디오/오디오 디코딩 중 발생할 수 있는 에러
///
/// FFmpeg 기반 디코더의 모든 에러 상황을 타입 안전하게 표현합니다.
///
/// - Note: Error 프로토콜
///   Error 프로토콜을 채택하여 Swift의 에러 처리 시스템과 통합됩니다.
///   throw, do-catch, try 키워드와 함께 사용할 수 있습니다.
///
/// - Important: Associated Values
///   각 case는 추가 정보를 담을 수 있습니다:
///   - String: 파일 경로, 코덱 이름, 일반 메시지
///   - Int32: FFmpeg 에러 코드
///   - Int: 스트림 인덱스
///
/// - SeeAlso: `VideoDecoder`, `AudioPlayer`
enum DecoderError: Error {

    // MARK: 파일 관련 에러

    /// @brief 입력 파일을 열 수 없음
    ///
    /// FFmpeg 함수: avformat_open_input()
    ///
    /// 발생 시점:
    /// - 파일이 존재하지 않음
    /// - 파일 권한 없음
    /// - 파일이 다른 프로세스에 의해 잠김
    /// - 지원하지 않는 파일 형식
    ///
    /// Associated Value:
    /// - String: 실패한 파일 경로
    ///
    /// 해결 방법:
    /// 1. 파일 존재 여부 확인: FileManager.default.fileExists(atPath:)
    /// 2. 읽기 권한 확인: FileManager.default.isReadableFile(atPath:)
    /// 3. 파일 확장자 확인: .mp4, .avi, .mov 등
    /// 4. 파일 손상 여부 확인: 다른 플레이어로 재생 테스트
    ///
    /// 사용 예:
    /// ```swift
    /// guard FileManager.default.fileExists(atPath: filePath) else {
    ///     throw DecoderError.cannotOpenFile(filePath)
    /// }
    /// ```
    case cannotOpenFile(String)

    /// @brief 스트림 정보를 찾을 수 없음
    ///
    /// FFmpeg 함수: avformat_find_stream_info()
    ///
    /// 발생 시점:
    /// - 파일 헤더 손상
    /// - 파일 형식 오류
    /// - 파일이 완전히 다운로드되지 않음
    /// - 암호화된 파일
    ///
    /// Associated Value:
    /// - String: 실패한 파일 경로
    ///
    /// 해결 방법:
    /// 1. 파일 무결성 확인
    /// 2. 파일 크기 확인 (0바이트 아닌지)
    /// 3. 파일 다시 다운로드
    /// 4. 다른 플레이어로 재생 가능한지 확인
    ///
    /// 기술적 설명:
    /// - avformat_find_stream_info는 파일을 약간 읽어서 코덱 정보 수집
    /// - 보통 파일의 처음 몇 프레임 분석
    /// - 손상된 헤더는 이 단계에서 감지됨
    case cannotFindStreamInfo(String)

    // MARK: 스트림 관련 에러

    /// @brief 비디오 스트림이 파일에 없음
    ///
    /// FFmpeg 함수: av_find_best_stream(AVMEDIA_TYPE_VIDEO)
    ///
    /// 발생 시점:
    /// - 오디오만 있는 파일 (음악 파일 등)
    /// - 비디오 스트림이 손상됨
    /// - 지원하지 않는 비디오 포맷
    ///
    /// 해결 방법:
    /// 1. 파일에 비디오가 실제로 있는지 확인
    /// 2. ffprobe로 스트림 정보 확인:
    ///    `ffprobe -show_streams video.mp4`
    /// 3. 오디오 전용 파일인 경우 AudioPlayer 사용
    ///
    /// 참고:
    /// - 블랙박스 파일은 항상 비디오 스트림이 있어야 함
    /// - 이 에러는 파일 손상 가능성 높음
    case noVideoStream

    /// @brief 오디오 스트림이 파일에 없음
    ///
    /// FFmpeg 함수: av_find_best_stream(AVMEDIA_TYPE_AUDIO)
    ///
    /// 발생 시점:
    /// - 비디오만 있는 파일 (무음 비디오)
    /// - 오디오 스트림이 손상됨
    /// - 오디오 없이 인코딩된 파일
    ///
    /// 해결 방법:
    /// 1. 이 에러는 일부 블랙박스에서 정상일 수 있음
    /// 2. 오디오 없이 비디오만 재생
    /// 3. 사용자에게 "오디오 없음" 알림
    ///
    /// 참고:
    /// - 일부 블랙박스는 오디오 녹음 off 기능 제공
    /// - 이 경우 이 에러는 정상 상황
    case noAudioStream

    // MARK: 코덱 관련 에러

    /// @brief 스트림의 코덱을 찾을 수 없음
    ///
    /// FFmpeg 함수: avcodec_find_decoder()
    ///
    /// 발생 시점:
    /// - 지원하지 않는 코덱 (예: HEVC in old FFmpeg)
    /// - FFmpeg 빌드 시 해당 코덱 제외됨
    /// - 코덱 ID 손상
    ///
    /// Associated Value:
    /// - String: 코덱 이름 또는 ID
    ///
    /// 해결 방법:
    /// 1. FFmpeg 빌드 확인: 필요한 코덱 포함 여부
    /// 2. 블랙박스에서 지원하는 코덱 확인:
    ///    - 일반적: H.264 (AVC), H.265 (HEVC)
    ///    - 오디오: AAC, MP3, PCM
    /// 3. 다른 코덱으로 재인코딩
    ///
    /// 기술적 설명:
    /// ```
    /// 코덱 ID → avcodec_find_decoder() → Decoder 구조체
    ///           ↓ 실패
    ///           codecNotFound 에러
    /// ```
    case codecNotFound(String)

    /// @brief 코덱 컨텍스트 할당 실패
    ///
    /// FFmpeg 함수: avcodec_alloc_context3()
    ///
    /// 발생 시점:
    /// - 메모리 부족
    /// - 시스템 리소스 고갈
    ///
    /// 해결 방법:
    /// 1. 사용 가능한 메모리 확인
    /// 2. 다른 앱 종료
    /// 3. 시스템 재시작
    ///
    /// 메모리 계산:
    /// - 1920x1080 프레임: ~8MB
    /// - 디코더 컨텍스트: ~1MB
    /// - 멀티채널(5개): ~45MB
    case cannotAllocateCodecContext

    /// @brief 코덱 파라미터 복사 실패
    ///
    /// FFmpeg 함수: avcodec_parameters_to_context()
    ///
    /// 발생 시점:
    /// - 잘못된 파라미터
    /// - 코덱 컨텍스트가 null
    /// - 메모리 부족
    ///
    /// 해결 방법:
    /// - 일반적으로 코드 버그
    /// - 파일 손상 가능성
    /// - 다른 파일로 테스트
    case cannotCopyCodecParameters

    /// @brief 코덱을 열 수 없음
    ///
    /// FFmpeg 함수: avcodec_open2()
    ///
    /// 발생 시점:
    /// - 잘못된 코덱 옵션
    /// - 하드웨어 가속 실패
    /// - 코덱 초기화 실패
    ///
    /// Associated Value:
    /// - String: 코덱 이름
    ///
    /// 해결 방법:
    /// 1. 하드웨어 가속 끄기
    /// 2. 소프트웨어 디코더로 전환
    /// 3. 코덱 옵션 확인
    ///
    /// 예:
    /// ```swift
    /// // 하드웨어 가속 시도
    /// if avcodec_open2(context, codec, &hwOptions) < 0 {
    ///     // 실패 시 소프트웨어로 재시도
    ///     if avcodec_open2(context, codec, nil) < 0 {
    ///         throw DecoderError.cannotOpenCodec(codecName)
    ///     }
    /// }
    /// ```
    case cannotOpenCodec(String)

    // MARK: 메모리 할당 에러

    /// @brief 프레임 구조체 할당 실패
    ///
    /// FFmpeg 함수: av_frame_alloc()
    ///
    /// 발생 시점:
    /// - 메모리 부족
    /// - 시스템 리소스 고갈
    ///
    /// 해결 방법:
    /// - 메모리 확보
    /// - 다른 앱 종료
    /// - 버퍼 크기 줄이기
    ///
    /// 메모리 요구사항:
    /// - AVFrame 구조체: 약 256 bytes
    /// - 실제 프레임 데이터는 별도 할당
    case cannotAllocateFrame

    /// @brief 패킷 구조체 할당 실패
    ///
    /// FFmpeg 함수: av_packet_alloc()
    ///
    /// 발생 시점:
    /// - 메모리 부족
    ///
    /// 해결 방법:
    /// - 메모리 확보
    ///
    /// 메모리 요구사항:
    /// - AVPacket 구조체: 약 88 bytes
    /// - 압축된 데이터는 별도
    case cannotAllocatePacket

    // MARK: 디코딩 프로세스 에러

    /// @brief 파일에서 프레임 읽기 실패
    ///
    /// FFmpeg 함수: av_read_frame()
    ///
    /// 발생 시점:
    /// - 파일 손상
    /// - 파일 끝에 도달 (AVERROR_EOF)
    /// - I/O 에러
    /// - 디스크 읽기 실패
    ///
    /// Associated Value:
    /// - Int32: FFmpeg 에러 코드
    ///   - AVERROR_EOF (-541478725): 파일 끝
    ///   - AVERROR(EIO) (-5): I/O 에러
    ///
    /// 해결 방법:
    /// ```swift
    /// let ret = av_read_frame(formatContext, packet)
    /// if ret < 0 {
    ///     if ret == AVERROR_EOF {
    ///         throw DecoderError.endOfFile
    ///     } else {
    ///         throw DecoderError.readFrameError(ret)
    ///     }
    /// }
    /// ```
    case readFrameError(Int32)

    /// @brief 디코더에 패킷 전송 실패
    ///
    /// FFmpeg 함수: avcodec_send_packet()
    ///
    /// 발생 시점:
    /// - 디코더가 가득 참 (AVERROR(EAGAIN))
    /// - 잘못된 패킷 데이터
    /// - 디코더 내부 에러
    ///
    /// Associated Value:
    /// - Int32: FFmpeg 에러 코드
    ///   - AVERROR(EAGAIN) (-11): 버퍼 가득 참, 먼저 프레임 수신 필요
    ///
    /// 해결 방법:
    /// ```swift
    /// let ret = avcodec_send_packet(context, packet)
    /// if ret == AVERROR(EAGAIN) {
    ///     // 먼저 avcodec_receive_frame() 호출
    ///     // 그 다음 다시 send_packet 시도
    /// } else if ret < 0 {
    ///     throw DecoderError.sendPacketError(ret)
    /// }
    /// ```
    case sendPacketError(Int32)

    /// @brief 디코더에서 프레임 수신 실패
    ///
    /// FFmpeg 함수: avcodec_receive_frame()
    ///
    /// 발생 시점:
    /// - 프레임이 아직 준비 안 됨 (AVERROR(EAGAIN))
    /// - 디코딩 에러
    /// - 메모리 부족
    ///
    /// Associated Value:
    /// - Int32: FFmpeg 에러 코드
    ///   - AVERROR(EAGAIN) (-11): 더 많은 패킷 필요
    ///   - AVERROR_EOF: 디코더 플러시 완료
    ///
    /// 해결 방법:
    /// ```swift
    /// let ret = avcodec_receive_frame(context, frame)
    /// if ret == AVERROR(EAGAIN) {
    ///     // avcodec_send_packet()로 더 많은 데이터 공급
    ///     continue
    /// } else if ret == AVERROR_EOF {
    ///     // 디코딩 완료
    ///     break
    /// } else if ret < 0 {
    ///     throw DecoderError.receiveFrameError(ret)
    /// }
    /// ```
    ///
    /// 디코딩 루프 패턴:
    /// ```
    /// while hasMorePackets {
    ///     send_packet(packet)  ← 압축 데이터 입력
    ///     while true {
    ///         receive_frame(frame)  ← 압축 해제된 프레임 출력
    ///         if EAGAIN { break }  ← 더 많은 패킷 필요
    ///         // 프레임 처리
    ///     }
    /// }
    /// ```
    case receiveFrameError(Int32)

    // MARK: 스케일링/변환 에러

    /// @brief 스케일러/리샘플러 초기화 실패
    ///
    /// FFmpeg 함수:
    /// - sws_getContext() (비디오 스케일러)
    /// - swr_alloc_set_opts() (오디오 리샘플러)
    ///
    /// 발생 시점:
    /// - 지원하지 않는 픽셀 포맷 변환
    /// - 잘못된 해상도 (0 또는 음수)
    /// - 메모리 부족
    ///
    /// 해결 방법:
    /// 1. 소스/대상 포맷 확인
    /// 2. 해상도 검증
    /// 3. 메모리 확보
    ///
    /// 비디오 스케일러 예:
    /// ```swift
    /// // YUV420p → RGB 변환
    /// let swsContext = sws_getContext(
    ///     width, height, AV_PIX_FMT_YUV420P,  // 소스
    ///     width, height, AV_PIX_FMT_RGB24,    // 대상
    ///     SWS_BILINEAR, nil, nil, nil
    /// )
    /// guard swsContext != nil else {
    ///     throw DecoderError.scalerInitError
    /// }
    /// ```
    case scalerInitError

    /// @brief 프레임 스케일링/변환 실패
    ///
    /// FFmpeg 함수:
    /// - sws_scale() (비디오)
    /// - swr_convert() (오디오)
    ///
    /// 발생 시점:
    /// - 버퍼 크기 부족
    /// - 스케일러 미초기화
    /// - 메모리 오류
    ///
    /// 해결 방법:
    /// 1. 출력 버퍼 크기 확인
    /// 2. 스케일러 초기화 확인
    /// 3. 입력 프레임 유효성 검증
    ///
    /// 사용 예:
    /// ```swift
    /// let height = sws_scale(
    ///     swsContext,
    ///     frame.data, frame.linesize, 0, frame.height,
    ///     rgbFrame.data, rgbFrame.linesize
    /// )
    /// guard height == frame.height else {
    ///     throw DecoderError.scaleFrameError
    /// }
    /// ```
    case scaleFrameError

    // MARK: 상태 관련 에러

    /// @brief 잘못된 스트림 인덱스
    ///
    /// 발생 시점:
    /// - 음수 인덱스
    /// - 파일의 스트림 개수를 초과하는 인덱스
    /// - 스트림 타입 불일치 (비디오 인덱스로 오디오 접근 등)
    ///
    /// Associated Value:
    /// - Int: 잘못된 인덱스 값
    ///
    /// 해결 방법:
    /// ```swift
    /// guard streamIndex >= 0 && streamIndex < formatContext.nb_streams else {
    ///     throw DecoderError.invalidStreamIndex(streamIndex)
    /// }
    /// ```
    case invalidStreamIndex(Int)

    /// @brief 디코더가 이미 초기화됨
    ///
    /// 발생 시점:
    /// - initialize() 를 두 번 호출
    /// - 이미 열린 디코더를 다시 열려고 시도
    ///
    /// 해결 방법:
    /// ```swift
    /// guard !isInitialized else {
    ///     throw DecoderError.alreadyInitialized
    /// }
    /// isInitialized = true
    /// // 초기화 로직...
    /// ```
    case alreadyInitialized

    /// @brief 디코더가 초기화되지 않음
    ///
    /// 발생 시점:
    /// - initialize() 호출 전에 다른 메서드 호출
    /// - 초기화 실패 후 계속 사용 시도
    ///
    /// 해결 방법:
    /// ```swift
    /// func decodeNextFrame() throws -> Frame? {
    ///     guard isInitialized else {
    ///         throw DecoderError.notInitialized
    ///     }
    ///     // 디코딩 로직...
    /// }
    /// ```
    case notInitialized

    /// @brief 파일 끝에 도달
    ///
    /// FFmpeg 에러: AVERROR_EOF
    ///
    /// 발생 시점:
    /// - av_read_frame()이 더 이상 읽을 데이터 없음
    /// - 정상적인 파일 끝
    ///
    /// 해결 방법:
    /// - 에러가 아니라 정상 종료 신호
    /// - 디코더 플러시 필요 (남은 프레임 출력)
    ///
    /// 디코더 플러시:
    /// ```swift
    /// // EOF 도달 시
    /// avcodec_send_packet(context, nil)  // nil = flush signal
    /// while true {
    ///     let ret = avcodec_receive_frame(context, frame)
    ///     if ret == AVERROR_EOF { break }  // 모든 프레임 출력됨
    ///     // 프레임 처리
    /// }
    /// ```
    case endOfFile

    /// @brief 알 수 없는 에러
    ///
    /// 발생 시점:
    /// - 위의 분류에 속하지 않는 에러
    /// - FFmpeg 내부 에러
    /// - 예상치 못한 상황
    ///
    /// Associated Value:
    /// - String: 에러 설명 메시지
    ///
    /// 해결 방법:
    /// - 로그 확인
    /// - FFmpeg 버전 확인
    /// - 버그 리포트
    case unknown(String)
}

// MARK: - LocalizedError Extension

/*
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ LocalizedError 프로토콜                                                        │
 └──────────────────────────────────────────────────────────────────────────────┘

 LocalizedError는 사용자에게 보여줄 에러 메시지를 제공하는 프로토콜입니다.

 프로토콜 정의:
 ```swift
 protocol LocalizedError : Error {
 var errorDescription: String? { get }
 var failureReason: String? { get }
 var recoverySuggestion: String? { get }
 var helpAnchor: String? { get }
 }
 ```

 우리는 errorDescription만 구현합니다:
 - errorDescription: 사용자에게 표시할 에러 메시지

 사용 예:
 ```swift
 do {
 try decoder.initialize()
 } catch {
 // error.localizedDescription이 자동으로 errorDescription 사용
 print(error.localizedDescription)
 // 출력: "Cannot open file: /path/to/video.mp4"
 }
 ```

 장점:
 1. 일관된 에러 메시지
 2. 다국어 지원 가능 (향후)
 3. UI에서 사용하기 쉬움
 */

/// @extension DecoderError
/// @brief LocalizedError 구현
///
/// 각 DecoderError case에 대한 사용자 친화적 메시지를 제공합니다.
///
/// - Note: errorDescription
///   String? 타입을 반환하지만 항상 String을 반환합니다 (nil 없음).
///   이는 프로토콜 요구사항 때문에 Optional입니다.
///
/// - Important: 메시지 작성 가이드
///   1. 명확하고 구체적으로
///   2. 기술적 용어 최소화 (사용자 대상)
///   3. Associated Value 정보 포함
///   4. 영어로 작성 (향후 다국어화)
extension DecoderError: LocalizedError {

    /// @var errorDescription
    /// @brief 에러 설명 문자열
    ///
    /// 각 에러 케이스에 대한 사람이 읽을 수 있는 설명을 반환합니다.
    ///
    /// - Returns: 에러 설명 문자열 (항상 non-nil)
    ///
    /// 메시지 포맷:
    /// - 동작 실패: "Cannot [action]: [details]"
    /// - 리소스 없음: "No [resource] found"
    /// - 상태 오류: "[Component] [state]"
    ///
    /// 사용 예:
    /// ```swift
    /// let error = DecoderError.cannotOpenFile("/video.mp4")
    /// print(error.errorDescription ?? "Unknown error")
    /// // 출력: "Cannot open file: /video.mp4"
    /// ```
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path):
            return "Cannot open file: \(path)"

        case .cannotFindStreamInfo(let path):
            return "Cannot find stream information: \(path)"

        case .noVideoStream:
            return "No video stream found"

        case .noAudioStream:
            return "No audio stream found"

        case .codecNotFound(let name):
            return "Codec not found: \(name)"

        case .cannotAllocateCodecContext:
            return "Cannot allocate codec context"

        case .cannotCopyCodecParameters:
            return "Cannot copy codec parameters"

        case .cannotOpenCodec(let name):
            return "Cannot open codec: \(name)"

        case .cannotAllocateFrame:
            return "Cannot allocate frame"

        case .cannotAllocatePacket:
            return "Cannot allocate packet"

        case .readFrameError(let code):
            // FFmpeg 에러 코드를 포함하여 디버깅 용이
            return "Read frame error: \(code)"

        case .sendPacketError(let code):
            return "Send packet error: \(code)"

        case .receiveFrameError(let code):
            return "Receive frame error: \(code)"

        case .scalerInitError:
            return "Scaler initialization error"

        case .scaleFrameError:
            return "Frame scaling error"

        case .invalidStreamIndex(let index):
            return "Invalid stream index: \(index)"

        case .alreadyInitialized:
            return "Decoder already initialized"

        case .notInitialized:
            return "Decoder not initialized"

        case .endOfFile:
            // 이건 실제로 에러가 아니라 정상 종료
            return "End of file reached"

        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                              에러 처리 패턴                                     ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝

 1. 기본 패턴:
 ```swift
 func decodeVideo() throws {
 // 파일 열기
 guard canOpen(file) else {
 throw DecoderError.cannotOpenFile(filePath)
 }

 // 코덱 찾기
 guard let codec = findCodec() else {
 throw DecoderError.codecNotFound("H.264")
 }

 // 디코딩...
 }

 // 사용
 do {
 try decodeVideo()
 } catch DecoderError.cannotOpenFile(let path) {
 print("File error: \(path)")
 // 사용자에게 파일 선택 다시 요청
 } catch DecoderError.codecNotFound(let name) {
 print("Codec \(name) not supported")
 // 사용자에게 다른 파일 요청
 } catch {
 print("Unexpected error: \(error)")
 }
 ```

 2. Result 타입 사용:
 ```swift
 func decodeVideo() -> Result<VideoFrame, DecoderError> {
 do {
 let frame = try performDecode()
 return .success(frame)
 } catch let error as DecoderError {
 return .failure(error)
 } catch {
 return .failure(.unknown(error.localizedDescription))
 }
 }

 // 사용
 switch decodeVideo() {
 case .success(let frame):
 display(frame)
 case .failure(let error):
 handle(error)
 }
 ```

 3. Optional 변환:
 ```swift
 let frame = try? decoder.decodeNextFrame()
 if frame == nil {
 // 에러 발생 (상세 정보 없음)
 }
 ```

 4. 에러 체이닝:
 ```swift
 func loadAndDecode(_ path: String) throws -> VideoFrame {
 let data = try loadFile(path)  // FileError 발생 가능
 let frame = try decode(data)   // DecoderError 발생 가능
 return frame
 }

 // 두 에러 타입 모두 처리
 do {
 let frame = try loadAndDecode("/video.mp4")
 } catch let error as FileError {
 // 파일 에러 처리
 } catch let error as DecoderError {
 // 디코더 에러 처리
 } catch {
 // 기타 에러
 }
 ```
 */
