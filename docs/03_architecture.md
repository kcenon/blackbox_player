# Architecture Design

> 🌐 **Language**: [English](#) | [한국어](03_architecture_kr.md)

## System Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐ │
│  │   SwiftUI   │ │   AppKit    │ │  Metal Renderer     │ │
│  │   Views     │ │   Windows   │ │  (Video Canvas)     │ │
│  └─────────────┘ └─────────────┘ └─────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                            │
┌──────────────────────────────────────────────────────────┐
│                   Application Layer                       │
│  ┌──────────────────────────────────────────────────┐   │
│  │         View Models (ObservableObject)           │   │
│  │  - PlayerViewModel                               │   │
│  │  - FileListViewModel                             │   │
│  │  - SettingsViewModel                             │   │
│  │  - MapViewModel                                  │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                            │
┌──────────────────────────────────────────────────────────┐
│                    Business Logic Layer                   │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │Video Player  │ │File Manager  │ │Data Processor   │  │
│  │Service       │ │Service       │ │Service          │  │
│  └──────────────┘ └──────────────┘ └─────────────────┘  │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │GPS Service   │ │G-Sensor      │ │Export Service   │  │
│  │              │ │Service       │ │                 │  │
│  └──────────────┘ └──────────────┘ └─────────────────┘  │
└──────────────────────────────────────────────────────────┘
                            │
┌──────────────────────────────────────────────────────────┐
│                      Data Layer                           │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│  │Video Decoder │ │Audio Decoder │ │Metadata Parser  │  │
│  │(FFmpeg)      │ │(FFmpeg)      │ │                 │  │
│  └──────────────┘ └──────────────┘ └─────────────────┘  │
│  ┌─────────────────────────────────────────────────┐    │
│  │          File System Access Layer               │    │
│  │          (FileManager + IOKit)                  │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Design Patterns

### MVVM (Model-View-ViewModel)

**Rationale:**
- Native to SwiftUI with `@ObservableObject` and `@StateObject`
- Clear separation of concerns
- Testability
- Reactive data binding

**Implementation:**

```swift
// Model
struct VideoFile: Identifiable {
    let id: UUID
    let path: String
    let duration: TimeInterval
    let eventType: EventType
    let metadata: VideoMetadata
}

// ViewModel
class FileListViewModel: ObservableObject {
    @Published var files: [VideoFile] = []
    @Published var selectedEventType: EventType = .all

    private let fileManager: FileManagerService

    func loadFiles() async {
        files = await fileManager.fetchFiles(type: selectedEventType)
    }
}

// View
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

### Dependency Injection

**Rationale:**
- Loose coupling
- Easy testing with mock services
- Flexible configuration

**Implementation:**

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

### Observer Pattern

**Rationale:**
- Real-time UI updates
- Decoupled components
- SwiftUI's reactive nature

**Implementation:**

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

## Module Architecture

### 1. Presentation Layer

#### Components

**SwiftUI Views:**
```
Views/
├── ContentView.swift              # Main container
├── Player/
│   ├── VideoPlayerView.swift      # Multi-channel player
│   ├── ControlsView.swift         # Playback controls
│   └── TimelineView.swift         # Video timeline
├── FileList/
│   ├── FileListView.swift         # File browser
│   ├── FileRow.swift              # Individual file item
│   └── EventFilterView.swift      # Event type filter
├── Map/
│   ├── GPSMapView.swift           # GPS route display
│   └── MapControlsView.swift      # Map controls
├── Charts/
│   └── GSensorChartView.swift     # G-Sensor graph
└── Settings/
    ├── SettingsView.swift         # Settings panel
    └── SettingRowView.swift       # Individual setting
```

**Metal Renderer:**
```swift
class MetalVideoRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    func render(frames: [CVPixelBuffer], to view: MTKView) {
        // Create command buffer
        // Create textures from pixel buffers
        // Render all channels in single pass
        // Present to screen
    }
}
```

### 2. Application Layer

#### View Models

```swift
// Player ViewModel
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

// File List ViewModel
class FileListViewModel: ObservableObject {
    @Published var files: [VideoFile] = []
    @Published var selectedFiles: Set<UUID> = []
    @Published var eventFilter: EventType = .all

    private let fileService: FileManagerService

    func loadFiles() async { /* ... */ }
    func exportSelected() async { /* ... */ }
    func deleteSelected() async { /* ... */ }
}

// Settings ViewModel
class SettingsViewModel: ObservableObject {
    @Published var settings: DashcamSettings

    private let settingsService: SettingsService

    func loadSettings() async { /* ... */ }
    func saveSettings() async { /* ... */ }
}
```

### 3. Business Logic Layer

#### Service Interfaces

```swift
// Video Player Service
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

    // Implementation...
}

