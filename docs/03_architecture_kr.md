# 아키텍처 설계

> 🌐 **Language**: [English](03_architecture.md) | [한국어](#)

## 시스템 아키텍처 개요

```
┌──────────────────────────────────────────────────────────┐
│                    프레젠테이션 계층                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐ │
│  │   SwiftUI   │ │   AppKit    │ │  Metal 렌더러       │ │
│  │   Views     │ │   Windows   │ │  (비디오 캔버스)     │ │
│  └─────────────┘ └─────────────┘ └─────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                            │
┌──────────────────────────────────────────────────────────┐
│                   애플리케이션 계층                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │     뷰 모델 (ObservableObject)                   │   │
│  │  - PlayerViewModel                               │   │
│  │  - FileListViewModel                             │   │
│  │  - SettingsViewModel                             │   │
│  │  - MapViewModel                                  │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                            │
┌──────────────────────────────────────────────────────────┐
│                    비즈니스 로직 계층                       │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │영상 플레이어  │ │파일 관리자   │ │데이터 처리      │  │
│  │서비스         │ │서비스         │ │서비스           │  │
│  └──────────────┘ └──────────────┘ └─────────────────┘  │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │GPS 서비스    │ │G-센서        │ │내보내기 서비스   │  │
│  │              │ │서비스         │ │                 │  │
│  └──────────────┘ └──────────────┘ └─────────────────┘  │
└──────────────────────────────────────────────────────────┘
                            │
┌──────────────────────────────────────────────────────────┐
│                      데이터 계층                           │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │영상 디코더   │ │음성 디코더   │ │메타데이터 파서   │  │
│  │(FFmpeg)      │ │(FFmpeg)      │ │                 │  │
│  └──────────────┘ └──────────────┘ └─────────────────┘  │
│  ┌─────────────────────────────────────────────────┐    │
│  │        EXT4 파일 시스템 액세스 계층              │    │
│  │     (Swift와 연결된 C/C++ 라이브러리 브리지)      │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## 디자인 패턴

### MVVM (Model-View-ViewModel)

**근거:**
- `@ObservableObject` 및 `@StateObject`와 함께 SwiftUI에 네이티브
- 명확한 관심사 분리
- 테스트 가능성
- 반응형 데이터 바인딩

**구현:**

```swift
// Model (모델)
struct VideoFile: Identifiable {
    let id: UUID
    let path: String
    let duration: TimeInterval
    let eventType: EventType
    let metadata: VideoMetadata
}

// ViewModel (뷰 모델)
class FileListViewModel: ObservableObject {
    @Published var files: [VideoFile] = []
    @Published var selectedEventType: EventType = .all

    private let fileManager: FileManagerService

    func loadFiles() async {
        files = await fileManager.fetchFiles(type: selectedEventType)
    }
}

// View (뷰)
struct FileListView: View {
    @StateObject var viewModel = FileListViewModel()

    var body: some View {
        List(viewModel.files) { file in
            FileRow(file: file)
        }
        .task {
            await viewModel.loadFiles()
        }
    }
}
```

### 의존성 주입 (Dependency Injection)

**근거:**
- 느슨한 결합
- 모의 서비스를 사용한 쉬운 테스트
- 유연한 구성

**구현:**

```swift
protocol VideoPlayerServiceProtocol {
    func play(channel: Int)
    func pause(channel: Int)
    func seek(to time: CMTime)
}

class PlayerViewModel: ObservableObject {
    private let playerService: VideoPlayerServiceProtocol

    init(playerService: VideoPlayerServiceProtocol = VideoPlayerService()) {
        self.playerService = playerService
    }
}
```

### 옵저버 패턴 (Observer Pattern)

**근거:**
- 실시간 UI 업데이트
- 분리된 컴포넌트
- SwiftUI의 반응형 특성

**구현:**

```swift
class PlaybackStateObserver {
    @Published var currentTime: CMTime = .zero
    @Published var isPlaying: Bool = false

    private var timeObserver: Any?

    func observe(player: AVPlayer) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time
        }
    }
}
```

## 모듈 아키텍처

### 1. 프레젠테이션 계층

#### 컴포넌트

**SwiftUI 뷰:**
```
Views/
├── ContentView.swift              # 메인 컨테이너
├── Player/
│   ├── VideoPlayerView.swift      # 다채널 플레이어
│   ├── ControlsView.swift         # 재생 제어
│   └── TimelineView.swift         # 영상 타임라인
├── FileList/
│   ├── FileListView.swift         # 파일 브라우저
│   ├── FileRow.swift              # 개별 파일 항목
│   └── EventFilterView.swift      # 이벤트 유형 필터
├── Map/
│   ├── GPSMapView.swift           # GPS 경로 표시
│   └── MapControlsView.swift      # 지도 제어
├── Charts/
│   └── GSensorChartView.swift     # G-센서 그래프
└── Settings/
    ├── SettingsView.swift         # 설정 패널
    └── SettingRowView.swift       # 개별 설정
