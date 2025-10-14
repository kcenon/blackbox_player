/// @file ChannelInfo.swift
/// @brief 블랙박스 비디오 채널/카메라 정보 모델
/// @author BlackboxPlayer Development Team
///
/// Model for video channel/camera information

import Foundation

/*
 ═══════════════════════════════════════════════════════════════════════════════
 ChannelInfo - 비디오 채널 정보
 ═══════════════════════════════════════════════════════════════════════════════

 【개요】
 ChannelInfo는 멀티 카메라 블랙박스 시스템에서 개별 채널(카메라)의 정보를 나타내는
 구조체입니다. 각 채널의 해상도, 프레임 레이트, 코덱, 파일 경로 등 비디오 스펙을
 저장하고 관리합니다.

 【비디오 채널(Video Channel)이란?】

 채널은 블랙박스의 각 카메라를 의미합니다.

 멀티 채널 블랙박스 구성 예시:
 - 1채널: 전방 카메라만 (기본)
 - 2채널: 전방 + 후방 (가장 일반적)
 - 3채널: 전방 + 후방 + 실내
 - 4채널: 전방 + 후방 + 좌측 + 우측
 - 5채널: 전방 + 후방 + 좌측 + 우측 + 실내 (고급형)

 각 채널은 독립적인 비디오 파일로 녹화됩니다:
 2025_01_10_09_00_00_F.mp4  ← 전방(Front) 채널
 2025_01_10_09_00_00_R.mp4  ← 후방(Rear) 채널
 2025_01_10_09_00_00_I.mp4  ← 실내(Interior) 채널

 【비디오 해상도(Resolution)】

 해상도는 영상의 픽셀 수를 나타냅니다.

 해상도 표기:
 너비(Width) × 높이(Height)
 예: 1920 × 1080 (Full HD)

 일반적인 해상도 등급:

 4K UHD:    3840 × 2160  (829만 픽셀) ★★★★★ 최고급
 2K QHD:    2560 × 1440  (369만 픽셀) ★★★★ 고급
 Full HD:   1920 × 1080  (207만 픽셀) ★★★ 일반
 HD:        1280 × 720   (92만 픽셀)  ★★ 보급형
 SD:         640 × 480   (31만 픽셀)  ★ 구형

 비교:
 ┌──────────────────────────────────┐
 │                                  │  4K (3840×2160)
 │                                  │
 │      ┌──────────────────┐        │
 │      │                  │        │  Full HD (1920×1080)
 │      │    ┌──────┐      │        │
 │      │    │      │      │        │  HD (1280×720)
 │      │    └──────┘      │        │
 │      └──────────────────┘        │
 └──────────────────────────────────┘

 해상도가 높을수록:
 - 더 선명한 영상
 - 더 큰 파일 크기
 - 더 많은 저장 공간 필요
 - 더 높은 처리 성능 요구

 【화면 비율(Aspect Ratio)】

 화면 비율은 가로와 세로의 비율입니다.

 일반적인 비율:
 16:9  - 와이드스크린 (일반 블랙박스, TV, 모니터)
 4:3   - 구형 비율 (오래된 블랙박스, 구형 TV)
 21:9  - 울트라 와이드 (영화관, 고급 모니터)

 비율 비교:
 16:9  ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬  (와이드)
 ▬▬▬▬▬▬▬▬▬▬▬

 4:3   ▬▬▬▬▬▬▬▬▬▬▬▬      (정사각형에 가까움)
 ▬▬▬▬▬▬▬▬▬

 계산 예시:
 1920 ÷ 1080 = 1.777... ≈ 16/9 = 1.777...
 1280 ÷ 720  = 1.777... ≈ 16/9
 1024 ÷ 768  = 1.333... ≈ 4/3 = 1.333...

 【프레임 레이트(Frame Rate)】

 프레임 레이트는 1초당 표시되는 프레임(정지 화면) 개수입니다.
 단위: fps (frames per second, 초당 프레임)

 일반적인 프레임 레이트:
 60 fps  - 매우 부드러운 영상 (고급 블랙박스, 게임, 슬로우모션)
 30 fps  - 일반 영상 (대부분의 블랙박스, 유튜브)
 24 fps  - 영화 표준
 15 fps  - 저성능 모드 (주차 모드)

 프레임 레이트와 부드러움:
 15 fps:  ●   ●   ●   ●      (뚝뚝 끊김)
 30 fps:  ●●  ●●  ●●  ●●     (자연스러움)
 60 fps:  ●●●●●●●●●●●●●●●● (매우 부드러움)

 높은 프레임 레이트의 장점:
 - 더 부드러운 영상
 - 빠른 움직임 포착 (사고 순간 포착)
 - 슬로우모션 가능

 단점:
 - 더 큰 파일 크기
 - 더 많은 처리 성능 필요

 【비트레이트(Bitrate)】

 비트레이트는 1초당 저장되는 데이터 양입니다.
 단위: bps (bits per second, 초당 비트)

 단위 변환:
 1 Kbps = 1,000 bps
 1 Mbps = 1,000,000 bps = 1,000 Kbps

 일반적인 비트레이트:

 Full HD (1920×1080):
 - 저품질:  4 Mbps
 - 일반:    8 Mbps  ← 대부분의 블랙박스
 - 고품질: 12 Mbps

 4K (3840×2160):
 - 저품질: 16 Mbps
 - 일반:   24 Mbps
 - 고품질: 40 Mbps

 비트레이트와 화질:
 낮은 비트레이트 (4 Mbps):
 - 압축 많음 → 화질 저하
 - 작은 파일 크기
 - 저장 공간 절약

 높은 비트레이트 (12 Mbps):
 - 압축 적음 → 선명한 화질
 - 큰 파일 크기
 - 더 많은 저장 공간 필요

 【비디오 코덱(Video Codec)】

 코덱(Codec)은 영상을 압축/해제하는 기술입니다.
 Codec = Coder(압축) + Decoder(해제)

 일반적인 비디오 코덱:

 H.264 (AVC):
 - 가장 널리 사용
 - 호환성 최고
 - 적당한 압축률
 - 대부분의 블랙박스 사용

 H.265 (HEVC):
 - H.264보다 2배 효율적인 압축
 - 같은 화질에 파일 크기 절반
 - 최신 블랙박스 사용
 - 일부 구형 기기에서 재생 안 될 수 있음

 압축률 비교 (같은 화질 기준):
 H.264: ████████ (8 MB)
 H.265: ████     (4 MB) ← 50% 작음

 【오디오 코덱(Audio Codec)】

 오디오 압축 기술입니다.

 AAC:
 - 고음질 압축
 - Apple 기기 최적화
 - 최신 블랙박스 사용

 MP3:
 - 범용 코덱
 - 호환성 최고
 - 구형 블랙박스 사용

 【파일 크기 계산 예시】

 Full HD, 30 fps, 8 Mbps, 1분 녹화:
 8 Mbps = 8,000,000 bits/초
 = 1,000,000 bytes/초 (8 bits = 1 byte)
 = 1 MB/초

 1분 = 60초
 파일 크기 = 1 MB/초 × 60초 = 60 MB

 1시간 녹화:
 60 MB/분 × 60분 = 3,600 MB = 3.6 GB

 32GB SD 카드 녹화 시간:
 32 GB ÷ 3.6 GB/시간 ≈ 8.9시간

 【ChannelInfo 사용 예시】

 ```swift
 // 전방 카메라 Full HD 채널
 let frontChannel = ChannelInfo(
 position: .front,
 filePath: "normal/2025_01_10_09_00_00_F.mp4",
 width: 1920,
 height: 1080,
 frameRate: 30.0,
 bitrate: 8_000_000,  // 8 Mbps
 codec: "h264",
 audioCodec: "mp3",
 fileSize: 100_000_000  // 100 MB
 )

 // 채널 정보 표시
 print("카메라 위치: \(frontChannel.position.displayName)")
 print("해상도: \(frontChannel.resolutionName) (\(frontChannel.resolutionString))")
 print("화면 비율: \(frontChannel.aspectRatioString)")
 print("프레임 레이트: \(frontChannel.frameRateString)")
 print("비트레이트: \(frontChannel.bitrateString ?? "N/A")")
 print("파일 크기: \(frontChannel.fileSizeString)")
 print("고해상도: \(frontChannel.isHighResolution ? "예" : "아니오")")
 print("오디오: \(frontChannel.hasAudio ? "있음" : "없음")")
 ```

 ═══════════════════════════════════════════════════════════════════════════════
 */

