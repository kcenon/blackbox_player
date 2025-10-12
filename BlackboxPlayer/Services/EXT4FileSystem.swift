/// @file EXT4FileSystem.swift
/// @brief Protocol-based EXT4 file system interface for easy C library integration
/// @author BlackboxPlayer Development Team
/// @details EXT4 파일시스템 인터페이스와 오류 타입 정의

/*
 ═══════════════════════════════════════════════════════════════════════════
 EXT4 파일시스템 인터페이스
 ═══════════════════════════════════════════════════════════════════════════

 【이 파일의 목적】
 macOS에서 Linux EXT4 파일시스템을 읽기 위한 Swift 인터페이스를 제공합니다.
 대부분의 블랙박스 SD 카드는 EXT4로 포맷되어 있지만, macOS는 이를 네이티브로
 지원하지 않아 외부 라이브러리(C/C++)를 통해 접근해야 합니다.

 【EXT4란 무엇인가?】
 EXT4 (Fourth Extended File System)는 Linux에서 가장 널리 사용되는
 파일시스템입니다. 특징:
 - 최대 16TB 파일 크기 지원
 - 저널링(Journaling) 지원: 시스템 충돌 시 데이터 손실 방지
 - 지연 할당(Delayed Allocation): 성능 향상
 - 익스텐트(Extent) 기반 저장: 연속된 블록을 효율적으로 관리

 【왜 프로토콜을 사용하는가?】
 프로토콜 기반 설계의 장점:

 1. C/C++ 브리지 분리
    ┌─────────────┐      ┌──────────────────┐
    │ Swift 코드  │──────│ Protocol 인터페이스│
    └─────────────┘      └──────────────────┘
                                 │
                    ┌────────────┼────────────┐
                    │                         │
              ┌─────▼─────┐           ┌──────▼──────┐
              │ 실제 구현  │           │  Mock 구현  │
              │ (C++ 브리지)│           │ (테스트용)  │
              └───────────┘           └─────────────┘

 2. 테스트 용이성: MockEXT4FileSystem으로 단위 테스트 가능
 3. 교체 가능성: 다른 EXT4 라이브러리로 쉽게 교체
 4. 플랫폼 독립성: 각 플랫폼별 구현 분리

 【데이터 흐름】
 SD 카드 삽입 → EXT4 마운트 → 파일 목록 조회 → 파일 읽기 → Swift Data로 변환
      ↓              ↓              ↓              ↓              ↓
   Device       Mount Point    Directory      File Content    VideoFile
   /dev/disk2   /Volumes/SD    /DCIM/...      MP4 binary     Metadata

 【주요 작업 흐름】

 작업 1: SD 카드 마운트
 ┌──────────────────────────────────────────────┐
 │ 1. mount(devicePath: "/dev/disk2s1")         │
 │ 2. C++ 라이브러리로 EXT4 superblock 읽기     │
 │ 3. 파일시스템 검증 (magic number 확인)       │
 │ 4. 마운트 포인트 생성                        │
 │ 5. isMounted = true 설정                     │
 └──────────────────────────────────────────────┘

 작업 2: 파일 읽기
 ┌──────────────────────────────────────────────┐
 │ 1. readFile(at: "DCIM/Video001.mp4")         │
 │ 2. 경로 정규화 (앞뒤 슬래시 제거)            │
 │ 3. inode 번호 조회                           │
 │ 4. extent 정보 읽기 (파일 블록 위치)         │
 │ 5. 블록 단위로 데이터 읽기                   │
 │ 6. Swift Data로 변환                         │
 └──────────────────────────────────────────────┘

 【통합 위치】
 - FileManagerService: 이 프로토콜을 사용하여 SD 카드 파일 접근
 - FileScanner: listFiles()로 비디오 파일 목록 수집
 - MetadataExtractor: readFile()로 MP4 파일 읽기

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

// MARK: - EXT4 Error Types

/*
 ───────────────────────────────────────────────────────────────────────────
 EXT4 오류 타입
 ───────────────────────────────────────────────────────────────────────────

 【오류 처리 전략】
 Swift의 Error 프로토콜을 활용하여 타입 안전한 오류 처리를 구현합니다.

 【오류 분류】
 1. 디바이스 오류: deviceNotFound, mountFailed, unmountFailed
 2. 상태 오류: alreadyMounted, notMounted
 3. 파일 오류: invalidPath, fileNotFound, readFailed, writeFailed
 4. 권한 오류: permissionDenied
 5. 공간 오류: insufficientSpace
 6. 파일시스템 오류: corruptedFileSystem
 7. 기타: unsupportedOperation, unknownError

 【사용 예시】
 ```swift
 do {
     try ext4.mount(devicePath: "/dev/disk2s1")
 } catch EXT4Error.deviceNotFound {
     print("SD 카드가 연결되지 않았습니다")
 } catch EXT4Error.mountFailed(let reason) {
     print("마운트 실패: \(reason)")
 } catch {
     print("알 수 없는 오류: \(error)")
 }
 ```

 【Equatable 채택 이유】
 테스트 코드에서 오류 비교를 위해 필요:
 XCTAssertThrowsError(try ext4.mount("/invalid")) { error in
     XCTAssertEqual(error as? EXT4Error, .deviceNotFound)
 }
 ───────────────────────────────────────────────────────────────────────────
 */

/// @enum EXT4Error
/// @brief EXT4 파일시스템 작업 중 발생할 수 있는 오류
/// @details 각 오류는 발생 원인과 복구 방법에 대한 정보를 포함합니다.
enum EXT4Error: Error, Equatable {

    // ──────────────────────────────────────
    // 디바이스 관련 오류
    // ──────────────────────────────────────

    /// @brief SD 카드나 외장 저장장치를 찾을 수 없음
    /// @details 발생 시나리오:
    /// - SD 카드가 컴퓨터에 연결되지 않음
    /// - 디바이스 경로가 존재하지 않음 (예: /dev/disk2s1)
    /// - USB 케이블 연결 불량
    ///
    /// 복구 방법:
    /// 1. SD 카드 재삽입
    /// 2. `diskutil list` 명령으로 디바이스 경로 확인
    /// 3. USB 허브 사용 시 직접 연결 시도
    case deviceNotFound