```

**Metal 렌더러:**
```swift
class MetalVideoRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    func render(frames: [CVPixelBuffer], to view: MTKView) {
        // 커맨드 버퍼 생성
        // 픽셀 버퍼에서 텍스처 생성
        // 단일 패스로 모든 채널 렌더링
        // 화면에 표시
    }
}
```

### 2. 애플리케이션 계층

#### 뷰 모델

```swift
// 플레이어 뷰 모델
class PlayerViewModel: ObservableObject {
    @Published var channels: [VideoChannel] = []
    @Published var currentTime: CMTime = .zero
    @Published var isPlaying: Bool = false
    @Published var playbackRate: Float = 1.0

    private let playerService: VideoPlayerService

    func play() { /* ... */ }
    func pause() { /* ... */ }
    func seek(to time: CMTime) { /* ... */ }
    func setSpeed(_ rate: Float) { /* ... */ }
}

// 파일 목록 뷰 모델
class FileListViewModel: ObservableObject {
    @Published var files: [VideoFile] = []
    @Published var selectedFiles: Set<UUID> = []
    @Published var eventFilter: EventType = .all

    private let fileService: FileManagerService

    func loadFiles() async { /* ... */ }
    func exportSelected() async { /* ... */ }
    func deleteSelected() async { /* ... */ }
}

// 설정 뷰 모델
class SettingsViewModel: ObservableObject {
    @Published var settings: DashcamSettings

    private let settingsService: SettingsService

    func loadSettings() async { /* ... */ }
    func saveSettings() async { /* ... */ }
}
```

### 3. 비즈니스 로직 계층

#### 서비스 인터페이스

```swift
// 영상 플레이어 서비스
protocol VideoPlayerServiceProtocol {
    func loadVideo(url: URL, channel: Int) async throws
    func play(channel: Int?)
    func pause(channel: Int?)
    func seek(to time: CMTime)
    func setPlaybackRate(_ rate: Float)
}

class VideoPlayerService: VideoPlayerServiceProtocol {
    private var channels: [VideoChannel] = []
    private var syncController: SyncController

    // 구현...
}

// 파일 관리자 서비스
protocol FileManagerServiceProtocol {
    func mountSDCard(device: String) async throws
    func fetchFiles(type: EventType?) async throws -> [VideoFile]
    func readFile(at path: String) async throws -> Data
    func writeFile(data: Data, to path: String) async throws
}

class FileManagerService: FileManagerServiceProtocol {
    private let ext4Bridge: EXT4Bridge

    // 구현...
}

// 내보내기 서비스
protocol ExportServiceProtocol {
    func exportToMP4(files: [VideoFile], destination: URL) async throws
    func repairVideo(file: VideoFile) async throws -> URL
    func extractChannel(file: VideoFile, channel: Int) async throws -> URL
}

class ExportService: ExportServiceProtocol {
    private let ffmpegWrapper: FFmpegWrapper

    // 구현...
}

// GPS 서비스
protocol GPSServiceProtocol {
    func parseGPSData(from file: VideoFile) async throws -> [GPSPoint]
    func getRoute(for file: VideoFile) async throws -> [CLLocationCoordinate2D]
}

class GPSService: GPSServiceProtocol {
    private let metadataParser: MetadataParser

    // 구현...
}