/// @struct ChannelInfo
/// @brief 비디오 채널/카메라 정보
///
/// Information about a video channel/camera in a multi-camera system
///
/// 멀티 카메라 시스템에서 개별 비디오 채널(카메라)의 정보를 나타내는 구조체입니다.
///
/// **주요 정보:**
/// - 카메라 위치 및 파일 경로
/// - 비디오 스펙 (해상도, 프레임 레이트, 비트레이트)
/// - 코덱 정보 (비디오/오디오)
/// - 파일 메타데이터 (크기, 길이)
///
/// **프로토콜:**
/// - Codable: JSON 직렬화/역직렬화
/// - Equatable: 동등성 비교
/// - Identifiable: SwiftUI List/ForEach에서 고유 식별 (id 프로퍼티)
/// - Hashable: Set/Dictionary 키로 사용 가능
///
/// **사용 예시:**
/// ```swift
/// let channel = ChannelInfo(
///     position: .front,
///     filePath: "normal/2025_01_10_09_00_00_F.mp4",
///     width: 1920,
///     height: 1080,
///     frameRate: 30.0,
///     bitrate: 8_000_000,
///     codec: "h264"
/// )
///
/// print(channel.resolutionName)  // "Full HD"
/// print(channel.aspectRatioString)  // "16:9"
/// print(channel.bitrateString ?? "N/A")  // "8.0 Mbps"
/// ```
struct ChannelInfo: Codable, Equatable, Identifiable, Hashable {
    /// @var id
    /// @brief 채널 고유 식별자 (UUID)
    ///
    /// Unique identifier for this channel
    ///
    /// 채널의 고유 식별자입니다.
    ///
    /// **UUID (Universally Unique Identifier):**
    /// - 128비트 숫자로 구성된 고유 식별자
    /// - 형식: 8-4-4-4-12 (36자, 하이픈 포함)
    /// - 예: "550e8400-e29b-41d4-a716-446655440000"
    /// - 충돌 확률: 거의 0 (10^-18 수준)
    ///
    /// **Identifiable 프로토콜:**
    /// - SwiftUI의 List, ForEach에서 각 항목을 구별하기 위해 사용
    /// - id 프로퍼티를 통해 각 ChannelInfo를 고유하게 식별
    ///
    /// **사용 예시:**
    /// ```swift
    /// // SwiftUI에서 채널 목록 표시
    /// List(channels) { channel in
    ///     // channel.id가 자동으로 고유 식별자로 사용됨
    ///     Text(channel.position.displayName)
    /// }
    /// ```
    let id: UUID

    /// @var position
    /// @brief 카메라 위치/종류
    ///
    /// Camera position/type
    ///
    /// 카메라의 위치/종류입니다.
    ///
    /// **CameraPosition enum:**
    /// - front: 전방 카메라
    /// - rear: 후방 카메라
    /// - left: 좌측 카메라
    /// - right: 우측 카메라
    /// - interior: 실내 카메라
    /// - unknown: 알 수 없음
    ///
    /// **채널 배치 예시:**
    /// ```
    ///         left
    ///          │
    ///     ┌────┼────┐
    ///     │         │
    ///   front     rear
    ///     │         │
    ///     └────┼────┘
    ///          │
    ///        right
    ///
    ///    interior (차량 내부)
    /// ```
    let position: CameraPosition

    /// @var filePath
    /// @brief 비디오 파일 경로
    ///
    /// File path to the video file for this channel
    ///
    /// 채널의 비디오 파일 경로입니다.
    ///
    /// **경로 형식:**
    /// - 상대 경로 또는 절대 경로
    /// - 일반적으로 블랙박스 SD 카드 내 경로
    ///
    /// **경로 예시:**
    /// ```
    /// "normal/2025_01_10_09_00_00_F.mp4"   (전방, 일반 녹화)
    /// "event/2025_01_10_10_30_15_R.mp4"    (후방, 이벤트)
    /// "/media/sd/normal/2025_01_10_09_00_00_F.mp4"  (절대 경로)
    /// ```
    ///
    /// **파일명 규칙:**
    /// - YYYY_MM_DD_HH_MM_SS_Position.mp4
    /// - Position: F(전방), R(후방), L(좌측), Ri(우측), I(실내)
    let filePath: String

