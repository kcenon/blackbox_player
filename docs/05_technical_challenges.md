# Technical Challenges and Solutions

> 🌐 **Language**: [English](#) | [한국어](05_technical_challenges_kr.md)

## Overview

This document outlines the major technical challenges for the macOS Blackbox Player project and provides detailed solutions and implementation strategies.

---

## Challenge 1: SD Card File System Access on macOS

### Problem Statement

**Severity:** 🟡 Medium
**Complexity:** Medium
**Impact:** Medium - Manageable with native APIs

The dashcam SD cards need to be accessed efficiently for reading video files and metadata. We must implement reliable file system access using macOS native APIs (FileManager and IOKit) while handling USB device detection and file permissions properly.

### Technical Details

1. **macOS File System Support:**
   - Native: APFS, HFS+, FAT32, exFAT
   - SD cards typically formatted as FAT32 or exFAT
   - Direct support through FileManager

2. **Sandbox Restrictions:**
   - macOS sandboxed apps have limited device access
   - Need specific entitlements for USB device access
   - User must grant permission through file picker or drag-and-drop

3. **Native API Integration:**
   - FileManager for file operations
   - IOKit for USB device detection
   - Pure Swift implementation - no bridging required
   - Native support for both Intel and Apple Silicon

### Solution Strategy

#### Option 1: FileManager + IOKit Integration (Recommended)

**Architecture:**
```
Swift (UI & Business Logic)
    ↕ Native Swift API
FileSystemService
    ↕ Foundation Framework
FileManager + IOKit
    ↕ macOS Kernel
SD Card Hardware (FAT32/exFAT)
```

**Implementation:**

**Step 1: Create FileSystemService**

```swift
// FileSystemService.swift
import Foundation

enum FileSystemError: Error {
    case accessDenied
    case readFailed(String)
    case writeFailed(String)
    case listFailed(String)
    case deviceNotFound
    case permissionDenied
    case fileNotFound
}

class FileSystemService {
    private let fileManager: FileManager

    init() {
        self.fileManager = FileManager.default
    }

    func listVideoFiles(at url: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw FileSystemError.accessDenied
        }

        return enumerator.compactMap { $0 as? URL }
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "mp4" || ext == "h264" || ext == "avi"
            }
    }

    func readFile(at url: URL) throws -> Data {
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw FileSystemError.accessDenied
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw FileSystemError.readFailed(error.localizedDescription)
        }
    }

    func getFileInfo(at url: URL) throws -> FileInfo {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)

            return FileInfo(
                name: url.lastPathComponent,
                size: attributes[.size] as? Int64 ?? 0,
                isDirectory: (attributes[.type] as? FileAttributeType) == .typeDirectory,
                path: url.path,
                creationDate: attributes[.creationDate] as? Date,
                modificationDate: attributes[.modificationDate] as? Date
            )
        } catch {
            throw FileSystemError.readFailed(error.localizedDescription)
        }
    }

    func deleteFiles(_ urls: [URL]) throws {
        for url in urls {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw FileSystemError.writeFailed("Failed to delete \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}

struct FileInfo {
    let name: String
    let size: Int64
    let isDirectory: Bool
    let path: String
    let creationDate: Date?
    let modificationDate: Date?
}
```

**Step 2: Device Detection with IOKit**

```swift
import IOKit
import IOKit.storage
import DiskArbitration

class DeviceDetector {
    func detectSDCards() -> [URL] {
        var mountedVolumes: [URL] = []

        // Get all mounted volumes
        if let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) {
            for url in urls {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])

                    // Check if it's a removable device (like SD card)
                    if let isRemovable = resourceValues.volumeIsRemovable,
                       let isEjectable = resourceValues.volumeIsEjectable,
                       isRemovable && isEjectable {
                        mountedVolumes.append(url)
                    }
                } catch {
                    print("Error checking volume properties: \(error)")
                }
            }
        }

        return mountedVolumes
    }

    func monitorDeviceChanges(onConnect: @escaping (URL) -> Void, onDisconnect: @escaping (URL) -> Void) {
        // Monitor volume mount/unmount notifications
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                onConnect(volume)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                onDisconnect(volume)
            }
        }
    }
}
```

**Step 3: File Picker Integration**

```swift
import SwiftUI
import AppKit

struct FilePicker: View {
    @Binding var selectedFolder: URL?

    var body: some View {
        Button("Select SD Card Folder") {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Select the dashcam SD card folder"

            if panel.runModal() == .OK {
                selectedFolder = panel.url
            }
        }
    }
}
```

**Step 4: Entitlements**

```xml
<!-- BlackboxPlayer.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Allow USB device access -->
    <key>com.apple.security.device.usb</key>
    <true/>

    <!-- Allow user-selected file access -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Allow read/write access to removable volumes -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>

    <!-- Enable App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

### Testing Strategy

```swift
class FileSystemIntegrationTests: XCTestCase {
    var fileSystemService: FileSystemService!
    var testVolumeURL: URL!

    override func setUp() {
        super.setUp()
        fileSystemService = FileSystemService()

        // Use a test SD card or mock volume
        testVolumeURL = URL(fileURLWithPath: "/Volumes/TEST_SD")
    }

    func testListVideoFiles() throws {
        let files = try fileSystemService.listVideoFiles(at: testVolumeURL)
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.allSatisfy { url in
            ["mp4", "h264", "avi"].contains(url.pathExtension.lowercased())
        })
    }

    func testGetFileInfo() throws {
        let files = try fileSystemService.listVideoFiles(at: testVolumeURL)
        guard let firstFile = files.first else {
            XCTFail("No files found")
            return
        }

        let fileInfo = try fileSystemService.getFileInfo(at: firstFile)
        XCTAssertEqual(fileInfo.name, firstFile.lastPathComponent)
        XCTAssertGreaterThan(fileInfo.size, 0)
    }

    func testReadVideoFile() throws {
        let files = try fileSystemService.listVideoFiles(at: testVolumeURL)
        guard let videoFile = files.first else {
            XCTFail("No video files found")
            return
        }

        let data = try fileSystemService.readFile(at: videoFile)
        XCTAssertGreaterThan(data.count, 0)
    }
}
```

### Fallback Plan

If SD card file system is incompatible or inaccessible:

1. **Manual Folder Selection:** Primary fallback
   - Use NSOpenPanel to let users select folder
   - Works with any mounted volume
   - No special permissions required

2. **Drag and Drop Support:** User-friendly alternative
   - Allow users to drag SD card folder into app
   - Automatic file system access
   - Intuitive UX

3. **Network Share Access:** For remote scenarios
   - Support SMB/AFP network shares
   - Access SD card mounted on another computer
   - Useful for team environments

---

## Challenge 2: Multi-Channel Synchronized Playback

### Problem Statement

**Severity:** 🟠 High
**Complexity:** High
**Impact:** High - Core feature requirement

Playing 5 video streams simultaneously while maintaining frame-perfect synchronization is computationally intensive and technically complex.

### Technical Details

1. **Synchronization Requirements:**
   - All channels must stay within ±50ms of each other
   - Playback speed changes must affect all channels equally
   - Seeking must be synchronized across channels

2. **Performance Challenges:**
   - 5 concurrent H.264 decoders
   - 5 separate audio decoders
   - Real-time rendering at 30fps+ per channel
   - Memory: ~400MB per HD stream = 2GB total

3. **Timing Issues:**
   - Different frame rates per channel (29.97 vs 30fps)
   - Variable frame intervals
   - Audio/video drift
   - Dropped frames

### Solution Strategy

#### Architecture

```
Master Clock (CMClock)
    │
    ├── Channel 1 ──→ Decoder ──→ Buffer ──→ Sync ──→ Renderer
    ├── Channel 2 ──→ Decoder ──→ Buffer ──→ Sync ──→ Renderer
    ├── Channel 3 ──→ Decoder ──→ Buffer ──→ Sync ──→ Renderer
    ├── Channel 4 ──→ Decoder ──→ Buffer ──→ Sync ──→ Renderer
    └── Channel 5 ──→ Decoder ──→ Buffer ──→ Sync ──→ Renderer
                                                   │
                                              Metal GPU
                                                   │
                                              Display
