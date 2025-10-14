# 프로젝트 개발 계획

> 🌐 **Language**: [English](04_project_plan.md) | [한국어](#)

## 타임라인 개요

```
단계 0: 준비               [■■░░░░░░░░░░░░░░] 1주
단계 1: 파일 시스템        [░░■■■░░░░░░░░░░░] 2-3주
단계 2: 단일 재생          [░░░░░■■■░░░░░░░░] 2-3주
단계 3: 다채널 동기화      [░░░░░░░░■■■░░░░░] 2-3주
단계 4: 추가 기능          [░░░░░░░░░░░■■░░░] 2주
단계 5: 내보내기/설정      [░░░░░░░░░░░░░■■░] 2주
단계 6: 현지화 및 마무리   [░░░░░░░░░░░░░░░■] 1-2주

총 예상 기간: 12-16주 (3-4개월)
```

## 단계 0: 준비 (1주)

### 목표
- 개발 환경 설정
- 기술적 실현 가능성 검증
- 프로젝트 인프라 구축

### 작업

#### 1. 환경 설정
- [ ] Mac App Store에서 Xcode 15+ 설치
- [ ] Homebrew 패키지 관리자 설치
- [ ] 개발 도구 설치:
  ```bash
  brew install ffmpeg cmake git git-lfs
  brew install swiftlint # 코드 품질 도구
  ```
- [ ] Apple Developer 계정 생성 (없는 경우)
- [ ] 코드 서명 인증서 구성

#### 2. 프로젝트 초기화
- [ ] 새 Xcode 프로젝트 생성
  - 템플릿: macOS App
  - 인터페이스: SwiftUI
  - 언어: Swift
  - 최소 배포 대상: macOS 12.0
- [ ] 프로젝트 구조 설정:
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
- [ ] Git 저장소 초기화
- [ ] Xcode 프로젝트용 `.gitignore` 생성
- [ ] CI/CD 파이프라인 설정 (GitHub Actions)

#### 3. 라이브러리 통합
- [ ] FFmpeg 통합:
  - FFmpeg 라이브러리 링크
  - Swift 래퍼 생성
  - 영상 디코딩 테스트
- [ ] Swift Package Manager 의존성 설정

#### 4. 샘플 데이터 수집
- [ ] 블랙박스에서 샘플 SD 카드 획득
- [ ] 파일 구조 문서화:
  ```
  /DCIM/
  ├── Normal/
  │   ├── 2024-01-15_08-30-00_F.h264
  │   ├── 2024-01-15_08-30-00_R.h264
  │   └── ...
  ├── Event/
  └── Parking/
  ```
- [ ] 메타데이터 포맷 분석
- [ ] GPS 및 G-센서 데이터 샘플 추출
- [ ] 영상 사양 문서화 (해상도, 코덱, 비트레이트)

#### 5. 개념 증명
- [ ] 최소한의 파일 시스템 액세스 데모 생성
- [ ] 최소한의 FFmpeg 디코딩 데모 생성
- [ ] 하드웨어 성능 검증 (5개 스트림 디코딩)

### 산출물
- ✅ 기본 구조를 갖춘 작동하는 Xcode 프로젝트
- ✅ 파일 시스템 액세스 작동
- ✅ FFmpeg 디코딩 작동
- ✅ 샘플 데이터 문서화
- ✅ 기술적 실현 가능성 확인

### 성공 기준
- SD 카드에서 파일 읽기 가능
- FFmpeg으로 H.264 영상 디코딩 가능
- SwiftUI에서 단일 영상 프레임 표시 가능
- 프로젝트가 오류 없이 빌드됨

---

## 단계 1: 파일 시스템 및 데이터 계층 (2-3주)

### 목표
- 파일 시스템 액세스 구현
- 블랙박스 메타데이터 파싱
- 파일 관리 기반 구축

### 작업

#### 1주차: 파일 시스템 통합

**1. 파일 시스템 서비스 구현**
```swift
// Swift 인터페이스
class FileSystemService {
    func listVideoFiles(at url: URL) throws -> [URL]
    func readFile(at url: URL) throws -> Data
    func getFileInfo(at url: URL) throws -> FileInfo
    func detectSDCards() -> [URL]
}
```

- [ ] FileManager 기반 파일 액세스 구현
- [ ] IOKit을 사용한 USB 장치 감지
- [ ] 오류 처리 추가
- [ ] 파일 열거 구현
- [ ] 파일 읽기 구현
- [ ] 파일 정보 조회 구현
- [ ] 단위 테스트 추가

**2. 장치 감지**
- [ ] 마운트된 볼륨 감지
- [ ] 블랙박스 SD 카드 식별
- [ ] 여러 SD 카드 처리
- [ ] 장치 선택 UI 추가

#### 2주차: 메타데이터 파싱

**1. 메타데이터 파서**
```swift
class MetadataParser {
    func parseGPS(from data: Data) -> [GPSPoint]
    func parseGSensor(from data: Data) -> [AccelerationData]
    func parseFileMetadata(from data: Data) -> VideoMetadata
}
```

- [ ] 메타데이터 포맷 리버스 엔지니어링
- [ ] GPS 데이터 파서 구현
- [ ] G-센서 데이터 파서 구현
- [ ] 타임스탬프 정보 파싱
- [ ] 채널 정보 파싱
- [ ] 검증 로직 추가

**2. 데이터 모델**
- [ ] `VideoFile` 모델 정의
- [ ] `GPSPoint` 모델 정의
- [ ] `AccelerationData` 모델 정의
- [ ] `VideoMetadata` 모델 정의
- [ ] Codable 준수 추가
- [ ] 테스트 픽스처 생성

#### 3주차: 파일 관리자 서비스

**1. 파일 관리자 구현**
```swift
class FileManagerService {
    func loadFiles() async throws -> [VideoFile]
    func getFiles(type: EventType) async throws -> [VideoFile]
    func searchFiles(query: String) async throws -> [VideoFile]
    func deleteFiles(_ files: [VideoFile]) async throws
}
```

- [ ] 파일 스캔 구현
- [ ] 이벤트 유형별로 파일 그룹화 (일반/충격/주차)
- [ ] 캐싱 메커니즘 구현
- [ ] 파일 필터링 추가
- [ ] 검색 기능 추가
- [ ] 손상된 파일을 우아하게 처리

**2. 기본 UI**
- [ ] FileListView 생성
- [ ] 파일 정보 표시
- [ ] 이벤트 유형 배지 표시
- [ ] 선택 메커니즘 구현

### 산출물
- ✅ 파일 시스템 완전 액세스 가능
- ✅ UI에 파일 목록 표시
- ✅ 메타데이터 파싱 작동
- ✅ 이벤트 유형 분류 구현

### 성공 기준
- SD 카드에서 모든 파일 나열 가능
- 영상 파일 데이터 읽기 가능
- GPS 및 G-센서 메타데이터 파싱 가능
- 이벤트 유형과 함께 파일 목록 올바르게 표시
- 파일 작업에서 메모리 누수 없음

### 테스트
```bash
# 단위 테스트
./run_tests.sh FileManagerServiceTests

# 통합 테스트
./run_tests.sh FileSystemIntegrationTests
```

---

## 단계 2: 단일 채널 영상 재생 (2-3주)

### 목표
- 영상 디코딩 구현
- 영상 플레이어 UI 생성
- 재생 제어 추가

### 작업

#### 1주차: 영상 디코더

**1. FFmpeg 통합**
```swift
class VideoDecoder {
    func open(url: URL) throws
    func decodeNextFrame() async throws -> VideoFrame?
    func seek(to time: CMTime) throws
    func close()
}
```

- [ ] H.264 디코딩 구현
- [ ] MP3 음성 디코딩 구현
- [ ] 다양한 해상도 처리
- [ ] 프레임 버퍼링 구현
- [ ] 오류 복구 추가
- [ ] 성능 최적화

**2. 음성/영상 동기화**
- [ ] 클록 동기화 구현
- [ ] A/V 드리프트 처리
- [ ] 버퍼 관리

#### 2주차: Metal 렌더러

**1. Metal 설정**
```swift
class MetalVideoRenderer: NSObject, MTKViewDelegate {
    func render(frame: VideoFrame, to view: MTKView)
}
```

- [ ] Metal 장치 및 커맨드 큐 생성
- [ ] 렌더 파이프라인 설정
- [ ] CVPixelBuffer에서 텍스처 생성
- [ ] 버텍스 및 프래그먼트 셰이더 구현
- [ ] 윈도우 크기 조정 처리
- [ ] 60fps 최적화

**2. 영상 플레이어 뷰**
- [ ] SwiftUI에서 MTKView 래퍼 생성
- [ ] 영상 프레임 표시
- [ ] 종횡비 처리
- [ ] 로딩 인디케이터 추가

#### 3주차: 재생 제어

**1. 플레이어 제어 UI**
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

- [ ] 재생/일시정지 버튼
- [ ] 정지 버튼
- [ ] 이전/다음 파일 버튼
- [ ] 타임라인 스크러버
- [ ] 현재 시간 표시
- [ ] 속도 제어 (0.5x, 1x, 2x)
- [ ] 볼륨 제어

**2. 키보드 단축키**
- [ ] Space: 재생/일시정지
- [ ] 좌/우: ±5초 탐색
- [ ] 위/아래: 볼륨
- [ ] F: 전체 화면
- [ ] ESC: 전체 화면 종료

**3. 플레이어 뷰 모델**
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

### 산출물
- ✅ 단일 영상 부드럽게 재생
- ✅ 재생 제어 작동
- ✅ 음성/영상 동기화
- ✅ 부드러운 탐색

### 성공 기준
- 영상이 최소 30fps로 재생
- 음성/영상 동기화 ±50ms 이내
- 탐색이 500ms 이내에 응답
- 단일 HD 영상에 대한 메모리 사용량 < 500MB
- 정상 재생 중 프레임 드롭 없음

### 테스트
- [ ] 다양한 영상 해상도 테스트 (720p, 1080p, 4K)
- [ ] 다양한 프레임 레이트 테스트 (25fps, 30fps, 60fps)
- [ ] 긴 영상 테스트 (>1시간)
- [ ] 손상된 영상 파일 테스트
- [ ] CPU/GPU 사용률 측정

---

## 단계 3: 다채널 동기화 (2-3주)

### 목표
- 5개 채널 동시 재생
- 동기화 유지
- 성능 최적화

### 작업

#### 1주차: 다채널 아키텍처

**1. 채널 관리**
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

- [ ] VideoChannel 추상화 생성
- [ ] 독립적인 디코더 구현 (5개 인스턴스)
- [ ] 각 채널에 대한 프레임 버퍼 생성
- [ ] 백그라운드 디코딩 스레드 설정

**2. 동기화 컨트롤러**
```swift
class SyncController {
    func syncPlay()
    func syncPause()
    func syncSeek(to time: CMTime)
    func monitorSync() // 드리프트 확인 및 수정
}
```

- [ ] 마스터 클록 구현
- [ ] 모든 채널을 마스터 클록에 동기화
- [ ] 동기화 드리프트 모니터링
- [ ] 드리프트 > 50ms 시 자동 수정
- [ ] 다른 프레임 레이트의 채널 처리

#### 2주차: 다중 텍스처 렌더링

**1. Metal 다중 텍스처 렌더러**
```swift
class MultiChannelRenderer {
    func render(channels: [VideoFrame], to view: MTKView) {
        // 모든 채널을 단일 렌더 패스로 렌더링
    }
}
```

- [ ] 단일 패스로 5개 텍스처 렌더링
- [ ] 그리드 레이아웃 구현 (2x2 + 1)
- [ ] 다양한 레이아웃 지원:
  - 그리드: 2x3
  - 포커스: 1개 크게 + 4개 작게
  - 수평: 1x5
- [ ] 누락된 채널 우아하게 처리

**2. 레이아웃 관리자**
```swift
enum ChannelLayout {
    case grid2x3           // 그리드 2x3
    case focusPlusSmall    // 포커스 + 작은 화면
    case horizontal        // 수평
}

class LayoutManager {
    func calculateFrames(for layout: ChannelLayout, in bounds: CGRect) -> [CGRect]
}
```

- [ ] 레이아웃 구성 정의
- [ ] 채널 위치 계산
- [ ] 윈도우 크기 조정 처리
- [ ] 레이아웃 전환 UI 추가

#### 3주차: 성능 최적화

**1. 메모리 최적화**
- [ ] 프레임 버퍼 제한 구현 (채널당 30 프레임)
- [ ] 오래된 프레임 즉시 해제
- [ ] 타이트 루프에 대한 autoreleasepool 사용
- [ ] 메모리 사용량 모니터링
- [ ] 메모리 경고 추가

**2. 스레딩 최적화**
```swift
// 각 채널을 별도 스레드에서 디코딩
let decodeQueues = (0..<5).map {
    DispatchQueue(label: "decoder.\($0)", qos: .userInitiated)
}

// 메인 스레드에서 렌더링
DispatchQueue.main.async {
    renderer.render(frames: frames)
}
```

- [ ] 스레드 수 최적화
- [ ] Grand Central Dispatch 효과적으로 사용
- [ ] 메인 스레드 차단 방지
- [ ] Instruments로 프로파일링

**3. GPU 최적화**
- [ ] 공유 Metal 리소스 사용
- [ ] 텍스처 업로드 최소화
- [ ] 드로우 콜 배치
- [ ] Metal 디버거로 프로파일링

### 산출물
- ✅ 5개 채널 동시 재생
- ✅ 모든 채널 동기화
- ✅ 부드러운 성능
- ✅ 여러 레이아웃 옵션

### 성공 기준
- 모든 5개 채널이 최소 30fps로 재생
- 동기화 드리프트 < ±50ms
- 메모리 사용량 < 2GB
- Apple Silicon에서 CPU 사용량 < 80%
- GPU 사용량 < 70%
- 정상 재생 중 프레임 드롭 없음

### 테스트
- [ ] 5x 1080p 영상으로 테스트
- [ ] 장기간 재생 테스트 (2시간 이상)
- [ ] 동기화 정확도 테스트
- [ ] 성능 메트릭 측정
- [ ] 다양한 Mac 모델에서 테스트 (Intel vs Apple Silicon)

---

## 단계 4: 추가 기능 (2주)

### 목표
- GPS 매핑 구현
- G-센서 시각화 추가
- 이미지 처리 기능

### 작업

#### 1주차: GPS 및 G-센서

**1. GPS 통합**
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

- [ ] GPS 데이터 파싱 구현
- [ ] MapKit (또는 Google Maps) 통합
- [ ] 지도에 주행 경로 그리기
- [ ] 영상 재생 시 위치 업데이트
- [ ] 지도 제어 추가 (줌, 패닝)
- [ ] 속도, 고도 정보 표시

**2. G-센서 시각화**
```swift
class GSensorChartView: NSView {
    var data: [AccelerationData]

    func drawChart() {
        // X/Y/Z 축 그리기
        // 충격 이벤트 강조
    }
}
```

- [ ] G-센서 데이터 파싱
- [ ] Core Graphics로 차트 뷰 생성
- [ ] X/Y/Z 가속도 표시
- [ ] 충격 이벤트 강조 (크기 > 임계값)
- [ ] 영상 재생과 동기화
- [ ] 차트에 대한 줌/패닝 추가

#### 2주차: 이미지 처리

**1. 화면 캡처**
```swift
func captureCurrentFrame() -> NSImage {
    // 현재 영상 프레임 캡처
    // PNG/JPEG로 저장
}
```

- [ ] 프레임 캡처 구현
- [ ] 사용자 선택 위치에 저장
- [ ] PNG 및 JPEG 포맷 지원
- [ ] 타임스탬프 오버레이 포함 (선택사항)

**2. 영상 변환**
```swift
class VideoTransformations {
    var brightness: Float = 1.0
    var horizontalFlip: Bool = false
    var verticalFlip: Bool = false
    var zoom: Float = 1.0
}
```

- [ ] 밝기 조정 구현 (Metal 셰이더)
- [ ] 수평 반전 구현
- [ ] 수직 반전 구현
- [ ] 디지털 줌 구현
- [ ] 변환을 위한 Metal 셰이더 업데이트

**3. 전체 화면 모드**
- [ ] 전체 화면 진입/종료
- [ ] 전체 화면에서 제어 숨기기/표시
- [ ] 여러 디스플레이 지원

### 산출물
- ✅ 지도에 GPS 경로 표시
- ✅ G-센서 데이터 시각화
- ✅ 이미지 캡처 작동
- ✅ 영상 변환 구현

### 성공 기준
- GPS 위치가 실시간으로 업데이트
- G-센서 차트가 부드럽게 렌더링
- 이미지 캡처가 전체 해상도로 저장
- 영상 변환이 성능에 영향 없음
- 전체 화면 모드가 올바르게 작동

---

## 단계 5: 내보내기 및 설정 (2주)

### 목표
- MP4 내보내기 기능
- 설정 관리
- 영상 복구

### 작업

#### 1주차: MP4 내보내기

**1. 내보내기 서비스**
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

- [ ] FFmpeg 먹싱 구현
- [ ] H.264 + MP3 → MP4 결합
- [ ] 채널 선택 지원
- [ ] 메타데이터 포함 (GPS, G-센서)
- [ ] 진행률 표시줄 표시
- [ ] 취소 처리
- [ ] 배치 내보내기 지원

**2. 영상 복구**
```swift
func repairVideo(_ file: VideoFile) async throws -> URL {
    // 파일 손상 분석
    // 유효한 프레임 복구
    // 복구된 MP4 생성
}
```

- [ ] 손상된 파일 감지
- [ ] 읽을 수 있는 프레임 복구
- [ ] 손상된 섹션 건너뛰기
- [ ] 재생 가능한 MP4 생성

**3. 채널 추출**
```swift
func extractChannel(_ file: VideoFile, channel: Int) async throws -> URL {
    // 다채널 파일에서 단일 채널 추출
}
```

- [ ] 특정 채널 추출
- [ ] 가능한 경우 음성 유지
- [ ] 영상 품질 유지

#### 2주차: 설정 관리

**1. 설정 서비스**
```swift
class SettingsService {
    func loadSettings(from sdCard: URL) async throws -> DashcamSettings
    func saveSettings(_ settings: DashcamSettings, to sdCard: URL) async throws
}
```

- [ ] 설정 파일 포맷 파싱
- [ ] SD 카드에서 설정 로드
- [ ] 설정 값 검증
- [ ] SD 카드에 설정 저장

**2. 설정 UI**
```swift
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("영상") {
                Picker("해상도", selection: $viewModel.resolution) { ... }
                Picker("녹화 모드", selection: $viewModel.mode) { ... }
            }

            Section("기능") {
                Toggle("주차 모드", isOn: $viewModel.parkingMode)
                Slider("충격 감도", value: $viewModel.sensitivity, in: 1...10)
            }
        }
    }
}
```

- [ ] 설정 양식 생성
- [ ] 카테고리별로 설정 그룹화
- [ ] 검증 추가
- [ ] 툴팁/도움말 텍스트 표시
- [ ] 저장/취소 버튼 구현
- [ ] 저장되지 않은 변경사항에 대한 경고

### 산출물
- ✅ MP4 내보내기 작동
- ✅ 영상 복구 기능
- ✅ 설정 로드 및 저장 가능
- ✅ 설정 UI 완료

### 성공 기준
- 5채널 영상을 MP4로 내보내기 가능
- 내보내기가 품질 유지
- 복구가 최대한의 프레임 복구
- 설정이 SD 카드에 올바르게 저장
- 설정 UI가 직관적

---

## 단계 6: 현지화 및 마무리 (1-2주)

### 목표
- 다국어 지원
- UI/UX 마무리
- 앱 패키징

### 작업

#### 1주차: 현지화

**1. 문자열 추출**
- [ ] 모든 UI 문자열 추출
- [ ] Localizable.strings 파일 생성:
  ```
  Resources/
  ├── en.lproj/
  │   └── Localizable.strings
  ├── ko.lproj/
  │   └── Localizable.strings
  └── ja.lproj/
      └── Localizable.strings
  ```

**2. 번역**
```swift
// NSLocalizedString 사용
Text(NSLocalizedString("play_button", comment: "재생 버튼"))
```

- [ ] 한국어 번역
- [ ] 영어 번역
- [ ] 일본어 번역 (선택사항)
- [ ] 언어 전환 테스트

**3. 현지화된 에셋**
- [ ] 현지화된 이미지 (있는 경우)
- [ ] 현지화된 도움말 텍스트
- [ ] 현지화된 오류 메시지

#### 2주차: 마무리 및 패키징

**1. UI 마무리**
- [ ] 다크 모드 지원
- [ ] 앱 아이콘 디자인
- [ ] 애니메이션 개선
- [ ] 오류 메시지 개선
- [ ] 로딩 상태 추가
- [ ] 전환 마무리

**2. 성능 튜닝**
- [ ] Instruments로 프로파일링
- [ ] 메모리 누수 수정
- [ ] 시작 시간 최적화
- [ ] CPU 사용량 감소
- [ ] 배터리 소모 감소

**3. 접근성**
- [ ] VoiceOver 레이블 추가
- [ ] 키보드 탐색 지원
- [ ] 색상 대비 확인
- [ ] 텍스트 크기 조정 지원

**4. 문서화**
- [ ] 사용자 매뉴얼
- [ ] 설치 가이드
- [ ] 문제 해결 가이드
- [ ] 개발자 문서
- [ ] API 문서

**5. 코드 서명 및 공증**
```bash
# 앱 서명
codesign --deep --force --verify --verbose \
         --sign "Developer ID Application: Your Name" \
         --options runtime \
         BlackboxPlayer.app

# DMG 생성
create-dmg BlackboxPlayer.app

# 공증
xcrun notarytool submit BlackboxPlayer.dmg \
         --apple-id "your@email.com" \
         --team-id "TEAM_ID" \
         --password "app-specific-password"

# 스테이플
xcrun stapler staple BlackboxPlayer.app
```

- [ ] 코드 서명 구성
- [ ] 공증 제출
- [ ] 공증된 앱 테스트
- [ ] DMG 설치 프로그램 생성

**6. 최종 테스트**
- [ ] macOS 12, 13, 14에서 테스트
- [ ] Intel 및 Apple Silicon에서 테스트
- [ ] 다양한 SD 카드로 테스트
- [ ] 모든 기능 테스트
- [ ] 중요한 버그 수정

### 산출물
- ✅ 앱이 한국어, 영어, 일본어 지원
- ✅ 다크 모드 구현
- ✅ 앱 서명 및 공증
- ✅ DMG 설치 프로그램 생성
- ✅ 문서화 완료

### 성공 기준
- 모든 UI 텍스트가 올바르게 현지화됨
- 다크 모드가 보기 좋음
- 앱이 공증 통과
- DMG가 원활하게 설치됨
- 중요한 버그가 남아있지 않음

---

## 리소스 요구사항

### 팀 구성

**필수:**
- 1x macOS 개발자 (Swift/SwiftUI, AVFoundation)
- 1x 영상 처리 엔지니어 (FFmpeg, 코덱)

**선택:**
- 1x UI/UX 디자이너
- 1x QA 엔지니어

### 하드웨어

**개발:**
- MacBook Pro M1/M2/M3 (16GB+ RAM)
- 외부 디스플레이 (멀티 스크린 테스트용)
- USB-C 카드 리더
- 샘플 SD 카드 (32GB, 64GB, 128GB)
- 테스트용 블랙박스 장치

**테스트:**
- Intel Mac (호환성 테스트용)
- 구형 MacBook (성능 테스트용)

### 소프트웨어

**필수:**
- Xcode 15+ ($0)
- Apple Developer Program (연 $99)
- FFmpeg (오픈 소스)

**선택:**
- Google Maps API (사용량에 따라 월 $0 - $200)
- Figma/Sketch (UI 디자인)
- Notion/Jira (프로젝트 관리)

---

## 리스크 관리

| 리스크 | 확률 | 영향 | 완화 |
|------|------|------|------|
| 5채널 성능 문제 | 중간 | 중간 | Metal 최적화; 품질 설정 제공 |
| 공증 거부 | 낮음 | 높음 | Apple 가이드라인 엄격히 준수; 조기 테스트 |
| GPS/G-센서 포맷 미상 | 중간 | 중간 | Windows 뷰어에서 리버스 엔지니어링 |
| 일정 지연 | 중간 | 중간 | 단계별 배포; 핵심 기능 우선순위 |
| 메모리 누수 | 낮음 | 중간 | Instruments로 정기 프로파일링 |
| 블랙박스 펌웨어 변형 | 높음 | 중간 | 여러 펌웨어 버전 지원; 버전 감지 |

---

## 품질 보증

### 테스트 전략

**단위 테스트 (80% 커버리지):**
```bash
xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'
```

**통합 테스트:**
- 실제 SD 카드에서 파일 읽기
- 샘플 영상으로 다채널 재생
- 다양한 영상 조합으로 내보내기

**성능 테스트:**
- 재생 FPS 측정
- 시간 경과에 따른 메모리 사용량 측정
- 내보내기 속도 측정

**UI 테스트:**
```swift
func testPlaybackControls() {
    let app = XCUIApplication()
    app.launch()

    app.buttons["재생"].tap()
    XCTAssertTrue(app.buttons["일시정지"].exists)

    app.sliders["타임라인"].adjust(toNormalizedSliderPosition: 0.5)
    // ...
}
```

### 지속적 통합

**GitHub Actions 워크플로:**
```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: 빌드 및 테스트
        run: |
          xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'
      - name: SwiftLint 실행
        run: swiftlint lint --strict
```

---

## 마일스톤 및 산출물

### 마일스톤 1: MVP (단계 3 종료)
- ✅ SD 카드 마운트 가능
- ✅ 영상 나열 및 재생 가능
- ✅ 다채널 동기화 재생
- ✅ 기본 재생 제어

### 마일스톤 2: 기능 완료 (단계 5 종료)
- ✅ 모든 요구사항 구현
- ✅ GPS 매핑 작동
- ✅ MP4 내보내기 기능
- ✅ 설정 관리 완료

### 마일스톤 3: 프로덕션 준비 (단계 6 종료)
- ✅ 현지화
- ✅ UI 마무리
- ✅ 서명 및 공증
- ✅ 문서화 완료
- ✅ 배포 준비 완료

---

## 출시 후 계획

### 버전 1.1 (출시 후 2-3개월)
- 사용자 피드백의 버그 수정
- 성능 개선
- 추가 언어 지원

### 버전 2.0 (출시 후 6개월)
- iOS 컴패니언 앱
- 클라우드 동기화 (iCloud)
- 블랙박스에서 실시간 스트리밍
- AI 기반 이벤트 감지
- 고급 편집 기능

---

## 성공 메트릭

### 성능 메트릭
- 앱 시작 시간 < 2초
- 영상 로드 시간 < 1초
- 5채널 재생 30fps 이상
- 메모리 사용량 < 2GB
- 내보내기 속도 > 1x 실시간

### 품질 메트릭
- 충돌률 < 0.1%
- 테스트 커버리지 > 80%
- 코드 리뷰 승인 필요
- 중요한 보안 문제 0건

### 사용자 메트릭 (출시 후)
- 활성 사용자
- 세션 지속 시간
- 기능 사용
- App Store 평점
- 지원 티켓

---

## 부록 A: 현재 구현 상태

**최종 갱신**: 2025-10-13
**상태**: 활발한 개발 진행 중
**전체 TODO 항목**: 59개

### 카테고리별 TODO 요약

| 카테고리 | 개수 | 우선순위 | 예상 작업 기간 | 주요 파일 |
|----------|------|----------|---------------|-----------|
| **UI/메뉴 액션** | 14 | 🔴 높음 | 5-7일 | BlackboxPlayerApp.swift |
| **파일 시스템 통합** | 8 | 🔴 높음 | 7-10일 | FileSystemService.swift |
| **영상 재생** | 8 | 🟠 중간 | 7-10일 | VideoDecoder.swift, SyncController.swift |
| **테스트** | 14 | 🟡 낮음 | 3-5일 | MultiChannelRendererTests.swift |
| **UI 컴포넌트** | 13 | 🟠 중간 | 5-7일 | FileListView.swift, FileRow.swift |

**총 예상 작업 기간**: 30-44일 (6-9주)

### 최우선 항목 (P0 우선순위)

다음 항목들은 다른 기능들을 블로킹하므로 최우선으로 완료해야 합니다:

1. **TODO #1** (BlackboxPlayerApp.swift:463): 폴더 선택 대화상자 - 메인 UI 진입점
2. **TODO #2** (FileSystemService.swift): SD 카드 볼륨 감지 - 파일 탐색에 필수
3. **TODO #3** (FileSystemService.swift): 비디오 파일 목록 조회 - 파일 탐색에 필수
4. **TODO #4** (FileSystemService.swift): 파일 읽기 - 영상 재생에 필수
5. **TODO #7** (BlackboxPlayerApp.swift:681): 재생/일시정지 - 핵심 재생 제어
6. **TODO #8** (VideoDecoder.swift): 영상 디코딩 - 재생에 필수

### 구현 로드맵 (8주)

#### Phase 1: 최우선 경로 (1-2주차)
- SD 카드 볼륨 감지 (#2)
- 디렉토리 목록 (#3)
- 폴더 선택 대화상자 (#1)
- 파일 읽기 (#4)
- 재생/일시정지 (#7)

#### Phase 2: 핵심 기능 (3-4주차)
- 파일 정보 조회 (#17)
- 영상 메타데이터 로드 (#27)
- GPS 메타데이터 파싱 (#25)
- 영상 타임스탬프 동기화 (#26)
- 프레임 앞/뒤로 이동 (#8, #9)

#### Phase 3: 향상된 UX (5-6주차)
- 메타데이터 오버레이 토글 (#4)
- 지도 오버레이 토글 (#5)
- 그래프 오버레이 토글 (#6)
- 재생 속도 제어 (#10, #11, #12)

#### Phase 4: 마무리 (7-8주차)
- About/Help 윈도우 (#13, #14)
- 테스트 스위트 완료 (#28-41)
- 버그 수정 및 최적화

### 주요 의존성

```
SD 카드 감지 (#2)
  ├─→ 디렉토리 목록 (#3)
  ├─→ 파일 읽기 (#4)
  └─→ 파일 정보 조회 (#5)
      ├─→ 메타데이터 로드 (#6)
      │   ├─→ GPS 파싱 (#7)
      │   └─→ 타임스탬프 동기화 (#8)
      │       ├─→ 재생/일시정지 (#9)
      │       └─→ 오버레이 토글 (#10, #11, #12)
      └─→ 폴더 열기 (#1)
          └─→ 파일 목록 새로고침 (#13)
```

### 리스크 평가

| 리스크 | 영향 | 완화 방안 |
|--------|------|----------|
| FFmpeg 호환성 문제 | 🟠 높음 | 샘플 파일로 광범위한 코덱 테스트 |
| Intel Mac에서 Metal 성능 문제 | 🟡 중간 | 셰이더 최적화, 품질 설정 제공 |
| GPS 메타데이터 포맷 미상 | 🟠 높음 | 샘플 데이터에서 리버스 엔지니어링 |
| SD 카드 호환성 문제 | 🟡 중간 | 다양한 SD 카드로 테스트, FAT32/exFAT 지원 |

### 진행 상황 추적

**완료**: 0/59 (0%)
**진행 중**: 0/59 (0%)
**미시작**: 59/59 (100%)

#### 마일스톤 1: MVP (1-4주차)
- [ ] SD 카드 볼륨 감지 작동
- [ ] SD 카드에서 파일 목록 로드
- [ ] 단일 채널 영상 재생
- [ ] 기본 재생 제어

#### 마일스톤 2: 다채널 (5-6주차)
- [ ] 여러 채널 동기화
- [ ] GPS 오버레이 작동
- [ ] 메타데이터 오버레이 작동
- [ ] G-센서 그래프 작동

#### 마일스톤 3: 기능 완료 (7-8주차)
- [ ] 모든 메뉴 액션 구현
- [ ] 내보내기 기능 작동
- [ ] 설정 관리 작동
- [ ] 테스트 커버리지 >80%

---

**참고**: 각 TODO 항목에 대한 상세한 구현 가이드(구체적인 코드 예시 및 라인 번호 포함)는 위에 나열된 소스 파일의 인라인 주석을 참조하세요.
