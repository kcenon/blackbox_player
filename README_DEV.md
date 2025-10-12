# BlackboxPlayer - Development Guide

> **Note**: For general project information, see [README.md](README.md)

This guide provides instructions for setting up and building the BlackboxPlayer project.

## Prerequisites

### System Requirements

- **macOS**: 12.0 (Monterey) or later
- **Xcode**: 15.0 or later (currently using 26.0.1)
- **Apple Silicon** or Intel Mac

### Required Tools

1. **Homebrew** (4.6.11+)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Development Tools**
   ```bash
   brew install ffmpeg cmake git git-lfs swiftlint xcodegen
   ```

   Installed versions:
   - FFmpeg: 8.0
   - Git LFS: 3.7.0
   - SwiftLint: 0.61.0
   - XcodeGen: 2.44.1

3. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   xcodebuild -runFirstLaunch
   ```

## Project Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd blackbox_player
```

### 2. Generate Xcode Project

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

```bash
xcodegen generate
```

**Note**: The `.xcodeproj` file is git-ignored and regenerated from `project.yml`. Never edit the `.xcodeproj` directly.

### 3. Open in Xcode

```bash
open BlackboxPlayer.xcodeproj
```

### 4. Build and Run

- Select the `BlackboxPlayer` scheme
- Choose your Mac as the destination
- Press `⌘+R` to build and run

## Project Structure

```
blackbox_player/
├── .github/
│   └── workflows/
│       └── build.yml          # CI/CD pipeline
├── BlackboxPlayer/
│   ├── App/                   # Application entry point
│   │   └── BlackboxPlayerApp.swift
│   ├── Views/                 # SwiftUI views
│   │   └── ContentView.swift
│   ├── ViewModels/            # View models (MVVM pattern)
│   ├── Services/              # Business logic and services
│   ├── Models/                # Data models
│   ├── Utilities/             # Utility functions and extensions
│   │   └── BridgingHeader.h  # Objective-C bridging header
│   ├── Resources/             # Assets and resources
│   │   ├── Info.plist
│   │   ├── BlackboxPlayer.entitlements
│   │   └── Assets.xcassets/
│   └── Tests/                 # Unit and integration tests
├── docs/                      # Project documentation
├── project.yml                # XcodeGen project configuration
├── .swiftlint.yml            # SwiftLint configuration
├── .gitignore                # Git ignore rules
├── IMPLEMENTATION_CHECKLIST.md       # Implementation progress (English)
├── IMPLEMENTATION_CHECKLIST_kr.md    # Implementation progress (Korean)
└── README.md                 # Project overview
```

## FFmpeg Integration

The project is configured to use Homebrew's FFmpeg installation:

- **Include Path**: `/opt/homebrew/Cellar/ffmpeg/8.0_1/include`
- **Library Path**: `/opt/homebrew/Cellar/ffmpeg/8.0_1/lib`
- **Linked Libraries**: `avformat`, `avcodec`, `swscale`, `avutil`, `swresample`

These paths are configured in `project.yml` and may need to be updated if FFmpeg is upgraded.

## Build Scripts

This project includes comprehensive build automation scripts in the `scripts/` directory:

### Local Development

**Build Script** (`scripts/build.sh`)
```bash
# Debug build (default)
./scripts/build.sh

# Release build
./scripts/build.sh Release
```

Features:
- Automatic xcodegen project generation
- Clean build option (Release only)
- Interactive test execution prompt
- Colored output and progress indicators
- Build logs saved to `build/` directory

**Test Script** (`scripts/test.sh`)
```bash
# Run tests with coverage
./scripts/test.sh
```

Features:
- Executes all unit tests
- Generates coverage reports
- Creates `.xcresult` bundles
- Saves results to `build/TestResults/`

**Archive Script** (`scripts/archive.sh`)
```bash
# Create release archive
./scripts/archive.sh
```

Features:
- Interactive workflow
- Creates `.xcarchive` for distribution
- Optional archive export
- Optional DMG creation

### CI/CD

**CI Build Script** (`scripts/ci-build.sh`)
```bash
# Debug build (with tests)
./scripts/ci-build.sh

# Release build (no tests)
./scripts/ci-build.sh Release
```

Features:
- Non-interactive (no prompts)
- CI environment detection
- Code signing disabled for CI
- GitHub Actions integration

See `scripts/README.md` for detailed documentation.

## Testing

### Running Tests

