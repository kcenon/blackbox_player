/// @file MultiChannelRenderer.swift
/// @brief Metal-based multi-channel video renderer
/// @author BlackboxPlayer Development Team
/// @details
/// A class that renders multiple video channels on the GPU using Metal.
///
/// ## What is Metal?
/// - Apple's low-level GPU programming API
/// - High-speed computation on GPU (graphics card) instead of CPU
/// - Used for games, video processing, machine learning, etc.
/// - Successor to OpenGL, much faster and more efficient
///
/// ## GPU vs CPU:
/// ```
/// CPU (Central Processing Unit):
/// - Complex logical operations
/// - Sequential processing
/// - Cores: 8-16
/// - Examples: File reading, decoding, control logic
///
/// GPU (Graphics Processing Unit):
/// - Simple parallel operations
/// - Simultaneous processing
/// - Cores: Thousands
/// - Examples: Video rendering, pixel processing, image transformation
/// ```
///
/// ## Rendering Pipeline:
/// ```
/// VideoFrame (CPU memory)
///   ↓
/// CVPixelBuffer (Shared memory)
///   ↓
/// MTLTexture (GPU memory)
///   ↓
/// Vertex Shader (GPU)
///   ↓
/// Fragment Shader (GPU)
///   ↓
/// Screen output (Drawable)
/// ```
///
/// ## Key Features:
/// 1. **Multi-channel rendering**: Process 4 channels simultaneously on GPU
/// 2. **Layout modes**: Grid, Focus, Horizontal arrangement
/// 3. **Video transformations**: Brightness, flip, zoom (GPU shaders)
/// 4. **Screen capture**: Save rendered frames as images
/// 5. **Texture caching**: Performance optimization with CVMetalTextureCache
///
/// ## Metal Key Concepts:
/// - **MTLDevice**: GPU device
/// - **MTLCommandQueue**: Command queue (task queue)
/// - **MTLTexture**: Image in GPU memory
/// - **MTLBuffer**: Data in GPU memory
/// - **MTLRenderPipelineState**: Rendering settings (shaders, formats, etc.)
/// - **MTLCommandBuffer**: Command bundle
/// - **MTLRenderCommandEncoder**: Rendering command encoder

import Foundation
import Metal
import MetalKit
import CoreVideo
import AVFoundation

/// @class MultiChannelRenderer
/// @brief Metal-based multi-channel video renderer
///
/// @details
/// A class that renders multiple video channels on the GPU using Metal.
class MultiChannelRenderer {
    // MARK: - Properties

    /// @var device
    /// @brief Metal device (GPU)
    ///
    /// @details
    /// What is MTLDevice?
    /// - Object representing the GPU
    /// - Starting point for all Metal resources
    /// - Creates buffers, textures, pipelines, etc.
    ///
    /// Creation:
    /// ```swift
    /// MTLCreateSystemDefaultDevice()
    /// // Returns the system's default GPU
    /// // Mac: Integrated or dedicated GPU
    /// // iOS: GPU in A-series chip
    /// ```
    ///
    /// nil case:
    /// - Legacy hardware without Metal support
    /// - Virtual machines (VMware, Parallels)
    /// - Some cloud instances
    private let device: MTLDevice

    /// @var commandQueue
    /// @brief Command Queue
    ///
    /// @details
    /// What is Command Queue?
    /// - Queue of commands to send to GPU
    /// - Similar concept to printer queue
    /// - Submit multiple commands to GPU in order
    ///
    /// How it works:
    /// ```
    /// [Command1: Load texture] → GPU processes
    /// [Command2: Render frame] → Waiting
    /// [Command3: Screen output] → Waiting
    /// ```
    ///
    /// CPU vs GPU:
    /// - CPU: commandQueue.makeCommandBuffer() (create command)
    /// - GPU: actual execution after commandBuffer.commit()
    private let commandQueue: MTLCommandQueue

    /// @var pipelineState
    /// @brief Render Pipeline State
    ///
    /// @details
    /// What is Pipeline State?
    /// - Bundle of rendering settings
    /// - Which shader to use
    /// - What pixel format to use
    /// - What vertex attributes to use
    ///
    /// Why create in advance?
    /// - High creation cost (several milliseconds)
    /// - Fast when reused (microseconds)
    /// - Performance degradation if created per frame
    ///
    /// Optional(?):
    /// - nil on initialization failure
    /// - Created in setupPipeline()
    private var pipelineState: MTLRenderPipelineState?

    /// @var textureCache
    /// @brief Texture Cache (Texture Cache)
    ///
    /// @details
    /// What is CVMetalTextureCache?
    /// - Cache that converts CVPixelBuffer to MTLTexture
    /// - Efficient sharing between CPU and GPU memory
    /// - Uses shared memory without copying (Zero-Copy)
    ///
    /// What happens without it?
    /// - Copy from CPU to GPU memory every time
    /// - Slow (several milliseconds)
    /// - Uses double memory
    ///
    /// With cache:
    /// - Uses shared memory
    /// - Fast (microseconds)
    /// - Saves memory
    ///
    /// CVPixelBuffer → CVMetalTexture → MTLTexture
    private var textureCache: CVMetalTextureCache?

