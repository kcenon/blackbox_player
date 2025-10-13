/// @file ContentView.swift
/// @brief 블랙박스 플레이어 메인 콘텐츠 View
/// @author BlackboxPlayer Development Team
/// @details
/// BlackboxPlayer 앱의 메인 콘텐츠 View로, 전체 UI 구조와 비즈니스 로직을 통합합니다.
/// NavigationView 기반 마스터-디테일 레이아웃, 폴더 스캔, 멀티채널 비디오 플레이어,
/// GPS 지도 및 G-센서 그래프 시각화 기능을 제공합니다.

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                            ContentView                                       ║
 ║                  블랙박스 플레이어 메인 콘텐츠 View                            ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝

 📚 이 파일의 목적
 ════════════════════════════════════════════════════════════════════════════════
 BlackboxPlayer 앱의 메인 콘텐츠 View로, 전체 UI 구조와 비즈니스 로직을 통합합니다.

 이 파일은 프로젝트에서 가장 큰 View 파일 중 하나로, 다음을 담당합니다:
 • NavigationView 기반 마스터-디테일 레이아웃
 • 폴더 스캔 및 비디오 파일 로딩
 • 멀티채널 비디오 플레이어 통합
 • GPS 지도 및 G-센서 그래프 시각화
 • 재생 컨트롤 및 타임라인 슬라이더


 🏗️ 전체 레이아웃 구조
 ════════════════════════════════════════════════════════════════════════════════
 ```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │ 🔧 ⊞ 📂 🖥️                                           [Toolbar]          │
 ├─────────────┬───────────────────────────────────────────────────────────┤
 │             │                                                           │
 │   Sidebar   │                  Main Content                             │
 │             │                                                           │
 │ 📁 Folder   │  ┌─────────────────────────────────────────────────┐     │
 │ ─────────   │  │                                                 │     │
 │ 3 files     │  │         Multi-Channel Player                    │     │
 │             │  │         (4 cameras synchronized)                │     │
 │ ┌─────────┐ │  │                                                 │     │
 │ │📹 File1 │ │  └─────────────────────────────────────────────────┘     │
 │ ├─────────┤ │                                                           │
 │ │📹 File2 │ │  📋 File Information Card                                │
 │ ├─────────┤ │  📹 Camera Channels Card                                 │
 │ │📹 File3 │ │  📊 Metadata Card                                        │
 │ └─────────┘ │  🗺️  GPS Map Card                                        │
 │             │  📈 Acceleration Graph Card                              │
 │             │                                                           │
 └─────────────┴───────────────────────────────────────────────────────────┘
    (FileListView)                    (ScrollView)

 [Debug Log Overlay] (하단, 토글 가능)
 [Loading Overlay] (전체화면, 스캔 중)
 ```


 🎨 주요 컴포넌트
 ════════════════════════════════════════════════════════════════════════════════

 1. **NavigationView**
    - 마스터(Sidebar) - 디테일(Main Content) 레이아웃
    - Sidebar: 파일 목록 + 검색/필터
    - Main Content: 선택된 파일의 상세 정보

 2. **Toolbar**
    - 사이드바 토글 버튼
    - 폴더 열기 버튼 (NSOpenPanel)
    - 디버그 로그 토글

 3. **Sidebar** (300-500px)
    - 현재 폴더 경로 표시
    - 파일 개수 표시
    - FileListView 통합 (검색/필터/선택)

 4. **Main Content**
    - Empty State: 파일 미선택 시 안내 화면
    - File Info View: 선택된 파일의 상세 정보
      - MultiChannelPlayerView (멀티채널 플레이어)
      - File Information Card
      - Camera Channels Card
      - Metadata Card
      - GPS Map Card (MapKit)
      - Acceleration Graph Card (Custom Drawing)

 5. **Overlays**
    - Loading Overlay: 폴더 스캔 중 표시
    - Debug Log Overlay: 하단에서 슬라이드 업


 📊 State 관리 패턴
 ════════════════════════════════════════════════════════════════════════════════

 이 View는 @State로 15개의 상태를 관리합니다:

 **파일 관련 State:**
 ```swift
 @State private var selectedVideoFile: VideoFile?    // 선택된 파일
 @State private var videoFiles: [VideoFile]          // 전체 파일 목록
 @State private var currentFolderPath: String?       // 현재 폴더 경로
 ```

 **UI 관련 State:**
 ```swift
 @State private var showSidebar = true               // 사이드바 표시 여부
 @State private var showDebugLog = false             // 디버그 로그 표시 여부
 @State private var isLoading = false                // 로딩 상태
 @State private var showError = false                // 에러 알림 표시
 @State private var errorMessage = ""                // 에러 메시지
 ```

 **재생 관련 State (시뮬레이션):**
 ```swift
 @State private var isPlaying = false                // 재생 중 여부
 @State private var currentPlaybackTime: Double      // 현재 재생 시간
 @State private var playbackSpeed: Double = 1.0      // 재생 속도
 @State private var volume: Double = 0.8             // 볼륨
 @State private var showControls = true              // 컨트롤 표시 여부
 ```

 📌 @State란?
    SwiftUI의 Property Wrapper로, 값이 변경되면 자동으로 View를 재렌더링합니다.
    private로 선언하여 현재 View 내부에서만 사용 가능합니다.

 📌 왜 이렇게 많은 State가 필요한가요?
    ContentView는 앱의 최상위 View로 다양한 UI 상태를 관리해야 합니다.
    각 State는 특정 UI 요소의 표시/동작을 제어합니다.


 🔌 서비스 통합
 ════════════════════════════════════════════════════════════════════════════════

 **FileScanner**
 - 역할: 폴더를 스캔하여 블랙박스 파일 그룹 탐지
 - 사용 시점: openFolder() → scanAndLoadFolder()
 - 동작: 백그라운드 스레드에서 파일 시스템 스캔

 **VideoFileLoader**
 - 역할: FileGroup → VideoFile 변환
 - 사용 시점: scanAndLoadFolder() → 파일 로드
 - 동작: 메타데이터 파싱 및 VideoFile 객체 생성

 ```
 사용자 액션          서비스 흐름
 ─────────────────────────────────────────
 [Open Folder]
      ↓
 NSOpenPanel (폴더 선택)
      ↓
 FileScanner.scanDirectory()
      ↓ (백그라운드)
 FileGroup[] 생성
      ↓
 VideoFileLoader.loadVideoFiles()
      ↓
 VideoFile[] 생성
      ↓ (메인 스레드)
 videoFiles 업데이트
      ↓
 View 자동 재렌더링
 ```


 🎯 핵심 기능 흐름
 ════════════════════════════════════════════════════════════════════════════════

 ### 1. 폴더 열기 흐름
 ```
 1) Toolbar > "Open Folder" 버튼 클릭
      ↓
 2) openFolder() 실행
      ↓
 3) NSOpenPanel 표시 (macOS 네이티브 폴더 선택 대화상자)
      ↓
 4) 사용자가 폴더 선택 → scanAndLoadFolder(URL) 호출
      ↓
 5) isLoading = true (로딩 오버레이 표시)
      ↓
 6) DispatchQueue.global() → 백그라운드 스레드에서 스캔
      ↓
 7) FileScanner.scanDirectory() → FileGroup[] 생성
      ↓
 8) VideoFileLoader.loadVideoFiles() → VideoFile[] 생성
      ↓
 9) DispatchQueue.main.async → 메인 스레드로 복귀
      ↓
 10) videoFiles 업데이트, isLoading = false
      ↓
 11) 첫 번째 파일 자동 선택
      ↓
 12) View 재렌더링 (파일 목록 + 상세 정보 표시)
 ```

 ### 2. 파일 선택 흐름
 ```
 1) Sidebar > FileListView에서 파일 탭
      ↓
 2) selectedVideoFile = file (바인딩으로 전달)
      ↓
 3) mainContent 조건부 렌더링
      ↓ if selectedFile != nil
 4) fileInfoView(for: file) 호출
      ↓
 5) ScrollView 내부에 순서대로 표시:
      - MultiChannelPlayerView (비디오 플레이어)
      - File Information Card (파일명, 타임스탬프, 크기 등)
      - Camera Channels Card (채널 목록)
      - Metadata Card (GPS, G-센서 요약)
      - GPS Map Card (MapKit 통합)
      - Acceleration Graph Card (Custom Drawing)
 ```

 ### 3. GPS 지도 표시 흐름
 ```
 1) videoFile.hasGPSData == true 확인
      ↓
 2) gpsMapCard(for: videoFile) 호출
      ↓
 3) GPSMapView(gpsPoints: [...]) 생성
      ↓ NSViewRepresentable
 4) makeNSView() → MKMapView 생성
      ↓
 5) updateNSView() → GPS 포인트 처리
      ↓
 6) MKPolyline으로 경로 그리기
      ↓
 7) 시작/끝 지점에 MKPointAnnotation 추가
      ↓
 8) 지도 영역 설정 (1km 반경)
 ```

 ### 4. 가속도 그래프 표시 흐름
 ```
 1) videoFile.hasAccelerationData == true 확인
      ↓
 2) accelerationGraphCard(for: videoFile) 호출
      ↓
 3) AccelerationGraphView(accelerationData: [...]) 생성
      ↓
 4) GeometryReader로 크기 측정
      ↓
 5) gridLines() → 격자 그리기
      ↓
 6) accelerationCurves() → 3개 축 그래프 그리기
      ↓ KeyPath 사용
 7) X축 (빨강), Y축 (초록), Z축 (파랑) Path 생성
      ↓
 8) ±2G 범위로 정규화하여 표시
      ↓
 9) Legend 표시 (우측 상단)
 ```


 🧩 SwiftUI 핵심 개념
 ════════════════════════════════════════════════════════════════════════════════

 ### 1. NavigationView (Master-Detail)
 ```swift
 NavigationView {
     // Master (Sidebar)
     if showSidebar { sidebar }

     // Detail (Main Content)
     mainContent
 }
 ```
 - macOS에서 사이드바 + 메인 콘텐츠 레이아웃 구현
 - showSidebar로 사이드바 토글 가능
 - .frame(minWidth:idealWidth:maxWidth:)로 크기 제한

 ### 2. Toolbar
 ```swift
 .toolbar {
     ToolbarItemGroup(placement: .navigation) {
         // 버튼들...
     }
 }
 ```
 - macOS 앱의 상단 툴바 커스터마이징
 - .navigation 배치: 좌측 영역
 - .help() modifier: 툴팁 표시

 ### 3. Overlay
 ```swift
 .overlay {
     if isLoading { ... }
 }
 .overlay(alignment: .bottom) {
     if showDebugLog { DebugLogView() }
 }
 ```
 - 기존 View 위에 다른 View를 겹쳐 표시
 - alignment로 위치 지정
 - 조건부 렌더링으로 표시/숨김

 ### 4. Alert
 ```swift
 .alert("Error", isPresented: $showError) {
     Button("OK", role: .cancel) { }
 } message: {
     Text(errorMessage)
 }
 ```
 - @State 바인딩으로 알림 표시 제어
 - showError = true 시 자동으로 알림 표시
 - 버튼 클릭 시 자동으로 false로 변경

 ### 5. GeometryReader
 ```swift
 GeometryReader { geometry in
     // geometry.size로 부모 크기 접근
     let layout = calculateChannelLayout(count: channels.count, in: geometry.size)
     ...
 }
 ```
 - 부모 View의 크기를 읽어서 동적 레이아웃 구성
 - 멀티채널 레이아웃 계산에 사용
 - DragGesture와 함께 타임라인 슬라이더 구현

 ### 6. NSViewRepresentable (GPSMapView)
 ```swift
 struct GPSMapView: NSViewRepresentable {
     func makeNSView(context: Context) -> MKMapView { ... }
     func updateNSView(_ mapView: MKMapView, context: Context) { ... }
     func makeCoordinator() -> Coordinator { ... }
 }
 ```
 - AppKit(macOS)의 NSView를 SwiftUI에서 사용
 - MKMapView (MapKit) 통합
 - Coordinator 패턴으로 델리게이트 처리

 ### 7. Property Wrapper: @State
 ```swift
 @State private var selectedVideoFile: VideoFile?
 ```
 - View 내부 상태 관리
 - 값 변경 시 자동 View 재렌더링
 - private: 외부 접근 불가

 ### 8. Binding ($)
 ```swift
 FileListView(
     videoFiles: $videoFiles,           // Binding<[VideoFile]>
     selectedFile: $selectedVideoFile   // Binding<VideoFile?>
 )
 ```
 - $ 접두사로 양방향 바인딩 생성
 - 자식 View가 부모의 State를 직접 수정 가능


 ⚙️ 비동기 처리 패턴
 ════════════════════════════════════════════════════════════════════════════════

 **폴더 스캔 시 백그라운드 처리:**
 ```swift
 DispatchQueue.global(qos: .userInitiated).async {
     // 🔄 백그라운드 스레드
     do {
         let groups = try fileScanner.scanDirectory(folderURL)
         let loadedFiles = videoFileLoader.loadVideoFiles(from: groups)

         DispatchQueue.main.async {
             // 🎨 메인 스레드 (UI 업데이트)
             self.videoFiles = loadedFiles
             self.isLoading = false
         }
     } catch {
         DispatchQueue.main.async {
             self.errorMessage = "Failed: \(error.localizedDescription)"
             self.showError = true
         }
     }
 }
 ```

 📌 왜 백그라운드 스레드를 사용하나요?
    파일 스캔은 I/O 작업으로 시간이 오래 걸릴 수 있습니다.
    메인 스레드에서 실행하면 UI가 멈추므로(freeze), 백그라운드에서 처리합니다.

 📌 왜 메인 스레드로 다시 돌아가나요?
    SwiftUI에서 UI 업데이트는 반드시 메인 스레드에서 해야 합니다.
    @State 값 변경도 메인 스레드에서 수행해야 자동 재렌더링이 동작합니다.


 🗺️ MapKit 통합 패턴
 ════════════════════════════════════════════════════════════════════════════════

 **GPSMapView (NSViewRepresentable):**

 1. **makeNSView()** - 초기 설정
    ```swift
    let mapView = MKMapView()
    mapView.mapType = .standard        // 표준 지도
    mapView.showsUserLocation = false  // 사용자 위치 안 보임
    mapView.isZoomEnabled = true       // 줌 가능
    mapView.isScrollEnabled = true     // 스크롤 가능
    ```

 2. **updateNSView()** - 데이터 업데이트
    ```swift
    // 기존 오버레이 제거
    mapView.removeOverlays(mapView.overlays)

    // GPS 포인트 → CLLocationCoordinate2D 변환
    let coordinates = gpsPoints.map { CLLocationCoordinate2D(...) }

    // MKPolyline으로 경로 그리기
    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    mapView.addOverlay(polyline)

    // 시작/끝 지점 마커 추가
    mapView.addAnnotation(startAnnotation)
    mapView.addAnnotation(endAnnotation)
    ```

 3. **Coordinator** - 델리게이트 패턴
    ```swift
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = NSColor.systemBlue  // 파란색 선
            renderer.lineWidth = 3                      // 3px 두께
            return renderer
        }
    }
    ```


 📈 Custom Drawing 패턴 (가속도 그래프)
 ════════════════════════════════════════════════════════════════════════════════

 **AccelerationGraphView:**

 1. **GeometryReader로 크기 측정**
    ```swift
    GeometryReader { geometry in
        ZStack {
            gridLines(in: geometry.size)
            accelerationCurves(in: geometry.size)
            legend
        }
    }
    ```

 2. **Path로 그래프 그리기**
    ```swift
    Path { path in
        let points = accelerationData.enumerated().map { index, data in
            let x = size.width * CGFloat(index) / CGFloat(count - 1)
            let value = data[keyPath: keyPath]                    // KeyPath 사용
            let normalizedValue = (value + maxValue) / (2 * maxValue)
            let y = size.height * (1 - CGFloat(normalizedValue)) // 반전 (위→0, 아래→1)
            return CGPoint(x: x, y: y)
        }

        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
    }
    .stroke(color, lineWidth: 2)
    ```

 3. **KeyPath를 사용한 동적 접근**
    ```swift
    accelerationPath(for: \.x, in: size, color: .red)    // X축
    accelerationPath(for: \.y, in: size, color: .green)  // Y축
    accelerationPath(for: \.z, in: size, color: .blue)   // Z축
    ```
    - KeyPath: 타입 안전한 프로퍼티 참조
    - 런타임에 다른 프로퍼티 값 읽기 가능


 🔧 NSOpenPanel 사용 패턴
 ════════════════════════════════════════════════════════════════════════════════

 **macOS 네이티브 폴더 선택 대화상자:**
 ```swift
 private func openFolder() {
     let panel = NSOpenPanel()                        // 패널 생성
     panel.canChooseFiles = false                     // 파일 선택 불가
     panel.canChooseDirectories = true                // 폴더 선택 가능
     panel.allowsMultipleSelection = false            // 단일 선택만
     panel.message = "Select a folder containing..."  // 안내 메시지
     panel.prompt = "Select"                          // 버튼 텍스트

     panel.begin { response in                        // 비동기 표시
         if response == .OK, let url = panel.url {
             scanAndLoadFolder(url)
         }
     }
 }
 ```

 📌 .begin vs .runModal:
    • .begin: 비동기, UI를 차단하지 않음 (권장)
    • .runModal: 동기, 선택 완료까지 UI 차단


 🎮 사용 예시
 ════════════════════════════════════════════════════════════════════════════════

 ```swift
 // 1. 앱 실행 시 테스트 파일 로드
 @State private var videoFiles: [VideoFile] = VideoFile.allTestFiles
 // → 7개 샘플 파일 자동 로드

 // 2. 폴더 열기
 사용자: Toolbar > "Open Folder" 클릭
      → NSOpenPanel 표시
      → 폴더 선택 (/Users/me/Blackbox)
      → FileScanner 동작
      → VideoFile[] 생성
      → Sidebar에 파일 목록 표시

 // 3. 파일 선택
 사용자: Sidebar > "2024_03_15_14_23_45_F.mp4" 탭
      → selectedVideoFile = file
      → Main Content에 상세 정보 표시
      → MultiChannelPlayerView 로드
      → GPS 지도 표시
      → 가속도 그래프 표시

 // 4. 사이드바 토글
 사용자: Toolbar > Sidebar 버튼 클릭
      → showSidebar.toggle()
      → Sidebar 숨김/표시

 // 5. 새로고침
 사용자: Sidebar > Refresh 버튼 클릭
      → refreshFileList()
      → 동일 폴더 재스캔
      → 파일 목록 업데이트
 ```


 ═══════════════════════════════════════════════════════════════════════════════
 */

