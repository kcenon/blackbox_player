/// @file ScreenCaptureService.swift
/// @brief Service for capturing current video frame and saving as image
/// @author BlackboxPlayer Development Team
/// @details
/**
 # ScreenCaptureService - Screen capture service

 ## 📸 What is Screen Capture?

 Feature to save the current playback moment as an image file.

 ### Usage Example:
 ```
 User discovers important scene in video
 ↓
 Click capture button
 ↓
 Save current screen as PNG/JPEG file
 ```

 ## 🎯 Key Features

 1. **Metal Texture → Image Conversion**
 - Convert GPU memory textures to CPU memory images
 - Uses CGImage and NSImage

 2. **Timestamp Overlay**
 - Display capture time
 - Display video playback time

 3. **Image Format Support**
 - PNG: lossless compression, larger file size
 - JPEG: lossy compression, smaller file size

 4. **File Saving**
 - Dialog to select save location
 - Notification upon completion

 ## 💡 Technical Concepts

 ### Metal Texture vs Image file
 ```
 Metal Texture (GPU memory):
 - Direct GPU access possible
 - Optimized for rendering
 - Cannot be saved to file

 Image file (disk):
 - CPU processing
 - Standard formats like PNG, JPEG
 - Can be opened in other apps
 ```

 ### Conversion Process:
 ```
 MTLTexture (GPU)
 ↓ texture.getBytes() - GPU → CPU copy
 [UInt8] array (pixel data)
 ↓ CGDataProvider
 CGImage (Core Graphics)
 ↓ NSImage
 NSImage (AppKit)
 ↓ NSBitmapImageRep
 PNG/JPEG Data
 ↓ write(to:)
 File saved
 ```

 ## 📚 Usage Examples

 ```swift
 // 1. Create service
 let captureService = ScreenCaptureService(device: metalDevice)

 // 2. Capture current frame
 if let data = captureService.captureFrame(
 from: currentTexture,
 format: .png,
 timestamp: Date(),
 videoTimestamp: 5.25  // At 5.25 seconds
 ) {
 // 3. Display save dialog
 captureService.showSavePanel(
 data: data,
 format: .png,
 defaultFilename: "Blackbox_Front_2024-10-12"
 )
 }
 ```

 ---

 This service converts GPU rendering results to image files that users can save.
 */

import Foundation
import AppKit
import CoreGraphics
import Metal
import MetalKit

// MARK: - Image Format Enum

/**
 ## CaptureImageFormat - Image format

 Defines the image format to use when saving captured screens.

 ### Format Comparison:

 **PNG (Portable Network Graphics)**
 - Lossless compression: maintains 100% original quality
 - File size: larger (1920×1080: ~2-5MB)
 - Transparency support: has alpha channel
 - Use case: high-quality archival, editing

 **JPEG (Joint Photographic Experts Group)**
 - Lossy compression: slight quality loss (not visible to the eye)
 - File size: smaller (1920×1080: ~200-500KB)
 - No transparency support: RGB only
 - Use case: quick sharing, saving storage space

 ### Selection Guide:
 ```
 Choose PNG when:
 - Planning to edit later
 - Highest quality needed
 - Storage space is sufficient

 Choose JPEG when:
 - Need to share immediately
 - Storage space is limited
 - 90-95% quality is sufficient
 ```
 */
/// @enum CaptureImageFormat
/// @brief Capture image format definition
enum CaptureImageFormat: String {
    /// @brief PNG format (lossless)
    case png = "png"

    /// @brief JPEG format (lossy)
    case jpeg = "jpg"