// File Manager Service
protocol FileManagerServiceProtocol {
    func mountSDCard(device: String) async throws
    func fetchFiles(type: EventType?) async throws -> [VideoFile]
    func readFile(at path: String) async throws -> Data
    func writeFile(data: Data, to path: String) async throws
}

class FileManagerService: FileManagerServiceProtocol {
    private let fileManager: FileManager

    // Implementation...
}

// Export Service
protocol ExportServiceProtocol {
    func exportToMP4(files: [VideoFile], destination: URL) async throws
    func repairVideo(file: VideoFile) async throws -> URL
    func extractChannel(file: VideoFile, channel: Int) async throws -> URL
}

class ExportService: ExportServiceProtocol {
    private let ffmpegWrapper: FFmpegWrapper

    // Implementation...
}

// GPS Service
protocol GPSServiceProtocol {
    func parseGPSData(from file: VideoFile) async throws -> [GPSPoint]
    func getRoute(for file: VideoFile) async throws -> [CLLocationCoordinate2D]
}

class GPSService: GPSServiceProtocol {
    private let metadataParser: MetadataParser

    // Implementation...
}

// G-Sensor Service
protocol GSensorServiceProtocol {
    func parseGSensorData(from file: VideoFile) async throws -> [AccelerationData]
    func detectImpacts(data: [AccelerationData]) -> [ImpactEvent]
}

class GSensorService: GSensorServiceProtocol {
    private let metadataParser: MetadataParser

    // Implementation...
}
```

### 4. Data Layer

#### Data Models

```swift
// Video File
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
    case normal
    case impact
    case parking
    case all
}

// Video Metadata
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
    case front
    case rear
    case left
    case right
    case interior
}

// GPS Data
struct GPSPoint: Codable {
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let speed: Double
    let altitude: Double
    let heading: Double
}

// G-Sensor Data
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

// Dashcam Settings
struct DashcamSettings: Codable {
    var resolution: VideoResolution
    var recordingMode: RecordingMode
    var parkingMode: Bool
    var impactSensitivity: Int
    var audioRecording: Bool
    var speedDisplay: Bool
}
```

#### File System Service

```swift
// FileManager-based file system access
class FileSystemService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func listVideoFiles(at url: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey]
        ) else {
            throw FileSystemError.accessDenied
        }

        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "mp4" || $0.pathExtension == "avi" }
    }

    func readFile(at url: URL) throws -> Data {
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw FileSystemError.readFailed
        }
        return try Data(contentsOf: url)
    }

    func getFileInfo(at url: URL) throws -> FileInfo {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return FileInfo(
            path: url.path,
            size: attributes[.size] as? Int64 ?? 0,
            createdAt: attributes[.creationDate] as? Date ?? Date()
        )
    }
}

enum FileSystemError: Error {
    case accessDenied
    case readFailed
    case writeFailed
    case invalidPath
    case deviceNotFound
}

struct FileInfo {
    let path: String
    let size: Int64
    let createdAt: Date
}
```

#### FFmpeg Wrapper

```swift
class FFmpegWrapper {
    func decodeVideo(url: URL) -> AsyncStream<VideoFrame> {
        AsyncStream { continuation in
            Task {
                var formatContext: UnsafeMutablePointer<AVFormatContext>?

                // Open input file
                avformat_open_input(&formatContext, url.path, nil, nil)
                avformat_find_stream_info(formatContext, nil)

                // Find video stream
                let streamIndex = findVideoStream(formatContext)

                // Decode frames
                while let frame = decodeNextFrame(formatContext, streamIndex: streamIndex) {
                    continuation.yield(frame)
                }

                continuation.finish()
                avformat_close_input(&formatContext)
            }
        }
    }

    func exportToMP4(inputs: [URL], output: URL, progress: @escaping (Double) -> Void) async throws {
        // Mux multiple streams into single MP4
        // Report progress via callback
    }
}
```

## Threading Model

### Thread Architecture

```
Main Thread (UI)
    │
    ├── SwiftUI View Updates
    ├── User Interaction
    └── Metal Rendering

Background Threads
    │
    ├── Video Decoding Queue (5 channels)
    │   ├── Channel 1 Decoder
    │   ├── Channel 2 Decoder
    │   ├── Channel 3 Decoder
    │   ├── Channel 4 Decoder
    │   └── Channel 5 Decoder
    │
    ├── File I/O Queue
    │   └── File System Operations
    │
    ├── Export Queue
    │   └── MP4 Encoding
    │
    └── Data Processing Queue
        ├── GPS Parsing
        └── G-Sensor Parsing
```

### Concurrency Implementation

```swift
actor VideoDecoder {
    private var isDecoding = false

    func decode(url: URL) async throws -> AsyncStream<VideoFrame> {
        guard !isDecoding else {
            throw DecoderError.alreadyDecoding
        }

        isDecoding = true
        defer { isDecoding = false }

        // Decode on background thread
        return await withCheckedContinuation { continuation in
            // FFmpeg decoding...
        }
    }
}

