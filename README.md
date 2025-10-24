# Blackbox Player for macOS

> 🌐 **Language**: [English](#) | [한국어](README_kr.md)

> A native macOS application for dashcam SD card video playback with multi-channel synchronization, GPS mapping, and comprehensive video management features.

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Technical Highlights](#technical-highlights)
- [Documentation](#documentation)
- [Technology Stack](#technology-stack)
- [System Requirements](#system-requirements)
- [Project Timeline](#project-timeline)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Development Phases](#development-phases)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

The Blackbox Player for macOS is a native application designed to bring the dashcam viewing experience—currently available only on Windows—to macOS users. This professional-grade viewer supports simultaneous playback of up to 5 video channels with frame-perfect synchronization, GPS route visualization, G-Sensor data analysis, and comprehensive file management.

### Background

Modern dashcams record video from multiple cameras simultaneously (front, rear, left, right, interior) and store the footage on SD cards. This project provides a fully-featured, native macOS application to view and manage dashcam footage on Mac.

### Project Goals

1. **Parity with Windows Viewer**: Provide all features available in the Windows version
2. **Native macOS Experience**: Leverage Apple's frameworks for optimal performance and user experience
3. **Professional Quality**: Deliver a polished, production-ready application
4. **Extensibility**: Design with future enhancements in mind (multi-language, cloud sync, iOS companion)

---

## Key Features

### 🎬 Multi-Channel Video Playback
- Simultaneous playback of up to **5 channels**
- Frame-perfect synchronization (±50ms accuracy)
- Independent channel controls
- Multiple layout options (grid, focus+small, horizontal)

### 🎮 Advanced Playback Controls
- Play, pause, stop, previous/next file
- Timeline scrubbing with precise seeking
- Variable playback speed (0.5x, 1x, 2x)
- Volume control per channel
- Full-screen mode support

### 📹 Video Processing
- **MP4 Export**: Convert multi-channel H.264+MP3 to standard MP4 format
- **Video Repair**: Recover damaged video files
- **Channel Extraction**: Extract specific channels from multi-channel recordings
- **Batch Operations**: Process multiple files simultaneously

### 🗺️ GPS Integration
- Real-time GPS route display on map (MapKit or Google Maps)
- Synchronized position updates during playback
- Speed, altitude, and heading information
- Route replay with playback controls

### 📊 G-Sensor Visualization
- Real-time acceleration data graphing (X/Y/Z axes)
- Impact event detection and highlighting
- Synchronized with video playback
- Zoom and pan for detailed analysis

### 📁 File Management
- Organized by event type:
  - **Normal**: Regular continuous recording
  - **Impact**: Event-triggered recordings
  - **Parking**: Parking mode recordings
- Color-coded event types
- Multi-select for batch operations
- Search and filter capabilities

### 🔌 Multi-Vendor Support
- **Automatic vendor detection**: Analyzes file naming patterns to identify dashcam manufacturer
- **Extensible parser architecture**: Strategy pattern for vendor-specific parsers
- **Supported vendors**:
  - **CR-2000 OMEGA**: Full support with GPS and accelerometer extraction
  - **BlackVue**: Complete filename parsing and event type detection
- **Easy vendor addition**: Protocol-based design for adding new dashcam vendors

### ⚙️ Dashcam Configuration
- Read settings from SD card
- Modify dashcam options within the app
- Save settings back to SD card
- Validation and error checking

### 🖼️ Image Processing
- Screen capture (save current frame as image)
- Digital zoom for detailed viewing
- Horizontal/vertical flip
- Brightness adjustment
- All operations performed in real-time with Metal GPU acceleration

### 🌍 Multi-Language Support
- Korean (한국어)
- English
- Japanese (日本語) - planned
- Extensible localization system

---

## Technical Highlights

### Native macOS Technologies

```
┌─────────────────────────────────────────┐
│        macOS Native Stack               │
├─────────────────────────────────────────┤
│ UI Layer      : SwiftUI + AppKit        │
│ Video         : AVFoundation + FFmpeg   │
│ Graphics      : Metal                   │
│ Maps          : MapKit / Google Maps    │
│ Charts        : Core Graphics           │
│ File System   : FileManager + IOKit     │
│ Build         : Xcode + XcodeGen        │
└─────────────────────────────────────────┘
```

### Performance Characteristics

| Metric | Target | Notes |
|--------|--------|-------|
| Video Playback | 30+ fps per channel | Hardware-accelerated with Metal |
| Sync Accuracy | ±50ms | Across all 5 channels |
| Memory Usage | < 2GB | For 5x 1080p streams |
| CPU Usage | < 80% | On Apple Silicon |
| App Startup | < 2s | Cold start |
| Export Speed | > 1x real-time | H.264+MP3 → MP4 |
| Frame Cache Hit Rate | > 90% | For frame-by-frame navigation |
| Cache Memory | ~250MB | 30 frames @ 1080p RGBA |
| Seek Response Time | < 100ms | With cache invalidation |

### Architecture

The application follows a clean **MVVM (Model-View-ViewModel)** architecture with clear separation of concerns:

```
┌──────────────────────────────────────────────────────┐
│                  Presentation Layer                   │
│         SwiftUI Views + Metal Renderer               │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│                 Application Layer                     │
│          View Models (ObservableObject)              │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│                Business Logic Layer                   │
│   Player • FileManager • GPS • GSensor • Export      │
└──────────────────────────────────────────────────────┘
                        ↕
┌──────────────────────────────────────────────────────┐
│                    Data Layer                         │
│         FFmpeg Decoders • File System Access         │
└──────────────────────────────────────────────────────┘
```

### Memory Management & Optimization

**Frame Caching System:**
- LRU-based cache with 100ms precision cache keys
- 30-frame capacity (~250MB for 1080p, ~1GB for 4K)
- Automatic cache cleanup every 5 seconds (maintains ±5 second range around current playback position)
- Cache invalidation on seek operations to free memory

**Memory Warning Handling:**
- NotificationCenter observer for system memory warnings
- Automatic cache clearing on low memory conditions
- Prevents app termination by freeing up to 1GB when needed
- Maintains playback functionality during memory pressure

**Performance Benefits:**
- Frame-by-frame navigation: instant response with cache hits (0ms decoding)
- Repeated playback: 10x faster response for cached frames
- Reduced CPU usage: eliminated redundant FFmpeg decoding operations
- Memory-efficient: automatic cleanup prevents unbounded growth

---

## Documentation

Comprehensive documentation is available in the `docs/` directory:

| Document | Description |
|----------|-------------|
| **[01_requirements.md](docs/01_requirements.md)** | Complete functional and non-functional requirements |
| **[02_technology_stack.md](docs/02_technology_stack.md)** | Detailed technology choices and rationale |
| **[03_architecture.md](docs/03_architecture.md)** | System architecture, design patterns, and module structure |
| **[04_project_plan.md](docs/04_project_plan.md)** | Phase-by-phase development plan with timelines |
| **[05_technical_challenges.md](docs/05_technical_challenges.md)** | Major technical challenges and detailed solutions |
| **[06_improvement_roadmap.md](docs/06_improvement_roadmap.md)** | 🆕 **Improvement roadmap for Phase 6 and beyond** |
| **[TESTING.md](docs/TESTING.md)** | Comprehensive testing guide with test suite documentation |
| **[VENDOR_PARSER.md](docs/VENDOR_PARSER.md)** | Multi-vendor parser architecture and implementation guide |

---

## Technology Stack

### Core Technologies

**Application Framework:**
- **Swift 5.9+**: Primary programming language
- **SwiftUI**: Modern declarative UI framework
- **AppKit**: Window management and system integration

**Video Processing:**
- **FFmpeg**: H.264 decoding, MP3 audio, MP4 muxing
- **AVFoundation**: Native video playback and synchronization
- **Metal**: GPU-accelerated rendering and image processing

**File System:**
- **FileManager**: Native file system access
- **IOKit**: USB device detection and management

**Mapping:**
- **MapKit**: Apple's native mapping framework (recommended)
- **Google Maps SDK**: Alternative with richer features

**Data Visualization:**
- **Core Graphics**: G-Sensor chart rendering
- **Swift Charts**: Modern declarative charting (macOS 13+)

### Development Tools

- **Xcode 15+**: IDE and build system
- **Swift Package Manager**: Dependency management
- **CMake**: Build system for C/C++ components
- **SwiftLint**: Code quality and style checking
- **Instruments**: Performance profiling
- **create-dmg**: macOS installer creation

---

## System Requirements

### Development Environment

**Required:**
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Homebrew package manager
- Apple Developer Program membership ($99/year)

**Hardware:**
- Mac with Apple Silicon (M1/M2/M3) or Intel Core i7+
- 16GB RAM minimum, 32GB recommended
- 50GB free storage

### Target Users

**Minimum:**
- macOS 12.0 (Monterey) or later
- 8GB RAM
- 100MB free storage (plus space for exported videos)

**Recommended:**
- macOS 13.0 (Ventura) or later
- 16GB RAM
- Apple Silicon Mac for best performance

---

## Project Timeline

```
┌────────────────────────────────────────────────────────┐
│ Phase 0: Preparation          │ 1 week                 │
│ Phase 1: File System & Data   │ 2-3 weeks              │
│ Phase 2: Single Playback      │ 2-3 weeks              │
│ Phase 3: Multi-Channel Sync   │ 2-3 weeks              │
│ Phase 4: Additional Features  │ 2 weeks                │
│ Phase 5: Export & Settings    │ 2 weeks                │
│ Phase 6: Localization & Polish│ 1-2 weeks              │
├────────────────────────────────────────────────────────┤
│ Total Duration                │ 12-16 weeks (3-4 months)│
└────────────────────────────────────────────────────────┘
```

### Milestones

**Milestone 1: MVP** (End of Phase 3)
- File system access working
- Multi-channel synchronized playback functional
- Basic playback controls implemented

**Milestone 2: Feature Complete** (End of Phase 5)
- All requirements implemented
- GPS mapping and G-Sensor visualization complete
- Export and settings management working

**Milestone 3: Production Ready** (End of Phase 6)
- Localized (Korean, English, Japanese)
- Polished UI with dark mode support
- Code signed and notarized
- DMG installer created
- Documentation complete

---

## ⚠️ Current Implementation Status

**Last Updated**: 2025-10-14

This project is under active development. The following summarizes the implementation progress:

### ✅ Completed Phases (Phases 1-4)

#### Phase 1: File System and Metadata Extraction ✅
**Commits**: f0981f7, 1fd70da, 60a418f

Implemented services:
- **FileScanner**: Recursive directory scanning with video file filtering
- **FileSystemService**: File metadata extraction and directory operations
- **VideoFileLoader**: Video metadata loading via VideoDecoder with concurrent processing
- **MetadataExtractor**: GPS and acceleration data extraction from MP4 atoms
- **VendorParser**: Multi-vendor support with automatic detection
  - **CR2000OmegaParser**: Filename parsing, GPS/accelerometer extraction from Stream #2
  - **BlackVueParser**: Path-based event type detection
  - **VendorDetector**: Auto-detection with caching (commit: 13983a4)

#### Phase 2: Video Decoding and Playback Control ✅
**Commit**: 083ba4d

Implemented services:
- **VideoDecoder** (1584 lines): FFmpeg integration with H.264/MP3 decoding, frame-by-frame navigation, keyframe-based seeking, BGRA output
- **MultiChannelSynchronizer**: Multi-channel timestamp synchronization with tolerance-based frame alignment

#### Phase 3: Multi-Channel Synchronization ✅
**Commit**: 4712a30

Implemented services:
- **VideoBuffer** (NEW): Thread-safe circular buffer (30 frames max) with timestamp-based search
- **MultiChannelSynchronizer** (Enhanced): Drift monitoring (100ms interval), automatic correction (50ms threshold), drift statistics

#### Phase 4: GPS, G-Sensor, and Image Processing ✅
**Commit**: 8b9232c

Implemented services:
- **GPSService** (1235 lines): GPS data parsing, timestamp-based queries, Haversine calculations, speed/direction
- **GSensorService** (1744 lines): Acceleration processing, impact detection, event classification
- **FrameCaptureService** (415 lines): Frame capture (PNG/JPEG), metadata overlay, multi-channel composites
- **VideoTransformations** (1085 lines): Brightness/contrast, flip, zoom, UserDefaults persistence

### ⏳ Pending Phase (Phase 5)

#### Phase 5: Metal Rendering and UI ⏳
**Status**: Not started (requires Xcode build environment)

Components to implement:
- **MetalRenderer**: GPU-accelerated video rendering for 5 channels
- **MapViewController**: MapKit integration for GPS route visualization
- **UI Layer**: SwiftUI/AppKit views, menu actions, keyboard shortcuts

### 🚀 Key Achievements
- ✅ **File System**: Complete SD card file scanning and metadata extraction
- ✅ **Video Decoding**: FFmpeg integration with frame-accurate seeking
- ✅ **Synchronization**: 5-channel sync with ±50ms accuracy and drift correction
- ✅ **GPS & G-Sensor**: Full data pipeline from parsing to processing
- ✅ **Image Processing**: Screenshot capture and video transformations

### 📊 Overall Progress
- **Phase 1-4**: 100% complete (Core backend services)
- **Phase 5**: 0% complete (Metal rendering and UI layer)
- **Overall**: ~80% backend complete, UI layer pending

For detailed implementation status, see [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md).

---

## Getting Started

> ⚠️ **Important Build Note**: This project requires **stable Xcode (15.4+ or 16.0+)**. Xcode 26.x beta has known build system crashes. See [Known Issues](#known-issues) below.

### Quick Start

For implementation guidance, see **[Implementation Checklist](IMPLEMENTATION_CHECKLIST.md)** for step-by-step TODO item completion guide.

### Prerequisites

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install development tools
brew install ffmpeg cmake git git-lfs swiftlint xcodegen

# Install Xcode Command Line Tools
xcode-select --install

# Download Metal Toolchain (required for shaders)
xcodebuild -downloadComponent MetalToolchain
```

### Initial Setup

1. **Clone the repository** (when created)
   ```bash
   git clone https://github.com/your-org/blackbox-player.git
   cd blackbox-player
   ```

2. **Open in Xcode**
   ```bash
   open BlackboxPlayer.xcodeproj
   ```

3. **Configure code signing**
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team
   - Verify bundle identifier

4. **Build and run**
   - Press `Cmd+R` or click the Run button
   - Select a target device (My Mac)

### Running Tests

The project includes comprehensive unit and integration tests to ensure functionality and performance.

**Run all tests:**
```bash
# Using build scripts (recommended)
./scripts/test.sh

# Using Xcode
# Press Cmd+U or select Product > Test

# Using xcodebuild
xcodebuild test -project BlackboxPlayer.xcodeproj -scheme BlackboxPlayer
```

**Test Suite Coverage:**

| Test Suite | Coverage | Description |
|------------|----------|-------------|
| **GPSSensorIntegrationTests** | GPS/G-Sensor Pipeline | End-to-end tests for GPS and G-sensor visualization pipeline |
| **SyncControllerTests** | Multi-Channel Sync | Tests for video synchronization across channels |
| **VideoDecoderTests** | Video Decoding | FFmpeg H.264/MP3 decoding validation |
| **VideoChannelTests** | Channel Management | Individual video channel functionality |
| **DataModelsTests** | Data Models | VideoFile, VideoMetadata, GPSPoint, AccelerationData |
| **MultiChannelRendererTests** | Metal Rendering | GPU-accelerated multi-channel rendering |

**GPS/G-Sensor Integration Tests** (`GPSSensorIntegrationTests.swift`):
- **Data Parsing**: GPS/G-sensor binary data parsing validation
- **Service Integration**: GPSService and GSensorService data loading
- **Synchronization**: Video-GPS and Video-G-sensor time synchronization
- **Real-time Updates**: Sensor data updates during playback
- **Performance**: Large dataset search performance (10,000+ GPS points)
- **Interpolation**: Linear interpolation between GPS points

Test data pipeline:
```
VideoFile → VideoMetadata → GPSService/GSensorService → SyncController → UI
```

### Testing with Sample Data

1. Obtain sample dashcam SD card or use provided test data
2. Connect SD card via USB card reader
3. Launch the application
4. Select the SD card device from the device picker
5. Browse and play videos

---

## Project Structure

```
blackbox_player/
├── README.md                   # This file
├── docs/                       # Detailed documentation
│   ├── 01_requirements.md
│   ├── 02_technology_stack.md
│   ├── 03_architecture.md
│   ├── 04_project_plan.md
│   └── 05_technical_challenges.md
├── BlackboxPlayer/             # Main application (to be created)
│   ├── App/
│   │   ├── BlackboxPlayerApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── Player/
│   │   ├── FileList/
│   │   ├── Map/
│   │   ├── Charts/
│   │   └── Settings/
│   ├── ViewModels/
│   │   ├── PlayerViewModel.swift
│   │   ├── FileListViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Services/
│   │   ├── VideoPlayerService.swift
│   │   ├── FileManagerService.swift
│   │   ├── ExportService.swift
│   │   ├── GPSService.swift
│   │   ├── GSensorService.swift
│   │   └── VendorParser/
│   │       ├── VendorParserProtocol.swift
│   │       ├── VendorDetector.swift
│   │       ├── CR2000OmegaParser.swift
│   │       ├── BlackVueParser.swift
│   │       └── MetadataStreamParser.swift
│   ├── Models/
│   │   ├── VideoFile.swift
│   │   ├── VideoMetadata.swift
│   │   ├── GPSPoint.swift
│   │   └── AccelerationData.swift
│   ├── Utilities/
│   │   ├── FFmpegWrapper.swift
│   │   └── MetalRenderer.swift
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── Localizable.strings
│   │   └── Info.plist
├── Tests/
│   ├── BlackboxPlayerTests.swift
│   ├── DataModelsTests.swift
│   ├── MultiChannelRendererTests.swift
│   ├── SyncControllerTests.swift
│   ├── VideoChannelTests.swift
│   ├── VideoDecoderTests.swift
│   ├── GPSSensorIntegrationTests.swift  # GPS/G-sensor visualization pipeline tests
│   └── VendorParserTests.swift          # Multi-vendor parser tests
└── scripts/
    ├── build.sh
    ├── sign.sh
    └── notarize.sh
```

---

## Development Phases

### Phase 0: Preparation (Week 1)
**Goal:** Set up development environment and validate technical feasibility

**Key Tasks:**
- ✅ Xcode project setup
- ✅ FFmpeg integration and testing
- ✅ Sample data collection and analysis
- ✅ Basic proof of concept

### Phase 1: File System & Data Layer (Weeks 2-4)
**Goal:** Implement file system access and metadata parsing

**Key Tasks:**
- File system service implementation
- USB device detection and mounting
- File enumeration and reading
- GPS and G-Sensor metadata parsing
- Basic file list UI

### Phase 2: Single Channel Playback (Weeks 5-7)
**Goal:** Implement smooth single-video playback

**Key Tasks:**
- FFmpeg H.264/MP3 decoding
- Metal renderer setup
- Video player view
- Playback controls (play, pause, seek, speed)
- Audio/video synchronization

### Phase 3: Multi-Channel Synchronization (Weeks 8-10)
**Goal:** Synchronize 5 channels with frame-perfect accuracy

**Key Tasks:**
- Multi-channel architecture
- Master clock implementation
- Sync controller with drift monitoring
- Multi-texture Metal rendering
- Layout manager (grid, focus, horizontal)
- Performance optimization

### Phase 4: Additional Features (Weeks 11-12)
**Goal:** Implement GPS, G-Sensor, and image processing

**Key Tasks:**
- GPS service and map integration
- G-Sensor chart visualization
- Screen capture functionality
- Video transformations (flip, brightness, zoom)
- Full-screen mode

### Phase 5: Export & Settings (Weeks 13-14)
**Goal:** MP4 export and dashcam configuration

**Key Tasks:**
- MP4 export with FFmpeg muxing
- Video repair functionality
- Channel extraction
- Settings file parser
- Settings UI and validation

### Phase 6: Localization & Polish (Weeks 15-16)
**Goal:** Production-ready application

**Key Tasks:**
- String localization (Korean, English, Japanese)
- Dark mode support
- UI/UX polish
- Performance tuning
- Code signing and notarization
- DMG installer creation
- Documentation

---

## Contributing

This is currently a private development project. Contribution guidelines will be added when the project is opened to external contributors.

### Development Workflow

1. Create feature branch from `develop`
2. Implement changes following Swift style guide
3. Add unit tests for new functionality
4. Run `swiftlint` to verify code quality
5. Submit pull request with detailed description
6. Pass code review and automated tests
7. Merge to `develop` after approval

### Code Standards

- **Swift Style**: Follow [Swift.org API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Commit Messages**: Use conventional commits format: `type(scope): description`
- **Test Coverage**: Maintain >80% code coverage
- **Documentation**: Document all public APIs with clear descriptions and examples

---

## License

**Proprietary - All Rights Reserved**

This project is proprietary software developed for [Company Name]. Unauthorized copying, distribution, or modification is strictly prohibited.

Copyright © 2024 [Company Name]. All rights reserved.

---

## Contact

For questions or support, please contact:

- **Project Lead**: [Name] - [email@example.com]
- **Technical Lead**: [Name] - [email@example.com]
- **Product Manager**: [Name] - [email@example.com]

---

## Acknowledgments

- **Apple Developer Documentation**: For comprehensive macOS development resources
- **FFmpeg Team**: For the excellent video processing library

---

## Roadmap

### Version 1.0 (Initial Release)
- ✅ All features described in requirements
- ✅ Korean and English localization
- ✅ Production-ready build

### Version 1.1 (Q2 2024)
- Additional language support (Japanese, Chinese)
- Performance improvements based on user feedback
- Bug fixes and stability improvements

### Version 2.0 (Q4 2024)
- iOS companion app
- iCloud sync for settings and bookmarks
- Live streaming from dashcam (Wi-Fi enabled models)
- AI-powered event detection
- Advanced video editing features
- Cloud storage integration

---

**Built with ❤️ for macOS**

Last Updated: 2025-10-14
Project Status: Phase 1-4 Complete (Backend Services) | Phase 5 Pending (UI Layer)