    /// @var vertexBuffer
    /// @brief Vertex Buffer (Vertex Buffer)
    ///
    /// @details
    /// What is Vertex Buffer?
    /// - GPU memory containing vertex data
    /// - Here it's a quad covering the entire screen
    ///
    /// What is a Vertex?
    /// - Point in 3D model
    /// - Position (x, y) + Texture coordinates (u, v)
    ///
    /// Full-Screen Quad:
    /// ```
    /// (-1, 1) ──────── (1, 1)    (0, 0) ──────── (1, 0)
    ///    │               │           │               │
    ///    │    Screen        │           │   Texture      │
    ///    │               │           │               │
    /// (-1,-1) ──────── (1,-1)    (0, 1) ──────── (1, 1)
    /// ```
    ///
    /// Why is one quad sufficient?
    /// - Set different viewport for each channel
    /// - Draw the same quad multiple times
    /// - Very fast on GPU
    private var vertexBuffer: MTLBuffer?

    /// @var layoutMode
    /// @brief Current Layout Mode (Current Layout Mode)
    ///
    /// @details
    /// LayoutMode Types:
    /// - .grid: Grid arrangement (2×2, 2×3 etc.)
    /// - .focus: One large + Others small
    /// - .horizontal: Side by side horizontally
    ///
    /// private(set):
    /// - Readable from outside
    /// - Can only be changed via setLayoutMode()
    private(set) var layoutMode: LayoutMode = .grid

    /// @var focusedPosition
    /// @brief Focused Channel (Focused Channel)
    ///
    /// @details
    /// Channel to display large in Focus layout:
    /// - .front: Front camera (default)
    /// - .rear: Rear camera
    /// - .left, .right, .interior
    ///
    /// Usage:
    /// ```swift
    /// renderer.setLayoutMode(.focus)
    /// renderer.setFocusedPosition(.rear)
    /// // Rear camera large, others small
    /// ```
    private(set) var focusedPosition: CameraPosition = .front

    /// @var samplerState
    /// @brief Sampler State (Sampler State)
    ///
    /// @details
    /// What is a Sampler?
    /// - Settings for reading pixel values from texture
    /// - Filtering mode (linear, nearest)
    /// - Border handling (clamp, repeat)
    ///
    /// Linear vs Nearest:
    /// ```
    /// Nearest (Nearest pixel):
    /// [■][■][■][■]  → Aliasing effect
    ///
    /// Linear (Linear interpolation):
    /// [■▓░][■▓░]    → Smooth
    /// ```
    ///
    /// Clamp vs Repeat:
    /// - Clamp: Stop at boundary (no margin)
    /// - Repeat: Repeat at boundary (tiling)
    ///
    /// Settings:
    /// - minFilter, magFilter: .linear (Smooth scaling)
    /// - addressMode: .clampToEdge (No boundary repetition)
    private var samplerState: MTLSamplerState?

    /// @var captureService
    /// @brief Screen Capture Service (Screen Capture Service)
    ///
    /// @details
    /// Role:
    /// - Convert rendered frames to images
    /// - Supports PNG/JPEG formats
    /// - Timestamp overlay
    /// - File save dialog
    ///
    /// Usage:
    /// ```swift
    /// renderer.captureAndSave(
    ///     format: .png,
    ///     timestamp: Date(),
    ///     defaultFilename: "Screenshot"
    /// )
    /// ```
    private(set) var captureService: ScreenCaptureService

    /// @var lastRenderedTexture
    /// @brief Last Rendered Texture (Last Rendered Texture)
    ///
    /// @details
    /// Saved for capture:
    /// - render() On call Save drawable.texture
    /// - captureCurrentFrame()Used in
    /// - Keep only last frame (Saves memory)
    ///
    /// Optional(?):
    /// - nil initially
    /// - Set value after first rendering
    private var lastRenderedTexture: MTLTexture?

    /// @var transformationService
    /// @brief Transformation Service (Transformation Service)
    ///
    /// @details
    /// VideoTransformationService:
    /// - Brightness
    /// - Flip horizontal
    /// - Flip vertical
    /// - Zoom level and center
    ///
    /// .shared: Singleton pattern
    /// - Use only one instance across app
    /// - Settings shared everywhere
    private let transformationService = VideoTransformationService.shared

