/// @file VideoFileLoader.swift
/// @brief Service for loading video file information and creating VideoFile models
/// @author BlackboxPlayer Development Team
/// @details
/// 이 파일은 VideoFileGroup (파일 그룹)을 VideoFile (재생 가능 모델)로 변환하는 서비스를 정의합니다.
/// 각 채널의 정보를 추출하고 메타데이터를 결합하여 완전한 VideoFile을 생성합니다.

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                   VideoFileLoader - 비디오 파일 로더 서비스                     ║
 ║                                                                              ║
 ║  목적:                                                                        ║
 ║    VideoFileGroup (파일 그룹)을 VideoFile (재생 가능 모델)로 변환합니다.        ║
 ║    각 채널의 정보를 추출하고 메타데이터를 결합하여 완전한 VideoFile을 생성합니다.  ║
 ║                                                                              ║
 ║  핵심 기능:                                                                   ║
 ║    • VideoFileGroup → VideoFile 변환                                         ║
 ║    • 각 채널 (카메라)의 비디오 정보 추출                                        ║
 ║    • GPS/가속도계 메타데이터 로딩                                              ║
 ║    • 파일 손상 검증                                                           ║
 ║    • 배치 처리 (여러 파일 동시 로딩)                                           ║
 ║                                                                              ║
 ║  데이터 흐름:                                                                 ║
 ║    ```                                                                       ║
 ║    FileScanner (디렉토리 스캔)                                                ║
 ║        ↓                                                                     ║
 ║    VideoFileGroup[] (그룹화된 파일들)                                          ║
 ║        ↓                                                                     ║
 ║    VideoFileLoader (본 클래스) ← MetadataExtractor (GPS/센서)                 ║
 ║        ↓                                                                     ║
 ║    VideoFile[] (재생 가능한 모델)                                              ║
 ║        ↓                                                                     ║
 ║    UI (파일 목록 표시)                                                        ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ║  블랙박스 파일 구조:                                                           ║
 ║    ```                                                                       ║
 ║    /normal/                                                                  ║
 ║      2025_01_10_09_00_00_F.mp4  (전방)                                       ║
 ║      2025_01_10_09_00_00_R.mp4  (후방)                                       ║
 ║      2025_01_10_09_00_00_L.mp4  (좌측)                                       ║
 ║      2025_01_10_09_00_00_Ri.mp4 (우측)                                       ║
 ║      2025_01_10_09_00_00_I.mp4  (실내)                                       ║
 ║      2025_01_10_09_00_00.gps    (GPS 데이터)                                 ║
 ║      2025_01_10_09_00_00.gsensor (가속도 데이터)                              ║
 ║                                                                              ║
 ║    FileScanner가 이들을 하나의 VideoFileGroup으로 묶음                          ║
 ║    → VideoFileLoader가 VideoFile로 변환                                       ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ║  사용 예:                                                                     ║
 ║    ```swift                                                                  ║
 ║    let scanner = FileScanner()                                               ║
 ║    let loader = VideoFileLoader()                                            ║
 ║                                                                              ║
 ║    // 1. 디렉토리 스캔                                                        ║
 ║    let groups = try scanner.scanDirectory(folderURL)                         ║
 ║                                                                              ║
 ║    // 2. VideoFile로 변환                                                    ║
 ║    let videoFiles = loader.loadVideoFiles(from: groups)                      ║
 ║                                                                              ║
 ║    // 3. UI 표시                                                             ║
 ║    self.videoFiles = videoFiles                                              ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ VideoFileGroup vs VideoFile                                                  │
 └──────────────────────────────────────────────────────────────────────────────┘

 ┌───────────────────────────────────────────────────────────────────────────┐
 │ 비교                                                                       │
 ├───────────────────────────────────────────────────────────────────────────┤
 │                                                                           │
 │ VideoFileGroup (중간 단계)                                                 │
 │   • FileScanner가 생성                                                     │
 │   • 파일들을 타임스탬프로 그룹화만 함                                        │
 │   • 비디오 정보 없음 (해상도, 프레임레이트 등)                               │
 │   • 메타데이터 없음 (GPS, 가속도계)                                         │
 │   • 재생 불가                                                              │
 │                                                                           │
 │ VideoFile (최종 모델)                                                       │
 │   • VideoFileLoader가 생성                                                 │
 │   • 각 채널의 상세 정보 포함                                                │
 │   • 비디오 정보 완전 (해상도, 코덱, 비트레이트)                              │
 │   • 메타데이터 포함 (GPS 경로, G-센서 데이터)                                │
 │   • 재생 가능                                                              │
 │                                                                           │
 └───────────────────────────────────────────────────────────────────────────┘

 변환 과정 예시:

 VideoFileGroup:
 ```
 timestamp: 2025-01-10 09:00:00
 eventType: .normal
 basePath: "/Volumes/SD/normal/"
 files: [
     VideoFileInfo(url: "...F.mp4", position: .front, size: 100MB),
     VideoFileInfo(url: "...R.mp4", position: .rear, size: 100MB)
 ]
 ```

 →  VideoFileLoader 처리  →

 VideoFile:
 ```
 id: UUID()
 timestamp: 2025-01-10 09:00:00
 eventType: .normal
 duration: 60.0 seconds
 channels: [
     ChannelInfo(position: .front, width: 1920, height: 1080, ...),
     ChannelInfo(position: .rear, width: 1920, height: 1080, ...)
 ]
 metadata: VideoMetadata(
     gpsPoints: [GPSPoint(), ...],
     accelerationData: [AccelerationData(), ...]
 )
 isCorrupted: false
 ```
 */

import Foundation

// MARK: - VideoFileLoader 클래스

/// @class VideoFileLoader
/// @brief 비디오 파일 정보를 추출하고 VideoFile 모델을 생성하는 서비스
///
/// @details
/// 이 클래스는 다음 역할을 수행합니다:
/// 1. VideoFileGroup에서 각 채널(카메라)의 정보 추출
/// 2. MetadataExtractor로 GPS/G-센서 데이터 로딩
/// 3. 모든 정보를 결합하여 완전한 VideoFile 생성
/// 4. 파일 손상 검증
///
/// ## 구현 상태:
/// 현재는 FFmpeg 비디오 분석이 미구현 상태입니다 (TODO).
/// 기본값으로 1920x1080, 30fps, H.264 코덱을 사용합니다.
/// 향후 VideoDecoder를 사용하여 실제 비디오 정보를 추출할 예정입니다.
///
/// ## 성능 고려사항:
/// - 파일 개수가 많을 경우 로딩 시간이 길어질 수 있음
/// - 백그라운드 스레드에서 호출 권장:
///   ```swift
///   DispatchQueue.global(qos: .userInitiated).async {
///       let files = loader.loadVideoFiles(from: groups)
///       DispatchQueue.main.async {
///           self.videoFiles = files  // UI 업데이트
///       }
///   }
///   ```
class VideoFileLoader {

