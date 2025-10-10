# 기술 스택

> 🌐 **Language**: [English](02_technology_stack.md) | [한국어](#)

## 권장 기술 스택

### 개요

```
┌─────────────────────────────────────────┐
│        macOS 네이티브 접근 방식          │
├─────────────────────────────────────────┤
│ UI 계층      : SwiftUI + AppKit        │
│ 영상         : AVFoundation + FFmpeg   │
│ 그래픽       : Metal                   │
│ 지도         : MapKit / Google Maps    │
│ 차트         : Core Graphics           │
│ 파일 시스템  : EXT4 Library (C/C++)    │
│ 빌드         : Xcode + CMake (hybrid)  │
└─────────────────────────────────────────┘
```

## 핵심 기술

### 1. 애플리케이션 프레임워크

#### SwiftUI + AppKit ⭐ (권장)

**장점:**
- 최고의 성능을 제공하는 네이티브 macOS 개발
- Apple 생태계와의 완벽한 통합
- 최신 선언형 UI 패러다임
- 뛰어난 개발자 경험

**단점:**
- Swift 전문 지식 필요
- macOS 전용(크로스 플랫폼 아님)

**사용 사례:**
- UI 계층
- 창 관리
- 시스템 통합
- 사용자 환경설정

**코드 예제:**
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

#### 대안: Qt (C++)

**장점:**
- 크로스 플랫폼(Windows, Linux, macOS)
- 포괄적인 위젯을 갖춘 성숙한 프레임워크
- 향후 확장 용이

**단점:**
- macOS에서 덜 네이티브한 느낌
- 상업적 사용 시 라이선스 비용
- 더 큰 바이너리 크기

**선택 시기:**
- 크로스 플랫폼 지원 필요 시
- 팀이 강력한 C++ 경험 보유
- 플랫폼 간 일관된 UI 필요

---

### 2. 영상 처리

#### FFmpeg (필수)

**기능:**
- H.264 디코딩
- MP4 먹싱/디먹싱
- 음성 처리(MP3)
- 광범위한 코덱 지원
- 스트림 조작

**설치:**
```bash
# 개발 환경 (Homebrew)
brew install ffmpeg

# 프로덕션 (정적 링킹)
./configure --enable-static --disable-shared \
            --enable-gpl --enable-libx264 \
            --enable-libmp3lame
make && make install
```

**주요 라이브러리:**
- `libavcodec`: 코덱 라이브러리
- `libavformat`: 컨테이너 포맷 I/O
- `libavutil`: 유틸리티 함수
- `libswscale`: 영상 스케일링 및 픽셀 포맷 변환

#### AVFoundation (Swift 통합)

**기능:**
- macOS 네이티브 영상 재생
- 하드웨어 가속 디코딩(VideoToolbox)
- 동기화된 재생 제어
- 시간 관리

**코드 예제:**
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

### 3. 파일 시스템 계층

#### 제공된 EXT4 라이브러리 (C/C++)

**통합 전략:**
- C/C++ 라이브러리를 Objective-C++로 래핑
- 브리징 헤더를 통해 Swift에 노출
- 블록 수준 I/O 작업 처리

**아키텍처:**
```
Swift 계층
    ↕ (브리징 헤더)
Objective-C++ 래퍼
    ↕ (C++ 상호운용)
EXT4 라이브러리 (C/C++)
    ↕ (블록 장치)
SD 카드 하드웨어
```

#### 선택사항: macOS용 FUSE

**목적:** 테스팅 및 개발
**설치:** `brew install macfuse`
**사용 사례:** EXT4를 사용자 공간 파일 시스템으로 마운트

---

### 4. 그래픽 및 렌더링

#### Metal (Swift 권장)

**장점:**
- Apple의 최신 GPU API
- macOS에서 최고의 성능
- 하드웨어 가속 렌더링
- 5채널용 멀티 텍스처 지원

**기능:**
- GPU 가속 영상 렌더링
- 실시간 이미지 처리(줌, 반전, 밝기)
- 렌더링 파이프라인에 대한 저수준 제어

**코드 예제:**
```swift
import Metal
import MetalKit

class VideoRenderer {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue

    func renderFrame(_ pixelBuffer: CVPixelBuffer, to view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // 픽셀 버퍼에서 텍스처 생성
        let texture = makeTexture(from: pixelBuffer)

        // 뷰에 렌더링
        let renderPassDescriptor = view.currentRenderPassDescriptor
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)

        // 그리기 명령...

        renderEncoder?.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}
```

#### 대안: OpenGL

**선택 시기:**
- 크로스 플랫폼 렌더링 필요
- 레거시 시스템 지원
- 팀이 OpenGL 경험 보유

**참고:** OpenGL은 macOS 10.14부터 사용 중단됨

---

### 5. 지도 및 GPS

#### 옵션 1: MapKit (Apple Maps)

**장점:**
- 네이티브 통합
- API 비용 없음
- 개인정보 친화적

**코드 예제:**
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

#### 옵션 2: Google Maps SDK

**장점:**
- 더 상세한 지도
- 더 나은 위성 이미지
- 사용자에게 익숙함

**비용:** 무료 티어: 월 28,000회 지도 로드

**코드 예제:**
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

#### 옵션 3: Mapbox GL

**장점:**
- 높은 커스터마이징 가능
- 오프라인 지도 지원
- 아름다운 스타일링 옵션

**비용:** 무료 티어: 월 50,000회 지도 로드

---

### 6. 데이터 시각화

#### Core Graphics

**사용 사례:** G-센서 차트 렌더링

**코드 예제:**
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

**최신 접근 방식:**
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

### 7. 빌드 및 패키징

#### Xcode

**목적:** Swift/Objective-C 개발용 주 IDE

**설정:**
- 배포 대상: macOS 12.0+
- Swift 버전: 5.9+
- 빌드 시스템: 새 빌드 시스템

#### CMake (C/C++ 컴포넌트용)

**목적:** EXT4 라이브러리 및 FFmpeg 통합 빌드

**CMakeLists.txt 예제:**
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

**목적:** macOS 설치 프로그램 생성

**설치:**
```bash
brew install create-dmg
```

**사용법:**
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

## 개발 도구

### 필수

1. **Xcode 15+**
   - Mac App Store에서 다운로드
   - 명령줄 도구: `xcode-select --install`

2. **Homebrew**
   - 패키지 관리자: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

3. **FFmpeg**
   - `brew install ffmpeg`

4. **Git**
   - `brew install git`

### 권장

1. **SwiftLint**
   - 코드 스타일 검사기
   - `brew install swiftlint`

2. **Instruments**
   - 프로파일링 도구(Xcode에 포함)
   - 성능 최적화에 필수

3. **SourceTree / Fork**
   - Git GUI 클라이언트

---

## 의존성 관리

### Swift Package Manager (SPM)

**Swift 의존성에 권장**

**Package.swift 예제:**
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

### CocoaPods (대안)

**Objective-C/C++ 라이브러리용**

**Podfile 예제:**
```ruby
platform :osx, '12.0'

target 'BlackboxPlayer' do
  use_frameworks!

  pod 'GoogleMaps'
  pod 'Realm', '~> 10.0'
end
```

---

## 기술 선택 근거

### SwiftUI + AppKit을 선택한 이유는?
- **네이티브 성능:** 오버헤드 없이 macOS API에 직접 액세스
- **미래 지향적:** Apple이 새 앱에 권장하는 프레임워크
- **생태계 통합:** macOS 기능(샌드박스, 공증)과 원활하게 통합
- **개발자 경험:** Swift가 Objective-C보다 안전하고 생산적

### OpenGL 대신 Metal을 선택한 이유는?
- **성능:** 멀티 텍스처 시나리오에서 10배 빠른 렌더링
- **최신 API:** 더 나은 개발자 경험 및 디버깅 도구
- **GPU 컴퓨팅:** GPU를 영상 처리 작업에 활용 가능
- **미래 지원:** OpenGL은 사용 중단됨, Metal이 미래

### FFmpeg을 선택한 이유는?
- **업계 표준:** 가장 널리 사용되는 영상 처리 라이브러리
- **포괄적:** 사실상 모든 영상/음성 포맷 지원
- **활발한 개발:** 정기적인 업데이트 및 보안 패치
- **허용적 라이선스:** LGPL은 동적 링킹 시 상업적 사용 허용

### EXT4 라이브러리 통합을 선택한 이유는?
- **대안 없음:** macOS는 네이티브로 EXT4에 액세스할 수 없음
- **직접 액세스:** 블록 수준 I/O가 완전한 제어 제공
- **성능:** FUSE 기반 솔루션보다 빠름
- **신뢰성:** 벤더 제공 라이브러리가 블랙박스 포맷과의 호환성 보장

---

## 라이선스 고려사항

### FFmpeg
- **LGPL 2.1+** (동적 링킹 시)
- **GPL 2.0+** (libx264와 같은 GPL 라이선스 컴포넌트 사용 시)
- **영향:** GPL 컴포넌트를 정적 링킹할 경우 GPL을 준수해야 함

### Google Maps SDK
- **독점:** API 키 필요 및 서비스 약관 준수
- **무료 티어:** 월 28,000회 지도 로드
- **대안:** 무제한 사용을 위해 MapKit 사용

### MapKit
- **무료:** API 비용 없음
- **Apple Developer Program 필요:** 연 $99

---

## 최소 시스템 요구사항

### 개발 머신
- **macOS:** 13.0(Ventura) 이상
- **RAM:** 최소 16GB, 32GB 권장
- **저장소:** 50GB 여유 공간
- **프로세서:** Apple Silicon(M1/M2/M3) 또는 Intel Core i7+

### 대상 사용자
- **macOS:** 12.0(Monterey) 이상
- **RAM:** 최소 8GB, 5채널 재생에 16GB
- **저장소:** 앱용 100MB + 내보낸 영상용 공간
- **프로세서:** Apple Silicon 또는 Intel Core i5+

---

## 다음 단계

1. **EXT4 라이브러리 호환성 확인**
   - 제공된 라이브러리 API 검토
   - macOS 12+에서 테스트
   - Swift 브리징 헤더 생성

2. **개발 환경 설정**
   - Xcode 15+ 설치
   - Homebrew 및 의존성 설치
   - 코드 서명 구성

3. **개념 증명 생성**
   - EXT4 읽기/쓰기 테스트
   - FFmpeg으로 단일 영상 재생
   - Metal 렌더링 테스트