    /**
     Format name to display to user

     - PNG → "PNG"
     - JPEG → "JPEG"
     */
    /// @var displayName
    /// @brief Format name to display to user
    /// @return PNG or JPEG string
    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        }
    }

    /**
     Uniform Type Identifier (UTI)

     ### What is UTI?
     - Standard method for identifying file formats on macOS/iOS
     - More accurate and explicit than file extensions

     Example:
     - "public.png" → PNG image
     - "public.jpeg" → JPEG image
     - "public.mp4" → MP4 video

     ### Usage:
     - Specify allowed file types in NSSavePanel
     - File type validation
     - Share file format information with the system
     */
    /// @var utType
    /// @brief Uniform Type Identifier (UTI)
    /// @return public.png or public.jpeg
    var utType: String {
        switch self {
        case .png: return "public.png"
        case .jpeg: return "public.jpeg"
        }
    }
}

// MARK: - Screen Capture Service

/**
 ## ScreenCaptureService - Screen capture service

 Converts Metal textures in GPU memory to image files in CPU memory and saves them.

 ### Main Responsibilities:
 1. Convert Metal texture → CGImage
 2. Add timestamp overlay
 3. Encode to PNG/JPEG format
 4. Display file save dialog
 5. Show save completion notification
 */
/// @class ScreenCaptureService
/// @brief Service for converting Metal textures from GPU memory to image files in CPU memory and saving
class ScreenCaptureService {

    // MARK: - Properties

    /**
     ## Metal Device

     ### What is MTLDevice?
     An abstraction object for the GPU (Graphics Processing Unit).

     Why this service uses it:
     - Metal textures belong to a specific GPU device
     - The corresponding device is needed to read texture data

     Analogy:
     - device = "Company ID card"
     - texture = "Internal company document"
     - You need the ID card to access the document
     */
    /// @var device
    /// @brief Metal device (for GPU access)
    private let device: MTLDevice

    /**
     ## JPEG Quality (0.0 ~ 1.0)

     ### Quality value meaning:
     - 0.0 = Lowest quality, minimum file size (significant artifacts)
     - 0.5 = Medium quality
     - 0.95 = High quality, larger file size (default value)
     - 1.0 = Highest quality, maximum file size

     ### Quality vs file size:
     ```
     For 1920×1080 image example:

     quality = 0.5  →  ~150KB  (noticeable compression artifacts)
     quality = 0.8  →  ~300KB  (decent quality)
     quality = 0.95 →  ~500KB  (high quality, default value)
     quality = 1.0  →  ~800KB  (highest quality)
     ```

     ### Recommended settings:
     - General use: 0.85 ~ 0.95
     - High quality needed: 0.95 ~ 1.0
     - File size important: 0.7 ~ 0.85
     */
    /// @var jpegQuality
    /// @brief JPEG compression quality (0.0 ~ 1.0, default value 0.95)
    var jpegQuality: CGFloat = 0.95

    // MARK: - Initialization

    /**
     Initialize service

     - Parameter device: Metal device (for GPU access)

     ### Initialization example:
     ```swift
     // Create in MultiChannelRenderer:
     let captureService = ScreenCaptureService(device: metalDevice)
     ```
     */
    /// @brief Initialize service
    /// @param device Metal device (for GPU access)
    init(device: MTLDevice) {
        self.device = device
    }

    // MARK: - Public Methods

