# Technology Stack

> 🌐 **Language**: [English](#) | [한국어](02_technology_stack_kr.md)

## Recommended Technology Stack

### Overview

```
┌─────────────────────────────────────────┐
│        macOS Native Approach            │
├─────────────────────────────────────────┤
│ UI Layer      : SwiftUI + AppKit        │
│ Video         : AVFoundation + FFmpeg   │
│ Graphics      : Metal                   │
│ Maps          : MapKit / Google Maps    │
│ Charts        : Core Graphics           │
│ File System   : EXT4 Library (C/C++)    │
│ Build         : Xcode + CMake (hybrid)  │
└─────────────────────────────────────────┘
```

## Core Technologies

### 1. Application Framework

#### SwiftUI + AppKit ⭐ (Recommended)

**Advantages:**
- Native macOS development with best performance
- Perfect integration with Apple ecosystem
- Modern declarative UI paradigm
- Excellent developer experience

**Disadvantages:**
- Requires Swift expertise
- macOS-specific (not cross-platform)

**Use Cases:**
- UI layer
- Window management
- System integration
- User preferences

**Code Example:**
```swift
import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = PlayerViewModel()

    var body: some View {
        HSplitView {
            FileListView()
            VideoPlayerView(channels: viewModel.channels)
            SidebarView()
        }
    }
}
```

#### Alternative: Qt (C++)

**Advantages:**
- Cross-platform (Windows, Linux, macOS)
- Mature framework with comprehensive widgets
- Easy future expansion

**Disadvantages:**
- Less native feel on macOS
- License costs (commercial use)
- Larger binary size

**When to Choose:**
- If cross-platform support is required
- Team has strong C++ experience
- Need for consistent UI across platforms

---

### 2. Video Processing

#### FFmpeg (Essential)

**Features:**
- H.264 decoding
- MP4 muxing/demuxing
- Audio processing (MP3)
- Extensive codec support
- Stream manipulation

**Installation:**
```bash
# Development (Homebrew)
brew install ffmpeg

# Production (Static linking)
./configure --enable-static --disable-shared \
            --enable-gpl --enable-libx264 \
            --enable-libmp3lame
make && make install
```

**Key Libraries:**
- `libavcodec`: Codec library
- `libavformat`: Container format I/O
- `libavutil`: Utility functions
- `libswscale`: Video scaling and pixel format conversion

#### AVFoundation (Swift Integration)

**Features:**
- macOS native video playback
- Hardware-accelerated decoding (VideoToolbox)
- Synchronized playback control
- Time management

**Code Example:**
```swift
import AVFoundation

class VideoPlayer {
    private var player: AVPlayer
    private var playerLayer: AVPlayerLayer

    func play(url: URL) {
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        player.play()
    }
}
```

---

### 3. File System Layer

#### Provided EXT4 Library (C/C++)

**Integration Strategy:**
- Wrap C/C++ library with Objective-C++
- Expose to Swift via bridging header
- Handle block-level I/O operations

**Architecture:**
```
Swift Layer
    ↕ (Bridging Header)
Objective-C++ Wrapper
    ↕ (C++ Interop)
EXT4 Library (C/C++)
    ↕ (Block Device)
SD Card Hardware
```

#### Optional: FUSE for macOS

**Purpose:** Testing and development
**Installation:** `brew install macfuse`
**Use Case:** Mount EXT4 as user-space file system

---

### 4. Graphics & Rendering

#### Metal (Recommended for Swift)

**Advantages:**
- Apple's modern GPU API
- Best performance on macOS
- Hardware-accelerated rendering
- Multi-texture support for 5 channels

**Features:**
- GPU-accelerated video rendering
- Real-time image processing (zoom, flip, brightness)
- Low-level control over rendering pipeline

**Code Example:**
```swift
import Metal
import MetalKit

class VideoRenderer {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue

    func renderFrame(_ pixelBuffer: CVPixelBuffer, to view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Create texture from pixel buffer
        let texture = makeTexture(from: pixelBuffer)

        // Render to view
        let renderPassDescriptor = view.currentRenderPassDescriptor
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)

        // Draw commands...

        renderEncoder?.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}
```

#### Alternative: OpenGL

**When to Choose:**
- Cross-platform rendering required
- Legacy system support
- Team has OpenGL experience

**Note:** OpenGL is deprecated on macOS since 10.14

---

### 5. Mapping & GPS

#### Option 1: MapKit (Apple Maps)

**Advantages:**
- Native integration
- No API costs
- Privacy-friendly

**Code Example:**
```swift
import MapKit

class GPSMapView: NSView {
    private let mapView = MKMapView()

    func updateRoute(points: [CLLocationCoordinate2D]) {
        let polyline = MKPolyline(coordinates: points, count: points.count)
        mapView.addOverlay(polyline)
    }
}
```

#### Option 2: Google Maps SDK

**Advantages:**
- More detailed maps
- Better satellite imagery
- Familiar to users

**Costs:** Free tier: 28,000 map loads/month

**Code Example:**
```swift
import GoogleMaps

class GMSMapView: NSView {
    private var mapView: GMSMapView!

    func drawRoute(path: [CLLocationCoordinate2D]) {
        let route = GMSPolyline()
        let path = GMSMutablePath()
        for point in path {
            path.add(point)
        }
        route.path = path
        route.map = mapView
    }
}
```

#### Option 3: Mapbox GL

**Advantages:**
- Highly customizable
- Offline maps support
- Beautiful styling options

**Costs:** Free tier: 50,000 map loads/month

---

### 6. Data Visualization

#### Core Graphics

**Use Case:** G-Sensor chart rendering

**Code Example:**
```swift
import CoreGraphics

class GSensorChart: NSView {
    func drawChart(data: [AccelerationData]) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setStrokeColor(NSColor.blue.cgColor)
        context.setLineWidth(2.0)

        context.beginPath()
        for (index, point) in data.enumerated() {
            let x = CGFloat(index) * scaleX
            let y = CGFloat(point.value) * scaleY

            if index == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.strokePath()
    }
}
```

#### Swift Charts (macOS 13+)

**Modern Approach:**
```swift
import Charts

struct GSensorChartView: View {
    let data: [AccelerationData]

    var body: some View {
        Chart(data) { item in
            LineMark(
                x: .value("Time", item.timestamp),
                y: .value("Acceleration", item.value)
            )
        }
    }
}
```

---

### 7. Build & Packaging

#### Xcode

**Purpose:** Primary IDE for Swift/Objective-C development

**Configuration:**
- Deployment Target: macOS 12.0+
- Swift Version: 5.9+
- Build System: New Build System

#### CMake (For C/C++ Components)

**Purpose:** Build EXT4 library and FFmpeg integration

**Example CMakeLists.txt:**
```cmake
cmake_minimum_required(VERSION 3.20)
project(EXT4Bridge)

add_library(ext4bridge STATIC
    ext4_wrapper.mm
    ext4_library.cpp
)

target_link_libraries(ext4bridge
    "-framework Foundation"
    ext4_library
)
```

#### create-dmg

**Purpose:** Generate macOS installer

**Installation:**
```bash
brew install create-dmg
```

**Usage:**
```bash
create-dmg \
  --volname "Blackbox Player" \
  --volicon "icon.icns" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "BlackboxPlayer.app" 200 190 \
  --hide-extension "BlackboxPlayer.app" \
  --app-drop-link 600 185 \
  "BlackboxPlayer-1.0.0.dmg" \
  "build/BlackboxPlayer.app"
```

---

## Development Tools

### Required

1. **Xcode 15+**
   - Download from Mac App Store
   - Command Line Tools: `xcode-select --install`

2. **Homebrew**
   - Package manager: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

3. **FFmpeg**
   - `brew install ffmpeg`

4. **Git**
   - `brew install git`

### Recommended

1. **SwiftLint**
   - Code style checker
   - `brew install swiftlint`

2. **Instruments**
   - Profiling tool (included with Xcode)
   - Essential for performance optimization

3. **SourceTree / Fork**
   - Git GUI client

---

## Dependencies Management

### Swift Package Manager (SPM)

**Recommended for Swift dependencies**

**Package.swift example:**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlackboxPlayer",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "BlackboxPlayer",
            dependencies: ["Alamofire"]
        )
    ]
)
```

### CocoaPods (Alternative)

**For Objective-C/C++ libraries**

**Podfile example:**
```ruby
platform :osx, '12.0'

