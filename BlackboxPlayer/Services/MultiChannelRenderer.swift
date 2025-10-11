//
//  MultiChannelRenderer.swift
//  BlackboxPlayer
//
//  Metal-based multi-channel video renderer
//

import Foundation
import Metal
import MetalKit
import CoreVideo
import AVFoundation

/// Multi-channel video renderer using Metal
class MultiChannelRenderer {
    // MARK: - Properties

    /// Metal device
    private let device: MTLDevice

    /// Command queue
    private let commandQueue: MTLCommandQueue

    /// Render pipeline state
    private var pipelineState: MTLRenderPipelineState?

    /// Texture cache for efficient pixel buffer conversion
    private var textureCache: CVMetalTextureCache?

    /// Vertex buffer for full-screen quad
    private var vertexBuffer: MTLBuffer?

    /// Current layout mode
    private(set) var layoutMode: LayoutMode = .grid

    /// Focused channel (for focus layout)
    private(set) var focusedPosition: CameraPosition = .front

    /// Sampler state for texture sampling
    private var samplerState: MTLSamplerState?

    /// Screen capture service
    private(set) var captureService: ScreenCaptureService

    /// Last rendered texture (for capture)
    private var lastRenderedTexture: MTLTexture?

    /// Transformation service
    private let transformationService = VideoTransformationService.shared

    /// Uniform buffer for transformation parameters
    private var uniformBuffer: MTLBuffer?

    // MARK: - Initialization

    init?() {
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        self.device = device

        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = commandQueue

        // Create texture cache
        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )

        guard result == kCVReturnSuccess, let textureCache = cache else {
            print("Failed to create texture cache")
            return nil
        }
        self.textureCache = textureCache

        // Create capture service
        self.captureService = ScreenCaptureService(device: device)