    // MARK: - Properties

    /// @var metadataExtractor
    /// @brief 메타데이터 추출기 (GPS/G-센서 데이터)
    /// @details
    /// MetadataExtractor는 별도 파일(.gps, .gsensor)에서 데이터를 읽어옵니다.
    ///
    /// 파일 예시:
    /// ```
    /// 2025_01_10_09_00_00_F.mp4   ← 비디오 파일
    /// 2025_01_10_09_00_00.gps     ← GPS 데이터 (NMEA 0183 형식)
    /// 2025_01_10_09_00_00.gsensor ← 가속도 데이터 (바이너리)
    /// ```
    ///
    /// 재사용성:
    /// 하나의 metadataExtractor 인스턴스를 모든 파일 로딩에 재사용합니다.
    /// 매번 새로 생성하는 것보다 효율적입니다.
    private let metadataExtractor: MetadataExtractor

    // MARK: - Initialization

    /// @brief VideoFileLoader 초기화
    ///
    /// @details
    /// MetadataExtractor를 자동으로 생성합니다.
    ///
    /// 사용 예:
    /// ```swift
    /// let loader = VideoFileLoader()  // 간단한 초기화
    /// ```
    ///
    /// 의존성 주입:
    /// 향후 테스트를 위해 의존성 주입 가능하게 변경할 수 있습니다:
    /// ```swift
    /// init(metadataExtractor: MetadataExtractor = MetadataExtractor()) {
    ///     self.metadataExtractor = metadataExtractor
    /// }
    /// ```
    init() {
        self.metadataExtractor = MetadataExtractor()
    }