    /// @var width
    /// @brief 비디오 가로 해상도 (픽셀)
    ///
    /// Video resolution width in pixels
    ///
    /// 비디오 해상도의 가로 픽셀 수입니다.
    ///
    /// **일반적인 가로 해상도:**
    /// - 3840: 4K UHD
    /// - 2560: 2K QHD
    /// - 1920: Full HD
    /// - 1280: HD
    /// - 640: SD
    ///
    /// **픽셀(Pixel):**
    /// - 화면을 구성하는 최소 단위 점
    /// - Picture Element의 약자
    /// - 더 많은 픽셀 = 더 선명한 영상
    let width: Int

    /// @var height
    /// @brief 비디오 세로 해상도 (픽셀)
    ///
    /// Video resolution height in pixels
    ///
    /// 비디오 해상도의 세로 픽셀 수입니다.
    ///
    /// **일반적인 세로 해상도:**
    /// - 2160: 4K UHD
    /// - 1440: 2K QHD
    /// - 1080: Full HD (1080p)
    /// - 720: HD (720p)
    /// - 480: SD (480p)
    ///
    /// **"p"의 의미:**
    /// - p = Progressive scan (순차 주사)
    /// - 1080p: 1080줄의 수평선을 순차적으로 표시
    /// - 모든 현대 블랙박스는 p 방식 사용
    let height: Int

    /// @var frameRate
    /// @brief 프레임 레이트 (fps)
    ///
    /// Frame rate in frames per second
    ///
    /// 초당 프레임 수입니다. (fps: frames per second)
    ///
    /// **프레임(Frame):**
    /// - 영상을 구성하는 개별 정지 화면
    /// - 여러 프레임을 빠르게 보여주면 동영상처럼 보임
    ///
    /// **일반적인 프레임 레이트:**
    /// - 60.0 fps: 고급 블랙박스, 매우 부드러운 영상
    /// - 30.0 fps: 일반 블랙박스 (가장 일반적)
    /// - 24.0 fps: 영화 표준
    /// - 15.0 fps: 주차 모드 (저전력)
    ///
    /// **프레임 레이트와 영상 품질:**
    /// - 높을수록 부드러운 영상
    /// - 빠른 움직임 포착에 유리 (사고 순간)
    /// - 파일 크기와 비례 (60fps는 30fps보다 2배 큼)
    ///
    /// **Double 타입인 이유:**
    /// - 일부 블랙박스는 29.97 fps 같은 소수점 프레임 레이트 사용
    /// - NTSC 표준 (미국, 한국): 29.97 fps
    /// - PAL 표준 (유럽): 25.0 fps
    let frameRate: Double

    /// @var bitrate
    /// @brief 비디오 비트레이트 (bps, 옵셔널)
    ///
    /// Video bitrate in bits per second (optional)
    ///
    /// 비디오 비트레이트입니다. (단위: bps, bits per second)
    ///
    /// **비트레이트(Bitrate):**
    /// - 1초당 저장되는 데이터 양
    /// - 높을수록 선명한 화질, 큰 파일 크기
    /// - 낮을수록 압축된 화질, 작은 파일 크기
    ///
    /// **단위 변환:**
    /// - 1,000 bps = 1 Kbps (킬로비트)
    /// - 1,000,000 bps = 1 Mbps (메가비트)
    /// - 8 bits = 1 byte
    /// - 8 Mbps = 1 MB/s (초당 1메가바이트)
    ///
    /// **일반적인 비트레이트:**
    /// - Full HD (1920×1080):
    ///   - 4,000,000 bps (4 Mbps): 저품질
    ///   - 8,000,000 bps (8 Mbps): 일반 ★
    ///   - 12,000,000 bps (12 Mbps): 고품질
    ///
    /// - 4K (3840×2160):
    ///   - 16,000,000 bps (16 Mbps): 저품질
    ///   - 24,000,000 bps (24 Mbps): 일반
    ///   - 40,000,000 bps (40 Mbps): 고품질
    ///
    /// **옵셔널인 이유:**
    /// - 일부 파일 포맷은 비트레이트 정보를 포함하지 않을 수 있음
    /// - 파싱 실패 시 nil
    let bitrate: Int?

    /// @var codec
    /// @brief 비디오 코덱 (옵셔널)
    ///
    /// Video codec (e.g., "h264", "h265")
    ///
    /// 비디오 코덱입니다.
    ///
    /// **코덱(Codec):**
    /// - Coder(압축) + Decoder(해제)의 합성어
    /// - 영상 데이터를 압축/해제하는 알고리즘
    /// - 압축 없이는 파일 크기가 너무 큼
    ///
    /// **압축 없는 Full HD 1초 크기:**
    /// - 1920 × 1080 픽셀 × 3 bytes(RGB) × 30 프레임
    /// - = 186 MB/초
    /// - 1분 = 11 GB (!!)
    ///
    /// **일반적인 비디오 코덱:**
    ///
    /// 1. h264 (AVC, MPEG-4 Part 10):
    ///    - 가장 널리 사용되는 코덱
    ///    - 호환성 최고 (거의 모든 기기 재생 가능)
    ///    - 적당한 압축률
    ///    - 대부분의 블랙박스 사용
    ///    - 예: "h264", "avc1"
    ///
    /// 2. h265 (HEVC, High Efficiency Video Coding):
    ///    - H.264보다 2배 효율적인 압축
    ///    - 같은 화질에 파일 크기 약 50% 감소
    ///    - 최신 블랙박스 사용
    ///    - 일부 구형 기기에서 재생 안 될 수 있음
    ///    - 예: "h265", "hevc", "hvc1"
    ///
    /// **압축률 비교 (같은 화질 기준):**
    /// ```
    /// 압축 없음: ████████████████ (186 MB/초)
    /// H.264:     ████ (1 MB/초, 약 1/186 압축)
    /// H.265:     ██ (0.5 MB/초, 약 1/372 압축)
    /// ```
    ///
    /// **옵셔널인 이유:**
    /// - 코덱 정보를 파싱하지 못할 수 있음
    /// - 알 수 없는 코덱 형식
    let codec: String?

    /// @var audioCodec
    /// @brief 오디오 코덱 (옵셔널)
    ///
    /// Audio codec (e.g., "mp3", "aac") (optional)
    ///
    /// 오디오 코덱입니다.
    ///
    /// **일반적인 오디오 코덱:**
    ///
    /// 1. AAC (Advanced Audio Coding):
    ///    - MP3보다 고음질/고효율
    ///    - Apple 기기 최적화
    ///    - 최신 블랙박스 사용
    ///    - 예: "aac", "mp4a"
    ///
    /// 2. MP3 (MPEG Audio Layer 3):
    ///    - 가장 범용적인 코덱
    ///    - 호환성 최고
    ///    - 구형 블랙박스 사용
    ///    - 예: "mp3", "mp3a"
    ///
    /// **오디오가 없는 경우:**
    /// - 일부 블랙박스는 오디오 녹음 안 함
    /// - 오디오 비활성화 설정
    /// - audioCodec = nil
    ///
    /// **옵셔널인 이유:**
    /// - 오디오가 없는 비디오 파일
    /// - 코덱 정보 파싱 실패
    let audioCodec: String?