        // Setup pipeline, vertex buffer, sampler, and uniform buffer
        setupPipeline()
        setupVertexBuffer()
        setupSampler()
        setupUniformBuffer()
    }

    // MARK: - Setup

    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }

        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            print("Failed to find shader functions")
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Configure vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()

        // Position attribute (attribute 0)
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // TexCoord attribute (attribute 1)
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
        vertexDescriptor.attributes[1].bufferIndex = 0

        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }

    private func setupVertexBuffer() {
        // Full-screen quad vertices (position + texCoord)
        let vertices: [Float] = [
            // Position (x, y)    TexCoord (u, v)
            -1.0, -1.0,           0.0, 1.0,  // Bottom-left
             1.0, -1.0,           1.0, 1.0,  // Bottom-right
            -1.0,  1.0,           0.0, 0.0,  // Top-left
             1.0,  1.0,           1.0, 0.0   // Top-right
        ]

        let size = vertices.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: vertices, length: size, options: [])
    }

    private func setupSampler() {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.mipFilter = .notMipmapped

        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    private func setupUniformBuffer() {
        // Create uniform buffer for transformation parameters
        // Size matches TransformUniforms struct in Metal shader (6 floats)
        let uniformSize = MemoryLayout<Float>.size * 6
        uniformBuffer = device.makeBuffer(length: uniformSize, options: [.storageModeShared])

        if uniformBuffer == nil {
            errorLog("[MultiChannelRenderer] Failed to create uniform buffer")
        } else {
            debugLog("[MultiChannelRenderer] Created uniform buffer with size \(uniformSize) bytes")
        }
    }

    private func updateUniformBuffer() {
        guard let buffer = uniformBuffer else {
            return
        }

        let transformations = transformationService.transformations

        // Update uniform buffer with current transformation values
        let pointer = buffer.contents().assumingMemoryBound(to: Float.self)
        pointer[0] = transformations.brightness
        pointer[1] = transformations.flipHorizontal ? 1.0 : 0.0
        pointer[2] = transformations.flipVertical ? 1.0 : 0.0
        pointer[3] = transformations.zoomLevel
        pointer[4] = transformations.zoomCenterX
        pointer[5] = transformations.zoomCenterY
    }

    // MARK: - Public Methods

    /// Render frames to drawable
    /// - Parameters:
    ///   - frames: Dictionary mapping camera positions to video frames
    ///   - drawable: Metal drawable to render to
    ///   - drawableSize: Size of the drawable
    func render(
        frames: [CameraPosition: VideoFrame],
        to drawable: CAMetalDrawable,
        drawableSize: CGSize
    ) {
        guard let pipelineState = pipelineState else { return }

        // Early return if no frames
        guard !frames.isEmpty else { return }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        // Create render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Update transformation uniform buffer
        updateUniformBuffer()

        // Create stable, sorted array of positions for thread-safe viewport calculation
        let sortedPositions = frames.keys.sorted { $0.rawValue < $1.rawValue }

        // Calculate viewports for each channel
        let viewports = calculateViewports(for: sortedPositions, in: drawableSize)

        // Render each channel
        for (position, frame) in frames {
            guard let viewport = viewports[position] else {
                debugLog("[MultiChannelRenderer] No viewport for position \(position.displayName)")
                continue
            }

            guard let pixelBuffer = frame.toPixelBuffer() else {
                debugLog("[MultiChannelRenderer] Failed to create pixel buffer for frame at \(String(format: "%.2f", frame.timestamp))s")
                continue
            }

            guard let texture = createTexture(from: pixelBuffer) else {
                debugLog("[MultiChannelRenderer] Failed to create texture from pixel buffer")
                continue
            }

            // Set viewport
            renderEncoder.setViewport(MTLViewport(
                originX: Double(viewport.origin.x),
                originY: Double(viewport.origin.y),
                width: Double(viewport.size.width),
                height: Double(viewport.size.height),
                znear: 0.0,
                zfar: 1.0
            ))

            // Set vertex buffer
            if let vertexBuffer = vertexBuffer {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            }

            // Set uniform buffer for transformations (buffer index 0 for both vertex and fragment shaders)
            if let uniformBuffer = uniformBuffer {
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            }

            // Set texture
            renderEncoder.setFragmentTexture(texture, index: 0)

            // Set sampler
            if let samplerState = samplerState {
                renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            }

            // Draw quad
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        renderEncoder.endEncoding()

        // Store last rendered texture for capture
        lastRenderedTexture = drawable.texture

        // Present drawable
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Capture current frame as image
    /// - Parameters:
    ///   - format: Image format (PNG or JPEG)
    ///   - timestamp: Optional timestamp to overlay
    ///   - videoTimestamp: Current video playback time
    /// - Returns: Captured image data, or nil if no frame available
    func captureCurrentFrame(
        format: CaptureImageFormat = .png,
        timestamp: Date? = nil,
        videoTimestamp: TimeInterval? = nil
    ) -> Data? {
        guard let texture = lastRenderedTexture else {
            errorLog("[MultiChannelRenderer] No rendered texture available for capture")
            return nil
        }

        return captureService.captureFrame(
            from: texture,
            format: format,
            timestamp: timestamp,
            videoTimestamp: videoTimestamp
        )
    }

    /// Capture and save current frame with save dialog
    /// - Parameters:
    ///   - format: Image format (PNG or JPEG)
    ///   - timestamp: Optional timestamp to overlay
    ///   - videoTimestamp: Current video playback time
    ///   - defaultFilename: Default filename without extension
    /// - Returns: True if saved successfully
    @discardableResult
    func captureAndSave(
        format: CaptureImageFormat = .png,
        timestamp: Date? = Date(),
        videoTimestamp: TimeInterval? = nil,
        defaultFilename: String = "BlackboxCapture"
    ) -> Bool {
        guard let data = captureCurrentFrame(
            format: format,
            timestamp: timestamp,
            videoTimestamp: videoTimestamp
        ) else {
            return false
        }

        return captureService.showSavePanel(
            data: data,
            format: format,
            defaultFilename: defaultFilename
        )
    }

    /// Set layout mode
    /// - Parameter mode: New layout mode
    func setLayoutMode(_ mode: LayoutMode) {
        self.layoutMode = mode
    }

    /// Set focused channel (for focus layout)
    /// - Parameter position: Camera position to focus on
    func setFocusedPosition(_ position: CameraPosition) {
        self.focusedPosition = position
    }

    // MARK: - Private Methods

    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else {
            debugLog("[MultiChannelRenderer] Texture cache is nil")
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        debugLog("[MultiChannelRenderer] Creating texture: \(width)x\(height), format: \(pixelFormat)")

        var texture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &texture
        )

        guard result == kCVReturnSuccess else {
            errorLog("[MultiChannelRenderer] CVMetalTextureCacheCreateTextureFromImage failed with code: \(result)")
            return nil
        }

        guard let cvTexture = texture else {
            errorLog("[MultiChannelRenderer] CVMetalTexture is nil after successful creation")
            return nil
        }

        guard let metalTexture = CVMetalTextureGetTexture(cvTexture) else {
            errorLog("[MultiChannelRenderer] Failed to get MTLTexture from CVMetalTexture")
            return nil
        }

        debugLog("[MultiChannelRenderer] Successfully created Metal texture")
        return metalTexture
    }

    private func calculateViewports(
        for positions: [CameraPosition],
        in size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]

        switch layoutMode {
        case .grid:
            viewports = calculateGridViewports(positions: positions, size: size)
        case .focus:
            viewports = calculateFocusViewports(positions: positions, size: size)
        case .horizontal:
            viewports = calculateHorizontalViewports(positions: positions, size: size)
        }

        return viewports
    }

    private func calculateGridViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]
        let count = positions.count

        // Calculate grid dimensions
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))

        let cellWidth = size.width / CGFloat(cols)
        let cellHeight = size.height / CGFloat(rows)

        for (index, position) in positions.enumerated() {
            let col = index % cols
            let row = index / cols

            let x = CGFloat(col) * cellWidth
            let y = CGFloat(row) * cellHeight

            viewports[position] = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
        }

        return viewports
    }

    private func calculateFocusViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]

        // Main viewport takes 75% of width and full height
        let mainWidth = size.width * 0.75
        let mainHeight = size.height

        // Thumbnail area takes 25% of width
        let thumbWidth = size.width * 0.25
        let thumbHeight = size.height / CGFloat(max(1, positions.count - 1))

        var thumbnailIndex = 0
        for position in positions {
            if position == focusedPosition {
                // Main viewport (left side)
                viewports[position] = CGRect(x: 0, y: 0, width: mainWidth, height: mainHeight)
            } else {
                // Thumbnail viewport (right side)
                let y = CGFloat(thumbnailIndex) * thumbHeight
                viewports[position] = CGRect(x: mainWidth, y: y, width: thumbWidth, height: thumbHeight)
                thumbnailIndex += 1
            }
        }

        return viewports
    }

    private func calculateHorizontalViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]
        let count = positions.count

        guard count > 0 else { return viewports }

        let cellWidth = size.width / CGFloat(count)
        let cellHeight = size.height

        for (index, position) in positions.enumerated() {
            let x = CGFloat(index) * cellWidth
            viewports[position] = CGRect(x: x, y: 0, width: cellWidth, height: cellHeight)
        }

        return viewports
    }
}

// MARK: - Supporting Types

/// Layout mode for multi-channel display
enum LayoutMode: String, CaseIterable {
    case grid       // Grid layout (2x2, 2x3, etc.)
    case focus      // One large + thumbnails
    case horizontal // Side-by-side horizontal

    var displayName: String {
        switch self {
        case .grid:
            return "Grid"
        case .focus:
            return "Focus"
        case .horizontal:
            return "Horizontal"
        }
    }
}
