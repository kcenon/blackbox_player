//
//  VideoFile.swift
//  BlackboxPlayer
//
//  Model for dashcam video file (potentially multi-channel)
//

import Foundation

/*
 ═══════════════════════════════════════════════════════════════════════════════
 VideoFile - 블랙박스 비디오 파일 모델
 ═══════════════════════════════════════════════════════════════════════════════

 【개요】
 VideoFile은 블랙박스 녹화 파일의 완전한 정보를 나타내는 최상위 모델입니다.
 여러 카메라 채널, GPS/G-센서 메타데이터, 이벤트 타입, 사용자 설정 등 모든 정보를
 하나의 구조체로 통합 관리합니다.

 【VideoFile이란?】

 하나의 녹화 시간에 기록된 모든 채널의 비디오 파일과 메타데이터의 집합입니다.

 구조 예시 (2채널 블랙박스, 2025년 1월 10일 09:00:00 녹화):

   VideoFile (2025_01_10_09_00_00)
   ├─ 📹 채널 1: 전방 카메라
   │   └─ 파일: 2025_01_10_09_00_00_F.mp4 (Full HD, 100 MB)
   │
   ├─ 📹 채널 2: 후방 카메라
   │   └─ 파일: 2025_01_10_09_00_00_R.mp4 (HD, 50 MB)
   │
   ├─ 📍 GPS 메타데이터
   │   └─ 3,600개 GPS 포인트 (1초마다)
   │
   ├─ 📊 G-센서 메타데이터
   │   └─ 36,000개 가속도 데이터 (0.1초마다)
   │
   └─ 📝 추가 정보
       ├─ 이벤트 타입: 일반 녹화
       ├─ 녹화 시간: 2025-01-10 09:00:00
       ├─ 길이: 1분
       ├─ 즐겨찾기: false
       ├─ 메모: nil
       └─ 손상 여부: false

 【모델 통합】

 VideoFile은 다른 모든 모델을 조합합니다:

   VideoFile
   ├─ EventType enum         (이벤트 종류)
   ├─ [ChannelInfo]          (채널 배열)
   │   └─ CameraPosition enum (카메라 위치)
   │
   └─ VideoMetadata          (메타데이터)
       ├─ [GPSPoint]         (GPS 배열)
       └─ [AccelerationData] (가속도 배열)

 【불변 구조체(Immutable Struct)】

 VideoFile은 struct로 선언되어 불변(immutable) 데이터 구조입니다.

 불변의 장점:
   1. 스레드 안전 (Thread-safe)
      - 여러 스레드에서 동시에 읽어도 안전
      - 동기화(lock) 불필요

   2. 예측 가능성 (Predictability)
      - 생성 후 값이 변하지 않음
      - 부작용(side effect) 없음

   3. 값 복사 (Value semantics)
      - 할당 시 복사본 생성
      - 원본 영향 없음

 불변 업데이트 패턴:
   ```swift
   // 기존 파일
   let originalFile = VideoFile(...)

   // 새로운 인스턴스 생성 (기존 파일은 변경 안 됨)
   let updatedFile = originalFile.withFavorite(true)

   // originalFile: isFavorite = false (변경 안 됨)
   // updatedFile: isFavorite = true   (새 인스턴스)
   ```

 이 패턴은 SwiftUI와 함께 사용할 때 특히 유용합니다:
   - @State, @Binding과 자연스럽게 동작
   - 뷰 업데이트 자동 트리거
   - Undo/Redo 구현 용이

 【멀티 채널 시스템】

 하나의 VideoFile은 1~5개의 채널을 포함할 수 있습니다:

   1채널 (기본):
   ┌─────────────┐
   │   전방 (F)   │
   └─────────────┘

   2채널 (일반적):
   ┌─────────────┬─────────────┐
   │   전방 (F)   │   후방 (R)   │
   └─────────────┴─────────────┘

   4채널 (고급):
   ┌──────┬──────┬──────┬──────┐
   │ 전방  │ 후방  │ 좌측  │ 우측  │
   │  (F) │  (R) │  (L) │ (Ri) │
   └──────┴──────┴──────┴──────┘

   5채널 (최고급):
   ┌──────┬──────┬──────┬──────┬──────┐
   │ 전방  │ 후방  │ 좌측  │ 우측  │ 실내  │
   │  (F) │  (R) │  (L) │ (Ri) │  (I) │
   └──────┴──────┴──────┴──────┴──────┘

 모든 채널은 동일한 timestamp에 녹화되지만 독립적인 파일입니다.

 【파일 시스템 구조】

 블랙박스 SD 카드 디렉토리 구조:

   /media/sd/
   ├─ normal/                    (일반 녹화)
   │   ├─ 2025_01_10_09_00_00_F.mp4
   │   ├─ 2025_01_10_09_00_00_R.mp4
   │   ├─ 2025_01_10_09_01_00_F.mp4
   │   └─ 2025_01_10_09_01_00_R.mp4
   │
   ├─ event/                     (충격 이벤트)
   │   ├─ 2025_01_10_10_30_15_F.mp4
   │   └─ 2025_01_10_10_30_15_R.mp4
   │
   ├─ parking/                   (주차 모드)
   │   └─ 2025_01_10_18_00_00_F.mp4
   │
   └─ manual/                    (수동 녹화)
       ├─ 2025_01_10_15_00_00_F.mp4
       └─ 2025_01_10_15_00_00_R.mp4

 basePath:
   - "normal/2025_01_10_09_00_00" (채널 접미사 제외)
   - 모든 채널에 공통된 경로 부분

 【사용 예시】

 ```swift
 // 2채널 블랙박스 파일 생성
 let videoFile = VideoFile(
     timestamp: Date(),
     eventType: .normal,
     duration: 60.0,
     channels: [frontChannel, rearChannel],
     metadata: metadata,
     basePath: "normal/2025_01_10_09_00_00"
 )

 // 채널 접근
 if let frontChannel = videoFile.frontChannel {
     print("전방 카메라: \(frontChannel.resolutionName)")
 }

 // 메타데이터 확인
 if videoFile.hasImpactEvents {
     print("⚠️ 충격 이벤트 \(videoFile.impactEventCount)회")
 }

 // 파일 정보
 print("총 크기: \(videoFile.totalFileSizeString)")
 print("길이: \(videoFile.durationString)")
 print("시간: \(videoFile.timestampString)")

 // 즐겨찾기 추가 (불변 업데이트)
 let favoriteFile = videoFile.withFavorite(true)
 ```

 ═══════════════════════════════════════════════════════════════════════════════
 */

