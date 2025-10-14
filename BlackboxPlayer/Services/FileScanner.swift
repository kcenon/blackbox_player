/// @file FileScanner.swift
/// @brief Service for scanning and discovering dashcam video files
/// @author BlackboxPlayer Development Team
/// @details 블랙박스 SD 카드의 디렉토리를 재귀적으로 스캔하여 비디오 파일을 발견하고,
/// 멀티채널 그룹으로 조직화하는 서비스입니다.

/*
 ═══════════════════════════════════════════════════════════════════════════
 파일 스캐너 서비스
 ═══════════════════════════════════════════════════════════════════════════

 【이 파일의 목적】
 블랙박스 SD 카드의 디렉토리를 재귀적으로 스캔하여 비디오 파일을 발견하고,
 멀티채널 그룹으로 조직화합니다.

 【블랙박스 파일 구조】
 일반적인 블랙박스 SD 카드의 디렉토리 구조:

 ```
 /SD_CARD/
 ├── Normal/              ← 일반 녹화
 │   ├── 20240115_143025_F.mp4    (전방 카메라)
 │   ├── 20240115_143025_R.mp4    (후방 카메라)
 │   ├── 20240115_143125_F.mp4
 │   └── 20240115_143125_R.mp4
 ├── Event/               ← 이벤트 녹화 (충격 감지)
 │   ├── 20240115_150230_F.mp4
 │   └── 20240115_150230_R.mp4
 ├── Parking/             ← 주차 모드
 │   └── ...
 └── GPS/                 ← 별도 GPS 로그 (선택적)
 └── 20240115.nmea
 ```

 【스캔 프로세스】
 1. FileManager.enumerator로 재귀적 디렉토리 탐색
 2. 비디오 확장자 필터링 (.mp4, .mov, .avi, .mkv)
 3. 정규식으로 파일명 파싱 (날짜, 시간, 카메라 위치)
 4. VideoFileInfo 구조체 생성
 5. baseFilename으로 멀티채널 그룹화
 6. VideoFileGroup 배열 반환 (최신순 정렬)

 【멀티채널 그룹화】
 같은 시각에 녹화된 전방/후방 영상을 하나의 그룹으로 통합:

 입력 (개별 파일):
 - 20240115_143025_F.mp4  (전방)
 - 20240115_143025_R.mp4  (후방)
 - 20240115_143125_F.mp4  (전방)

 출력 (그룹):
 - Group 1: [Front, Rear]  (2024-01-15 14:30:25)
 - Group 2: [Front]        (2024-01-15 14:31:25)

 【통합 위치】
 - FileManagerService: 이 서비스를 사용하여 SD 카드 스캔
 - ContentView: 스캔 결과를 UI에 표시

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

/*
 ───────────────────────────────────────────────────────────────────────────
 FileScanner 클래스
 ───────────────────────────────────────────────────────────────────────────

 【역할】
 블랙박스 비디오 파일을 발견하고 조직화하는 중앙 서비스입니다.

 【주요 기능】
 1. 재귀적 디렉토리 스캔
 2. 파일명 패턴 매칭 (정규식)
 3. 메타데이터 추출 (날짜, 시간, 카메라 위치, 이벤트 타입)
 4. 멀티채널 그룹화
 5. 빠른 파일 카운트

 【사용 시나리오】

 시나리오 1: 기본 스캔
 ```swift
 let scanner = FileScanner()
 let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")

 do {
 let groups = try scanner.scanDirectory(sdCardURL)
 print("\(groups.count)개 녹화 그룹 발견")

 for group in groups {
 print("[\(group.timestamp)] \(group.channelCount)채널, \(group.totalFileSize) bytes")
 if group.hasChannel(.front) {
 print("  - 전방 카메라: \(group.file(for: .front)!.lastPathComponent)")
 }
 if group.hasChannel(.rear) {
 print("  - 후방 카메라: \(group.file(for: .rear)!.lastPathComponent)")
 }
 }
 } catch {
 print("스캔 실패: \(error)")
 }
 ```

 시나리오 2: 빠른 카운트
 ```swift
 let scanner = FileScanner()
 let count = scanner.countVideoFiles(in: sdCardURL)
 print("\(count)개 비디오 파일 발견")
 ```

 시나리오 3: 필터링
 ```swift
 let groups = try scanner.scanDirectory(sdCardURL)

 // 이벤트 녹화만 필터링
 let eventGroups = groups.filter { $0.eventType == .event }

 // 특정 날짜 필터링
 let calendar = Calendar.current
 let todayGroups = groups.filter {
 calendar.isDateInToday($0.timestamp)
 }

 // 2채널 녹화만 필터링
 let twoChannelGroups = groups.filter { $0.channelCount == 2 }
 ```

 【성능 특성】
 - 재귀 스캔: O(N) - N은 전체 파일 수
 - 파일명 파싱: O(M) - M은 비디오 파일 수
 - 그룹화: O(M log M) - 정렬 포함

 일반적인 SD 카드 (1000개 파일):
 - 스캔 시간: 약 100-200ms
 - 메모리 사용: 약 1-2 MB
 ───────────────────────────────────────────────────────────────────────────
 */

/// @class FileScanner
/// @brief 디렉토리를 스캔하여 블랙박스 비디오 파일을 발견하고 조직화하는 서비스
///
/// FileManager의 재귀적 enumerator를 사용하여 모든 하위 디렉토리를 탐색하고,
/// 정규식으로 파일명을 파싱하여 메타데이터를 추출합니다.
class FileScanner {
    // MARK: - Properties

    /*
     ───────────────────────────────────────────────────────────────────────
     지원하는 비디오 확장자
     ───────────────────────────────────────────────────────────────────────

     【Set 사용 이유】
     contains() 연산이 O(1)로 빠릅니다.

     Array를 사용하면:
     videoExtensions.contains("mp4")  // O(N) - 최악의 경우 모든 요소 확인

     Set을 사용하면:
     videoExtensions.contains("mp4")  // O(1) - 해시 테이블 조회

     【소문자로 저장】
     파일 확장자는 대소문자 구분 없이 매칭:
     - video.MP4 → "mp4" (lowercased)
     - video.Mp4 → "mp4"
     - video.mp4 → "mp4"

     【확장자 선택】
     - mp4: H.264/H.265, 블랙박스 표준
     - mov: QuickTime, 일부 고급 모델
     - avi: 오래된 형식, 레거시 지원
     - mkv: Matroska, 일부 제조사 사용
     ───────────────────────────────────────────────────────────────────────
     */

