# Project Development Plan

> 🌐 **Language**: [English](#) | [한국어](04_project_plan_kr.md)

## Timeline Overview

```
Phase 0: Preparation      [■■░░░░░░░░░░░░░░] 1 week
Phase 1: File System      [░░■■■░░░░░░░░░░░] 2-3 weeks
Phase 2: Single Playback  [░░░░░■■■░░░░░░░░] 2-3 weeks
Phase 3: Multi-Channel    [░░░░░░░░■■■░░░░░] 2-3 weeks
Phase 4: Features         [░░░░░░░░░░░■■░░░] 2 weeks
Phase 5: Export/Settings  [░░░░░░░░░░░░░■■░] 2 weeks
Phase 6: Localization     [░░░░░░░░░░░░░░░■] 1-2 weeks

Total Estimated Duration: 12-16 weeks (3-4 months)
```

## Phase 0: Preparation (1 week)

### Objectives
- Set up development environment
- Verify technical feasibility
- Establish project infrastructure

### Tasks

#### 1. Environment Setup
- [ ] Install Xcode 15+ from Mac App Store
- [ ] Install Homebrew package manager
- [ ] Install development tools:
  ```bash
  brew install ffmpeg cmake git git-lfs
  brew install swiftlint # Code quality tool
  ```
- [ ] Create Apple Developer account (if not exists)
- [ ] Configure code signing certificates

#### 2. Project Initialization
- [ ] Create new Xcode project
  - Template: macOS App
  - Interface: SwiftUI
  - Language: Swift
  - Minimum Deployment: macOS 12.0
- [ ] Set up project structure:
  ```
  BlackboxPlayer/
  ├── App/
  ├── Views/
  ├── ViewModels/
  ├── Services/
  ├── Models/
  ├── Utilities/
  ├── Resources/
  └── Tests/
  ```
- [ ] Initialize Git repository
- [ ] Create `.gitignore` for Xcode projects
- [ ] Set up CI/CD pipeline (GitHub Actions)

#### 3. Library Integration
- [ ] Set up FileManager integration:
  - Test SD card mounting and access
  - Verify file system permissions
  - Test IOKit USB device detection
- [ ] Integrate FFmpeg:
  - Link FFmpeg libraries
  - Create Swift wrapper
  - Test video decoding
- [ ] Set up Swift Package Manager dependencies

#### 4. Sample Data Collection
- [ ] Obtain sample SD card from dashcam
- [ ] Document file structure:
  ```
  /DCIM/
  ├── Normal/
  │   ├── 2024-01-15_08-30-00_F.h264
  │   ├── 2024-01-15_08-30-00_R.h264
  │   └── ...
  ├── Event/
  └── Parking/
  ```
- [ ] Analyze metadata format
- [ ] Extract GPS and G-Sensor data samples
- [ ] Document video specifications (resolution, codec, bitrate)

#### 5. Proof of Concept
- [ ] Create minimal file system access demo
- [ ] Create minimal FFmpeg decode demo
- [ ] Validate hardware performance (decode 5 streams)

### Deliverables
- ✅ Working Xcode project with basic structure
- ✅ FileManager integration successfully tested
- ✅ FFmpeg decoding working
- ✅ Sample data documented
- ✅ Technical feasibility confirmed

### Success Criteria
- Can read files from SD card using FileManager
- Can decode H.264 video with FFmpeg
- Can display single video frame in SwiftUI
- Project builds without errors

---

## Phase 1: File System & Data Layer (2-3 weeks)

### Objectives
- Implement file system access with FileManager
- Parse dashcam metadata
- Build file management foundation

### Tasks

#### Week 1: File System Integration

**1. FileSystemService Implementation**
```swift
// Swift interface
class FileSystemService {
    private let fileManager: FileManager

    func listVideoFiles(at url: URL) throws -> [URL]
    func readFile(at url: URL) throws -> Data
    func getFileInfo(at url: URL) throws -> FileInfo
    func deleteFiles(_ urls: [URL]) throws
}
```

- [ ] Implement FileSystemService
- [ ] Create FileInfo model
- [ ] Add error handling
- [ ] Implement file enumeration
- [ ] Implement file reading
- [ ] Implement metadata access
- [ ] Add unit tests

**2. Device Detection**
- [ ] Detect connected USB devices with IOKit
- [ ] Identify dashcam SD card mount point
- [ ] Handle multiple SD cards
- [ ] Add UI for device selection

#### Week 2: Metadata Parsing

**1. Metadata Parser**
```swift
class MetadataParser {
    func parseGPS(from data: Data) -> [GPSPoint]
    func parseGSensor(from data: Data) -> [AccelerationData]
    func parseFileMetadata(from data: Data) -> VideoMetadata
}
```

- [ ] Reverse engineer metadata format
- [ ] Implement GPS data parser
- [ ] Implement G-Sensor data parser
- [ ] Parse timestamp information
- [ ] Parse channel information
- [ ] Add validation logic

**2. Data Models**
- [ ] Define `VideoFile` model
- [ ] Define `GPSPoint` model
- [ ] Define `AccelerationData` model
- [ ] Define `VideoMetadata` model
- [ ] Add Codable conformance
- [ ] Create test fixtures

#### Week 3: File Manager Service

**1. File Manager Implementation**
```swift
class FileManagerService {
    func loadFiles() async throws -> [VideoFile]
    func getFiles(type: EventType) async throws -> [VideoFile]
    func searchFiles(query: String) async throws -> [VideoFile]
    func deleteFiles(_ files: [VideoFile]) async throws
}
```

- [ ] Implement file scanning
- [ ] Group files by event type (Normal/Impact/Parking)
- [ ] Implement caching mechanism
- [ ] Add file filtering
- [ ] Add search functionality
- [ ] Handle corrupted files gracefully

**2. Basic UI**
- [ ] Create FileListView
- [ ] Display file information
- [ ] Show event type badges
- [ ] Implement selection mechanism

### Deliverables
- ✅ File system access fully functional
- ✅ File list displayed in UI
- ✅ Metadata parsing working
- ✅ Event type categorization implemented

### Success Criteria
- Can access SD card and list all files
- Can read video file data
- Can parse GPS and G-Sensor metadata
- File list displays correctly with event types
- No memory leaks in file operations

### Testing
```bash
# Unit tests
./run_tests.sh FileManagerServiceTests

# Integration tests
./run_tests.sh FileSystemIntegrationTests
```

---

## Phase 2: Single Channel Video Playback (2-3 weeks)

### Objectives
- Implement video decoding
- Create video player UI
- Add playback controls

### Tasks

#### Week 1: Video Decoder

**1. FFmpeg Integration**
```swift
class VideoDecoder {
    func open(url: URL) throws
    func decodeNextFrame() async throws -> VideoFrame?
    func seek(to time: CMTime) throws
    func close()
}
```

- [ ] Implement H.264 decoding
- [ ] Implement MP3 audio decoding
- [ ] Handle different resolutions
- [ ] Implement frame buffering
- [ ] Add error recovery
- [ ] Optimize for performance

**2. Audio/Video Synchronization**
- [ ] Implement clock synchronization
- [ ] Handle A/V drift
- [ ] Buffer management

#### Week 2: Metal Renderer

**1. Metal Setup**
```swift
class MetalVideoRenderer: NSObject, MTKViewDelegate {
    func render(frame: VideoFrame, to view: MTKView)
}
```

- [ ] Create Metal device and command queue
- [ ] Set up render pipeline
- [ ] Create texture from CVPixelBuffer
- [ ] Implement vertex and fragment shaders
- [ ] Handle window resizing
- [ ] Optimize for 60fps

**2. Video Player View**
- [ ] Create MTKView wrapper in SwiftUI
- [ ] Display video frames
- [ ] Handle aspect ratio
- [ ] Add loading indicator

#### Week 3: Playback Controls

**1. Player Controls UI**
```swift
struct PlayerControlsView: View {
    var body: some View {
        HStack {
            PlayPauseButton()
            TimelineSlider()
            SpeedControl()
            VolumeSlider()
        }
    }
}
```

- [ ] Play/Pause button
- [ ] Stop button
- [ ] Previous/Next file buttons
- [ ] Timeline scrubber
- [ ] Current time display
- [ ] Speed control (0.5x, 1x, 2x)
- [ ] Volume control

**2. Keyboard Shortcuts**
- [ ] Space: Play/Pause
- [ ] Left/Right: Seek ±5 seconds
- [ ] Up/Down: Volume
- [ ] F: Full screen
- [ ] ESC: Exit full screen

**3. Player ViewModel**
```swift
class PlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: CMTime = .zero
    @Published var duration: CMTime = .zero
    @Published var playbackRate: Float = 1.0

    func play()
    func pause()
    func seek(to time: CMTime)
    func setSpeed(_ rate: Float)
}
```

### Deliverables
- ✅ Single video plays smoothly
- ✅ Playback controls functional
- ✅ Audio/video synchronized
- ✅ Smooth seeking

### Success Criteria
- Video plays at 30fps minimum
- Audio/video sync within ±50ms
- Seeking responds within 500ms
- Memory usage < 500MB for single HD video
- No frame drops during normal playback

### Testing
- [ ] Test various video resolutions (720p, 1080p, 4K)
- [ ] Test different frame rates (25fps, 30fps, 60fps)
- [ ] Test long videos (>1 hour)
- [ ] Test damaged video files
- [ ] Measure CPU/GPU usage

---

## Phase 3: Multi-Channel Synchronization (2-3 weeks)

### Objectives
- Play 5 channels simultaneously
- Maintain synchronization
- Optimize performance

### Tasks

#### Week 1: Multi-Channel Architecture

**1. Channel Management**
```swift
class VideoChannel: Identifiable {
    let id: Int
    var decoder: VideoDecoder
    var buffer: VideoBuffer
    var state: PlaybackState
}

class MultiChannelPlayer {
    var channels: [VideoChannel] = []
    var syncController: SyncController
}
```

- [ ] Create VideoChannel abstraction
- [ ] Implement independent decoders (5 instances)
- [ ] Create frame buffers for each channel
- [ ] Set up background decoding threads

**2. Synchronization Controller**
```swift
class SyncController {
    func syncPlay()
    func syncPause()
    func syncSeek(to time: CMTime)
    func monitorSync() // Check and correct drift
}
```

- [ ] Implement master clock
- [ ] Sync all channels to master clock
- [ ] Monitor synchronization drift
- [ ] Auto-correct when drift > 50ms
- [ ] Handle channels with different frame rates

#### Week 2: Multi-Texture Rendering

**1. Metal Multi-Texture Renderer**
```swift
class MultiChannelRenderer {
    func render(channels: [VideoFrame], to view: MTKView) {
        // Single render pass for all channels
    }
}
```

- [ ] Render 5 textures in single pass
- [ ] Implement grid layout (2x2 + 1)
- [ ] Support different layouts:
  - Grid: 2x3
  - Focus: 1 large + 4 small
  - Horizontal: 1x5
- [ ] Handle missing channels gracefully

**2. Layout Manager**
```swift
enum ChannelLayout {
    case grid2x3
    case focusPlusSmall
    case horizontal
}

class LayoutManager {
    func calculateFrames(for layout: ChannelLayout, in bounds: CGRect) -> [CGRect]
}
```

- [ ] Define layout configurations
- [ ] Calculate channel positions
- [ ] Handle window resizing
- [ ] Add layout switching UI

#### Week 3: Performance Optimization

**1. Memory Optimization**
- [ ] Implement frame buffer limits (30 frames/channel)
- [ ] Release old frames promptly
- [ ] Use autoreleasepool for tight loops
- [ ] Monitor memory usage
- [ ] Add memory warnings

**2. Threading Optimization**
```swift
// Decode each channel on separate thread
let decodeQueues = (0..<5).map {
    DispatchQueue(label: "decoder.\($0)", qos: .userInitiated)
}

// Render on main thread
DispatchQueue.main.async {
    renderer.render(frames: frames)
}
```

- [ ] Optimize thread count
- [ ] Use Grand Central Dispatch effectively
- [ ] Avoid main thread blocking
- [ ] Profile with Instruments

**3. GPU Optimization**
- [ ] Use shared Metal resources
- [ ] Minimize texture uploads
- [ ] Batch draw calls
- [ ] Profile with Metal debugger

### Deliverables
- ✅ 5 channels playing simultaneously
- ✅ All channels synchronized
- ✅ Smooth performance
- ✅ Multiple layout options

### Success Criteria
- All 5 channels play at 30fps minimum
- Synchronization drift < ±50ms
- Memory usage < 2GB
- CPU usage < 80% on Apple Silicon
- GPU usage < 70%
- No frame drops during normal playback

### Testing
- [ ] Test with 5x 1080p videos
- [ ] Test long-duration playback (2+ hours)
- [ ] Test synchronization accuracy
- [ ] Measure performance metrics
- [ ] Test on different Mac models (Intel vs Apple Silicon)

---

## Phase 4: Additional Features (2 weeks)

### Objectives
- Implement GPS mapping
- Add G-Sensor visualization
- Image processing features

### Tasks

#### Week 1: GPS & G-Sensor

**1. GPS Integration**
```swift
class GPSService {
    func loadGPSData(for file: VideoFile) async -> [GPSPoint]
    func getCurrentLocation(at time: CMTime) -> GPSPoint?
}

class GPSMapView: NSView {
    var mapView: MKMapView
    var route: [CLLocationCoordinate2D]

    func updateLocation(_ point: GPSPoint)
    func drawRoute()
}
```

- [ ] Implement GPS data parsing
- [ ] Integrate MapKit (or Google Maps)
- [ ] Draw driving route on map
- [ ] Update location as video plays
- [ ] Add map controls (zoom, pan)
- [ ] Show speed, altitude info

**2. G-Sensor Visualization**
```swift
class GSensorChartView: NSView {
    var data: [AccelerationData]

    func drawChart() {
        // Draw X/Y/Z axes
        // Highlight impact events
    }
}
```

- [ ] Parse G-Sensor data
- [ ] Create chart view with Core Graphics
- [ ] Display X/Y/Z acceleration
- [ ] Highlight impact events (magnitude > threshold)
- [ ] Synchronize with video playback
- [ ] Add zoom/pan for chart

#### Week 2: Image Processing

**1. Screen Capture**
```swift
func captureCurrentFrame() -> NSImage {
    // Capture current video frame
    // Save as PNG/JPEG
}
```

- [ ] Implement frame capture
- [ ] Save to user-selected location
- [ ] Support PNG and JPEG formats
- [ ] Include timestamp overlay (optional)

**2. Video Transformations**
```swift
class VideoTransformations {
    var brightness: Float = 1.0
    var horizontalFlip: Bool = false
    var verticalFlip: Bool = false
    var zoom: Float = 1.0
}
```

- [ ] Implement brightness adjustment (Metal shader)
- [ ] Implement horizontal flip
- [ ] Implement vertical flip
- [ ] Implement digital zoom
- [ ] Update Metal shaders for transformations

**3. Full Screen Mode**
- [ ] Enter/exit full screen
- [ ] Hide/show controls in full screen
- [ ] Support multiple displays

### Deliverables
- ✅ GPS route displayed on map
- ✅ G-Sensor data visualized
- ✅ Image capture working
- ✅ Video transformations implemented

### Success Criteria
- GPS location updates in real-time
- G-Sensor chart renders smoothly
- Image capture saves at full resolution
- Video transformations don't impact performance
- Full screen mode works correctly

---

## Phase 5: Export & Settings (2 weeks)

### Objectives
- MP4 export functionality
- Settings management
- Video repair

### Tasks

#### Week 1: MP4 Export

**1. Export Service**
```swift
class ExportService {
    func exportToMP4(
        files: [VideoFile],
        destination: URL,
        options: ExportOptions,
        progress: @escaping (Double) -> Void
    ) async throws
}

struct ExportOptions {
    var includeChannels: [Int]
    var includeAudio: Bool
    var quality: VideoQuality
}
```

- [ ] Implement FFmpeg muxing
- [ ] Combine H.264 + MP3 → MP4
- [ ] Support channel selection
- [ ] Embed metadata (GPS, G-Sensor)
- [ ] Show progress bar
- [ ] Handle cancellation
- [ ] Support batch export

**2. Video Repair**
```swift
func repairVideo(_ file: VideoFile) async throws -> URL {
    // Analyze file damage
    // Recover valid frames
    // Create repaired MP4
}
```

- [ ] Detect corrupted files
- [ ] Recover readable frames
- [ ] Skip damaged sections
- [ ] Generate playable MP4

**3. Channel Extraction**
```swift
func extractChannel(_ file: VideoFile, channel: Int) async throws -> URL {
    // Extract single channel from multi-channel file
}
```

- [ ] Extract specific channel
- [ ] Preserve audio if available
- [ ] Maintain video quality

#### Week 2: Settings Management

**1. Settings Service**
```swift
class SettingsService {
    func loadSettings(from sdCard: URL) async throws -> DashcamSettings
    func saveSettings(_ settings: DashcamSettings, to sdCard: URL) async throws
}
```

- [ ] Parse settings file format
- [ ] Load settings from SD card
- [ ] Validate setting values
- [ ] Save settings back to SD card

**2. Settings UI**
```swift
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Video") {
                Picker("Resolution", selection: $viewModel.resolution) { ... }
                Picker("Recording Mode", selection: $viewModel.mode) { ... }
            }

            Section("Features") {
                Toggle("Parking Mode", isOn: $viewModel.parkingMode)
                Slider("Impact Sensitivity", value: $viewModel.sensitivity, in: 1...10)
            }
        }
    }
}
```

- [ ] Create settings form
- [ ] Group settings by category
- [ ] Add validation
- [ ] Show tooltips/help text
- [ ] Implement save/cancel buttons
- [ ] Warn on unsaved changes

### Deliverables
- ✅ MP4 export working
- ✅ Video repair functional
- ✅ Settings can be loaded and saved
- ✅ Settings UI complete

### Success Criteria
- Can export 5-channel video to MP4
- Export preserves quality
- Repair recovers maximum frames
- Settings save correctly to SD card
- Settings UI is intuitive

---

## Phase 6: Localization & Polish (1-2 weeks)

### Objectives
- Multi-language support
- UI/UX polish
- App packaging

### Tasks

#### Week 1: Localization

**1. String Extraction**
- [ ] Extract all UI strings
- [ ] Create Localizable.strings files:
  ```
  Resources/
  ├── en.lproj/
  │   └── Localizable.strings
  ├── ko.lproj/
  │   └── Localizable.strings
  └── ja.lproj/
      └── Localizable.strings
  ```

**2. Translations**
```swift
// Use NSLocalizedString
Text(NSLocalizedString("play_button", comment: "Play button"))
```

- [ ] Korean translation (Korean)
- [ ] English translation (English)
- [ ] Japanese translation (準備) (optional)
- [ ] Test language switching

**3. Localized Assets**
- [ ] Localized images (if any)
- [ ] Localized help text
- [ ] Localized error messages

#### Week 2: Polish & Packaging

**1. UI Polish**
- [ ] Dark mode support
- [ ] App icon design
- [ ] Refine animations
- [ ] Improve error messages
- [ ] Add loading states
- [ ] Polish transitions

**2. Performance Tuning**
- [ ] Profile with Instruments
- [ ] Fix memory leaks
- [ ] Optimize startup time
- [ ] Reduce CPU usage
- [ ] Reduce battery drain

**3. Accessibility**
- [ ] Add VoiceOver labels
- [ ] Support keyboard navigation
- [ ] Ensure color contrast
- [ ] Add text scaling support

**4. Documentation**
- [ ] User manual
- [ ] Installation guide
- [ ] Troubleshooting guide
- [ ] Developer documentation
- [ ] API documentation

**5. Code Signing & Notarization**
```bash
# Sign app
codesign --deep --force --verify --verbose \
         --sign "Developer ID Application: Your Name" \
         --options runtime \
         BlackboxPlayer.app

# Create DMG
create-dmg BlackboxPlayer.app

# Notarize
xcrun notarytool submit BlackboxPlayer.dmg \
         --apple-id "your@email.com" \
         --team-id "TEAM_ID" \
         --password "app-specific-password"

# Staple
xcrun stapler staple BlackboxPlayer.app
```

- [ ] Configure code signing
- [ ] Submit for notarization
- [ ] Test notarized app
- [ ] Create DMG installer

**6. Final Testing**
- [ ] Test on macOS 12, 13, 14
- [ ] Test on Intel and Apple Silicon
- [ ] Test with various SD cards
- [ ] Test all features
- [ ] Fix critical bugs

### Deliverables
- ✅ App supports Korean, English, Japanese
- ✅ Dark mode implemented
- ✅ App signed and notarized
- ✅ DMG installer created
- ✅ Documentation complete

### Success Criteria
- All UI text properly localized
- Dark mode looks good
- App passes notarization
- DMG installs smoothly
- No critical bugs remaining

---

## Resource Requirements

### Team Composition

**Required:**
- 1x macOS Developer (Swift/SwiftUI, AVFoundation)
- 1x Video Processing Engineer (FFmpeg, codecs)

**Optional:**
- 1x UI/UX Designer
- 1x QA Engineer

### Hardware

**Development:**
- MacBook Pro M1/M2/M3 (16GB+ RAM)
- External display (for testing multi-screen)
- USB-C card readers
- Sample SD cards (32GB, 64GB, 128GB)
- Dashcam devices for testing

**Testing:**
- Intel Mac (for compatibility testing)
- Older MacBook (for performance testing)

### Software

**Required:**
- Xcode 15+ ($0)
- Apple Developer Program ($99/year)
- FFmpeg (open source)

**Optional:**
- Google Maps API ($0 - $200/month depending on usage)
- Figma/Sketch (UI design)
- Notion/Jira (project management)

---

## Risk Management

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| SD card access permissions | Low | Medium | Request proper permissions; guide users on setup |
| 5-channel performance issues | Medium | Medium | Metal optimization; offer quality settings |
| Notarization rejection | Low | High | Follow Apple guidelines strictly; test early |
| GPS/G-Sensor format unknown | Medium | Medium | Reverse engineer from Windows viewer |
| Schedule delays | Medium | Medium | Phase-based delivery; prioritize core features |
| Memory leaks | Low | Medium | Regular profiling with Instruments |
| Dashcam firmware variations | High | Medium | Support multiple firmware versions; version detection |

---

## Quality Assurance

### Testing Strategy

**Unit Tests (80% coverage):**
```bash
xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'
```

**Integration Tests:**
- File reading with real SD card
- Multi-channel playback with sample videos
- Export with various video combinations

**Performance Tests:**
- Measure playback FPS
- Measure memory usage over time
- Measure export speed

**UI Tests:**
```swift
func testPlaybackControls() {
    let app = XCUIApplication()
    app.launch()

    app.buttons["Play"].tap()
    XCTAssertTrue(app.buttons["Pause"].exists)

    app.sliders["Timeline"].adjust(toNormalizedSliderPosition: 0.5)
    // ...
}
```

### Continuous Integration

**GitHub Actions workflow:**
```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and test
        run: |
          xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'
      - name: Run SwiftLint
        run: swiftlint lint --strict
```

---

## Milestones & Deliverables

### Milestone 1: MVP (End of Phase 3)
- ✅ Can mount SD card
- ✅ Can list and play videos
- ✅ Multi-channel synchronized playback
- ✅ Basic playback controls

### Milestone 2: Feature Complete (End of Phase 5)
- ✅ All requirements implemented
- ✅ GPS mapping working
- ✅ Export to MP4 functional
- ✅ Settings management complete

### Milestone 3: Production Ready (End of Phase 6)
- ✅ Localized
- ✅ Polished UI
- ✅ Signed and notarized
- ✅ Documentation complete
- ✅ Ready for distribution

---

## Post-Launch Plan

### Version 1.1 (2-3 months after launch)
- Bug fixes from user feedback
- Performance improvements
- Additional language support

### Version 2.0 (6 months after launch)
- iOS companion app
- Cloud sync (iCloud)
- Live streaming from dashcam
- AI-powered event detection
- Advanced editing features

---

## Success Metrics

### Performance Metrics
- App startup time < 2 seconds
- Video load time < 1 second
- 5-channel playback at 30fps+
- Memory usage < 2GB
- Export speed > 1x real-time

### Quality Metrics
- Crash rate < 0.1%
- Test coverage > 80%
- Code review approval required
- Zero critical security issues

### User Metrics (Post-Launch)
- Active users
- Session duration
- Feature usage
- App Store ratings
- Support tickets

---

## Appendix A: Current Implementation Status

**Last Updated**: 2025-10-13
**Status**: Active Development
**Total TODO Items**: 59

### TODO Summary by Category

| Category | Count | Priority | Estimated Effort | Key Files |
|----------|-------|----------|------------------|-----------|
| **UI/Menu Actions** | 14 | 🔴 High | 5-7 days | BlackboxPlayerApp.swift |
| **File System Integration** | 10 | 🔴 High | 7-10 days | FileSystemService.swift |
| **Video Playback** | 8 | 🟠 Medium | 7-10 days | VideoDecoder.swift, SyncController.swift |
| **Testing** | 14 | 🟡 Low | 3-5 days | MultiChannelRendererTests.swift |
| **UI Components** | 13 | 🟠 Medium | 5-7 days | FileListView.swift, FileRow.swift |

**Total Estimated Effort**: 27-41 days (5-8 weeks)

### Critical Path Items (P0 Priority)

These items must be completed first as they block other features:

1. **TODO #15** (FileSystemService.swift): Access SD card - **BLOCKER** for all file operations
2. **TODO #16** (FileSystemService.swift): List files in directory - Required for file browsing
3. **TODO #18** (FileSystemService.swift): Read file data - Required for video playback
4. **TODO #24** (FileSystemService.swift): Handle device unmounting - Required for safe cleanup
5. **TODO #1** (BlackboxPlayerApp.swift:463): Open Folder Picker - Main UI entry point
6. **TODO #7** (BlackboxPlayerApp.swift:681): Play/Pause - Core playback control

### Implementation Roadmap (8 weeks)

#### Phase 1: Critical Path (Weeks 1-2)
- File System Access Setup (#15, #24)
- List Directory (#16)
- Open Folder Picker (#1)
- Read File (#18)
- Play/Pause (#7)

#### Phase 2: Core Features (Weeks 3-4)
- Get File Info (#17)
- Load Video Metadata (#27)
- Parse GPS Metadata (#25)
- Sync Video Timestamp (#26)
- Step Forward/Backward (#8, #9)

#### Phase 3: Enhanced UX (Weeks 5-6)
- Toggle Metadata Overlay (#4)
- Toggle Map Overlay (#5)
- Toggle Graph Overlay (#6)
- Playback Speed Controls (#10, #11, #12)

#### Phase 4: Polish (Weeks 7-8)
- About/Help Windows (#13, #14)
- Complete Test Suite (#28-41)
- Bug fixes and optimization

### Key Dependencies

```
File System Access (#15)
  ├─→ List Directory (#16)
  ├─→ Read File (#18)
  └─→ Get File Info (#17)
      ├─→ Load Metadata (#27)
      │   ├─→ Parse GPS (#25)
      │   └─→ Sync Timestamp (#26)
      │       ├─→ Play/Pause (#7)
      │       └─→ Toggle Overlays (#4, #5, #6)
      └─→ Open Folder (#1)
          └─→ Refresh Files (#2)
```

### Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| SD card access permissions | 🟡 Medium | Request proper permissions, provide user guidance |
| FFmpeg compatibility issues | 🟠 High | Extensive codec testing with sample files |
| Metal performance on Intel Macs | 🟡 Medium | Optimize shaders, provide quality settings |
| GPS metadata format unknown | 🟠 High | Reverse engineer from sample data |

### Progress Tracking

**Completed**: 0/59 (0%)
**In Progress**: 0/59 (0%)
**Not Started**: 59/59 (100%)

#### Milestone 1: MVP (Weeks 1-4)
- [ ] File system access working
- [ ] File list loading from SD card
- [ ] Single channel video playback
- [ ] Basic playback controls

#### Milestone 2: Multi-Channel (Weeks 5-6)
- [ ] Multiple channels synchronized
- [ ] GPS overlay working
- [ ] Metadata overlay working
- [ ] G-sensor graph working

#### Milestone 3: Feature Complete (Weeks 7-8)
- [ ] All menu actions implemented
- [ ] Export functionality working
- [ ] Settings management working
- [ ] Test coverage >80%

---

**Note**: For detailed implementation guidance on each TODO item, including specific code examples and line numbers, developers should refer to the inline comments in the source files listed above.
