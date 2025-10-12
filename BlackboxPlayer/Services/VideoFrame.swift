/// @file VideoFrame.swift
/// @brief 디코딩된 비디오 프레임 데이터 모델
/// @author BlackboxPlayer Development Team
/// @details
/// FFmpeg에서 디코딩한 원시 비디오 프레임(픽셀 데이터)를 담는 구조체입니다.
/// H.264 등 압축된 비디오를 디코딩하면 RGB 또는 YUV 형태의 원시 픽셀 데이터가 생성되는데,
/// 이를 프레임 단위로 관리합니다.
///
/// [이 파일의 역할]
/// FFmpeg에서 디코딩한 원시 비디오 프레임(픽셀 데이터)를 담는 구조체입니다.
/// H.264 등 압축된 비디오를 디코딩하면 RGB 또는 YUV 형태의 원시 픽셀 데이터가 생성되는데,
/// 이를 프레임 단위로 관리합니다.
///
/// [비디오 프레임이란?]
/// 동영상의 한 장의 이미지입니다:
/// - 영화: 24 fps (1초에 24장)
/// - TV/비디오: 30 fps (1초에 30장)
/// - 블랙박스: 일반적으로 30 fps
///
/// [데이터 흐름]
/// 1. VideoDecoder가 FFmpeg로 H.264 디코딩 → 원시 픽셀 데이터 생성
/// 2. VideoFrame 구조체에 픽셀 데이터 + 메타정보 저장
/// 3. MultiChannelRenderer가 VideoFrame을 CVPixelBuffer로 변환
/// 4. Metal GPU가 화면에 렌더링
///
/// H.264 파일 (압축) → FFmpeg 디코딩 → VideoFrame (원시 픽셀) → CVPixelBuffer → Metal → 🖥️ 화면
///

import Foundation
import CoreGraphics
import CoreVideo

// MARK: - VideoFrame 구조체

/// @struct VideoFrame
/// @brief 디코딩된 비디오 프레임 (원시 픽셀 데이터)
///
/// @details
/// FFmpeg에서 디코딩한 원시 비디오 데이터를 Swift에서 다루기 쉽게 포장한 구조체입니다.
///
/// ## 사용 예시
/// ```swift
/// // FFmpeg에서 디코딩된 비디오 프레임 생성
/// let frame = VideoFrame(
///     timestamp: 1.5,           // 비디오 1.5초 지점
///     width: 1920,              // Full HD 너비
///     height: 1080,             // Full HD 높이
///     pixelFormat: .rgba,       // RGBA 32비트 컬러
///     data: pixelData,          // 실제 픽셀 바이트
///     lineSize: 1920 * 4,       // 1행당 바이트 (1920 × 4)
///     frameNumber: 45,          // 45번째 프레임
///     isKeyFrame: true          // I-프레임 (키프레임)
/// )
///
/// // Metal 렌더링을 위해 CVPixelBuffer로 변환
/// if let pixelBuffer = frame.toPixelBuffer() {
///     renderer.render(pixelBuffer)
/// }
/// ```
///
/// ## RGB vs YUV 픽셀 포맷
///
/// **RGB (Red, Green, Blue)**:
/// - 컴퓨터 그래픽 표준
/// - 픽셀 = (R, G, B) 또는 (R, G, B, A)
/// - 직관적이고 처리 쉬움
/// - 메모리 많이 사용
///
/// **YUV (Luma, Chroma)**:
/// - 비디오 압축 표준 (H.264, H.265)
/// - Y = 밝기, U/V = 색상
/// - 색상 서브샘플링으로 메모리 절약 (4:2:0 = 50% 절감)
/// - 디코딩 후 RGB 변환 필요
struct VideoFrame {
    // MARK: - Properties

    /// @var timestamp
    /// @brief 프레젠테이션 타임스탬프 (초 단위)
    ///
    /// @details
    /// 이 비디오 프레임이 재생되어야 하는 시간입니다.
    /// 오디오 프레임과 동기화하는 데 사용됩니다.
    ///
    /// **예시**:
    /// - timestamp = 0.000초 (첫 프레임)
    /// - timestamp = 0.033초 (30fps 기준 두 번째 프레임)
    /// - timestamp = 1.000초 (1초 지점)
    let timestamp: TimeInterval