// G-센서 서비스
protocol GSensorServiceProtocol {
    func parseGSensorData(from file: VideoFile) async throws -> [AccelerationData]
    func detectImpacts(data: [AccelerationData]) -> [ImpactEvent]
}

class GSensorService: GSensorServiceProtocol {
    private let metadataParser: MetadataParser

    // 구현...
}
```

### 4. 데이터 계층

#### 데이터 모델

```swift
// 영상 파일
struct VideoFile: Identifiable, Codable {
    let id: UUID
    let path: String
    let filename: String
    let size: Int64
    let duration: TimeInterval
    let eventType: EventType
    let createdAt: Date
    let metadata: VideoMetadata
}

enum EventType: String, Codable {
    case normal     // 일반
    case impact     // 충격
    case parking    // 주차
    case all        // 전체
}

// 영상 메타데이터
struct VideoMetadata: Codable {
    let resolution: CGSize
    let frameRate: Double
    let codec: String
    let bitrate: Int
    let channels: [ChannelInfo]
}

struct ChannelInfo: Codable {
    let index: Int
    let position: CameraPosition
    let hasAudio: Bool
}

enum CameraPosition: String, Codable {
    case front      // 전면
    case rear       // 후면
    case left       // 좌측
    case right      // 우측
    case interior   // 실내
}

// GPS 데이터
struct GPSPoint: Codable {
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let speed: Double
    let altitude: Double
    let heading: Double
}

// G-센서 데이터
struct AccelerationData: Codable {
    let timestamp: Date
    let x: Double
    let y: Double
    let z: Double
    let magnitude: Double
}

struct ImpactEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let magnitude: Double
    let duration: TimeInterval
}

// 블랙박스 설정
struct DashcamSettings: Codable {
    var resolution: VideoResolution
    var recordingMode: RecordingMode
    var parkingMode: Bool
    var impactSensitivity: Int
    var audioRecording: Bool
    var speedDisplay: Bool
}
```

#### EXT4 브리지

```swift
// Swift 인터페이스
class EXT4Bridge {
    private let wrapper: EXT4Wrapper

    func mount(device: String) throws {
        guard wrapper.mount(device) else {
            throw EXT4Error.mountFailed
        }
    }

    func readFile(at path: String) throws -> Data {
        guard let data = wrapper.readFile(atPath: path) else {
            throw EXT4Error.readFailed
        }
        return data
    }

    func listDirectory(at path: String) throws -> [FileInfo] {
        guard let list = wrapper.listDirectory(atPath: path) else {
            throw EXT4Error.listFailed
        }
        return list.map { FileInfo(from: $0) }
    }
}

enum EXT4Error: Error {
    case mountFailed    // 마운트 실패
    case readFailed     // 읽기 실패
    case writeFailed    // 쓰기 실패
    case listFailed     // 목록 실패
    case invalidPath    // 잘못된 경로
}
```

```objc
// Objective-C++ 래퍼 (EXT4Wrapper.h)
@interface EXT4Wrapper : NSObject

- (BOOL)mount:(NSString *)devicePath;
- (NSData *)readFileAtPath:(NSString *)path;
- (BOOL)writeData:(NSData *)data toPath:(NSString *)path;
- (NSArray<NSDictionary *> *)listDirectoryAtPath:(NSString *)path;
- (void)unmount;

@end
```

```cpp
// C++ 구현 (EXT4Wrapper.mm)
#import "EXT4Wrapper.h"
#include "ext4_library.hpp"

@implementation EXT4Wrapper {
    ext4_fs* filesystem;
}

- (BOOL)mount:(NSString *)devicePath {
    const char* path = [devicePath UTF8String];
    filesystem = ext4_mount(path);
    return filesystem != nullptr;
}

- (NSData *)readFileAtPath:(NSString *)path {
    const char* filepath = [path UTF8String];

    void* buffer;
    size_t size;

    if (ext4_read_file(filesystem, filepath, &buffer, &size) == 0) {
        return [NSData dataWithBytesNoCopy:buffer length:size];
    }

    return nil;
}

// ... 기타 메서드

