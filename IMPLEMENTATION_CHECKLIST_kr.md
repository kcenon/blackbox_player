# BlackboxPlayer - 구현 체크리스트

**최종 업데이트**: 2025-10-13
**목적**: TODO 항목 구현을 위한 단계별 실행 가능한 가이드
**대상 독자**: TODO 항목을 구현하는 개발자

---

## 📋 목차

1. [환경 설정](#1-환경-설정-체크리스트)
2. [시작하기 전에](#2-시작하기-전-체크리스트)
3. [Phase 1: 최우선 경로](#3-phase-1-최우선-경로)
4. [Phase 2: 핵심 기능](#4-phase-2-핵심-기능)
5. [Phase 3: 향상된 UX](#5-phase-3-향상된-ux)
6. [Phase 4: 마무리](#6-phase-4-마무리)
7. [테스트 및 검증](#7-테스트-및-검증-체크리스트)
8. [코드 품질](#8-코드-품질-체크리스트)

---

## 1. 환경 설정 체크리스트

### 사전 요구사항 확인

- [ ] **Xcode 버전 확인**
  ```bash
  xcodebuild -version
  # 필수: Xcode 15.4+ 또는 16.0+ (26.x beta 제외)
  ```
  **Xcode 26.x beta인 경우**: https://developer.apple.com/download/all/ 에서 안정 버전 다운로드

- [ ] **Homebrew 설치 확인**
  ```bash
  brew --version
  ```
  **없는 경우**: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

- [ ] **Swift 버전 확인**
  ```bash
  swift --version
  # 필수: Swift 5.9+
  ```

### 개발 도구 설치

- [ ] **FFmpeg 설치**
  ```bash
  brew install ffmpeg
  ffmpeg -version | head -1
  ```

- [ ] **빌드 도구 설치**
  ```bash
  brew install cmake git git-lfs xcodegen swiftlint
  ```

- [ ] **Metal Toolchain 설치**
  ```bash
  xcodebuild -downloadComponent MetalToolchain
  # 예상 다운로드 크기: ~700MB
  ```
  **검증**: 빌드 시 "cannot execute tool 'metal'" 오류가 더 이상 나타나지 않음

### 프로젝트 설정

- [ ] **Xcode에서 프로젝트 열기**
  ```bash
  cd /Users/dongcheolshin/Sources/blackbox_player
  open BlackboxPlayer.xcodeproj
  ```

- [ ] **코드 서명 구성**
  - BlackboxPlayer 타겟 선택
  - "Signing & Capabilities"로 이동
  - 개발 팀 선택
  - 번들 식별자 확인: `com.blackboxplayer.app`

- [ ] **프로젝트 빌드 성공**
  ```bash
  xcodebuild -project BlackboxPlayer.xcodeproj \
             -scheme BlackboxPlayer \
             -configuration Debug build
  ```
  **예상 결과**: 0개의 오류로 빌드 성공

---

## 2. 시작하기 전 체크리스트

### 코드베이스 이해하기

- [ ] **핵심 문서 읽기**
  - [ ] `docs/03_architecture.md` - MVVM 아키텍처 이해
  - [ ] `docs/02_technology_stack.md` - FFmpeg/Metal/SwiftUI 스택 검토
  - [ ] `docs/04_project_plan.md` - 부록 A (TODO 요약) 읽기

- [ ] **주요 파일 학습** (우선순위 순서)
  1. [ ] `BlackboxPlayer/App/BlackboxPlayerApp.swift` (433줄, 14개 TODO)
     - 앱 진입점
     - 메뉴 구조
     - 메뉴 액션을 위한 TODO 항목

  2. [ ] `BlackboxPlayer/Models/VideoFile.swift` (1911줄)
     - 핵심 데이터 모델
     - 다중 채널 구조
     - 테스트용 샘플 데이터

  3. [ ] `BlackboxPlayer/Services/VideoDecoder.swift` (1006줄)
     - FFmpeg 통합
     - H.264/MP3 디코딩

### 기존 테스트 실행하기

- [ ] **전체 테스트 스위트 실행**
  ```bash
  ./scripts/test.sh
  # 또는: xcodebuild test -scheme BlackboxPlayer
  ```
  **참고**: 일부 테스트는 미구현으로 실패할 수 있음 - 이는 예상된 동작

- [ ] **테스트 커버리지 검토**
  - [ ] GPSSensorIntegrationTests - GPS/G-sensor 파이프라인
  - [ ] SyncControllerTests - 다중 채널 동기화
  - [ ] VideoDecoderTests - FFmpeg 디코딩
  - [ ] DataModelsTests - 핵심 데이터 구조

---

## 3. Phase 1: 최우선 경로

**목표**: 기본 파일 로딩 및 재생 작동

#### TODO #1: 폴더 선택 대화상자 열기 🔴 P0
- [ ] **NSOpenPanel 구현**
  ```swift
  // 파일: BlackboxPlayer/App/BlackboxPlayerApp.swift:463
  func openFolderPicker() {
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.begin { response in
          if response == .OK, let url = panel.url {
              // url에서 파일 로드
          }
      }
  }
  ```

- [ ] **검증**
  - [ ] 대화상자가 올바르게 열리고 닫힘
  - [ ] 선택한 폴더가 파일 로딩 트리거
  - [ ] UI가 파일 목록으로 업데이트됨

#### TODO #7: 재생/일시정지 🔴 P0
- [ ] **재생 제어 구현**
  ```swift
  // 파일: BlackboxPlayer/App/BlackboxPlayerApp.swift:681
  func togglePlayPause() {
      // TODO: VideoPlayerService.togglePlayPause() 호출
  }
  ```
  - [ ] 기존 VideoDecoder에 연결
  - [ ] UI 상태 업데이트
  - [ ] 키보드 단축키 처리 (Space)

- [ ] **검증**
  - [ ] 비디오가 올바르게 재생 및 일시정지됨
  - [ ] 오디오가 동기화됨
  - [ ] 프레임 레이트 안정적 (최소 30fps)

#### TODO #2: 파일 목록 새로고침 🔴 P0
- [ ] **새로고침 구현**
  ```swift
  // 파일: BlackboxPlayer/App/BlackboxPlayerApp.swift:507
  func refreshFileList() {
      // TODO: FileSystemService.refreshFiles() 호출
  }
  ```

- [ ] **검증**
  - [ ] SD 카드에 추가된 새 파일 감지
  - [ ] 전체 재시작 없이 UI 업데이트
  - [ ] 사용자 선택 유지

---

## 4. Phase 2: 핵심 기능

**목표**: 메타데이터를 포함한 다중 채널 재생

### 메타데이터 파싱

#### TODO #27: 비디오 메타데이터 로드 🟠 P1
- [ ] 독점 메타데이터 포맷 파싱
- [ ] 채널 정보 추출
- [ ] 연관된 메타데이터 파일 로드 (.gps, .gsensor)
- [ ] **검증**: 메타데이터가 비디오와 정렬됨

#### TODO #25: GPS 메타데이터 파싱 🟠 P1
- [ ] **구현** (`MetadataExtractor.swift:359`)
  - [ ] GPS 바이너리 포맷 역공학
  - [ ] 위도, 경도, 고도, 속도 파싱
  - [ ] 타임스탬프 동기화 처리
- [ ] **검증**: GPS 포인트가 지도에 올바르게 렌더링됨

### 동기화

#### TODO #26: 비디오 타임스탬프 동기화 🟠 P1
- [ ] **구현** (`SyncController.swift:1459`)
  - [ ] 비디오 PTS를 GPS 타임스탬프와 정렬
  - [ ] 드리프트 보정 구현 (±50ms)
  - [ ] 다른 프레임 레이트 처리
- [ ] **검증**: 재생 중 메타데이터가 실시간으로 업데이트됨

#### TODO #8: 프레임 앞으로 이동 🟠 P1
- [ ] currentTime + (1/frameRate)로 탐색
- [ ] 모든 채널 동기적으로 업데이트
- [ ] **검증**: 프레임 단위 정확한 스테핑

#### TODO #9: 프레임 뒤로 이동 🟠 P1
- [ ] currentTime - (1/frameRate)로 탐색
- [ ] 파일 시작 경계 처리
- [ ] **검증**: 역방향 프레임 스테핑 작동

#### TODO #3: 사이드바 토글 🟠 P1
- [ ] NavigationSplitViewVisibility 토글 구현
- [ ] UserDefaults에 상태 저장
- [ ] **검증**: 사이드바가 올바르게 표시/숨김

---

## 5. Phase 3: 향상된 UX

**목표**: 오버레이 및 고급 제어

### 오버레이 구현

#### TODO #4: 메타데이터 오버레이 토글 🟠 P1
- [ ] MetadataOverlayView 생성
- [ ] 표시: 시간, GPS, 속도, G-센서
- [ ] 재생 중 실시간 업데이트
- [ ] **검증**: 오버레이가 비디오와 동기화됨

#### TODO #5: 지도 오버레이 토글 🟠 P1
- [ ] MapKit 통합
- [ ] 지도에 GPS 경로 그리기
- [ ] 현재 위치 강조
- [ ] **검증**: 재생 중 지도 업데이트

#### TODO #6: 그래프 오버레이 토글 🟠 P1
- [ ] Charts 프레임워크로 GSensorChartView 생성
- [ ] X/Y/Z 가속도 플롯
- [ ] 충격 이벤트 강조
- [ ] **검증**: 그래프가 비디오와 동기화됨

### 재생 제어

#### TODO #10: 속도 증가 🟡 P2
- [ ] 속도 증가 구현 (1x → 1.5x → 2x → 4x)
- [ ] UI 표시기 업데이트
- [ ] **검증**: 오디오 피치 유지

#### TODO #11: 속도 감소 🟡 P2
- [ ] 속도 감소 구현 (4x → 2x → 1.5x → 1x → 0.5x)
- [ ] 슬로우 모션 오디오 처리
- [ ] **검증**: 부드러운 속도 전환

#### TODO #12: 일반 속도 🟡 P2
- [ ] 1.0x 재생 속도로 재설정
- [ ] **검증**: 즉시 정상 속도로 복귀

#### TODO #42: 파일 목록 필터링 🟡 P2
- [ ] 필터 컨트롤 추가 (이벤트 유형, 날짜, 채널)
- [ ] 조건자 로직 구현
- [ ] **검증**: 필터가 올바르게 적용됨

#### TODO #43: 파일 행 액션 🟡 P2
- [ ] 컨텍스트 메뉴 추가 (내보내기, 삭제, 이름 변경)
- [ ] 액션 핸들러 구현
- [ ] **검증**: 선택한 파일에서 액션 작동

---

## 6. Phase 4: 마무리

**목표**: 완전한 애플리케이션

### 도움말 및 설정

#### TODO #13: About 윈도우 표시 🟢 P3
- [ ] 앱 정보가 포함된 AboutView 생성
- [ ] 버전, 저작권, 라이선스 포함
- [ ] **검증**: About 윈도우가 올바르게 표시됨

#### TODO #14: 도움말 표시 🟢 P3
- [ ] 사용자 가이드가 포함된 HelpView 생성
- [ ] 키보드 단축키 문서화
- [ ] **검증**: 도움말이 접근 가능하고 정확함

### 테스트 및 최적화

#### TODO #28-41: Metal 렌더러 테스트 🟡 P2
- [ ] 다중 텍스처 렌더링 테스트
- [ ] 레이아웃 전환 테스트
- [ ] 비디오 변환 테스트
- [ ] 성능 벤치마크 테스트
- [ ] 메모리 관리 테스트
- [ ] 스레드 안전성 테스트
- [ ] **검증**: 모든 테스트 통과, 커버리지 >80%

---

## 7. 테스트 및 검증 체크리스트

### 단위 테스팅

- [ ] **전체 테스트 스위트 실행**
  ```bash
  xcodebuild test -scheme BlackboxPlayer \
    -destination 'platform=macOS'
  ```

- [ ] **테스트 커버리지 분석**
  ```bash
  xcodebuild test -scheme BlackboxPlayer \
    -enableCodeCoverage YES
  ```
  **목표**: >80% 커버리지

- [ ] **특정 테스트 스위트**
  - [ ] DataModelsTests - 핵심 데이터 구조
  - [ ] VideoDecoderTests - FFmpeg 통합
  - [ ] SyncControllerTests - 다중 채널 동기화
  - [ ] GPSSensorIntegrationTests - 엔드투엔드 GPS/G-센서

### 통합 테스팅

- [ ] **다중 채널 재생**
  - [ ] 5개의 1080p 비디오 동시 재생
  - [ ] 모든 채널 동기화 (±50ms)
  - [ ] 10분 재생 중 프레임 드롭 없음

- [ ] **파일 작업**
  - [ ] 로컬 파일시스템에서 파일 로드 가능
  - [ ] 1000개 이상 비디오 파일 메타데이터 파싱 가능
  - [ ] 대용량 비디오 파일 처리 가능 (>2GB)

- [ ] **성능**
  - [ ] 재생 중 메모리 사용량 <2GB
  - [ ] Apple Silicon에서 CPU 사용량 <80%
  - [ ] GPU 사용량 <70%

### 수동 테스팅

- [ ] **정상 경로**
  - [ ] 폴더 선택 대화상자 열기 → 비디오 폴더 선택
  - [ ] 파일 목록 탐색 → 비디오 선택
  - [ ] 비디오 재생 → 모든 채널 표시
  - [ ] 오버레이 토글 → GPS/메타데이터 표시
  - [ ] MP4로 내보내기 → 파일 성공적으로 생성

- [ ] **오류 케이스**
  - [ ] 잘못된 폴더 경로 → 오류 메시지 표시
  - [ ] 손상된 비디오 파일 → 우아한 처리
  - [ ] 누락된 비디오 파일 → 깨끗한 오류 처리

- [ ] **엣지 케이스**
  - [ ] 매우 긴 비디오 (>2시간)
  - [ ] 고해상도 비디오 (4K)
  - [ ] 혼합 파일 형식의 폴더

---

## 8. 코드 품질 체크리스트

### 커밋 전

- [ ] **코드 포맷팅**
  ```bash
  swiftlint lint --fix
  swiftlint lint --strict
  ```
  **예상**: 0개의 경고

- [ ] **코드 리뷰 자가 점검**
  - [ ] 설명적인 함수/변수 이름
  - [ ] guard 문으로 조기 종료
  - [ ] do-catch로 오류 처리
  - [ ] 매직 넘버 없음 (명명된 상수 사용)
  - [ ] 주석은 "왜"를 설명, "무엇"이 아님

### 문서화

- [ ] **DocC 주석 추가**
  ```swift
  /// 바이너리 메타데이터 파일에서 GPS 포인트 로드
  ///
  /// - Parameter filePath: .gps 메타데이터 파일의 절대 경로
  /// - Returns: 타임스탬프가 포함된 파싱된 GPS 포인트 배열
  /// - Throws: 파일이 손상된 경우 `MetadataError.invalidFormat`
  func loadGPSPoints(from filePath: String) async throws -> [GPSPoint]
  ```

- [ ] **인라인 주석 업데이트**
  - [ ] 완료된 TODO를 구현 노트로 표시
  - [ ] 관련 있는 곳에 성능 노트 추가
  - [ ] 알려진 제한사항 문서화

### 커밋 메시지

- [ ] **Conventional Commits 사용**
  ```bash
  # 형식: type(scope): description

  # 예시:
  git commit -m "feat(decoder): add H.265 video codec support"
  git commit -m "fix(decoder): resolve memory leak in frame cleanup"
  git commit -m "test(gps): add integration tests for route sync"
  ```

- [ ] **유형**
  - `feat`: 새로운 기능
  - `fix`: 버그 수정
  - `docs`: 문서만
  - `test`: 테스트 추가/업데이트
  - `refactor`: 코드 재구조화
  - `perf`: 성능 개선
  - `chore`: 빌드/도구 변경

### Pull Request

- [ ] **PR 설명 템플릿**
  ```markdown
  ## 요약
  TODO #X 구현: [간단한 설명]

  ## 변경사항
  - [주요 변경사항 목록]

  ## 테스트
  - [테스트 방법]
  - [커버된 테스트 케이스]

  ## 스크린샷 (UI 변경인 경우)
  [변경 전/후 스크린샷 첨부]

  ## 성능 (해당되는 경우)
  - 메모리: [영향]
  - CPU: [영향]
  - FPS: [영향]

  Closes #X
  ```

- [ ] **리뷰 요청 전**
  - [ ] 모든 테스트 통과
  - [ ] SwiftLint 0개 경고
  - [ ] 문서 업데이트
  - [ ] 성능 벤치마크 실행 (해당되는 경우)

---

## 📊 진행 상황 추적

### 마일스톤

#### 마일스톤 1: MVP
- [ ] 로컬 파일시스템에서 파일 목록 로드
- [ ] 단일 채널 비디오 재생
- [ ] 기본 재생 제어 (재생, 일시정지, 탐색)

**완료 정의**: 로컬 폴더에서 단일 채널 비디오 재생 가능

#### 마일스톤 2: 다중 채널
- [ ] 여러 채널 동기화
- [ ] GPS 오버레이 작동
- [ ] 메타데이터 오버레이 작동
- [ ] G-센서 그래프 작동

**완료 정의**: 오버레이와 함께 5개 채널 재생 가능

#### 마일스톤 3: 기능 완료
- [ ] 모든 메뉴 액션 구현
- [ ] 내보내기 기능 작동
- [ ] 설정 관리 작동
- [ ] 테스트 커버리지 >80%

**완료 정의**: 59개 TODO 모두 완료, 베타 테스팅 준비 완료

---

## 🆘 문제 해결 가이드

### 일반적인 빌드 이슈

#### "Cannot find module 'FFmpeg'"
```bash
# 해결법: FFmpeg를 헤더 검색 경로에 추가
# project.yml에서:
HEADER_SEARCH_PATHS: /opt/homebrew/Cellar/ffmpeg/8.0_1/include
```

#### "Metal pipeline state creation failed"
```bash
# 해결법: 셰이더 구문 확인
# Xcode 빌드 로그에서 셰이더 컴파일 출력 확인
# MultiChannelShaders.metal에서 구문 오류 찾기
```

#### "The Xcode build system has crashed"
```bash
# 해결법: 안정 버전 Xcode로 다운그레이드
# Xcode 26.x beta는 실험적 기능에 알려진 이슈 있음
# developer.apple.com에서 Xcode 15.4 또는 16.0 다운로드
```

### 런타임 이슈

#### 시간 경과에 따라 메모리 사용량 증가
확인 사항:
- 해제되지 않은 비디오 프레임
- 닫히지 않은 파일 핸들
- 클로저에서 유지된 강한 참조

Instruments → Leaks 도구로 프로파일링.

---

## 📚 참고자료

### 기능별 주요 파일

| 기능 | 주요 파일 | 테스트 파일 |
|------|-----------|------------|
| 비디오 디코딩 | VideoDecoder.swift | VideoDecoderTests.swift |
| 다중 채널 동기화 | SyncController.swift | SyncControllerTests.swift |
| GPS 서비스 | GPSService.swift | GPSSensorIntegrationTests.swift |
| Metal 렌더링 | MultiChannelRenderer.swift | MultiChannelRendererTests.swift |
| 메뉴 액션 | BlackboxPlayerApp.swift | (UI Tests) |

### 외부 리소스

- **FFmpeg**: https://ffmpeg.org/documentation.html
- **Metal**: https://developer.apple.com/documentation/metal
- **SwiftUI**: https://developer.apple.com/documentation/swiftui

---

**최종 업데이트**: 2025-10-13
**다음 검토**: 각 마일스톤 완료 후