    /// @var width
    /// @brief 프레임 너비 (픽셀 단위)
    ///
    /// @details
    /// **일반적인 해상도**:
    /// - 640 × 480: VGA (구형)
    /// - 1280 × 720: HD (720p)
    /// - 1920 × 1080: Full HD (1080p) ⭐ 블랙박스 표준
    /// - 3840 × 2160: 4K UHD
    let width: Int

    /// @var height
    /// @brief 프레임 높이 (픽셀 단위)
    let height: Int

    /// @var pixelFormat
    /// @brief 픽셀 포맷 (RGB, RGBA, YUV 등)
    ///
    /// @details
    /// 픽셀 데이터가 메모리에 저장된 형식을 정의합니다.
    ///
    /// **포맷 선택의 영향**:
    /// ```
    /// RGB24 (1920×1080):  1920 × 1080 × 3 = 6,220,800 bytes (6.2MB)
    /// RGBA (1920×1080):   1920 × 1080 × 4 = 8,294,400 bytes (8.3MB)
    /// YUV420p (1920×1080): 1920 × 1080 × 1.5 = 3,110,400 bytes (3.1MB) ← 50% 절약!
    /// ```
    let pixelFormat: PixelFormat

    /// @var data
    /// @brief 원시 픽셀 데이터 (바이트 배열)
    ///
    /// @details
    /// 실제 이미지의 색상 정보가 바이너리 형태로 저장된 Data입니다.
    ///
    /// **데이터 구조 예시 (RGBA, 2×2 픽셀)**:
    /// ```
    /// 픽셀 레이아웃:
    /// [Pixel(0,0)][Pixel(1,0)]
    /// [Pixel(0,1)][Pixel(1,1)]
    ///
    /// 메모리 레이아웃 (RGBA):
    /// [R0 G0 B0 A0][R1 G1 B1 A1][R2 G2 B2 A2][R3 G3 B3 A3]
    ///  픽셀(0,0)    픽셀(1,0)    픽셀(0,1)    픽셀(1,1)
    ///
    /// 총 16바이트 (4픽셀 × 4바이트)
    /// ```
    ///
    /// FFmpeg에서 디코딩 시 이 Data를 채웁니다.
    let data: Data

    /// @var lineSize
    /// @brief 라인 크기 (1행당 바이트 수)
    ///
    /// @details
    /// 이미지 한 줄(행)을 저장하는 데 사용되는 바이트 수입니다.
    /// 메모리 정렬(alignment)을 위해 실제 픽셀 데이터보다 클 수 있습니다.
    ///
    /// **계산**:
    /// ```
    /// 이론적 크기: width × bytesPerPixel
    /// 실제 크기: lineSize (정렬 패딩 포함)
    ///
    /// 예시 (1920×1080 RGBA):
    /// 이론: 1920 × 4 = 7,680 bytes
    /// 실제: 7,680 bytes (또는 7,696 bytes with padding)
    /// ```
    ///
    /// **왜 차이가 나는가?**
    /// CPU/GPU는 16바이트, 32바이트 단위로 메모리를 읽는 것이 효율적입니다.
    /// 따라서 1행의 크기를 16의 배수로 맞추기 위해 패딩을 추가합니다.
    let lineSize: Int

    /// @var frameNumber
    /// @brief 프레임 번호 (0부터 시작)
    ///
    /// @details
    /// 비디오 시작부터의 순서입니다.
    ///
    /// **예시**:
    /// - frameNumber = 0: 첫 프레임
    /// - frameNumber = 30: 30fps 비디오의 1초 지점
    /// - frameNumber = 900: 30fps 비디오의 30초 지점
    let frameNumber: Int

