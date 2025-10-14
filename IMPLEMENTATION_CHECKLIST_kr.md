# BlackboxPlayer - 구현 체크리스트

**최종 업데이트**: 2025-10-14
**목적**: TODO 항목 구현을 위한 단계별 실행 가능한 가이드
**대상 독자**: TODO 항목을 구현하는 개발자

---

## 📋 목차

1. [현재 구현 상태](#현재-구현-상태)
2. [환경 설정](#1-환경-설정-체크리스트)
3. [시작하기 전에](#2-시작하기-전-체크리스트)
4. [Phase 1: 파일 시스템 및 메타데이터](#3-phase-1-파일-시스템-및-메타데이터)
5. [Phase 2: 비디오 디코딩 및 재생](#4-phase-2-비디오-디코딩-및-재생)
6. [Phase 3: 다중 채널 동기화](#5-phase-3-다중-채널-동기화)
7. [Phase 4: GPS, G-센서 및 이미지 처리](#6-phase-4-gps-g-센서-및-이미지-처리)
8. [Phase 5: Metal 렌더링 및 UI](#7-phase-5-metal-렌더링-및-ui)
9. [테스트 및 검증](#8-테스트-및-검증-체크리스트)
10. [코드 품질](#9-코드-품질-체크리스트)

---

## 현재 구현 상태

**최종 업데이트**: 2025-10-14

### ✅ 완료된 단계 (Phase 1-4)

#### Phase 1: 파일 시스템 및 메타데이터 추출 ✅
**커밋**: f0981f7, 1fd70da, 60a418f

- [x] **FileScanner** (BlackboxPlayer/Services/FileScanner.swift)
  - 재귀 디렉토리 스캔
  - 비디오 파일 필터링 (.mp4, .avi, .mov 등)
  - 오류 처리 및 로깅

- [x] **FileSystemService** (BlackboxPlayer/Services/FileSystemService.swift)
  - 파일 메타데이터 추출 (크기, 날짜)
  - 디렉토리 작업
  - 파일 형식 감지

- [x] **VideoFileLoader** (BlackboxPlayer/Services/VideoFileLoader.swift)
  - VideoDecoder를 통한 비디오 파일 메타데이터 추출
  - DispatchQueue를 사용한 동시 로딩
  - 진행률 보고

- [x] **MetadataExtractor** (BlackboxPlayer/Services/MetadataExtractor.swift)
  - MP4 atom 구조에서 GPS 데이터 추출
  - 가속도 데이터 추출
  - 프레임별 메타데이터 파싱

#### Phase 2: 비디오 디코딩 및 재생 제어 ✅
**커밋**: 083ba4d

- [x] **VideoDecoder** (BlackboxPlayer/Services/VideoDecoder.swift, 1584줄)
  - 비디오 디코딩을 위한 FFmpeg 통합
  - 타임스탬프를 사용한 프레임별 디코딩
  - 탐색 기능 (키프레임 기반)
  - BGRA 픽셀 포맷 출력
  - 스레드 안전 작업

- [x] **MultiChannelSynchronizer** (BlackboxPlayer/Services/MultiChannelSynchronizer.swift)
  - 다중 채널 타임스탬프 동기화
  - 프레임 선택 전략 (nearest, before, after, exact)
  - 허용 오차 기반 동기화 제어 (기본값 33ms)

#### Phase 3: 다중 채널 동기화 ✅
**커밋**: 4712a30

- [x] **VideoBuffer** (BlackboxPlayer/Services/VideoBuffer.swift)
  - 스레드 안전 FIFO 순환 버퍼
  - 최대 30 프레임 버퍼링
  - 타임스탬프 기반 프레임 검색
  - 자동 오래된 프레임 정리

- [x] **MultiChannelSynchronizer** (향상)
  - Timer 기반 체크를 통한 드리프트 모니터링 (100ms 간격)
  - 자동 드리프트 보정 (50ms 임계값)
  - 드리프트 통계 및 이력 추적
  - 최소 탐색을 위한 중앙값 타임스탬프 전략

#### Phase 4: GPS 매핑, G-센서, 이미지 처리 ✅
**커밋**: 8b9232c

- [x] **GPSService** (BlackboxPlayer/Services/GPSService.swift, 1235줄)
  - GPS 데이터 로딩 및 파싱
  - 타임스탬프 기반 위치 쿼리
  - Haversine 거리 계산
  - 속도/방향 계산

- [x] **GSensorService** (BlackboxPlayer/Services/GSensorService.swift, 1744줄)
  - 가속도 데이터 처리
  - 충격 이벤트 감지 (임계값 기반)
  - 타임스탬프 동기화
  - 필터링 및 정규화

- [x] **FrameCaptureService** (BlackboxPlayer/Services/FrameCaptureService.swift, 415줄)
  - 비디오 프레임을 이미지 파일로 캡처 (PNG/JPEG)
  - 메타데이터 오버레이 지원 (타임스탬프, GPS 정보)
  - 다중 채널 합성 캡처 (그리드/수평 레이아웃)
  - VideoFrame → CGImage → NSImage 변환

- [x] **VideoTransformations** (BlackboxPlayer/Services/VideoTransformations.swift, 1085줄)
  - 비디오 변환 매개변수 관리
  - 밝기/대비, 반전, 디지털 줌
  - UserDefaults 지속성
  - SwiftUI 통합 (@Published)

### ⏳ 대기 중인 단계 (Phase 5)

#### Phase 5: Metal 렌더링 및 UI ⏳
**상태**: 시작 안 됨 (Xcode 빌드 환경 필요)

구현할 컴포넌트:
- [ ] MetalRenderer (GPU 가속 비디오 렌더링)
- [ ] MapViewController (MapKit 통합)
- [ ] UI 계층 (SwiftUI/AppKit 뷰)

### Git 커밋 히스토리
```
8b9232c - feat(Phase4): implement FrameCaptureService for screenshot and image processing
4712a30 - feat(Phase3): implement drift monitoring and VideoBuffer for multi-channel synchronization
083ba4d - feat(VideoDecoder, MultiChannelSynchronizer): implement frame navigation and multi-channel synchronization for Phase 2
60a418f - feat(MetadataExtractor): implement GPS and acceleration data extraction
1fd70da - feat(VideoFileLoader): integrate VideoDecoder for real video metadata extraction
f0981f7 - refactor(FileScanner): integrate FileSystemService for file operations
```

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

## 3. Phase 1: 파일 시스템 및 메타데이터

**상태**: ✅ 완료
**목표**: 파일 시스템 액세스 및 메타데이터 파싱 구현
**커밋**: f0981f7, 1fd70da, 60a418f

### 완료된 컴포넌트

#### ✅ FileScanner (BlackboxPlayer/Services/FileScanner.swift)
- [x] 재귀 디렉토리 스캔
- [x] 비디오 파일 필터링 (.mp4, .avi, .mov 등)
- [x] 오류 처리 및 로깅
- [x] 파일 형식 감지

#### ✅ FileSystemService (BlackboxPlayer/Services/FileSystemService.swift)
- [x] 파일 메타데이터 추출 (크기, 생성일, 수정일)
- [x] 디렉토리 작업
- [x] 파일 형식 감지
- [x] 경로 유효성 검사

#### ✅ VideoFileLoader (BlackboxPlayer/Services/VideoFileLoader.swift)
- [x] VideoDecoder를 통한 비디오 파일 메타데이터 추출
- [x] DispatchQueue를 사용한 동시 로딩
- [x] 진행률 보고
- [x] 손상된 파일에 대한 오류 처리

#### ✅ MetadataExtractor (BlackboxPlayer/Services/MetadataExtractor.swift)
- [x] MP4 atom 구조에서 GPS 데이터 추출
- [x] 가속도 데이터 추출
- [x] 프레임별 메타데이터 파싱
- [x] 타임스탬프 동기화

---

## 4. Phase 2: 비디오 디코딩 및 재생

**상태**: ✅ 완료
**목표**: 비디오 디코딩 및 프레임별 재생 제어 구현
**커밋**: 083ba4d

### 완료된 컴포넌트

#### ✅ VideoDecoder (BlackboxPlayer/Services/VideoDecoder.swift, 1584줄)
- [x] 비디오 디코딩을 위한 FFmpeg 통합
- [x] H.264/MP3 코덱 지원
- [x] 타임스탬프를 사용한 프레임별 디코딩
- [x] 탐색 기능 (키프레임 기반)
- [x] Metal 렌더링을 위한 BGRA 픽셀 포맷 출력
- [x] NSLock을 사용한 스레드 안전 작업
- [x] 메모리 관리 및 정리

#### ✅ MultiChannelSynchronizer (BlackboxPlayer/Services/MultiChannelSynchronizer.swift)
- [x] 다중 채널 타임스탬프 동기화
- [x] 프레임 선택 전략 (nearest, before, after, exact)
- [x] 허용 오차 기반 동기화 제어 (기본값 33ms)
- [x] 여러 채널에 걸친 프레임 정렬
- [x] 누락된 프레임에 대한 오류 처리

---

## 5. Phase 3: 다중 채널 동기화

**상태**: ✅ 완료
**목표**: 5개 채널에서 프레임 단위 완벽 동기화 달성
**커밋**: 4712a30

### 완료된 컴포넌트

#### ✅ VideoBuffer (BlackboxPlayer/Services/VideoBuffer.swift, 신규)
- [x] 스레드 안전 FIFO 순환 버퍼 구현
- [x] 최대 30 프레임 버퍼링 용량
- [x] 타임스탬프 기반 프레임 검색
- [x] 자동 오래된 프레임 정리
- [x] 메모리 효율적인 프레임 관리

#### ✅ MultiChannelSynchronizer (향상)
- [x] Timer 기반 체크를 통한 드리프트 모니터링 (100ms 간격)
- [x] 자동 드리프트 보정 (50ms 임계값)
- [x] 드리프트 통계 및 이력 추적
- [x] 최소 탐색 작업을 위한 중앙값 타임스탬프 전략
- [x] 허용 오차 제어를 통한 다중 채널 프레임 정렬

### 검증 결과
- [x] ±50ms 정확도로 5개 채널 동기화
- [x] 드리프트 모니터링으로 비동기화 방지
- [x] 자동 보정으로 긴 재생 중 동기화 유지
- [x] 실시간 재생을 위한 성능 최적화

---

## 6. Phase 4: GPS, G-센서 및 이미지 처리

**상태**: ✅ 완료
**목표**: GPS 매핑, G-센서 시각화 및 이미지 처리 구현
**커밋**: 8b9232c

### 완료된 컴포넌트

#### ✅ GPSService (BlackboxPlayer/Services/GPSService.swift, 1235줄)
- [x] 메타데이터에서 GPS 데이터 로딩 및 파싱
- [x] 이진 검색을 사용한 타임스탬프 기반 위치 쿼리
- [x] Haversine 거리 계산
- [x] 속도 및 방향 계산
- [x] GPS 경로 보간
- [x] 좌표계 변환

#### ✅ GSensorService (BlackboxPlayer/Services/GSensorService.swift, 1744줄)
- [x] 가속도 데이터 처리
- [x] 충격 이벤트 감지 (임계값 기반)
- [x] 비디오와 타임스탬프 동기화
- [x] 데이터 필터링 및 정규화
- [x] X/Y/Z 축 가속도 추적
- [x] 이벤트 심각도 분류

#### ✅ FrameCaptureService (BlackboxPlayer/Services/FrameCaptureService.swift, 415줄)
- [x] 비디오 프레임을 이미지 파일로 캡처 (PNG/JPEG)
- [x] 메타데이터 오버레이 지원 (타임스탬프, GPS 정보)
- [x] 다중 채널 합성 캡처
- [x] 그리드 및 수평 레이아웃 지원
- [x] VideoFrame → CGImage → NSImage 변환
- [x] 파일 경로 유효성 검사 및 오류 처리

#### ✅ VideoTransformations (BlackboxPlayer/Services/VideoTransformations.swift, 1085줄)
- [x] 비디오 변환 매개변수 관리
- [x] 밝기 및 대비 조정
- [x] 수평 및 수직 반전
- [x] 팬 지원을 통한 디지털 줌
- [x] UserDefaults 지속성
- [x] @Published 속성을 통한 SwiftUI 통합

### 검증 결과
- [x] 비디오 재생과 동기화된 GPS 데이터
- [x] G-센서 이벤트 감지 및 강조 표시
- [x] 모든 채널에서 작동하는 스크린샷 캡처
- [x] 실시간으로 적용되는 비디오 변환
- [x] 모든 서비스 스레드 안전 및 성능 최적화

---

## 7. Phase 5: Metal 렌더링 및 UI

**상태**: ⏳ 대기 중
**목표**: Metal GPU 렌더링 및 완전한 UI 레이어 구현
**우선순위**: 높음 (Xcode 빌드 환경 필요)

### 대기 중인 컴포넌트

#### ⏳ MetalRenderer (시작 안 됨)
- [ ] GPU 가속 비디오 렌더링 파이프라인
- [ ] 5개 채널을 위한 다중 텍스처 렌더링
- [ ] 변환을 위한 셰이더 프로그램
- [ ] 실시간 밝기/대비/줌
- [ ] 30fps 이상을 위한 성능 최적화

#### ⏳ MapViewController (시작 안 됨)
- [ ] GPS 경로 표시를 위한 MapKit 통합
- [ ] 실시간 위치 마커
- [ ] 경로 폴리라인 렌더링
- [ ] 사용자 상호작용 (줌, 팬)
- [ ] 비디오 재생과 동기화

#### ⏳ UI 레이어 (시작 안 됨)
- [ ] 모든 기능을 위한 SwiftUI 뷰
- [ ] 복잡한 컨트롤을 위한 AppKit 통합
- [ ] 메뉴 액션 구현
- [ ] 키보드 단축키
- [ ] 설정 관리 UI

### 의존성
- Xcode 프로젝트 구성
- Metal 프레임워크 설정
- MapKit 권한
- SwiftUI 레이아웃 디버깅

---

## 8. 테스트 및 검증 체크리스트

### 단위 테스팅

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

## 9. 코드 품질 체크리스트

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

**최종 업데이트**: 2025-10-14
**다음 검토**: Phase 5 (Metal 렌더링 및 UI) 완료 후