    /// @var isEnabled
    /// @brief 채널 활성화 여부
    ///
    /// Channel is enabled/active
    ///
    /// 채널이 활성화되어 있는지 여부입니다.
    ///
    /// **활성화/비활성화:**
    /// - true: 채널이 활성화됨 (재생, 표시)
    /// - false: 채널이 비활성화됨 (숨김, 재생 안 함)
    ///
    /// **사용 시나리오:**
    /// - 사용자가 특정 채널 숨기기 (예: 실내 카메라 프라이버시)
    /// - 파일 손상으로 재생 불가
    /// - 선택적 채널 표시 (전방만 표시 등)
    ///
    /// **UI 표시:**
    /// ```swift
    /// if channel.isEnabled {
    ///     // 채널 재생
    ///     playerView.isHidden = false
    /// } else {
    ///     // 채널 숨김
    ///     playerView.isHidden = true
    ///     showDisabledMessage()
    /// }
    /// ```
    let isEnabled: Bool

    /// @var fileSize
    /// @brief 파일 크기 (bytes)
    ///
    /// File size in bytes
    ///
    /// 파일 크기입니다. (단위: bytes)
    ///
    /// **UInt64 타입:**
    /// - Unsigned Integer 64-bit (부호 없는 64비트 정수)
    /// - 범위: 0 ~ 18,446,744,073,709,551,615 (약 18 엑사바이트)
    /// - 파일 크기는 음수가 될 수 없으므로 Unsigned 사용
    /// - 대용량 파일도 처리 가능 (64비트면 충분)
    ///
    /// **단위 변환:**
    /// - 1 KB = 1,024 bytes
    /// - 1 MB = 1,024 KB = 1,048,576 bytes
    /// - 1 GB = 1,024 MB = 1,073,741,824 bytes
    ///
    /// **파일 크기 예시:**
    /// - Full HD, 30 fps, 8 Mbps, 1분:
    ///   - 8 Mbps = 1 MB/초
    ///   - 60초 × 1 MB = 60 MB
    ///   - = 62,914,560 bytes (약 63 MB)
    ///
    /// - Full HD, 30 fps, 8 Mbps, 1시간:
    ///   - 60 MB/분 × 60분 = 3,600 MB
    ///   - = 3,774,873,600 bytes (약 3.6 GB)
    let fileSize: UInt64

    /// @var duration
    /// @brief 비디오 길이 (초)
    ///
    /// Duration of video in seconds
    ///
    /// 비디오 길이입니다. (단위: 초)
    ///
    /// **TimeInterval 타입:**
    /// - Double의 typealias
    /// - 시간 간격을 나타내는 표준 타입
    /// - 소수점 이하도 표현 가능 (예: 123.456초)
    ///
    /// **일반적인 블랙박스 녹화 길이:**
    /// - 1분 파일: 60.0초
    /// - 3분 파일: 180.0초
    /// - 5분 파일: 300.0초 (가장 일반적)
    /// - 10분 파일: 600.0초
    ///
    /// **분할 녹화 이유:**
    /// - 파일 손상 시 피해 최소화
    /// - SD 카드 호환성 (FAT32는 4GB 제한)
    /// - 파일 관리 용이
    ///
    /// **시간 변환:**
    /// ```swift
    /// let seconds = 3665.5  // 1시간 1분 5.5초
    /// let hours = Int(seconds / 3600)  // 1
    /// let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)  // 1
    /// let secs = seconds.truncatingRemainder(dividingBy: 60)  // 5.5
    /// ```
    let duration: TimeInterval