    /// @var uniformBuffer
    /// @brief Uniform Buffer (Uniform Buffer)
    ///
    /// @details
    /// What is Uniform?
    /// - Value applied uniformly to all vertices/pixels
    /// - Example: Brightness, flip state, zoom scale
    ///
    /// Uniform vs Attribute:
    /// - Attribute: Different per vertex (Position, texture coordinates)
    /// - Uniform: Same for all vertices (Transformation parameters)
    ///
    /// Buffer structure (6floats):
    /// ```
    /// [0] brightness      (Brightness)
    /// [1] flipHorizontal  (horizontal Flip)
    /// [2] flipVertical    (vertical Flip)
    /// [3] zoomLevel       (zoom Scale)
    /// [4] zoomCenterX     (zoom Center X)
    /// [5] zoomCenterY     (zoom Center Y)
    /// ```
    ///
    /// Shared with shader:
    /// - CPUUpdate value in
    /// - GPU Read in shader
    /// - Apply real-time transformation
    private var uniformBuffer: MTLBuffer?

    // MARK: - Initialization (Initialization)

    /// @brief Initialize the renderer.
    ///
    /// @details
    /// Failable Initializer (init?):
    /// - Failed possible Initialization
    /// - nil return 
    /// - guard letwith Use
    ///
    /// Initialization process:
    /// 1. Metal Create device (GPU)
    /// 2. Command Queue Create
    /// 3. Texture Cache Create
    /// 4. Capture Service Create
    /// 5. Pipeline Set
    /// 6. Vertex Buffer Create
    /// 7. Sampler Set
    /// 8. Uniform Buffer Create
    ///
    /// Failure reasons:
    /// - Metal Unsupported hardware
    /// - Resource creation failed
    init?() {
        // 1. Metal Device get
        guard let device = MTLCreateSystemDefaultDevice() else {
            // MTLCreateSystemDefaultDevice():
            // - whensystem's Return default GPU
            // - nil: Metal Unsupported

            print("Metal is not supported on this device")
            return nil
            // Failable init: nil return Initialization Failed
        }
        self.device = device

        // 2. Command Queue Create
        guard let commandQueue = device.makeCommandQueue() else {
            // makeCommandQueue():
            // - Create command queue
            // - nil: Creation failed (rare)

            print("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = commandQueue

        // 3. Texture Cache Create
        var cache: CVMetalTextureCache?
        // Optional Variable declaration (To pass as pointer)

        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,  // Default memory allocator
            nil,                  // Cache options (nil = Default value)
            device,               // Metal Device
            nil,                  // Texture options (nil = Default value)
            &cache                // Pointer to variable for result
        )
        // C API: Return success code, result via pointer

        guard result == kCVReturnSuccess, let textureCache = cache else {
            // result Check + Optional Binding
            print("Failed to create texture cache")
            return nil
        }
        self.textureCache = textureCache

        // 4. Capture Service Create
        self.captureService = ScreenCaptureService(device: device)
        // GPU DeviceShare to optimize performance

        // 5-8. Rest Set
        setupPipeline()       // Render pipeline
        setupVertexBuffer()   // Vertex Buffer
        setupSampler()        // Sampler
        setupUniformBuffer()  // Uniform Buffer

        // Initialization Success
        // nil No return = Normal initialization
    }

    // MARK: - Setup (Set)

    /// @brief Set up the render pipeline.
    ///
    /// @details
    /// What is a Pipeline?
    /// - Stages of the rendering process
    /// - Settings required for each stage
    ///
    /// Pipeline stages:
    /// ```
    /// 1. Vertex Shader   (Vertex transformation)
    ///    ↓
    /// 2. Rasterization   (Pixel generation)
    ///    ↓
    /// 3. Fragment Shader (Pixel color calculation)
    ///    ↓
    /// 4. Output          (Screen output)
    /// ```
    ///
    /// Configuration:
    /// - Vertex Shader function
    /// - Fragment Shader function
    /// - Pixel format (BGRA8)
    /// - Vertex attributes (Position, texture coordinates)
    private func setupPipeline() {
        // 1. Create Shader Library
        guard let library = device.makeDefaultLibrary() else {
            // makeDefaultLibrary():
            // - Project's .metal Library compiled from files
            // - Contains all shader functions

            print("Failed to create Metal library")
            return
        }

        // 2. Find Shader function
        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            // makeFunction(name:):
            // - Find shader function by name
            // - MultiChannelShaders.metal Defined in file

            print("Failed to find shader functions")
            return
        }

        // 3. Create Pipeline Descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        // Descriptor: Object containing settings

        pipelineDescriptor.vertexFunction = vertexFunction
        // Specify vertex shader

        pipelineDescriptor.fragmentFunction = fragmentFunction
        // Specify pixel shader

        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // Output pixel format:
        // - BGRA: Blue, Green, Red, Alpha Order
        // - 8: Per channel 8bits (0~255)
        // - Unorm: Unsigned Normalized (0.0~1.0)

        // 4. Set up Vertex Descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        // Define vertex attribute layout

        // Position Attribute (attribute 0)
        vertexDescriptor.attributes[0].format = .float2
        // float2: 2of float (x, y)

        vertexDescriptor.attributes[0].offset = 0
        // Offset from buffer start = 0bytes

        vertexDescriptor.attributes[0].bufferIndex = 0
        // Buffer index = 0

        // TexCoord Attribute (attribute 1)
        vertexDescriptor.attributes[1].format = .float2
        // float2: 2of float (u, v)

        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
        // Offset = 8bytes (float 2 size)
        // position Start from next

        vertexDescriptor.attributes[1].bufferIndex = 0
        // Use same buffer (Interleaved)

        // Layout Set
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
        // Stride (Stride): 16bytes
        // = float 4 (position 2 + texCoord 2)

        vertexDescriptor.layouts[0].stepFunction = .perVertex
        // Move to next data per vertex

        /*
         Buffer layout:
         [px, py, tx, ty, px, py, tx, ty, ...]
         └─────┘ └─────┘  ← vertex 1 (16bytes)
         └─────┘ └─────┘  ← vertex 2
         */

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // 5. Create Pipeline State
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            // High creation cost (several milliseconds)
            // Create once and reuse
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }

