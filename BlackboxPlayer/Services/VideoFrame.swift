/// @file VideoFrame.swift
/// @brief Decoded video frame data model
/// @author BlackboxPlayer Development Team
/// @details
/// A structure containing raw video frame (pixel data) decoded from FFmpeg.
/// When compressed video (H.264, etc.) is decoded, raw pixel data in RGB or YUV format is generated,
/// which is managed per frame.
///
/// [Purpose of this file]
/// A structure containing raw video frame (pixel data) decoded from FFmpeg.
/// When compressed video (H.264, etc.) is decoded, raw pixel data in RGB or YUV format is generated,
/// which is managed per frame.
///
/// [What is a video frame?]
/// A single image of a video:
/// - Movies: 24 fps (24 frames per second)
/// - TV/Video: 30 fps (30 frames per second)
/// - Dashcam: typically 30 fps
///
/// [Data flow]
/// 1. VideoDecoder decodes H.264 with FFmpeg → raw pixel data generated
/// 2. VideoFrame structure stores pixel data + metadata
/// 3. MultiChannelRenderer converts VideoFrame to CVPixelBuffer
/// 4. Metal GPU renders to screen
///
/// H.264 file (compressed) → FFmpeg decoding → VideoFrame (raw pixels) → CVPixelBuffer → Metal → 🖥️ Screen
///

import Foundation
import CoreGraphics
import CoreVideo

// MARK: - VideoFrame Structure

/// @struct VideoFrame
/// @brief Decoded video frame (raw pixel data)
///
/// @details
/// A structure wrapping raw video data decoded from FFmpeg for easy handling in Swift.
///
/// ## Usage Example
/// ```swift
/// // Create video frame decoded from FFmpeg
/// let frame = VideoFrame(
///     timestamp: 1.5,           // 1.5 second position in video
///     width: 1920,              // Full HD width
///     height: 1080,             // Full HD height
///     pixelFormat: .rgba,       // RGBA 32-bit color
///     data: pixelData,          // Actual pixel bytes
///     lineSize: 1920 * 4,       // Bytes per row (1920 × 4)
///     frameNumber: 45,          // 45th frame
///     isKeyFrame: true          // I-frame (keyframe)
/// )
///
/// // Convert to CVPixelBuffer for Metal rendering
/// if let pixelBuffer = frame.toPixelBuffer() {
///     renderer.render(pixelBuffer)
/// }
/// ```
///
/// ## RGB vs YUV Pixel Formats
///
/// **RGB (Red, Green, Blue)**:
/// - Computer graphics standard
/// - Pixel = (R, G, B) or (R, G, B, A)
/// - Intuitive and easy to process
/// - Uses more memory
///
/// **YUV (Luma, Chroma)**:
/// - Video compression standard (H.264, H.265)
/// - Y = brightness, U/V = color
/// - Memory savings through color subsampling (4:2:0 = 50% reduction)
/// - Requires RGB conversion after decoding
struct VideoFrame {
    // MARK: - Properties

    /// @var timestamp
    /// @brief Presentation timestamp (in seconds)
    ///
    /// @details
    /// The time at which this video frame should be played.
    /// Used for synchronization with audio frames.
    ///
    /// **Examples**:
    /// - timestamp = 0.000s (first frame)
    /// - timestamp = 0.033s (second frame at 30fps)
    /// - timestamp = 1.000s (1 second mark)
    let timestamp: TimeInterval

    /// @var width
    /// @brief Frame width (in pixels)
    ///
    /// @details
    /// **Common resolutions**:
    /// - 640 × 480: VGA (legacy)
    /// - 1280 × 720: HD (720p)
    /// - 1920 × 1080: Full HD (1080p) ⭐ Dashcam standard
    /// - 3840 × 2160: 4K UHD
    let width: Int

    /// @var height
    /// @brief Frame height (in pixels)
    let height: Int