/// Dashcam video file with metadata and channel information
///
/// 블랙박스 비디오 파일의 완전한 정보를 나타내는 구조체입니다.
///
/// **포함 정보:**
/// - 채널 정보 (1~5개 카메라)
/// - 메타데이터 (GPS, G-센서)
/// - 이벤트 타입 (일반, 충격, 주차 등)
/// - 사용자 설정 (즐겨찾기, 메모)
/// - 파일 상태 (손상 여부)
///
/// **프로토콜:**
/// - Codable: JSON 직렬화/역직렬화
/// - Equatable: 동등성 비교
/// - Identifiable: SwiftUI List/ForEach에서 고유 식별
/// - Hashable: Set/Dictionary 키로 사용 가능
///
/// **불변 구조:**
/// - struct로 선언되어 값 타입 (value type)
/// - 프로퍼티는 모두 let (상수)
/// - 변경은 새 인스턴스 생성 (withX 메서드)
///
/// **사용 예시:**
/// ```swift
/// let videoFile = VideoFile(
///     timestamp: Date(),
///     eventType: .normal,
///     duration: 60.0,
///     channels: [frontChannel, rearChannel],
///     metadata: metadata,
///     basePath: "normal/2025_01_10_09_00_00"
/// )
///
/// // 채널 확인
/// print("채널 수: \(videoFile.channelCount)")
/// print("전방 카메라: \(videoFile.hasChannel(.front) ? "있음" : "없음")")
///
/// // 메타데이터 확인
/// if videoFile.hasImpactEvents {
///     print("⚠️ 충격 \(videoFile.impactEventCount)회")
/// }
///
/// // 즐겨찾기 추가 (불변 업데이트)
/// let favoriteFile = videoFile.withFavorite(true)
/// ```
struct VideoFile: Codable, Equatable, Identifiable, Hashable {
    /// Unique identifier
    ///
    /// 파일의 고유 식별자입니다.
    ///
    /// **UUID (Universally Unique Identifier):**
    /// - 128비트 고유 식별자
    /// - SwiftUI List/ForEach에서 각 파일 구별
    /// - 충돌 확률: 거의 0 (10^-18 수준)
    ///
    /// **사용 예시:**
    /// ```swift
    /// List(videoFiles) { file in
    ///     // file.id로 각 파일 구별
    ///     VideoFileRow(file: file)
    /// }
    /// ```
    let id: UUID

    /// Recording start timestamp
    ///
    /// 녹화 시작 시간입니다.
    ///
    /// **Date 타입:**
    /// - Swift의 표준 날짜/시간 타입
    /// - UTC 기반 절대 시간 (타임존 독립적)
    /// - TimeInterval 연산 가능 (초 단위)
    ///
    /// **타임스탬프 활용:**
    /// - 파일 정렬 (시간순 정렬)
    /// - 파일 검색 (날짜/시간 필터)
    /// - UI 표시 (DateFormatter)
    ///
    /// **파일명 규칙:**
    /// - 파일명에 포함: YYYY_MM_DD_HH_MM_SS
    /// - 예: 2025_01_10_09_00_00 → 2025년 1월 10일 09:00:00
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 시간 비교
    /// let recentFiles = videoFiles.filter { file in
    ///     file.timestamp > Date().addingTimeInterval(-3600) // 1시간 이내
    /// }
    ///
    /// // 시간순 정렬
    /// let sortedFiles = videoFiles.sorted { $0.timestamp < $1.timestamp }
    ///
    /// // 날짜 표시
    /// print(videoFile.timestampString)  // "2025. 1. 10. 오전 9:00"
    /// ```
    let timestamp: Date

    /// Event type (normal, impact, parking, etc.)
    ///
    /// 이벤트 종류입니다.
    ///
    /// **EventType enum:**
    /// - normal: 일반 녹화 (우선순위 1)
    /// - impact: 충격 이벤트 (우선순위 4)
    /// - parking: 주차 모드 (우선순위 2)
    /// - manual: 수동 녹화 (우선순위 3)
    /// - emergency: 비상 녹화 (우선순위 5)
    /// - unknown: 알 수 없음 (우선순위 0)
    ///
    /// **자동 분류:**
    /// - 파일 경로로 자동 감지
    /// - "event/" 폴더 → .impact
    /// - "parking/" 폴더 → .parking
    /// - "manual/" 폴더 → .manual
    ///
    /// **활용:**
    /// - 파일 분류 및 그룹화
    /// - 색상 코딩 (빨강: 충격, 초록: 일반)
    /// - 우선순위 정렬
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 충격 이벤트 필터링
    /// let impactFiles = videoFiles.filter { $0.eventType == .impact }
    ///
    /// // 우선순위 정렬 (높은 것부터)
    /// let sortedFiles = videoFiles.sorted { $0.eventType > $1.eventType }
    ///
    /// // 색상 표시
    /// let badgeColor = videoFile.eventType.colorHex  // "#F44336" (빨강)
    /// ```
    let eventType: EventType

    /// Video duration in seconds
    ///
    /// 비디오 길이입니다. (단위: 초)
    ///
    /// **TimeInterval 타입:**
    /// - Double의 typealias
    /// - 소수점 포함 가능 (예: 59.5초)
    ///
    /// **일반적인 녹화 길이:**
    /// - 1분: 60.0초 (가장 일반적)
    /// - 3분: 180.0초
    /// - 5분: 300.0초
    /// - 충격 이벤트: 30.0초 (전후 포함)
    /// - 주차 모드: 10.0초 (움직임 감지 시)
    ///
    /// **모든 채널 동일:**
    /// - 모든 채널의 duration은 동일
    /// - 동시에 녹화 시작/종료
    ///
    /// **포맷팅:**
    /// - durationString: "1:00" (1분), "1:30" (1분 30초), "1:05:30" (1시간 5분 30초)
    ///
    /// **사용 예시:**
    /// ```swift
    /// print("길이: \(videoFile.durationString)")  // "1:00"
    ///
    /// // 긴 영상 필터링
    /// let longVideos = videoFiles.filter { $0.duration > 180.0 } // 3분 이상
    ///
    /// // 재생 진행률 계산
    /// let progress = currentTime / videoFile.duration  // 0.0 ~ 1.0
    /// ```
    let duration: TimeInterval

    /// All video channels (front, rear, left, right, interior)
    ///
    /// 모든 비디오 채널 배열입니다.
    ///
    /// **ChannelInfo 배열:**
    /// - 1~5개 채널 포함
    /// - 각 채널은 독립적인 비디오 파일
    /// - 동일한 timestamp, duration
    ///
    /// **채널 수에 따른 분류:**
    /// - 1채널: 전방만 (기본)
    /// - 2채널: 전방 + 후방 (일반적)
    /// - 3채널: 전방 + 후방 + 실내
    /// - 4채널: 전방 + 후방 + 좌측 + 우측
    /// - 5채널: 전방 + 후방 + 좌측 + 우측 + 실내
    ///
    /// **배열 순서:**
    /// - 순서는 중요하지 않음
    /// - 일반적으로 displayPriority 순서 (front, rear, left, right, interior)
    ///
    /// **활용:**
    /// - 멀티 뷰 재생 (화면 분할)
    /// - 채널별 재생/숨김 제어
    /// - 총 파일 크기 계산
    ///
    /// **사용 예시:**
    /// ```swift
    /// print("채널 수: \(videoFile.channels.count)")
    ///
    /// // 모든 채널 정보 출력
    /// for channel in videoFile.channels {
    ///     print("\(channel.position.displayName): \(channel.resolutionName)")
    /// }
    ///
    /// // 특정 채널 찾기
    /// if let frontChannel = videoFile.frontChannel {
    ///     print("전방: \(frontChannel.fileSizeString)")
    /// }
    /// ```
    let channels: [ChannelInfo]