import SwiftUI
import MapKit
import AppKit
import Combine

/// @struct ContentView
/// @brief 블랙박스 플레이어의 메인 콘텐츠 View
///
/// @details
/// BlackboxPlayer 앱의 최상위 View로 다음 기능을 제공합니다:
/// - NavigationView 기반 마스터-디테일 레이아웃
/// - 폴더 스캔 및 비디오 파일 로딩
/// - 멀티채널 비디오 플레이어 통합
/// - GPS 지도 및 G-센서 그래프 시각화
/// - 재생 컨트롤 및 타임라인 슬라이더
///
/// ## 주요 기능
/// - **NavigationView 레이아웃**: 사이드바(파일 목록) + 메인 콘텐츠(상세 정보)
/// - **폴더 스캔**: NSOpenPanel → FileScanner → VideoFileLoader
/// - **멀티채널 플레이어**: 최대 5개 카메라 동기화 재생
/// - **GPS 지도**: MapKit 통합, 경로 시각화
/// - **G-센서 그래프**: Custom Path Drawing, 3축 실시간 표시
/// - **비동기 처리**: DispatchQueue로 백그라운드 스캔, 메인 스레드 UI 업데이트
///
/// ## State 관리
/// 15개의 @State 프로퍼티로 UI 상태 관리:
/// - 파일 관련: selectedVideoFile, videoFiles, currentFolderPath
/// - UI 관련: showSidebar, showDebugLog, isLoading, showError
/// - 재생 관련: isPlaying, currentPlaybackTime, playbackSpeed, volume
///
/// ## 서비스 통합
/// - FileScanner: 폴더 스캔 및 파일 그룹 탐지
/// - VideoFileLoader: FileGroup → VideoFile 변환
struct ContentView: View {
    // MARK: - State Properties