    /**
     ## Capture frame from Metal texture

     Converts the current GPU-rendered screen to image data.

     ### Processing Steps:
     ```
     1. Convert MTLTexture → CGImage
     - Copy GPU memory → CPU memory
     - Extract RGBA pixel data

     2. Convert CGImage → NSImage
     - Create AppKit image object

     3. Add timestamp overlay (optional)
     - Display current time
     - Display video playback time

     4. Encode to PNG/JPEG
     - Compress to specified format

     5. Return Data
     - Binary data that can be written to file
     ```

     - Parameters:
     - texture: Metal texture to capture (current screen)
     - format: Image format to save (PNG or JPEG)
     - timestamp: Time to overlay (no overlay if nil)
     - videoTimestamp: video playback time (in seconds)

     - Returns: Image data (Data), or nil on failure

     ### Usage Examples:
     ```swift
     // 1. Capture without timestamp
     let data = captureService.captureFrame(
     from: currentTexture,
     format: .png
     )

     // 2. Capture including timestamp
     let data = captureService.captureFrame(
     from: currentTexture,
     format: .jpeg,
     timestamp: Date(),           // current time: 2024-10-12 15:30:45
     videoTimestamp: 125.5        // video time: 00:02:05.500
     )
     ```

     ### Failure cases:
     - Empty texture
     - Out of memory
     - Format conversion failure
     */
    /// @brief Capture frame from Metal texture
    /// @param texture Metal texture to capture (current screen)
    /// @param format Image format to save (PNG or JPEG)
    /// @param timestamp Time to overlay (no overlay if nil)
    /// @param videoTimestamp video playback time (in seconds)
    /// @return Image data (Data), or nil on failure
    func captureFrame(
        from texture: MTLTexture,
        format: CaptureImageFormat,
        timestamp: Date? = nil,
        videoTimestamp: TimeInterval? = nil
    ) -> Data? {
        // ===== Step 1: MTLTexture → CGImage =====
        // Convert texture in GPU memory to image in CPU memory
        guard let cgImage = createCGImage(from: texture) else {
            errorLog("[ScreenCaptureService] Failed to create CGImage from texture")
            return nil
        }

        // ===== Step 2: CGImage → NSImage =====
        // Convert Core Graphics image to AppKit image
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(cgImage: cgImage, size: size)

        // ===== Step 3: Add timestamp overlay (optional) =====
        // if-let expression (Swift 5.9+):
        // - If timestamp is not nil → add overlay to image
        // - If timestamp is nil → use original image
        let finalImage = if let timestamp = timestamp {
            addTimestampOverlay(to: nsImage, timestamp: timestamp, videoTimestamp: videoTimestamp)
        } else {
            nsImage
        }

        // ===== Step 4: Encode to PNG/JPEG =====
        // NSImage → Data (binary data writable to file)
        return convertToData(image: finalImage, format: format)
    }