    /// @var timeOffset
    /// @brief 채널 시간 오프셋 (초)
    ///
    /// Time offset for this channel in seconds
    ///
    /// 채널 간 시간 차이를 보정하기 위한 오프셋입니다.
    ///
    /// **시간 오프셋(Time Offset)이란?**
    /// - 카메라 간 하드웨어 딜레이 보정
    /// - 각 채널이 정확히 같은 시간에 녹화를 시작하지 않을 수 있음
    /// - 예: 전방 카메라가 후방 카메라보다 0.05초 빠르게 시작
    ///
    /// **사용 예시:**
    /// ```swift
    /// let frontChannel = ChannelInfo(
    ///     position: .front,
    ///     ...,
    ///     timeOffset: 0.0  // 기준 채널
    /// )
    ///
    /// let rearChannel = ChannelInfo(
    ///     position: .rear,
    ///     ...,
    ///     timeOffset: 0.05  // 0.05초 늦게 시작
    /// )
    ///
    /// // 동기화 시:
    /// // 전방 5.00초 프레임 == 후방 5.05초 프레임
    /// ```
    ///
    /// **값의 의미:**
    /// - 0.0: 기준 시간 (보통 전방 카메라)
    /// - 양수: 이 채널이 늦게 시작 (시간 추가)
    /// - 음수: 이 채널이 빠르게 시작 (시간 감소)
    let timeOffset: TimeInterval

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        position: CameraPosition,
        filePath: String,
        width: Int,
        height: Int,
        frameRate: Double,
        bitrate: Int? = nil,
        codec: String? = nil,
        audioCodec: String? = nil,
        isEnabled: Bool = true,
        fileSize: UInt64 = 0,
        duration: TimeInterval = 0,
        timeOffset: TimeInterval = 0.0
    ) {
        self.id = id
        self.position = position
        self.filePath = filePath
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.codec = codec
        self.audioCodec = audioCodec
        self.isEnabled = isEnabled
        self.fileSize = fileSize
        self.duration = duration
        self.timeOffset = timeOffset
    }

    // MARK: - Computed Properties

    /// @brief 해상도 문자열 (예: "1920x1080")
    /// @return "가로x세로" 형식
    ///
    /// Resolution as a formatted string (e.g., "1920x1080")
    ///
    /// 해상도를 "가로x세로" 형식의 문자열로 반환합니다.
    ///
    /// **형식:**
    /// - "{width}x{height}"
    /// - 예: "1920x1080", "3840x2160", "1280x720"
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD
    /// print(channel.resolutionString)  // "1920x1080"
    ///
    /// // UI 표시
    /// resolutionLabel.text = channel.resolutionString
    /// ```
    var resolutionString: String {
        return "\(width)x\(height)"
    }

    /// @brief 일반적인 해상도 이름 (예: "Full HD", "4K")
    /// @return 해상도 등급 이름
    ///
    /// Common resolution name (e.g., "Full HD", "4K")
    ///
    /// 일반적인 해상도 이름을 반환합니다.
    ///
    /// **해상도 매핑:**
    /// - 3840 × 2160 → "4K UHD" (Ultra High Definition)
    /// - 2560 × 1440 → "2K QHD" (Quad High Definition)
    /// - 1920 × 1080 → "Full HD"
    /// - 1280 × 720  → "HD"
    /// - 640 × 480   → "SD" (Standard Definition)
    /// - 기타        → "1920x1080" (resolutionString 반환)
    ///
    /// **switch 패턴 매칭:**
    /// - (width, height) 튜플로 두 값을 동시에 매칭
    /// - case (3840, 2160): 정확히 3840×2160일 때만 매칭
    /// - default: 위의 경우에 해당하지 않는 모든 경우
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo(position: .front, ..., width: 1920, height: 1080)
    /// print(channel.resolutionName)  // "Full HD"
    ///
    /// // UI에 표시
    /// resolutionLabel.text = channel.resolutionName  // "Full HD"
    /// detailLabel.text = channel.resolutionString    // "1920x1080"
    /// ```
    var resolutionName: String {
        switch (width, height) {
        case (3840, 2160):
            return "4K UHD"
        case (2560, 1440):
            return "2K QHD"
        case (1920, 1080):
            return "Full HD"
        case (1280, 720):
            return "HD"
        case (640, 480):
            return "SD"
        default:
            // 알 수 없는 해상도는 "1920x1080" 형식으로 반환
            return resolutionString
        }
    }

    /// @brief 화면 비율 (소수)
    /// @return 가로/세로 비율
    ///
    /// Aspect ratio as a decimal
    ///
    /// 화면 비율을 소수로 반환합니다.
    ///
    /// **화면 비율(Aspect Ratio):**
    /// - 가로 ÷ 세로의 비율
    /// - 화면의 가로세로 비율을 나타냄
    ///
    /// **계산 공식:**
    /// ```
    /// aspectRatio = width / height
    ///
    /// 예시:
    ///   1920 ÷ 1080 = 1.777... (16:9)
    ///   1280 ÷ 720  = 1.777... (16:9)
    ///   1024 ÷ 768  = 1.333... (4:3)
    ///   2560 ÷ 1080 = 2.370... (21:9)
    /// ```
    ///
    /// **일반적인 비율:**
    /// - 1.777 (16:9): 와이드스크린 (일반 블랙박스, TV)
    /// - 1.333 (4:3): 구형 비율
    /// - 2.370 (21:9): 울트라 와이드
    ///
    /// **Double 캐스팅:**
    /// - width와 height는 Int 타입
    /// - 나눗셈 전에 Double로 변환해야 소수점 계산
    /// - Double(width) / Double(height)
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD
    /// print(channel.aspectRatio)  // 1.7777777777777777
    ///
    /// // 화면 비율 체크
    /// if channel.aspectRatio > 2.0 {
    ///     print("울트라 와이드 화면")
    /// }
    /// ```
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    /// @brief 화면 비율 문자열 (예: "16:9")
    /// @return 비율 문자열
    ///
    /// Aspect ratio as a formatted string (e.g., "16:9")
    ///
    /// 화면 비율을 읽기 쉬운 문자열로 반환합니다.
    ///
    /// **변환 규칙:**
    /// - 16:9 (1.777...)에 가까우면 → "16:9"
    /// - 4:3 (1.333...)에 가까우면 → "4:3"
    /// - 21:9 (2.333...)에 가까우면 → "21:9"
    /// - 그 외 → "1.78:1" (소수점 2자리)
    ///
    /// **근사값 비교:**
    /// - abs(ratio - 16.0/9.0) < 0.01
    /// - abs: 절댓값 (음수를 양수로)
    /// - ratio와 16/9의 차이가 0.01 미만이면 "같다"고 판단
    /// - 오차 허용: 부동소수점 연산의 미세한 오차 보정
    ///
    /// **계산 예시:**
    /// ```
    /// 1920 ÷ 1080 = 1.7777...
    /// 16 ÷ 9 = 1.7777...
    /// 차이 = |1.7777... - 1.7777...| = 0.0 < 0.01  ✓ → "16:9"
    ///
    /// 1024 ÷ 768 = 1.3333...
    /// 4 ÷ 3 = 1.3333...
    /// 차이 = |1.3333... - 1.3333...| = 0.0 < 0.01  ✓ → "4:3"
    ///
    /// 1920 ÷ 1200 = 1.6
    /// 16 ÷ 9 = 1.7777...
    /// 차이 = |1.6 - 1.7777...| = 0.1777 > 0.01  ✗ → "1.60:1"
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel1 = ChannelInfo(position: .front, ..., width: 1920, height: 1080)
    /// print(channel1.aspectRatioString)  // "16:9"
    ///
    /// let channel2 = ChannelInfo(position: .front, ..., width: 1024, height: 768)
    /// print(channel2.aspectRatioString)  // "4:3"
    ///
    /// let channel3 = ChannelInfo(position: .front, ..., width: 1920, height: 1200)
    /// print(channel3.aspectRatioString)  // "1.60:1"
    /// ```
    var aspectRatioString: String {
        let ratio = aspectRatio
        // 16:9 체크 (1.777...)
        if abs(ratio - 16.0 / 9.0) < 0.01 {
            return "16:9"
            // 4:3 체크 (1.333...)
        } else if abs(ratio - 4.0 / 3.0) < 0.01 {
            return "4:3"
            // 21:9 체크 (2.333...)
        } else if abs(ratio - 21.0 / 9.0) < 0.01 {
            return "21:9"
            // 기타: "1.78:1" 형식
        } else {
            return String(format: "%.2f:1", ratio)
        }
    }

    /// @brief 프레임 레이트 문자열
    /// @return "XX fps" 또는 "XX.XX fps" 형식
    ///
    /// Frame rate as formatted string
    ///
    /// 프레임 레이트를 문자열로 반환합니다.
    ///
    /// **형식:**
    /// - 정수 프레임 레이트: "30 fps", "60 fps"
    /// - 소수 프레임 레이트: "29.97 fps", "23.98 fps"
    ///
    /// **정수 체크:**
    /// - frameRate == floor(frameRate)
    /// - floor: 소수점 이하 버림 (예: floor(30.0) = 30.0)
    /// - 30.0 == floor(30.0) → true (정수)
    /// - 29.97 == floor(29.97) → false (29.97 != 29.0)
    ///
    /// **포맷 선택:**
    /// - 정수: "\(Int(frameRate)) fps" → "30 fps"
    /// - 소수: String(format: "%.2f fps", frameRate) → "29.97 fps"
    ///
    /// **NTSC vs PAL:**
    /// - NTSC (미국, 한국): 29.97 fps (정확히는 30000/1001)
    /// - PAL (유럽): 25.0 fps
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel1 = ChannelInfo(position: .front, ..., frameRate: 30.0)
    /// print(channel1.frameRateString)  // "30 fps"
    ///
    /// let channel2 = ChannelInfo(position: .front, ..., frameRate: 29.97)
    /// print(channel2.frameRateString)  // "29.97 fps"
    ///
    /// // UI 표시
    /// fpsLabel.text = channel.frameRateString
    /// ```
    var frameRateString: String {
        // 정수 프레임 레이트 체크
        if frameRate == floor(frameRate) {
            // 정수: "30 fps"
            return "\(Int(frameRate)) fps"
        } else {
            // 소수: "29.97 fps"
            return String(format: "%.2f fps", frameRate)
        }
    }

    /// @brief 비트레이트 문자열
    /// @return "XX.X Mbps" 또는 "XXX Kbps" 형식 (옵셔널)
    ///
    /// Bitrate as human-readable string
    ///
    /// 비트레이트를 읽기 쉬운 문자열로 반환합니다.
    ///
    /// **변환 규칙:**
    /// - 1,000,000 bps 이상 → Mbps (메가비트)
    /// - 1,000,000 bps 미만 → Kbps (킬로비트)
    ///
    /// **단위 변환:**
    /// ```
    /// 1 Mbps = 1,000,000 bps
    /// 1 Kbps = 1,000 bps
    ///
    /// 예시:
    ///   8,000,000 bps = 8.0 Mbps
    ///   4,500,000 bps = 4.5 Mbps
    ///   750,000 bps = 750 Kbps
    /// ```
    ///
    /// **포맷:**
    /// - Mbps: 소수점 1자리 (예: "8.0 Mbps")
    /// - Kbps: 정수 (예: "750 Kbps")
    ///
    /// **옵셔널 반환:**
    /// - bitrate가 nil이면 nil 반환
    /// - guard let으로 옵셔널 바인딩
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel1 = ChannelInfo(position: .front, ..., bitrate: 8_000_000)
    /// print(channel1.bitrateString ?? "N/A")  // "8.0 Mbps"
    ///
    /// let channel2 = ChannelInfo(position: .front, ..., bitrate: 750_000)
    /// print(channel2.bitrateString ?? "N/A")  // "750 Kbps"
    ///
    /// let channel3 = ChannelInfo(position: .front, ..., bitrate: nil)
    /// print(channel3.bitrateString ?? "N/A")  // "N/A"
    ///
    /// // UI 표시
    /// bitrateLabel.text = channel.bitrateString ?? "알 수 없음"
    /// ```
    var bitrateString: String? {
        // bitrate가 nil이면 nil 반환
        guard let bitrate = bitrate else { return nil }

        // Mbps 단위로 변환
        let mbps = Double(bitrate) / 1_000_000

        // 1 Mbps 이상: Mbps 단위로 표시
        if mbps >= 1.0 {
            return String(format: "%.1f Mbps", mbps)
            // 1 Mbps 미만: Kbps 단위로 표시
        } else {
            let kbps = Double(bitrate) / 1000
            return String(format: "%.0f Kbps", kbps)
        }
    }

    /// @brief 파일 크기 문자열
    /// @return "XXX MB" 또는 "X.X GB" 형식
    ///
    /// File size as human-readable string
    ///
    /// 파일 크기를 읽기 쉬운 문자열로 반환합니다.
    ///
    /// **ByteCountFormatter:**
    /// - Foundation의 표준 파일 크기 포맷터
    /// - 자동으로 적절한 단위 선택 (Bytes, KB, MB, GB)
    /// - 로케일에 맞는 형식으로 표시
    ///
    /// **countStyle:**
    /// - .file: 파일 크기 형식 (1024 기반, 이진)
    ///   - 1 KB = 1,024 bytes
    ///   - 1 MB = 1,024 KB
    ///   - 1 GB = 1,024 MB
    ///
    /// - .memory: 메모리 형식 (.file과 동일, 더 명확한 이름)
    ///
    /// - .decimal: 십진법 형식 (1000 기반)
    ///   - 1 KB = 1,000 bytes
    ///   - 1 MB = 1,000 KB
    ///
    /// **포맷 예시:**
    /// ```
    /// 1,024 bytes       → "1 KB"
    /// 1,048,576 bytes   → "1 MB"
    /// 104,857,600 bytes → "100 MB"
    /// 1,073,741,824 bytes → "1 GB"
    /// ```
    ///
    /// **Int64 캐스팅:**
    /// - ByteCountFormatter.string(fromByteCount:)는 Int64 파라미터
    /// - fileSize는 UInt64
    /// - Int64(fileSize)로 변환 필요
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo(position: .front, ..., fileSize: 104_857_600)
    /// print(channel.fileSizeString)  // "100 MB"
    ///
    /// // UI 표시
    /// fileSizeLabel.text = "크기: \(channel.fileSizeString)"
    /// ```
    var fileSizeString: String {
        // ByteCountFormatter 생성
        let formatter = ByteCountFormatter()
        // 파일 크기 형식 (1024 기반)
        formatter.countStyle = .file
        // UInt64를 Int64로 변환하여 포맷
        return formatter.string(fromByteCount: Int64(fileSize))
    }

    /// @brief 파일 경로에서 파일명 추출
    /// @return 파일명 (경로 제외)
    ///
    /// Filename extracted from path
    ///
    /// 파일 경로에서 파일명만 추출합니다.
    ///
    /// **경로 vs 파일명:**
    /// ```
    /// 경로:   "normal/2025_01_10_09_00_00_F.mp4"
    ///                  ↓ lastPathComponent
    /// 파일명: "2025_01_10_09_00_00_F.mp4"
    /// ```
    ///
    /// **NSString.lastPathComponent:**
    /// - 경로의 마지막 구성 요소(파일명) 반환
    /// - 디렉토리 구분자(/) 이후의 문자열
    /// - Swift String을 NSString으로 캐스팅하여 사용
    ///
    /// **예시:**
    /// ```
    /// "normal/2025_01_10_09_00_00_F.mp4"       → "2025_01_10_09_00_00_F.mp4"
    /// "/media/sd/event/2025_01_10_10_30_15_R.mp4" → "2025_01_10_10_30_15_R.mp4"
    /// "video.mp4"                              → "video.mp4"
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo(
    ///     position: .front,
    ///     filePath: "normal/2025_01_10_09_00_00_F.mp4",
    ///     ...
    /// )
    /// print(channel.filename)  // "2025_01_10_09_00_00_F.mp4"
    ///
    /// // UI 표시
    /// filenameLabel.text = channel.filename
    /// ```
    var filename: String {
        return (filePath as NSString).lastPathComponent
    }

    /// @brief 고해상도 채널 확인 (>= 1080p)
    /// @return 1080p 이상이면 true
    ///
    /// Check if this is a high-resolution channel (>= 1080p)
    ///
    /// 고해상도 채널인지 확인합니다. (1080p 이상)
    ///
    /// **고해상도 기준:**
    /// - height >= 1080 (세로 픽셀이 1080 이상)
    /// - Full HD (1920×1080) 이상
    ///
    /// **해상도 분류:**
    /// ```
    /// 고해상도 (true):
    ///   - 4K UHD (3840×2160)     height: 2160 ✓
    ///   - 2K QHD (2560×1440)     height: 1440 ✓
    ///   - Full HD (1920×1080)    height: 1080 ✓
    ///
    /// 저해상도 (false):
    ///   - HD (1280×720)          height: 720  ✗
    ///   - SD (640×480)           height: 480  ✗
    /// ```
    ///
    /// **활용:**
    /// - UI 레이아웃 조정 (고해상도는 더 큰 화면)
    /// - 성능 최적화 (고해상도는 더 많은 리소스 사용)
    /// - 품질 표시 (고해상도 배지 표시)
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD  // 1920×1080
    /// if channel.isHighResolution {
    ///     print("고해상도 채널")
    ///     // 고해상도 UI 레이아웃 사용
    ///     playerView.frame = largeFrame
    /// } else {
    ///     print("저해상도 채널")
    ///     // 저해상도 UI 레이아웃 사용
    ///     playerView.frame = smallFrame
    /// }
    /// ```
    var isHighResolution: Bool {
        return height >= 1080
    }

    /// @brief 오디오 유무 확인
    /// @return 오디오가 있으면 true
    ///
    /// Check if audio is available
    ///
    /// 오디오가 있는지 확인합니다.
    ///
    /// **체크 로직:**
    /// - audioCodec != nil: 오디오 코덱이 있으면 오디오 있음
    /// - audioCodec == nil: 오디오 코덱이 없으면 오디오 없음
    ///
    /// **오디오가 없는 경우:**
    /// - 블랙박스 설정에서 오디오 녹음 비활성화
    /// - 오디오 하드웨어 없음 (저가형 블랙박스)
    /// - 파일 손상 또는 코덱 파싱 실패
    ///
    /// **활용:**
    /// - 오디오 컨트롤 UI 표시/숨김
    /// - 음량 조절 버튼 활성화/비활성화
    /// - 오디오 없음 안내 메시지
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD
    /// if channel.hasAudio {
    ///     print("오디오 있음: \(channel.audioCodec ?? "unknown")")
    ///     // 오디오 컨트롤 표시
    ///     volumeSlider.isHidden = false
    ///     muteButton.isHidden = false
    /// } else {
    ///     print("오디오 없음")
    ///     // 오디오 컨트롤 숨김
    ///     volumeSlider.isHidden = true
    ///     muteButton.isHidden = true
    ///     showNoAudioMessage()
    /// }
    /// ```
    var hasAudio: Bool {
        return audioCodec != nil
    }

    // MARK: - Validation

    /// @brief 필수 속성 유효성 검증
    /// @return 모든 필수 속성이 유효하면 true
    ///
    /// Validate that all required properties are valid
    ///
    /// 필수 속성이 모두 유효한지 검증합니다.
    ///
    /// **검증 조건:**
    /// 1. width > 0: 가로 해상도가 양수
    /// 2. height > 0: 세로 해상도가 양수
    /// 3. frameRate > 0: 프레임 레이트가 양수
    /// 4. !filePath.isEmpty: 파일 경로가 비어있지 않음
    ///
    /// **논리 AND (&&) 연산:**
    /// - 모든 조건이 true여야 최종 결과가 true
    /// - 하나라도 false면 최종 결과가 false
    ///
    /// **검증 예시:**
    /// ```
    /// 유효한 채널:
    ///   width: 1920 > 0       ✓
    ///   height: 1080 > 0      ✓
    ///   frameRate: 30.0 > 0   ✓
    ///   filePath: "normal/2025_01_10_09_00_00_F.mp4"  ✓
    ///   → isValid = true
    ///
    /// 잘못된 채널:
    ///   width: 0              ✗ (0은 유효하지 않음)
    ///   → isValid = false
    ///
    /// 빈 경로:
    ///   filePath: ""          ✗ (비어있음)
    ///   → isValid = false
    /// ```
    ///
    /// **활용:**
    /// - 데이터 무결성 확인
    /// - 잘못된 데이터 필터링
    /// - 에러 처리
    ///
    /// **사용 예시:**
    /// ```swift
    /// let channel = ChannelInfo(
    ///     position: .front,
    ///     filePath: "normal/2025_01_10_09_00_00_F.mp4",
    ///     width: 1920,
    ///     height: 1080,
    ///     frameRate: 30.0
    /// )
    ///
    /// if channel.isValid {
    ///     print("유효한 채널")
    ///     // 채널 재생
    ///     playChannel(channel)
    /// } else {
    ///     print("잘못된 채널 데이터")
    ///     // 에러 처리
    ///     showError("채널 데이터가 유효하지 않습니다")
    /// }
    ///
    /// // 유효한 채널만 필터링
    /// let validChannels = channels.filter { $0.isValid }
    /// ```
    var isValid: Bool {
        return width > 0 &&
            height > 0 &&
            frameRate > 0 &&
            !filePath.isEmpty
    }
}