    /// @var selectedVideoFile
    /// @brief 현재 선택된 비디오 파일
    @State private var selectedVideoFile: VideoFile?

    /// @var videoFiles
    /// @brief 전체 비디오 파일 목록
    @State private var videoFiles: [VideoFile] = VideoFile.allTestFiles

    /// @var showSidebar
    /// @brief 사이드바 표시 여부
    @State private var showSidebar = true

    /// @var isPlaying
    /// @brief 재생 중 여부 (시뮬레이션)
    @State private var isPlaying = false

    /// @var currentPlaybackTime
    /// @brief 현재 재생 시간 (초 단위)
    @State private var currentPlaybackTime: Double = 0.0

    /// @var playbackSpeed
    /// @brief 재생 속도 (1.0 = 정상 속도)
    @State private var playbackSpeed: Double = 1.0

    /// @var volume
    /// @brief 볼륨 (0.0 ~ 1.0)
    @State private var volume: Double = 0.8

    /// @var showControls
    /// @brief 컨트롤 표시 여부
    @State private var showControls = true

    /// @var currentFolderPath
    /// @brief 현재 열린 폴더 경로
    @State private var currentFolderPath: String?

    /// @var isLoading
    /// @brief 로딩 상태 (폴더 스캔 중)
    @State private var isLoading = false