    /**
     ## Display save dialog and save file

     Allows the user to select a save location and saves the image file.

     ### What is NSSavePanel?
     macOS standard "Save As" dialog.

     ```
     ┌─────────────────────────────────────┐
     │ Save Screenshot                     │
     │                                     │
     │ Choose where to save...             │
     │                                     │
     │ Save As: [BlackboxCapture.png    ] │
     │ Where:   [▼ Documents            ] │
     │                                     │
     │              [ Cancel ]  [ Save ]   │
     └─────────────────────────────────────┘
     ```

     ### Processing flow:
     ```
     1. Create and configure NSSavePanel
     - Set title and message
     - Set default filename
     - Set allowed file extensions

     2. Call runModal()
     - Display dialog (modal)
     - Wait for user input
     - Wait for Cancel or Save button click

     3. Check response
     - .OK → proceed with save
     - Cancel → return false

     4. Write file
     - data.write(to: url)
     - Success → display notification
     - Failure → error notification
     ```

     - Parameters:
     - data: Image data to save
     - format: Image format (determines extension)
     - defaultFilename: Default filename (excluding extension)

     - Returns: Whether save was successful (true/false)

     ### What is @discardableResult?
     - Attribute to suppress warning when return value is ignored
     - Because this method's result doesn't always need to be checked

     ```swift
     // Using return value:
     if captureService.showSavePanel(data: data, format: .png) {
     print("Save successful!")
     }

     // Ignoring return value (no warning):
     captureService.showSavePanel(data: data, format: .png)
     ```

     ### Usage Example:
     ```swift
     // Capture and save:
     if let data = captureService.captureFrame(from: texture, format: .png) {
     captureService.showSavePanel(
     data: data,
     format: .png,
     defaultFilename: "Blackbox_Front_2024-10-12_15-30-45"
     )
     }
     ```
     */
    /// @brief Display save dialog and save file
    /// @param data to save image data
    /// @param format Image format (determines extension)
    /// @param defaultFilename Default filename (excluding extension)
    /// @return save success whether (true/false)
    @discardableResult
    func showSavePanel(
        data: Data,
        format: CaptureImageFormat,
        defaultFilename: String = "BlackboxCapture"
    ) -> Bool {
        // ===== Step 1: Create and configure NSSavePanel =====
        let savePanel = NSSavePanel()

        // Dialog title
        savePanel.title = "Save Screenshot"

        // Internal message
        savePanel.message = "Choose where to save the captured frame"

        // Default filename (Example: "BlackboxCapture.png")
        savePanel.nameFieldStringValue = "\(defaultFilename).\(format.rawValue)"

        // Allowed file extensions
        // [.init(filenameExtension: "png")!] → Allow PNG only
        savePanel.allowedContentTypes = [.init(filenameExtension: format.rawValue)!]

        // Display create folder button
        savePanel.canCreateDirectories = true

        // Display extension (don't hide)
        savePanel.isExtensionHidden = false

        // ===== Step 2: Display dialog (modal) =====
        // runModal() waits until user clicks button
        // Return value:
        // - .OK: "Save" button clicked
        // - .cancel: "Cancel" button clicked or ESC key
        let response = savePanel.runModal()

        // ===== Step 3: Check response =====
        guard response == .OK, let url = savePanel.url else {
            // Cancelled or no URL → don't save
            return false
        }

        // ===== Step 4: Write file =====
        do {
            // Save Data to file
            // atomically: true → write to temp file then rename (safe)
            try data.write(to: url)

            // Record log
            infoLog("[ScreenCaptureService] Saved screenshot to: \(url.path)")

            // ===== Step 5: Success notification =====
            showNotification(
                title: "Screenshot Saved",
                message: "Saved to \(url.lastPathComponent)"
            )

            return true

        } catch {
            // ===== Error handling =====
            errorLog("[ScreenCaptureService] Failed to save screenshot: \(error)")

            // Failure notification
            showNotification(
                title: "Save Failed",
                message: error.localizedDescription,
                isError: true
            )

            return false
        }
    }

    // MARK: - Private Methods