    /// @brief Vertex Buffer Create.
    ///
    /// @details
    /// Full-Screen Quad:
    /// - Quad covering entire screen
    /// - 2Composed of triangles
    /// - Triangle StripDraw with
    ///
    /// Vertex Data:
    /// - Position: NDC (Normalized Device Coordinates)
    ///   - (-1,-1) = Bottom-left
    ///   - (1, 1) = Top-right
    /// - TexCoord: Texture coordinates
    ///   - (0, 0) = Top-left
    ///   - (1, 1) = Bottom-right
    ///
    /// Triangle Strip:
    /// ```
    /// 3 ──── 4        Order: 1→2→3→4
    /// │ ╲    │        triangle1: 1,2,3
    /// │   ╲  │        triangle2: 2,4,3
    /// 1 ──── 2
    /// ```
    private func setupVertexBuffer() {
        // Full-screen quad vertices (position + texCoord)
        let vertices: [Float] = [
            // Position (x, y)    TexCoord (u, v)
            -1.0, -1.0, 0.0, 1.0,  // Bottom-left
            1.0, -1.0, 1.0, 1.0,  // Bottom-right
            -1.0, 1.0, 0.0, 0.0,  // Top-left
            1.0, 1.0, 1.0, 0.0   // Top-right
        ]
        // 4vertices × 4floats = 16floats

        /*
         Coordinate description:
         NDC (Normalized Device Coordinates):
         (-1, 1) ──────── (1, 1)
         │               │
         │   Screen center    │
         │     (0, 0)    │
         │               │
         (-1,-1) ──────── (1,-1)

         Texture Coordinates:
         (0, 0) ──────── (1, 0)
         │               │
         │               │
         │               │
         (0, 1) ──────── (1, 1)
         */

        let size = vertices.count * MemoryLayout<Float>.size
        // 16 × 4bytes = 64bytes

        vertexBuffer = device.makeBuffer(bytes: vertices, length: size, options: [])
        // Copy vertex data to GPU memory
        // options: [] = Default options
    }

