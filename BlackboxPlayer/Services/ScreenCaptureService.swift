//
//  ScreenCaptureService.swift
//  BlackboxPlayer
//
//  Service for capturing current video frame and saving as image
//

import Foundation
import AppKit
import CoreGraphics
import Metal
import MetalKit

/// Image format for screen capture
enum CaptureImageFormat: String {
    case png = "png"
    case jpeg = "jpg"

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        }
    }

    var utType: String {
        switch self {
        case .png: return "public.png"
        case .jpeg: return "public.jpeg"
        }
    }
}

/// Screen capture service
class ScreenCaptureService {

    // MARK: - Properties

    /// Metal device
    private let device: MTLDevice

    /// JPEG quality (0.0-1.0)
    var jpegQuality: CGFloat = 0.95

    // MARK: - Initialization

    init(device: MTLDevice) {
        self.device = device
    }

    // MARK: - Public Methods

    /// Capture current frame from Metal texture
    /// - Parameters:
    ///   - texture: Metal texture to capture
    ///   - format: Image format (PNG or JPEG)
    ///   - timestamp: Optional timestamp to overlay
    ///   - videoTimestamp: Current video playback time
    /// - Returns: Captured image data
    func captureFrame(
        from texture: MTLTexture,
        format: CaptureImageFormat,
        timestamp: Date? = nil,
        videoTimestamp: TimeInterval? = nil
    ) -> Data? {
        // Create CGImage from Metal texture
        guard let cgImage = createCGImage(from: texture) else {
            errorLog("[ScreenCaptureService] Failed to create CGImage from texture")
            return nil
        }

        // Create NSImage
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(cgImage: cgImage, size: size)

        // Add timestamp overlay if requested
        let finalImage = if let timestamp = timestamp {
            addTimestampOverlay(to: nsImage, timestamp: timestamp, videoTimestamp: videoTimestamp)
        } else {
            nsImage
        }

        // Convert to requested format
        return convertToData(image: finalImage, format: format)
    }

    /// Show save panel and save captured image
    /// - Parameters:
    ///   - data: Image data to save
    ///   - format: Image format
    ///   - defaultFilename: Default filename without extension
    /// - Returns: True if saved successfully
    @discardableResult
    func showSavePanel(
        data: Data,
        format: CaptureImageFormat,
        defaultFilename: String = "BlackboxCapture"
    ) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Screenshot"
        savePanel.message = "Choose where to save the captured frame"
        savePanel.nameFieldStringValue = "\(defaultFilename).\(format.rawValue)"
        savePanel.allowedContentTypes = [.init(filenameExtension: format.rawValue)!]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        let response = savePanel.runModal()

        guard response == .OK, let url = savePanel.url else {
            return false
        }

        do {
            try data.write(to: url)
            infoLog("[ScreenCaptureService] Saved screenshot to: \(url.path)")

            // Show success notification
            showNotification(
                title: "Screenshot Saved",
                message: "Saved to \(url.lastPathComponent)"
            )

            return true
        } catch {
            errorLog("[ScreenCaptureService] Failed to save screenshot: \(error)")

            // Show error notification
            showNotification(
                title: "Save Failed",
                message: error.localizedDescription,
                isError: true
            )

            return false
        }
    }

    // MARK: - Private Methods

    /// Create CGImage from Metal texture
    private func createCGImage(from texture: MTLTexture) -> CGImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        // Allocate buffer for pixel data
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // Copy texture data to buffer
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        // Create data provider
        guard let dataProvider = CGDataProvider(
            data: Data(pixelData) as CFData
        ) else {
            return nil
        }

        // Create CGImage
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    /// Add timestamp overlay to image
    private func addTimestampOverlay(
        to image: NSImage,
        timestamp: Date,
        videoTimestamp: TimeInterval?
    ) -> NSImage {
        let size = image.size

        // Create bitmap context
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return image
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            return image
        }

        NSGraphicsContext.current = context

        // Draw original image
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )

        // Format timestamp text
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var timestampText = dateFormatter.string(from: timestamp)

        if let videoTime = videoTimestamp {
            let hours = Int(videoTime) / 3600
            let minutes = (Int(videoTime) % 3600) / 60
            let seconds = Int(videoTime) % 60
            let milliseconds = Int((videoTime.truncatingRemainder(dividingBy: 1)) * 1000)
            timestampText += String(format: " [%02d:%02d:%02d.%03d]", hours, minutes, seconds, milliseconds)
        }

        // Draw timestamp with background
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white
        ]

        let attributedString = NSAttributedString(string: timestampText, attributes: attributes)
        let textSize = attributedString.size()

        // Position at bottom-right with padding
        let padding: CGFloat = 12
        let backgroundPadding: CGFloat = 8
        let textRect = NSRect(
            x: size.width - textSize.width - padding - backgroundPadding * 2,
            y: padding,
            width: textSize.width + backgroundPadding * 2,
            height: textSize.height + backgroundPadding * 2
        )

        // Draw semi-transparent background
        NSColor.black.withAlphaComponent(0.7).setFill()
        let backgroundPath = NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4)
        backgroundPath.fill()

        // Draw text
        attributedString.draw(at: NSPoint(
            x: textRect.origin.x + backgroundPadding,
            y: textRect.origin.y + backgroundPadding
        ))

        // Create final image
        let finalImage = NSImage(size: size)
        finalImage.addRepresentation(bitmapRep)

        return finalImage
    }

    /// Convert NSImage to data in specified format
    private func convertToData(image: NSImage, format: CaptureImageFormat) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            return bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegQuality]
            )
        }
    }

    /// Show user notification
    private func showNotification(title: String, message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = isError ? .warning : .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
