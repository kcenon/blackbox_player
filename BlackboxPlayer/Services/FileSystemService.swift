/// @file FileSystemService.swift
/// @brief Service for accessing files on SD card file system
/// @author BlackboxPlayer Development Team
/// @details SD 카드의 파일 시스템에 접근하여 파일을 읽고, 정보를 조회하고, 삭제하는 서비스입니다.

/*
 ═══════════════════════════════════════════════════════════════════════════
 파일 시스템 서비스
 ═══════════════════════════════════════════════════════════════════════════

 【이 파일의 목적】
 macOS의 FileManager를 사용하여 SD 카드의 파일 시스템에 안전하게 접근합니다.
 모든 파일 I/O 작업의 기반이 되는 하위 레벨 서비스입니다.

 【주요 기능】
 1. 비디오 파일 목록 조회 (listVideoFiles)
 2. 파일 읽기 (readFile)
 3. 파일 정보 조회 (getFileInfo)
 4. 파일 삭제 (deleteFiles)

 【설계 원칙】
 - Native API 사용: macOS FileManager로 APFS/FAT32/exFAT 지원
 - 에러 처리: throws로 명시적 오류 전파
 - 타입 안전성: FileSystemError enum으로 구체적인 오류 정보 제공
 - 테스트 용이성: protocol 기반 설계로 mock 가능

 【통합 위치】
 - FileScanner: 파일 목록 조회에 사용 가능
 - FileManagerService: 메타데이터 관리 시 파일 접근
 - VideoFileLoader: 비디오 파일 읽기

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

// MARK: - File System Error

/*
 ───────────────────────────────────────────────────────────────────────────
 FileSystemError 열거형
 ───────────────────────────────────────────────────────────────────────────

 【오류 종류】
 - accessDenied: 파일 접근 권한 없음
 - readFailed: 파일 읽기 실패
 - writeFailed: 파일 쓰기/삭제 실패
 - listFailed: 디렉토리 목록 조회 실패
 - deviceNotFound: SD 카드 장치를 찾을 수 없음
 - permissionDenied: macOS 샌드박스 권한 거부
 - fileNotFound: 파일이 존재하지 않음

 【Associated Values】
 String 타입의 추가 정보를 포함하여 디버깅을 용이하게 합니다.

 예:
 - .readFailed("Permission denied")
 - .listFailed("Directory does not exist")

 【LocalizedError】
 사용자에게 표시할 수 있는 친화적인 메시지 제공
 ───────────────────────────────────────────────────────────────────────────
 */

/// @enum FileSystemError
/// @brief 파일 시스템 작업 중 발생할 수 있는 오류
enum FileSystemError: Error {
    /// @brief 파일 접근 권한 없음
    ///
    /// 발생 시나리오:
    /// - macOS 샌드박스 권한 부족
    /// - 파일 시스템 권한 설정 문제
    /// - SD 카드가 읽기 전용으로 마운트됨
    case accessDenied

    /// @brief 파일 읽기 실패
    ///
    /// Associated value로 실패 원인 포함:
    /// ```swift
    /// throw FileSystemError.readFailed("File is corrupted")
    /// ```
    case readFailed(String)

    /// @brief 파일 쓰기 또는 삭제 실패
    ///
    /// 발생 시나리오:
    /// - 디스크 공간 부족
    /// - 파일이 다른 프로세스에 의해 잠김
    /// - 읽기 전용 파일 시스템
    case writeFailed(String)

    /// @brief 디렉토리 목록 조회 실패
    ///
    /// 발생 시나리오:
    /// - 디렉토리가 존재하지 않음
    /// - 디렉토리 읽기 권한 없음
    case listFailed(String)

    /// @brief SD 카드 장치를 찾을 수 없음
    ///
    /// 발생 시나리오:
    /// - SD 카드가 연결되지 않음
    /// - SD 카드가 마운트되지 않음
    case deviceNotFound

    /// @brief 권한 거부됨
    ///
    /// 발생 시나리오:
    /// - 사용자가 파일 접근을 거부함
    /// - 샌드박스 entitlements 누락
    case permissionDenied

    /// @brief 파일이 존재하지 않음
    ///
    /// 발생 시나리오:
    /// - 파일이 삭제됨
    /// - 경로가 잘못됨
    /// - SD 카드가 언마운트됨
    case fileNotFound
}