```

#### Implementation

**1. Master Clock**

```swift
class MasterClock {
    private var startTime: CFAbsoluteTime = 0
    private var isPaused: Bool = true
    private var pausedTime: TimeInterval = 0
    private var rate: Float = 1.0

    func start() {
        isPaused = false
        startTime = CFAbsoluteTimeGetCurrent() - pausedTime
    }

    func pause() {
        isPaused = true
        pausedTime = currentTime
    }

    var currentTime: TimeInterval {
        if isPaused {
            return pausedTime
        }
        return (CFAbsoluteTimeGetCurrent() - startTime) * Double(rate)
    }

    func seek(to time: TimeInterval) {
        pausedTime = time
        startTime = CFAbsoluteTimeGetCurrent() - time
    }

    func setRate(_ newRate: Float) {
        let current = currentTime
        rate = newRate
        startTime = CFAbsoluteTimeGetCurrent() - current
    }
}
```

**2. Synchronized Channel**

```swift
class SynchronizedChannel {
    let id: Int
    private let decoder: VideoDecoder
    private let buffer: CircularBuffer<VideoFrame>
    private let masterClock: MasterClock

    private var currentFrame: VideoFrame?
    private var nextFrameTime: TimeInterval = 0

    init(id: Int, url: URL, masterClock: MasterClock) {
        self.id = id
        self.masterClock = masterClock
        self.decoder = VideoDecoder(url: url)
        self.buffer = CircularBuffer(capacity: 30)

        startDecoding()
    }