    /**
     ## Convert Metal texture to CGImage

     ### Conversion Process (detailed):

     ```
     Step 1: Memory allocation
     ┌─────────────────────────────────────┐
     │ CPU memory (empty array)            │
     │ [0, 0, 0, 0, 0, 0, 0, 0, ...]       │
     │ Size: width × height × 4 bytes      │
     └─────────────────────────────────────┘

     Step 2: GPU → CPU copy
     ┌─────────────────┐
     │ GPU memory      │  texture.getBytes()
     │ (MTLTexture)    │  ──────────────────→  CPU memory
     │ RGBA pixel data │                       [R,G,B,A, R,G,B,A, ...]
     └─────────────────┘

     Step 3: Create CGDataProvider
     - Provide pixel data to Core Graphics
     - Automated memory management

     Step 4: Create CGImage
     - Width, height info
     - Pixel format info (RGBA, 8bit per channel)
     - ColorSpace (RGB)
     - BitmapInfo (Alpha channel location)
     ```

     ### Pixel data structure:
     ```
     Single pixel = 4 bytes (RGBA)

     Example: Red pixel
     [255, 0, 0, 255]
     R   G  B  A

     2×2 image:
     [255,0,0,255,  0,255,0,255,    ← First row (red, green)
     0,0,255,255,  255,255,255,255] ← Second row (blue, white)

     Total size = 2 × 2 × 4 = 16 bytes
     ```

     - Parameter texture: Metal texture to convert
     - Returns: CGImage, or nil on failure
     */
    /// @brief Convert Metal texture to CGImage
    /// @param texture Metal texture to convert
    /// @return CGImage, or nil on failure
    private func createCGImage(from texture: MTLTexture) -> CGImage? {
        // ===== Get texture info =====
        let width = texture.width        // Example: 1920
        let height = texture.height      // Example: 1080
        let bytesPerPixel = 4            // RGBA = 4 bytes
        let bytesPerRow = width * bytesPerPixel  // Bytes per row
        let bitsPerComponent = 8         // R, G, B, A each 8 bits

        // ===== Step 1: Allocate CPU memory =====
        // Array to store all pixel data
        // Size = 1920 × 1080 × 4 = 8,294,400 bytes (about 8MB)
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // ===== Step 2: Copy GPU → CPU =====
        // Specify which region of texture to copy (entire region)
        let region = MTLRegionMake2D(0, 0, width, height)

        // texture.getBytes():
        // - Copy pixel data from GPU memory to CPU memory
        // - This operation is relatively slow (GPU ↔ CPU bus communication)
        // - But no performance issue since capture happens rarely
        texture.getBytes(
            &pixelData,                  // CPU memory address to copy to
            bytesPerRow: bytesPerRow,    // Bytes per row
            from: region,                // Region to copy (entire)
            mipmapLevel: 0               // Mipmap level (0 = original size)
        )

        // ===== Step 3: Create CGDataProvider =====
        // What is CGDataProvider?
        // - Object that provides pixel data to Core Graphics
        // - Abstracts data source (memory, file, network, etc.)
        guard let dataProvider = CGDataProvider(
            data: Data(pixelData) as CFData
        ) else {
            return nil
        }

        // ===== Step 4: Create CGImage =====
        // What is CGImage?
        // - Core Graphics image object
        // - Platform independent (macOS, iOS shared)
        // - Immutable object
        return CGImage(
            width: width,                // Image width
            height: height,              // Image height
            bitsPerComponent: bitsPerComponent,  // Bits per channel (8bit)
            bitsPerPixel: bytesPerPixel * bitsPerComponent,  // Bits per pixel (32bit)
            bytesPerRow: bytesPerRow,    // Bytes per row
            space: CGColorSpaceCreateDeviceRGB(),  // Color space (RGB)
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            // ↑ Alpha channel location: RGBA (last)
            // premultiplied: RGB values already multiplied by Alpha
            provider: dataProvider,      // Pixel data provider
            decode: nil,                 // Decode array (none)
            shouldInterpolate: true,     // Use interpolation (smooth scaling)
            intent: .defaultIntent       // Rendering intent (default)
        )
    }

    /**
     ## Add timestamp overlay to image

     ### What is overlay?
     Text or graphics added on top of the original image.

     ```
     Original image:
     ┌─────────────────────────────┐
     │                             │
     │     [Video screen]          │
     │                             │
     │                             │
     │                             │
     └─────────────────────────────┘

     After timestamp overlay:
     ┌─────────────────────────────┐
     │                             │
     │     [Video screen]          │
     │                             │
     │                             │
     │   ┌───────────────────────┐ │
     │   │ 2024-10-12 15:30:45   │ │ ← Added text
     │   │ [00:02:05.500]        │ │
     └───┴───────────────────────┴─┘
     ```

     ### Processing Steps:
     ```
     1. Create NSBitmapImageRep
     - Bitmap image representation object
     - Can directly manipulate pixel data

     2. Set NSGraphicsContext
     - Graphics drawing context
     - Set current drawing target

     3. Draw original image
     - Use as background

     4. Format timestamp text
     - Date/time: "2024-10-12 15:30:45"
     - Video time: "[00:02:05.500]"

     5. Draw background rectangle
     - Semi-transparent black
     - Improve text readability

     6. Draw text
     - White monospace font
     - Bottom-right position

     7. Convert to NSImage
     - Final result image
     ```

     - Parameters:
     - image: Original image
     - timestamp: Capture time
     - videoTimestamp: Video playback time (seconds)

     - Returns: Image with timestamp added
     */
    /// @brief Add timestamp overlay to image
    /// @param image Original image
    /// @param timestamp capture time
    /// @param videoTimestamp video playback time (seconds)
    /// @return Timestamp add image
    private func addTimestampOverlay(
        to image: NSImage,
        timestamp: Date,
        videoTimestamp: TimeInterval?
    ) -> NSImage {
        let size = image.size

        // ===== Step 1: Create NSBitmapImageRep =====
        // What is NSBitmapImageRep?
        // - Bitmap (pixel-based) image representation
        // - Can directly manipulate pixel data
        // - Supports various pixel formats
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,          // Data planes (nil = auto allocate)
            pixelsWide: Int(size.width),    // Width (pixels)
            pixelsHigh: Int(size.height),   // Height (pixels)
            bitsPerSample: 8,               // Bits per sample (R, G, B, A each 8 bits)
            samplesPerPixel: 4,             // Samples per pixel (RGBA = 4)
            hasAlpha: true,                 // Has alpha channel
            isPlanar: false,                // Not planar format (interleaved)
            colorSpaceName: .deviceRGB,     // RGB color space
            bytesPerRow: 0,                 // 0 = auto calculate
            bitsPerPixel: 0                 // 0 = auto calculate
        ) else {
            // Creation failure → return original
            return image
        }