@end
```

#### FFmpeg 래퍼

```swift
class FFmpegWrapper {
    func decodeVideo(url: URL) -> AsyncStream<VideoFrame> {
        AsyncStream { continuation in
            Task {
                var formatContext: UnsafeMutablePointer<AVFormatContext>?

                // 입력 파일 열기
                avformat_open_input(&formatContext, url.path, nil, nil)
                avformat_find_stream_info(formatContext, nil)

                // 영상 스트림 찾기
                let streamIndex = findVideoStream(formatContext)

                // 프레임 디코딩
                while let frame = decodeNextFrame(formatContext, streamIndex: streamIndex) {
                    continuation.yield(frame)
                }

                continuation.finish()
                avformat_close_input(&formatContext)
            }
        }
    }

    func exportToMP4(inputs: [URL], output: URL, progress: @escaping (Double) -> Void) async throws {
        // 여러 스트림을 단일 MP4로 먹싱
        // 콜백을 통해 진행 상황 보고
    }
}
```

## 스레딩 모델

### 스레드 아키텍처

```
메인 스레드 (UI)
    │
    ├── SwiftUI 뷰 업데이트
    ├── 사용자 상호작용
    └── Metal 렌더링

백그라운드 스레드
    │
    ├── 영상 디코딩 큐 (5개 채널)
    │   ├── 채널 1 디코더
    │   ├── 채널 2 디코더
    │   ├── 채널 3 디코더
    │   ├── 채널 4 디코더
    │   └── 채널 5 디코더
    │
    ├── 파일 I/O 큐
    │   └── EXT4 작업
    │
    ├── 내보내기 큐
    │   └── MP4 인코딩
    │
    └── 데이터 처리 큐
        ├── GPS 파싱
        └── G-센서 파싱
```

### 동시성 구현

```swift
actor VideoDecoder {
    private var isDecoding = false

    func decode(url: URL) async throws -> AsyncStream<VideoFrame> {
        guard !isDecoding else {
            throw DecoderError.alreadyDecoding
        }

        isDecoding = true
        defer { isDecoding = false }

        // 백그라운드 스레드에서 디코딩
        return await withCheckedContinuation { continuation in
            // FFmpeg 디코딩...
        }
    }
}

// 사용 예시
class VideoChannel {
    private let decoder: VideoDecoder

    func loadVideo(url: URL) async {
        for await frame in try await decoder.decode(url: url) {
            await MainActor.run {
                // 새 프레임으로 UI 업데이트
                self.currentFrame = frame
            }
        }
    }
}
```

## 데이터 흐름

### 재생 흐름

```
사용자 동작 (재생 버튼)
    ↓
PlayerViewModel.play()
    ↓
VideoPlayerService.play()
    ↓
SyncController.syncPlay()
    ↓
[채널 1..5].play()
    ↓
VideoDecoder.decode() (백그라운드)
    ↓
MetalRenderer.render() (메인 스레드)
    ↓
화면에 표시
```

### 내보내기 흐름

```
사용자가 파일 선택
    ↓
FileListViewModel.exportSelected()
    ↓
ExportService.exportToMP4()
    ↓
FFmpegWrapper.mux()
    ↓
콜백을 통한 진행 상황 업데이트
    ↓
완료 알림
```

## 메모리 관리

### 리소스 수명 주기

```swift
class VideoBuffer {
    private let maxBufferSize = 30 // 프레임
    private var frames: [VideoFrame] = []

    func addFrame(_ frame: VideoFrame) {
        frames.append(frame)

        // 오래된 프레임 제거
        if frames.count > maxBufferSize {
            let removed = frames.removeFirst()
            removed.release() // Metal 텍스처 해제
        }
    }
}

class VideoChannel {
    private var buffer: VideoBuffer

    deinit {
        // 리소스 정리
        buffer.clear()
        decoder.stop()
    }
}
```

### 메모리 모니터링

```swift
class MemoryMonitor {
    func checkMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }

        return 0
    }
}
```

## 오류 처리

### 오류 유형

```swift
enum PlayerError: Error {
    case fileNotFound           // 파일을 찾을 수 없음
    case unsupportedFormat      // 지원하지 않는 포맷
    case decodingFailed         // 디코딩 실패
    case syncLost               // 동기화 손실
    case insufficientMemory     // 메모리 부족
}