    /// @var isKeyFrame
    /// @brief 키프레임(I-프레임) 여부
    ///
    /// @details
    /// **비디오 압축의 프레임 타입**:
    /// ```
    /// I-Frame (Intra-frame, 키프레임):
    /// - 완전한 이미지 (독립적)
    /// - 크기 큼 (100~200KB)
    /// - Seek 시작점
    ///
    /// P-Frame (Predicted frame):
    /// - 이전 프레임과의 차이만 저장
    /// - 크기 작음 (10~50KB)
    /// - I-Frame 없이 디코딩 불가
    ///
    /// B-Frame (Bidirectional frame):
    /// - 이전+이후 프레임 참조
    /// - 크기 매우 작음 (5~20KB)
    /// - 가장 복잡한 디코딩
    /// ```
    ///
    /// **GOP (Group of Pictures) 구조 예시**:
    /// ```
    /// I P P P P P P P P P I P P P P P P P P P I ...
    /// ↑ 키프레임     ↑ 키프레임     ↑ 키프레임
    /// └─ GOP 1 ──────┘ └─ GOP 2 ──────┘
    /// ```
    ///
    /// **Seek 동작**:
    /// - 사용자가 30초로 Seek 요청
    /// - 30초 이전의 가장 가까운 I-Frame 찾기 (예: 28초)
    /// - 28초 I-Frame부터 디코딩 시작
    /// - 30초까지 P/B-Frame 디코딩
    let isKeyFrame: Bool

    // MARK: - Initialization

    /// @brief VideoFrame 초기화
    ///
    /// @details
    /// FFmpeg에서 디코딩한 픽셀 데이터로 VideoFrame을 생성합니다.
    /// 일반적으로 VideoDecoder 내부에서 호출됩니다.
    ///
    /// @param timestamp 프레젠테이션 타임스탬프 (초 단위)
    /// @param width 프레임 너비 (픽셀)
    /// @param height 프레임 높이 (픽셀)
    /// @param pixelFormat 픽셀 포맷
    /// @param data 원시 픽셀 데이터
    /// @param lineSize 1행당 바이트 수
    /// @param frameNumber 프레임 번호
    /// @param isKeyFrame 키프레임 여부
    init(
        timestamp: TimeInterval,
        width: Int,
        height: Int,
        pixelFormat: PixelFormat,
        data: Data,
        lineSize: Int,
        frameNumber: Int,
        isKeyFrame: Bool
    ) {
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.data = data
        self.lineSize = lineSize
        self.frameNumber = frameNumber
        self.isKeyFrame = isKeyFrame
    }

    // MARK: - Computed Properties

    /// @brief 화면 비율 (가로 ÷ 세로)
    ///
    /// @return 화면 비율 (Double)
    ///
    /// @details
    /// **일반적인 비율**:
    /// ```
    /// 4:3 = 1.333 (구형 TV)
    /// 16:9 = 1.777 (HD, Full HD) ⭐ 현대 표준
    /// 21:9 = 2.333 (시네마 디스플레이)
    /// ```
    ///
    /// **사용 예시**:
    /// ```swift
    /// // 화면에 맞게 비율 유지하며 표시
    /// let frame = videoFrame
    /// let viewAspect = view.width / view.height
    /// let frameAspect = frame.aspectRatio
    ///
    /// if frameAspect > viewAspect {
    ///     // 프레임이 더 넓음 → 가로 맞춤, 위아래 여백
    /// } else {
    ///     // 프레임이 더 높음 → 세로 맞춤, 좌우 여백
    /// }
    /// ```
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    /// @brief 픽셀 데이터의 총 바이트 크기
    ///
    /// @return 데이터 크기 (바이트)
    ///
    /// @details
    /// **메모리 사용량 계산**:
    /// ```
    /// 1080p RGBA: 8.3MB per frame
    /// 30fps: 8.3MB × 30 = 249MB/sec
    /// 1분 비디오: 249MB × 60 = 14.9GB!
    ///
    /// → 압축 필수 (H.264로 압축 시 수백 배 절감)
    /// ```
    var dataSize: Int {
        return data.count
    }

    // MARK: - Image Conversion