The project includes comprehensive unit and integration tests covering all major components.

**Run all tests:**
```bash
# Using test script (recommended)
./scripts/test.sh

# Using build script with tests
./scripts/build.sh  # Will prompt to run tests after build

# Using xcodebuild
xcodebuild test -project BlackboxPlayer.xcodeproj -scheme BlackboxPlayer
```

**Run specific test classes:**
```bash
# Run only GPS/G-sensor integration tests
xcodebuild test -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -only-testing:BlackboxPlayerTests/GPSSensorIntegrationTests
```

### Test Suite Overview

The test suite is organized into functional categories:

| Test File | Focus Area | Test Count | Description |
|-----------|------------|------------|-------------|
| **GPSSensorIntegrationTests.swift** | GPS/G-Sensor Integration | 9 tests | End-to-end GPS and G-sensor visualization pipeline testing |
| **SyncControllerTests.swift** | Multi-Channel Sync | Multiple | Frame-accurate synchronization across 5 video channels |
| **VideoDecoderTests.swift** | Video Decoding | Multiple | FFmpeg H.264/MP3 decoding and frame extraction |
| **VideoChannelTests.swift** | Channel Management | Multiple | Individual video channel lifecycle and state management |
| **DataModelsTests.swift** | Data Models | Multiple | VideoFile, VideoMetadata, GPSPoint, AccelerationData |
| **EXT4FileSystemTests.swift** | File System | Multiple | EXT4 SD card access and file enumeration |
| **MultiChannelRendererTests.swift** | Metal Rendering | Multiple | GPU-accelerated multi-texture rendering |

### GPS/G-Sensor Integration Tests

The `GPSSensorIntegrationTests.swift` file provides comprehensive coverage of the GPS and G-sensor data processing pipeline:

**Test Categories:**

1. **Data Parsing Tests**
   - `testVideoMetadataGPSData()` - GPS point storage and retrieval
   - `testVideoMetadataAccelerationData()` - Acceleration data storage and retrieval
   - `testImpactEventDetection()` - Impact event detection from acceleration data

2. **Service Integration Tests**
   - `testGPSServiceIntegration()` - GPSService data loading from VideoMetadata
   - `testGPSInterpolation()` - Linear interpolation between GPS points

3. **Synchronization Tests**
   - `testVideoGPSSynchronization()` - Video playback time to GPS data synchronization
   - `testVideoGSensorSynchronization()` - Video playback time to G-sensor data synchronization
   - `testRealtimeSensorDataUpdate()` - Real-time sensor data updates during playback

4. **Performance Tests**
   - `testGPSDataSearchPerformance()` - Binary search performance with 10,000+ GPS points

**Data Pipeline Flow:**
```
VideoFile (with metadata)
    ↓
VideoMetadata
    ├─→ GPS Points Array → GPSService → getCurrentLocation(at:)
    └─→ Acceleration Array → GSensorService → getCurrentAcceleration(at:)
                ↓
         SyncController (30fps)
                ↓
    ┌───────────┴──────────┐
    ↓                      ↓
MapOverlay            GSensorChart
(GPS route)           (XYZ graph)
```

**Adding New Sensor Tests:**

When adding new GPS or G-sensor functionality, follow this pattern:

```swift
func testNewSensorFeature() {
    // Given: Create sample data
    let baseDate = Date()
    let gpsPoints = createSampleGPSPoints(baseDate: baseDate, count: 10)
    let metadata = VideoMetadata(gpsPoints: gpsPoints, accelerationData: [])

    // When: Load data and perform operation
    gpsService.loadGPSData(from: metadata, startTime: baseDate)
    let result = gpsService.performNewFeature()

    // Then: Assert expected behavior
    XCTAssertNotNil(result, "Expected result")
}
```

### Test Coverage Goals

- **Minimum Coverage**: 80% code coverage across all modules
- **Critical Paths**: 100% coverage for synchronization, decoding, and data parsing
- **Performance Tests**: All data-intensive operations must have performance benchmarks

### Generating Coverage Reports

```bash
# Run tests with coverage
./scripts/test.sh

# View coverage in Xcode
# After running tests: Product > Show Build Folder in Finder
# Navigate to: Logs/Test/*.xcresult
# Open with: xcodebuild -resultBundlePath <path> -json
```

## Building from Command Line

### Using Build Scripts (Recommended)

```bash
# Quick Debug build
./scripts/build.sh

# Release build
./scripts/build.sh Release

# Run tests
./scripts/test.sh
```