    private func startDecoding() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            for await frame in self.decoder.decode() {
                await self.buffer.append(frame)

                // Throttle if buffer is full
                while await self.buffer.count >= 25 {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
        }
    }

    func currentFrameForDisplay() async -> VideoFrame? {
        let clockTime = masterClock.currentTime

        // If we don't have a current frame or we've passed its display time
        if currentFrame == nil || clockTime >= nextFrameTime {
            // Get next frame from buffer
            if let frame = await buffer.dequeue() {
                currentFrame = frame
                nextFrameTime = frame.timestamp + frame.duration
            }
        }

        return currentFrame
    }
}
```

**3. Sync Controller**

```swift
class SyncController {
    private let masterClock: MasterClock
    private var channels: [SynchronizedChannel] = []
    private var syncMonitorTask: Task<Void, Never>?

    init() {
        masterClock = MasterClock()
    }

    func addChannel(url: URL) {
        let channel = SynchronizedChannel(
            id: channels.count,
            url: url,
            masterClock: masterClock
        )
        channels.append(channel)
    }

    func play() {
        masterClock.start()
        startSyncMonitoring()
    }

    func pause() {
        masterClock.pause()
    }

    func seek(to time: TimeInterval) {
        masterClock.pause()
        masterClock.seek(to: time)

        // Seek all channels
        for channel in channels {
            channel.seek(to: time)
        }

        masterClock.start()
    }

    func setPlaybackRate(_ rate: Float) {
        masterClock.setRate(rate)
    }

    private func startSyncMonitoring() {
        syncMonitorTask = Task.detached(priority: .high) { [weak self] in
            while !Task.isCancelled {
                await self?.checkSynchronization()
                try? await Task.sleep(nanoseconds: 100_000_000) // Check every 100ms
            }
        }
    }

    private func checkSynchronization() async {
        // Measure drift between channels
        var timestamps: [TimeInterval] = []

        for channel in channels {
            if let frame = await channel.currentFrameForDisplay() {
                timestamps.append(frame.timestamp)
            }
        }

        guard timestamps.count > 1 else { return }

        let maxDrift = timestamps.max()! - timestamps.min()!

        // If drift exceeds threshold, resync
        if maxDrift > 0.050 { // 50ms
            print("⚠️ Sync drift detected: \(maxDrift * 1000)ms - Resyncing...")
            await resync()
        }
    }

    private func resync() async {
        let currentTime = masterClock.currentTime

        // Pause and seek all channels to current time
        masterClock.pause()

        for channel in channels {
            channel.seek(to: currentTime)
        }

        // Wait for buffers to fill
        try? await Task.sleep(nanoseconds: 100_000_000)

        masterClock.start()
    }
}
```

**4. Multi-Texture Metal Renderer**

```swift
import Metal
import MetalKit

class MultiChannelRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache

    init(device: MTLDevice) throws {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = queue

        // Create texture cache
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        self.textureCache = cache!

        // Set up render pipeline
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        super.init()
    }

    func render(frames: [VideoFrame?], to view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Render each channel
        for (index, frame) in frames.enumerated() {
            guard let frame = frame else { continue }

            // Convert CVPixelBuffer to Metal texture
            if let texture = makeTexture(from: frame.pixelBuffer) {
                // Calculate viewport for this channel
                let viewport = calculateViewport(for: index, totalChannels: frames.count, viewSize: view.drawableSize)

                // Set viewport
                renderEncoder.setViewport(viewport)

                // Bind texture
                renderEncoder.setFragmentTexture(texture, index: 0)

                // Draw quad
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }

        renderEncoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var textureRef: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &textureRef
        )

        guard status == kCVReturnSuccess,
              let texture = textureRef else {
            return nil
        }

        return CVMetalTextureGetTexture(texture)
    }

    private func calculateViewport(for index: Int, totalChannels: Int, viewSize: CGSize) -> MTLViewport {
        // Grid layout: 2x3 for 5 channels
        let cols = 3
        let rows = 2

        let cellWidth = viewSize.width / Double(cols)
        let cellHeight = viewSize.height / Double(rows)

        let col = index % cols
        let row = index / cols

        return MTLViewport(
            originX: Double(col) * cellWidth,
            originY: Double(row) * cellHeight,
            width: cellWidth,
            height: cellHeight,
            znear: 0,
            zfar: 1
        )
    }
}
```

**5. Metal Shaders**

```metal
// Shaders.metal
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    // Fullscreen quad
    float2 positions[4] = {
        float2(-1, -1),
        float2(-1,  1),
        float2( 1, -1),
        float2( 1,  1)
    };

    float2 texCoords[4] = {
        float2(0, 1),
        float2(0, 0),
        float2(1, 1),
        float2(1, 0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return texture.sample(textureSampler, in.texCoord);
}
```

### Performance Optimization

**1. Thread Management**
```swift
// Dedicated queues for each task type
class QueueManager {
    static let decoding = DispatchQueue(label: "com.app.decoding", qos: .userInitiated, attributes: .concurrent)
    static let rendering = DispatchQueue.main // Must be main thread
    static let fileIO = DispatchQueue(label: "com.app.fileio", qos: .utility)
}
```

**2. Memory Management**

**Circular Buffer for Stream Buffering**
```swift
class CircularBuffer<T> {
    private var buffer: [T?]
    private var head = 0
    private var tail = 0
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }

        buffer[tail] = item
        tail = (tail + 1) % capacity

        // Overwrite if full
        if tail == head {
            head = (head + 1) % capacity
        }
    }

    func dequeue() -> T? {
        lock.lock()
        defer { lock.unlock() }

        guard head != tail else { return nil }

        let item = buffer[head]
        buffer[head] = nil
        head = (head + 1) % capacity

        return item
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }

        if tail >= head {
            return tail - head
        } else {
            return capacity - head + tail
        }
    }
}
```

**Frame Caching System**

To eliminate redundant decoding operations during frame-by-frame navigation and repeated playback, we implement an LRU-based frame cache:

```swift
class VideoPlayerViewModel {
    /// LRU frame cache with 100ms precision
    private var frameCache: [TimeInterval: VideoFrame] = [:]
    private let maxFrameCacheSize: Int = 30
    private var lastCacheCleanupTime: Date = Date()

    /// Memory warning observer
    private var memoryWarningObserver: NSObjectProtocol?