    /// @brief EXT4 파일시스템 마운트 실패
    /// @param reason C 라이브러리의 에러 메시지
    /// @details 발생 시나리오:
    /// - 파일시스템이 손상됨
    /// - 권한이 부족함 (root 권한 필요)
    /// - 이미 다른 프로세스가 마운트함
    case mountFailed(reason: String)

    /// @brief 언마운트 실패
    /// @param reason 실패 원인 메시지
    /// @details 발생 시나리오:
    /// - 파일이 아직 열려 있음
    /// - 디렉토리가 작업 디렉토리로 사용 중
    case unmountFailed(reason: String)

    /// @brief 이미 마운트된 상태에서 재마운트 시도
    /// @details 방지 방법: mount() 호출 전 isMounted 확인
    case alreadyMounted

    /// @brief 마운트되지 않은 상태에서 파일 작업 시도
    /// @details 발생 시나리오:
    /// - mount() 호출하지 않고 readFile() 호출
    /// - unmount() 후 파일 접근 시도
    case notMounted

    // ──────────────────────────────────────
    // 파일/디렉토리 오류
    // ──────────────────────────────────────

    /// @brief 잘못된 경로 형식
    /// @details 예시:
    /// - 빈 문자열
    /// - null 문자 포함
    /// - 경로 길이 초과 (보통 4096바이트)
    case invalidPath

    /// @brief 파일이나 디렉토리가 존재하지 않음
    /// @param path 찾을 수 없는 파일의 경로
    /// @details 디버깅 팁:
    /// 1. listFiles()로 상위 디렉토리 내용 확인
    /// 2. 대소문자 구분 확인 (EXT4는 대소문자 구분)
    /// 3. 경로 구분자 확인 (/)
    case fileNotFound(path: String)

    /// @brief 파일 읽기 실패
    /// @param path 읽으려던 파일 경로
    /// @param reason 실패 원인 (예: "I/O error", "Permission denied")
    /// @details 발생 시나리오:
    /// - 디스크 읽기 오류 (불량 섹터)
    /// - 파일 권한 부족
    /// - 파일이 삭제됨 (TOCTOU 문제)
    case readFailed(path: String, reason: String)

    /// @brief 파일 쓰기 실패
    /// @param path 쓰려던 파일 경로
    /// @param reason 실패 원인
    /// @details 참고: 블랙박스 플레이어는 읽기 전용이므로 거의 발생하지 않음
    case writeFailed(path: String, reason: String)

    // ──────────────────────────────────────
    // 권한 및 공간 오류
    // ──────────────────────────────────────

    /// @brief 권한 거부
    /// @details macOS에서 EXT4 마운트는 보통 root 권한 필요:
    /// sudo ./BlackboxPlayer
    case permissionDenied

    /// @brief 디스크 공간 부족
    /// @details 쓰기 작업에서만 발생 (블랙박스 플레이어는 읽기 전용)
    case insufficientSpace

    // ──────────────────────────────────────
    // 파일시스템 오류
    // ──────────────────────────────────────

    /// @brief 파일시스템이 손상됨
    /// @details 발생 시나리오:
    /// - Superblock magic number 불일치
    /// - inode 테이블 손상
    /// - 블록 그룹 descriptor 오류
    ///
    /// 복구 방법:
    /// Linux에서 e2fsck 실행:
    /// sudo e2fsck -f /dev/sdX
    case corruptedFileSystem

    /// @brief 지원하지 않는 작업
    /// @details 예시:
    /// - EXT4 기능이 너무 새로움 (라이브러리 버전 낮음)
    /// - 특수 파일 타입 (소켓, 파이프 등)
    case unsupportedOperation

    /// @brief 알 수 없는 오류
    /// @param code C 라이브러리의 errno 값
    /// @details 디버깅:
    /// 1. errno 코드를 man 페이지에서 검색
    /// 2. strerror(code)로 메시지 확인
    case unknownError(code: Int32)

    /*
     ───────────────────────────────────────────────────────────────────────
     사용자 친화적 오류 메시지
     ───────────────────────────────────────────────────────────────────────

     【지역화 전략】
     현재는 영어 메시지만 제공하지만, 추후 NSLocalizedString으로 변경 가능:

     return NSLocalizedString(
         "ext4.error.deviceNotFound",
         comment: "Device not found error"
     )

     【메시지 작성 원칙】
     1. 사용자가 이해할 수 있는 언어로 작성
     2. 원인과 해결 방법을 간단히 포함
     3. 기술적 세부사항은 reason 파라미터에 포함
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 사용자에게 표시할 오류 메시지
    /// @return 지역화된 오류 메시지 문자열
    var localizedDescription: String {
        switch self {
        case .deviceNotFound:
            return "Device not found or disconnected"
        case .mountFailed(let reason):
            return "Failed to mount EXT4 filesystem: \(reason)"
        case .unmountFailed(let reason):
            return "Failed to unmount EXT4 filesystem: \(reason)"
        case .alreadyMounted:
            return "Device is already mounted"
        case .notMounted:
            return "Device is not mounted"
        case .invalidPath:
            return "Invalid file path"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .readFailed(let path, let reason):
            return "Failed to read file '\(path)': \(reason)"
        case .writeFailed(let path, let reason):
            return "Failed to write file '\(path)': \(reason)"
        case .permissionDenied:
            return "Permission denied"
        case .insufficientSpace:
            return "Insufficient disk space"
        case .corruptedFileSystem:
            return "Corrupted file system"
        case .unsupportedOperation:
            return "Operation not supported"
        case .unknownError(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

// MARK: - File Information

/*
 ───────────────────────────────────────────────────────────────────────────
 EXT4 파일 정보
 ───────────────────────────────────────────────────────────────────────────

 【inode란 무엇인가?】
 EXT4에서 각 파일/디렉토리는 inode(index node)라는 데이터 구조로 표현됩니다.

 inode 구조:
 ┌────────────────────────────────────┐
 │ inode 번호: 12345                  │  ← 고유 식별자
 │ 파일 크기: 1048576 bytes           │
 │ 권한: 0o644 (rw-r--r--)            │
 │ 소유자: uid=1000, gid=1000         │
 │ 타임스탬프:                        │
 │   - ctime: 생성 시각               │
 │   - mtime: 수정 시각               │
 │   - atime: 접근 시각               │
 │ 블록 포인터:                       │
 │   - Direct blocks (12개)           │  ← 직접 데이터 블록 참조
 │   - Indirect block (1개)           │  ← 간접 블록 (포인터의 포인터)
 │   - Double indirect (1개)          │
 │   - Triple indirect (1개)          │
 └────────────────────────────────────┘

 【파일 이름과 inode의 관계】
 파일 이름은 디렉토리 엔트리에 저장되고, inode 번호로 실제 inode를 참조:

 디렉토리 엔트리:
 ┌──────────────────┬────────────┐
 │ 파일 이름         │ inode 번호 │
 ├──────────────────┼────────────┤
 │ Video001.mp4     │   12345    │
 │ Video002.mp4     │   12346    │
 │ GPS001.nmea      │   12347    │
 └──────────────────┴────────────┘

 【Codable 채택 이유】
 파일 정보를 캐싱하거나 네트워크로 전송하기 위해 JSON으로 변환 가능:

 let encoder = JSONEncoder()
 let json = try encoder.encode(fileInfo)
 // {"path":"DCIM/Video001.mp4","size":1048576,...}
 ───────────────────────────────────────────────────────────────────────────
 */

/// @struct EXT4FileInfo
/// @brief EXT4 파일시스템의 파일/디렉토리 정보
/// @details inode의 중요 필드를 Swift 구조체로 표현합니다.
struct EXT4FileInfo: Equatable, Codable {