    /// @brief CGImage로 변환 (화면 표시용)
    ///
    /// @return CGImage, 변환 실패 시 nil
    ///
    /// @details
    /// RGB 또는 RGBA 픽셀 데이터를 macOS의 표준 이미지 형식인 CGImage로 변환합니다.
    /// AppKit (NSImage) 또는 SwiftUI (Image)에서 사용할 수 있습니다.
    ///
    /// **변환 과정**:
    /// ```
    /// VideoFrame (원시 픽셀) → CGDataProvider → CGImage
    ///                           (메모리 래핑)   (이미지 객체)
    /// ```
    ///
    /// **지원 포맷**: RGB24, RGBA만 지원. YUV는 RGB 변환 후 사용해야 함.
    ///
    /// **사용 예시**:
    /// ```swift
    /// // SwiftUI에서 표시
    /// if let cgImage = frame.toCGImage() {
    ///     let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))
    ///     Image(nsImage: nsImage)
    ///         .resizable()
    ///         .aspectRatio(contentMode: .fit)
    /// }
    /// ```
    func toCGImage() -> CGImage? {
        // YUV 포맷은 지원하지 않음 (RGB 변환 필요)
        guard pixelFormat == .rgb24 || pixelFormat == .rgba else {
            return nil
        }

        // 픽셀 정보 설정
        let bitsPerComponent = 8  // R, G, B 각각 8비트 (256 레벨)
        let bitsPerPixel = pixelFormat == .rgb24 ? 24 : 32  // RGB=24, RGBA=32
        let bytesPerRow = lineSize

        // CGDataProvider 생성 (Data를 CGImage가 읽을 수 있게 래핑)
        guard let dataProvider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        // RGB 색공간 생성 (sRGB)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // 알파 채널 정보 설정
        let bitmapInfo: CGBitmapInfo = pixelFormat == .rgba ?
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue) :  // RGBA: 알파 있음
            CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)                 // RGB: 알파 없음

        // CGImage 생성
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,      // 부드러운 확대/축소
            intent: .defaultIntent
        )
    }

    /// @brief CVPixelBuffer로 변환 (Metal GPU 렌더링용)
    ///
    /// @return CVPixelBuffer, 변환 실패 시 nil
    ///
    /// @details
    /// Metal GPU가 직접 사용할 수 있는 CVPixelBuffer 형식으로 변환합니다.
    /// GPU 메모리와 호환되며 제로카피(zero-copy) 렌더링이 가능합니다.
    ///
    /// **CVPixelBuffer란?**
    /// - Core Video의 픽셀 버퍼 타입
    /// - GPU 메모리와 직접 공유 가능
    /// - Metal, AVFoundation과 호환
    /// - IOSurface 기반 (프로세스 간 공유 가능)
    ///
    /// **제로카피 렌더링**:
    /// ```
    /// 일반적인 방법:
    /// Data → 복사 → Texture → GPU
    ///          ↑ 메모리 복사 (느림)
    ///
    /// CVPixelBuffer 방법:
    /// Data → CVPixelBuffer ← Metal Texture
    ///            ↑ 같은 메모리 공유 (빠름)
    /// ```
    ///
    /// **Metal 통합**:
    /// ```swift
    /// // CVPixelBuffer → Metal Texture 변환
    /// if let pixelBuffer = frame.toPixelBuffer() {
    ///     let texture = textureCache.createTexture(from: pixelBuffer)
    ///     metalRenderer.render(texture)
    /// }
    /// ```
    func toPixelBuffer() -> CVPixelBuffer? {
        // 1단계: 픽셀 포맷 매핑
        let pixelFormatType: OSType
        switch pixelFormat {
        case .rgb24:
            pixelFormatType = kCVPixelFormatType_24RGB
        case .rgba:
            // Metal 호환성을 위해 BGRA 사용
            // FFmpeg는 RGBA로 출력하지만 실제로는 BGRA 순서
            pixelFormatType = kCVPixelFormatType_32BGRA
        case .yuv420p:
            pixelFormatType = kCVPixelFormatType_420YpCbCr8Planar
        case .nv12:
            pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }

        // 2단계: Metal 호환 속성 설정
        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,    // Metal 사용 가능
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary  // 프로세스 간 공유 가능
        ]

        // 3단계: CVPixelBuffer 생성
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormatType,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            errorLog("[VideoFrame] Failed to create CVPixelBuffer with status: \(status)")
            return nil
        }

        // 4단계: 픽셀 데이터 복사
        // Lock: CPU가 버퍼에 쓰는 동안 GPU 접근 차단
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }  // 자동 Unlock

        // 행(row) 단위로 복사 (stride 차이 처리)
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)  // CVPixelBuffer의 stride
            let srcBytesPerRow = lineSize                                // 소스 데이터의 stride
            let minBytesPerRow = min(destBytesPerRow, srcBytesPerRow)  // 실제 복사할 크기

            data.withUnsafeBytes { dataBytes in
                if let sourcePtr = dataBytes.baseAddress {
                    // 각 행을 개별적으로 복사 (stride 차이 때문)
                    for row in 0..<height {
                        let destRowPtr = baseAddress.advanced(by: row * destBytesPerRow)
                        let srcRowPtr = sourcePtr.advanced(by: row * srcBytesPerRow)
                        memcpy(destRowPtr, srcRowPtr, minBytesPerRow)
                    }
                }
            }
        }

        return buffer
    }
}