    /// @var showError
    /// @brief 에러 알림 표시 여부
    @State private var showError = false

    /// @var errorMessage
    /// @brief 에러 메시지 내용
    @State private var errorMessage = ""

    /// @var showDebugLog
    /// @brief 디버그 로그 표시 여부
    @State private var showDebugLog = false

    // MARK: - Services

    private let fileScanner = FileScanner()
    private let videoFileLoader = VideoFileLoader()

    // MARK: - Body

    var body: some View {
        NavigationView {
            // Sidebar: File list
            if showSidebar {
                sidebar
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 500)
            }

            // Main content
            mainContent
                .frame(minWidth: 600, minHeight: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { showSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle sidebar")

                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open blackbox video folder")
                .disabled(isLoading)

                Button(action: { showDebugLog.toggle() }) {
                    Image(systemName: showDebugLog ? "terminal.fill" : "terminal")
                }
                .help("Toggle debug log")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(.circular)
                        Text("Scanning folder...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottom) {
            if showDebugLog {
                DebugLogView()
                    .padding()
                    .transition(.move(edge: .bottom))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolderRequested)) { _ in
            openFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshFileListRequested)) { _ in
            refreshFileList()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarRequested)) { _ in
            showSidebar.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMetadataOverlayRequested)) { _ in
            print("Toggle metadata overlay - not yet implemented")
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMapOverlayRequested)) { _ in
            print("Toggle map overlay - not yet implemented")
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleGraphOverlayRequested)) { _ in
            print("Toggle graph overlay - not yet implemented")
        }
        .onReceive(NotificationCenter.default.publisher(for: .playPauseRequested)) { _ in
            isPlaying.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stepForwardRequested)) { _ in
            print("Step forward - not yet implemented")
        }
        .onReceive(NotificationCenter.default.publisher(for: .stepBackwardRequested)) { _ in
            print("Step backward - not yet implemented")
        }
        .onReceive(NotificationCenter.default.publisher(for: .increaseSpeedRequested)) { _ in
            let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0]
            if let currentIndex = speeds.firstIndex(of: playbackSpeed),
               currentIndex < speeds.count - 1 {
                playbackSpeed = speeds[currentIndex + 1]
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .decreaseSpeedRequested)) { _ in
            let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0]
            if let currentIndex = speeds.firstIndex(of: playbackSpeed),
               currentIndex > 0 {
                playbackSpeed = speeds[currentIndex - 1]
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .normalSpeedRequested)) { _ in
            playbackSpeed = 1.0
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAboutRequested)) { _ in
            print("Show about window - not yet implemented")
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHelpRequested)) { _ in
            print("Show help - not yet implemented")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Video Files")
                        .font(.headline)

                    Spacer()

                    Button(action: refreshFileList) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh file list")
                    .disabled(isLoading || currentFolderPath == nil)
                }
                .padding(.horizontal)
                .padding(.top)

                if let folderPath = currentFolderPath {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                        Text((folderPath as NSString).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(videoFiles.count) files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else {
                    Text("No folder selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }

            Divider()

            // File list
            FileListView(
                videoFiles: $videoFiles,
                selectedFile: $selectedVideoFile
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            if let selectedFile = selectedVideoFile {
                // Selected file info
                fileInfoView(for: selectedFile)
            } else {
                // Empty state
                emptyState
            }
        }
        .background(Color.black)
    }

    // MARK: - File Info View

    private func fileInfoView(for videoFile: VideoFile) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Video thumbnail placeholder
                videoThumbnail(for: videoFile)

                // File information
                fileInformationCard(for: videoFile)

                // Channel information
                channelsCard(for: videoFile)

                // Metadata information
                if videoFile.hasGPSData || videoFile.hasAccelerationData {
                    metadataCard(for: videoFile)
                }

                // GPS Map
                if videoFile.hasGPSData {
                    gpsMapCard(for: videoFile)
                }

                // Acceleration Graph
                if videoFile.hasAccelerationData {
                    accelerationGraphCard(for: videoFile)
                }
            }
            .padding()
        }
    }

    private func videoThumbnail(for videoFile: VideoFile) -> some View {
        // Multi-channel video player
        MultiChannelPlayerView(videoFile: videoFile)
            .id(videoFile.id)  // Force view recreation when video changes
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(12)
            .shadow(radius: 4)
    }

    private var singleChannelPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.8))

            Text("Video Player")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Text("Implementation pending")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func multiChannelLayout(for videoFile: VideoFile) -> some View {
        GeometryReader { geometry in
            let channels = videoFile.channels.filter(\.isEnabled)
            let layout = calculateChannelLayout(count: channels.count, in: geometry.size)

            ZStack {
                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                    if index < layout.count {
                        channelPlaceholder(for: channel)
                            .frame(width: layout[index].width, height: layout[index].height)
                            .position(x: layout[index].x, y: layout[index].y)
                    }
                }

                // Play overlay
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.9))

                    Text("\(channels.count) Channels")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
            }
        }
    }

    private func channelPlaceholder(for channel: ChannelInfo) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))

                Text(channel.position.shortName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func calculateChannelLayout(count: Int, in size: CGSize) -> [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] {
        var layout: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = []

        switch count {
        case 1:
            layout.append((x: size.width / 2, y: size.height / 2, width: size.width, height: size.height))

        case 2:
            // Side by side
            let w = size.width / 2
            layout.append((x: w / 2, y: size.height / 2, width: w, height: size.height))
            layout.append((x: w + w / 2, y: size.height / 2, width: w, height: size.height))

        case 3:
            // One large on left, two stacked on right
            let w = size.width * 2 / 3
            let h = size.height / 2
            layout.append((x: w / 2, y: size.height / 2, width: w, height: size.height))
            layout.append((x: w + (size.width - w) / 2, y: h / 2, width: size.width - w, height: h))
            layout.append((x: w + (size.width - w) / 2, y: h + h / 2, width: size.width - w, height: h))

        case 4:
            // 2x2 grid
            let w = size.width / 2
            let h = size.height / 2
            layout.append((x: w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w / 2, y: h + h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h + h / 2, width: w, height: h))

        case 5:
            // 3 on top, 2 on bottom
            let w = size.width / 3
            let h = size.height / 2
            // Top row
            layout.append((x: w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h / 2, width: w, height: h))
            layout.append((x: 2 * w + w / 2, y: h / 2, width: w, height: h))
            // Bottom row
            let bottomW = size.width / 2
            layout.append((x: bottomW / 2, y: h + h / 2, width: bottomW, height: h))
            layout.append((x: bottomW + bottomW / 2, y: h + h / 2, width: bottomW, height: h))

        default:
            // Fallback: single channel
            layout.append((x: size.width / 2, y: size.height / 2, width: size.width, height: size.height))
        }

        return layout
    }

    private func fileInformationCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File Information")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            InfoRow(label: "Filename", value: videoFile.baseFilename)
            InfoRow(label: "Event Type", value: videoFile.eventType.displayName)
            InfoRow(label: "Timestamp", value: videoFile.timestampString)
            InfoRow(label: "Duration", value: videoFile.durationString)
            InfoRow(label: "File Size", value: videoFile.totalFileSizeString)
            InfoRow(label: "Favorite", value: videoFile.isFavorite ? "Yes" : "No")

            if let notes = videoFile.notes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(notes)
                        .foregroundColor(.white)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func channelsCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Channels (\(videoFile.channelCount))")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            ForEach(videoFile.channels, id: \.id) { channel in
                HStack {
                    Image(systemName: "video.fill")
                        .foregroundColor(channel.isEnabled ? .green : .gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.position.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text("\(channel.width)x\(channel.height) @ \(Int(channel.frameRate))fps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(channel.codec ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func metadataCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            if videoFile.hasGPSData {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("GPS Data")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.metadata.gpsPoints.count) points")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if videoFile.hasAccelerationData {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.blue)
                    Text("G-Sensor Data")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.metadata.accelerationData.count) points")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if videoFile.hasImpactEvents {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Impact Events")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.impactEventCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Video Selected")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Select a video from the sidebar to view details")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Button(action: { showSidebar = true }) {
                Label("Show Sidebar", systemImage: "sidebar.left")
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundColor(.white)
    }

    // MARK: - GPS Map Card

    private func gpsMapCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.green)
                Text("GPS Route")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(videoFile.metadata.gpsPoints.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Map view
            GPSMapView(gpsPoints: videoFile.metadata.gpsPoints)
                .frame(height: 300)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Acceleration Graph Card

    private func accelerationGraphCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                Text("G-Sensor Data")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(videoFile.metadata.accelerationData.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Graph view
            AccelerationGraphView(accelerationData: videoFile.metadata.accelerationData)
                .frame(height: 200)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Playback Controls

    private func playbackControls(for videoFile: VideoFile) -> some View {
        VStack(spacing: 0) {
            // Timeline
            timelineSlider(for: videoFile)
                .padding(.horizontal)
                .padding(.top, 8)

            // Control buttons
            HStack(spacing: 20) {
                // Play/Pause button
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                // Seek backward 10s
                Button(action: { seekBy(-10, in: videoFile) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Seek forward 10s
                Button(action: { seekBy(10, in: videoFile) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Current time / Duration
                Text(formatTime(currentPlaybackTime) + " / " + videoFile.durationString)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                // Speed control
                speedControl

                // Volume control
                volumeControl
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func timelineSlider(for videoFile: VideoFile) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                // Progress
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * (currentPlaybackTime / max(1, videoFile.duration)), height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: geometry.size.width * (currentPlaybackTime / max(1, videoFile.duration)) - 6)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newTime = Double(value.location.x / geometry.size.width) * videoFile.duration
                        currentPlaybackTime = max(0, min(videoFile.duration, newTime))
                    }
            )
        }
        .frame(height: 12)
    }

    private var speedControl: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: { playbackSpeed = speed }) {
                    HStack {
                        Text(formatSpeed(speed))
                        if playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge")
                    .font(.system(size: 14))
                Text(formatSpeed(playbackSpeed))
                    .font(.system(size: 13))
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 28)
            .background(Color.white.opacity(0.2))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Button(action: { volume = volume > 0 ? 0 : 0.8 }) {
                Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Slider(value: $volume, in: 0...1)
                .frame(width: 80)
                .accentColor(.white)
        }
    }

    private func seekBy(_ seconds: Double, in videoFile: VideoFile) {
        currentPlaybackTime = max(0, min(videoFile.duration, currentPlaybackTime + seconds))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.2gx", speed)
    }

    // MARK: - Actions

    /// @brief 폴더 선택 대화상자 열기
    ///
    /// @details
    /// NSOpenPanel을 사용하여 블랙박스 비디오 파일이 있는 폴더를 선택합니다.
    /// 폴더 선택 후 scanAndLoadFolder() 메서드를 호출하여 파일을 로드합니다.
    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing blackbox video files"
        panel.prompt = "Select"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                scanAndLoadFolder(url)
            }
        }
    }

    /// @brief 폴더 스캔 및 비디오 파일 로드
    ///
    /// @param folderURL 스캔할 폴더의 URL
    ///
    /// @details
    /// 백그라운드 스레드에서 FileScanner로 폴더를 스캔하고,
    /// VideoFileLoader로 파일을 로드한 후 메인 스레드에서 UI를 업데이트합니다.
    private func scanAndLoadFolder(_ folderURL: URL) {
        isLoading = true
        selectedVideoFile = nil

        // Perform scanning on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Scan directory
                let groups = try fileScanner.scanDirectory(folderURL)

                // Load video files
                let loadedFiles = videoFileLoader.loadVideoFiles(from: groups)

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.currentFolderPath = folderURL.path
                    self.videoFiles = loadedFiles
                    self.isLoading = false

                    // Select first file if available
                    if let firstFile = loadedFiles.first {
                        self.selectedVideoFile = firstFile
                    }
                }
            } catch {
                // Handle error on main thread
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to scan folder: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    /// @brief 현재 폴더에서 파일 목록 새로고침
    ///
    /// @details
    /// currentFolderPath가 설정되어 있으면 해당 폴더를 다시 스캔하고,
    /// 설정되어 있지 않으면 테스트 파일을 로드합니다.
    private func refreshFileList() {
        guard let folderPath = currentFolderPath else {
            // No folder selected, reload test files
            videoFiles = VideoFile.allTestFiles
            return
        }

        let folderURL = URL(fileURLWithPath: folderPath)
        scanAndLoadFolder(folderURL)
    }
}

