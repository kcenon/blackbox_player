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

        // Setup pipeline and vertex buffer
        setupPipeline()
        setupVertexBuffer()
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

        // Calculate viewports for each channel
        let viewports = calculateViewports(for: frames.keys, in: drawableSize)

        // Render each channel
        for (position, frame) in frames {
            guard let viewport = viewports[position],
                  let texture = createTexture(from: frame.pixelBuffer) else {
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

            // Set texture
            renderEncoder.setFragmentTexture(texture, index: 0)

            // Draw quad
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        renderEncoder.endEncoding()

        // Present drawable
        commandBuffer.present(drawable)
        commandBuffer.commit()
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
        guard let textureCache = textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

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

        guard result == kCVReturnSuccess,
              let cvTexture = texture else {
            return nil
        }

        return CVMetalTextureGetTexture(cvTexture)
    }

    private func calculateViewports(
        for positions: Dictionary<CameraPosition, VideoFrame>.Keys,
        in size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]
        let positions = Array(positions).sorted { $0.rawValue < $1.rawValue }

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