// Usage
class VideoChannel {
    private let decoder: VideoDecoder

    func loadVideo(url: URL) async {
        for await frame in try await decoder.decode(url: url) {
            await MainActor.run {
                // Update UI with new frame
                self.currentFrame = frame
            }
        }
    }
}
```

## Data Flow

### Playback Flow

```
User Action (Play Button)
    ↓
PlayerViewModel.play()
    ↓
VideoPlayerService.play()
    ↓
SyncController.syncPlay()
    ↓
[Channel 1..5].play()
    ↓
VideoDecoder.decode() (Background)
    ↓
MetalRenderer.render() (Main Thread)
    ↓
Display on Screen
```

### Export Flow

```
User Selects Files
    ↓
FileListViewModel.exportSelected()
    ↓
ExportService.exportToMP4()
    ↓
FFmpegWrapper.mux()
    ↓
Progress Updates via Callback
    ↓
Completion Notification
```

## Memory Management

### Resource Lifecycle

```swift
class VideoBuffer {
    private let maxBufferSize = 30 // frames
    private var frames: [VideoFrame] = []

    func addFrame(_ frame: VideoFrame) {
        frames.append(frame)

        // Remove old frames
        if frames.count > maxBufferSize {
            let removed = frames.removeFirst()
            removed.release() // Release Metal texture
        }
    }
}

class VideoChannel {
    private var buffer: VideoBuffer

    deinit {
        // Clean up resources
        buffer.clear()
        decoder.stop()
    }
}
```

### Memory Monitoring

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

## Error Handling

### Error Types

```swift
enum PlayerError: Error {
    case fileNotFound
    case unsupportedFormat
    case decodingFailed
    case syncLost
    case insufficientMemory
}

enum FileSystemError: Error {
    case accessDenied
    case readFailed
    case writeFailed
    case deviceNotFound
}

enum ExportError: Error {
    case encodingFailed
    case insufficientSpace
    case cancelled
}
```

### Error Handling Strategy

```swift
class VideoPlayerService {
    func loadVideo(url: URL) async throws {
        do {
            let data = try await fileService.readFile(at: url.path)
            let frames = try await decoder.decode(data)
            // ...
        } catch FileSystemError.readFailed {
            // Log error
            logger.error("Failed to read file: \(url)")
            // Attempt recovery
            try await repairFile(url)
        } catch DecoderError.unsupportedFormat {
            // User-friendly error
            throw PlayerError.unsupportedFormat
        } catch {
            // Generic error
            throw PlayerError.decodingFailed
        }
    }
}
```

## Security Considerations

### Sandboxing

```xml
<!-- Entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>

<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<key>com.apple.security.device.usb</key>
<true/>

<key>com.apple.security.network.client</key>
<true/> <!-- For Google Maps -->
```

### Input Validation

```swift
class FileValidator {
    func validateVideoFile(_ url: URL) throws {
        // Check file extension
        guard url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "h264" else {
            throw ValidationError.invalidFileType
        }

        // Check file size (max 4GB)
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        guard fileSize < 4_294_967_296 else {
            throw ValidationError.fileTooLarge
        }

        // Validate video header
        let data = try Data(contentsOf: url, options: .mappedIfSafe).prefix(1024)
        guard isValidVideoHeader(data) else {
            throw ValidationError.corruptedFile
        }
    }
}
```

## Testing Strategy

### Unit Tests

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
        // Given
        let testURL = URL(fileURLWithPath: "/test/video.mp4")
        mockFileService.mockFile = VideoFile(id: UUID(), path: testURL.path, ...)

        // When
        try await sut.loadVideo(url: testURL)
        sut.play()

        // Then
        XCTAssertTrue(sut.isPlaying)
    }
}
```

### Integration Tests

```swift
class FileSystemIntegrationTests: XCTestCase {
    func testReadFromActualSDCard() throws {
        // Requires actual SD card for integration testing
        let fileService = FileSystemService()
        let mountPoint = URL(fileURLWithPath: "/Volumes/DASHCAM")

        let files = try fileService.listVideoFiles(at: mountPoint.appendingPathComponent("DCIM"))
        XCTAssertFalse(files.isEmpty)

        let data = try fileService.readFile(at: files[0])
        XCTAssertFalse(data.isEmpty)
    }
}
```

## Performance Optimization

### Lazy Loading

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

### Caching

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

## Scalability

### Modular Design

- Each service is independent and can be replaced
- Protocol-based design allows easy mocking
- Clear separation of concerns enables parallel development

### Future Extensions

- Cloud sync capability (iCloud integration)
- Live streaming from dashcam
- AI-powered event detection
- Multi-platform support (iOS companion app)