    /// @brief Set up the sampler.
    ///
    /// @details
    /// What is a Sampler?
    /// - Method to read colors from texture
    /// - Settings for filtering, border handling, etc.
    ///
    /// Configuration:
    /// - minFilter: Minification filter = linear
    /// - magFilter: Magnification filter = linear
    /// - sAddressMode: Saxis (horizontal) border = clampToEdge
    /// - tAddressMode: Taxis (vertical) border = clampToEdge
    /// - mipFilter: Mipmap = Not used
    private func setupSampler() {
        let samplerDescriptor = MTLSamplerDescriptor()

        // Linear Filtering
        samplerDescriptor.minFilter = .linear
        // On minification: interpolate adjacent pixels
        samplerDescriptor.magFilter = .linear
        // On magnification: interpolate adjacent pixels

        /*
         Linear vs Nearest:
         Original:  [R][G][B][W]

         Nearest:   [R][R][G][G][B][B][W][W]  (Aliasing)
         Linear:    [R][Y][G][C][B][P][W][W]  (Smooth)
         ↑      ↑      ↑
         Interpolated color
         */

        // Clamp Border handling
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        // Repeat edge pixels when crossing boundary

        /*
         Clamp vs Repeat:
         Clamp:  [ABC|ABC|ABC]  Stop at boundary
         Repeat: [ABC ABC ABC]  Repeat at boundary (tiling)
         */

        // Mipmap Not used
        samplerDescriptor.mipFilter = .notMipmapped
        // Mipmap: Multiple resolutions of Texture (Performance optimization)
        // Video uses original resolution only

        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    /// @brief Uniform Buffer Create.
    ///
    /// @details
    /// Uniform Buffer:
    /// - Transformation parameters save
    /// - CPUin update
    /// - GPU Read in shader
    ///
    /// Buffer size:
    /// - 6floats × 4bytes = 24bytes
    ///
    /// Buffer contents:
    /// - [0] brightness
    /// - [1] flipHorizontal
    /// - [2] flipVertical
    /// - [3] zoomLevel
    /// - [4] zoomCenterX
    /// - [5] zoomCenterY
    ///
    /// storageModeShared:
    /// - CPU and GPU shared memory
    /// - CPUin write and, GPUin read
    /// - no copy, fast
    private func setupUniformBuffer() {
        // Create uniform buffer for transformation parameters
        // size matches TransformUniforms struct in Metal shader (6 floats)
        let uniformsize = MemoryLayout<Float>.size * 6
        // Float size(4bytes) × 6 = 24bytes

        uniformBuffer = device.makeBuffer(length: uniformsize, options: [.storageModeShared])
        // Create as shared memory
        // CPU ↔ GPU Bidirectional access possible

        if uniformBuffer == nil {
            errorLog("[MultiChannelRenderer] Failed to create uniform buffer")
        } else {
            debugLog("[MultiChannelRenderer] Created uniform buffer with size \(uniformsize) bytes")
        }
    }

    /// @brief Update uniform buffer.
    ///
    /// @details
    /// Update process:
    /// 1. Get current transformation settings
    /// 2. Get buffer pointer
    /// 3. Write each value to buffer
    ///
    /// When to call:
    /// - Before rendering each frame
    /// - When transformation settings change
    ///
    /// Performance:
    /// - 24bytes Copy: very fast (nanoseconds)
    /// - Shared memory: No copy
    private func updateUniformBuffer() {
        guard let buffer = uniformBuffer else {
            return
        }

        // 1. Get current transformation settings
        let transformations = transformationService.transformations
        // VideoTransformationService.sharedsettings of

        // 2. Get buffer pointer
        let pointer = buffer.contents().assumingMemoryBound(to: Float.self)
        // contents(): UnsafeMutableRawPointer
        // assumingMemoryBound(to:): Float pointer cast to

        // 3. each value write
        pointer[0] = transformations.brightness
        // Brightness: 0.0 (dark) ~ 1.0 (normal) ~ 2.0 (bright)

        pointer[1] = transformations.flipHorizontal ? 1.0 : 0.0
        // horizontal Flip: 1.0 = Flip, 0.0 = normal

        pointer[2] = transformations.flipVertical ? 1.0 : 0.0
        // vertical Flip: 1.0 = Flip, 0.0 = normal

        pointer[3] = transformations.zoomLevel
        // zoom Scale: 1.0 (100%) ~ 2.0 (200%)

        pointer[4] = transformations.zoomCenterX
        // zoom Center X: 0.0 (left) ~ 1.0 (right)

        pointer[5] = transformations.zoomCenterY
        // zoom Center Y: 0.0 (top) ~ 1.0 (bottom)

        /*
         Buffer memory layout:
         [brightness][flipH][flipV][zoom][centerX][centerY]
         4bytes     4bytes  4bytes  4bytes  4bytes  4bytes
         */
    }

    // MARK: - Public Methods (Public Methods)

    /// @brief Render frames to drawable.
    ///
    /// @param frames Frame for each channel (camera position → frame)
    /// @param drawable Rendering target (Screen buffer)
    /// @param drawableSize Screen size
    ///
    /// @details
    /// What is Drawable?
    /// - Final image to display on screen
    /// - MTKViewProvided by
    /// - Double buffering (Front + Back buffer)
    ///
    /// Rendering process:
    /// 1. Command Buffer Create
    /// 2. Set up Render Pass (Screen clear)
    /// 3. Create Render Encoder
    /// 4. Viewport Calculate (Position/size of each channel)
    /// 5. Render each channel
    ///    - Pixel Buffer → Texture Transform
    ///    - Viewport Set
    ///    - Buffers Binding
    ///    - Draw Call
    /// 6. Screen output (Present)
    func render(
        frames: [CameraPosition: VideoFrame],
        to drawable: CAMetalDrawable,
        drawableSize: CGSize
    ) {
        // 1. Pipeline Check
        guard let pipelineState = pipelineState else {
            return  // Not initialized
        }

        // 2. frame Check
        guard !frames.isEmpty else {
            return  // No frames to render
        }

        // 3. Command Buffer Create
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        // Command Buffer: GPU Container holding commands

        // 4. Render Pass Descriptor Create
        let renderPassDescriptor = MTLRenderPassDescriptor()
        // Render Pass: Unit of rendering work

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        // Rendering target: drawabletexture of (Screen buffer)

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        // Load Action: Action at rendering start
        // .clear: Screen clear

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        // Clear color: black (R=0, G=0, B=0, A=1)

        renderPassDescriptor.colorAttachments[0].storeAction = .store
        // Store Action: Action at rendering end
        // .store: Store result

        // 5. Create Render Encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        // Render Encoder: Encode rendering commands

        // 6. Pipeline State Set
        renderEncoder.setRenderPipelineState(pipelineState)
        // Set which shader to use

        // 7. Uniform Buffer update
        updateUniformBuffer()
        // Update transformation parameters to latest values

        // 8. Create sorted channel list
        let sortedPositions = frames.keys.sorted { $0.rawValue < $1.rawValue }
        // Ensure thread-safe ordering
        // rawValue Order: front, rear, left, right, interior

        // 9. Viewport Calculate
        let viewports = calculateViewports(for: sortedPositions, in: drawableSize)
        // Calculate screen position and size for each channel
        // Depends on layout mode

        // 10. Render each channel
        for (position, frame) in frames {
            // 10-1. Viewport Check
            guard let viewport = viewports[position] else {
                debugLog("[MultiChannelRenderer] No viewport for position \(position.displayName)")
                continue  // To next channel
            }

            // 10-2. Pixel Buffer Transform
            guard let pixelBuffer = frame.toPixelBuffer() else {
                debugLog("[MultiChannelRenderer] Failed to create pixel buffer for frame at \(String(format: "%.2f", frame.timestamp))s")
                continue
            }
            // VideoFramepixel data of CVPixelBufferConvert with

            // 10-3. Texture Create
            guard let texture = createTexture(from: pixelBuffer) else {
                debugLog("[MultiChannelRenderer] Failed to create texture from pixel buffer")
                continue
            }
            // CVPixelBuffer → MTLTexture (GPU memory)

            // 10-4. Viewport Set
            renderEncoder.setViewport(MTLViewport(
                originX: Double(viewport.origin.x),
                originY: Double(viewport.origin.y),
                width: Double(viewport.size.width),
                height: Double(viewport.size.height),
                znear: 0.0,
                zfar: 1.0
            ))
            // Specify screen area to draw this channel

            // 10-5. Vertex Buffer Binding
            if let vertexBuffer = vertexBuffer {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                // Vertex data (quad 4 vertices)
            }

            // 10-6. Uniform Buffer Binding
            if let uniformBuffer = uniformBuffer {
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
                // Vertex Shader's buffer(1)

                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
                // Fragment Shader's buffer(0)
            }

            // 10-7. Texture Binding
            renderEncoder.setFragmentTexture(texture, index: 0)
            // Fragment Shader's texture(0)

            // 10-8. Sampler Binding
            if let samplerState = samplerState {
                renderEncoder.setFragmentSamplerState(samplerState, index: 0)
                // Fragment Shader's sampler(0)
            }

            // 10-9. Draw Call
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            // Triangle Strip: 4 vertices with 2 triangles draw
            // GPUin Vertex Shader → Rasterization → Fragment Shader execute
        }

        // 11. Encoding end
        renderEncoder.endEncoding()
        // No more rendering commands

        // 12. last Texture save (for capture)
        lastRenderedTexture = drawable.texture

        // 13. Drawable display
        commandBuffer.present(drawable)
        // Output to screen (Front/Back buffer Swap)

        // 14. Command Buffer submit
        commandBuffer.commit()
        // GPUSend commands to
        // Now GPUactually starts rendering
    }

    /// @brief Capture current frame as image.
    ///
    /// @param format Image format (.png or .jpeg)
    /// @param timestamp Date/time to overlay
    /// @param videoTimestamp Video playback time
    ///
    /// @return Image data (nil = Failed)
    ///
    /// @details
    /// Capture process:
    /// 1. Last Rendered Texture Check
    /// 2. ScreenCaptureServiceConvert with
    /// 3. PNG/JPEG Return data
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

    /// @brief Capture current frame and show save dialog.
    ///
    /// @param format Image format
    /// @param timestamp Date/time to overlay (Default: current time)
    /// @param videoTimestamp Video playback time
    /// @param defaultFilename Default filename (Excluding extension)
    ///
    /// @return Whether save succeeded
    ///
    /// @details
    /// Convenience method:
    /// - captureCurrentFrame() + Save file
    /// - NSSavePanelSelect save location with
    /// - Automatically add extension (.png or .jpg)
    ///
    /// @discardableResult:
    /// - No warning when ignoring return value
    /// - renderer.captureAndSave() // OK
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

    /// @brief Set the layout mode.
    ///
    /// @param mode New layout mode
    ///
    /// @details
    /// Layout modes:
    /// - .grid: Grid arrangement (2×2, 2×3 etc.)
    /// - .focus: One large + Others small
    /// - .horizontal: Side by side horizontally
    func setLayoutMode(_ mode: LayoutMode) {
        self.layoutMode = mode
    }

    /// @brief Set the channel to focus.
    ///
    /// @param position Camera position to focus
    ///
    /// @details
    /// Focus layoutonly in Usage:
    /// - Display specified channel large
    /// - Display other channels small
    func setFocusedPosition(_ position: CameraPosition) {
        self.focusedPosition = position
    }

    // MARK: - Private Methods (Private Methods)

    /// @brief Create Metal Texture from Pixel Buffer.
    ///
    /// @param pixelBuffer To convert CVPixelBuffer
    ///
    /// @return GPU Texture (nil = Failed)
    ///
    /// @details
    /// Conversion process:
    /// 1. Texture Cache Use
    /// 2. CVMetalTextureCacheConvert with
    /// 3. MTLTexture Extract
    ///
    /// Zero-Copy:
    /// - Share without memory copy
    /// - CPU memoryand GPU Memory shared
    /// - Fast and efficient
    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else {
            debugLog("[MultiChannelRenderer] Texture cache is nil")
            return nil
        }

        // 1. Pixel Buffer Get information
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        debugLog("[MultiChannelRenderer] Creating texture: \(width)x\(height), format: \(pixelFormat)")

        // 2. CVMetalTexture Create
        var texture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,    // Memory allocator
            textureCache,           // Texture Cache
            pixelBuffer,            // Original Pixel Buffer
            nil,                    // Options (nil = Default value)
            .bgra8Unorm,            // Metal Pixel format
            width,                  // Width
            height,                 // Height
            0,                      // Plane Index (0 = First)
            &texture                // Variable to store result
        )