target 'BlackboxPlayer' do
  use_frameworks!

  pod 'GoogleMaps'
  pod 'Realm', '~> 10.0'
end
```

---

## Rationale for Technology Choices

### Why SwiftUI + AppKit?
- **Native Performance:** Direct access to macOS APIs without overhead
- **Future-Proof:** Apple's recommended framework for new apps
- **Ecosystem Integration:** Seamless integration with macOS features (Sandbox, Notarization)
- **Developer Experience:** Swift is safer and more productive than Objective-C

### Why Metal over OpenGL?
- **Performance:** 10x faster rendering for multi-texture scenarios
- **Modern API:** Better developer experience and debugging tools
- **GPU Compute:** Can leverage GPU for video processing tasks
- **Future Support:** OpenGL is deprecated, Metal is the future

### Why FFmpeg?
- **Industry Standard:** Most widely used video processing library
- **Comprehensive:** Supports virtually all video/audio formats
- **Active Development:** Regular updates and security patches
- **Permissive License:** LGPL allows commercial use with dynamic linking

### Why EXT4 Library Integration?
- **No Alternative:** macOS cannot natively access EXT4
- **Direct Access:** Block-level I/O provides full control
- **Performance:** Faster than FUSE-based solutions
- **Reliability:** Vendor-provided library ensures compatibility with dashcam format

---

## License Considerations

### FFmpeg
- **LGPL 2.1+** (if dynamically linked)
- **GPL 2.0+** (if using GPL-licensed components like libx264)
- **Impact:** Must comply with GPL if statically linking GPL components

### Google Maps SDK
- **Proprietary:** Requires API key and compliance with Terms of Service
- **Free Tier:** 28,000 map loads per month
- **Alternative:** Use MapKit for unlimited usage

### MapKit
- **Free:** No API costs
- **Apple Developer Program required:** $99/year

---

## Minimum System Requirements

### Development Machine
- **macOS:** 13.0 (Ventura) or later
- **RAM:** 16GB minimum, 32GB recommended
- **Storage:** 50GB free space
- **Processor:** Apple Silicon (M1/M2/M3) or Intel Core i7+

### Target Users
- **macOS:** 12.0 (Monterey) or later
- **RAM:** 8GB minimum, 16GB for 5-channel playback
- **Storage:** 100MB for app + space for exported videos
- **Processor:** Apple Silicon or Intel Core i5+

---

## Next Steps

1. **Verify EXT4 Library Compatibility**
   - Review provided library API
   - Test on macOS 12+
   - Create Swift bridging header

2. **Set Up Development Environment**
   - Install Xcode 15+
   - Install Homebrew and dependencies
   - Configure code signing

3. **Create Proof of Concept**
   - EXT4 read/write test
   - Single video playback with FFmpeg
   - Metal rendering test