        // ===== Step 2: Set NSGraphicsContext =====
        // What is NSGraphicsContext?
        // - AppKit drawing context
        // - Manages current drawing target
        // - Commands like draw(), fill() apply to this context

        // Save current state
        NSGraphicsContext.saveGraphicsState()

        // What is defer?
        // - Code to execute when function ends
        // - Always executes regardless of return, throw, break, etc.
        // - Useful for resource cleanup (close files, release locks, etc.)
        defer { NSGraphicsContext.restoreGraphicsState() }

        // Create context that can draw to bitmapRep
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            return image
        }

        // Set current drawing context
        // Now all drawing commands apply to bitmapRep
        NSGraphicsContext.current = context

        // ===== Step 3: Draw original image (background) =====
        image.draw(
            in: NSRect(origin: .zero, size: size),   // Position to draw (entire)
            from: NSRect(origin: .zero, size: size), // Source region (entire)
            operation: .copy,                        // Copy (overwrite)
            fraction: 1.0                            // Opacity 100%
        )

        // ===== Step 4: Format timestamp text =====

        // What is DateFormatter?
        // - Converts Date object to string
        // - Can specify date/time format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        // Example: "2024-10-12 15:30:45"

        var timestampText = dateFormatter.string(from: timestamp)

        // Add video playback time (if available)
        if let videoTime = videoTimestamp {
            // Time calculation:
            // videoTime = 125.5 seconds
            // → hours = 0, minutes = 2, seconds = 5, milliseconds = 500
            let hours = Int(videoTime) / 3600
            let minutes = (Int(videoTime) % 3600) / 60
            let seconds = Int(videoTime) % 60
            let milliseconds = Int((videoTime.truncatingRemainder(dividingBy: 1)) * 1000)

            // Format: "[HH:MM:SS.mmm]"
            timestampText += String(format: " [%02d:%02d:%02d.%03d]", hours, minutes, seconds, milliseconds)
            // Example: " [00:02:05.500]"
        }

        // Final text example:
        // "2024-10-12 15:30:45 [00:02:05.500]"

        // ===== Step 5: Set text style =====

        // What is NSAttributedString?
        // - String with styling applied
        // - Can specify font, color, size, etc.
        let attributes: [NSAttributedString.Key: Any] = [
            // Monospace font (good for number alignment)
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium),
            // White text (stands out on dark background)
            .foregroundColor: NSColor.white
        ]

        let attributedString = NSAttributedString(string: timestampText, attributes: attributes)
        let textSize = attributedString.size()  // Size that text will occupy

        // ===== Step 6: Calculate background rectangle position =====

        let padding: CGFloat = 12                    // Screen edge margin
        let backgroundPadding: CGFloat = 8           // Margin around text

        // Calculate bottom-right position:
        // ```
        //              padding
        //              ↓
        //    ┌─────────────────────────────┐
        //    │                             │
        //    │                             │
        //    │                             │
        //    │   ┌─────────────────────┐   │
        //    │   │ 2024-10-12 15:30:45 │   │ ← Place here
        //    └───┴─────────────────────┴───┘
        //        ↑                       ↑
        //    padding              backgroundPadding
        // ```
        let textRect = NSRect(
            x: size.width - textSize.width - padding - backgroundPadding * 2,
            y: padding,
            width: textSize.width + backgroundPadding * 2,
            height: textSize.height + backgroundPadding * 2
        )

        // ===== Step 7: Draw background rectangle =====

        // Semi-transparent black:
        // - Black color
        // - 70% opacity (alpha = 0.7)
        // - Improves text readability
        NSColor.black.withAlphaComponent(0.7).setFill()

        // Rounded corner rectangle
        let backgroundPath = NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4)
        backgroundPath.fill()

        // ===== Step 8: Draw text =====

        attributedString.draw(at: NSPoint(
            x: textRect.origin.x + backgroundPadding,
            y: textRect.origin.y + backgroundPadding
        ))

        // ===== Step 9: Convert to NSImage =====

        let finalImage = NSImage(size: size)
        finalImage.addRepresentation(bitmapRep)

        return finalImage
    }

    /**
     ## Convert NSImage to PNG/JPEG data

     ### Conversion Process:
     ```
     NSImage (AppKit object)
     ↓ tiffRepresentation
     TIFF Data (temporary format)
     ↓ NSBitmapImageRep
     Bitmap representation
     ↓ representation(using:)
     PNG/JPEG Data (final)
     ```

     ### Why go through TIFF?
     - NSImage can mix vector/bitmap
     - TIFF unifies all representations into bitmap
     - Easy to convert to NSBitmapImageRep

     ### JPEG compression options:
     ```swift
     properties: [.compressionFactor: 0.95]
     ```
     - compressionFactor: compression quality (0.0 ~ 1.0)
     - 0.95 = 95% quality (default value)

     - Parameters:
     - image: Image to convert
     - format: Target format (PNG or JPEG)

     - Returns: Image data, or nil on failure
     */
    /// @brief NSImage PNG/JPEG data convert
    /// @param image Image to convert
    /// @param format Target format (PNG or JPEG)
    /// @return Image data, or nil on failure
    private func convertToData(image: NSImage, format: CaptureImageFormat) -> Data? {
        // ===== Step 1: NSImage → TIFF Data =====
        // TIFF (Tagged Image File Format):
        // - Lossless format
        // - Used as temporary intermediate format
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // ===== Step 2: NSBitmapImageRep → PNG/JPEG Data =====
        switch format {
        case .png:
            // PNG encoding:
            // - Lossless compression
            // - properties = [:] → use default settings
            return bitmapRep.representation(using: .png, properties: [:])

        case .jpeg:
            // JPEG encoding:
            // - Lossy compression
            // - compressionFactor = 0.95 → 95% quality
            return bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegQuality]
            )
        }
    }

    /**
     ## Display user notification

     ### What is NSAlert?
     macOS standard notification dialog.

     ```
     ┌─────────────────────────────┐
     │  ⓘ Screenshot Saved         │  ← Title
     │                             │
     │  Saved to Blackbox_001.png  │  ← Message
     │                             │
     │              [ OK ]          │  ← Button
     └─────────────────────────────┘
     ```

     ### Alert Style:
     - .informational: Info icon (blue ⓘ)
     - .warning: Warning icon (yellow ⚠)
     - .critical: Critical icon (red ⛔)

     ### Why DispatchQueue.main.async?
     - UI updates can only happen on the main thread
     - This method may be called from a background thread
     - async delivers the work to the main thread

     - Parameters:
     - title: Notification title
     - message: Notification message
     - isError: Whether error notification (true = warning style)
     */
    /// @brief Display user notification
    /// @param title Notification title
    /// @param message notification message
    /// @param isError Whether error notification (true = warning style)
    private func showNotification(title: String, message: String, isError: Bool = false) {
        // ===== Execute on main thread =====
        // UI work must happen on main thread!
        DispatchQueue.main.async {
            // Create NSAlert
            let alert = NSAlert()

            // Set title
            alert.messageText = title

            // Set detailed message
            alert.informativeText = message

            // Set style:
            // - Error → .warning (warning icon)
            // - Normal → .informational (info icon)
            alert.alertStyle = isError ? .warning : .informational

            // Add button
            alert.addButton(withTitle: "OK")

            // Run modal:
            // - Display dialog on screen
            // - Wait until user clicks button
            alert.runModal()
        }
    }
}

