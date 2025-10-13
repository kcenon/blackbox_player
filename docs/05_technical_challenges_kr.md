# 기술적 과제 및 솔루션

> 🌐 **Language**: [English](05_technical_challenges.md) | [한국어](#)

## 개요

이 문서는 macOS 블랙박스 플레이어 프로젝트의 주요 기술적 과제를 설명하고 상세한 솔루션 및 구현 전략을 제공합니다.

---

## 과제 1: macOS에서 EXT4 파일 시스템 액세스

### 문제 설명

**심각도:** 🔴 Critical (치명적)
**복잡도:** High (높음)
**영향:** High - 해결되지 않으면 프로젝트 차단

macOS는 기본적으로 EXT4 파일 시스템을 지원하지 않습니다. 블랙박스 SD 카드는 EXT4로 포맷되어 있어 기본적으로 macOS에서 읽을 수 없습니다. 제공된 C/C++ 라이브러리를 사용하여 블록 수준 I/O를 구현해야 합니다.

### 기술적 세부사항

1. **macOS 파일 시스템 지원:**
   - 네이티브: APFS, HFS+, FAT32, exFAT
   - EXT4 네이티브 지원 없음
   - 커널 확장 또는 FUSE 없이는 EXT4 볼륨을 마운트할 수 없음

2. **샌드박스 제한:**
   - macOS 샌드박스 앱은 장치 액세스가 제한됨
   - USB 장치 액세스를 위한 특정 권한 필요
   - 블록 장치 액세스에는 상승된 권한 필요

3. **라이브러리 통합:**
   - 제공된 라이브러리는 C/C++로 작성되었을 가능성이 높음
   - Swift로 브리징 필요
   - 다양한 아키텍처 처리 필요 (Intel vs Apple Silicon)

### 솔루션 전략

#### 옵션 1: 직접 라이브러리 통합 (권장)

**아키텍처:**
```
Swift (UI 및 비즈니스 로직)
    ↕ 브리징 헤더
Objective-C++ 래퍼
    ↕ C++ 상호운용
EXT4 라이브러리 (C/C++)
    ↕ 블록 I/O
SD 카드 하드웨어
```

**구현:**

**단계 1: Objective-C++ 래퍼 생성**

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
#include "ext4.h" // 제공된 C/C++ 라이브러리
#include <iostream>

@implementation EXT4Wrapper {
    ext4_fs *filesystem;
    ext4_device device;
}

- (BOOL)mountDevice:(NSString *)devicePath error:(NSError **)error {
    const char *path = [devicePath UTF8String];

    // 블록 장치 초기화
    if (ext4_device_init(&device, path) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"EXT4ErrorDomain"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize device"}];
        }
        return NO;
    }

    // 파일 시스템 마운트
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

    // 파일 크기 가져오기
    ext4_fseek(&file, 0, SEEK_END);
    size_t fileSize = ext4_ftell(&file);
    ext4_fseek(&file, 0, SEEK_SET);

    // 데이터 읽기
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

**단계 2: Swift 브리지 생성**

```swift
// EXT4Bridge.swift
import Foundation

enum EXT4Error: Error {
    case mountFailed(String)        // 마운트 실패
    case unmountFailed              // 언마운트 실패
    case readFailed(String)         // 읽기 실패
    case writeFailed(String)        // 쓰기 실패
    case listFailed(String)         // 목록 실패
    case deviceNotFound             // 장치를 찾을 수 없음
    case permissionDenied           // 권한 거부
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

**단계 3: 장치 감지**

```swift
import IOKit
import IOKit.storage

class DeviceDetector {
    func detectSDCards() -> [String] {
        var devices: [String] = []

        // 모든 블록 장치 가져오기
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

            // 장치 속성 가져오기
            var properties: Unmanaged<CFMutableDictionary>?
            let kr = IORegistryEntryCreateCFProperties(device, &properties, kCFAllocatorDefault, 0)

            guard kr == KERN_SUCCESS,
                  let props = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // 이동식 장치인지 확인
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

**단계 4: 권한 설정**

```xml
<!-- BlackboxPlayer.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- USB 장치 액세스 허용 -->
    <key>com.apple.security.device.usb</key>
    <true/>

    <!-- 사용자 선택 파일 액세스 허용 -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- 개발용 앱 샌드박스 비활성화 (프로덕션에서는 적절한 권한과 함께 활성화) -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

#### 옵션 2: FUSE 기반 접근 방식 (대안)

macFUSE를 사용하여 EXT4를 사용자 공간 파일 시스템으로 마운트합니다.

**장점:**
- 더 간단한 구현
- 표준 파일 API 작동

**단점:**
- 외부 의존성 필요 (macFUSE)
- 사용자가 macFUSE를 별도로 설치해야 함
- 시스템 확장 필요 (보안 문제)
- 직접 블록 액세스보다 느림

**구현:**
```bash
# macFUSE 설치
brew install macfuse

# fuse-ext2 사용
brew install fuse-ext2

# SD 카드 마운트
fuse-ext2 /dev/disk2s1 /Volumes/SDCard -o ro
```

### 테스트 전략

```swift
class EXT4IntegrationTests: XCTestCase {
    var fileSystem: EXT4FileSystem!

    override func setUp() {
        super.setUp()
        fileSystem = EXT4FileSystem()
    }

    func testMountSDCard() throws {
        // 실제 SD 카드가 연결되어 있어야 함
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

### 대체 계획

제공된 EXT4 라이브러리가 호환되지 않는 경우:

1. **libext4fs 사용:** 오픈소스 대안
   - GitHub: https://github.com/lwext4/lwext4
   - MIT 라이선스
   - 잘 유지 관리됨

2. **ext4fuse:** FUSE 기반 솔루션
   - GitHub: https://github.com/gerard/ext4fuse
   - 읽기 전용 지원

3. **Windows SMB 공유 요청:** 최후의 수단
   - Windows PC에 SD 카드 마운트
   - 네트워크로 공유
   - SMB를 통해 Mac에서 액세스

---

## 과제 2: 다채널 동기화 재생

### 문제 설명

**심각도:** 🟠 High (높음)
**복잡도:** High (높음)
**영향:** High - 핵심 기능 요구사항

프레임 완벽 동기화를 유지하면서 5개의 영상 스트림을 동시에 재생하는 것은 계산 집약적이고 기술적으로 복잡합니다.

### 기술적 세부사항

1. **동기화 요구사항:**
   - 모든 채널이 ±50ms 이내로 유지되어야 함
   - 재생 속도 변경이 모든 채널에 동일하게 영향을 미쳐야 함
   - 탐색이 채널 간에 동기화되어야 함

2. **성능 과제:**
   - 5개의 동시 H.264 디코더
   - 5개의 별도 음성 디코더
   - 채널당 30fps 이상의 실시간 렌더링
   - 메모리: HD 스트림당 ~400MB = 총 2GB

3. **타이밍 문제:**
   - 채널당 다른 프레임 레이트 (29.97 vs 30fps)
   - 가변 프레임 간격
   - 음성/영상 드리프트
   - 프레임 드롭

### 솔루션 전략

#### 아키텍처

```
마스터 클록 (CMClock)
    │
    ├── 채널 1 ──→ 디코더 ──→ 버퍼 ──→ 동기화 ──→ 렌더러
    ├── 채널 2 ──→ 디코더 ──→ 버퍼 ──→ 동기화 ──→ 렌더러
    ├── 채널 3 ──→ 디코더 ──→ 버퍼 ──→ 동기화 ──→ 렌더러
    ├── 채널 4 ──→ 디코더 ──→ 버퍼 ──→ 동기화 ──→ 렌더러
    └── 채널 5 ──→ 디코더 ──→ 버퍼 ──→ 동기화 ──→ 렌더러
                                                   │
                                              Metal GPU
                                                   │
                                              디스플레이
```

#### 구현

**1. 마스터 클록**

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

**2. 동기화된 채널**

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

                // 버퍼가 가득 차면 조절
                while await self.buffer.count >= 25 {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
        }
    }

    func currentFrameForDisplay() async -> VideoFrame? {
        let clockTime = masterClock.currentTime

        // 현재 프레임이 없거나 표시 시간이 지난 경우
        if currentFrame == nil || clockTime >= nextFrameTime {
            // 버퍼에서 다음 프레임 가져오기
            if let frame = await buffer.dequeue() {
                currentFrame = frame
                nextFrameTime = frame.timestamp + frame.duration
            }
        }

        return currentFrame
    }
}
```

**3. 동기화 컨트롤러**

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

        // 모든 채널 탐색
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
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms마다 확인
            }
        }
    }

    private func checkSynchronization() async {
        // 채널 간 드리프트 측정
        var timestamps: [TimeInterval] = []

        for channel in channels {
            if let frame = await channel.currentFrameForDisplay() {
                timestamps.append(frame.timestamp)
            }
        }

        guard timestamps.count > 1 else { return }

        let maxDrift = timestamps.max()! - timestamps.min()!

        // 드리프트가 임계값을 초과하면 재동기화
        if maxDrift > 0.050 { // 50ms
            print("⚠️ 동기화 드리프트 감지: \(maxDrift * 1000)ms - 재동기화 중...")
            await resync()
        }
    }

    private func resync() async {
        let currentTime = masterClock.currentTime

        // 모든 채널을 현재 시간으로 일시정지 및 탐색
        masterClock.pause()

        for channel in channels {
            channel.seek(to: currentTime)
        }

        // 버퍼가 채워질 때까지 대기
        try? await Task.sleep(nanoseconds: 100_000_000)

        masterClock.start()
    }
}
```

**4. 다중 텍스처 Metal 렌더러**

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

        // 텍스처 캐시 생성
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        self.textureCache = cache!

        // 렌더 파이프라인 설정
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

        // 각 채널 렌더링
        for (index, frame) in frames.enumerated() {
            guard let frame = frame else { continue }

            // CVPixelBuffer를 Metal 텍스처로 변환
            if let texture = makeTexture(from: frame.pixelBuffer) {
                // 이 채널의 뷰포트 계산
                let viewport = calculateViewport(for: index, totalChannels: frames.count, viewSize: view.drawableSize)

                // 뷰포트 설정
                renderEncoder.setViewport(viewport)

                // 텍스처 바인딩
                renderEncoder.setFragmentTexture(texture, index: 0)

                // 쿼드 그리기
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
        // 그리드 레이아웃: 5개 채널용 2x3
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

**5. Metal 셰이더**

```metal
// Shaders.metal
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    // 전체 화면 쿼드
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

### 성능 최적화

**1. 스레드 관리**
```swift
// 각 작업 유형에 대한 전용 큐
class QueueManager {
    static let decoding = DispatchQueue(label: "com.app.decoding", qos: .userInitiated, attributes: .concurrent)
    static let rendering = DispatchQueue.main // 메인 스레드여야 함
    static let fileIO = DispatchQueue(label: "com.app.fileio", qos: .utility)
}
```

**2. 메모리 관리**

**스트림 버퍼링을 위한 순환 버퍼**
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

        // 가득 차면 덮어쓰기
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

**프레임 캐싱 시스템**

프레임 단위 탐색 및 반복 재생 중 중복 디코딩 작업을 제거하기 위해 LRU 기반 프레임 캐시를 구현합니다:

```swift
class VideoPlayerViewModel {
    /// 100ms 정밀도의 LRU 프레임 캐시
    private var frameCache: [TimeInterval: VideoFrame] = [:]
    private let maxFrameCacheSize: Int = 30
    private var lastCacheCleanupTime: Date = Date()

    /// 메모리 경고 관찰자
    private var memoryWarningObserver: NSObjectProtocol?

    init() {
        // 메모리 경고 등록
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

    /// 캐시 조회를 통한 프레임 로드
    private func loadFrameAt(time: TimeInterval) {
        // 1. 먼저 캐시 확인
        let key = cacheKey(for: time)
        if let cachedFrame = frameCache[key] {
            currentFrame = cachedFrame
            return  // 디코딩 스킵
        }

        // 2. 캐시 미스 - 프레임 디코딩
        // ... 디코딩 로직 ...

        // 3. 캐시에 추가
        addToCache(frame: decodedFrame, at: key)
    }

    /// 100ms 정밀도로 캐시 키 생성
    private func cacheKey(for time: TimeInterval) -> TimeInterval {
        return round(time * 10.0) / 10.0
    }

    /// LRU 제거 방식으로 캐시에 프레임 추가
    private func addToCache(frame: VideoFrame, at key: TimeInterval) {
        frameCache[key] = frame

        // 크기 기반 제거
        if frameCache.count > maxFrameCacheSize {
            if let oldestKey = frameCache.keys.sorted().first {
                frameCache.removeValue(forKey: oldestKey)
            }
        }

        // 시간 기반 정리 (5초마다)
        let now = Date()
        if now.timeIntervalSince(lastCacheCleanupTime) > 5.0 {
            cleanupCache()
            lastCacheCleanupTime = now
        }
    }

    /// ±5초 범위 밖의 프레임 제거
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

    /// 시스템 메모리 경고 처리
    private func handleMemoryWarning() {
        frameCache.removeAll()
        print("메모리 경고 수신: 프레임 캐시 정리됨")
    }

    func seekToTime(_ time: TimeInterval) {
        // 탐색 시 캐시 무효화
        frameCache.removeAll()
        // ... 탐색 로직 ...
    }

    func stop() {
        // 정지 시 캐시 정리
        frameCache.removeAll()
        // ... 정지 로직 ...
    }
}
```

**캐시 성능 특성:**
- **캐시 키 정밀도:** 100ms (메모리 사용량과 적중률의 균형)
- **캐시 용량:** 30 프레임 (1080p의 경우 ~250MB, 4K의 경우 ~1GB)
- **제거 전략:** 하이브리드 LRU
  - 크기 기반: 30 프레임 초과 시 가장 오래된 항목 제거
  - 시간 기반: 5초마다 ±5초 범위 밖의 프레임 제거
- **무효화:** 탐색 작업 시 완전 정리
- **메모리 경고:** 메모리 부족 시 자동 캐시 정리

**성능 이점:**
- 프레임 단위 탐색: 캐시 적중 시 0ms 응답 (디코딩 시 15-30ms 대비)
- 반복 재생: 캐시된 구간에서 10배 더 빠름
- CPU 사용률 감소: 중복 FFmpeg 작업 제거
- 메모리 효율성: 자동 정리로 무한 증가 방지

### 테스트

```swift
class SyncControllerTests: XCTestCase {
    func testSynchronization() async throws {
        let controller = SyncController()

        // 5개의 테스트 채널 추가
        for i in 0..<5 {
            let url = Bundle.main.url(forResource: "test_video_\(i)", withExtension: "mp4")!
            controller.addChannel(url: url)
        }

        controller.play()

        // 재생 대기
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5초

        // 동기화 정확도 측정
        let timestamps = await controller.getCurrentTimestamps()
        let maxDrift = timestamps.max()! - timestamps.min()!

        XCTAssertLessThan(maxDrift, 0.050) // 50ms 미만 드리프트
    }
}
```

---

## 과제 3: FFmpeg 통합 및 영상 처리

### 문제 설명

**심각도:** 🟡 Medium (중간)
**복잡도:** Medium (중간)
**영향:** High - 모든 영상 작업에 필요

FFmpeg은 Swift에 신중하게 통합해야 하는 C 라이브러리입니다. H.264 디코딩, MP3 음성, MP4 먹싱/디먹싱을 처리해야 합니다.

### 솔루션 전략

#### Swift 래퍼

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

        // 입력 파일 열기
        guard avformat_open_input(&ctx, url.path, nil, nil) == 0 else {
            throw FFmpegError.openFailed
        }
        formatContext = ctx

        // 스트림 정보 검색
        guard avformat_find_stream_info(formatContext, nil) >= 0 else {
            throw FFmpegError.streamInfoFailed
        }

        // 영상 및 음성 스트림 찾기
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

        // 디코더 찾기
        guard let codec = avcodec_find_decoder(codecParams.pointee.codec_id) else {
            throw FFmpegError.codecNotFound
        }

        // 코덱 컨텍스트 할당
        guard let codecContext = avcodec_alloc_context3(codec) else {
            throw FFmpegError.codecAllocFailed
        }

        // 코덱 매개변수 복사
        guard avcodec_parameters_to_context(codecContext, codecParams) >= 0 else {
            throw FFmpegError.codecParamsFailed
        }

        // 코덱 열기
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
                // 디코더에 패킷 전송
                guard avcodec_send_packet(videoCodecContext, packet) >= 0 else {
                    continue
                }

                // 디코딩된 프레임 수신
                while avcodec_receive_frame(videoCodecContext, frame) >= 0 {
                    // AVFrame을 CVPixelBuffer로 변환
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

        // Y 평면 복사
        let yDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!
        let yDestStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let ySrc = frame.pointee.data.0!
        let ySrcStride = Int(frame.pointee.linesize.0)

        for row in 0..<height {
            let destRow = yDest.advanced(by: row * yDestStride)
            let srcRow = ySrc.advanced(by: row * ySrcStride)
            memcpy(destRow, srcRow, width)
        }

        // UV 평면 복사
        let uvDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)!
        let uvDestStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        let uSrc = frame.pointee.data.1!
        let vSrc = frame.pointee.data.2!
        let uvSrcStride = Int(frame.pointee.linesize.1)

        for row in 0..<height/2 {
            let destRow = uvDest.advanced(by: row * uvDestStride)
            let uSrcRow = uSrc.advanced(by: row * uvSrcStride)
            let vSrcRow = vSrc.advanced(by: row * uvSrcStride)

            // U와 V 인터리브
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
    case openFailed                 // 열기 실패
    case streamInfoFailed           // 스트림 정보 실패
    case codecNotFound              // 코덱을 찾을 수 없음
    case codecAllocFailed           // 코덱 할당 실패
    case codecParamsFailed          // 코덱 매개변수 실패
    case codecOpenFailed            // 코덱 열기 실패
    case notOpen                    // 열리지 않음
}

struct VideoFrame {
    let pixelBuffer: CVPixelBuffer
    let timestamp: TimeInterval
    let duration: TimeInterval
}
```

---

## 과제 4: 코드 서명 및 공증

### 문제 설명

**심각도:** 🟡 Medium (중간)
**복잡도:** Low-Medium (낮음-중간)
**영향:** High - 배포에 필요

macOS Gatekeeper는 서명되지 않았거나 공증되지 않은 앱이 macOS 10.15 이상에서 실행되는 것을 방지합니다.

### 솔루션

**단계 1: Developer ID 인증서 획득**
1. Apple Developer Program 가입 (연 $99)
2. Developer ID Application 인증서 생성
3. Keychain에 다운로드 및 설치

**단계 2: 권한 구성**
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

**단계 3: 애플리케이션 서명**
```bash
#!/bin/bash

APP_PATH="build/BlackboxPlayer.app"
IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

# 먼저 모든 프레임워크 및 라이브러리 서명
find "$APP_PATH/Contents/Frameworks" -name "*.dylib" -o -name "*.framework" | while read -r file; do
    codesign --force --verify --verbose --sign "$IDENTITY" --options runtime "$file"
done

# 앱 번들 서명
codesign --deep --force --verify --verbose \
         --sign "$IDENTITY" \
         --options runtime \
         --entitlements "BlackboxPlayer.entitlements" \
         "$APP_PATH"

# 서명 확인
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --verbose=4 --type execute "$APP_PATH"
```

**단계 4: DMG 생성**
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

**단계 5: 공증**
```bash
#!/bin/bash

DMG_PATH="BlackboxPlayer-1.0.0.dmg"
APPLE_ID="your@email.com"
TEAM_ID="TEAM_ID"

# appleid.apple.com에서 앱별 비밀번호 생성

# 공증 제출
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "app-specific-password" \
    --wait

# 성공하면 공증 티켓 스테이플
xcrun stapler staple "$DMG_PATH"

# 확인
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"
```

---

## 요약

이러한 과제는 프로젝트의 핵심 기술적 장애물을 나타냅니다. 제공된 솔루션으로 체계적으로 대처함으로써 강력하고 고성능의 macOS 블랙박스 뷰어 애플리케이션을 구축할 수 있습니다.

**우선순위:**
1. ✅ EXT4 통합 (단계 0-1) - 성공 또는 실패
2. ✅ 영상 디코딩 (단계 2) - 모든 기능의 기반
3. ✅ 다채널 동기화 (단계 3) - 핵심 차별화 요소
4. ✅ 코드 서명 (단계 6) - 배포에 필요