    /// @var pixelFormat
    /// @brief Pixel format (RGB, RGBA, YUV, etc.)
    ///
    /// @details
    /// Defines the format in which pixel data is stored in memory.
    ///
    /// **Impact of format choice**:
    /// ```
    /// RGB24 (1920×1080):  1920 × 1080 × 3 = 6,220,800 bytes (6.2MB)
    /// RGBA (1920×1080):   1920 × 1080 × 4 = 8,294,400 bytes (8.3MB)
    /// YUV420p (1920×1080): 1920 × 1080 × 1.5 = 3,110,400 bytes (3.1MB) ← 50% savings!
    /// ```
    let pixelFormat: PixelFormat

    /// @var data
    /// @brief Raw pixel data (byte array)
    ///
    /// @details
    /// Data containing the actual image color information in binary format.
    ///
    /// **Data structure example (RGBA, 2×2 pixels)**:
    /// ```
    /// Pixel layout:
    /// [Pixel(0,0)][Pixel(1,0)]
    /// [Pixel(0,1)][Pixel(1,1)]
    ///
    /// Memory layout (RGBA):
    /// [R0 G0 B0 A0][R1 G1 B1 A1][R2 G2 B2 A2][R3 G3 B3 A3]
    ///  Pixel(0,0)   Pixel(1,0)   Pixel(0,1)   Pixel(1,1)
    ///
    /// Total 16 bytes (4 pixels × 4 bytes)
    /// ```
    ///
    /// This Data is populated during FFmpeg decoding.
    let data: Data

    /// @var lineSize
    /// @brief Line size (bytes per row)
    ///
    /// @details
    /// The number of bytes used to store one line (row) of the image.
    /// May be larger than actual pixel data due to memory alignment.
    ///
    /// **Calculation**:
    /// ```
    /// Theoretical size: width × bytesPerPixel
    /// Actual size: lineSize (including alignment padding)
    ///
    /// Example (1920×1080 RGBA):
    /// Theoretical: 1920 × 4 = 7,680 bytes
    /// Actual: 7,680 bytes (or 7,696 bytes with padding)
    /// ```
    ///
    /// **Why the difference?**
    /// CPUs/GPUs read memory more efficiently in 16-byte or 32-byte units.
    /// Therefore, padding is added to make row size a multiple of 16.
    let lineSize: Int

    /// @var frameNumber
    /// @brief Frame number (starting from 0)
    ///
    /// @details
    /// The sequential order from the beginning of the video.
    ///
    /// **Examples**:
    /// - frameNumber = 0: first frame
    /// - frameNumber = 30: 1 second mark in 30fps video
    /// - frameNumber = 900: 30 second mark in 30fps video
    let frameNumber: Int

    /// @var isKeyFrame
    /// @brief Whether this is a keyframe (I-frame)
    ///
    /// @details
    /// **Video compression frame types**:
    /// ```
    /// I-Frame (Intra-frame, keyframe):
    /// - Complete image (independent)
    /// - Large size (100~200KB)
    /// - Seek starting point
    ///
    /// P-Frame (Predicted frame):
    /// - Only stores differences from previous frame
    /// - Smaller size (10~50KB)
    /// - Cannot be decoded without I-Frame
    ///
    /// B-Frame (Bidirectional frame):
    /// - References both previous and next frames
    /// - Very small size (5~20KB)
    /// - Most complex decoding
    /// ```
    ///
    /// **GOP (Group of Pictures) structure example**:
    /// ```
    /// I P P P P P P P P P I P P P P P P P P P I ...
    /// ↑ keyframe     ↑ keyframe     ↑ keyframe
    /// └─ GOP 1 ──────┘ └─ GOP 2 ──────┘
    /// ```
    ///
    /// **Seek operation**:
    /// - User requests seek to 30 seconds
    /// - Find nearest I-Frame before 30 seconds (e.g., 28 seconds)
    /// - Start decoding from 28-second I-Frame
    /// - Decode P/B-Frames up to 30 seconds
    let isKeyFrame: Bool

    // MARK: - Initialization