    /// @var path
    /// @brief 파일의 전체 경로 (마운트 포인트 기준 상대 경로)
    /// @details 예시:
    /// - "DCIM/Video/Video001.mp4"
    /// - "GPS/20240115.nmea"
    /// - "EventLog/event001.dat"
    ///
    /// 참고: 앞에 슬래시(/)를 포함하지 않습니다
    let path: String

    /// @var name
    /// @brief 파일 이름 (경로 제외)
    /// @details path가 "DCIM/Video/Video001.mp4"이면
    /// name은 "Video001.mp4"
    ///
    /// 구현 예시:
    /// name = (path as NSString).lastPathComponent
    let name: String

    /// @var size
    /// @brief 파일 크기 (바이트 단위)
    /// @details UInt64 사용 이유:
    /// - EXT4는 최대 16TB 파일 지원
    /// - Int는 음수 값이 불필요하므로 UInt 사용
    /// - 64비트로 충분히 큰 파일 표현 가능
    ///
    /// 크기 변환 예시:
    /// let mb = Double(size) / 1024.0 / 1024.0
    /// print(String(format: "%.2f MB", mb))
    let size: UInt64

    /// @var isDirectory
    /// @brief 디렉토리 여부
    /// @details true: 디렉토리 (listFiles 가능)
    /// false: 일반 파일 (readFile 가능)
    ///
    /// inode의 S_IFDIR 비트로 판별:
    /// isDirectory = (inode.i_mode & S_IFDIR) != 0
    let isDirectory: Bool

    /// @var creationDate
    /// @brief 파일 생성 시각
    /// @details EXT4의 i_crtime (creation time) 필드
    ///
    /// Optional인 이유:
    /// - 오래된 EXT4는 생성 시각을 저장하지 않음
    /// - 생성 시각 지원은 EXT4의 확장 기능
    let creationDate: Date?

    /// @var modificationDate
    /// @brief 파일 수정 시각
    /// @details EXT4의 i_mtime (modification time) 필드
    ///
    /// 블랙박스에서 중요:
    /// - 녹화 시각 파악
    /// - 파일 정렬 (최신순)
    /// - 중복 파일 감지
    ///
    /// 예시:
    /// let formatter = DateFormatter()
    /// formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    /// print(formatter.string(from: modificationDate))
    /// // "2024-01-15 14:30:25"
    let modificationDate: Date?

    /// @var permissions
    /// @brief 파일 권한 (UNIX 스타일)
    /// @details 【권한 비트 구조】
    /// 8진수로 표현: 0oXXX
    ///
    /// ┌─────────────────────────────────────┐
    /// │  Owner  │  Group  │  Others │       │
    /// │  r w x  │  r w x  │  r w x  │       │
    /// │  4 2 1  │  4 2 1  │  4 2 1  │       │
    /// └─────────────────────────────────────┘
    ///
    /// 예시:
    /// 0o644 = rw-r--r--
    ///   ↓
    /// Owner: 6 = 4(읽기) + 2(쓰기)
    /// Group: 4 = 4(읽기)
    /// Others: 4 = 4(읽기)
    ///
    /// 0o755 = rwxr-xr-x
    ///   ↓
    /// Owner: 7 = 4(읽기) + 2(쓰기) + 1(실행)
    /// Group: 5 = 4(읽기) + 1(실행)
    /// Others: 5 = 4(읽기) + 1(실행)
    ///
    /// 【권한 확인 방법】
    /// let canRead = (permissions & 0o400) != 0  // Owner 읽기 권한
    /// let canWrite = (permissions & 0o200) != 0 // Owner 쓰기 권한
    /// let canExecute = (permissions & 0o100) != 0 // Owner 실행 권한
    let permissions: UInt16

    /// @brief 초기화 메서드
    /// @param path 파일 경로
    /// @param name 파일 이름
    /// @param size 파일 크기 (바이트)
    /// @param isDirectory 디렉토리 여부
    /// @param creationDate 생성 시각 (Optional)
    /// @param modificationDate 수정 시각 (Optional)
    /// @param permissions UNIX 권한 (기본값: 0o644)
    /// @details 대부분의 파라미터는 C 라이브러리에서 읽은 inode 정보를 변환하여 전달합니다.
    init(
        path: String,
        name: String,
        size: UInt64,
        isDirectory: Bool,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        permissions: UInt16 = 0o644
    ) {
        self.path = path
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.permissions = permissions
    }
}

// MARK: - Device Information

/*
 ───────────────────────────────────────────────────────────────────────────
 EXT4 디바이스 정보
 ───────────────────────────────────────────────────────────────────────────

 【Superblock이란?】
 EXT4 파일시스템의 첫 번째 블록(오프셋 1024바이트)에 위치하는 메타데이터입니다.

 Superblock 구조 (일부):
 ┌─────────────────────────────────────────┐
 │ Magic Number: 0xEF53                    │  ← EXT4 식별자
 │ Total Blocks: 1953792                   │  ← 총 블록 수
 │ Free Blocks: 523456                     │  ← 남은 블록 수
 │ Block Size: 4096                        │  ← 블록 크기
 │ Blocks Per Group: 32768                 │
 │ Inodes Per Group: 8192                  │
 │ Volume Name: "BlackboxSD"               │
 │ Mount Count: 42                         │
 │ Maximum Mount Count: 65535              │
 │ Last Mount Time: 2024-01-15 14:30:25    │
 │ Creator OS: Linux                       │
 │ Features: journal, extent, flex_bg      │
 └─────────────────────────────────────────┘

 【블록(Block)이란?】
 EXT4는 데이터를 블록 단위로 관리합니다. 보통 4KB (4096바이트).

 총 용량 계산:
 totalSize = Total Blocks × Block Size
           = 1953792 × 4096
           = 8,000,004,096 bytes
           ≈ 7.45 GB

 여유 공간 계산:
 freeSpace = Free Blocks × Block Size
           = 523456 × 4096
           = 2,144,337,920 bytes
           ≈ 2.0 GB
 ───────────────────────────────────────────────────────────────────────────
 */

/// @struct EXT4DeviceInfo
/// @brief EXT4 저장 장치의 정보
/// @details Superblock에서 읽어온 파일시스템 메타데이터를 표현합니다.
struct EXT4DeviceInfo: Equatable {