// MARK: - Supporting Types

/// @enum PixelFormat
/// @brief 픽셀 포맷 정의
///
/// @details
/// 픽셀 데이터를 메모리에 저장하는 방식을 정의합니다.
///
/// ## RGB vs YUV 비교
///
/// **RGB (Red, Green, Blue)**:
/// ```
/// 장점:
/// ✅ 직관적 (컴퓨터 모니터 방식)
/// ✅ 처리 간단
/// ✅ 픽셀별 독립적
///
/// 단점:
/// ❌ 메모리 많이 사용
/// ❌ 압축 효율 낮음
///
/// 용도: 컴퓨터 그래픽, 사진 편집
/// ```
///
/// **YUV (Luma + Chroma)**:
/// ```
/// 장점:
/// ✅ 메모리 절약 (4:2:0 = 50% 절감)
/// ✅ 압축 효율 높음
/// ✅ 비디오 표준 (H.264, H.265)
///
/// 단점:
/// ❌ RGB 변환 필요
/// ❌ 색상 서브샘플링으로 정밀도 손실
///
/// 용도: 비디오 압축, 방송
/// ```
///
/// ## 4:2:0 서브샘플링
/// ```
/// Full Resolution (4:4:4):
/// Y Y Y Y    U U U U    V V V V
/// Y Y Y Y    U U U U    V V V V
/// Y Y Y Y    U U U U    V V V V
/// Y Y Y Y    U U U U    V V V V
/// 48 samples (100%)
///
/// 4:2:0 Subsampling:
/// Y Y Y Y    U   U      V   V
/// Y Y Y Y
/// Y Y Y Y    U   U      V   V
/// Y Y Y Y
/// 24 samples (50%) ← 절반으로 감소!
/// ```
enum PixelFormat: String, Codable {
    /// @brief RGB 24비트 (알파 없음)
    ///
    /// @details
    /// **구조**: [R G B][R G B][R G B]...
    /// - R: 빨강 (0~255)
    /// - G: 초록 (0~255)
    /// - B: 파랑 (0~255)
    ///
    /// **메모리**: width × height × 3 bytes
    /// 예: 1920×1080 = 6.2MB per frame
    case rgb24 = "rgb24"

    /// @brief RGBA 32비트 (알파 포함)
    ///
    /// @details
    /// **구조**: [R G B A][R G B A][R G B A]...
    /// - R, G, B: 색상 (0~255)
    /// - A: 투명도 (0=투명, 255=불투명)
    ///
    /// **메모리**: width × height × 4 bytes
    /// 예: 1920×1080 = 8.3MB per frame
    case rgba = "rgba"

    /// @brief YUV 4:2:0 Planar (표준 비디오 포맷)
    ///
    /// @details
    /// **구조**: [Y plane][U plane][V plane]
    /// - Y: 밝기 정보 (full resolution)
    /// - U: 파랑-밝기 차이 (1/4 resolution)
    /// - V: 빨강-밝기 차이 (1/4 resolution)
    ///
    /// **메모리**: width × height × 1.5 bytes
    /// 예: 1920×1080 = 3.1MB per frame (RGB의 50%)
    ///
    /// **H.264 표준 포맷**
    case yuv420p = "yuv420p"

    /// @brief NV12 Semi-Planar (하드웨어 디코더 사용)
    ///
    /// @details
    /// **구조**: [Y plane][UV interleaved plane]
    /// - Y: 밝기 정보 (full resolution)
    /// - UV: U와 V가 교차 배치 (UVUVUV...)
    ///
    /// **메모리**: width × height × 1.5 bytes
    ///
    /// **특징**: GPU 하드웨어 디코더 선호 포맷
    case nv12 = "nv12"