    /// @var videoExtensions
    /// @brief 지원하는 비디오 파일 확장자
    ///
    /// Set으로 저장하여 O(1) 시간에 포함 여부 확인 가능합니다.
    /// 모든 확장자는 소문자로 저장되어 대소문자 구분 없이 매칭됩니다.
    ///
    /// 지원 형식:
    /// - mp4: 가장 일반적인 블랙박스 형식
    /// - mov: QuickTime 형식 (일부 고급 모델)
    /// - avi: 레거시 형식 지원
    /// - mkv: Matroska 컨테이너
    private let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv"]

    /*
     ───────────────────────────────────────────────────────────────────────
     파일명 패턴 정규식
     ───────────────────────────────────────────────────────────────────────

     【정규식 패턴】
     #"^(\d{8})_(\d{6})_([FRLIi]+)\.(\w+)$"#

     구성 요소:
     - ^          : 문자열 시작
     - (\d{8})    : 그룹 1 - 8자리 숫자 (YYYYMMDD)
     - _          : 언더스코어
     - (\d{6})    : 그룹 2 - 6자리 숫자 (HHMMSS)
     - _          : 언더스코어
     - ([FRLIi]+) : 그룹 3 - 카메라 위치 코드 (1글자 이상)
     - \.         : 점 (이스케이프)
     - (\w+)      : 그룹 4 - 파일 확장자 (알파벳/숫자)
     - $          : 문자열 끝

     【매칭 예시】
     ✓ "20240115_143025_F.mp4"
     그룹 1: "20240115" (날짜)
     그룹 2: "143025" (시간)
     그룹 3: "F" (전방)
     그룹 4: "mp4" (확장자)

     ✓ "20240115_143025_RF.mp4"  (후방+전방 듀얼)
     그룹 3: "RF"

     ✗ "video.mp4"               (패턴 불일치)
     ✗ "2024_01_15_14_30_25.mp4" (구분자 다름)

     【카메라 위치 코드】
     - F: Front (전방)
     - R: Rear (후방)
     - L: Left (좌측)
     - I/i: Interior (실내)

     일부 제조사는 RF, FI 같은 조합 사용:
     - RF: Rear + Front
     - FI: Front + Interior

     【NSRegularExpression】
     Swift의 정규식 엔진입니다.
     컴파일한 정규식을 재사용하여 성능 향상:
     - 한 번 컴파일: init()에서
     - 여러 번 사용: parseVideoFile()에서
     ───────────────────────────────────────────────────────────────────────
     */

    /// @var filenamePattern
    /// @brief BlackVue 형식 파일명 패턴 (YYYYMMDD_HHMMSS_X.mp4)
    ///
    /// 정규식 패턴:
    /// - `(\d{8})`: 날짜 (YYYYMMDD)
    /// - `(\d{6})`: 시간 (HHMMSS)
    /// - `([FRLIi]+)`: 카메라 위치 (Front/Rear/Left/Interior)
    /// - `(\w+)`: 파일 확장자
    ///
    /// 매칭 예시:
    /// - "20240115_143025_F.mp4" → ✓ (전방 카메라)
    /// - "20240115_143025_R.mp4" → ✓ (후방 카메라)
    /// - "video.mp4" → ✗ (패턴 불일치)
    private let filenamePattern = #"^(\d{8})_(\d{6})_([FRLIi]+)\.(\w+)$"#

    /// @var filenameRegex
    /// @brief 컴파일된 정규식 객체
    ///
    /// init()에서 한 번 컴파일하여 재사용함으로써 성능 향상.
    /// 컴파일 실패 시 nil (패턴 오류).
    private let filenameRegex: NSRegularExpression?

    // MARK: - Initialization

