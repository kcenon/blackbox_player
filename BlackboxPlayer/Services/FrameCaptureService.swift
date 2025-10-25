/// @file FrameCaptureService.swift
/// @brief Frame capture service for screenshot functionality
/// @author BlackboxPlayer Development Team
/// @details
/// This file defines a service for capturing video frames and saving them as image files.

import Foundation
import CoreGraphics
import AppKit

/// @class FrameCaptureService
/// @brief Service class for capturing and saving video frames.
///
/// @details
/// ## Key Features:
/// - Capture current video frame
/// - Support various image formats (PNG, JPEG)
/// - Metadata overlay (Timestamp, GPS info)
/// - Multi-channel capture (All camera views at once)
///
/// ## Usage Example:
/// ```swift
/// let service = FrameCaptureService()
///
/// // Single frame capture
/// try service.captureFrame(
///     frame: videoFrame,
///     toFile: "/path/to/capture.png",
///     format: .png
/// )
///
/// // Capture with metadata included
/// try service.captureWithOverlay(
///     frame: videoFrame,
///     metadata: "2024-01-15 14:30:25",
///     toFile: "/path/to/capture.png"
/// )
/// ```
class FrameCaptureService {

    // MARK: - Types

    /// @enum ImageFormat
    /// @brief Supported image formats
    enum ImageFormat {
        case png    // Lossless compression, larger file size
        case jpeg(quality: Double)  // Lossy compression, smaller file size, quality: 0.0~1.0
    }

    /// @enum CaptureError
    /// @brief Capture-related errors
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

    /// @brief Create frame capture service.
    init() {
        // No initialization needed
    }

    // MARK: - Public Methods