    /// @var devicePath
    /// @brief 디바이스 경로
    /// @details macOS 예시:
    /// - "/dev/disk2s1" : SD 카드의 첫 번째 파티션
    /// - "/dev/disk3s1" : USB 드라이브
    ///
    /// Linux 예시:
    /// - "/dev/sdb1"
    /// - "/dev/mmcblk0p1" (eMMC/SD)
    ///
    /// 디바이스 찾기:
    /// ```bash
    /// diskutil list          # macOS
    /// lsblk                  # Linux
    /// ```
    let devicePath: String

    /// @var volumeName
    /// @brief 볼륨 이름 (선택적)
    /// @details Superblock의 s_volume_name 필드 (최대 16바이트)
    ///
    /// 예시:
    /// - "BlackboxSD"
    /// - "DASHCAM"
    /// - "NO_NAME" (포맷 시 이름 지정 안 함)
    ///
    /// nil인 경우: 볼륨 이름이 설정되지 않음
    let volumeName: String?

    /// @var totalSize
    /// @brief 총 용량 (바이트)
    /// @details 계산: s_blocks_count × s_log_block_size
    ///
    /// 예시:
    /// let gb = Double(totalSize) / 1_000_000_000
    /// print("\(gb) GB")  // "7.45 GB"
    let totalSize: UInt64

    /// @var freeSpace
    /// @brief 사용 가능한 여유 공간 (바이트)
    /// @details 계산: s_free_blocks_count × s_log_block_size
    ///
    /// 주의: Root 예약 공간 제외
    /// EXT4는 기본적으로 총 용량의 5%를 root 사용자를 위해 예약합니다.
    /// 따라서 일반 사용자는 freeSpace가 0이 아니어도 쓰기에 실패할 수 있습니다.
    let freeSpace: UInt64

    /// @var blockSize
    /// @brief 블록 크기 (바이트)
    /// @details 일반적인 값:
    /// - 1024 (1 KB) : 작은 파일이 많을 때
    /// - 2048 (2 KB)
    /// - 4096 (4 KB) : 기본값, 대부분의 시스템
    /// - 8192 (8 KB) : 대용량 파일 처리
    ///
    /// 블록 크기가 클수록:
    /// 장점: 큰 파일 I/O 성능 향상
    /// 단점: 작은 파일 낭비 증가 (내부 단편화)
    ///
    /// 예시:
    /// blockSize = 4096일 때, 100바이트 파일도 4096바이트 차지
    let blockSize: UInt32

    /// @var isMounted
    /// @brief 마운트 상태
    /// @details true: 현재 마운트됨 (파일 접근 가능)
    /// false: 언마운트됨 (파일 접근 불가)
    ///
    /// 마운트 상태 확인:
    /// ```bash
    /// mount | grep /dev/disk2s1  # macOS
    /// ```
    let isMounted: Bool

