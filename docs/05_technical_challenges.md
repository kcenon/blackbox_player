# Technical Challenges and Solutions

> 🌐 **Language**: [English](#) | [한국어](05_technical_challenges_kr.md)

## Overview

This document outlines the major technical challenges for the macOS Blackbox Player project and provides detailed solutions and implementation strategies.

---

## Challenge 1: EXT4 File System Access on macOS

### Problem Statement

**Severity:** 🔴 Critical
**Complexity:** High
**Impact:** High - Project blocker if unsolved

macOS does not natively support EXT4 file systems. The dashcam SD cards are formatted with EXT4, making them unreadable by default on macOS. We must implement block-level I/O using a provided C/C++ library.

### Technical Details

1. **macOS File System Support:**
   - Native: APFS, HFS+, FAT32, exFAT
   - No native EXT4 support
   - Cannot mount EXT4 volumes without kernel extensions or FUSE

2. **Sandbox Restrictions:**
   - macOS sandboxed apps have limited device access
   - Need specific entitlements for USB device access
   - Block device access requires elevated privileges

3. **Library Integration:**
   - Provided library likely written in C/C++
   - Need to bridge to Swift
   - Must handle different architectures (Intel vs Apple Silicon)

### Solution Strategy

#### Option 1: Direct Library Integration (Recommended)

**Architecture:**
```
Swift (UI & Business Logic)
    ↕ Bridging Header
Objective-C++ Wrapper
    ↕ C++ Interop
EXT4 Library (C/C++)
    ↕ Block I/O
SD Card Hardware
```

**Implementation:**

**Step 1: Create Objective-C++ Wrapper**

```objc
// EXT4Wrapper.h
#import <Foundation/Foundation.h>

@interface EXT4Wrapper : NSObject

- (BOOL)mountDevice:(NSString *)devicePath error:(NSError **)error;
- (void)unmount;
- (NSData *)readFileAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)writeData:(NSData *)data toPath:(NSString *)path error:(NSError **)error;
- (NSArray<NSDictionary *> *)listDirectoryAtPath:(NSString *)path error:(NSError **)error;

@end
```

```cpp
// EXT4Wrapper.mm (Objective-C++)
#import "EXT4Wrapper.h"
#include "ext4.h" // Provided C/C++ library
#include <iostream>

@implementation EXT4Wrapper {
    ext4_fs *filesystem;
    ext4_device device;
}

- (BOOL)mountDevice:(NSString *)devicePath error:(NSError **)error {
    const char *path = [devicePath UTF8String];

    // Initialize block device
    if (ext4_device_init(&device, path) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"EXT4ErrorDomain"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize device"}];
        }
        return NO;
    }

    // Mount filesystem
    if (ext4_mount(&device, "/", false) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"EXT4ErrorDomain"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to mount filesystem"}];
        }
        return NO;
    }

    return YES;
}

- (void)unmount {
    if (filesystem) {
        ext4_umount("/");
        ext4_device_fini(&device);
        filesystem = nullptr;
    }
}

- (NSData *)readFileAtPath:(NSString *)path error:(NSError **)error {
    const char *filepath = [path UTF8String];

    ext4_file file;
    if (ext4_fopen(&file, filepath, "rb") != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"EXT4ErrorDomain"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to open file"}];
        }
        return nil;
    }

    // Get file size
    ext4_fseek(&file, 0, SEEK_END);
    size_t fileSize = ext4_ftell(&file);
    ext4_fseek(&file, 0, SEEK_SET);

    // Read data
    void *buffer = malloc(fileSize);
    size_t bytesRead;
    ext4_fread(&file, buffer, fileSize, &bytesRead);
    ext4_fclose(&file);

    NSData *data = [NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:YES];
    return data;
}

- (NSArray<NSDictionary *> *)listDirectoryAtPath:(NSString *)path error:(NSError **)error {
    const char *dirpath = [path UTF8String];

    ext4_dir dir;
    if (ext4_dir_open(&dir, dirpath) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"EXT4ErrorDomain"
                                         code:3001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to open directory"}];
        }
        return nil;
    }

    NSMutableArray *files = [NSMutableArray array];
    const ext4_direntry *entry;

    while ((entry = ext4_dir_entry_next(&dir)) != NULL) {
        NSString *name = [NSString stringWithUTF8String:(const char *)entry->name];

        NSDictionary *fileInfo = @{
            @"name": name,
            @"size": @(entry->inode_size),
            @"isDirectory": @(entry->inode_type == EXT4_DE_DIR)
        };

        [files addObject:fileInfo];
    }

    ext4_dir_close(&dir);
    return files;
}

@end
```

**Step 2: Create Swift Bridge**

```swift
// EXT4Bridge.swift
import Foundation

enum EXT4Error: Error {
    case mountFailed(String)
    case unmountFailed
    case readFailed(String)
    case writeFailed(String)
    case listFailed(String)
    case deviceNotFound
    case permissionDenied
}

class EXT4FileSystem {
    private let wrapper = EXT4Wrapper()
    private var isMounted = false
    private var currentDevice: String?

    func mount(device: String) throws {
        var error: NSError?
        let success = wrapper.mountDevice(device, error: &error)

        if !success {
            throw EXT4Error.mountFailed(error?.localizedDescription ?? "Unknown error")
        }

        isMounted = true
        currentDevice = device
    }

    func unmount() {
        wrapper.unmount()
        isMounted = false
        currentDevice = nil
    }

    func readFile(at path: String) throws -> Data {
        guard isMounted else {
            throw EXT4Error.readFailed("Filesystem not mounted")
        }

        var error: NSError?
        guard let data = wrapper.readFile(atPath: path, error: &error) else {
            throw EXT4Error.readFailed(error?.localizedDescription ?? "Unknown error")
        }

        return data
    }

    func listDirectory(at path: String) throws -> [FileInfo] {
        guard isMounted else {
            throw EXT4Error.listFailed("Filesystem not mounted")
        }

        var error: NSError?
        guard let list = wrapper.listDirectory(atPath: path, error: &error) else {
            throw EXT4Error.listFailed(error?.localizedDescription ?? "Unknown error")
        }

        return list.map { dict in
            FileInfo(
                name: dict["name"] as! String,
                size: dict["size"] as! Int64,
                isDirectory: dict["isDirectory"] as! Bool,
                path: "\(path)/\(dict["name"] as! String)"
            )
        }
    }
}

struct FileInfo {
    let name: String
    let size: Int64
    let isDirectory: Bool
    let path: String
}
```

**Step 3: Device Detection**

```swift
import IOKit
import IOKit.storage

class DeviceDetector {
    func detectSDCards() -> [String] {
        var devices: [String] = []

        // Get all block devices
        let matching = IOServiceMatching(kIOMediaClass)
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return devices }

        defer { IOObjectRelease(iterator) }

        var device: io_object_t = IOIteratorNext(iterator)
        while device != 0 {
            defer {
                IOObjectRelease(device)
                device = IOIteratorNext(iterator)
            }

            // Get device properties
            var properties: Unmanaged<CFMutableDictionary>?
            let kr = IORegistryEntryCreateCFProperties(device, &properties, kCFAllocatorDefault, 0)

            guard kr == KERN_SUCCESS,
                  let props = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Check if it's a removable device
            if let removable = props["Removable"] as? Bool,
               removable,
               let bsdName = props["BSD Name"] as? String {
                devices.append("/dev/\(bsdName)")
            }
        }

        return devices
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

    <!-- Disable App Sandbox for development (enable for production with proper entitlements) -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

#### Option 2: FUSE-based Approach (Alternative)

Use macFUSE to mount EXT4 as a user-space filesystem.

**Pros:**
- Simpler implementation
- Standard file APIs work

**Cons:**
- Requires external dependency (macFUSE)
- User must install macFUSE separately
- System extension required (security concerns)
- Slower than direct block access

**Implementation:**
```bash
# Install macFUSE
brew install macfuse

# Use fuse-ext2
brew install fuse-ext2

# Mount SD card
fuse-ext2 /dev/disk2s1 /Volumes/SDCard -o ro
```

### Testing Strategy

```swift
class EXT4IntegrationTests: XCTestCase {
    var fileSystem: EXT4FileSystem!

    override func setUp() {
        super.setUp()
        fileSystem = EXT4FileSystem()
    }

    func testMountSDCard() throws {
        // Requires actual SD card connected
        try fileSystem.mount(device: "/dev/disk2s1")
        XCTAssertTrue(fileSystem.isMounted)
    }

    func testListRootDirectory() throws {
        try fileSystem.mount(device: "/dev/disk2s1")

        let files = try fileSystem.listDirectory(at: "/")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.name == "DCIM" })
    }

    func testReadVideoFile() throws {
        try fileSystem.mount(device: "/dev/disk2s1")

        let data = try fileSystem.readFile(at: "/DCIM/video.h264")
        XCTAssertGreaterThan(data.count, 0)
    }
}
```

### Fallback Plan

If provided EXT4 library is incompatible:

1. **Use libext4fs:** Open-source alternative
   - GitHub: https://github.com/lwext4/lwext4
   - MIT License
   - Well-maintained

2. **ext4fuse:** FUSE-based solution
   - GitHub: https://github.com/gerard/ext4fuse
   - Read-only support

3. **Request Windows SMB Share:** As last resort
   - Mount SD card on Windows PC
   - Share over network
   - Access from Mac via SMB

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
1. ✅ EXT4 integration (Phase 0-1) - Make or break
2. ✅ Video decoding (Phase 2) - Foundation for all features
3. ✅ Multi-channel sync (Phase 3) - Core differentiator
4. ✅ Code signing (Phase 6) - Required for distribution