    /// @brief 픽셀당 바이트 크기
    ///
    /// @return 바이트 크기
    ///
    /// @details
    /// **주의**: YUV는 서브샘플링으로 인해 픽셀별로 다릅니다.
    /// 여기서는 평균값 (1.5) 대신 Luma plane 기준 (1)을 반환합니다.
    var bytesPerPixel: Int {
        switch self {
        case .rgb24:
            return 3  // RGB
        case .rgba:
            return 4  // RGBA
        case .yuv420p, .nv12:
            return 1  // Y plane만 (U/V는 서브샘플링)
        }
    }
}

// MARK: - Equatable

/// @brief VideoFrame 동등성 비교
///
/// @details
/// 두 VideoFrame이 "같은" 프레임인지 판단합니다.
/// 주로 디버깅, 테스트, 중복 제거에 사용됩니다.
///
/// **비교 기준**:
/// - timestamp: 같은 시점인가?
/// - frameNumber: 같은 프레임 번호인가?
/// - width, height: 같은 크기인가?
///
/// **주의**: `data`는 비교하지 않습니다! (성능상 이유)
extension VideoFrame: Equatable {
    /// @brief 두 VideoFrame 비교
    /// @param lhs 왼쪽 피연산자
    /// @param rhs 오른쪽 피연산자
    /// @return 동등하면 true
    static func == (lhs: VideoFrame, rhs: VideoFrame) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.frameNumber == rhs.frameNumber &&
               lhs.width == rhs.width &&
               lhs.height == rhs.height
    }
}

// MARK: - CustomStringConvertible

/// @brief VideoFrame 디버그 문자열 표현
///
/// @details
/// **출력 예시**:
/// ```
/// [K] Frame #0 @ 0.000s (1920x1080 rgba) 8294400 bytes
/// [ ] Frame #1 @ 0.033s (1920x1080 rgba) 8294400 bytes
/// [ ] Frame #2 @ 0.067s (1920x1080 rgba) 8294400 bytes
/// [K] Frame #30 @ 1.000s (1920x1080 rgba) 8294400 bytes
///
/// [K] = 키프레임 (I-Frame)
/// [ ] = P/B-Frame
/// ```
extension VideoFrame: CustomStringConvertible {
    /// @brief 디버그 문자열
    var description: String {
        let keyframeStr = isKeyFrame ? "K" : " "  // K = Keyframe
        return String(
            format: "[%@] Frame #%d @ %.3fs (%dx%d %@) %d bytes",
            keyframeStr,
            frameNumber,
            timestamp,
            width,
            height,
            pixelFormat.rawValue,
            dataSize
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// 통합 가이드: VideoFrame 사용 플로우
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ 디코딩 (VideoDecoder)
// ────────────────────────────────────────────────
// H.264 파일 → FFmpeg 디코딩 → 픽셀 데이터
//
// let videoFrame = VideoFrame(
//     timestamp: pts,
//     width: 1920,
//     height: 1080,
//     pixelFormat: .rgba,
//     data: pixelData,
//     lineSize: 1920 * 4,
//     frameNumber: frameIndex,
//     isKeyFrame: isKeyFrame
// )
//
// 2️⃣ 큐잉 (VideoChannel)
// ────────────────────────────────────────────────
// 디코딩된 프레임을 버퍼에 저장
//
// videoBuffer.append(videoFrame)
//
// 3️⃣ 동기화 (SyncController)
// ────────────────────────────────────────────────
// 오디오 프레임과 타임스탬프 비교
//
// if abs(videoFrame.timestamp - audioFrame.timestamp) < 0.05 {
//     // 동기화 OK (±50ms 이내)
// }
//
// 4️⃣ 렌더링 (MultiChannelRenderer)
// ────────────────────────────────────────────────
// CVPixelBuffer로 변환 후 Metal GPU 렌더링
//
// if let pixelBuffer = videoFrame.toPixelBuffer() {
//     let texture = textureCache.createTexture(from: pixelBuffer)
//     metalRenderer.draw(texture)
// }
//
// 5️⃣ 화면 출력
// ────────────────────────────────────────────────
// Metal → CAMetalLayer → 🖥️ 디스플레이
//
// ═══════════════════════════════════════════════════════════════════════════