    init() {
        // Register for memory warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSApplicationDidReceiveMemoryWarningNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Load frame with cache lookup
    private func loadFrameAt(time: TimeInterval) {
        // 1. Check cache first
        let key = cacheKey(for: time)
        if let cachedFrame = frameCache[key] {
            currentFrame = cachedFrame
            return  // Skip decoding
        }

        // 2. Cache miss - decode frame
        // ... decoding logic ...

        // 3. Add to cache
        addToCache(frame: decodedFrame, at: key)
    }

    /// Generate cache key with 100ms precision
    private func cacheKey(for time: TimeInterval) -> TimeInterval {
        return round(time * 10.0) / 10.0
    }

    /// Add frame to cache with LRU eviction
    private func addToCache(frame: VideoFrame, at key: TimeInterval) {
        frameCache[key] = frame

        // Size-based eviction
        if frameCache.count > maxFrameCacheSize {
            if let oldestKey = frameCache.keys.sorted().first {
                frameCache.removeValue(forKey: oldestKey)
            }
        }

        // Time-based cleanup (every 5 seconds)
        let now = Date()
        if now.timeIntervalSince(lastCacheCleanupTime) > 5.0 {
            cleanupCache()
            lastCacheCleanupTime = now
        }
    }

    /// Remove frames outside ±5 second range
    private func cleanupCache() {
        let lowerBound = currentTime - 5.0
        let upperBound = currentTime + 5.0

        let keysToRemove = frameCache.keys.filter { key in
            key < lowerBound || key > upperBound
        }

        for key in keysToRemove {
            frameCache.removeValue(forKey: key)
        }
    }

    /// Handle system memory warnings
    private func handleMemoryWarning() {
        frameCache.removeAll()
        print("Memory warning received: Frame cache cleared")
    }

    func seekToTime(_ time: TimeInterval) {
        // Invalidate cache on seek
        frameCache.removeAll()
        // ... seek logic ...
    }

    func stop() {
        // Clear cache on stop
        frameCache.removeAll()
        // ... stop logic ...
    }
}
```

**Cache Performance Characteristics:**
- **Cache Key Precision:** 100ms (balances memory usage and hit rate)
- **Cache Capacity:** 30 frames (~250MB for 1080p, ~1GB for 4K)
- **Eviction Strategy:** Hybrid LRU
  - Size-based: Remove oldest when exceeds 30 frames
  - Time-based: Every 5 seconds, remove frames outside ±5 second range
- **Invalidation:** Complete clear on seek operations
- **Memory Warning:** Automatic cache clear on low memory

**Performance Benefits:**
- Frame-by-frame navigation: 0ms response on cache hit (vs 15-30ms decode)
- Repeated playback: 10x faster for cached segments
- Reduced CPU usage: Eliminates redundant FFmpeg operations
- Memory-efficient: Automatic cleanup prevents unbounded growth

### Testing

```swift
class SyncControllerTests: XCTestCase {
    func testSynchronization() async throws {
        let controller = SyncController()

        // Add 5 test channels
        for i in 0..<5 {
            let url = Bundle.main.url(forResource: "test_video_\(i)", withExtension: "mp4")!
            controller.addChannel(url: url)
        }

        controller.play()

        // Wait for playback
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

        // Measure sync accuracy
        let timestamps = await controller.getCurrentTimestamps()
        let maxDrift = timestamps.max()! - timestamps.min()!

        XCTAssertLessThan(maxDrift, 0.050) // Less than 50ms drift
    }
}
```

---

## Challenge 3: FFmpeg Integration and Video Processing

### Problem Statement

**Severity:** 🟡 Medium
**Complexity:** Medium
**Impact:** High - Required for all video operations

FFmpeg is a C library that requires careful integration into Swift. We need to handle H.264 decoding, MP3 audio, and MP4 muxing/demuxing.

### Solution Strategy

#### Swift Wrapper

```swift
import AVFoundation

class FFmpegDecoder {
    private var formatContext: UnsafeMutablePointer<AVFormatContext>?
    private var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?
    private var audioCodecContext: UnsafeMutablePointer<AVCodecContext>?
    private var videoStreamIndex: Int32 = -1
    private var audioStreamIndex: Int32 = -1