// MARK: - Helper Views

/// @struct InfoRow
/// @brief 정보 행 표시 컴포넌트
///
/// @details
/// 레이블과 값을 좌우로 표시하는 간단한 정보 행입니다.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .font(.caption)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.body)
        }
    }
}

// MARK: - GPS Map View

/// @struct GPSMapView
/// @brief GPS 경로 지도 표시 View
///
/// @details
/// NSViewRepresentable을 사용하여 MapKit의 MKMapView를 SwiftUI에 통합합니다.
/// GPS 포인트를 폴리라인으로 표시하고 시작/종료 지점에 마커를 추가합니다.
struct GPSMapView: NSViewRepresentable {
    let gpsPoints: [GPSPoint]

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays
        mapView.removeOverlays(mapView.overlays)

        guard !gpsPoints.isEmpty else { return }

        // Create coordinates array
        let coordinates = gpsPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        // Add polyline
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        mapView.delegate = context.coordinator

        // Set region to show all points
        if let firstPoint = coordinates.first {
            let region = MKCoordinateRegion(
                center: firstPoint,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: false)
        }

        // Add pins for start and end
        if let start = coordinates.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = start
            startAnnotation.title = "Start"
            mapView.addAnnotation(startAnnotation)
        }

        if let end = coordinates.last, coordinates.count > 1 {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = end
            endAnnotation.title = "End"
            mapView.addAnnotation(endAnnotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Acceleration Graph View

/// @struct AccelerationGraphView
/// @brief 가속도 센서 데이터 그래프 View
///
/// @details
/// 3축(X, Y, Z) 가속도 데이터를 실시간으로 그래프로 표시합니다.
/// Path를 사용한 커스텀 드로잉으로 구현되었습니다.
struct AccelerationGraphView: View {
    let accelerationData: [AccelerationData]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.opacity(0.3)

                // Grid lines
                gridLines(in: geometry.size)

                // Acceleration curves
                accelerationCurves(in: geometry.size)

                // Legend
                legend
                    .position(x: geometry.size.width - 60, y: 30)
            }
        }
    }

    private func gridLines(in size: CGSize) -> some View {
        Path { path in
            // Horizontal lines
            for i in 0...4 {
                let y = size.height * CGFloat(i) / 4
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            // Vertical lines
            for i in 0...4 {
                let x = size.width * CGFloat(i) / 4
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }

    private func accelerationCurves(in size: CGSize) -> some View {
        ZStack {
            // X axis (red)
            accelerationPath(for: \.x, in: size, color: .red)

            // Y axis (green)
            accelerationPath(for: \.y, in: size, color: .green)

            // Z axis (blue)
            accelerationPath(for: \.z, in: size, color: .blue)
        }
    }

    private func accelerationPath(for keyPath: KeyPath<AccelerationData, Double>, in size: CGSize, color: Color) -> some View {
        Path { path in
            guard !accelerationData.isEmpty else { return }

            let maxValue: Double = 2.0 // ±2G range
            let points = accelerationData.enumerated().map { index, data in
                let x = size.width * CGFloat(index) / CGFloat(max(1, accelerationData.count - 1))
                let value = data[keyPath: keyPath]
                let normalizedValue = (value + maxValue) / (2 * maxValue) // Normalize to 0-1
                let y = size.height * (1 - CGFloat(normalizedValue))
                return CGPoint(x: x, y: y)
            }

            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: 2)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("X")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Y")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("Z")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