    // MARK: - Public Methods

    /// @brief 비디오 파일 그룹에서 VideoFile 생성
    ///
    /// @param group 하나의 타임스탬프에 속하는 비디오 파일 그룹
    /// @return 생성된 VideoFile 또는 nil (로딩 실패 시)
    ///
    /// @details
    /// 전체 프로세스:
    /// 1. 각 채널 파일의 비디오 정보 추출 (extractChannelInfo)
    /// 2. 전방 카메라에서 메타데이터 로딩 (MetadataExtractor)
    /// 3. VideoFile 객체 생성
    /// 4. 손상 검사 (checkCorruption)
    ///
    /// nil 반환 경우:
    /// - group.files가 비어있음
    /// - 모든 채널 정보 추출 실패
    /// - 파일 접근 불가
    ///
    /// 실제 사용 흐름:
    /// ```
    /// VideoFileGroup {
    ///   files: [F.mp4, R.mp4]
    /// }
    ///   ↓
    /// extractChannelInfo(F.mp4) → ChannelInfo(front)
    /// extractChannelInfo(R.mp4) → ChannelInfo(rear)
    ///   ↓
    /// metadataExtractor.extract(F.mp4) → VideoMetadata
    ///   ↓
    /// VideoFile {
    ///   channels: [front, rear]
    ///   metadata: VideoMetadata
    /// }
    ///   ↓
    /// checkCorruption() → isCorrupted: false
    ///   ↓
    /// return VideoFile
    /// ```
    ///
    /// 손상된 파일 처리:
    /// 파일이 손상되었어도 nil을 반환하지 않습니다.
    /// 대신 isCorrupted=true로 표시하여 UI에서 경고 표시합니다.
    func loadVideoFile(from group: VideoFileGroup) -> VideoFile? {
        // 1. 빈 그룹 검사
        // - guard문: 조건 실패 시 early return
        // - nil 반환: 비디오 파일이 없으면 VideoFile 생성 불가
        guard !group.files.isEmpty else { return nil }

        // 2. 각 채널의 정보 추출
        // - var: 배열에 append하므로 가변
        // - [ChannelInfo]: 초기값은 빈 배열
        var channels: [ChannelInfo] = []

        // 3. 모든 파일에 대해 채널 정보 추출
        // - for-in: 각 fileInfo를 순회
        // - if let: extractChannelInfo가 nil 반환 가능 (실패 시)
        // - 성공한 채널만 channels 배열에 추가
        for fileInfo in group.files {
            if let channelInfo = extractChannelInfo(from: fileInfo) {
                channels.append(channelInfo)
            }
        }

        // 4. 최소 하나의 채널은 있어야 함
        // - 모든 채널 추출 실패 시 nil 반환
        guard !channels.isEmpty else { return nil }

        // 5. 재생 시간 가져오기
        // - channels.first: 첫 번째 채널 (Optional)
        // - ?. : Optional chaining (nil이면 전체가 nil)
        // - ?? 0: nil이면 기본값 0 사용
        //
        // 왜 첫 번째 채널?
        // - 모든 채널의 duration이 동일해야 함 (동기화)
        // - 다를 경우 문제 있는 파일
        let duration = channels.first?.duration ?? 0

        // 6. 메타데이터 추출 (GPS/가속도계)
        //
        // 우선순위:
        // 1. 전방 카메라 파일에서 추출 (가장 중요한 뷰)
        // 2. 전방이 없으면 첫 번째 파일 사용
        //
        // group.files.first { ... }:
        // - 조건을 만족하는 첫 번째 요소 찾기
        // - $0: 클로저의 첫 번째 매개변수 (fileInfo)
        // - $0.position == .front: 전방 카메라인지 확인
        let frontChannel = group.files.first { $0.position == .front } ?? group.files.first

        // 메타데이터 추출 시도
        let metadata: VideoMetadata
        if let frontChannel = frontChannel,  // 파일이 있고
           let extractedMetadata = metadataExtractor.extractMetadata(from: frontChannel.url.path) {  // 추출 성공
            // 성공: 추출된 메타데이터 사용
            metadata = extractedMetadata
        } else {
            // 실패: 빈 메타데이터 사용 (GPS/가속도 없음)
            metadata = VideoMetadata()
        }

        // 7. VideoFile 생성
        // - UUID(): 고유 식별자 자동 생성
        // - 모든 정보를 결합하여 완전한 VideoFile 생성
        let videoFile = VideoFile(
            id: UUID(),
            timestamp: group.timestamp,           // 그룹의 타임스탬프
            eventType: group.eventType,           // 이벤트 타입 (normal, impact 등)
            duration: duration,                   // 첫 번째 채널에서 가져온 시간
            channels: channels,                   // 추출한 모든 채널 정보
            metadata: metadata,                   // GPS/가속도 메타데이터
            basePath: group.basePath,             // 파일들의 기본 경로
            isFavorite: false,                    // 초기값: 즐겨찾기 아님
            notes: nil,                           // 초기값: 메모 없음
            isCorrupted: false                    // 아직 검사 안 함
        )

        // 8. 손상 검사
        // - checkCorruption(): VideoFile extension에 구현
        // - 파일 존재, duration, fileSize 등을 검사
        let isCorrupted = videoFile.checkCorruption()

        // 9. 손상되었으면 isCorrupted=true로 새로 생성
        // - 왜 새로 생성? VideoFile은 struct (불변)이므로 수정 불가
        // - 모든 필드를 복사하되 isCorrupted만 true로 변경
        if isCorrupted {
            // Return corrupted VideoFile for display with warning
            // UI에서 "⚠️ 손상된 파일" 같은 경고 표시 가능
            return VideoFile(
                id: videoFile.id,
                timestamp: videoFile.timestamp,
                eventType: videoFile.eventType,
                duration: videoFile.duration,
                channels: videoFile.channels,
                metadata: videoFile.metadata,
                basePath: videoFile.basePath,
                isFavorite: false,
                notes: nil,
                isCorrupted: true  // 여기만 다름!
            )
        }

        // 10. 정상 VideoFile 반환
        return videoFile
    }