        guard result == kCVReturnSuccess else {
            errorLog("[MultiChannelRenderer] CVMetalTextureCacheCreateTextureFromImage failed with code: \(result)")
            return nil
        }

        guard let cvTexture = texture else {
            errorLog("[MultiChannelRenderer] CVMetalTexture is nil after successful creation")
            return nil
        }

        // 3. MTLTexture Extract
        guard let metalTexture = CVMetalTextureGetTexture(cvTexture) else {
            errorLog("[MultiChannelRenderer] Failed to get MTLTexture from CVMetalTexture")
            return nil
        }

        debugLog("[MultiChannelRenderer] Successfully created Metal texture")
        return metalTexture
    }

    /// @brief Calculate viewport for each channel.
    ///
    /// @param positions Channel position array (Sorted)
    /// @param size Total screen size
    ///
    /// @return Viewport of each channel
    ///
    /// @details
    /// What is Viewport?
    /// - Area to render on screen
    /// - position (x, y) + size (width, height)
    ///
    /// Calculation by layout mode:
    /// - .grid: calculateGridViewports
    /// - .focus: calculateFocusViewports
    /// - .horizontal: calculateHorizontalViewports
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

    /// @brief Calculate viewport for grid layout.
    ///
    /// @param positions Channel position array
    /// @param size Total screen size
    ///
    /// @return Viewport of each channel
    ///
    /// @details
    /// Grid Layout:
    /// - N×M Grid (rows×Columns)
    /// - Automatically calculate optimal arrangement
    ///
    /// Calculation method:
    /// 1. From number of channels √N (Square root)
    /// 2. Round up to calculate number of columns
    /// 3. rows  = Number of channels / Columns  (Round up)
    /// 4. Each cell size = Screen / Grid
    ///
    /// Example:
    /// - 1channels: 1×1 (Full screen)
    /// - 2channels: 1×2 (horizontal 2)
    /// - 3channels: 2×2 (3 + Empty space 1)
    /// - 4channels: 2×2
    /// - 5channels: 2×3 (5 + Empty space 1)
    private func calculateGridViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]
        let count = positions.count

        // 1. Calculate grid size
        let cols = Int(ceil(sqrt(Double(count))))
        // sqrt: Square root
        // ceil: Round up
        // Example: count=4 → sqrt(4)=2.0 → ceil(2.0)=2

        let rows = Int(ceil(Double(count) / Double(cols)))
        // rows  = Number of channels / Columns  (Round up)
        // Example: count=5, cols=3 → ceil(5/3)=2

        // 2. Calculate cell size
        let cellWidth = size.width / CGFloat(cols)
        let cellHeight = size.height / CGFloat(rows)

        // 3. Calculate viewport for each channel
        for (index, position) in positions.enumerated() {
            // enumerated(): (Index, Element) Return tuple

            let col = index % cols
            // Column = index modulo number of columns
            // Example: index=3, cols=2 → col=1

            let row = index / cols
            // Row = index divided by number of columns
            // Example: index=3, cols=2 → row=1

            let x = CGFloat(col) * cellWidth
            let y = CGFloat(row) * cellHeight

            viewports[position] = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
        }

        /*
         Example: 4channels Grid (2×2)
         ┌─────────┬─────────┐
         │ Front   │ Rear    │
         │ (0,0)   │ (1,0)   │
         ├─────────┼─────────┤
         │ Left    │ Right   │
         │ (0,1)   │ (1,1)   │
         └─────────┴─────────┘
         */

        return viewports
    }

    /// @brief Calculate viewport for focus layout.
    ///
    /// @param positions Channel position array
    /// @param size Total screen size
    ///
    /// @return Viewport of each channel
    ///
    /// @details
    /// Focus Layout:
    /// - One channel large (75% Width)
    /// - others small (25% Width, Arranged vertically)
    ///
    /// Arrangement:
    /// - left 75%: Focused Channel
    /// - right 25%: Other channels (Thumbnails)
    ///
    /// Example:
    /// ```
    /// ┌─────────────────────┬──────┐
    /// │                     │Rear  │
    /// │                     ├──────┤
    /// │   Front (Focus)      │Left  │
    /// │                     ├──────┤
    /// │                     │Right │
    /// └─────────────────────┴──────┘
    /// ```
    private func calculateFocusViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]

        // 1. Main viewport size
        let mainWidth = size.width * 0.75   // 75% Width
        let mainHeight = size.height        // Full height

        // 2. Thumbnail area size
        let thumbWidth = size.width * 0.25  // 25% Width
        let thumbHeight = size.height / CGFloat(max(1, positions.count - 1))
        // Divide height by number of other channels
        // max(1, ...): 0Prevent division by

        // 3. Thumbnail index
        var thumbnailIndex = 0

        // 4. Arrange each channel
        for position in positions {
            if position == focusedPosition {
                // Focused Channel: left Large area
                viewports[position] = CGRect(x: 0, y: 0, width: mainWidth, height: mainHeight)
            } else {
                // Rest channels: right Small area
                let y = CGFloat(thumbnailIndex) * thumbHeight
                viewports[position] = CGRect(x: mainWidth, y: y, width: thumbWidth, height: thumbHeight)
                thumbnailIndex += 1
            }
        }

        return viewports
    }

    /// @brief Calculate viewport for horizontal layout.
    ///
    /// @param positions Channel position array
    /// @param size Total screen size
    ///
    /// @return Viewport of each channel
    ///
    /// @details
    /// Horizontal Layout:
    /// - Arrange all channels horizontally side by side
    /// - Divide with equal width
    /// - Use full height
    ///
    /// Example:
    /// ```
    /// 4channels:
    /// ┌─────┬─────┬─────┬─────┐
    /// │Front│Rear │Left │Right│
    /// │     │     │     │     │
    /// └─────┴─────┴─────┴─────┘
    /// ```
    private func calculateHorizontalViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]
        let count = positions.count

        guard count > 0 else {
            return viewports  // Empty dictionary if no channels
        }

        // 1. Calculate cell size
        let cellWidth = size.width / CGFloat(count)
        // Divide width by number of channels

        let cellHeight = size.height
        // Use full height

        // 2. Arrange each channel
        for (index, position) in positions.enumerated() {
            let x = CGFloat(index) * cellWidth
            viewports[position] = CGRect(x: x, y: 0, width: cellWidth, height: cellHeight)
        }

        return viewports
    }
}

