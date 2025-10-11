//
//  VideoFrame.swift
//  BlackboxPlayer
//
//  Model for decoded video frame
//

import Foundation
import CoreGraphics
import CoreVideo

/// Decoded video frame with pixel data
struct VideoFrame {
    /// Presentation timestamp in seconds
    let timestamp: TimeInterval

    /// Frame width in pixels
    let width: Int

    /// Frame height in pixels
    let height: Int

    /// Pixel format
    let pixelFormat: PixelFormat

    /// Raw pixel data (RGB or YUV)
    let data: Data

    /// Line size (bytes per row)
    let lineSize: Int

    /// Frame number (0-indexed)
    let frameNumber: Int

    /// Whether this is a keyframe (I-frame)
    let isKeyFrame: Bool

    // MARK: - Initialization

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

    /// Aspect ratio (width / height)
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    /// Total size in bytes
    var dataSize: Int {
        return data.count
    }

    // MARK: - Image Conversion

    /// Convert to CGImage for display
    /// - Returns: CGImage or nil if conversion fails
    func toCGImage() -> CGImage? {
        guard pixelFormat == .rgb24 || pixelFormat == .rgba else {
            return nil
        }

        let bitsPerComponent = 8
        let bitsPerPixel = pixelFormat == .rgb24 ? 24 : 32
        let bytesPerRow = lineSize

        guard let dataProvider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = pixelFormat == .rgba ?
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue) :
            CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

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
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    /// Convert to CVPixelBuffer for Metal rendering
    /// - Returns: CVPixelBuffer or nil if conversion fails
    func toPixelBuffer() -> CVPixelBuffer? {
        let pixelFormatType: OSType
        switch pixelFormat {
        case .rgb24:
            pixelFormatType = kCVPixelFormatType_24RGB
        case .rgba:
            // Use BGRA for Metal compatibility (our decoder outputs BGRA as "RGBA")
            pixelFormatType = kCVPixelFormatType_32BGRA
        case .yuv420p:
            pixelFormatType = kCVPixelFormatType_420YpCbCr8Planar
        case .nv12:
            pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }

        // Create attributes for Metal compatibility
        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

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

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        // Copy pixel data row by row to handle stride differences
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let srcBytesPerRow = lineSize
            let minBytesPerRow = min(destBytesPerRow, srcBytesPerRow)

            data.withUnsafeBytes { dataBytes in
                if let sourcePtr = dataBytes.baseAddress {
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

/// Pixel format for decoded frames
enum PixelFormat: String, Codable {
    /// RGB 24-bit (8 bits per channel, no alpha)
    case rgb24 = "rgb24"

    /// RGBA 32-bit (8 bits per channel with alpha)
    case rgba = "rgba"

    /// YUV 4:2:0 planar format
    case yuv420p = "yuv420p"

    /// NV12 semi-planar format (used by hardware decoders)
    case nv12 = "nv12"

    var bytesPerPixel: Int {
        switch self {
        case .rgb24:
            return 3
        case .rgba:
            return 4
        case .yuv420p, .nv12:
            return 1  // Planar format, varies by plane
        }
    }
}

// MARK: - Equatable

extension VideoFrame: Equatable {
    static func == (lhs: VideoFrame, rhs: VideoFrame) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.frameNumber == rhs.frameNumber &&
               lhs.width == rhs.width &&
               lhs.height == rhs.height
    }
}

// MARK: - CustomStringConvertible

extension VideoFrame: CustomStringConvertible {
    var description: String {
        let keyframeStr = isKeyFrame ? "K" : " "
        return String(format: "[%@] Frame #%d @ %.3fs (%dx%d %@) %d bytes",
                     keyframeStr, frameNumber, timestamp, width, height,
                     pixelFormat.rawValue, dataSize)
    }
}