    /// Associated metadata (GPS, G-Sensor)
    ///
    /// GPS 및 G-센서 메타데이터입니다.
    ///
    /// **VideoMetadata 구조:**
    /// - gpsPoints: [GPSPoint] (GPS 시계열)
    /// - accelerationData: [AccelerationData] (센서 시계열)
    /// - deviceInfo: DeviceInfo? (장치 정보)
    ///
    /// **메타데이터 크기:**
    /// - GPS: 1시간당 약 3,600개 포인트 (1Hz)
    /// - G-센서: 1시간당 약 36,000개 포인트 (10Hz)
    /// - 메모리: 1시간당 약 2.5 MB
    ///
    /// **빈 메타데이터:**
    /// - GPS/센서 없는 블랙박스
    /// - 구형 모델
    /// - metadata = VideoMetadata() (빈 구조체)
    ///
    /// **활용:**
    /// - 지도에 주행 경로 표시
    /// - 속도 그래프 표시
    /// - 충격 이벤트 타임라인 표시
    ///
    /// **사용 예시:**
    /// ```swift
    /// // GPS 데이터 확인
    /// if videoFile.hasGPSData {
    ///     let summary = videoFile.metadata.summary
    ///     print("주행 거리: \(summary.distanceString)")
    ///     print("평균 속도: \(summary.averageSpeedString ?? "N/A")")
    /// }
    ///
    /// // 충격 이벤트 확인
    /// if videoFile.hasImpactEvents {
    ///     for event in videoFile.metadata.impactEvents {
    ///         print("충격: \(event.magnitude)G at \(event.timestamp)")
    ///     }
    /// }
    /// ```
    let metadata: VideoMetadata

    /// Base file path (without channel suffix)
    ///
    /// 기본 파일 경로입니다. (채널 접미사 제외)
    ///
    /// **basePath 구조:**
    /// - "폴더/YYYY_MM_DD_HH_MM_SS"
    /// - 채널별 파일은 _F, _R, _L, _Ri, _I 접미사 추가
    ///
    /// **예시:**
    /// ```
    /// basePath: "normal/2025_01_10_09_00_00"
    ///
    /// 실제 파일:
    ///   normal/2025_01_10_09_00_00_F.mp4   (전방)
    ///   normal/2025_01_10_09_00_00_R.mp4   (후방)
    ///   normal/2025_01_10_09_00_00_L.mp4   (좌측)
    ///   normal/2025_01_10_09_00_00_Ri.mp4  (우측)
    ///   normal/2025_01_10_09_00_00_I.mp4   (실내)
    /// ```
    ///
    /// **폴더 구조:**
    /// - "normal/": 일반 녹화
    /// - "event/": 충격 이벤트
    /// - "parking/": 주차 모드
    /// - "manual/": 수동 녹화
    /// - "emergency/": 비상 녹화
    ///
    /// **활용:**
    /// - 파일 경로 생성
    /// - 폴더별 분류
    /// - 파일 삭제 (모든 채널 동시 삭제)
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 기본 파일명 추출
    /// print(videoFile.baseFilename)  // "2025_01_10_09_00_00"
    ///
    /// // 전체 경로 생성
    /// let frontPath = "\(videoFile.basePath)_F.mp4"
    /// let rearPath = "\(videoFile.basePath)_R.mp4"
    /// ```
    let basePath: String

    /// Whether this file is marked as favorite
    ///
    /// 즐겨찾기 표시 여부입니다.
    ///
    /// **즐겨찾기 기능:**
    /// - 사용자가 중요한 영상 표시
    /// - 자동 삭제에서 보호
    /// - 빠른 접근 (즐겨찾기 탭)
    ///
    /// **활용 시나리오:**
    /// - 아름다운 풍경
    /// - 재미있는 순간
    /// - 사고 영상 (증거)
    /// - 특별한 순간 (여행, 이벤트)
    ///
    /// **불변 업데이트:**
    /// ```swift
    /// // 즐겨찾기 추가
    /// let favoriteFile = videoFile.withFavorite(true)
    ///
    /// // 즐겨찾기 제거
    /// let unfavoriteFile = favoriteFile.withFavorite(false)
    /// ```
    ///
    /// **UI 표시:**
    /// - 별 아이콘 (★ vs ☆)
    /// - 노란색 강조
    /// - 즐겨찾기 배지
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 즐겨찾기 필터링
    /// let favorites = videoFiles.filter { $0.isFavorite }
    ///
    /// // 즐겨찾기 토글
    /// let updatedFile = videoFile.withFavorite(!videoFile.isFavorite)
    ///
    /// // UI 표시
    /// favoriteButton.setImage(
    ///     UIImage(systemName: videoFile.isFavorite ? "star.fill" : "star"),
    ///     for: .normal
    /// )
    /// ```
    let isFavorite: Bool

    /// User-added notes/comments
    ///
    /// 사용자가 추가한 메모/코멘트입니다.
    ///
    /// **옵셔널 String:**
    /// - 메모가 없으면 nil
    /// - 빈 문자열("")과 nil은 다름
    /// - nil: 메모 입력 안 함
    /// - "": 메모 입력했지만 비어있음
    ///
    /// **활용 시나리오:**
    /// - 영상 설명 ("아름다운 석양")
    /// - 위치 정보 ("서울 명동")
    /// - 사건 기록 ("급브레이크 차량")
    /// - 개인 메모 ("나중에 편집")
    ///
    /// **최대 길이:**
    /// - 제한 없음 (UI에서 제한 가능)
    /// - 일반적으로 200~500자
    ///
    /// **불변 업데이트:**
    /// ```swift
    /// // 메모 추가
    /// let notedFile = videoFile.withNotes("Beautiful sunset drive")
    ///
    /// // 메모 제거
    /// let clearedFile = notedFile.withNotes(nil)
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 메모 표시
    /// if let notes = videoFile.notes, !notes.isEmpty {
    ///     notesLabel.text = notes
    ///     notesLabel.isHidden = false
    /// } else {
    ///     notesLabel.isHidden = true
    /// }
    ///
    /// // 메모 검색
    /// let searchResults = videoFiles.filter { file in
    ///     file.notes?.localizedCaseInsensitiveContains("sunset") ?? false
    /// }
    /// ```
    let notes: String?

