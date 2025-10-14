# 기술적 과제 및 솔루션

> 🌐 **Language**: [English](05_technical_challenges.md) | [한국어](#)

## 개요

이 문서는 macOS 블랙박스 플레이어 프로젝트의 주요 기술적 과제를 설명하고 상세한 솔루션 및 구현 전략을 제공합니다.

---

## 과제 1: macOS에서 SD 카드 파일 시스템 액세스

### 문제 설명

**심각도:** 🟡 Medium (중간)
**복잡도:** Medium (중간)
**영향:** Medium - 네이티브 API로 관리 가능

블랙박스 SD 카드에 효율적으로 액세스하여 영상 파일과 메타데이터를 읽어야 합니다. USB 장치 감지 및 파일 권한을 올바르게 처리하면서 macOS 네이티브 API (FileManager 및 IOKit)를 사용하여 안정적인 파일 시스템 액세스를 구현해야 합니다.

### 기술적 세부사항

1. **macOS 파일 시스템 지원:**
   - 네이티브: APFS, HFS+, FAT32, exFAT
   - SD 카드는 일반적으로 FAT32 또는 exFAT으로 포맷됨
   - FileManager를 통한 직접 지원

2. **샌드박스 제한:**
   - macOS 샌드박스 앱은 장치 액세스가 제한됨
   - USB 장치 액세스를 위한 특정 권한 필요
   - 사용자는 파일 선택기 또는 드래그 앤 드롭을 통해 권한을 부여해야 함

3. **네이티브 API 통합:**
   - 파일 작업을 위한 FileManager
   - USB 장치 감지를 위한 IOKit
   - 순수 Swift 구현 - 브리징 불필요
   - Intel 및 Apple Silicon 모두 네이티브 지원

### 솔루션 전략

#### 옵션 1: FileManager + IOKit 통합 (권장)

**아키텍처:**
```
Swift (UI 및 비즈니스 로직)
    ↕ 네이티브 Swift API
FileSystemService
    ↕ Foundation 프레임워크
FileManager + IOKit
    ↕ macOS 커널
SD 카드 하드웨어 (FAT32/exFAT)
```

**구현:**

**단계 1: FileSystemService 생성**

```swift
// FileSystemService.swift
import Foundation

enum FileSystemError: Error {
    case accessDenied           // 액세스 거부
    case readFailed(String)     // 읽기 실패
    case writeFailed(String)    // 쓰기 실패
    case listFailed(String)     // 목록 실패
    case deviceNotFound         // 장치를 찾을 수 없음
    case permissionDenied       // 권한 거부
    case fileNotFound           // 파일을 찾을 수 없음
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
                throw FileSystemError.writeFailed("\(url.lastPathComponent) 삭제 실패: \(error.localizedDescription)")
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

**단계 2: IOKit을 사용한 장치 감지**

```swift
import IOKit
import IOKit.storage
import DiskArbitration

class DeviceDetector {
    func detectSDCards() -> [URL] {
        var mountedVolumes: [URL] = []

        // 마운트된 모든 볼륨 가져오기
        if let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) {
            for url in urls {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])

                    // 이동식 장치(SD 카드 등)인지 확인
                    if let isRemovable = resourceValues.volumeIsRemovable,
                       let isEjectable = resourceValues.volumeIsEjectable,
                       isRemovable && isEjectable {
                        mountedVolumes.append(url)
                    }
                } catch {
                    print("볼륨 속성 확인 오류: \(error)")
                }
            }
        }

        return mountedVolumes
    }

    func monitorDeviceChanges(onConnect: @escaping (URL) -> Void, onDisconnect: @escaping (URL) -> Void) {
        // 볼륨 마운트/언마운트 알림 모니터링
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

**단계 3: 파일 선택기 통합**

```swift
import SwiftUI
import AppKit

struct FilePicker: View {
    @Binding var selectedFolder: URL?

    var body: some View {
        Button("SD 카드 폴더 선택") {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "블랙박스 SD 카드 폴더를 선택하세요"

            if panel.runModal() == .OK {
                selectedFolder = panel.url
            }
        }
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

    <!-- 이동식 볼륨 읽기/쓰기 액세스 허용 -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>

    <!-- 앱 샌드박스 활성화 -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

### 테스트 전략

```swift
class FileSystemIntegrationTests: XCTestCase {
    var fileSystemService: FileSystemService!
    var testVolumeURL: URL!

    override func setUp() {
        super.setUp()
        fileSystemService = FileSystemService()

        // 테스트 SD 카드 또는 모의 볼륨 사용
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
            XCTFail("파일을 찾을 수 없음")
            return
        }

        let fileInfo = try fileSystemService.getFileInfo(at: firstFile)
        XCTAssertEqual(fileInfo.name, firstFile.lastPathComponent)
        XCTAssertGreaterThan(fileInfo.size, 0)
    }

    func testReadVideoFile() throws {
        let files = try fileSystemService.listVideoFiles(at: testVolumeURL)
        guard let videoFile = files.first else {
            XCTFail("영상 파일을 찾을 수 없음")
            return
        }

        let data = try fileSystemService.readFile(at: videoFile)
        XCTAssertGreaterThan(data.count, 0)
    }
}
```

### 대체 계획

SD 카드 파일 시스템이 호환되지 않거나 액세스할 수 없는 경우:

1. **수동 폴더 선택:** 주요 대체 방법
   - NSOpenPanel을 사용하여 사용자가 폴더 선택
   - 마운트된 모든 볼륨에서 작동
   - 특별한 권한 불필요

2. **드래그 앤 드롭 지원:** 사용자 친화적 대안
   - 사용자가 SD 카드 폴더를 앱으로 드래그
   - 자동 파일 시스템 액세스
   - 직관적인 UX

3. **네트워크 공유 액세스:** 원격 시나리오용
   - SMB/AFP 네트워크 공유 지원
   - 다른 컴퓨터에 마운트된 SD 카드 액세스
   - 팀 환경에 유용

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
1. ✅ 파일 시스템 통합 (단계 0-1) - 파일 액세스 기반
2. ✅ 영상 디코딩 (단계 2) - 핵심 기능
3. ✅ 다채널 동기화 (단계 3) - 주요 차별화 요소
4. ✅ 코드 서명 (단계 6) - 배포에 필요