    /*
     ───────────────────────────────────────────────────────────────────────
     계산 속성 (Computed Properties)
     ───────────────────────────────────────────────────────────────────────

     【Computed Property란?】
     저장되지 않고 매번 계산되는 속성입니다.

     장점:
     1. 메모리 절약: 값을 저장하지 않음
     2. 항상 최신: totalSize나 freeSpace가 변경되면 자동 반영
     3. 일관성: 수동 업데이트 불필요

     단점:
     1. 계산 비용: 접근할 때마다 계산

     그러나 여기서는 간단한 산술 연산이므로 비용이 거의 없습니다.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 사용 중인 공간 (바이트)
    /// @return 사용 중인 공간 (바이트)
    /// @details 계산: 총 용량 - 여유 공간
    ///
    /// 오버플로우 방지:
    /// totalSize가 freeSpace보다 작으면 0 반환 (비정상적 상황)
    ///
    /// 예시:
    /// let usedMB = Double(usedSpace) / 1_000_000
    /// print("사용 중: \(usedMB) MB")
    var usedSpace: UInt64 {
        return totalSize > freeSpace ? totalSize - freeSpace : 0
    }

    /// @brief 사용률 (퍼센트)
    /// @return 사용률 (0.0 ~ 100.0)
    /// @details 계산: (사용 공간 / 총 용량) × 100
    ///
    /// 반환 범위: 0.0 ~ 100.0
    ///
    /// 예시:
    /// print(String(format: "디스크 사용률: %.1f%%", usagePercentage))
    /// // "디스크 사용률: 73.2%"
    ///
    /// UI에서 프로그레스 바 표시:
    /// ProgressView(value: usagePercentage / 100.0)
    ///
    /// 경고 표시:
    /// if usagePercentage > 90.0 {
    ///     print("⚠️ 디스크 공간이 부족합니다!")
    /// }
    var usagePercentage: Double {
        guard totalSize > 0 else { return 0.0 }
        return Double(usedSpace) / Double(totalSize) * 100.0
    }
}

// MARK: - EXT4 File System Protocol

/*
 ───────────────────────────────────────────────────────────────────────────
 EXT4 파일시스템 프로토콜
 ───────────────────────────────────────────────────────────────────────────

 【프로토콜 기반 설계의 장점】

 1. 테스트 용이성
    ┌────────────────────┐
    │ 프로덕션 코드       │
    │                    │
    │ let fs = EXT4Bridge()  ←── 실제 C++ 구현
    └────────────────────┘

    ┌────────────────────┐
    │ 테스트 코드         │
    │                    │
    │ let fs = MockEXT4FileSystem()  ←── 메모리 기반 Mock
    └────────────────────┘

 2. 플랫폼 독립성
    - macOS: libext2fs 기반 구현
    - Linux: 직접 시스템 콜 사용
    - Windows: ext2fsd 드라이버 사용

 3. 점진적 구현
    - 먼저 Mock으로 UI 개발
    - 나중에 실제 구현 교체

 【동기(Sync) vs 비동기(Async) 작업】

 파일시스템 작업은 시간이 오래 걸릴 수 있습니다:
 - SD 카드 I/O: 10~50 MB/s (느린 카드)
 - 큰 파일 읽기: 수 초 소요

 따라서:
 - 기본 메서드: 동기 (throws)
 - Async 메서드: 비동기 (async throws) - UI 스레드 블로킹 방지

 사용 예시:
 ```swift
 // 동기 (백그라운드 스레드에서 호출)
 DispatchQueue.global().async {
     let data = try fs.readFile(at: "Video001.mp4")
     // ... 처리
 }

 // 비동기 (Swift Concurrency)
 Task {
     let data = try await fs.readFileAsync(at: "Video001.mp4")
     // ... UI 업데이트
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @protocol EXT4FileSystemProtocol
/// @brief EXT4 파일시스템 작업을 정의하는 프로토콜
/// @details 이 추상화를 통해 C/C++ 라이브러리를 쉽게 통합할 수 있습니다.
protocol EXT4FileSystemProtocol {

    // MARK: - Device Management

    /*
     ───────────────────────────────────────────────────────────────────────
     디바이스 관리
     ───────────────────────────────────────────────────────────────────────

     【마운트(Mount)란?】
     파일시스템을 운영체제에서 사용할 수 있도록 연결하는 작업입니다.

     마운트 과정:
     1. Superblock 읽기 (오프셋 1024)
     2. Magic number 확인 (0xEF53)
     3. 블록 그룹 descriptor 읽기
     4. 마운트 포인트 생성 (/tmp/ext4_mount_XXX)
     5. 메모리에 메타데이터 캐싱

     비유: USB 메모리를 꽂으면 "E:" 드라이브로 보이는 것과 유사
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief EXT4 디바이스를 마운트
    /// @param devicePath 디바이스 경로 (예: "/dev/disk2s1")
    /// @throws EXT4Error
    ///   - .deviceNotFound: 디바이스가 존재하지 않음
    ///   - .mountFailed: 마운트 실패 (손상된 파일시스템, 권한 부족 등)
    ///   - .alreadyMounted: 이미 마운트됨
    /// @details 마운트 후 파일 작업이 가능해집니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// let fs: EXT4FileSystemProtocol = EXT4Bridge()
    /// do {
    ///     try fs.mount(devicePath: "/dev/disk2s1")
    ///     print("마운트 성공")
    /// } catch EXT4Error.mountFailed(let reason) {
    ///     print("마운트 실패: \(reason)")
    /// }
    /// ```
    ///
    /// 주의사항:
    /// - macOS에서는 root 권한이 필요할 수 있음 (sudo)
    /// - 마운트 전 isMounted로 상태 확인 권장
    /// - 마운트는 무거운 작업이므로 앱 시작 시 1회만 실행
    func mount(devicePath: String) throws

    /// @brief 현재 마운트된 디바이스를 언마운트
    /// @throws EXT4Error
    ///   - .notMounted: 마운트되지 않은 상태
    ///   - .unmountFailed: 언마운트 실패 (파일이 열려 있음 등)
    /// @details 파일 핸들이 모두 닫혀야 성공합니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// // 앱 종료 시 정리
    /// do {
    ///     try fs.unmount()
    ///     print("언마운트 완료")
    /// } catch {
    ///     print("언마운트 실패: \(error)")
    /// }
    /// ```
    ///
    /// 주의사항:
    /// - 언마운트 후 파일 작업 시도 시 .notMounted 오류 발생
    /// - 백그라운드 작업이 진행 중이면 실패할 수 있음
    func unmount() throws

    /// @var isMounted
    /// @brief 디바이스가 현재 마운트되어 있는지 확인
    /// @return true: 마운트됨 (파일 작업 가능), false: 언마운트됨 (mount() 호출 필요)
    /// @details 사용 예시:
    /// ```swift
    /// if !fs.isMounted {
    ///     try fs.mount(devicePath: "/dev/disk2s1")
    /// }
    /// let files = try fs.listFiles(at: "DCIM")
    /// ```
    var isMounted: Bool { get }

    /// @brief 마운트된 디바이스의 정보를 조회
    /// @return EXT4DeviceInfo 구조체
    /// @throws EXT4Error.notMounted 마운트되지 않은 상태
    /// @details Superblock에서 읽은 메타데이터를 반환합니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// let info = try fs.getDeviceInfo()
    /// print("볼륨: \(info.volumeName ?? "Unknown")")
    /// print("총 용량: \(info.totalSize / 1_000_000_000) GB")
    /// print("여유 공간: \(info.freeSpace / 1_000_000_000) GB")
    /// print("사용률: \(String(format: "%.1f%%", info.usagePercentage))")
    /// ```
    ///
    /// UI 표시:
    /// ```swift
    /// let info = try fs.getDeviceInfo()
    /// Text("디스크 사용: \(info.usagePercentage, specifier: "%.1f")%")
    /// ProgressView(value: info.usagePercentage / 100.0)
    /// ```
    func getDeviceInfo() throws -> EXT4DeviceInfo

    // MARK: - File Operations

    /*
     ───────────────────────────────────────────────────────────────────────
     파일 작업
     ───────────────────────────────────────────────────────────────────────

     【경로 규칙】
     - 상대 경로 사용 (마운트 포인트 기준)
     - 앞에 슬래시(/) 붙이지 않음
     - 경로 구분자: / (Unix 스타일)

     올바른 경로:
     ✓ "DCIM/Video001.mp4"
     ✓ "GPS/20240115.nmea"
     ✓ ""  (루트 디렉토리)

     잘못된 경로:
     ✗ "/DCIM/Video001.mp4"  (앞 슬래시)
     ✗ "DCIM\\Video001.mp4"  (백슬래시)
     ✗ "/Volumes/SD/DCIM/..."  (절대 경로)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 디렉토리의 파일 목록 조회
    /// @param path 디렉토리 경로 (마운트 포인트 기준 상대 경로)
    /// @return EXT4FileInfo 배열
    /// @throws EXT4Error
    ///   - .notMounted: 마운트되지 않음
    ///   - .fileNotFound: 디렉토리가 존재하지 않음
    ///   - .readFailed: 읽기 실패
    /// @details 지정된 디렉토리의 모든 파일/하위 디렉토리를 반환합니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// // 루트 디렉토리 목록
    /// let rootFiles = try fs.listFiles(at: "")
    /// for file in rootFiles {
    ///     print("\(file.name) - \(file.isDirectory ? "DIR" : "\(file.size) bytes")")
    /// }
    ///
    /// // 특정 디렉토리
    /// let videos = try fs.listFiles(at: "DCIM/Video")
    /// let mp4Files = videos.filter { $0.name.hasSuffix(".mp4") }
    /// print("MP4 파일 \(mp4Files.count)개 발견")
    /// ```
    ///
    /// 재귀 탐색 예시:
    /// ```swift
    /// func findAllFiles(in path: String = "") throws -> [EXT4FileInfo] {
    ///     var allFiles: [EXT4FileInfo] = []
    ///     let files = try fs.listFiles(at: path)
    ///
    ///     for file in files {
    ///         allFiles.append(file)
    ///         if file.isDirectory {
    ///             let subFiles = try findAllFiles(in: file.path)
    ///             allFiles.append(contentsOf: subFiles)
    ///         }
    ///     }
    ///     return allFiles
    /// }
    /// ```
    func listFiles(at path: String) throws -> [EXT4FileInfo]

    /// @brief 파일 내용 읽기
    /// @param path 파일 경로 (마운트 포인트 기준 상대 경로)
    /// @return 파일의 내용 (Data)
    /// @throws EXT4Error
    ///   - .notMounted: 마운트되지 않음
    ///   - .fileNotFound: 파일이 존재하지 않음
    ///   - .readFailed: 읽기 실패 (I/O 오류, 권한 부족 등)
    /// @details 전체 파일을 메모리로 읽어 Data로 반환합니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// // MP4 파일 읽기
    /// let data = try fs.readFile(at: "DCIM/Video001.mp4")
    /// print("파일 크기: \(data.count) bytes")
    ///
    /// // 텍스트 파일 읽기
    /// let nmea = try fs.readFile(at: "GPS/20240115.nmea")
    /// if let text = String(data: nmea, encoding: .utf8) {
    ///     print("GPS 데이터:\n\(text)")
    /// }
    /// ```
    ///
    /// 주의사항:
    /// - 큰 파일(수 GB)은 메모리 부족 발생 가능
    /// - 큰 파일은 readFileAsync() 사용 권장
    /// - 또는 청크 단위 읽기 구현 필요 (향후 확장)
    ///
    /// 메모리 사용량 예측:
    /// let info = try fs.getFileInfo(at: path)
    /// if info.size > 100_000_000 { // 100 MB 이상
    ///     print("경고: 큰 파일입니다")
    /// }
    func readFile(at path: String) throws -> Data

    /// @brief 파일에 데이터 쓰기
    /// @param data 쓸 데이터
    /// @param path 파일 경로 (마운트 포인트 기준 상대 경로)
    /// @throws EXT4Error
    ///   - .notMounted: 마운트되지 않음
    ///   - .writeFailed: 쓰기 실패
    ///   - .insufficientSpace: 공간 부족
    ///   - .permissionDenied: 권한 부족
    /// @details 지정된 경로에 데이터를 씁니다. 파일이 존재하면 덮어씁니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// let text = "Hello, World!"
    /// let data = text.data(using: .utf8)!
    /// try fs.writeFile(data: data, to: "test.txt")
    /// ```
    ///
    /// 참고: 블랙박스 플레이어는 읽기 전용이므로 거의 사용되지 않습니다.
    func writeFile(data: Data, to path: String) throws

    /// @brief 파일/디렉토리 존재 여부 확인
    /// @param path 확인할 경로
    /// @return 존재하면 true, 없으면 false
    ///
    /// 사용 예시:
    /// ```swift
    /// if fs.fileExists(at: "DCIM/Video001.mp4") {
    ///     let data = try fs.readFile(at: "DCIM/Video001.mp4")
    ///     // ... 처리
    /// } else {
    ///     print("파일이 존재하지 않습니다")
    /// }
    /// ```
    ///
    /// 주의: 이 메서드는 throws하지 않습니다.
    /// 마운트되지 않은 상태에서는 false 반환
    func fileExists(at path: String) -> Bool

    /// @brief 파일 정보 조회
    /// @param path 파일 경로
    /// @return EXT4FileInfo 구조체
    /// @throws EXT4Error
    ///   - .notMounted: 마운트되지 않음
    ///   - .fileNotFound: 파일이 존재하지 않음
    /// @details 파일의 메타데이터(크기, 날짜, 권한 등)를 반환합니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// let info = try fs.getFileInfo(at: "DCIM/Video001.mp4")
    /// print("파일명: \(info.name)")
    /// print("크기: \(info.size) bytes")
    /// print("수정일: \(info.modificationDate ?? Date())")
    /// print("디렉토리: \(info.isDirectory)")
    /// print("권한: \(String(info.permissions, radix: 8))") // 8진수로 출력
    /// ```
    ///
    /// 파일 크기 확인 후 읽기:
    /// ```swift
    /// let info = try fs.getFileInfo(at: path)
    /// if info.size > 1_000_000_000 { // 1 GB
    ///     print("큰 파일입니다. 시간이 걸릴 수 있습니다.")
    /// }
    /// let data = try fs.readFile(at: path)
    /// ```
    func getFileInfo(at path: String) throws -> EXT4FileInfo

    /// @brief 파일 삭제
    /// @param path 삭제할 파일 경로
    /// @throws EXT4Error
    ///   - .notMounted: 마운트되지 않음
    ///   - .fileNotFound: 파일이 존재하지 않음
    ///   - .permissionDenied: 권한 부족
    /// @details 참고: 블랙박스 플레이어는 읽기 전용이므로 거의 사용되지 않습니다.
    func deleteFile(at path: String) throws

    /// @brief 디렉토리 생성
    /// @param path 생성할 디렉토리 경로
    /// @throws EXT4Error
    ///   - .notMounted: 마운트되지 않음
    ///   - .writeFailed: 생성 실패
    ///   - .permissionDenied: 권한 부족
    /// @details 참고: 블랙박스 플레이어는 읽기 전용이므로 거의 사용되지 않습니다.
    func createDirectory(at path: String) throws

    // MARK: - Async Operations (for future use)

    /*
     ───────────────────────────────────────────────────────────────────────
     비동기 작업
     ───────────────────────────────────────────────────────────────────────

     【Swift Concurrency】
     macOS 12.0+에서 도입된 async/await 기반 동시성 모델입니다.

     장점:
     1. 메인 스레드 블로킹 방지 (UI 응답성 유지)
     2. 순차적 코드처럼 읽기 쉬움 (콜백 지옥 회피)
     3. 자동 스레드 관리 (GCD보다 효율적)

     사용 시나리오:
     - 큰 파일 읽기 (수백 MB ~ GB)
     - UI에서 파일 로드
     - 여러 파일 동시 읽기

     예시:
     ```swift
     Task {
         do {
             // UI 스레드 블로킹 없이 파일 읽기
             let data = try await fs.readFileAsync(at: "LargeVideo.mp4")

             // UI 업데이트 (자동으로 메인 스레드에서 실행)
             await MainActor.run {
                 self.videoData = data
                 self.isLoading = false
             }
         } catch {
             print("로드 실패: \(error)")
         }
     }
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 비동기로 파일 읽기
    /// @param path 파일 경로
    /// @return 파일 내용 (Data)
    /// @throws EXT4Error
    /// @details 큰 파일을 읽을 때 UI 스레드를 블로킹하지 않습니다.
    ///
    /// 사용 예시:
    /// ```swift
    /// @MainActor
    /// class VideoLoader {
    ///     var isLoading = false
    ///     var videoData: Data?
    ///
    ///     func loadVideo(fs: EXT4FileSystemProtocol, path: String) async {
    ///         isLoading = true
    ///         defer { isLoading = false }
    ///
    ///         do {
    ///             videoData = try await fs.readFileAsync(at: path)
    ///         } catch {
    ///             print("로드 실패: \(error)")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// 여러 파일 동시 읽기:
    /// ```swift
    /// let paths = ["Video001.mp4", "Video002.mp4", "Video003.mp4"]
    /// let dataArray = try await withThrowingTaskGroup(of: Data.self) { group in
    ///     for path in paths {
    ///         group.addTask {
    ///             try await fs.readFileAsync(at: path)
    ///         }
    ///     }
    ///
    ///     var results: [Data] = []
    ///     for try await data in group {
    ///         results.append(data)
    ///     }
    ///     return results
    /// }
    /// ```
    @available(macOS 12.0, *)
    func readFileAsync(at path: String) async throws -> Data
}

// MARK: - Default Implementations

/*
 ───────────────────────────────────────────────────────────────────────────
 프로토콜 확장 (Protocol Extension)
 ───────────────────────────────────────────────────────────────────────────

 【프로토콜 확장이란?】
 프로토콜에 기본 구현을 제공하는 Swift의 강력한 기능입니다.

 장점:
 1. 코드 재사용: 모든 구현체가 공통 기능 사용
 2. 선택적 구현: 필요하면 override 가능
 3. 인터페이스 확장: 기존 코드 수정 없이 기능 추가

 비유:
 - 인터페이스(Protocol): "이런 기능을 제공해야 합니다"
 - 프로토콜 확장: "기본 구현은 이렇게 하면 됩니다"

 여기서는 두 가지 헬퍼 함수를 제공:
 1. readFileAsync: 동기 readFile을 비동기로 래핑
 2. normalizePath: 경로 정규화 (공통 로직)
 ───────────────────────────────────────────────────────────────────────────
 */

extension EXT4FileSystemProtocol {