    /// File is corrupted or damaged
    ///
    /// 파일이 손상되었는지 여부입니다.
    ///
    /// **손상 원인:**
    /// - SD 카드 불량 섹터
    /// - 갑작스러운 전원 차단 (녹화 중)
    /// - 파일 시스템 손상
    /// - 코덱 오류
    ///
    /// **손상 증상:**
    /// - 재생 불가
    /// - 메타데이터 파싱 실패
    /// - 파일 크기 0
    /// - duration = 0
    ///
    /// **손상 파일 처리:**
    /// - 재생 시도 안 함 (에러 방지)
    /// - UI에 경고 표시
    /// - 복구 시도 또는 삭제 권장
    ///
    /// **isPlayable vs isCorrupted:**
    /// - isPlayable = isValid && !isCorrupted
    /// - 둘 다 체크해야 안전한 재생
    ///
    /// **사용 예시:**
    /// ```swift
    /// if videoFile.isCorrupted {
    ///     // 손상 파일 표시
    ///     thumbnailView.alpha = 0.5
    ///     warningLabel.text = "⚠️ 손상된 파일"
    ///     warningLabel.isHidden = false
    ///     playButton.isEnabled = false
    /// } else if videoFile.isPlayable {
    ///     // 정상 재생 가능
    ///     playButton.isEnabled = true
    /// }
    ///
    /// // 손상 파일 필터링
    /// let healthyFiles = videoFiles.filter { !$0.isCorrupted }
    /// ```
    let isCorrupted: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: Date,
        eventType: EventType,
        duration: TimeInterval,
        channels: [ChannelInfo],
        metadata: VideoMetadata = VideoMetadata(),
        basePath: String,
        isFavorite: Bool = false,
        notes: String? = nil,
        isCorrupted: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.duration = duration
        self.channels = channels
        self.metadata = metadata
        self.basePath = basePath
        self.isFavorite = isFavorite
        self.notes = notes
        self.isCorrupted = isCorrupted
    }

    // MARK: - Channel Access

    /// Get channel by position
    /// - Parameter position: Camera position
    /// - Returns: Channel info or nil
    ///
    /// 특정 위치의 채널을 찾습니다.
    ///
    /// **검색 알고리즘:**
    /// - first(where:) 사용
    /// - 배열을 순회하며 첫 번째 일치 항목 반환
    /// - 시간 복잡도: O(n), n = channels.count (보통 1~5)
    ///
    /// **옵셔널 반환:**
    /// - 채널이 있으면 ChannelInfo 반환
    /// - 채널이 없으면 nil 반환
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 전방 카메라 찾기
    /// if let frontChannel = videoFile.channel(for: .front) {
    ///     print("전방: \(frontChannel.resolutionName)")
    /// } else {
    ///     print("전방 카메라 없음")
    /// }
    ///
    /// // 모든 채널 확인
    /// for position in CameraPosition.allCases {
    ///     if let channel = videoFile.channel(for: position) {
    ///         print("\(position.displayName): \(channel.fileSizeString)")
    ///     }
    /// }
    /// ```
    func channel(for position: CameraPosition) -> ChannelInfo? {
        return channels.first { $0.position == position }
    }

    /// Front camera channel
    ///
    /// 전방 카메라 채널입니다.
    ///
    /// **편의 프로퍼티:**
    /// - channel(for: .front)의 축약형
    /// - 가장 자주 사용되는 채널 (전방)
    ///
    /// **사용 예시:**
    /// ```swift
    /// if let front = videoFile.frontChannel {
    ///     print("전방 해상도: \(front.resolutionName)")
    ///     playerView.loadVideo(from: front.filePath)
    /// }
    /// ```
    var frontChannel: ChannelInfo? {
        return channel(for: .front)
    }

    /// Rear camera channel
    ///
    /// 후방 카메라 채널입니다.
    ///
    /// **편의 프로퍼티:**
    /// - channel(for: .rear)의 축약형
    /// - 2채널 이상 블랙박스에서 사용
    ///
    /// **사용 예시:**
    /// ```swift
    /// if let rear = videoFile.rearChannel {
    ///     print("후방 해상도: \(rear.resolutionName)")
    ///     rearPlayerView.loadVideo(from: rear.filePath)
    /// }
    /// ```
    var rearChannel: ChannelInfo? {
        return channel(for: .rear)
    }

    /// Check if specific channel exists
    /// - Parameter position: Camera position
    /// - Returns: True if channel exists
    ///
    /// 특정 채널이 있는지 확인합니다.
    ///
    /// **체크 로직:**
    /// - channel(for:)가 nil이 아니면 true
    /// - nil이면 false
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 채널별 UI 표시/숨김
    /// rearPlayerView.isHidden = !videoFile.hasChannel(.rear)
    /// leftPlayerView.isHidden = !videoFile.hasChannel(.left)
    /// rightPlayerView.isHidden = !videoFile.hasChannel(.right)
    ///
    /// // 채널 개수 안내
    /// if videoFile.hasChannel(.rear) {
    ///     print("2채널 이상 블랙박스")
    /// } else {
    ///     print("1채널 블랙박스")
    /// }
    /// ```
    func hasChannel(_ position: CameraPosition) -> Bool {
        return channel(for: position) != nil
    }

    /// Number of available channels
    ///
    /// 사용 가능한 채널 개수입니다.
    ///
    /// **채널 개수:**
    /// - 1: 전방만
    /// - 2: 전방 + 후방 (가장 일반적)
    /// - 3: 전방 + 후방 + 실내
    /// - 4: 전방 + 후방 + 좌측 + 우측
    /// - 5: 전방 + 후방 + 좌측 + 우측 + 실내
    ///
    /// **사용 예시:**
    /// ```swift
    /// print("\(videoFile.channelCount)채널 블랙박스")
    ///
    /// // UI 레이아웃 선택
    /// switch videoFile.channelCount {
    /// case 1:
    ///     useSingleViewLayout()
    /// case 2:
    ///     useDualViewLayout()
    /// case 3...5:
    ///     useMultiViewLayout()
    /// default:
    ///     break
    /// }
    /// ```
    var channelCount: Int {
        return channels.count
    }

    /// Array of enabled channels only
    ///
    /// 활성화된 채널만 포함하는 배열입니다.
    ///
    /// **필터링:**
    /// - isEnabled == true인 채널만
    /// - 사용자가 특정 채널을 숨긴 경우 제외
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 활성화된 채널만 재생
    /// for channel in videoFile.enabledChannels {
    ///     createPlayerView(for: channel)
    /// }
    ///
    /// print("\(videoFile.enabledChannels.count)개 채널 활성화")
    /// ```
    var enabledChannels: [ChannelInfo] {
        return channels.filter { $0.isEnabled }
    }

    /// Check if this is a multi-channel recording
    ///
    /// 멀티 채널 녹화인지 확인합니다.
    ///
    /// **멀티 채널 기준:**
    /// - 2개 이상의 채널
    /// - 1채널: false (단일 채널)
    /// - 2채널 이상: true (멀티 채널)
    ///
    /// **활용:**
    /// - UI 레이아웃 선택
    /// - 채널 전환 버튼 표시/숨김
    /// - 화면 분할 모드 활성화
    ///
    /// **사용 예시:**
    /// ```swift
    /// if videoFile.isMultiChannel {
    ///     // 채널 전환 버튼 표시
    ///     channelSwitchButton.isHidden = false
    ///
    ///     // 화면 분할 옵션 활성화
    ///     splitViewButton.isEnabled = true
    /// } else {
    ///     // 단일 채널 모드
    ///     channelSwitchButton.isHidden = true
    ///     splitViewButton.isEnabled = false
    /// }
    /// ```
    var isMultiChannel: Bool {
        return channels.count > 1
    }

    // MARK: - File Properties

    /// Total size of all channel files
    ///
    /// 모든 채널 파일의 총 크기입니다. (단위: bytes)
    ///
    /// **집계 연산:**
    /// - reduce 사용하여 모든 채널의 fileSize 합산
    /// - 초기값: 0
    /// - 누적 연산: $0 + $1.fileSize
    ///
    /// **reduce 동작 원리:**
    /// ```swift
    /// channels.reduce(0) { $0 + $1.fileSize }
    ///
    /// // 단계별 계산 (2채널 예시):
    /// 초기: result = 0
    /// 1단계: result = 0 + frontChannel.fileSize (100 MB)
    ///        result = 100 MB
    /// 2단계: result = 100 MB + rearChannel.fileSize (50 MB)
    ///        result = 150 MB
    /// 최종: 150 MB
    /// ```
    ///
    /// **예상 크기:**
    /// - 1채널: 60~100 MB (1분 Full HD)
    /// - 2채널: 100~150 MB
    /// - 5채널: 200~300 MB
    ///
    /// **사용 예시:**
    /// ```swift
    /// let totalSize = videoFile.totalFileSize
    /// print("총 크기: \(totalSize) bytes")
    ///
    /// // 포맷된 문자열
    /// print("총 크기: \(videoFile.totalFileSizeString)")  // "150 MB"
    ///
    /// // 저장 공간 체크
    /// if videoFile.totalFileSize > 500_000_000 {  // 500 MB
    ///     print("⚠️ 대용량 파일")
    /// }
    /// ```
    var totalFileSize: UInt64 {
        // reduce로 모든 채널의 fileSize 합산
        return channels.reduce(0) { $0 + $1.fileSize }
    }

    /// Total file size as human-readable string
    ///
    /// 총 파일 크기를 읽기 쉬운 문자열로 반환합니다.
    ///
    /// **ByteCountFormatter:**
    /// - Foundation의 표준 파일 크기 포맷터
    /// - 자동으로 적절한 단위 선택
    /// - 1024 기반 (이진)
    ///
    /// **포맷 예시:**
    /// ```
    /// 1,048,576 bytes     → "1 MB"
    /// 157,286,400 bytes   → "150 MB"
    /// 1,073,741,824 bytes → "1 GB"
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// fileSizeLabel.text = "크기: \(videoFile.totalFileSizeString)"
    /// // 출력: "크기: 150 MB"
    /// ```
    var totalFileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalFileSize))
    }

    /// Base filename (extracted from basePath)
    ///
    /// 기본 파일명입니다. (basePath에서 추출)
    ///
    /// **추출 방법:**
    /// - lastPathComponent: 경로의 마지막 부분
    /// - "normal/2025_01_10_09_00_00" → "2025_01_10_09_00_00"
    ///
    /// **파일명 형식:**
    /// - YYYY_MM_DD_HH_MM_SS
    /// - 예: 2025_01_10_09_00_00 (2025년 1월 10일 09:00:00)
    ///
    /// **사용 예시:**
    /// ```swift
    /// print(videoFile.baseFilename)  // "2025_01_10_09_00_00"
    ///
    /// // 파일 검색
    /// let searchTerm = "2025_01_10"
    /// if videoFile.baseFilename.contains(searchTerm) {
    ///     print("2025년 1월 10일 녹화 파일")
    /// }
    /// ```
    var baseFilename: String {
        return (basePath as NSString).lastPathComponent
    }

    /// Duration as formatted string (HH:MM:SS)
    ///
    /// 길이를 HH:MM:SS 형식의 문자열로 반환합니다.
    ///
    /// **포맷 규칙:**
    /// - 1시간 이상: "H:MM:SS" (예: "1:05:30")
    /// - 1시간 미만: "M:SS" (예: "1:30")
    ///
    /// **계산 과정:**
    /// ```swift
    /// duration = 3665초 (1시간 1분 5초)
    ///
    /// hours = 3665 / 3600 = 1
    /// minutes = (3665 % 3600) / 60 = 1065 / 60 = 17
    /// seconds = 3665 % 60 = 45
    ///
    /// 결과: "1:17:45"
    /// ```
    ///
    /// **포맷 문자열:**
    /// - %d: 정수 (시간, 분)
    /// - %02d: 2자리 정수, 앞에 0 패딩 (분, 초)
    /// - 예: minutes=5 → "%02d" → "05"
    ///
    /// **사용 예시:**
    /// ```swift
    /// durationLabel.text = videoFile.durationString
    /// // 출력: "1:00" (1분) 또는 "1:05:30" (1시간 5분 30초)
    ///
    /// // 남은 시간 표시
    /// let remaining = duration - currentTime
    /// let remainingString = formatDuration(remaining)
    /// ```
    var durationString: String {
        // 시간, 분, 초 계산
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        // 1시간 이상: "H:MM:SS"
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        // 1시간 미만: "M:SS"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Timestamp as formatted string
    ///
    /// 타임스탬프를 날짜+시간 형식의 문자열로 반환합니다.
    ///
    /// **DateFormatter:**
    /// - dateStyle: .medium (예: "2025. 1. 10.")
    /// - timeStyle: .medium (예: "오전 9:00:00")
    ///
    /// **로케일:**
    /// - 시스템 로케일 사용
    /// - 한국: "2025. 1. 10. 오전 9:00:00"
    /// - 미국: "Jan 10, 2025 at 9:00:00 AM"
    ///
    /// **사용 예시:**
    /// ```swift
    /// timestampLabel.text = videoFile.timestampString
    /// // 출력: "2025. 1. 10. 오전 9:00:00"
    /// ```
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    /// Short timestamp (date only)
    ///
    /// 날짜만 포함하는 짧은 타임스탬프입니다.
    ///
    /// **DateFormatter:**
    /// - dateStyle: .medium (예: "2025. 1. 10.")
    /// - timeStyle: .none (시간 제외)
    ///
    /// **사용 예시:**
    /// ```swift
    /// dateLabel.text = videoFile.dateString
    /// // 출력: "2025. 1. 10."
    ///
    /// // 날짜별 그룹화
    /// let grouped = Dictionary(grouping: videoFiles) { $0.dateString }
    /// ```
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }

    /// Short timestamp (time only)
    ///
    /// 시간만 포함하는 짧은 타임스탬프입니다.
    ///
    /// **DateFormatter:**
    /// - dateStyle: .none (날짜 제외)
    /// - timeStyle: .short (예: "오전 9:00")
    ///
    /// **사용 예시:**
    /// ```swift
    /// timeLabel.text = videoFile.timeString
    /// // 출력: "오전 9:00"
    ///
    /// // 같은 날짜 파일의 시간 표시
    /// for file in todayFiles {
    ///     print("\(file.timeString): \(file.eventType.displayName)")
    /// }
    /// ```
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // MARK: - Metadata Access

    /// Check if video has GPS data
    ///
    /// GPS 데이터가 있는지 확인합니다.
    ///
    /// **위임 패턴:**
    /// - metadata.hasGPSData로 위임
    /// - VideoFile이 직접 구현하지 않고 VideoMetadata에 위임
    ///
    /// **사용 예시:**
    /// ```swift
    /// if videoFile.hasGPSData {
    ///     showMapView()
    /// }
    /// ```
    var hasGPSData: Bool {
        return metadata.hasGPSData
    }

    /// Check if video has G-Sensor data
    ///
    /// G-센서 데이터가 있는지 확인합니다.
    ///
    /// **위임 패턴:**
    /// - metadata.hasAccelerationData로 위임
    ///
    /// **사용 예시:**
    /// ```swift
    /// if videoFile.hasAccelerationData {
    ///     showGForceGraph()
    /// }
    /// ```
    var hasAccelerationData: Bool {
        return metadata.hasAccelerationData
    }

    /// Check if video contains impact events
    ///
    /// 충격 이벤트가 있는지 확인합니다.
    ///
    /// **위임 패턴:**
    /// - metadata.hasImpactEvents로 위임
    /// - 2.5G 이상의 충격이 하나라도 있으면 true
    ///
    /// **사용 예시:**
    /// ```swift
    /// if videoFile.hasImpactEvents {
    ///     warningBadge.isHidden = false
    ///     warningBadge.text = "⚠️"
    /// }
    /// ```
    var hasImpactEvents: Bool {
        return metadata.hasImpactEvents
    }

    /// Number of impact events detected
    ///
    /// 감지된 충격 이벤트 개수입니다.
    ///
    /// **위임 패턴:**
    /// - metadata.impactEvents.count로 위임
    /// - 2.5G 이상의 충격 개수
    ///
    /// **사용 예시:**
    /// ```swift
    /// if videoFile.impactEventCount > 0 {
    ///     impactLabel.text = "충격 \(videoFile.impactEventCount)회"
    /// }
    /// ```
    var impactEventCount: Int {
        return metadata.impactEvents.count
    }

    // MARK: - Validation

    /// Check if video file is valid (has at least one channel)
    ///
    /// 비디오 파일이 유효한지 확인합니다.
    ///
    /// **유효성 조건:**
    /// 1. channels.isEmpty == false (채널이 하나 이상)
    /// 2. channels.allSatisfy { $0.isValid } (모든 채널이 유효)
    ///
    /// **allSatisfy 메서드:**
    /// - 배열의 모든 요소가 조건을 만족하면 true
    /// - 하나라도 실패하면 false
    /// - 빈 배열은 true 반환 (vacuous truth)
    ///
    /// **논리 AND (&&):**
    /// - 두 조건 모두 true여야 true
    /// - 채널이 있고 + 모든 채널이 유효
    ///
    /// **사용 예시:**
    /// ```swift
    /// if videoFile.isValid {
    ///     // 유효한 파일
    ///     enablePlayButton()
    /// } else {
    ///     // 잘못된 파일
    ///     showError("파일이 유효하지 않습니다")
    /// }
    ///
    /// // 유효한 파일만 필터링
    /// let validFiles = videoFiles.filter { $0.isValid }
    /// ```
    var isValid: Bool {
        return !channels.isEmpty && channels.allSatisfy { $0.isValid }
    }

    /// Check if video is playable (valid and not corrupted)
    ///
    /// 비디오가 재생 가능한지 확인합니다.
    ///
    /// **재생 가능 조건:**
    /// 1. isValid == true (유효한 파일)
    /// 2. isCorrupted == false (손상되지 않음)
    ///
    /// **논리 AND (&&):**
    /// - 둘 다 true여야 재생 가능
    /// - 유효하지만 손상된 파일: 재생 불가
    /// - 유효하고 손상 안 됨: 재생 가능 ✓
    ///
    /// **사용 예시:**
    /// ```swift
    /// playButton.isEnabled = videoFile.isPlayable
    ///
    /// if !videoFile.isPlayable {
    ///     if !videoFile.isValid {
    ///         showError("파일이 유효하지 않습니다")
    ///     } else if videoFile.isCorrupted {
    ///         showError("파일이 손상되었습니다")
    ///     }
    /// }
    ///
    /// // 재생 가능한 파일만 필터링
    /// let playableFiles = videoFiles.filter { $0.isPlayable }
    /// ```
    var isPlayable: Bool {
        return isValid && !isCorrupted
    }

    // MARK: - Mutations (return new instance)

    /// Create a copy with updated favorite status
    /// - Parameter isFavorite: New favorite status
    /// - Returns: New VideoFile instance
    ///
    /// 즐겨찾기 상태를 변경한 새 인스턴스를 생성합니다.
    ///
    /// **불변 업데이트 패턴:**
    /// - struct는 불변 (immutable)
    /// - 기존 인스턴스를 수정하는 대신 새 인스턴스 생성
    /// - 원본은 변경되지 않음
    ///
    /// **왜 불변인가?**
    /// 1. 스레드 안전 (Thread safety)
    /// 2. 예측 가능성 (Predictability)
    /// 3. SwiftUI 호환성 (State management)
    ///
    /// **동작 원리:**
    /// ```swift
    /// let file1 = VideoFile(..., isFavorite: false)
    /// let file2 = file1.withFavorite(true)
    ///
    /// file1.isFavorite  // false (변경 안 됨)
    /// file2.isFavorite  // true  (새 인스턴스)
    /// ```
    ///
    /// **SwiftUI 통합:**
    /// ```swift
    /// @State private var videoFile: VideoFile = ...
    ///
    /// Button("Toggle Favorite") {
    ///     // SwiftUI가 자동으로 뷰 업데이트
    ///     videoFile = videoFile.withFavorite(!videoFile.isFavorite)
    /// }
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 즐겨찾기 추가
    /// let favoriteFile = videoFile.withFavorite(true)
    ///
    /// // 즐겨찾기 토글
    /// let toggled = videoFile.withFavorite(!videoFile.isFavorite)
    ///
    /// // 배열에서 업데이트
    /// videoFiles[index] = videoFiles[index].withFavorite(true)
    /// ```
    func withFavorite(_ isFavorite: Bool) -> VideoFile {
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }

    /// Create a copy with updated notes
    /// - Parameter notes: New notes text
    /// - Returns: New VideoFile instance
    ///
    /// 메모를 변경한 새 인스턴스를 생성합니다.
    ///
    /// **불변 업데이트 패턴:**
    /// - withFavorite(_:)와 동일한 패턴
    /// - 메모만 변경, 나머지는 유지
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 메모 추가
    /// let notedFile = videoFile.withNotes("Beautiful sunset")
    ///
    /// // 메모 수정
    /// let updatedFile = videoFile.withNotes("Updated: Beautiful sunset drive")
    ///
    /// // 메모 제거
    /// let clearedFile = videoFile.withNotes(nil)
    ///
    /// // 사용자 입력 반영
    /// let newFile = videoFile.withNotes(notesTextField.text)
    /// ```
    func withNotes(_ notes: String?) -> VideoFile {
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }

    /// Create a copy with enabled/disabled channel
    /// - Parameters:
    ///   - position: Camera position
    ///   - enabled: New enabled status
    /// - Returns: New VideoFile instance
    ///
    /// 특정 채널의 활성화 상태를 변경한 새 인스턴스를 생성합니다.
    ///
    /// **복잡한 업데이트:**
    /// - 중첩된 구조 업데이트 (channels 배열 내부)
    /// - 특정 채널만 수정, 나머지는 유지
    ///
    /// **알고리즘:**
    /// 1. channels 배열을 map으로 순회
    /// 2. 해당 position의 채널 찾기
    /// 3. 해당 채널만 새 ChannelInfo 생성 (isEnabled 변경)
    /// 4. 나머지 채널은 그대로 반환
    /// 5. 업데이트된 channels로 새 VideoFile 생성
    ///
    /// **map 동작:**
    /// ```swift
    /// channels.map { channel -> ChannelInfo in
    ///     if channel.position == position {
    ///         // 이 채널만 수정
    ///         return ChannelInfo(..., isEnabled: enabled)
    ///     }
    ///     // 나머지는 그대로
    ///     return channel
    /// }
    /// ```
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 후방 카메라 숨기기
    /// let hiddenRear = videoFile.withChannel(.rear, enabled: false)
    ///
    /// // 실내 카메라 표시
    /// let shownInterior = videoFile.withChannel(.interior, enabled: true)
    ///
    /// // 채널 토글
    /// if let rear = videoFile.rearChannel {
    ///     let toggled = videoFile.withChannel(.rear, enabled: !rear.isEnabled)
    /// }
    ///
    /// // UI 버튼 핸들러
    /// @objc func toggleRearCamera() {
    ///     videoFile = videoFile.withChannel(.rear, enabled: !videoFile.rearChannel!.isEnabled)
    /// }
    /// ```
    func withChannel(_ position: CameraPosition, enabled: Bool) -> VideoFile {
        // 채널 배열을 순회하며 특정 채널만 수정
        let updatedChannels = channels.map { channel -> ChannelInfo in
            if channel.position == position {
                // 해당 채널: isEnabled만 변경한 새 인스턴스 생성
                return ChannelInfo(
                    id: channel.id,
                    position: channel.position,
                    filePath: channel.filePath,
                    width: channel.width,
                    height: channel.height,
                    frameRate: channel.frameRate,
                    bitrate: channel.bitrate,
                    codec: channel.codec,
                    audioCodec: channel.audioCodec,
                    isEnabled: enabled,
                    fileSize: channel.fileSize
                )
            }
            // 다른 채널: 그대로 반환
            return channel
        }

        // 업데이트된 channels로 새 VideoFile 생성
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: updatedChannels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }
}