extension FileSystemError: LocalizedError {
    /// @brief 사용자에게 표시할 오류 메시지
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied. Please check file permissions."
        case .readFailed(let reason):
            return "Failed to read file: \(reason)"
        case .writeFailed(let reason):
            return "Failed to write file: \(reason)"
        case .listFailed(let reason):
            return "Failed to list directory: \(reason)"
        case .deviceNotFound:
            return "SD card device not found. Please insert SD card."
        case .permissionDenied:
            return "Permission denied. Please grant file access in System Preferences."
        case .fileNotFound:
            return "File not found."
        }
    }
}

// MARK: - File Info

/*
 ───────────────────────────────────────────────────────────────────────────
 FileInfo 구조체
 ───────────────────────────────────────────────────────────────────────────

 【목적】
 파일의 메타데이터를 담는 경량 구조체

 【필드 설명】
 - name: 파일명 (예: "video.mp4")
 - size: 파일 크기 (바이트)
 - isDirectory: 디렉토리 여부
 - path: 절대 경로
 - creationDate: 생성 날짜
 - modificationDate: 수정 날짜

 【사용 시나리오】
 ```swift
 let fileInfo = try fileSystemService.getFileInfo(at: url)
 print("파일: \(fileInfo.name)")
 print("크기: \(fileInfo.size) bytes")
 print("생성일: \(fileInfo.creationDate)")
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @struct FileInfo
/// @brief 파일의 메타데이터 정보
struct FileInfo {
    /// @var name
    /// @brief 파일명 (확장자 포함)
    let name: String

    /// @var size
    /// @brief 파일 크기 (바이트)
    let size: Int64

    /// @var isDirectory
    /// @brief 디렉토리 여부
    let isDirectory: Bool

    /// @var path
    /// @brief 파일의 절대 경로
    let path: String

    /// @var creationDate
    /// @brief 파일 생성 날짜 (없을 수 있음)
    let creationDate: Date?

    /// @var modificationDate
    /// @brief 파일 수정 날짜 (없을 수 있음)
    let modificationDate: Date?
}

// MARK: - File System Service

/*
 ───────────────────────────────────────────────────────────────────────────
 FileSystemService 클래스
 ───────────────────────────────────────────────────────────────────────────

 【역할】
 macOS FileManager를 래핑하여 안전한 파일 시스템 접근을 제공합니다.

 【주요 메서드】
 1. listVideoFiles(at:) - 비디오 파일 목록 조회
 2. readFile(at:) - 파일 내용 읽기
 3. getFileInfo(at:) - 파일 메타데이터 조회
 4. deleteFiles(_:) - 파일 삭제

 【스레드 안전성】
 FileManager.default는 스레드 안전하지 않으므로,
 각 인스턴스가 독립적인 FileManager를 갖습니다.

 【테스트】
 protocol로 추출하여 mock 가능하게 설계:
 ```swift
 protocol FileSystemServiceProtocol {
     func listVideoFiles(at url: URL) throws -> [URL]
     // ...
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @class FileSystemService
/// @brief SD 카드 파일 시스템 접근 서비스
///
/// macOS의 FileManager를 사용하여 FAT32/exFAT/APFS 파일 시스템에 접근합니다.
/// 모든 파일 I/O 작업의 기반이 되는 하위 레벨 서비스입니다.
class FileSystemService {
    // MARK: - Properties

    /// @var fileManager
    /// @brief FileManager 인스턴스
    ///
    /// 스레드 안전성을 위해 인스턴스마다 독립적인 FileManager 사용.
    /// FileManager.default는 스레드 안전하지 않으므로 주의 필요.
    private let fileManager: FileManager

    /// @var supportedVideoExtensions
    /// @brief 지원하는 비디오 파일 확장자
    ///
    /// Set으로 저장하여 O(1) 시간에 포함 여부 확인.
    /// 블랙박스에서 일반적으로 사용하는 형식:
    /// - mp4: H.264/H.265, 가장 일반적
    /// - h264: Raw H.264 스트림
    /// - avi: 레거시 형식
    private let supportedVideoExtensions: Set<String> = ["mp4", "h264", "avi"]

    // MARK: - Initialization

    /*
     ───────────────────────────────────────────────────────────────────────
     초기화
     ───────────────────────────────────────────────────────────────────────

     【Dependency Injection】
     FileManager를 주입 받아 테스트 용이성 향상:

     프로덕션:
     ```swift
     let service = FileSystemService()  // FileManager.default 사용
     ```

     테스트:
     ```swift
     let mockFileManager = MockFileManager()
     let service = FileSystemService(fileManager: mockFileManager)
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief FileSystemService 초기화
    ///
    /// @param fileManager FileManager 인스턴스 (기본값: FileManager.default)
    ///
    /// 사용 예시:
    /// ```swift
    /// // 기본 사용
    /// let service = FileSystemService()
    ///
    /// // 테스트용 mock 주입
    /// let service = FileSystemService(fileManager: mockFileManager)
    /// ```
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Public Methods

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 1: listVideoFiles
     ───────────────────────────────────────────────────────────────────────

     【목적】
     디렉토리에서 비디오 파일 목록을 조회합니다.

     【알고리즘】
     1. 디렉토리 존재 확인
     2. FileManager.enumerator로 재귀 탐색
     3. 일반 파일만 필터링 (디렉토리, 심볼릭 링크 제외)
     4. 비디오 확장자만 필터링 (.mp4, .h264, .avi)
     5. URL 배열 반환

     【enumerator 옵션】
     - includingPropertiesForKeys: 미리 로드할 속성 (성능 향상)
       - .isRegularFileKey: 일반 파일 여부
       - .fileSizeKey: 파일 크기
       - .creationDateKey: 생성 날짜
     - options:
       - .skipsHiddenFiles: 숨김 파일 제외 (.DS_Store 등)

     【성능】
     - 시간 복잡도: O(N) - N은 디렉토리의 전체 파일 수
     - 공간 복잡도: O(M) - M은 비디오 파일 수
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 디렉토리의 비디오 파일 목록 조회
    ///
    /// 디렉토리를 재귀적으로 탐색하여 비디오 파일(.mp4, .h264, .avi)만 반환합니다.
    ///
    /// @param url 스캔할 디렉토리의 URL
    /// @return 비디오 파일 URL 배열
    /// @throws FileSystemError
    ///   - .fileNotFound: 디렉토리가 존재하지 않음
    ///   - .accessDenied: 디렉토리 접근 권한 없음
    ///
    /// 사용 예시:
    /// ```swift
    /// let service = FileSystemService()
    /// let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")
    ///
    /// do {
    ///     let videoFiles = try service.listVideoFiles(at: sdCardURL)
    ///     print("\(videoFiles.count)개 비디오 파일 발견")
    ///
    ///     for videoURL in videoFiles {
    ///         print(videoURL.lastPathComponent)
    ///     }
    /// } catch FileSystemError.fileNotFound {
    ///     print("디렉토리를 찾을 수 없습니다")
    /// } catch FileSystemError.accessDenied {
    ///     print("디렉토리 접근 권한이 없습니다")
    /// } catch {
    ///     print("오류: \(error)")
    /// }
    /// ```
    func listVideoFiles(at url: URL) throws -> [URL] {
        // 1단계: 디렉토리 존재 확인
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound
        }

        // 2단계: 재귀적 enumerator 생성
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw FileSystemError.accessDenied
        }

        var videoFiles: [URL] = []

        // 3단계: 모든 항목 순회
        for case let fileURL as URL in enumerator {
            // 3-1: 일반 파일인지 확인 (디렉토리, 심볼릭 링크 제외)
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard let isRegularFile = resourceValues.isRegularFile, isRegularFile else {
                    continue
                }
            } catch {
                // 속성 읽기 실패 시 스킵
                continue
            }

            // 3-2: 비디오 확장자 확인
            let ext = fileURL.pathExtension.lowercased()
            if supportedVideoExtensions.contains(ext) {
                videoFiles.append(fileURL)
            }
        }

        return videoFiles
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 2: readFile
     ───────────────────────────────────────────────────────────────────────

     【목적】
     파일의 전체 내용을 메모리로 읽어옵니다.

     【주의사항】
     대용량 파일(1GB 이상)을 읽을 때 메모리 부족 가능성:
     - 비디오 파일은 보통 100-500MB
     - 전체를 메모리에 로드하지 않고 스트리밍 방식으로 처리 권장

     【대안】
     스트리밍:
     ```swift
     let fileHandle = try FileHandle(forReadingFrom: url)
     while let chunk = try fileHandle.read(upToCount: 1024 * 1024) {
         // 1MB씩 처리
     }
     ```

     【사용 시나리오】
     - 메타데이터 파일 읽기 (GPS 로그, 설정 파일)
     - 작은 비디오 클립
     - 파일 검증 (헤더 확인)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 파일의 전체 내용을 읽기
    ///
    /// 파일을 메모리로 읽어 Data 객체로 반환합니다.
    /// 대용량 파일은 메모리 부족을 유발할 수 있으므로 주의가 필요합니다.
    ///
    /// @param url 읽을 파일의 URL
    /// @return 파일 내용 (Data)
    /// @throws FileSystemError
    ///   - .accessDenied: 파일 읽기 권한 없음
    ///   - .readFailed: 파일 읽기 실패
    ///
    /// 사용 예시:
    /// ```swift
    /// let fileURL = URL(fileURLWithPath: "/Volumes/SD/gps.log")
    ///
    /// do {
    ///     let data = try service.readFile(at: fileURL)
    ///     print("파일 크기: \(data.count) bytes")
    ///
    ///     if let content = String(data: data, encoding: .utf8) {
    ///         print("내용: \(content)")
    ///     }
    /// } catch {
    ///     print("파일 읽기 실패: \(error)")
    /// }
    /// ```
    ///
    /// 주의:
    /// - 대용량 파일(1GB+)은 메모리 부족 가능
    /// - 비디오 파일은 스트리밍 방식 권장
    func readFile(at url: URL) throws -> Data {
        // 읽기 권한 확인
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw FileSystemError.accessDenied
        }

        // 파일 읽기
        do {
            return try Data(contentsOf: url)
        } catch {
            throw FileSystemError.readFailed(error.localizedDescription)
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 3: getFileInfo
     ───────────────────────────────────────────────────────────────────────

     【목적】
     파일의 메타데이터를 조회합니다.

     【조회 속성】
     FileManager.attributesOfItem으로 다음 속성 읽기:
     - .size: 파일 크기 (Int64)
     - .type: 파일 타입 (.typeRegular, .typeDirectory)
     - .creationDate: 생성 날짜 (Date)
     - .modificationDate: 수정 날짜 (Date)

     【타입 캐스팅】
     attributesOfItem은 [FileAttributeKey: Any] 반환:
     ```swift
     let size = attributes[.size] as? Int64 ?? 0
     let creationDate = attributes[.creationDate] as? Date
     ```

     【활용 사례】
     - 파일 리스트 UI 표시
     - 정렬 (크기, 날짜)
     - 필터링 (특정 날짜 이후)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 파일의 메타데이터 정보 조회
    ///
    /// 파일의 크기, 생성/수정 날짜 등 메타데이터를 조회합니다.
    ///
    /// @param url 조회할 파일의 URL
    /// @return FileInfo 구조체
    /// @throws FileSystemError
    ///   - .fileNotFound: 파일이 존재하지 않음
    ///   - .readFailed: 속성 읽기 실패
    ///
    /// 사용 예시:
    /// ```swift
    /// let fileURL = URL(fileURLWithPath: "/Volumes/SD/video.mp4")
    ///
    /// do {
    ///     let info = try service.getFileInfo(at: fileURL)
    ///     print("파일명: \(info.name)")
    ///     print("크기: \(info.size) bytes")
    ///     print("생성일: \(info.creationDate ?? Date())")
    ///     print("디렉토리: \(info.isDirectory)")
    /// } catch {
    ///     print("정보 조회 실패: \(error)")
    /// }
    /// ```
    func getFileInfo(at url: URL) throws -> FileInfo {
        // 파일 존재 확인
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound
        }

        // 파일 속성 조회
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)

            return FileInfo(
                name: url.lastPathComponent,
                size: attributes[.size] as? Int64 ?? 0,
                isDirectory: (attributes[.type] as? FileAttributeType) == .typeDirectory,
                path: url.path,
                creationDate: attributes[.creationDate] as? Date,
                modificationDate: attributes[.modificationDate] as? Date
            )
        } catch {
            throw FileSystemError.readFailed(error.localizedDescription)
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 4: deleteFiles
     ───────────────────────────────────────────────────────────────────────

     【목적】
     여러 파일을 일괄 삭제합니다.

     【트랜잭션】
     현재 구현은 non-transactional:
     - 중간에 실패하면 일부만 삭제됨
     - 복구 불가능

     트랜잭션 구현 시:
     1. 모든 파일을 임시 위치로 이동
     2. 모두 성공하면 실제 삭제
     3. 실패 시 원래 위치로 복원

     【에러 처리】
     첫 번째 실패에서 즉시 throws:
     ```swift
     for url in urls {
         try fileManager.removeItem(at: url)  // 실패 시 즉시 종료
     }
     ```

     【사용 주의】
     삭제는 복구 불가능하므로 신중하게:
     - 사용자 확인 다이얼로그 표시
     - 휴지통으로 이동 고려
     - 로그 기록
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 파일 일괄 삭제
    ///
    /// 여러 파일을 한 번에 삭제합니다.
    /// 중간에 실패하면 일부만 삭제될 수 있습니다 (non-transactional).
    ///
    /// @param urls 삭제할 파일 URL 배열
    /// @throws FileSystemError
    ///   - .writeFailed: 파일 삭제 실패
    ///
    /// 사용 예시:
    /// ```swift
    /// let filesToDelete = [
    ///     URL(fileURLWithPath: "/Volumes/SD/old1.mp4"),
    ///     URL(fileURLWithPath: "/Volumes/SD/old2.mp4")
    /// ]
    ///
    /// do {
    ///     try service.deleteFiles(filesToDelete)
    ///     print("\(filesToDelete.count)개 파일 삭제 완료")
    /// } catch FileSystemError.writeFailed(let reason) {
    ///     print("삭제 실패: \(reason)")
    /// }
    /// ```
    ///
    /// 주의:
    /// - 삭제는 복구 불가능
    /// - 중간에 실패하면 일부만 삭제됨
    /// - 사용자 확인 필요
    func deleteFiles(_ urls: [URL]) throws {
        for url in urls {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw FileSystemError.writeFailed("Failed to delete \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 가이드
 ═══════════════════════════════════════════════════════════════════════════

 【1. 기본 사용법】

 ```swift
 let fileSystemService = FileSystemService()
 let sdCardURL = URL(fileURLWithPath: "/Volumes/BlackboxSD")

 do {
     // 비디오 파일 목록 조회
     let videoFiles = try fileSystemService.listVideoFiles(at: sdCardURL)
     print("\(videoFiles.count)개 비디오 파일")

     for videoURL in videoFiles {
         // 파일 정보 조회
         let info = try fileSystemService.getFileInfo(at: videoURL)
         print("\(info.name): \(info.size) bytes")
     }

     // 파일 읽기 (작은 메타데이터 파일)
     let gpsURL = sdCardURL.appendingPathComponent("GPS/20240115.nmea")
     let gpsData = try fileSystemService.readFile(at: gpsURL)

     // 파일 삭제
     let oldFiles = videoFiles.filter { url in
         let info = try? fileSystemService.getFileInfo(at: url)
         let isOld = info?.creationDate?.timeIntervalSinceNow ?? 0 < -7 * 24 * 3600
         return isOld
     }
     try fileSystemService.deleteFiles(oldFiles)

 } catch FileSystemError.fileNotFound {
     print("파일을 찾을 수 없습니다")
 } catch FileSystemError.accessDenied {
     print("파일 접근 권한이 없습니다")
 } catch {
     print("오류: \(error)")
 }
 ```

 【2. FileScanner와의 통합】

 FileScanner는 FileManager를 직접 사용하지만,
 FileSystemService를 사용하도록 수정 가능:

 ```swift
 class FileScanner {
     private let fileSystemService: FileSystemService

     init(fileSystemService: FileSystemService = FileSystemService()) {
         self.fileSystemService = fileSystemService
     }

     func scanDirectory(_ directoryURL: URL) throws -> [VideoFileGroup] {
         // FileSystemService 사용
         let videoFiles = try fileSystemService.listVideoFiles(at: directoryURL)

         // 파일명 파싱 및 그룹화
         // ...
     }
 }
 ```

 【3. SwiftUI ViewModel 통합】

 ```swift
 @MainActor
 class FileListViewModel: ObservableObject {
     @Published var videoFiles: [URL] = []
     @Published var errorMessage: String?

     private let fileSystemService: FileSystemService

     init(fileSystemService: FileSystemService = FileSystemService()) {
         self.fileSystemService = fileSystemService
     }

     func loadFiles(from url: URL) async {
         do {
             let files = try fileSystemService.listVideoFiles(at: url)
             self.videoFiles = files
         } catch FileSystemError.fileNotFound {
             self.errorMessage = "SD 카드를 찾을 수 없습니다"
         } catch FileSystemError.accessDenied {
             self.errorMessage = "파일 접근 권한이 필요합니다"
         } catch {
             self.errorMessage = "오류: \(error.localizedDescription)"
         }
     }

     func deleteFile(_ url: URL) async {
         do {
             try fileSystemService.deleteFiles([url])
             videoFiles.removeAll { $0 == url }
         } catch {
             self.errorMessage = "파일 삭제 실패"
         }
     }
 }
 ```

 【4. 테스트 코드】

 ```swift
 class FileSystemServiceTests: XCTestCase {
     var service: FileSystemService!
     var testDirectory: URL!

     override func setUp() {
         service = FileSystemService()
         testDirectory = createTestDirectory()
     }

     func testListVideoFiles() throws {
         // 테스트 파일 생성
         createTestFile("video1.mp4", in: testDirectory)
         createTestFile("video2.mp4", in: testDirectory)
         createTestFile("document.txt", in: testDirectory)

         // 비디오 파일만 조회
         let videoFiles = try service.listVideoFiles(at: testDirectory)

         // 검증
         XCTAssertEqual(videoFiles.count, 2)
         XCTAssertTrue(videoFiles.allSatisfy { $0.pathExtension == "mp4" })
     }

     func testGetFileInfo() throws {
         let fileURL = createTestFile("test.mp4", size: 1024, in: testDirectory)

         let info = try service.getFileInfo(at: fileURL)

         XCTAssertEqual(info.name, "test.mp4")
         XCTAssertEqual(info.size, 1024)
         XCTAssertFalse(info.isDirectory)
         XCTAssertNotNil(info.creationDate)
     }

     func testReadFile() throws {
         let content = "test content"
         let fileURL = createTestFile("test.txt", content: content, in: testDirectory)

         let data = try service.readFile(at: fileURL)
         let readContent = String(data: data, encoding: .utf8)

         XCTAssertEqual(readContent, content)
     }

     func testDeleteFiles() throws {
         let file1 = createTestFile("file1.mp4", in: testDirectory)
         let file2 = createTestFile("file2.mp4", in: testDirectory)

         try service.deleteFiles([file1, file2])

         XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path))
         XCTAssertFalse(FileManager.default.fileExists(atPath: file2.path))
     }

     func testFileNotFound() {
         let nonexistentURL = URL(fileURLWithPath: "/nonexistent/path")

         XCTAssertThrowsError(try service.listVideoFiles(at: nonexistentURL)) { error in
             XCTAssertTrue(error is FileSystemError)
             if case FileSystemError.fileNotFound = error {
                 // Expected
             } else {
                 XCTFail("Expected fileNotFound error")
             }
         }
     }
 }
 ```

 【5. DeviceDetector와의 통합】

 DeviceDetector가 SD 카드를 발견하면 FileSystemService로 파일 접근:

 ```swift
 class ContentViewModel: ObservableObject {
     @Published var videoFiles: [URL] = []

     private let deviceDetector = DeviceDetector()
     private let fileSystemService = FileSystemService()

     func startMonitoring() {
         deviceDetector.monitorDeviceChanges(
             onConnect: { [weak self] volumeURL in
                 self?.handleSDCardConnected(volumeURL)
             },
             onDisconnect: { [weak self] volumeURL in
                 self?.handleSDCardDisconnected(volumeURL)
             }
         )
     }

     private func handleSDCardConnected(_ volumeURL: URL) {
         Task { @MainActor in
             do {
                 let files = try fileSystemService.listVideoFiles(at: volumeURL)
                 self.videoFiles = files
                 print("\(files.count)개 비디오 파일 발견")
             } catch {
                 print("파일 로드 실패: \(error)")
             }
         }
     }

     private func handleSDCardDisconnected(_ volumeURL: URL) {
         self.videoFiles = []
     }
 }
 ```

 ═══════════════════════════════════════════════════════════════════════════
 */