    /*
     ───────────────────────────────────────────────────────────────────────
     비동기 읽기의 기본 구현
     ───────────────────────────────────────────────────────────────────────

     【withCheckedThrowingContinuation이란?】
     기존 콜백 기반 코드를 async/await로 변환하는 Swift의 브리지입니다.

     동작 흐름:
     1. async 함수가 호출됨
     2. continuation 객체 생성 (실행 재개 지점 표시)
     3. DispatchQueue.global()에서 동기 작업 실행
     4. 성공: continuation.resume(returning: data)
     5. 실패: continuation.resume(throwing: error)
     6. async 함수가 결과 반환

     비유:
     continuation = "여기서 다시 시작하세요" 라는 책갈피

     【DispatchQueue.global(qos: .userInitiated)】
     QoS (Quality of Service) 레벨:
     - .userInteractive: 최고 우선순위 (UI 즉시 반영)
     - .userInitiated: 높음 (사용자가 시작한 작업)  ←── 여기
     - .default: 보통
     - .utility: 낮음 (진행률 표시가 있는 작업)
     - .background: 최저 (백업, 동기화 등)

     userInitiated를 선택한 이유:
     - 사용자가 파일 로드를 명시적으로 요청
     - 빠른 응답이 필요하지만 UI만큼 긴급하지는 않음
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 비동기 파일 읽기의 기본 구현
    /// @param path 파일 경로
    /// @return 파일 데이터
    /// @throws EXT4Error
    /// @details 동기 readFile()을 백그라운드 스레드에서 실행하여 비동기로 변환합니다.
    ///
    /// 동작 방식:
    /// 1. withCheckedThrowingContinuation으로 continuation 생성
    /// 2. DispatchQueue.global()에서 readFile() 호출
    /// 3. 성공/실패 결과를 continuation으로 반환
    ///
    /// 참고:
    /// - 구현체에서 더 효율적인 비동기 I/O가 있다면 override 가능
    /// - 예: aio_read(), io_uring 등의 네이티브 비동기 I/O
    @available(macOS 12.0, *)
    func readFileAsync(at path: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            // 백그라운드 스레드에서 동기 읽기 실행
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try self.readFile(at: path)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     경로 정규화
     ───────────────────────────────────────────────────────────────────────

     【왜 경로 정규화가 필요한가?】

     사용자 입력이나 UI에서 전달된 경로는 다양한 형태일 수 있습니다:
     - "/DCIM/Video001.mp4"  (앞에 슬래시)
     - "DCIM/Video001.mp4/"  (뒤에 슬래시)
     - " DCIM/Video001.mp4 " (공백)

     이를 통일된 형태로 변환:
     → "DCIM/Video001.mp4"

     【정규화 규칙】
     1. 앞뒤 공백 제거
     2. 앞의 슬래시(/) 제거
     3. 뒤의 슬래시(/) 제거

     【예시】
     Input                      → Output
     ─────────────────────────────────────────
     "/DCIM/Video001.mp4"      → "DCIM/Video001.mp4"
     "DCIM/Video001.mp4/"      → "DCIM/Video001.mp4"
     "  /DCIM/  "              → "DCIM"
     "/"                       → "" (루트)
     ""                        → "" (루트)

     【루트 디렉토리】
     빈 문자열("")이 루트 디렉토리를 의미:
     listFiles(at: "") → 루트의 모든 파일/디렉토리
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 경로를 정규화 (앞뒤 슬래시 제거)
    /// @param path 원본 경로
    /// @return 정규화된 경로
    /// @details EXT4 작업에서 사용하는 경로는 마운트 포인트 기준 상대 경로입니다.
    /// 앞에 슬래시를 붙이지 않고 사용합니다.
    ///
    /// 변환 예시:
    /// ```swift
    /// normalizePath("/DCIM/Video001.mp4")   // "DCIM/Video001.mp4"
    /// normalizePath("DCIM/Video001.mp4/")   // "DCIM/Video001.mp4"
    /// normalizePath("  /DCIM/  ")           // "DCIM"
    /// normalizePath("/")                    // "" (루트)
    /// ```
    ///
    /// 사용 예시:
    /// ```swift
    /// func listFiles(at path: String) throws -> [EXT4FileInfo] {
    ///     let normalizedPath = normalizePath(path)
    ///     // ... C 라이브러리 호출
    /// }
    /// ```
    func normalizePath(_ path: String) -> String {
        // 1단계: 앞뒤 공백 제거
        var normalized = path.trimmingCharacters(in: .whitespaces)

        // 2단계: 앞의 슬래시 제거
        // hasPrefix는 O(1) 복잡도 (첫 문자만 확인)
        if normalized.hasPrefix("/") {
            normalized = String(normalized.dropFirst())
        }

        // 3단계: 뒤의 슬래시 제거
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        return normalized
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 가이드
 ═══════════════════════════════════════════════════════════════════════════

 【1. EXT4Bridge 구현】

 실제 C/C++ 라이브러리를 연결하는 구현체:

 ```swift
 class EXT4Bridge: EXT4FileSystemProtocol {
     private var mountContext: OpaquePointer?
     private var mountPath: String?

     func mount(devicePath: String) throws {
         // C 라이브러리 호출
         let result = ext2fs_open(devicePath, ...)
         if result != 0 {
             throw EXT4Error.mountFailed(reason: String(cString: strerror(result)))
         }
     }

     func readFile(at path: String) throws -> Data {
         let normalized = normalizePath(path)

         // 1. 경로 → inode 번호 변환
         var inode: ext2_ino_t = 0
         ext2fs_namei(mountContext, EXT2_ROOT_INO, ..., normalized, &inode)

         // 2. inode → 파일 내용 읽기
         var buffer = [UInt8](repeating: 0, count: size)
         ext2fs_file_read(file, &buffer, size, ...)

         return Data(buffer)
     }
 }
 ```

 【2. MockEXT4FileSystem 사용】

 테스트나 프로토타이핑:

 ```swift
 let mockFS = MockEXT4FileSystem()
 mockFS.addFile(path: "DCIM/Video001.mp4", data: dummyVideoData)
 mockFS.addFile(path: "GPS/20240115.nmea", data: dummyGPSData)

 // 실제 구현과 동일하게 사용
 let files = try mockFS.listFiles(at: "DCIM")
 let video = try mockFS.readFile(at: "DCIM/Video001.mp4")
 ```

 【3. FileManagerService 통합】

 ```swift
 class FileManagerService {
     private let fileSystem: EXT4FileSystemProtocol

     init(fileSystem: EXT4FileSystemProtocol = EXT4Bridge()) {
         self.fileSystem = fileSystem
     }

     func loadSDCard(devicePath: String) throws {
         try fileSystem.mount(devicePath: devicePath)

         let info = try fileSystem.getDeviceInfo()
         print("SD 카드 마운트: \(info.volumeName ?? "Unknown")")
         print("용량: \(info.totalSize / 1_000_000_000) GB")
     }

     func scanVideoFiles() throws -> [VideoFile] {
         let files = try fileSystem.listFiles(at: "DCIM")
         return files
             .filter { $0.name.hasSuffix(".mp4") }
             .map { VideoFile(from: $0) }
     }
 }
 ```

 【4. 오류 처리 패턴】

 ```swift
 func handleSDCard() {
     do {
         try fileSystem.mount(devicePath: "/dev/disk2s1")

         let files = try fileSystem.listFiles(at: "DCIM")
         print("\(files.count)개 파일 발견")

     } catch EXT4Error.deviceNotFound {
         showAlert("SD 카드를 찾을 수 없습니다. 연결을 확인하세요.")

     } catch EXT4Error.mountFailed(let reason) {
         showAlert("마운트 실패: \(reason)")

     } catch EXT4Error.corruptedFileSystem {
         showAlert("파일시스템이 손상되었습니다. Linux에서 복구하세요.")

     } catch {
         showAlert("알 수 없는 오류: \(error)")
     }
 }
 ```

 【5. 비동기 UI 통합】

 ```swift
 @MainActor
 class SDCardViewModel: ObservableObject {
     @Published var files: [EXT4FileInfo] = []
     @Published var isLoading = false

     private let fs: EXT4FileSystemProtocol

     func loadFiles(at path: String) async {
         isLoading = true
         defer { isLoading = false }

         do {
             // 백그라운드에서 파일 목록 로드
             let loadedFiles = try await withCheckedThrowingContinuation { continuation in
                 DispatchQueue.global().async {
                     do {
                         let files = try self.fs.listFiles(at: path)
                         continuation.resume(returning: files)
                     } catch {
                         continuation.resume(throwing: error)
                     }
                 }
             }

             // 메인 스레드에서 UI 업데이트
             self.files = loadedFiles

         } catch {
             print("로드 실패: \(error.localizedDescription)")
         }
     }
 }
 ```

 ═══════════════════════════════════════════════════════════════════════════
 */