// MARK: - Sample Data

/*
 ───────────────────────────────────────────────────────────────────────────────
 Sample Data - 샘플 비디오 파일 데이터
 ───────────────────────────────────────────────────────────────────────────────

 테스트, SwiftUI 프리뷰, 개발 중 UI 확인을 위한 샘플 데이터입니다.

 【일반 샘플】

 1. normal5Channel: 5채널 일반 녹화
    - 모든 채널 포함 (전방, 후방, 좌측, 우측, 실내)
    - 완전한 메타데이터 (GPS + G-센서)
    - 5채널 블랙박스 테스트용

 2. impact2Channel: 2채널 충격 이벤트
    - 전방 + 후방
    - 충격 메타데이터 포함
    - 사고 영상 시뮬레이션

 3. parking1Channel: 1채널 주차 모드
    - 전방만
    - GPS만 (센서 없음)
    - 주차 모드 테스트

 4. favoriteRecording: 즐겨찾기 녹화
    - isFavorite = true
    - notes 포함
    - 사용자 기능 테스트

 5. corruptedFile: 손상된 파일
    - isCorrupted = true
    - 빈 메타데이터
    - 에러 처리 테스트

 【실제 테스트 파일】

 실제 비디오 파일을 사용하는 테스트 데이터:
 - comma2k19Test: Comma.ai 자율주행 데이터셋 (48초)
 - test360p, test720p, test1080p: 다양한 해상도 테스트
 - multiChannel4Test: 4채널 멀티뷰 테스트

 【사용 예시】

 SwiftUI 프리뷰:
 ```swift
 struct VideoFileView_Previews: PreviewProvider {
     static var previews: some View {
         Group {
             VideoFileView(file: .normal5Channel)
                 .previewDisplayName("5 Channels")

             VideoFileView(file: .impact2Channel)
                 .previewDisplayName("Impact Event")

             VideoFileView(file: .corruptedFile)
                 .previewDisplayName("Corrupted")
         }
     }
 }
 ```

 단위 테스트:
 ```swift
 func testMultiChannel() {
     let file = VideoFile.normal5Channel
     XCTAssertEqual(file.channelCount, 5)
     XCTAssertTrue(file.isMultiChannel)
     XCTAssertTrue(file.isValid)
 }

 func testImpactDetection() {
     let file = VideoFile.impact2Channel
     XCTAssertTrue(file.hasImpactEvents)
     XCTAssertGreaterThan(file.impactEventCount, 0)
 }
 ```

 ───────────────────────────────────────────────────────────────────────────────
 */