// MARK: - Supporting Types (Supporting Types)

/// @enum LayoutMode
/// @brief Multi-channel display layout mode
///
/// @details
/// enum + String:
/// - rawValue to string columns Use
/// - UserDefaults Convenient for save/load
///
/// CaseIterable:
/// - LayoutMode.allCasesAccess all cases with
/// - UI Useful when creating selection menu
enum LayoutMode: String, CaseIterable {
    /// @var grid
    /// @brief Grid layout (Grid)
    ///
    /// @details
    /// N×M GridArrangement:
    /// - 1channels: 1×1 (Full screen)
    /// - 2channels: 1×2 (Split horizontally in 2)
    /// - 3channels: 2×2 (4cells, using 3)
    /// - 4channels: 2×2
    /// - 5channels: 2×3 (6cells, using 5)
    case grid       // Grid layout (2x2, 2x3, etc.)

    /// @var focus
    /// @brief Focus layout (Focus)
    ///
    /// @details
    /// One large + Others small:
    /// - left 75%: Focused Channel
    /// - right 25%: Rest Thumbnails
    case focus      // One large + thumbnails

    /// @var horizontal
    /// @brief Horizontal layout (horizontal)
    ///
    /// @details
    /// Side by side horizontally:
    /// - Divide with equal width
    /// - Use full height
    case horizontal // Side-by-side horizontal

    /// @brief UIName to display in
    ///
    /// @return User-friendly name
    ///
    /// @details
    /// computed property:
    /// - User-friendly name for each case
    /// - Display in menus, buttons, etc.
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