    /// @brief Save video frame as image file.
    ///
    /// @param frame Video frame to capture
    /// @param toFile File path to save (Absolute path)
    /// @param format Image format (default value: PNG)
    ///
    /// @throws CaptureError
    ///
    /// @details
    /// Capture process:
    /// 1. Convert VideoFrame data to CGImage
    /// 2. Convert CGImage to NSImage
    /// 3. Encode to specified format
    /// 4. Save to file
    func captureFrame(
        frame: VideoFrame,
        toFile filePath: String,
        format: ImageFormat = .png
    ) throws {
        // 1. Convert VideoFrame to CGImage
        guard let cgImage = createCGImage(from: frame) else {
            throw CaptureError.cannotCreateImage
        }

        // 2. Convert CGImage to NSImage
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))

        // 3. Create image data
        guard let imageData = encodeImage(nsImage, format: format) else {
            throw CaptureError.cannotCreateImage
        }

        // 4. Save to file
        let url = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw CaptureError.cannotWriteFile(filePath)
        }
    }

    /// @brief Capture frame with metadata overlay.
    ///
    /// @param frame Video frame to capture
    /// @param overlayText Text to overlay (Timestamp, GPS info, etc)
    /// @param toFile File path to save
    /// @param format Image format
    ///
    /// @throws CaptureError
    ///
    /// @details
    /// Overlay location:
    /// - Bottom of screen with semi-transparent black background
    /// - Display white text info
    func captureWithOverlay(
        frame: VideoFrame,
        overlayText: String,
        toFile filePath: String,
        format: ImageFormat = .png
    ) throws {
        // 1. Convert VideoFrame to CGImage
        guard let cgImage = createCGImage(from: frame) else {
            throw CaptureError.cannotCreateImage
        }

        // 2. Convert CGImage to NSImage
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))

        // 3. Add overlay
        let overlayedImage = addOverlay(to: nsImage, text: overlayText)

        // 4. Create image data
        guard let imageData = encodeImage(overlayedImage, format: format) else {
            throw CaptureError.cannotCreateImage
        }

        // 5. Save to file
        let url = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw CaptureError.cannotWriteFile(filePath)
        }
    }

    /// @brief Capture multi-channel frames as single image.
    ///
    /// @param frames Dictionary of video frames by channel
    /// @param layout Layout (grid, horizontal)
    /// @param toFile File path to save
    /// @param format Image format
    ///
    /// @throws CaptureError
    ///
    /// @details
    /// Layout options:
    /// - grid: 2x3 grid (maximum 6 channels)
    /// - horizontal: Horizontal arrangement (1x5)
    func captureMultiChannel(
        frames: [String: VideoFrame],
        layout: ChannelLayout = .grid,
        toFile filePath: String,
        format: ImageFormat = .png
    ) throws {
        // Sort channels (consistent order)
        let sortedFrames = frames.sorted { $0.key < $1.key }.map { $0.value }

        guard !sortedFrames.isEmpty else {
            throw CaptureError.invalidFrame
        }

        // Composite according to layout
        let compositeImage: NSImage
        switch layout {
        case .grid:
            compositeImage = createGridImage(frames: sortedFrames)
        case .horizontal:
            compositeImage = createHorizontalImage(frames: sortedFrames)
        }

        // Create image data
        guard let imageData = encodeImage(compositeImage, format: format) else {
            throw CaptureError.cannotCreateImage
        }

        // Save to file
        let url = URL(fileURLWithPath: filePath)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw CaptureError.cannotWriteFile(filePath)
        }
    }

    // MARK: - Private Methods

    /// @brief Convert VideoFrame to CGImage.
    ///
    /// @param frame Video frame
    ///
    /// @return CGImage, or nil on failure
    ///
    /// @details
    /// Convert VideoFrame's BGRA data to CGImage.
    private func createCGImage(from frame: VideoFrame) -> CGImage? {
        let width = frame.width
        let height = frame.height
        let data = frame.data

        // Convert Data to CFData
        let cfData = data as CFData

        // Create Data Provider
        guard let dataProvider = CGDataProvider(data: cfData) else {
            return nil
        }

        // Create Color Space (sRGB)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        // Create CGImage
        // BGRA format (VideoDecoder output format)
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

    /// @brief Encode NSImage to specified format
    ///
    /// @param image NSImage instance
    /// @param format Image format
    ///
    /// @return Encoded image data, or nil on failure
    private func encodeImage(_ image: NSImage, format: ImageFormat) -> Data? {
        // Convert NSImage to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Create NSBitmapImageRep
        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        // Encode according to format
        switch format {
        case .png:
            return bitmap.representation(using: .png, properties: [:])
        case .jpeg(let quality):
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
    }

    /// @brief Add text overlay to image
    ///
    /// @param image Original image
    /// @param text Text to overlay
    ///
    /// @return Image with overlay added
    private func addOverlay(to image: NSImage, text: String) -> NSImage {
        let size = image.size

        // Create new image (same size as original)
        let newImage = NSImage(size: size)
        newImage.lockFocus()

        // Draw original image
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)

        // Background rectangle (bottom, semi-transparent black)
        let bgHeight: CGFloat = 40
        let bgRect = NSRect(x: 0, y: 0, width: size.width, height: bgHeight)
        NSColor.black.withAlphaComponent(0.7).setFill()
        bgRect.fill()

        // Text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        // Draw text
        let textRect = NSRect(x: 0, y: 10, width: size.width, height: 20)
        (text as NSString).draw(in: textRect, withAttributes: attributes)

        newImage.unlockFocus()

        return newImage
    }

    /// @brief Compose frames in grid layout
    ///
    /// @param frames frame array
    ///
    /// @return Composed image
    ///
    /// @details
    /// 2x3 grid (maximum 6 channels)
    private func createGridImage(frames: [VideoFrame]) -> NSImage {
        // Use first frame's size as reference
        let frameWidth = frames.first?.width ?? 1920
        let frameHeight = frames.first?.height ?? 1080

        // 2x3 grid
        let cols = 3
        let rows = 2
        let totalWidth = frameWidth * cols
        let totalHeight = frameHeight * rows

        // Create new image
        let compositeImage = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        compositeImage.lockFocus()

        // Arrange each frame
        for (index, frame) in frames.prefix(6).enumerated() {
            let row = index / cols
            let col = index % cols

            let x = col * frameWidth
            let y = (rows - 1 - row) * frameHeight  // Top to bottom

            if let cgImage = createCGImage(from: frame) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))
                let rect = NSRect(x: x, y: y, width: frameWidth, height: frameHeight)
                nsImage.draw(in: rect)
            }
        }

        compositeImage.unlockFocus()

        return compositeImage
    }

    /// @brief Compose frames in horizontal layout
    ///
    /// @param frames frame array
    ///
    /// @return Composed image
    ///
    /// @details
    /// 1x5 horizontal arrangement
    private func createHorizontalImage(frames: [VideoFrame]) -> NSImage {
        let frameWidth = frames.first?.width ?? 1920
        let frameHeight = frames.first?.height ?? 1080

        let count = min(frames.count, 5)
        let totalWidth = frameWidth * count
        let totalHeight = frameHeight

        // Create new image
        let compositeImage = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        compositeImage.lockFocus()

        // Arrange each frame
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
/// @brief Multi-channel layout
enum ChannelLayout {
    case grid        // 2x3 grid
    case horizontal  // 1x5 horizontal
}