// MARK: - Sample Data

/*
 ───────────────────────────────────────────────────────────────────────────────
 Sample Data - 샘플 채널 데이터
 ───────────────────────────────────────────────────────────────────────────────

 테스트, SwiftUI 프리뷰, 개발 중 UI 확인을 위한 샘플 데이터입니다.

 【샘플 채널 구성】

 1. frontHD: 전방 카메라 (Full HD, 1920×1080, 30fps, 8 Mbps)
 - 가장 일반적인 설정
 - 오디오 포함 (MP3)

 2. rearHD: 후방 카메라 (HD, 1280×720, 30fps, 4 Mbps)
 - 전방보다 낮은 해상도 (일반적)
 - 오디오 없음

 3. leftHD: 좌측 카메라 (HD, 1280×720, 30fps, 4 Mbps)
 - 4채널 이상 블랙박스

 4. rightHD: 우측 카메라 (HD, 1280×720, 30fps, 4 Mbps)
 - 4채널 이상 블랙박스

 5. interiorHD: 실내 카메라 (HD, 1280×720, 30fps, 4 Mbps)
 - 택시, 승차 공유용

 【실제 블랙박스 해상도 구성 예시】

 2채널 일반형:
 - 전방: Full HD (1920×1080)
 - 후방: HD (1280×720)

 2채널 고급형:
 - 전방: 4K (3840×2160)
 - 후방: Full HD (1920×1080)

 4채널:
 - 전방: Full HD (1920×1080)
 - 후방/좌측/우측: HD (1280×720)

 【사용 예시】

 SwiftUI 프리뷰:
 ```swift
 struct ChannelView_Previews: PreviewProvider {
 static var previews: some View {
 Group {
 ChannelView(channel: .frontHD)
 .previewDisplayName("Front Camera")

 ChannelView(channel: .rearHD)
 .previewDisplayName("Rear Camera")
 }
 }
 }
 ```

 단위 테스트:
 ```swift
 func testChannelValidation() {
 XCTAssertTrue(ChannelInfo.frontHD.isValid)
 XCTAssertTrue(ChannelInfo.frontHD.isHighResolution)
 XCTAssertTrue(ChannelInfo.frontHD.hasAudio)
 }

 func testResolutionNames() {
 XCTAssertEqual(ChannelInfo.frontHD.resolutionName, "Full HD")
 XCTAssertEqual(ChannelInfo.rearHD.resolutionName, "HD")
 }
 ```

 ───────────────────────────────────────────────────────────────────────────────
 */

