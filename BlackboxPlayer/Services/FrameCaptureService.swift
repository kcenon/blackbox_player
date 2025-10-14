/// @file FrameCaptureService.swift
/// @brief Frame capture service for screenshot functionality
/// @author BlackboxPlayer Development Team
/// @details
/// 이 파일은 비디오 프레임을 캡처하여 이미지 파일로 저장하는 서비스를 정의합니다.

import Foundation
import CoreGraphics
import AppKit

/// @class FrameCaptureService
/// @brief 비디오 프레임을 캡처하고 저장하는 서비스 클래스입니다.
///
/// @details
/// ## 주요 기능:
/// - 현재 비디오 프레임 캡처
/// - 다양한 이미지 포맷 지원 (PNG, JPEG)
/// - 메타데이터 오버레이 (타임스탬프, GPS 정보)
/// - 다중 채널 캡처 (모든 카메라 뷰 한 번에)
///
/// ## 사용 예:
/// ```swift
/// let service = FrameCaptureService()
///
/// // 단일 프레임 캡처
/// try service.captureFrame(
///     frame: videoFrame,
///     toFile: "/path/to/capture.png",
///     format: .png
/// )
///
/// // 메타데이터 포함 캡처
/// try service.captureWithOverlay(
///     frame: videoFrame,
///     metadata: "2024-01-15 14:30:25",
///     toFile: "/path/to/capture.png"
/// )
/// ```
class FrameCaptureService {

    // MARK: - Types

    /// @enum ImageFormat
    /// @brief 지원되는 이미지 포맷
    enum ImageFormat {
        case png    // 무손실 압축, 큰 파일 크기
        case jpeg(quality: Double)  // 손실 압축, 작은 파일 크기, quality: 0.0~1.0
    }

    /// @enum CaptureError
    /// @brief 캡처 관련 에러
    enum CaptureError: LocalizedError {
        case cannotCreateImage
        case cannotWriteFile(String)
        case invalidFrame
        case invalidPath(String)

        var errorDescription: String? {
            switch self {
            case .cannotCreateImage:
                return "Failed to create image from frame data"
            case .cannotWriteFile(let path):
                return "Failed to write image to file: \(path)"
            case .invalidFrame:
                return "Invalid video frame data"
            case .invalidPath(let path):
                return "Invalid file path: \(path)"
            }
        }
    }

    // MARK: - Initialization

    /// @brief 프레임 캡처 서비스를 생성합니다.
    init() {
        // 초기화 로직 없음
    }

    // MARK: - Public Methods