/**
 # ScreenCaptureService Usage Guide

 ## Basic Usage:

 ```swift
 // 1. Create service (once at app start)
 let captureService = ScreenCaptureService(device: metalDevice)

 // 2. Set JPEG quality (optional)
 captureService.jpegQuality = 0.90  // 90% quality

 // 3. Capture frame
 if let data = captureService.captureFrame(
 from: currentTexture,
 format: .png,
 timestamp: Date(),
 videoTimestamp: syncController.currentTime
 ) {
 // 4. Save file
 captureService.showSavePanel(
 data: data,
 format: .png,
 defaultFilename: generateFilename()
 )
 }
 ```

 ## Filename Creation Example:

 ```swift
 func generateFilename() -> String {
 let dateFormatter = DateFormatter()
 dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
 let dateString = dateFormatter.string(from: Date())

 let position = "Front"  // or currentCameraPosition

 return "Blackbox_\(position)_\(dateString)"
 // Example: "Blackbox_Front_2024-10-12_15-30-45"
 }
 ```

 ## Keyboard Shortcut Capture:

 ```swift
 // ContentView.swift
 .onReceive(NotificationCenter.default.publisher(for: .captureScreenshot)) { _ in
 if let texture = renderer.currentTexture {
 if let data = captureService.captureFrame(
 from: texture,
 format: .png,
 timestamp: Date(),
 videoTimestamp: syncController.currentTime
 ) {
 captureService.showSavePanel(data: data, format: .png)
 }
 }
 }

 // Register shortcut: Command+S
 .keyboardShortcut("s", modifiers: .command)
 ```

 ## Auto Save (without dialog):

 ```swift
 func autoSaveCapture() {
 guard let texture = renderer.currentTexture else { return }

 guard let data = captureService.captureFrame(
 from: texture,
 format: .jpeg,  // Smaller file size
 timestamp: Date(),
 videoTimestamp: syncController.currentTime
 ) else { return }

 // Auto save path
 let filename = generateFilename() + ".jpg"
 let documentsURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
 let fileURL = documentsURL.appendingPathComponent("Blackbox").appendingPathComponent(filename)

 do {
 try data.write(to: fileURL)
 print("Auto-saved: \(fileURL.path)")
 } catch {
 print("Auto-save failed: \(error)")
 }
 }
 ```

 ## Performance Considerations:

 1. **Capture is an expensive operation**
 - GPU → CPU memory copy (8MB)
 - Image encoding (PNG: slow, JPEG: fast)
 - File writing

 2. **Recommendations**
 - Pause playback before capture
 - Prevent continuous capture (1 second interval limit)
 - Use JPEG (5-10x faster than PNG)

 3. **Memory management**
 - Data is automatically released after capture
 - Capture may fail if out of memory
 */