    /// @brief 여러 비디오 파일 그룹을 한 번에 로딩
    ///
    /// @param groups 비디오 파일 그룹 배열
    /// @return VideoFile 배열 (실패한 그룹은 제외됨)
    ///
    /// @details
    /// FileScanner가 스캔한 모든 그룹을 VideoFile 배열로 변환합니다.
    ///
    /// compactMap:
    /// compactMap은 map + filter(nil 제거)의 조합입니다:
    /// ```swift
    /// // map: 모든 요소 변환 (nil 포함)
    /// let results = groups.map { loadVideoFile(from: $0) }
    /// // results: [VideoFile?, VideoFile?, nil, VideoFile?, ...]
    ///
    /// // compactMap: nil 제거 + 변환
    /// let results = groups.compactMap { loadVideoFile(from: $0) }
    /// // results: [VideoFile, VideoFile, VideoFile, ...]  (nil 없음!)
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// let scanner = FileScanner()
    /// let loader = VideoFileLoader()
    ///
    /// // 100개 그룹 스캔
    /// let groups = try scanner.scanDirectory(folder)  // [VideoFileGroup]
    ///
    /// // 95개 성공, 5개 실패 (nil) 가정
    /// let videoFiles = loader.loadVideoFiles(from: groups)
    /// // videoFiles는 95개만 포함 (자동으로 nil 제거)
    /// ```
    ///
    /// 실패 처리:
    /// 개별 그룹 로딩 실패는 조용히 무시됩니다.
    /// 로그를 보고 싶으면 커스텀 구현 필요:
    /// ```swift
    /// groups.compactMap { group in
    ///     if let videoFile = loadVideoFile(from: group) {
    ///         return videoFile
    ///     } else {
    ///         print("Failed to load group: \(group.timestamp)")
    ///         return nil
    ///     }
    /// }
    /// ```
    func loadVideoFiles(from groups: [VideoFileGroup]) -> [VideoFile] {
        // compactMap { ... }:
        // 1. 각 group에 대해 loadVideoFile(from:) 호출
        // 2. 결과가 nil이 아닌 것만 배열에 포함
        // 3. [VideoFile?] → [VideoFile] 변환
        //
        // $0:
        // - 클로저의 첫 번째 (그리고 유일한) 매개변수
        // - 여기서는 VideoFileGroup 타입
        return groups.compactMap { loadVideoFile(from: $0) }
    }