extension ChannelInfo {
    /// Sample front camera (Full HD)
    ///
    /// 전방 카메라 샘플입니다. (Full HD)
    ///
    /// **스펙:**
    /// - 위치: 전방 (Front)
    /// - 해상도: 1920×1080 (Full HD)
    /// - 프레임 레이트: 30 fps
    /// - 비트레이트: 8 Mbps
    /// - 코덱: H.264
    /// - 오디오: MP3
    /// - 파일 크기: 100 MB
    ///
    /// **일반적인 전방 카메라 설정:**
    /// - 가장 높은 해상도 (Full HD 또는 4K)
    /// - 오디오 녹음 활성화
    /// - 높은 비트레이트로 선명한 화질
    static let frontHD = ChannelInfo(
        position: .front,
        filePath: "normal/2025_01_10_09_00_00_F.mp4",
        width: 1920,
        height: 1080,
        frameRate: 30.0,
        bitrate: 8_000_000,
        codec: "h264",
        audioCodec: "mp3",
        fileSize: 100_000_000
    )

    /// Sample rear camera (HD)
    ///
    /// 후방 카메라 샘플입니다. (HD)
    ///
    /// **스펙:**
    /// - 위치: 후방 (Rear)
    /// - 해상도: 1280×720 (HD)
    /// - 프레임 레이트: 30 fps
    /// - 비트레이트: 4 Mbps
    /// - 코덱: H.264
    /// - 오디오: 없음
    /// - 파일 크기: 50 MB
    ///
    /// **일반적인 후방 카메라 설정:**
    /// - 전방보다 낮은 해상도 (비용 절감)
    /// - 오디오 없음 (중복 녹음 불필요)
    /// - 전방의 50% 비트레이트
    static let rearHD = ChannelInfo(
        position: .rear,
        filePath: "normal/2025_01_10_09_00_00_R.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Sample left camera (HD)
    ///
    /// 좌측 카메라 샘플입니다. (HD)
    ///
    /// **스펙:**
    /// - 위치: 좌측 (Left)
    /// - 해상도: 1280×720 (HD)
    /// - 4채널 이상 블랙박스에서 사용
    static let leftHD = ChannelInfo(
        position: .left,
        filePath: "normal/2025_01_10_09_00_00_L.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Sample right camera (HD)
    ///
    /// 우측 카메라 샘플입니다. (HD)
    ///
    /// **스펙:**
    /// - 위치: 우측 (Right)
    /// - 해상도: 1280×720 (HD)
    /// - 4채널 이상 블랙박스에서 사용
    static let rightHD = ChannelInfo(
        position: .right,
        filePath: "normal/2025_01_10_09_00_00_Ri.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Sample interior camera (HD)
    ///
    /// 실내 카메라 샘플입니다. (HD)
    ///
    /// **스펙:**
    /// - 위치: 실내 (Interior)
    /// - 해상도: 1280×720 (HD)
    /// - 택시, 승차 공유 차량용
    static let interiorHD = ChannelInfo(
        position: .interior,
        filePath: "normal/2025_01_10_09_00_00_I.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Array of all sample channels
    ///
    /// 모든 샘플 채널의 배열입니다.
    ///
    /// **포함 채널:**
    /// - frontHD: 전방 Full HD
    /// - rearHD: 후방 HD
    /// - leftHD: 좌측 HD
    /// - rightHD: 우측 HD
    /// - interiorHD: 실내 HD
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 모든 채널을 SwiftUI List로 표시
    /// List(ChannelInfo.allSampleChannels) { channel in
    ///     VStack(alignment: .leading) {
    ///         Text(channel.position.displayName)
    ///         Text(channel.resolutionName)
    ///     }
    /// }
    ///
    /// // 5채널 블랙박스 시뮬레이션
    /// let multiChannelPlayer = MultiChannelPlayer(
    ///     channels: ChannelInfo.allSampleChannels
    /// )
    /// ```
    static let allSampleChannels: [ChannelInfo] = [
        frontHD,
        rearHD,
        leftHD,
        rightHD,
        interiorHD
    ]
}