    func open(url: URL) throws {
        var ctx: UnsafeMutablePointer<AVFormatContext>?

        // Open input file
        guard avformat_open_input(&ctx, url.path, nil, nil) == 0 else {
            throw FFmpegError.openFailed
        }
        formatContext = ctx

        // Retrieve stream information
        guard avformat_find_stream_info(formatContext, nil) >= 0 else {
            throw FFmpegError.streamInfoFailed
        }

        // Find video and audio streams
        try findStreams()
    }

    private func findStreams() throws {
        guard let formatContext = formatContext else {
            throw FFmpegError.notOpen
        }

        let streamCount = Int(formatContext.pointee.nb_streams)
        let streams = UnsafeBufferPointer(start: formatContext.pointee.streams, count: streamCount)

        for (index, stream) in streams.enumerated() {
            guard let stream = stream else { continue }
            let codecParams = stream.pointee.codecpar

            if codecParams.pointee.codec_type == AVMEDIA_TYPE_VIDEO && videoStreamIndex == -1 {
                videoStreamIndex = Int32(index)
                try openCodec(stream: stream, context: &videoCodecContext)
            } else if codecParams.pointee.codec_type == AVMEDIA_TYPE_AUDIO && audioStreamIndex == -1 {
                audioStreamIndex = Int32(index)
                try openCodec(stream: stream, context: &audioCodecContext)
            }
        }
    }

    private func openCodec(stream: UnsafeMutablePointer<AVStream>, context: inout UnsafeMutablePointer<AVCodecContext>?) throws {
        let codecParams = stream.pointee.codecpar

        // Find decoder
        guard let codec = avcodec_find_decoder(codecParams.pointee.codec_id) else {
            throw FFmpegError.codecNotFound
        }

        // Allocate codec context
        guard let codecContext = avcodec_alloc_context3(codec) else {
            throw FFmpegError.codecAllocFailed
        }

        // Copy codec parameters
        guard avcodec_parameters_to_context(codecContext, codecParams) >= 0 else {
            throw FFmpegError.codecParamsFailed
        }

        // Open codec
        guard avcodec_open2(codecContext, codec, nil) >= 0 else {
            throw FFmpegError.codecOpenFailed
        }

        context = codecContext
    }

    func decode() -> AsyncStream<VideoFrame> {
        AsyncStream { continuation in
            Task.detached {
                await self.decodeLoop(continuation: continuation)
            }
        }
    }

    private func decodeLoop(continuation: AsyncStream<VideoFrame>.Continuation) async {
        guard let formatContext = formatContext,
              let videoCodecContext = videoCodecContext else {
            continuation.finish()
            return
        }

        let packet = av_packet_alloc()!
        let frame = av_frame_alloc()!

        defer {
            av_packet_free(&packet)
            av_frame_free(&frame)
        }

        while av_read_frame(formatContext, packet) >= 0 {
            defer { av_packet_unref(packet) }

            if packet.pointee.stream_index == videoStreamIndex {
                // Send packet to decoder
                guard avcodec_send_packet(videoCodecContext, packet) >= 0 else {
                    continue
                }

                // Receive decoded frames
                while avcodec_receive_frame(videoCodecContext, frame) >= 0 {
                    // Convert AVFrame to CVPixelBuffer
                    if let pixelBuffer = convertToCVPixelBuffer(frame: frame) {
                        let videoFrame = VideoFrame(
                            pixelBuffer: pixelBuffer,
                            timestamp: TimeInterval(frame.pointee.pts) * av_q2d(videoCodecContext.pointee.time_base),
                            duration: TimeInterval(frame.pointee.pkt_duration) * av_q2d(videoCodecContext.pointee.time_base)
                        )

                        continuation.yield(videoFrame)
                    }
                }
            }
        }

        continuation.finish()
    }

    private func convertToCVPixelBuffer(frame: UnsafeMutablePointer<AVFrame>) -> CVPixelBuffer? {
        let width = Int(frame.pointee.width)
        let height = Int(frame.pointee.height)

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        // Copy Y plane
        let yDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!
        let yDestStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let ySrc = frame.pointee.data.0!
        let ySrcStride = Int(frame.pointee.linesize.0)

        for row in 0..<height {
            let destRow = yDest.advanced(by: row * yDestStride)
            let srcRow = ySrc.advanced(by: row * ySrcStride)
            memcpy(destRow, srcRow, width)
        }

        // Copy UV plane
        let uvDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)!
        let uvDestStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        let uSrc = frame.pointee.data.1!
        let vSrc = frame.pointee.data.2!
        let uvSrcStride = Int(frame.pointee.linesize.1)