    /// @brief 파일이 유효한 비디오 파일인지 빠르게 확인
    ///
    /// @param url 검사할 파일 URL
    /// @return true면 유효한 비디오 파일
    ///
    /// @details
    /// 실제 디코딩 없이 확장자와 파일 존재 여부만 검사합니다.
    ///
    /// 제한사항:
    /// 이 메서드는 파일 형식만 검사합니다.
    /// 실제로 재생 가능한지는 확인하지 않습니다.
    /// 파일이 손상되었어도 true를 반환할 수 있습니다.
    ///
    /// 사용 사례:
    /// ```swift
    /// // 드래그 앤 드롭 검증
    /// func dragged(_ files: [URL]) {
    ///     let validFiles = files.filter { loader.isValidVideoFile($0) }
    ///     if validFiles.isEmpty {
    ///         showAlert("비디오 파일이 아닙니다")
    ///     }
    /// }
    /// ```
    ///
    /// 지원 확장자:
    /// - mp4: 가장 일반적 (H.264 + AAC)
    /// - mov: Apple QuickTime
    /// - avi: 오래된 포맷 (Windows)
    /// - mkv: Matroska (고급 기능)
    func isValidVideoFile(_ url: URL) -> Bool {
        // 1. 파일 확장자 추출 및 소문자 변환
        // - url.pathExtension: "video.MP4" → "MP4"
        // - .lowercased(): "MP4" → "mp4"
        let fileExtension = url.pathExtension.lowercased()

        // 2. 지원하는 확장자 목록
        // - let: 상수 배열 (변경 불가)
        // - [String]: 문자열 배열
        let validExtensions = ["mp4", "mov", "avi", "mkv"]

        // 3. 두 가지 조건 모두 만족해야 함
        // - &&: 논리 AND 연산자
        // - 왼쪽과 오른쪽 모두 true여야 결과가 true
        //
        // FileManager.default.fileExists(atPath:):
        // - 파일이 실제로 존재하는지 확인
        // - url.path: URL → String 경로 변환
        //
        // validExtensions.contains(fileExtension):
        // - 확장자가 목록에 있는지 확인
        // - "mp4" in ["mp4", "mov", "avi", "mkv"] → true
        return FileManager.default.fileExists(atPath: url.path) &&
               validExtensions.contains(fileExtension)
    }

    // MARK: - Private Methods