    /// @brief VideoFrame initialization
    ///
    /// @details
    /// Creates a VideoFrame from pixel data decoded by FFmpeg.
    /// Typically called from within VideoDecoder.
    ///
    /// @param timestamp Presentation timestamp (in seconds)
    /// @param width Frame width (pixels)
    /// @param height Frame height (pixels)
    /// @param pixelFormat Pixel format
    /// @param data Raw pixel data
    /// @param lineSize Bytes per row
    /// @param frameNumber Frame number
    /// @param isKeyFrame Whether this is a keyframe
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

    /// @brief Aspect ratio (width ÷ height)
    ///
    /// @return Aspect ratio (Double)
    ///
    /// @details
    /// **Common ratios**:
    /// ```
    /// 4:3 = 1.333 (legacy TV)
    /// 16:9 = 1.777 (HD, Full HD) ⭐ modern standard
    /// 21:9 = 2.333 (cinema display)
    /// ```
    ///
    /// **Usage example**:
    /// ```swift
    /// // Display with aspect ratio preserved to fit screen
    /// let frame = videoFrame
    /// let viewAspect = view.width / view.height
    /// let frameAspect = frame.aspectRatio
    ///
    /// if frameAspect > viewAspect {
    ///     // Frame is wider → fit to width, top/bottom margins
    /// } else {
    ///     // Frame is taller → fit to height, left/right margins
    /// }
    /// ```
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    /// @brief Total byte size of pixel data
    ///
    /// @return Data size (bytes)
    ///
    /// @details
    /// **Memory usage calculation**:
    /// ```
    /// 1080p RGBA: 8.3MB per frame
    /// 30fps: 8.3MB × 30 = 249MB/sec
    /// 1 minute video: 249MB × 60 = 14.9GB!
    ///
    /// → Compression essential (H.264 compression provides hundreds of times reduction)
    /// ```
    var dataSize: Int {
        return data.count
    }

    // MARK: - Image Conversion