extension VideoFile {
    /// Sample normal recording (5 channels)
    ///
    /// 5채널 일반 녹화 샘플입니다.
    ///
    /// **포함 채널:**
    /// - 전방 (Full HD, 100 MB)
    /// - 후방 (HD, 50 MB)
    /// - 좌측 (HD, 50 MB)
    /// - 우측 (HD, 50 MB)
    /// - 실내 (HD, 50 MB)
    /// - 총 크기: 300 MB
    ///
    /// **메타데이터:**
    /// - GPS: 60개 포인트 (1분)
    /// - G-센서: 600개 포인트 (1분, 10Hz)
    /// - 장치 정보: BlackVue DR900X-2CH
    static let normal5Channel = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 60.0,
        channels: ChannelInfo.allSampleChannels,
        metadata: VideoMetadata.sample,
        basePath: "normal/2025_01_10_09_00_00"
    )

    /// Sample impact recording (2 channels)
    ///
    /// 2채널 충격 이벤트 샘플입니다.
    ///
    /// **포함 채널:**
    /// - 전방 (Full HD, 100 MB)
    /// - 후방 (HD, 50 MB)
    /// - 총 크기: 150 MB
    ///
    /// **메타데이터:**
    /// - 충격 이벤트 포함 (3.5G)
    /// - 짧은 길이 (30초)
    /// - 충격 전후 15초씩
    static let impact2Channel = VideoFile(
        timestamp: Date().addingTimeInterval(-3600),
        eventType: .impact,
        duration: 30.0,
        channels: [ChannelInfo.frontHD, ChannelInfo.rearHD],
        metadata: VideoMetadata.withImpact,
        basePath: "event/2025_01_10_10_30_15"
    )

    /// Sample parking recording (1 channel)
    ///
    /// 1채널 주차 모드 샘플입니다.
    ///
    /// **포함 채널:**
    /// - 전방 (Full HD, 100 MB)
    ///
    /// **메타데이터:**
    /// - GPS만 (센서 없음)
    /// - 짧은 길이 (10초)
    /// - 움직임 감지 시 녹화
    static let parking1Channel = VideoFile(
        timestamp: Date().addingTimeInterval(-7200),
        eventType: .parking,
        duration: 10.0,
        channels: [ChannelInfo.frontHD],
        metadata: VideoMetadata.gpsOnly,
        basePath: "parking/2025_01_10_18_00_00"
    )

    /// Sample favorite recording
    ///
    /// 즐겨찾기 녹화 샘플입니다.
    ///
    /// **특징:**
    /// - isFavorite = true
    /// - notes 포함 ("Beautiful sunset drive")
    /// - 수동 녹화 (EventType.manual)
    /// - 긴 길이 (2분)
    static let favoriteRecording = VideoFile(
        timestamp: Date().addingTimeInterval(-10800),
        eventType: .manual,
        duration: 120.0,
        channels: [ChannelInfo.frontHD, ChannelInfo.rearHD],
        metadata: VideoMetadata.sample,
        basePath: "manual/2025_01_10_15_00_00",
        isFavorite: true,
        notes: "Beautiful sunset drive"
    )

    /// Sample corrupted file
    ///
    /// 손상된 파일 샘플입니다.
    ///
    /// **특징:**
    /// - isCorrupted = true
    /// - duration = 0 (재생 불가)
    /// - 빈 메타데이터
    /// - 에러 처리 테스트용
    static let corruptedFile = VideoFile(
        timestamp: Date().addingTimeInterval(-14400),
        eventType: .normal,
        duration: 0.0,
        channels: [ChannelInfo.frontHD],
        metadata: VideoMetadata.empty,
        basePath: "normal/2025_01_10_12_00_00",
        isCorrupted: true
    )

    /// Array of all sample files
    ///
    /// 모든 샘플 파일의 배열입니다.
    ///
    /// **포함 샘플:**
    /// - normal5Channel: 5채널 일반
    /// - impact2Channel: 2채널 충격
    /// - parking1Channel: 1채널 주차
    /// - favoriteRecording: 즐겨찾기
    /// - corruptedFile: 손상 파일
    ///
    /// **사용 예시:**
    /// ```swift
    /// List(VideoFile.allSamples) { file in
    ///     VideoFileRow(file: file)
    /// }
    /// ```
    static let allSamples: [VideoFile] = [
        normal5Channel,
        impact2Channel,
        parking1Channel,
        favoriteRecording,
        corruptedFile
    ]

    // MARK: - Test Data with Real Files

    /// Test video: comma2k19 sample with sensor data
    ///
    /// Comma.ai comma2k19 데이터셋 샘플입니다.
    ///
    /// **파일 정보:**
    /// - 해상도: 1164×874 (약 1.2:1)
    /// - 프레임 레이트: 25 fps
    /// - 길이: 48초
    /// - 크기: 15.4 MB
    /// - 용도: 자율주행 연구 데이터
    static let comma2k19Test = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 48.0,
        channels: [
            ChannelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            )
        ],
        metadata: VideoMetadata.empty,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample"
    )

    /// Test video: 360p basic test
    ///
    /// 360p 기본 테스트 비디오입니다.
    ///
    /// **파일 정보:**
    /// - 해상도: 640×360 (SD 미만)
    /// - 프레임 레이트: 30 fps
    /// - 길이: 10초
    /// - 크기: 991 KB (약 1 MB)
    static let test360p = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 10.0,
        channels: [
            ChannelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_360p.mp4",
                width: 640,
                height: 360,
                frameRate: 30.0,
                bitrate: 792_000,
                codec: "h264",
                fileSize: 991_232,
                duration: 10.0
            )
        ],
        metadata: VideoMetadata.empty,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_360p"
    )

    /// Test video: 720p HD test
    ///
    /// 720p HD 테스트 비디오입니다.
    ///
    /// **파일 정보:**
    /// - 해상도: 1280×720 (HD)
    /// - 프레임 레이트: 30 fps
    /// - 길이: 10초
    /// - 크기: 5 MB
    static let test720p = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 10.0,
        channels: [
            ChannelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_720p.mp4",
                width: 1280,
                height: 720,
                frameRate: 30.0,
                bitrate: 3_900_000,
                codec: "h264",
                fileSize: 5_033_984,
                duration: 10.0
            )
        ],
        metadata: VideoMetadata.empty,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_720p"
    )

    /// Test video: 1080p high quality test
    ///
    /// 1080p Full HD 고품질 테스트 비디오입니다.
    ///
    /// **파일 정보:**
    /// - 해상도: 1920×1080 (Full HD)
    /// - 프레임 레이트: 60 fps (고급)
    /// - 길이: 10초
    /// - 크기: 10 MB
    static let test1080p = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 10.0,
        channels: [
            ChannelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/sample_1080p.mp4",
                width: 1920,
                height: 1080,
                frameRate: 60.0,
                bitrate: 8_300_000,
                codec: "h264",
                fileSize: 10_485_760,
                duration: 10.0
            )
        ],
        metadata: VideoMetadata.empty,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/sample_1080p"
    )

    /// Test video: Multi-channel simulation (4 channels using comma2k19)
    ///
    /// 4채널 멀티뷰 시뮬레이션 테스트입니다.
    ///
    /// **파일 정보:**
    /// - 4채널: 전방, 후방, 좌측, 우측
    /// - 모든 채널 동일 비디오 (comma2k19) 사용
    /// - 총 크기: 약 60 MB (4 × 15 MB)
    /// - 멀티 채널 UI 테스트용
    static let multiChannel4Test = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 48.0,
        channels: [
            ChannelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            ),
            ChannelInfo(
                position: .rear,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            ),
            ChannelInfo(
                position: .left,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            ),
            ChannelInfo(
                position: .right,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            )
        ],
        metadata: VideoMetadata.empty,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_multichannel"
    )

    /// All real test files
    ///
    /// 모든 실제 테스트 파일의 배열입니다.
    ///
    /// **포함 테스트:**
    /// - multiChannel4Test: 4채널 멀티뷰 (맨 앞, 자주 사용)
    /// - comma2k19Test: 자율주행 데이터
    /// - test1080p: Full HD 60fps
    /// - test720p: HD 30fps
    /// - test360p: 저해상도
    ///
    /// **사용 예시:**
    /// ```swift
    /// // 개발 중 테스트 파일 선택
    /// List(VideoFile.allTestFiles) { file in
    ///     Button(file.basePath) {
    ///         playVideo(file)
    ///     }
    /// }
    /// ```
    static let allTestFiles: [VideoFile] = [
        multiChannel4Test,  // Multi-channel test first for easy access
        comma2k19Test,
        test1080p,
        test720p,
        test360p
    ]
}