    /// @brief VideoFileInfo에서 ChannelInfo 추출 (내부용)
    ///
    /// @param fileInfo 파일 기본 정보 (URL, position, size)
    /// @return 추출된 ChannelInfo 또는 nil (실패 시)
    ///
    /// @details
    /// 개별 비디오 파일의 상세 정보를 추출합니다.
    ///
    /// TODO - FFmpeg 구현 필요:
    /// 현재는 하드코딩된 기본값을 사용합니다:
    /// - 1920x1080 (Full HD)
    /// - 30fps
    /// - H.264 코덱
    /// - 60초 재생시간
    ///
    /// 향후 VideoDecoder를 사용하여 실제 값 추출:
    /// ```swift
    /// let decoder = VideoDecoder(filePath: filePath)
    /// try decoder.initialize()
    /// let videoInfo = decoder.videoInfo  // width, height, fps 등
    /// let duration = decoder.getDuration()
    /// ```
    ///
    /// 실패 사유:
    /// 1. 파일이 존재하지 않음
    /// 2. 읽기 권한 없음
    /// 3. FFmpeg 디코딩 실패 (향후)
    private func extractChannelInfo(from fileInfo: VideoFileInfo) -> ChannelInfo? {
        // 1. 파일 경로 가져오기
        // - url.path: URL을 String 경로로 변환
        // - 예: file:///path/to/video.mp4 → /path/to/video.mp4
        let filePath = fileInfo.url.path

        // 2. 파일 존재 확인
        // - guard: 조건 실패 시 early return
        // - FileManager: 파일 시스템 작업용 클래스
        // - .default: 싱글톤 인스턴스
        // - fileExists(atPath:): 파일/디렉토리 존재 여부
        guard FileManager.default.fileExists(atPath: filePath) else {
            // print: 콘솔에 경고 메시지 출력
            // - 디버깅용
            // - 프로덕션에서는 로깅 시스템 사용 권장
            print("Warning: File does not exist: \(filePath)")
            return nil  // ChannelInfo 생성 불가
        }

        // 3. 읽기 권한 확인
        // - isReadableFile(atPath:): 읽기 가능한지 확인
        // - 권한 없으면 디코딩 불가
        guard FileManager.default.isReadableFile(atPath: filePath) else {
            print("Warning: File is not readable: \(filePath)")
            return nil
        }

        // 4. TODO: FFmpeg 비디오 분석 구현 필요
        //
        // ┌────────────────────────────────────────────────────────────────┐
        // │ 향후 구현 계획                                                   │
        // ├────────────────────────────────────────────────────────────────┤
        // │                                                                │
        // │ let decoder = VideoDecoder(filePath: filePath)                 │
        // │ try decoder.initialize()                                       │
        // │                                                                │
        // │ guard let videoInfo = decoder.videoInfo else {                 │
        // │     return nil                                                 │
        // │ }                                                              │
        // │                                                                │
        // │ let width = Int(videoInfo.width)                               │
        // │ let height = Int(videoInfo.height)                             │
        // │ let frameRate = videoInfo.frameRate                            │
        // │ let codec = videoInfo.codecName                                │
        // │ let duration = decoder.getDuration() ?? 0                      │
        // │                                                                │
        // │ let audioInfo = decoder.audioInfo                              │
        // │ let audioCodec = audioInfo?.codecName                          │
        // │                                                                │
        // └────────────────────────────────────────────────────────────────┘

        // 5. 현재는 일반적인 블랙박스 스펙 기본값 사용
        // - 대부분의 블랙박스가 이 스펙 사용
        // - 실제 값과 다를 수 있지만 UI 표시는 가능
        let width = 1920                    // Full HD 가로
        let height = 1080                   // Full HD 세로
        let frameRate = 30.0                // 30 프레임/초
        let bitrate: Int? = nil             // 비트레이트 알 수 없음
        let codec = "h264"                  // H.264 코덱 (가장 일반적)
        let audioCodec: String? = "aac"     // AAC 오디오 코덱
        let duration: TimeInterval = 60.0   // 기본 1분 (실제와 다를 수 있음)

        // 6. ChannelInfo 생성 및 반환
        // - UUID(): 각 채널마다 고유 ID 생성
        // - fileInfo에서 가져온 값: position, fileSize
        // - 위에서 결정한 값: width, height, frameRate 등
        return ChannelInfo(
            id: UUID(),
            position: fileInfo.position,      // 카메라 위치 (front, rear 등)
            filePath: filePath,               // 비디오 파일 전체 경로
            width: width,                     // 비디오 가로 해상도
            height: height,                   // 비디오 세로 해상도
            frameRate: frameRate,             // 프레임 레이트 (fps)
            bitrate: bitrate,                 // 비트레이트 (bps) - optional
            codec: codec,                     // 비디오 코덱 이름
            audioCodec: audioCodec,           // 오디오 코덱 이름 - optional
            isEnabled: true,                  // 기본적으로 활성화
            fileSize: fileInfo.fileSize,      // 파일 크기 (bytes)
            duration: duration                // 재생 시간 (seconds)
        )
    }
}