    /// @brief Convert to CGImage (for screen display)
    ///
    /// @return CGImage, or nil on conversion failure
    ///
    /// @details
    /// Converts RGB or RGBA pixel data to CGImage, macOS's standard image format.
    /// Can be used with AppKit (NSImage) or SwiftUI (Image).
    ///
    /// **Conversion process**:
    /// ```
    /// VideoFrame (raw pixels) → CGDataProvider → CGImage
    ///                           (memory wrapper)  (image object)
    /// ```
    ///
    /// **Supported formats**: RGB24 and RGBA only. YUV must be converted to RGB first.
    ///
    /// **Usage example**:
    /// ```swift
    /// // Display in SwiftUI
    /// if let cgImage = frame.toCGImage() {
    ///     let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))
    ///     Image(nsImage: nsImage)
    ///         .resizable()
    ///         .aspectRatio(contentMode: .fit)
    /// }
    /// ```
    func toCGImage() -> CGImage? {
        // YUV format not supported (RGB conversion required)
        guard pixelFormat == .rgb24 || pixelFormat == .rgba else {
            return nil
        }

        // Set pixel information
        let bitsPerComponent = 8  // R, G, B each 8 bits (256 levels)
        let bitsPerPixel = pixelFormat == .rgb24 ? 24 : 32  // RGB=24, RGBA=32
        let bytesPerRow = lineSize

        // Create CGDataProvider (wrap Data for CGImage to read)
        guard let dataProvider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        // Create RGB color space (sRGB)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Set alpha channel information
        let bitmapInfo: CGBitmapInfo = pixelFormat == .rgba ?
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue) :  // RGBA: has alpha
            CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)                 // RGB: no alpha

        // Create CGImage
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
            shouldInterpolate: true,      // Smooth scaling
            intent: .defaultIntent
        )
    }

    /// @brief Convert to CVPixelBuffer (for Metal GPU rendering)
    ///
    /// @return CVPixelBuffer, or nil on conversion failure
    ///
    /// @details
    /// Converts to CVPixelBuffer format that Metal GPU can use directly.
    /// Compatible with GPU memory and enables zero-copy rendering.
    ///
    /// **What is CVPixelBuffer?**
    /// - Core Video's pixel buffer type
    /// - Can be shared directly with GPU memory
    /// - Compatible with Metal and AVFoundation
    /// - IOSurface-based (can be shared between processes)
    ///
    /// **Zero-copy rendering**:
    /// ```
    /// Traditional approach:
    /// Data → copy → Texture → GPU
    ///          ↑ memory copy (slow)
    ///
    /// CVPixelBuffer approach:
    /// Data → CVPixelBuffer ← Metal Texture
    ///            ↑ shared memory (fast)
    /// ```
    ///
    /// **Metal integration**:
    /// ```swift
    /// // CVPixelBuffer → Metal Texture conversion
    /// if let pixelBuffer = frame.toPixelBuffer() {
    ///     let texture = textureCache.createTexture(from: pixelBuffer)
    ///     metalRenderer.render(texture)
    /// }
    /// ```
    func toPixelBuffer() -> CVPixelBuffer? {
        // Step 1: Map pixel format
        let pixelFormatType: OSType
        switch pixelFormat {
        case .rgb24:
            pixelFormatType = kCVPixelFormatType_24RGB
        case .rgba:
            // Use BGRA for Metal compatibility
            // FFmpeg outputs as RGBA but actual order is BGRA
            pixelFormatType = kCVPixelFormatType_32BGRA
        case .yuv420p:
            pixelFormatType = kCVPixelFormatType_420YpCbCr8Planar
        case .nv12:
            pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }

        // Step 2: Set Metal-compatible attributes
        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,    // Metal usage enabled
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary  // Inter-process sharing enabled
        ]

        // Step 3: Create CVPixelBuffer
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

        // Step 4: Copy pixel data
        // Lock: Block GPU access while CPU writes to buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }  // Auto unlock

        // Copy row by row (handle stride differences)
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let destBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)  // CVPixelBuffer's stride
            let srcBytesPerRow = lineSize                                // Source data's stride
            let minBytesPerRow = min(destBytesPerRow, srcBytesPerRow)  // Actual size to copy

            data.withUnsafeBytes { dataBytes in
                if let sourcePtr = dataBytes.baseAddress {
                    // Copy each row individually (due to stride differences)
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
/// @brief Pixel format definitions
///
/// @details
/// Defines how pixel data is stored in memory.
///
/// ## RGB vs YUV Comparison
///
/// **RGB (Red, Green, Blue)**:
/// ```
/// Advantages:
/// ✅ Intuitive (computer monitor format)
/// ✅ Simple processing
/// ✅ Independent per pixel
///
/// Disadvantages:
/// ❌ High memory usage
/// ❌ Low compression efficiency
///
/// Use cases: Computer graphics, photo editing
/// ```
///
/// **YUV (Luma + Chroma)**:
/// ```
/// Advantages:
/// ✅ Memory savings (4:2:0 = 50% reduction)
/// ✅ High compression efficiency
/// ✅ Video standard (H.264, H.265)
///
/// Disadvantages:
/// ❌ Requires RGB conversion
/// ❌ Precision loss from color subsampling
///
/// Use cases: Video compression, broadcasting
/// ```
///
/// ## 4:2:0 Subsampling
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
/// 24 samples (50%) ← Reduced to half!
/// ```
enum PixelFormat: String, Codable {
    /// @brief RGB 24-bit (no alpha)
    ///
    /// @details
    /// **Structure**: [R G B][R G B][R G B]...
    /// - R: Red (0~255)
    /// - G: Green (0~255)
    /// - B: Blue (0~255)
    ///
    /// **Memory**: width × height × 3 bytes
    /// Example: 1920×1080 = 6.2MB per frame
    case rgb24 = "rgb24"

    /// @brief RGBA 32-bit (with alpha)
    ///
    /// @details
    /// **Structure**: [R G B A][R G B A][R G B A]...
    /// - R, G, B: Color (0~255)
    /// - A: Transparency (0=transparent, 255=opaque)
    ///
    /// **Memory**: width × height × 4 bytes
    /// Example: 1920×1080 = 8.3MB per frame
    case rgba = "rgba"

    /// @brief YUV 4:2:0 Planar (standard video format)
    ///
    /// @details
    /// **Structure**: [Y plane][U plane][V plane]
    /// - Y: Brightness information (full resolution)
    /// - U: Blue-brightness difference (1/4 resolution)
    /// - V: Red-brightness difference (1/4 resolution)
    ///
    /// **Memory**: width × height × 1.5 bytes
    /// Example: 1920×1080 = 3.1MB per frame (50% of RGB)
    ///
    /// **H.264 standard format**
    case yuv420p = "yuv420p"

    /// @brief NV12 Semi-Planar (used by hardware decoders)
    ///
    /// @details
    /// **Structure**: [Y plane][UV interleaved plane]
    /// - Y: Brightness information (full resolution)
    /// - UV: U and V interleaved (UVUVUV...)
    ///
    /// **Memory**: width × height × 1.5 bytes
    ///
    /// **Feature**: Preferred format for GPU hardware decoders
    case nv12 = "nv12"

    /// @brief Bytes per pixel
    ///
    /// @return Byte size
    ///
    /// @details
    /// **Note**: YUV varies per pixel due to subsampling.
    /// Returns Luma plane basis (1) instead of average (1.5).
    var bytesPerPixel: Int {
        switch self {
        case .rgb24:
            return 3  // RGB
        case .rgba:
            return 4  // RGBA
        case .yuv420p, .nv12:
            return 1  // Y plane only (U/V are subsampled)
        }
    }
}

// MARK: - Equatable

/// @brief VideoFrame equality comparison
///
/// @details
/// Determines whether two VideoFrames are "the same" frame.
/// Primarily used for debugging, testing, and deduplication.
///
/// **Comparison criteria**:
/// - timestamp: Same time point?
/// - frameNumber: Same frame number?
/// - width, height: Same dimensions?
///
/// **Note**: `data` is NOT compared! (for performance reasons)
extension VideoFrame: Equatable {
    /// @brief Compare two VideoFrames
    /// @param lhs Left operand
    /// @param rhs Right operand
    /// @return true if equal
    static func == (lhs: VideoFrame, rhs: VideoFrame) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
            lhs.frameNumber == rhs.frameNumber &&
            lhs.width == rhs.width &&
            lhs.height == rhs.height
    }
}

// MARK: - CustomStringConvertible

/// @brief VideoFrame debug string representation
///
/// @details
/// **Output example**:
/// ```
/// [K] Frame #0 @ 0.000s (1920x1080 rgba) 8294400 bytes
/// [ ] Frame #1 @ 0.033s (1920x1080 rgba) 8294400 bytes
/// [ ] Frame #2 @ 0.067s (1920x1080 rgba) 8294400 bytes
/// [K] Frame #30 @ 1.000s (1920x1080 rgba) 8294400 bytes
///
/// [K] = Keyframe (I-Frame)
/// [ ] = P/B-Frame
/// ```
extension VideoFrame: CustomStringConvertible {
    /// @brief Debug string
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
// Integration Guide: VideoFrame Usage Flow
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ Decoding (VideoDecoder)
// ────────────────────────────────────────────────
// H.264 file → FFmpeg decoding → pixel data
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
// 2️⃣ Queuing (VideoChannel)
// ────────────────────────────────────────────────
// Store decoded frames in buffer
//
// videoBuffer.append(videoFrame)
//
// 3️⃣ Synchronization (SyncController)
// ────────────────────────────────────────────────
// Compare timestamps with audio frames
//
// if abs(videoFrame.timestamp - audioFrame.timestamp) < 0.05 {
//     // Sync OK (within ±50ms)
// }
//
// 4️⃣ Rendering (MultiChannelRenderer)
// ────────────────────────────────────────────────
// Convert to CVPixelBuffer then Metal GPU rendering
//
// if let pixelBuffer = videoFrame.toPixelBuffer() {
//     let texture = textureCache.createTexture(from: pixelBuffer)
//     metalRenderer.draw(texture)
// }
//
// 5️⃣ Screen Output
// ────────────────────────────────────────────────
// Metal → CAMetalLayer → 🖥️ Display
//
// ═══════════════════════════════════════════════════════════════════════════