        for row in 0..<height/2 {
            let destRow = uvDest.advanced(by: row * uvDestStride)
            let uSrcRow = uSrc.advanced(by: row * uvSrcStride)
            let vSrcRow = vSrc.advanced(by: row * uvSrcStride)

            // Interleave U and V
            for col in 0..<width/2 {
                destRow.advanced(by: col * 2).storeBytes(of: uSrcRow.advanced(by: col).load(as: UInt8.self), as: UInt8.self)
                destRow.advanced(by: col * 2 + 1).storeBytes(of: vSrcRow.advanced(by: col).load(as: UInt8.self), as: UInt8.self)
            }
        }

        return buffer
    }

    func close() {
        if let videoCodecContext = videoCodecContext {
            avcodec_free_context(&videoCodecContext)
        }
        if let audioCodecContext = audioCodecContext {
            avcodec_free_context(&audioCodecContext)
        }
        if let formatContext = formatContext {
            avformat_close_input(&formatContext)
        }
    }

    deinit {
        close()
    }
}

enum FFmpegError: Error {
    case openFailed
    case streamInfoFailed
    case codecNotFound
    case codecAllocFailed
    case codecParamsFailed
    case codecOpenFailed
    case notOpen
}

struct VideoFrame {
    let pixelBuffer: CVPixelBuffer
    let timestamp: TimeInterval
    let duration: TimeInterval
}
```

---

## Challenge 4: Code Signing and Notarization

### Problem Statement

**Severity:** 🟡 Medium
**Complexity:** Low-Medium
**Impact:** High - Required for distribution

macOS Gatekeeper prevents unsigned or un-notarized apps from running on macOS 10.15+.

### Solution

**Step 1: Obtain Developer ID Certificate**
1. Join Apple Developer Program ($99/year)
2. Create Developer ID Application certificate
3. Download and install in Keychain

**Step 2: Configure Entitlements**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.usb</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

**Step 3: Sign Application**
```bash
#!/bin/bash

APP_PATH="build/BlackboxPlayer.app"
IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

# Sign all frameworks and libraries first
find "$APP_PATH/Contents/Frameworks" -name "*.dylib" -o -name "*.framework" | while read -r file; do
    codesign --force --verify --verbose --sign "$IDENTITY" --options runtime "$file"
done

# Sign the app bundle
codesign --deep --force --verify --verbose \
         --sign "$IDENTITY" \
         --options runtime \
         --entitlements "BlackboxPlayer.entitlements" \
         "$APP_PATH"

# Verify signature
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --verbose=4 --type execute "$APP_PATH"
```

**Step 4: Create DMG**
```bash
create-dmg \
  --volname "Blackbox Player" \
  --volicon "AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "BlackboxPlayer.app" 200 190 \
  --hide-extension "BlackboxPlayer.app" \
  --app-drop-link 600 185 \
  --background "dmg-background.png" \
  "BlackboxPlayer-1.0.0.dmg" \
  "$APP_PATH"
```

**Step 5: Notarize**
```bash
#!/bin/bash

DMG_PATH="BlackboxPlayer-1.0.0.dmg"
APPLE_ID="your@email.com"
TEAM_ID="TEAM_ID"

# Create app-specific password at appleid.apple.com

# Submit for notarization
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "app-specific-password" \
    --wait

# If successful, staple the notarization ticket
xcrun stapler staple "$DMG_PATH"

# Verify
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"
```

---

## Summary

These challenges represent the core technical hurdles of the project. By addressing them systematically with the provided solutions, we can build a robust and performant macOS dashcam viewer application.

**Priority Order:**
1. ✅ File system integration (Phase 0-1) - Foundation for file access
2. ✅ Video decoding (Phase 2) - Core functionality
3. ✅ Multi-channel sync (Phase 3) - Key differentiator
4. ✅ Code signing (Phase 6) - Required for distribution