// MARK: - VideoFile Extension

/*
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ Extension이란?                                                                │
 └──────────────────────────────────────────────────────────────────────────────┘

 Extension은 기존 타입에 새로운 기능을 추가하는 Swift의 강력한 기능입니다.

 특징:
 1. 원본 코드 수정 없이 기능 추가 가능
 2. struct, class, enum, protocol 모두 확장 가능
 3. 메서드, 계산 프로퍼티, initializer 추가 가능
 4. 저장 프로퍼티는 추가 불가 (제한사항)

 왜 여기서 Extension을 사용하나?
 - VideoFile은 Models 디렉토리에 정의됨
 - checkCorruption()은 로딩 시에만 필요 (Services 관련)
 - 로직적으로 분리하여 코드 구조 개선

 비교:
 ```swift
 // VideoFile 원본 (Models/VideoFile.swift)
 struct VideoFile {
     let id: UUID
     let timestamp: Date
     // ... 기본 프로퍼티만
 }

 // Extension으로 추가 (Services/VideoFileLoader.swift)
 extension VideoFile {
     func checkCorruption() -> Bool {
         // 로딩 관련 로직
     }
 }
 ```
 */

extension VideoFile {

    /// @brief 비디오 파일이 손상되었는지 확인
    ///
    /// @return true면 손상됨, false면 정상
    ///
    /// @details
    /// 다음 항목들을 검사합니다:
    /// 1. 모든 채널 파일이 존재하는지
    /// 2. 재생 시간이 유효한지 (> 0)
    /// 3. 모든 채널의 파일 크기가 0이 아닌지
    ///
    /// 검사 레벨:
    /// 이것은 기본적인 검사만 수행합니다.
    /// 더 깊은 검증 (코덱 확인, 프레임 디코딩 등)은
    /// 실제 재생 시도 시 수행됩니다.
    ///
    /// 손상 원인:
    /// 1. 녹화 중 전원 끊김 → 파일 불완전
    /// 2. SD 카드 손상 → 파일 읽기 불가
    /// 3. 파일 시스템 오류 → 메타데이터 손실
    /// 4. 수동 삭제 → 일부 채널만 남음
    ///
    /// UI 표시:
    /// ```swift
    /// if videoFile.isCorrupted {
    ///     Text(videoFile.name)
    ///         .foregroundColor(.red)
    ///     Image(systemName: "exclamationmark.triangle")
    ///         .foregroundColor(.orange)
    /// }
    /// ```
    func checkCorruption() -> Bool {
        // 1. 모든 채널 파일이 존재하는지 확인
        // - for-in: channels 배열 순회
        // - FileManager.default.fileExists: 파일 존재 확인
        // - !: 부정 (exists가 false면 true)
        // - return true: 하나라도 없으면 즉시 "손상됨" 반환
        for channel in channels {
            if !FileManager.default.fileExists(atPath: channel.filePath) {
                return true  // 파일 없음 = 손상
            }
        }

        // 2. 재생 시간 유효성 검사
        // - duration <= 0: 0초 이하는 비정상
        // - 원인: 파일 생성 실패, 메타데이터 손상
        if duration <= 0 {
            return true  // 잘못된 duration = 손상
        }

        // 3. 모든 채널의 파일 크기 확인
        //
        // allSatisfy 고차 함수:
        // - 배열의 모든 요소가 조건을 만족하는지 검사
        // - 클로저: { $0.fileSize == 0 }
        //   - $0: 각 channel (ChannelInfo)
        //   - .fileSize: 파일 크기 (bytes)
        //   - == 0: 크기가 0인지
        // - 결과: 모두 0이면 true, 하나라도 0이 아니면 false
        //
        // 예시:
        // ```swift
        // let sizes = [0, 0, 0]
        // sizes.allSatisfy { $0 == 0 }  // true (모두 0)
        //
        // let sizes = [0, 100, 0]
        // sizes.allSatisfy { $0 == 0 }  // false (100이 0이 아님)
        // ```
        //
        // 왜 이것이 손상 신호?
        // - 모든 채널이 0 bytes = 파일이 비어있음
        // - 녹화 실패 또는 파일 생성만 되고 데이터 기록 안 됨
        if channels.allSatisfy({ $0.fileSize == 0 }) {
            return true  // 모든 파일이 비어있음 = 손상
        }

        // 4. 모든 검사 통과 = 정상
        return false
    }
}

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                            추가 학습 자료                                       ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝

 1. Optional Chaining 완전 가이드:
 ```swift
 // 기본 Optional 처리
 if let first = channels.first {
     if let duration = first.duration {
         print(duration)
     }
 }

 // Optional Chaining으로 간결하게
 let duration = channels.first?.duration ?? 0
 //             └─────┬──────┘ └──┬──┘
 //                   │           └─ nil이면 0 사용
 //                   └─ first가 nil이면 전체가 nil
 ```

 2. 고차 함수 비교:
 ```swift
 let numbers = [1, 2, 3, 4, 5]

 // map: 모든 요소 변환
 numbers.map { $0 * 2 }           // [2, 4, 6, 8, 10]

 // filter: 조건 만족하는 요소만
 numbers.filter { $0 > 2 }        // [3, 4, 5]

 // reduce: 하나의 값으로 합산
 numbers.reduce(0, +)             // 15

 // compactMap: 변환 + nil 제거
 ["1", "2", "a"].compactMap { Int($0) }  // [1, 2]

 // allSatisfy: 모든 요소가 조건 만족?
 numbers.allSatisfy { $0 > 0 }    // true

 // contains: 특정 요소 포함?
 numbers.contains(3)              // true
 ```

 3. Guard vs If-Let:
 ```swift
 // guard: early return 패턴 (권장)
 guard let user = getUser() else {
     print("No user")
     return
 }
 // user 사용 가능 (스코프 전체)
 print(user.name)

 // if-let: 중첩 가능성
 if let user = getUser() {
     // user 사용 (if 블록 내에서만)
     print(user.name)
 } else {
     print("No user")
 }
 // user 사용 불가 (스코프 밖)
 ```

 4. FileManager 주요 메서드:
 ```swift
 let fm = FileManager.default

 // 존재 확인
 fm.fileExists(atPath: path)

 // 디렉토리인지 확인
 var isDirectory: ObjCBool = false
 fm.fileExists(atPath: path, isDirectory: &isDirectory)

 // 읽기/쓰기 권한
 fm.isReadableFile(atPath: path)
 fm.isWritableFile(atPath: path)

 // 파일 속성
 let attrs = try fm.attributesOfItem(atPath: path)
 let fileSize = attrs[.size] as? UInt64

 // 파일 생성/삭제
 fm.createFile(atPath: path, contents: data)
 try fm.removeItem(atPath: path)

 // 디렉토리 내용
 let contents = try fm.contentsOfDirectory(atPath: path)
 ```
 */