enum EXT4Error: Error {
    case mountFailed            // 마운트 실패
    case readFailed             // 읽기 실패
    case writeFailed            // 쓰기 실패
    case corruptedFileSystem    // 손상된 파일 시스템
}

enum ExportError: Error {
    case encodingFailed         // 인코딩 실패
    case insufficientSpace      // 공간 부족
    case cancelled              // 취소됨
}
```

### 오류 처리 전략

```swift
class VideoPlayerService {
    func loadVideo(url: URL) async throws {
        do {
            let data = try await fileService.readFile(at: url.path)
            let frames = try await decoder.decode(data)
            // ...
        } catch EXT4Error.readFailed {
            // 오류 로그 기록
            logger.error("파일 읽기 실패: \(url)")
            // 복구 시도
            try await repairFile(url)
        } catch DecoderError.unsupportedFormat {
            // 사용자 친화적 오류
            throw PlayerError.unsupportedFormat
        } catch {
            // 일반 오류
            throw PlayerError.decodingFailed
        }
    }
}
```

## 보안 고려사항

### 샌드박싱

```xml
<!-- Entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>

<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<key>com.apple.security.device.usb</key>
<true/>

<key>com.apple.security.network.client</key>
<true/> <!-- Google Maps용 -->
```

### 입력 검증

```swift
class FileValidator {
    func validateVideoFile(_ url: URL) throws {
        // 파일 확장자 확인
        guard url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "h264" else {
            throw ValidationError.invalidFileType
        }

        // 파일 크기 확인 (최대 4GB)
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        guard fileSize < 4_294_967_296 else {
            throw ValidationError.fileTooLarge
        }

        // 영상 헤더 검증
        let data = try Data(contentsOf: url, options: .mappedIfSafe).prefix(1024)
        guard isValidVideoHeader(data) else {
            throw ValidationError.corruptedFile
        }
    }
}
```

## 테스트 전략

### 단위 테스트

```swift
class VideoPlayerServiceTests: XCTestCase {
    var sut: VideoPlayerService!
    var mockFileService: MockFileService!

    override func setUp() {
        super.setUp()
        mockFileService = MockFileService()
        sut = VideoPlayerService(fileService: mockFileService)
    }

    func testPlayVideo() async throws {
        // Given (준비)
        let testURL = URL(fileURLWithPath: "/test/video.mp4")
        mockFileService.mockFile = VideoFile(id: UUID(), path: testURL.path, ...)

        // When (실행)
        try await sut.loadVideo(url: testURL)
        sut.play()

        // Then (검증)
        XCTAssertTrue(sut.isPlaying)
    }
}
```

### 통합 테스트

```swift
class EXT4IntegrationTests: XCTestCase {
    func testReadFromActualSDCard() throws {
        // 통합 테스트를 위해 실제 SD 카드 필요
        let bridge = EXT4Bridge()
        try bridge.mount(device: "/dev/disk2s1")

        let files = try bridge.listDirectory(at: "/DCIM")
        XCTAssertFalse(files.isEmpty)

        let data = try bridge.readFile(at: files[0].path)
        XCTAssertFalse(data.isEmpty)
    }
}
```

## 성능 최적화

### 지연 로딩 (Lazy Loading)

```swift
class FileListViewModel: ObservableObject {
    @Published var files: [VideoFile] = []
    private var allFiles: [VideoFile] = []

    func loadMoreFiles() {
        let nextBatch = Array(allFiles[files.count..<min(files.count + 50, allFiles.count)])
        files.append(contentsOf: nextBatch)
    }
}
```

### 캐싱

```swift
class ThumbnailCache {
    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(for file: VideoFile) async -> NSImage {
        let key = file.id.uuidString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let thumbnail = await generateThumbnail(file)
        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }
}
```

## 확장성

### 모듈 설계

- 각 서비스는 독립적이며 교체 가능
- 프로토콜 기반 설계로 쉬운 모킹 가능
- 명확한 관심사 분리로 병렬 개발 가능

### 향후 확장

- 클라우드 동기화 기능 (iCloud 통합)
- 블랙박스에서 실시간 스트리밍
- AI 기반 이벤트 감지
- 멀티플랫폼 지원 (iOS 컴패니언 앱)