    /// @brief 비디오 프레임을 이미지 파일로 저장합니다.
    ///
    /// @param frame 캡처할 비디오 프레임
    /// @param toFile 저장할 파일 경로 (절대 경로)
    /// @param format 이미지 포맷 (기본값: PNG)
    ///
    /// @throws CaptureError
    ///
    /// @details
    /// 캡처 과정:
    /// 1. VideoFrame 데이터를 CGImage로 변환
    /// 2. CGImage를 NSImage로 변환
    /// 3. 지정된 포맷으로 인코딩
    /// 4. 파일에 저장
    func captureFrame(
        frame: VideoFrame,
        toFile filePath: String,
        format: ImageFormat = .png
    ) throws {
        // 1. VideoFrame을 CGImage로 변환
        guard let cgImage = createCGImage(from: frame) else {
            throw CaptureError.cannotCreateImage
        }

        // 2. CGImage를 NSImage로 변환
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))

        // 3. 이미지 데이터 생성
        guard let imageData = encodeImage(nsImage, format: format) else {
            throw CaptureError.cannotCreateImage
        }

        // 4. 파일에 저장
        let url = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw CaptureError.cannotWriteFile(filePath)
        }
    }

    /// @brief 메타데이터 오버레이와 함께 프레임을 캡처합니다.
    ///
    /// @param frame 캡처할 비디오 프레임
    /// @param overlayText 오버레이할 텍스트 (타임스탬프, GPS 정보 등)
    /// @param toFile 저장할 파일 경로
    /// @param format 이미지 포맷
    ///
    /// @throws CaptureError
    ///
    /// @details
    /// 오버레이 위치:
    /// - 화면 하단에 반투명 검은색 배경
    /// - 흰색 텍스트로 정보 표시
    func captureWithOverlay(
        frame: VideoFrame,
        overlayText: String,
        toFile filePath: String,
        format: ImageFormat = .png
    ) throws {
        // 1. VideoFrame을 CGImage로 변환
        guard let cgImage = createCGImage(from: frame) else {
            throw CaptureError.cannotCreateImage
        }

        // 2. CGImage를 NSImage로 변환
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))

        // 3. 오버레이 추가
        let overlayedImage = addOverlay(to: nsImage, text: overlayText)

        // 4. 이미지 데이터 생성
        guard let imageData = encodeImage(overlayedImage, format: format) else {
            throw CaptureError.cannotCreateImage
        }

        // 5. 파일에 저장
        let url = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw CaptureError.cannotWriteFile(filePath)
        }
    }

    /// @brief 다중 채널 프레임을 하나의 이미지로 캡처합니다.
    ///
    /// @param frames 채널별 비디오 프레임 딕셔너리
    /// @param layout 레이아웃 (grid, horizontal)
    /// @param toFile 저장할 파일 경로
    /// @param format 이미지 포맷
    ///
    /// @throws CaptureError
    ///
    /// @details
    /// 레이아웃:
    /// - grid: 2x3 그리드 (최대 6개 채널)
    /// - horizontal: 수평 배치 (1x5)
    func captureMultiChannel(
        frames: [String: VideoFrame],
        layout: ChannelLayout = .grid,
        toFile filePath: String,
        format: ImageFormat = .png
    ) throws {
        // 채널 정렬 (일관된 순서로)
        let sortedFrames = frames.sorted { $0.key < $1.key }.map { $0.value }

        guard !sortedFrames.isEmpty else {
            throw CaptureError.invalidFrame
        }

        // 레이아웃에 따라 합성
        let compositeImage: NSImage
        switch layout {
        case .grid:
            compositeImage = createGridImage(frames: sortedFrames)
        case .horizontal:
            compositeImage = createHorizontalImage(frames: sortedFrames)
        }

        // 이미지 데이터 생성
        guard let imageData = encodeImage(compositeImage, format: format) else {
            throw CaptureError.cannotCreateImage
        }

        // 파일에 저장
        let url = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw CaptureError.cannotWriteFile(filePath)
        }
    }

    // MARK: - Private Methods

    /// @brief VideoFrame을 CGImage로 변환합니다.
    ///
    /// @param frame 비디오 프레임
    ///
    /// @return CGImage, 실패 시 nil
    ///
    /// @details
    /// VideoFrame의 BGRA 데이터를 CGImage로 변환합니다.
    private func createCGImage(from frame: VideoFrame) -> CGImage? {
        let width = frame.width
        let height = frame.height
        let data = frame.data

        // Data를 CFData로 변환
        let cfData = data as CFData

        // Data Provider 생성
        guard let dataProvider = CGDataProvider(data: cfData) else {
            return nil
        }

        // Color Space 생성 (sRGB)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        // CGImage 생성
        // BGRA 포맷 (VideoDecoder 출력 포맷)
        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: frame.lineSize,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )

        return cgImage
    }

    /// @brief NSImage를 지정된 포맷으로 인코딩합니다.
    ///
    /// @param image NSImage 인스턴스
    /// @param format 이미지 포맷
    ///
    /// @return 인코딩된 이미지 데이터, 실패 시 nil
    private func encodeImage(_ image: NSImage, format: ImageFormat) -> Data? {
        // NSImage를 CGImage로 변환
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // NSBitmapImageRep 생성
        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        // 포맷에 따라 인코딩
        switch format {
        case .png:
            return bitmap.representation(using: .png, properties: [:])
        case .jpeg(let quality):
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
    }

    /// @brief 이미지에 텍스트 오버레이를 추가합니다.
    ///
    /// @param image 원본 이미지
    /// @param text 오버레이할 텍스트
    ///
    /// @return 오버레이가 추가된 이미지
    private func addOverlay(to image: NSImage, text: String) -> NSImage {
        let size = image.size

        // 새 이미지 생성 (원본과 같은 크기)
        let newImage = NSImage(size: size)
        newImage.lockFocus()

        // 원본 이미지 그리기
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)

        // 배경 사각형 (하단, 반투명 검은색)
        let bgHeight: CGFloat = 40
        let bgRect = NSRect(x: 0, y: 0, width: size.width, height: bgHeight)
        NSColor.black.withAlphaComponent(0.7).setFill()
        bgRect.fill()

        // 텍스트 속성
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        // 텍스트 그리기
        let textRect = NSRect(x: 0, y: 10, width: size.width, height: 20)
        (text as NSString).draw(in: textRect, withAttributes: attributes)

        newImage.unlockFocus()

        return newImage
    }

    /// @brief 프레임들을 그리드 레이아웃으로 합성합니다.
    ///
    /// @param frames 프레임 배열
    ///
    /// @return 합성된 이미지
    ///
    /// @details
    /// 2x3 그리드 (최대 6개 채널)
    private func createGridImage(frames: [VideoFrame]) -> NSImage {
        // 첫 번째 프레임의 크기를 기준으로
        let frameWidth = frames.first?.width ?? 1920
        let frameHeight = frames.first?.height ?? 1080

        // 2x3 그리드
        let cols = 3
        let rows = 2
        let totalWidth = frameWidth * cols
        let totalHeight = frameHeight * rows

        // 새 이미지 생성
        let compositeImage = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        compositeImage.lockFocus()

        // 각 프레임 배치
        for (index, frame) in frames.prefix(6).enumerated() {
            let row = index / cols
            let col = index % cols

            let x = col * frameWidth
            let y = (rows - 1 - row) * frameHeight  // 위에서 아래로

            if let cgImage = createCGImage(from: frame) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))
                let rect = NSRect(x: x, y: y, width: frameWidth, height: frameHeight)
                nsImage.draw(in: rect)
            }
        }

        compositeImage.unlockFocus()

        return compositeImage
    }

    /// @brief 프레임들을 수평 레이아웃으로 합성합니다.
    ///
    /// @param frames 프레임 배열
    ///
    /// @return 합성된 이미지
    ///
    /// @details
    /// 1x5 수평 배치
    private func createHorizontalImage(frames: [VideoFrame]) -> NSImage {
        let frameWidth = frames.first?.width ?? 1920
        let frameHeight = frames.first?.height ?? 1080

        let count = min(frames.count, 5)
        let totalWidth = frameWidth * count
        let totalHeight = frameHeight

        // 새 이미지 생성
        let compositeImage = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        compositeImage.lockFocus()

        // 각 프레임 배치
        for (index, frame) in frames.prefix(5).enumerated() {
            let x = index * frameWidth

            if let cgImage = createCGImage(from: frame) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))
                let rect = NSRect(x: x, y: 0, width: frameWidth, height: frameHeight)
                nsImage.draw(in: rect)
            }
        }

        compositeImage.unlockFocus()

        return compositeImage
    }
}

// MARK: - Supporting Types

/// @enum ChannelLayout
/// @brief 다중 채널 레이아웃
enum ChannelLayout {
    case grid        // 2x3 그리드
    case horizontal  // 1x5 수평
}