    /*
     ───────────────────────────────────────────────────────────────────────
     초기화
     ───────────────────────────────────────────────────────────────────────

     【정규식 컴파일】
     NSRegularExpression(pattern:options:)는 throws하지만, try?로 변환:
     - 성공: filenameRegex에 저장
     - 실패: nil (패턴 오류) → parseVideoFile()에서 nil 반환

     정규식 컴파일 비용:
     - 한 번: 약 0.1ms
     - 매번: 약 0.1ms × N회 = 비효율적

     따라서 init()에서 한 번만 컴파일합니다.

     【options: []】
     정규식 옵션을 지정하지 않음:
     - .caseInsensitive: 대소문자 무시 (불필요 - 파일명은 보통 일관성 있음)
     - .anchorsMatchLines: ^ $ 를 줄 단위로 매칭 (불필요 - 전체 문자열 매칭)
     - .dotMatchesLineSeparators: . 이 개행 문자 매칭 (불필요)

     빈 배열 []은 기본 옵션 = 정확한 매칭만 수행.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief FileScanner 초기화
    ///
    /// 정규식 패턴을 컴파일하여 성능을 최적화합니다.
    /// 컴파일 실패 시 filenameRegex는 nil이 되며, 모든 파일이 스킵됩니다.
    init() {
        self.filenameRegex = try? NSRegularExpression(pattern: filenamePattern, options: [])
    }

    // MARK: - Public Methods

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 1: scanDirectory
     ───────────────────────────────────────────────────────────────────────

     【목적】
     디렉토리를 재귀적으로 스캔하여 모든 비디오 파일을 발견하고 그룹화합니다.

     【FileManager.enumerator】
     재귀적 디렉토리 탐색을 위한 Apple의 표준 API:

     ```swift
     let enumerator = fileManager.enumerator(
     at: directoryURL,
     includingPropertiesForKeys: [.isRegularFileKey, ...],
     options: [.skipsHiddenFiles]
     )
     ```

     동작:
     1. 디렉토리의 모든 항목 순회 (재귀적)
     2. includingPropertiesForKeys: 미리 로드할 속성 지정
     3. options: 숨김 파일 제외

     【includingPropertiesForKeys】
     파일 속성을 미리 로드하여 성능 향상:
     - .isRegularFileKey: 일반 파일 여부 (디렉토리/심볼릭 링크 제외)
     - .fileSizeKey: 파일 크기
     - .contentModificationDateKey: 수정 날짜

     미리 로드하지 않으면:
     - 각 파일마다 별도의 시스템 콜 필요
     - 성능 저하 (특히 많은 파일)

     【options: .skipsHiddenFiles】
     숨김 파일/디렉토리 제외:
     - .DS_Store (macOS 메타데이터)
     - .Trash (휴지통)
     - ._ 로 시작하는 파일 (macOS 리소스 포크)

     【반환 타입: [VideoFileGroup]】
     개별 파일이 아닌 그룹 단위로 반환:
     - 같은 시각의 전방/후방 영상을 하나의 그룹으로 통합
     - 최신순 정렬 (가장 최근 녹화가 먼저)

     【throws】
     디렉토리 접근 실패 시 오류 던짐:
     - directoryNotFound: 디렉토리 없음
     - cannotEnumerateDirectory: 권한 부족 등
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 디렉토리를 스캔하여 블랙박스 비디오 파일 발견
    ///
    /// FileManager.enumerator를 사용하여 재귀적으로 모든 하위 디렉토리를 탐색하고,
    /// 비디오 파일을 파싱하여 멀티채널 그룹으로 조직화합니다.
    ///
    /// @param directoryURL 스캔할 디렉토리의 URL
    /// @return VideoFileGroup 배열 (최신순 정렬)
    /// @throws FileScannerError
    ///   - .directoryNotFound: 디렉토리가 존재하지 않음
    ///   - .cannotEnumerateDirectory: 디렉토리 열기 실패
    ///
    /// 스캔 과정:
    /// 1. 디렉토리 존재 여부 확인
    /// 2. FileManager.enumerator로 재귀 탐색
    /// 3. 각 파일의 확장자 확인 (.mp4, .mov 등)
    /// 4. 정규식으로 파일명 파싱 (날짜, 시간, 카메라 위치)
    /// 5. VideoFileInfo 구조체 생성
    /// 6. baseFilename으로 그룹화
    /// 7. 최신순 정렬하여 반환
    ///
    /// 사용 예시:
    /// ```swift
    /// let scanner = FileScanner()
    /// let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")
    ///
    /// do {
    ///     let groups = try scanner.scanDirectory(sdCardURL)
    ///     print("\(groups.count)개 녹화 그룹 발견")
    ///
    ///     for group in groups {
    ///         print("[\(group.timestamp)]")
    ///         print("  채널: \(group.channelCount)")
    ///         print("  타입: \(group.eventType)")
    ///         print("  크기: \(group.totalFileSize) bytes")
    ///     }
    /// } catch FileScannerError.directoryNotFound(let path) {
    ///     print("디렉토리를 찾을 수 없습니다: \(path)")
    /// } catch {
    ///     print("스캔 실패: \(error)")
    /// }
    /// ```
    ///
    /// 성능:
    /// - 시간: O(N) - N은 전체 파일 수
    /// - 메모리: O(M) - M은 비디오 파일 수
    /// - 일반적인 SD 카드 (1000개 파일): 약 100-200ms
    func scanDirectory(_ directoryURL: URL) throws -> [VideoFileGroup] {
        let fileManager = FileManager.default

        // 1단계: 디렉토리 존재 확인
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            throw FileScannerError.directoryNotFound(directoryURL.path)
        }

        // 2단계: 재귀적 enumerator 생성
        // includingPropertiesForKeys: 미리 로드할 파일 속성
        //   - .isRegularFileKey: 일반 파일 여부 (디렉토리 제외)
        //   - .fileSizeKey: 파일 크기
        //   - .contentModificationDateKey: 수정 날짜
        // options: .skipsHiddenFiles - 숨김 파일 제외 (.DS_Store 등)
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw FileScannerError.cannotEnumerateDirectory(directoryURL.path)
        }

        var videoFiles: [VideoFileInfo] = []

        // 3단계: 모든 파일 순회
        for case let fileURL as URL in enumerator {
            // 3-1: 일반 파일인지 확인 (디렉토리, 심볼릭 링크 제외)
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }

            // 3-2: 비디오 확장자 확인
            // pathExtension: URL에서 확장자 추출 (예: "mp4")
            // lowercased(): 대소문자 구분 없이 매칭
            let fileExtension = fileURL.pathExtension.lowercased()
            guard videoExtensions.contains(fileExtension) else {
                continue
            }

            // 3-3: 파일명 파싱 및 VideoFileInfo 생성
            if let fileInfo = parseVideoFile(fileURL) {
                videoFiles.append(fileInfo)
            }
        }

        // 4단계: 멀티채널 그룹화
        // 같은 시각의 전방/후방 영상을 하나의 그룹으로 통합
        let groups = groupVideoFiles(videoFiles)

        return groups
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 2: countVideoFiles
     ───────────────────────────────────────────────────────────────────────

     【목적】
     파일명 파싱 없이 빠르게 비디오 파일 개수만 세기

     【사용 시나리오】
     1. 진행률 표시:
     "전체 파일 개수: 1000개"
     "스캔 중... (500/1000)"

     2. 빠른 확인:
     "SD 카드에 비디오 파일이 있나요?"

     3. 메모리 절약:
     개수만 필요하고 상세 정보는 불필요할 때

     【scanDirectory()와의 차이】
     scanDirectory():
     - 파일명 정규식 매칭
     - VideoFileInfo 생성
     - 그룹화
     - 메모리: O(M) - M은 비디오 파일 수
     - 시간: 약 100-200ms

     countVideoFiles():
     - 확장자만 확인
     - 메모리: O(1) - count 변수만
     - 시간: 약 50-100ms (2배 빠름)

     【반환 타입: Int】
     오류 발생 시 0 반환 (throws 아님):
     - 디렉토리 없음 → 0
     - 권한 부족 → 0
     - 파일 없음 → 0

     사용자 친화적 처리:
     ```swift
     let count = scanner.countVideoFiles(in: url)
     if count == 0 {
     print("비디오 파일을 찾을 수 없습니다")
     } else {
     print("\(count)개 파일 발견")
     }
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 디렉토리의 비디오 파일 개수를 빠르게 계산
    ///
    /// 파일명 파싱 없이 확장자만 확인하여 빠른 카운트를 수행합니다.
    /// scanDirectory()보다 약 2배 빠르며 메모리를 거의 사용하지 않습니다.
    ///
    /// @param directoryURL 스캔할 디렉토리의 URL
    /// @return 비디오 파일 개수, 오류 발생 시 0
    ///
    /// 사용 예시:
    /// ```swift
    /// let scanner = FileScanner()
    /// let count = scanner.countVideoFiles(in: sdCardURL)
    ///
    /// if count == 0 {
    ///     print("비디오 파일을 찾을 수 없습니다")
    /// } else {
    ///     print("\(count)개 파일 발견")
    ///     // 이제 전체 스캔 시작
    ///     let groups = try scanner.scanDirectory(sdCardURL)
    /// }
    /// ```
    ///
    /// 진행률 표시 예시:
    /// ```swift
    /// let totalCount = scanner.countVideoFiles(in: sdCardURL)
    /// var scannedCount = 0
    ///
    /// // 스캔하면서 진행률 업데이트
    /// for group in groups {
    ///     scannedCount += group.channelCount
    ///     let progress = Double(scannedCount) / Double(totalCount)
    ///     updateProgressBar(progress)
    /// }
    /// ```
    ///
    /// 참고:
    /// - 오류 발생 시 0 반환 (throws 아님)
    /// - 파일명 파싱 생략으로 scanDirectory()보다 빠름
    /// - 메모리 사용: O(1) - count 변수만
    func countVideoFiles(in directoryURL: URL) -> Int {
        let fileManager = FileManager.default

        // 디렉토리 존재 확인 및 enumerator 생성
        // 실패 시 0 반환 (guard 바인딩)
        guard fileManager.fileExists(atPath: directoryURL.path),
              let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return 0
        }

        var count = 0

        // 모든 파일 순회하며 비디오 확장자만 카운트
        for case let fileURL as URL in enumerator {
            let fileExtension = fileURL.pathExtension.lowercased()
            if videoExtensions.contains(fileExtension) {
                count += 1
            }
        }

        return count
    }

    // MARK: - Private Methods

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 3: parseVideoFile (Private)
     ───────────────────────────────────────────────────────────────────────

     【목적】
     비디오 파일 URL에서 메타데이터 추출

     【추출 정보】
     1. timestamp: 녹화 시작 시각 (Date)
     2. position: 카메라 위치 (CameraPosition enum)
     3. eventType: 이벤트 타입 (EventType enum)
     4. fileSize: 파일 크기 (UInt64)
     5. baseFilename: 기본 파일명 (그룹화용)

     【파일명 파싱 과정】
     입력: "20240115_143025_F.mp4"

     1. 정규식 매칭:
     그룹 1: "20240115" (날짜)
     그룹 2: "143025" (시간)
     그룹 3: "F" (카메라 위치)
     그룹 4: "mp4" (확장자)

     2. 타임스탬프 변환:
     "20240115143025" → Date(2024-01-15 14:30:25 +0900)

     3. 카메라 위치 감지:
     "F" → CameraPosition.front

     4. 이벤트 타입 감지:
     경로에서 "Event" 포함 → EventType.event

     5. 기본 파일명 생성:
     "20240115_143025" (카메라 위치 코드 제외)

     출력: VideoFileInfo(...)

     【DateFormatter】
     문자열 → Date 변환:
     ```swift
     let dateFormatter = DateFormatter()
     dateFormatter.dateFormat = "yyyyMMddHHmmss"
     dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
     let date = dateFormatter.date(from: "20240115143025")
     ```

     타임존 중요:
     - 블랙박스는 한국 시각으로 녹화
     - Asia/Seoul 지정하지 않으면 UTC로 해석
     - 시차 9시간 오류 발생

     【실패 케이스】
     - 정규식 불일치 → nil 반환
     - 날짜 형식 오류 → nil 반환
     - 패턴 매치하지만 유효하지 않은 날짜 → nil 반환
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 비디오 파일 URL에서 메타데이터 파싱
    ///
    /// 파일명을 정규식으로 분석하여 날짜, 시간, 카메라 위치 등을 추출합니다.
    ///
    /// @param fileURL 비디오 파일의 URL
    /// @return VideoFileInfo, 파싱 실패 시 nil
    ///
    /// 파싱 과정:
    /// 1. 파일명 추출 (lastPathComponent)
    /// 2. 정규식으로 패턴 매칭
    /// 3. 날짜/시간 문자열 → Date 변환
    /// 4. 카메라 위치 코드 → CameraPosition enum
    /// 5. 경로에서 이벤트 타입 감지
    /// 6. 파일 크기 조회
    /// 7. VideoFileInfo 구조체 생성
    ///
    /// 입력 예시:
    /// - "20240115_143025_F.mp4" → ✓ 파싱 성공
    /// - "video.mp4" → ✗ nil 반환 (패턴 불일치)
    ///
    /// 참고:
    /// - DateFormatter는 "Asia/Seoul" 타임존 사용
    /// - baseFilename은 카메라 위치 코드 제외 ("20240115_143025")
    /// - 파싱 실패 시 해당 파일은 무시됨
    private func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        let filename = fileURL.lastPathComponent
        let pathString = fileURL.path

        // 정규식 매칭 시도
        guard let regex = filenameRegex else { return nil }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range) else {
            // BlackVue 패턴이 아님 → 스킵
            return nil
        }

        // 캡처 그룹 개수 확인
        // numberOfRanges = 5: [전체, 날짜, 시간, 위치, 확장자]
        guard match.numberOfRanges == 5 else { return nil }

        // 캡처 그룹 추출
        // match.range(at: 0): 전체 매칭 문자열
        // match.range(at: 1): 날짜 (20240115)
        // match.range(at: 2): 시간 (143025)
        // match.range(at: 3): 카메라 위치 (F)
        // match.range(at: 4): 확장자 (mp4)
        let dateString = (filename as NSString).substring(with: match.range(at: 1))
        let timeString = (filename as NSString).substring(with: match.range(at: 2))
        let positionCode = (filename as NSString).substring(with: match.range(at: 3))
        let extensionString = (filename as NSString).substring(with: match.range(at: 4))

        // 타임스탬프 파싱
        // "20240115" + "143025" = "20240115143025"
        let timestampString = dateString + timeString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"  // YYYYMMDDHHMMSS
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")  // 한국 시간대

        guard let timestamp = dateFormatter.date(from: timestampString) else {
            // 날짜 형식 오류 → 스킵
            return nil
        }

        // 카메라 위치 감지
        // "F" → CameraPosition.front
        // "R" → CameraPosition.rear
        // "I" → CameraPosition.interior
        let position = CameraPosition.detect(from: positionCode)

        // 이벤트 타입 감지
        // 경로에서 "Event", "Parking", "Normal" 등 감지
        let eventType = EventType.detect(from: pathString)

        // 파일 크기 조회
        // FileManager.attributesOfItem으로 파일 속성 읽기
        // .size 키로 UInt64 값 추출
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: pathString)[.size] as? UInt64) ?? 0

        // 기본 파일명 생성 (카메라 위치 코드 제외)
        // "20240115_143025_F" → "20240115_143025"
        // 멀티채널 그룹화에 사용
        let baseFilename = "\(dateString)_\(timeString)"

        return VideoFileInfo(
            url: fileURL,
            timestamp: timestamp,
            position: position,
            eventType: eventType,
            fileSize: fileSize,
            baseFilename: baseFilename
        )
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 4: groupVideoFiles (Private)
     ───────────────────────────────────────────────────────────────────────

     【목적】
     개별 비디오 파일을 멀티채널 그룹으로 통합

     【그룹화 기준】
     - baseFilename: "20240115_143025" (시각)
     - eventType: .normal, .event, .parking

     같은 시각 + 같은 이벤트 타입 = 하나의 그룹

     【그룹화 예시】
     입력 (개별 파일):
     ```
     [
     VideoFileInfo(baseFilename: "20240115_143025", position: .front, eventType: .normal),
     VideoFileInfo(baseFilename: "20240115_143025", position: .rear, eventType: .normal),
     VideoFileInfo(baseFilename: "20240115_143125", position: .front, eventType: .event),
     ]
     ```

     Dictionary 그룹화:
     ```
     {
     "20240115_143025_normal": [Front, Rear],
     "20240115_143125_event": [Front]
     }
     ```

     출력 (그룹):
     ```
     [
     VideoFileGroup(files: [Front, Rear], timestamp: 2024-01-15 14:30:25),
     VideoFileGroup(files: [Front], timestamp: 2024-01-15 14:31:25)
     ]
     ```

     【정렬】
     1. 그룹 내 파일 정렬:
     displayPriority로 정렬 (Front → Rear → Left → Interior)

     2. 그룹 정렬:
     timestamp 내림차순 (최신순)

     【Dictionary 사용】
     ```swift
     var groups: [String: [VideoFileInfo]] = [:]
     let key = "\(file.baseFilename)_\(file.eventType.rawValue)"
     groups[key, default: []].append(file)
     ```

     또는:
     ```swift
     if groups[key] == nil {
     groups[key] = []
     }
     groups[key]?.append(file)
     ```

     【성능】
     - Dictionary 그룹화: O(N) - N은 파일 수
     - 정렬: O(M log M) - M은 그룹 수
     - 총: O(N + M log M)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 개별 비디오 파일을 멀티채널 그룹으로 통합
    ///
    /// 같은 시각(baseFilename)과 이벤트 타입의 파일들을 하나의 그룹으로 묶습니다.
    ///
    /// @param files VideoFileInfo 배열
    /// @return VideoFileGroup 배열 (최신순 정렬)
    ///
    /// 그룹화 과정:
    /// 1. baseFilename + eventType을 키로 Dictionary 생성
    /// 2. 같은 키의 파일들을 배열로 누적
    /// 3. 각 그룹 내에서 카메라 위치별로 정렬 (Front → Rear → ...)
    /// 4. 그룹을 timestamp 내림차순 정렬 (최신순)
    ///
    /// 예시:
    /// ```swift
    /// // 입력
    /// let files = [
    ///     VideoFileInfo(baseFilename: "20240115_143025", position: .front, ...),
    ///     VideoFileInfo(baseFilename: "20240115_143025", position: .rear, ...)
    /// ]
    ///
    /// // 그룹화
    /// let groups = groupVideoFiles(files)
    /// // groups[0].files = [Front, Rear]
    /// // groups[0].channelCount = 2
    /// ```
    ///
    /// 참고:
    /// - 그룹 내 파일은 displayPriority로 정렬
    /// - 그룹은 timestamp 내림차순 정렬 (최신이 먼저)
    private func groupVideoFiles(_ files: [VideoFileInfo]) -> [VideoFileGroup] {
        // 1단계: Dictionary로 그룹화
        // 키: "baseFilename_eventType" (예: "20240115_143025_normal")
        var groups: [String: [VideoFileInfo]] = [:]

        for file in files {
            let key = "\(file.baseFilename)_\(file.eventType.rawValue)"
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(file)
        }

        // 2단계: VideoFileGroup으로 변환
        return groups.values.map { groupFiles in
            // 2-1: 그룹 내 파일 정렬
            // displayPriority: Front(0) → Rear(1) → Left(2) → Interior(3)
            let sortedFiles = groupFiles.sorted { $0.position.displayPriority < $1.position.displayPriority }
            return VideoFileGroup(files: sortedFiles)
        }.sorted { $0.timestamp > $1.timestamp }  // 2-2: 그룹 최신순 정렬
    }
}

// MARK: - Supporting Types

/*
 ───────────────────────────────────────────────────────────────────────────
 VideoFileInfo 구조체
 ───────────────────────────────────────────────────────────────────────────

 【목적】
 개별 비디오 파일의 메타데이터를 담는 경량 구조체

 【필드 설명】
 - url: 파일의 URL (파일 열기용)
 - timestamp: 녹화 시작 시각 (정렬, 필터링용)
 - position: 카메라 위치 (전방/후방 구분)
 - eventType: 이벤트 타입 (일반/이벤트/주차)
 - fileSize: 파일 크기 (저장 공간 계산용)
 - baseFilename: 기본 파일명 (그룹화 키)

 【struct 사용 이유】
 - 값 타입: 복사 시 독립적
 - 가벼움: 참조 카운트 없음
 - 불변성: let으로 선언하여 안전성 보장

 【사용 시나리오】
 ```swift
 let fileInfo = VideoFileInfo(
 url: URL(fileURLWithPath: "/Videos/20240115_143025_F.mp4"),
 timestamp: Date(),
 position: .front,
 eventType: .normal,
 fileSize: 104857600,  // 100 MB
 baseFilename: "20240115_143025"
 )

 print(fileInfo.url.lastPathComponent)  // "20240115_143025_F.mp4"
 print(fileInfo.position)                // CameraPosition.front
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @struct VideoFileInfo
/// @brief 개별 비디오 파일의 정보
///
/// 파일명을 파싱하여 추출한 메타데이터를 담는 경량 구조체입니다.
/// 그룹화 전의 개별 파일 단위 정보를 표현합니다.
struct VideoFileInfo {
    /// @var url
    /// @brief 파일의 URL
    ///
    /// 파일을 열거나 메타데이터를 읽을 때 사용:
    /// ```swift
    /// let data = try Data(contentsOf: fileInfo.url)
    /// ```
    let url: URL

    /// @var timestamp
    /// @brief 녹화 시작 시각
    ///
    /// 파일명에서 추출한 날짜/시간:
    /// "20240115_143025_F.mp4" → Date(2024-01-15 14:30:25 +0900)
    ///
    /// 용도:
    /// - 파일 정렬 (최신순/오래된순)
    /// - 날짜 필터링 (오늘, 이번 주 등)
    /// - UI 표시 ("2024-01-15 14:30")
    let timestamp: Date

    /// @var position
    /// @brief 카메라 위치
    ///
    /// 파일명의 위치 코드에서 추출:
    /// - "F" → .front (전방)
    /// - "R" → .rear (후방)
    /// - "L" → .left (좌측)
    /// - "I" → .interior (실내)
    ///
    /// 용도:
    /// - 멀티채널 그룹화
    /// - UI에서 채널 선택
    let position: CameraPosition

    /// @var eventType
    /// @brief 이벤트 타입
    ///
    /// 파일 경로에서 감지:
    /// - "/Normal/" 포함 → .normal (일반 녹화)
    /// - "/Event/" 포함 → .event (충격 감지)
    /// - "/Parking/" 포함 → .parking (주차 모드)
    ///
    /// 용도:
    /// - 이벤트 필터링
    /// - UI 아이콘 표시 (⚠️ 이벤트)
    let eventType: EventType

    /// @var fileSize
    /// @brief 파일 크기 (바이트)
    ///
    /// FileManager.attributesOfItem에서 조회:
    /// ```swift
    /// let mb = Double(fileSize) / 1_000_000
    /// print(String(format: "%.1f MB", mb))
    /// ```
    ///
    /// 용도:
    /// - 저장 공간 계산
    /// - 전송 시간 예측
    /// - 대용량 파일 경고
    let fileSize: UInt64

    /// @var baseFilename
    /// @brief 기본 파일명 (카메라 위치 코드 제외)
    ///
    /// "20240115_143025_F.mp4" → "20240115_143025"
    ///
    /// 용도:
    /// - 멀티채널 그룹화 키
    /// - 같은 baseFilename = 같은 시각의 다른 채널
    ///
    /// 예시:
    /// - "20240115_143025_F.mp4" → baseFilename: "20240115_143025"
    /// - "20240115_143025_R.mp4" → baseFilename: "20240115_143025"
    /// → 같은 그룹으로 묶임
    let baseFilename: String
}

/*
 ───────────────────────────────────────────────────────────────────────────
 VideoFileGroup 구조체
 ───────────────────────────────────────────────────────────────────────────

 【목적】
 같은 시각에 녹화된 멀티채널 비디오 파일의 그룹

 【구조】
 ```
 VideoFileGroup
 ├── files: [VideoFileInfo]
 │   ├── Front camera
 │   └── Rear camera
 ├── timestamp: Date (첫 번째 파일의 시각)
 ├── eventType: EventType (그룹의 이벤트 타입)
 └── channelCount: Int (채널 수: 1 or 2)
 ```

 【Computed Properties】
 저장하지 않고 필요할 때 계산:
 - timestamp: files[0].timestamp
 - eventType: files[0].eventType
 - baseFilename: files[0].baseFilename
 - basePath: files[0]의 디렉토리 경로
 - channelCount: files.count
 - totalFileSize: 모든 파일 크기의 합

 이점:
 - 메모리 절약
 - 자동 업데이트 (files 변경 시)
 - 일관성 보장

 【메서드】
 - file(for:): 특정 위치의 파일 URL 조회
 - hasChannel(_:): 특정 위치의 채널 존재 여부

 【사용 예시】
 ```swift
 let group = VideoFileGroup(files: [frontFile, rearFile])

 print(group.timestamp)           // 2024-01-15 14:30:25
 print(group.channelCount)        // 2
 print(group.totalFileSize)       // 200000000 (200 MB)

 if let frontURL = group.file(for: .front) {
 print(frontURL.lastPathComponent)  // "20240115_143025_F.mp4"
 }

 if group.hasChannel(.rear) {
 print("후방 카메라 녹화 있음")
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @struct VideoFileGroup
/// @brief 같은 시각에 녹화된 멀티채널 비디오 파일의 그룹
///
/// 전방/후방 카메라가 동시에 녹화한 파일들을 하나의 그룹으로 표현합니다.
struct VideoFileGroup {
    /// @var files
    /// @brief 그룹에 속한 비디오 파일들
    ///
    /// 정렬 순서: displayPriority (Front → Rear → Left → Interior)
    ///
    /// 일반적인 구성:
    /// - 1채널: [Front]
    /// - 2채널: [Front, Rear]
    /// - 3채널: [Front, Rear, Interior] (고급 모델)
    let files: [VideoFileInfo]

    /*
     ───────────────────────────────────────────────────────────────────────
     Computed Properties
     ───────────────────────────────────────────────────────────────────────

     저장하지 않고 필요할 때 계산하는 속성들입니다.

     장점:
     1. 메모리 절약: 값을 저장하지 않음
     2. 자동 업데이트: files가 변경되면 자동 반영
     3. 일관성: files와 항상 동기화

     단점:
     1. 계산 비용: 매번 호출 시 계산

     그러나 여기서는 단순 조회 작업이므로 비용이 거의 없습니다.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @var timestamp
    /// @brief 녹화 시작 시각
    ///
    /// 그룹의 첫 번째 파일 시각을 반환합니다.
    /// 모든 파일은 같은 시각이므로 첫 번째 파일만 확인.
    ///
    /// files가 비어 있으면 현재 시각 반환 (방어 코드).
    var timestamp: Date {
        return files.first?.timestamp ?? Date()
    }

    /// @var eventType
    /// @brief 이벤트 타입
    ///
    /// 그룹의 첫 번째 파일 이벤트 타입을 반환합니다.
    /// 모든 파일은 같은 이벤트 타입이므로 첫 번째 파일만 확인.
    ///
    /// files가 비어 있으면 .unknown 반환.
    var eventType: EventType {
        return files.first?.eventType ?? .unknown
    }

    /// @var baseFilename
    /// @brief 기본 파일명
    ///
    /// 그룹의 첫 번째 파일 baseFilename을 반환합니다.
    /// 예: "20240115_143025"
    var baseFilename: String {
        return files.first?.baseFilename ?? ""
    }

    /// @var basePath
    /// @brief 기본 경로 (디렉토리 경로)
    ///
    /// 그룹의 첫 번째 파일이 위치한 디렉토리 경로를 반환합니다.
    ///
    /// 예시:
    /// - 파일: "/Volumes/SD/Normal/20240115_143025_F.mp4"
    /// - basePath: "/Volumes/SD/Normal"
    ///
    /// 용도:
    /// - 같은 디렉토리의 다른 파일 접근
    /// - 경로 표시
    var basePath: String {
        guard let firstFile = files.first else { return "" }
        return firstFile.url.deletingLastPathComponent().path
    }

    /// @var channelCount
    /// @brief 채널 수
    ///
    /// 그룹에 포함된 비디오 파일 개수를 반환합니다.
    ///
    /// 일반적인 값:
    /// - 1: 단일 채널 (전방만)
    /// - 2: 듀얼 채널 (전방 + 후방)
    /// - 3: 트리플 채널 (전방 + 후방 + 실내)
    ///
    /// 용도:
    /// - UI 레이아웃 결정 (1채널: 전체 화면, 2채널: 분할 화면)
    /// - 필터링 (2채널 녹화만 보기)
    var channelCount: Int {
        return files.count
    }

    /// @var totalFileSize
    /// @brief 전체 파일 크기 (바이트)
    ///
    /// 그룹의 모든 파일 크기를 합산합니다.
    ///
    /// 계산:
    /// totalFileSize = file1.size + file2.size + ...
    ///
    /// 예시:
    /// - Front: 100 MB
    /// - Rear: 80 MB
    /// - Total: 180 MB
    ///
    /// 용도:
    /// - 저장 공간 계산
    /// - 전송 시간 예측
    /// - 대용량 그룹 경고
    ///
    /// reduce 사용:
    /// ```swift
    /// [100, 80, 50].reduce(0, +)  // 230
    /// [100, 80, 50].reduce(0) { $0 + $1 }  // 230
    /// ```
    var totalFileSize: UInt64 {
        return files.reduce(0) { $0 + $1.fileSize }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드
     ───────────────────────────────────────────────────────────────────────

     특정 카메라 위치의 파일을 조회하는 헬퍼 메서드들입니다.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 특정 카메라 위치의 파일 URL 조회
    ///
    /// @param position 조회할 카메라 위치
    /// @return 해당 위치의 파일 URL, 없으면 nil
    ///
    /// 사용 예시:
    /// ```swift
    /// let group = VideoFileGroup(files: [frontFile, rearFile])
    ///
    /// if let frontURL = group.file(for: .front) {
    ///     print("전방 카메라: \(frontURL.lastPathComponent)")
    ///     // 전방 비디오 재생
    /// }
    ///
    /// if let rearURL = group.file(for: .rear) {
    ///     print("후방 카메라: \(rearURL.lastPathComponent)")
    ///     // 후방 비디오 재생
    /// } else {
    ///     print("후방 카메라 없음")
    /// }
    /// ```
    ///
    /// 내부 동작:
    /// files 배열에서 position이 일치하는 첫 번째 파일의 URL 반환:
    /// ```swift
    /// files.first { $0.position == position }?.url
    /// ```
    func file(for position: CameraPosition) -> URL? {
        return files.first { $0.position == position }?.url
    }

    /// @brief 특정 카메라 위치의 채널 존재 여부 확인
    ///
    /// @param position 확인할 카메라 위치
    /// @return 해당 위치의 파일이 있으면 true
    ///
    /// 사용 예시:
    /// ```swift
    /// let group = VideoFileGroup(files: [frontFile])
    ///
    /// if group.hasChannel(.front) {
    ///     print("✓ 전방 카메라")
    /// }
    ///
    /// if group.hasChannel(.rear) {
    ///     print("✓ 후방 카메라")
    /// } else {
    ///     print("✗ 후방 카메라 없음")
    /// }
    ///
    /// // UI 버튼 활성화/비활성화
    /// rearButton.isEnabled = group.hasChannel(.rear)
    /// ```
    ///
    /// 내부 동작:
    /// files 배열에 position이 일치하는 파일이 있는지 확인:
    /// ```swift
    /// files.contains { $0.position == position }
    /// ```
    func hasChannel(_ position: CameraPosition) -> Bool {
        return files.contains { $0.position == position }
    }
}

/*
 ───────────────────────────────────────────────────────────────────────────
 FileScannerError 열거형
 ───────────────────────────────────────────────────────────────────────────

 【오류 종류】
 1. directoryNotFound: 디렉토리가 존재하지 않음
 2. cannotEnumerateDirectory: 디렉토리 열기 실패 (권한 부족 등)
 3. invalidPath: 잘못된 경로 (향후 확장용)

 【LocalizedError 프로토콜】
 사용자 친화적인 오류 메시지 제공:
 ```swift
 do {
 let groups = try scanner.scanDirectory(url)
 } catch {
 print(error.localizedDescription)  // "Directory not found: /path"
 }
 ```

 【사용 패턴】
 ```swift
 do {
 let groups = try scanner.scanDirectory(sdCardURL)
 // 성공 처리
 } catch FileScannerError.directoryNotFound(let path) {
 showAlert("디렉토리를 찾을 수 없습니다: \(path)")
 } catch FileScannerError.cannotEnumerateDirectory(let path) {
 showAlert("디렉토리를 읽을 수 없습니다: \(path)")
 } catch {
 showAlert("알 수 없는 오류: \(error)")
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @enum FileScannerError
/// @brief 파일 스캔 중 발생할 수 있는 오류
enum FileScannerError: Error {
    /// @brief 디렉토리가 존재하지 않음
    ///
    /// 발생 시나리오:
    /// - SD 카드가 마운트되지 않음
    /// - 경로 오타
    /// - SD 카드가 제거됨
    ///
    /// 복구 방법:
    /// 1. SD 카드 재삽입
    /// 2. 경로 확인
    /// 3. 다른 경로 시도
    case directoryNotFound(String)

    /// @brief 디렉토리 열기 실패
    ///
    /// 발생 시나리오:
    /// - 읽기 권한 부족
    /// - 디스크 I/O 오류
    /// - 파일시스템 손상
    ///
    /// 복구 방법:
    /// 1. 권한 확인 (chmod)
    /// 2. 디스크 검사
    /// 3. SD 카드 교체
    case cannotEnumerateDirectory(String)

    /// @brief 잘못된 경로
    ///
    /// 향후 확장을 위한 예약 오류.
    /// 현재는 사용되지 않음.
    case invalidPath(String)
}

extension FileScannerError: LocalizedError {
    /// @brief 사용자에게 표시할 오류 메시지
    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .cannotEnumerateDirectory(let path):
            return "Cannot enumerate directory: \(path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 가이드
 ═══════════════════════════════════════════════════════════════════════════

 【1. 기본 사용법】

 ```swift
 let scanner = FileScanner()
 let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")

 do {
 let groups = try scanner.scanDirectory(sdCardURL)
 print("\(groups.count)개 녹화 그룹 발견")

 for group in groups {
 let dateFormatter = DateFormatter()
 dateFormatter.dateStyle = .short
 dateFormatter.timeStyle = .short

 print("[\(dateFormatter.string(from: group.timestamp))]")
 print("  채널: \(group.channelCount)")
 print("  타입: \(group.eventType)")
 print("  크기: \(group.totalFileSize / 1_000_000) MB")

 if let frontURL = group.file(for: .front) {
 print("  전방: \(frontURL.lastPathComponent)")
 }
 if let rearURL = group.file(for: .rear) {
 print("  후방: \(rearURL.lastPathComponent)")
 }
 print()
 }
 } catch {
 print("스캔 실패: \(error.localizedDescription)")
 }
 ```

 【2. 필터링 예시】

 ```swift
 let groups = try scanner.scanDirectory(sdCardURL)

 // 이벤트 녹화만 필터링
 let eventGroups = groups.filter { $0.eventType == .event }
 print("이벤트 녹화: \(eventGroups.count)개")

 // 오늘 녹화만 필터링
 let calendar = Calendar.current
 let todayGroups = groups.filter {
 calendar.isDateInToday($0.timestamp)
 }
 print("오늘 녹화: \(todayGroups.count)개")

 // 특정 날짜 범위 필터링
 let startDate = Date(timeIntervalSinceNow: -7 * 24 * 3600)  // 7일 전
 let recentGroups = groups.filter {
 $0.timestamp > startDate
 }
 print("최근 7일: \(recentGroups.count)개")

 // 2채널 녹화만 필터링
 let dualChannelGroups = groups.filter { $0.channelCount == 2 }
 print("2채널 녹화: \(dualChannelGroups.count)개")

 // 대용량 파일 필터링 (100 MB 이상)
 let largeGroups = groups.filter { $0.totalFileSize > 100_000_000 }
 print("대용량 녹화: \(largeGroups.count)개")
 ```

 【3. 진행률 표시】

 ```swift
 @MainActor
 class ScanViewModel: ObservableObject {
 @Published var progress: Double = 0.0
 @Published var statusMessage: String = ""
 @Published var groups: [VideoFileGroup] = []

 func scanDirectory(_ url: URL) async {
 let scanner = FileScanner()

 // 1단계: 빠른 카운트
 statusMessage = "파일 개수 확인 중..."
 let totalCount = await Task.detached {
 scanner.countVideoFiles(in: url)
 }.value

 if totalCount == 0 {
 statusMessage = "비디오 파일을 찾을 수 없습니다"
 return
 }

 statusMessage = "\(totalCount)개 파일 스캔 중..."
 progress = 0.0

 // 2단계: 전체 스캔
 do {
 groups = try await Task.detached {
 try scanner.scanDirectory(url)
 }.value

 statusMessage = "스캔 완료: \(groups.count)개 녹화"
 progress = 1.0
 } catch {
 statusMessage = "스캔 실패: \(error.localizedDescription)"
 }
 }
 }

 // SwiftUI에서 사용
 struct ScanView: View {
 @StateObject private var viewModel = ScanViewModel()

 var body: some View {
 VStack {
 Text(viewModel.statusMessage)
 ProgressView(value: viewModel.progress)
 Button("스캔 시작") {
 Task {
 await viewModel.scanDirectory(sdCardURL)
 }
 }
 }
 }
 }
 ```

 【4. SwiftUI 리스트 통합】

 ```swift
 struct VideoListView: View {
 let groups: [VideoFileGroup]

 var body: some View {
 List(groups, id: \.baseFilename) { group in
 VideoGroupRow(group: group)
 }
 }
 }

 struct VideoGroupRow: View {
 let group: VideoFileGroup

 var body: some View {
 HStack {
 // 이벤트 아이콘
 if group.eventType == .event {
 Image(systemName: "exclamationmark.triangle.fill")
 .foregroundColor(.red)
 }

 VStack(alignment: .leading) {
 // 날짜/시간
 Text(group.timestamp, style: .date)
 Text(group.timestamp, style: .time)
 .font(.caption)
 .foregroundColor(.secondary)
 }

 Spacer()

 // 채널 표시
 HStack(spacing: 4) {
 if group.hasChannel(.front) {
 Image(systemName: "camera.fill")
 }
 if group.hasChannel(.rear) {
 Image(systemName: "camera.fill")
 .rotationEffect(.degrees(180))
 }
 }

 // 파일 크기
 Text(formatFileSize(group.totalFileSize))
 .font(.caption)
 .foregroundColor(.secondary)
 }
 }

 func formatFileSize(_ bytes: UInt64) -> String {
 let mb = Double(bytes) / 1_000_000
 return String(format: "%.1f MB", mb)
 }
 }
 ```

 【5. 오류 처리 패턴】

 ```swift
 func handleScan(_ url: URL) {
 let scanner = FileScanner()

 do {
 let groups = try scanner.scanDirectory(url)

 if groups.isEmpty {
 showWarning("비디오 파일을 찾을 수 없습니다")
 } else {
 showSuccess("\(groups.count)개 녹화 발견")
 displayGroups(groups)
 }

 } catch FileScannerError.directoryNotFound(let path) {
 showAlert(
 title: "디렉토리를 찾을 수 없습니다",
 message: "경로: \(path)\n\nSD 카드가 마운트되었는지 확인하세요."
 )

 } catch FileScannerError.cannotEnumerateDirectory(let path) {
 showAlert(
 title: "디렉토리를 읽을 수 없습니다",
 message: "경로: \(path)\n\n읽기 권한을 확인하세요."
 )

 } catch {
 showAlert(
 title: "스캔 실패",
 message: error.localizedDescription
 )
 }
 }
 ```

 【6. 테스트 코드】

 ```swift
 class FileScannerTests: XCTestCase {
 var scanner: FileScanner!
 var testURL: URL!

 override func setUp() {
 scanner = FileScanner()
 testURL = createTestDirectory()
 }

 func testScanDirectory() throws {
 // 테스트 파일 생성
 createTestFile("20240115_143025_F.mp4")
 createTestFile("20240115_143025_R.mp4")
 createTestFile("20240115_143125_F.mp4")

 // 스캔
 let groups = try scanner.scanDirectory(testURL)

 // 검증
 XCTAssertEqual(groups.count, 2)
 XCTAssertEqual(groups[0].channelCount, 2)  // 전방 + 후방
 XCTAssertEqual(groups[1].channelCount, 1)  // 전방만
 }

 func testCountVideoFiles() {
 createTestFile("20240115_143025_F.mp4")
 createTestFile("20240115_143025_R.mp4")
 createTestFile("README.txt")  // 비비디오 파일

 let count = scanner.countVideoFiles(in: testURL)
 XCTAssertEqual(count, 2)  // 비디오 파일만 카운트
 }

 func testDirectoryNotFound() {
 let invalidURL = URL(fileURLWithPath: "/nonexistent")
 XCTAssertThrowsError(try scanner.scanDirectory(invalidURL)) { error in
 XCTAssertTrue(error is FileScannerError)
 }
 }
 }
 ```

 ═══════════════════════════════════════════════════════════════════════════
 */