### Using xcodebuild Directly

**Clean Build**
```bash
xcodebuild -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -configuration Debug \
           clean build
```

**Run Tests**
```bash
xcodebuild -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -configuration Debug \
           test
```

**Run SwiftLint**
```bash
swiftlint lint BlackboxPlayer
```

## Code Signing

For development builds, the project uses **automatic code signing** with ad-hoc signing.

For distribution:
1. Configure your Apple Developer account in Xcode
2. Select your development team
3. Update `CODE_SIGN_STYLE` in `project.yml` if needed

## Continuous Integration

The project uses GitHub Actions for CI/CD:

- **Build and Test**: Runs on every push and pull request
- **SwiftLint**: Checks code quality
- **Coverage**: Reports test coverage

See `.github/workflows/build.yml` for configuration.

## Common Issues

### Issue: FFmpeg not found

**Error**: `ld: library not found for -lavformat`

**Solution**:
```bash
# Reinstall FFmpeg
brew reinstall ffmpeg

# Update paths in project.yml if needed
brew --prefix ffmpeg
```

### Issue: Xcode project out of sync

**Error**: Build settings or file references are incorrect

**Solution**:
```bash
# Regenerate the project
xcodegen generate

# Clean build
xcodebuild clean
```

### Issue: SwiftLint warnings

**Solution**:
```bash
# Auto-fix some issues
swiftlint --fix

# Or update .swiftlint.yml to adjust rules
```

## Development Workflow

1. **Make changes** in your editor
2. **Regenerate project** if you added/removed files:
   ```bash
   xcodegen generate
   ```
3. **Run SwiftLint** to check code quality:
   ```bash
   swiftlint lint BlackboxPlayer --quiet
   ```
4. **Build and test**:
   ```bash
   xcodebuild build test
   ```
5. **Commit changes**:
   ```bash
   git add .
   git commit -m "type(scope): description"
   ```

## Commit Message Format

Follow the conventional commits format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Examples**:
- `feat(player): add video playback controls`
- `fix(decoder): resolve memory leak in frame conversion`
- `docs(readme): update build instructions`

## Resources

- [Project Documentation](docs/)
- [Testing Guide](docs/TESTING.md)
- [Implementation Checklist](IMPLEMENTATION_CHECKLIST.md)
- [Technical Challenges](docs/05_technical_challenges.md)
- [Architecture](docs/03_architecture.md)

## Current Status

**Overall Progress**: 69/156 tasks (44.2%)

### Completed Phases

✅ **Phase 0: Preparation** - 11/15 tasks (73%)
- Environment setup complete
- Project structure created
- CI/CD pipeline configured
- FFmpeg integration complete
- EXT4 interface ready (mock implementation)

✅ **Phase 2: Single Channel Playback** - 18/22 tasks (82%)
- FFmpeg H.264/MP3 decoder implemented
- Metal renderer with GPU acceleration
- Playback controls (play/pause/seek/speed)
- Timeline scrubber with time display

✅ **Phase 3: Multi-Channel Sync** - 17/21 tasks (81%)
- Multi-channel architecture with VideoChannel
- SyncController with ±50ms accuracy
- 3 layout modes (Grid/Focus/Horizontal)
- Performance optimized (5 channels @ 30fps)

✅ **Phase 4 Week 2: Image Processing** - 20/38 tasks (53%)
- Screen capture (PNG/JPEG with timestamp)
- Video transformations (brightness/flip/zoom)
- Fullscreen mode with auto-hide controls
- Multi-display support

### In Progress

⏳ **Phase 4 Week 1: GPS & G-Sensor** (in progress)
- GPS service and map integration
- G-Sensor chart visualization
- ✅ GPS/G-sensor integration tests completed (GPSSensorIntegrationTests.swift)

### Pending

📋 **Phase 5: Export & Settings** - 0/16 tasks
- MP4 export pipeline
- Video repair functionality
- Settings management

📋 **Phase 6: Localization & Polish** - 0/20 tasks
- Multi-language support (KR/EN/JP)
- Dark mode implementation
- Code signing & notarization

See [IMPLEMENTATION_CHECKLIST_kr.md](IMPLEMENTATION_CHECKLIST_kr.md) for detailed progress.

---

**Last Updated**: 2025-10-12
**Xcode Version**: 26.0.1
**macOS Target**: 12.0+
