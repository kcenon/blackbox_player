/// @file FileManagerService.swift
/// @brief Service for managing video files (favorites, notes, deletion)
/// @author BlackboxPlayer Development Team
/// @details Service for managing video file metadata and operations

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                     FileManagerService 개요                              │
 │                                                                          │
 │  이 서비스는 블랙박스 비디오 파일의 메타데이터 관리 및 파일 연산을      │
 │  담당하는 핵심 서비스입니다.                                             │
 │                                                                          │
 │  【주요 기능】                                                           │
 │  1. 즐겨찾기 관리 (Favorites Management)                                 │
 │     - UserDefaults를 사용한 영구 저장                                    │
 │     - Set<String> 구조로 중복 없는 ID 관리                               │
 │                                                                          │
 │  2. 메모 관리 (Notes Management)                                         │
 │     - 비디오 파일별 텍스트 메모 저장                                     │
 │     - Dictionary<UUID, String> 구조                                      │
 │                                                                          │
 │  3. 파일 연산 (File Operations)                                          │
 │     - 삭제 (Delete): 모든 채널 파일 제거                                 │
 │     - 이동 (Move): 다른 디렉토리로 파일 이동                             │
 │     - 내보내기 (Export): 외부 위치로 복사                                │
 │                                                                          │
 │  4. 캐시 관리 (Cache Management)                                         │
 │     - 메모리 내 VideoFile 캐시                                           │
 │     - 5분 만료 시간, 1000개 크기 제한                                    │
 │     - NSLock으로 스레드 안전성 보장                                      │
 │                                                                          │
 │  5. 일괄 작업 (Batch Operations)                                         │
 │     - 여러 파일에 대한 즐겨찾기 설정                                     │
 │     - 여러 파일 삭제 및 오류 수집                                        │
 │                                                                          │
 │  【아키텍처 위치】                                                       │
 │                                                                          │
 │  Views (ContentView, MultiChannelPlayerView)                            │
 │    │                                                                     │
 │    ├─▶ FileManagerService ◀── 이 파일                                   │
 │    │     │                                                               │
 │    │     ├─▶ UserDefaults (favorites, notes 영구 저장)                  │
 │    │     ├─▶ FileManager (파일 시스템 연산)                             │
 │    │     └─▶ NSLock (캐시 동시 접근 제어)                               │
 │    │                                                                     │
 │    └─▶ FileScanner (파일 검색)                                          │
 │        └─▶ MetadataExtractor (메타데이터 추출)                          │
 │                                                                          │
 │  【데이터 흐름】                                                         │
 │                                                                          │
 │  사용자 액션                                                             │
 │      │                                                                   │
 │      ├── 즐겨찾기 토글                                                   │
 │      │      └─▶ setFavorite() → UserDefaults 저장                       │
 │      │                                                                   │
 │      ├── 메모 작성                                                       │
 │      │      └─▶ setNote() → UserDefaults 저장                           │
 │      │                                                                   │
 │      ├── 파일 삭제                                                       │
 │      │      └─▶ deleteVideoFile() → FileManager.removeItem()            │
 │      │                                                                   │
 │      └── 파일 이동/내보내기                                              │
 │             └─▶ moveVideoFile() / exportVideoFile()                     │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【UserDefaults란 무엇인가?】

 UserDefaults는 iOS/macOS에서 제공하는 간단한 키-값(Key-Value) 저장소입니다.
 앱의 설정이나 작은 데이터를 영구적으로 저장하는 데 사용됩니다.

 ┌────────────────────────────────────────────────┐
 │  UserDefaults (앱 종료 후에도 유지)            │
 │  ┌──────────────────────────────────────────┐  │
 │  │ Key: "com.blackboxplayer.favorites"      │  │
 │  │ Value: ["uuid-1", "uuid-2", "uuid-3"]    │  │
 │  │                                          │  │
 │  │ Key: "com.blackboxplayer.notes"          │  │
 │  │ Value: {                                 │  │
 │  │   "uuid-1": "고속도로 사고 영상",        │  │
 │  │   "uuid-2": "주차장 접촉 사고"           │  │
 │  │ }                                        │  │
 │  └──────────────────────────────────────────┘  │
 └────────────────────────────────────────────────┘

 장점:
 - 간단한 API (set, get 메서드)
 - 자동 직렬화/역직렬화
 - 앱 재시작 후에도 데이터 유지

 단점:
 - 대용량 데이터 저장 부적합 (수 KB 이하 권장)
 - 복잡한 쿼리 불가능
 - 스레드 안전하지만 느림

 사용 예시:
 ```swift
 // 저장
 userDefaults.set(["uuid-1", "uuid-2"], forKey: "favorites")

 // 불러오기
 let favorites = userDefaults.array(forKey: "favorites") as? [String]

 // 삭제
 userDefaults.removeObject(forKey: "favorites")
 ```

 【NSLock이란 무엇인가?】

 NSLock은 여러 스레드가 동시에 같은 데이터에 접근하는 것을 방지하는
 잠금 메커니즘입니다. "뮤텍스(Mutex)"라고도 불립니다.

 ┌──────────────────────────────────────────────────────────┐
 │  캐시 딕셔너리 (공유 자원)                               │
 │  fileCache: [String: CachedFileInfo]                     │
 │                                                          │
 │  스레드 A           NSLock          스레드 B             │
 │     │                │                │                  │
 │     ├─ lock() ──────▶│◀───────────────┤ (대기 중...)    │
 │     │                │                │                  │
 │     ├─ 캐시 읽기     │                │                  │
 │     │                │                │                  │
 │     ├─ unlock() ─────▶│                │                  │
 │     │                │                │                  │
 │     │                │◀─── lock() ────┤                  │
 │     │                │                │                  │
 │     │                │                ├─ 캐시 쓰기      │
 │     │                │                │                  │
 │     │                │◀─── unlock() ──┤                  │
 └──────────────────────────────────────────────────────────┘

 왜 필요한가?
 - SwiftUI는 멀티스레드 환경에서 동작
 - 메인 스레드(UI)와 백그라운드 스레드(파일 I/O)가 동시에 캐시에 접근
 - 동시 접근 시 데이터 손상 가능 (Race Condition)

 사용 패턴:
 ```swift
 cacheLock.lock()         // 1. 잠금 획득 (다른 스레드 대기)
 defer { cacheLock.unlock() }  // 2. 함수 종료 시 자동 해제

 // 3. 안전하게 캐시 접근
 fileCache[key] = value
 ```

 defer의 중요성:
 - return, throw로 함수가 중간에 종료되어도 unlock() 보장
 - 잠금을 해제하지 않으면 다른 스레드가 영원히 대기 (데드락)

 【캐시 LRU(Least Recently Used) 전략】

 캐시 크기가 제한(1000개)을 초과하면 가장 오래된 항목 20%를 제거합니다.

 ┌──────────────────────────────────────────────────────────┐
 │  캐시 상태 (1000개 항목)                                 │
 │  ┌───────────────────────────────────────────────────┐   │
 │  │ Key         │ CachedAt                            │   │
 │  ├───────────────────────────────────────────────────┤   │
 │  │ file_001.mp4│ 2025-01-15 10:00:00 ◀── 가장 오래됨 │   │
 │  │ file_002.mp4│ 2025-01-15 10:01:23                 │   │
 │  │ file_003.mp4│ 2025-01-15 10:02:45                 │   │
 │  │ ...         │ ...                                 │   │
 │  │ file_999.mp4│ 2025-01-15 14:58:12                 │   │
 │  │ file_1000.mp4│2025-01-15 15:00:00 ◀── 가장 최근   │   │
 │  └───────────────────────────────────────────────────┘   │
 │                                                          │
 │  새 항목 추가 시 (1001개가 됨)                           │
 │  ↓                                                       │
 │  1. cachedAt 기준으로 정렬                               │
 │  2. 가장 오래된 200개 (20%) 제거                         │
 │  3. 새 항목 추가 (총 801개가 됨)                         │
 └──────────────────────────────────────────────────────────┘

 왜 20%를 제거하는가?
 - 한 번에 많이 제거하여 제거 빈도 감소
 - CPU 오버헤드 최소화
 - 메모리 여유 공간 확보

 캐시 만료 시간 (5분):
 - 파일 메타데이터는 자주 변하지 않음
 - 5분 이내 재접근 시 디스크 I/O 절약
 - 5분 경과 시 최신 정보 재로딩
 */

import Foundation

/*
 【FileManagerService 클래스】

 비디오 파일의 메타데이터와 파일 시스템 연산을 관리하는 서비스입니다.

 주요 책임:
 1. 즐겨찾기 상태 관리 (isFavorite)
 2. 파일별 메모 관리 (notes)
 3. 파일 삭제/이동/내보내기
 4. VideoFile 정보 캐싱 (성능 최적화)
 5. 일괄 작업 지원 (여러 파일 동시 처리)

 설계 패턴:
 - **Service Layer Pattern**: 비즈니스 로직을 View에서 분리
 - **Repository Pattern**: 데이터 저장소(UserDefaults) 추상화
 - **Cache Pattern**: 자주 사용하는 데이터를 메모리에 보관

 의존성:
 - UserDefaults: 즐겨찾기/메모 영구 저장
 - FileManager: 파일 시스템 연산 (삭제/이동/복사)
 - NSLock: 멀티스레드 환경에서 캐시 보호
 */
/// @class FileManagerService
/// @brief Service for managing video file metadata and operations
/// @details 비디오 파일의 메타데이터와 파일 시스템 연산을 관리하는 서비스입니다.
class FileManagerService {
    // MARK: - Properties

    /*
     【UserDefaults 인스턴스】

     앱의 설정과 작은 데이터를 영구적으로 저장하는 키-값 저장소입니다.

     저장 위치:
     - macOS: ~/Library/Preferences/[BundleID].plist
     - iOS: /Library/Preferences/[BundleID].plist

     저장되는 데이터:
     1. favorites: 즐겨찾기한 비디오 파일 UUID 배열
     2. notes: 비디오 파일 UUID → 메모 텍스트 딕셔너리

     특징:
     - 앱 종료 후에도 데이터 유지
     - 자동 동기화 (변경 사항 즉시 디스크에 저장)
     - 스레드 안전 (여러 스레드에서 동시 접근 가능)
     */
    /// @var userDefaults
    /// @brief UserDefaults instance for persistent storage
    private let userDefaults: UserDefaults

    /*
     【UserDefaults 키 (Key)】

     UserDefaults는 키-값 저장소이므로 데이터를 저장/불러올 때 사용할 키가 필요합니다.

     역방향 도메인 표기법 (Reverse Domain Notation):
     - "com.blackboxplayer.favorites"
     - 앱 식별자를 포함하여 다른 앱/라이브러리와 충돌 방지
     - Apple 권장 명명 규칙

     예시:
     ```swift
     // 저장
     userDefaults.set(["uuid-1"], forKey: "com.blackboxplayer.favorites")

     // 불러오기
     let favorites = userDefaults.array(forKey: "com.blackboxplayer.favorites")
     ```

     왜 상수로 선언하는가?
     - 오타 방지 (컴파일 타임 체크)
     - 키 변경 시 한 곳만 수정
     - 코드 자동 완성 지원
     */
    /// @var favoritesKey
    /// @brief UserDefaults key for favorites storage
    private let favoritesKey = "com.blackboxplayer.favorites"
    /// @var notesKey
    /// @brief UserDefaults key for notes storage
    private let notesKey = "com.blackboxplayer.notes"

    /*
     【파일 정보 캐시】

     VideoFile 객체를 메모리에 캐싱하여 반복적인 파일 I/O를 줄입니다.

     구조:
     - Key: 파일 경로 (String) - 예: "/path/to/video.mp4"
     - Value: CachedFileInfo - VideoFile + 캐시된 시간

     캐시 설정:
     - maxCacheAge: 5분 (300초) - 이 시간이 지나면 만료
     - maxCacheSize: 1000개 - 최대 캐시 항목 수

     캐시 히트 vs 미스:
     ┌───────────────────────────────────────────┐
     │  요청: "/videos/event/20250115_100000.mp4"│
     │    ↓                                      │
     │  캐시에 있는가?                            │
     │    ├─ 있음 & 5분 이내 → 캐시 히트 (반환) │
     │    ├─ 있음 & 5분 초과 → 만료 (재로딩)    │
     │    └─ 없음 → 캐시 미스 (파일 읽기)       │
     └───────────────────────────────────────────┘

     성능 효과:
     - 캐시 히트 시: 0.001초 (메모리 조회)
     - 캐시 미스 시: 0.1초 (디스크 I/O + 파싱)
     - 100배 속도 차이!
     */
    /// @var fileCache
    /// @brief File information cache
    private var fileCache: [String: CachedFileInfo] = [:]

    /*
     【NSLock - 스레드 안전성을 위한 잠금】

     fileCache는 여러 스레드에서 동시에 접근할 수 있습니다.
     예를 들어:
     - 메인 스레드: UI에서 캐시 읽기
     - 백그라운드 스레드: 파일 스캔 후 캐시 쓰기

     동시 접근 문제 (Race Condition):
     ```
     스레드 A                     스레드 B
     fileCache[key] 읽기 (nil)
     fileCache[key] = value1
     fileCache[key] = value2

     결과: value1이 손실됨!
     ```

     NSLock으로 해결:
     ```swift
     cacheLock.lock()  // 다른 스레드는 여기서 대기
     fileCache[key] = value
     cacheLock.unlock()  // 잠금 해제
     ```

     defer 패턴 사용:
     ```swift
     cacheLock.lock()
     defer { cacheLock.unlock() }  // 함수 종료 시 자동 실행

     // return이나 throw가 발생해도 unlock() 보장!
     if condition {
     return  // unlock() 자동 호출
     }
     ```
     */
    /// @var cacheLock
    /// @brief Lock for thread-safe cache access
    private let cacheLock = NSLock()

    /*
     【캐시 설정 상수】

     maxCacheAge: 5분 (300초)
     - 5분 동안은 캐시된 데이터 사용
     - 5분 후에는 파일에서 다시 읽기
     - 비디오 메타데이터는 자주 변하지 않으므로 5분이 적절

     maxCacheSize: 1000개
     - 약 1000개의 VideoFile 객체 저장 (약 10MB 메모리)
     - 1000개 초과 시 가장 오래된 20% (200개) 제거
     - 메모리 사용량 제한

     TimeInterval이란?
     - Swift의 시간 간격 타입
     - Double의 별칭 (typealias TimeInterval = Double)
     - 초 단위로 표현 (300 = 300초 = 5분)
     */
    /// @var maxCacheAge
    /// @brief Maximum cache age in seconds (5 minutes)
    private let maxCacheAge: TimeInterval = 300 // 5 minutes
    /// @var maxCacheSize
    /// @brief Maximum number of cached files
    private let maxCacheSize: Int = 1000 // Maximum cached files

    // MARK: - Initialization

    /*
     【초기화 메서드】

     FileManagerService 인스턴스를 생성합니다.

     매개변수:
     - userDefaults: UserDefaults 인스턴스 (기본값: .standard)

     기본값 패턴:
     ```swift
     init(userDefaults: UserDefaults = .standard)
     ```

     사용 예시:
     ```swift
     // 1. 기본 UserDefaults 사용
     let service = FileManagerService()

     // 2. 테스트용 UserDefaults 사용
     let testDefaults = UserDefaults(suiteName: "test")!
     let testService = FileManagerService(userDefaults: testDefaults)
     ```

     의존성 주입 (Dependency Injection):
     - UserDefaults를 외부에서 주입받음
     - 테스트 시 Mock UserDefaults 사용 가능
     - 유연한 설정 (앱 그룹 UserDefaults 등)
     */
    /// @brief Initialize FileManagerService
    /// @param userDefaults UserDefaults instance for storage (default: .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Favorites

    /*
     【즐겨찾기 확인 메서드】

     주어진 비디오 파일이 즐겨찾기에 등록되어 있는지 확인합니다.

     매개변수:
     - videoFile: 확인할 VideoFile 객체

     반환값:
     - true: 즐겨찾기에 있음
     - false: 즐겨찾기에 없음

     동작 순서:
     1. loadFavorites()로 UserDefaults에서 즐겨찾기 Set 불러오기
     2. videoFile.id.uuidString이 Set에 있는지 확인
     3. Set의 contains()는 O(1) 시간 복잡도

     Set vs Array:
     - Set: contains() = O(1) - 해시 테이블
     - Array: contains() = O(n) - 순차 검색

     사용 예시:
     ```swift
     let service = FileManagerService()
     let videoFile = VideoFile(...)

     if service.isFavorite(videoFile) {
     print("⭐ 즐겨찾기된 파일입니다")
     }
     ```
     */
    /// @brief Check if video file is marked as favorite
    /// @param videoFile VideoFile to check
    /// @return true if favorited
    func isFavorite(_ videoFile: VideoFile) -> Bool {
        let favorites = loadFavorites()  // UserDefaults에서 Set<String> 불러오기
        return favorites.contains(videoFile.id.uuidString)  // O(1) 시간 복잡도
    }

    /*
     【즐겨찾기 설정 메서드】

     비디오 파일의 즐겨찾기 상태를 변경합니다.

     매개변수:
     - videoFile: 대상 VideoFile 객체
     - isFavorite: 설정할 즐겨찾기 상태

     동작 순서:
     1. loadFavorites()로 현재 즐겨찾기 Set 불러오기
     2. isFavorite 값에 따라 Set에 추가 또는 제거
     3. saveFavorites()로 변경된 Set을 UserDefaults에 저장

     Set 연산:
     - insert(): 중복 자동 방지 (이미 있으면 무시)
     - remove(): 없으면 무시 (에러 없음)

     사용 예시:
     ```swift
     // 즐겨찾기 추가
     service.setFavorite(videoFile, isFavorite: true)

     // 즐겨찾기 제거
     service.setFavorite(videoFile, isFavorite: false)

     // 토글
     let currentState = service.isFavorite(videoFile)
     service.setFavorite(videoFile, isFavorite: !currentState)
     ```

     영속성:
     - UserDefaults에 저장되므로 앱 종료 후에도 유지
     - 자동 동기화 (변경 즉시 디스크에 기록)
     */
    /// @brief Set favorite status for video file
    /// @param videoFile VideoFile to update
    /// @param isFavorite New favorite status
    func setFavorite(_ videoFile: VideoFile, isFavorite: Bool) {
        var favorites = loadFavorites()  // 현재 즐겨찾기 Set 불러오기

        if isFavorite {
            // 즐겨찾기 추가: UUID를 String으로 변환하여 Set에 insert
            favorites.insert(videoFile.id.uuidString)
        } else {
            // 즐겨찾기 제거: Set에서 UUID String 제거
            favorites.remove(videoFile.id.uuidString)
        }

        saveFavorites(favorites)  // 변경된 Set을 UserDefaults에 저장
    }

    /*
     【모든 즐겨찾기 조회 메서드】

     현재 즐겨찾기에 등록된 모든 비디오 파일 ID를 반환합니다.

     반환값:
     - Set<String>: 즐겨찾기된 비디오 파일의 UUID 문자열 Set

     사용 예시:
     ```swift
     let favorites = service.getAllFavorites()
     print("즐겨찾기 개수: \(favorites.count)")

     // 특정 파일이 즐겨찾기인지 확인
     if favorites.contains("some-uuid-string") {
     print("즐겨찾기에 있습니다")
     }

     // 모든 즐겨찾기 파일 순회
     for uuid in favorites {
     print("즐겨찾기 파일 ID: \(uuid)")
     }
     ```

     왜 Set을 반환하는가?
     - 중복 없음 보장
     - contains() 연산이 빠름 (O(1))
     - 순서가 중요하지 않음
     */
    /// @brief Get all favorited video file IDs
    /// @return Set of video file UUIDs
    func getAllFavorites() -> Set<String> {
        return loadFavorites()  // UserDefaults에서 Set 불러오기
    }

    /*
     【모든 즐겨찾기 삭제 메서드】

     저장된 모든 즐겨찾기 정보를 삭제합니다.

     동작:
     - UserDefaults에서 favoritesKey에 해당하는 데이터 제거
     - 디스크에서도 완전히 삭제됨

     사용 예시:
     ```swift
     // 확인 다이얼로그 후 삭제
     let alert = NSAlert()
     alert.messageText = "모든 즐겨찾기를 삭제하시겠습니까?"
     alert.addButton(withTitle: "삭제")
     alert.addButton(withTitle: "취소")

     if alert.runModal() == .alertFirstButtonReturn {
     service.clearAllFavorites()
     print("즐겨찾기가 모두 삭제되었습니다")
     }
     ```

     주의:
     - 복구 불가능한 작업
     - 사용자에게 확인 받는 것이 좋음
     - 앱 재설치나 데이터 초기화 기능에 유용
     */
    /// @brief Clear all favorites
    func clearAllFavorites() {
        userDefaults.removeObject(forKey: favoritesKey)  // UserDefaults에서 키 제거
    }

    // MARK: - Notes

    /*
     【메모 조회 메서드】

     특정 비디오 파일에 저장된 메모를 가져옵니다.

     매개변수:
     - videoFile: 메모를 조회할 VideoFile 객체

     반환값:
     - String?: 저장된 메모 텍스트 (없으면 nil)

     동작 순서:
     1. loadNotes()로 [UUID: String] Dictionary 불러오기
     2. videoFile.id.uuidString을 키로 Dictionary 조회
     3. 값이 있으면 반환, 없으면 nil

     Dictionary 조회:
     - notes[key] 는 Optional<String>을 반환
     - 키가 없으면 자동으로 nil 반환

     사용 예시:
     ```swift
     if let note = service.getNote(for: videoFile) {
     print("메모: \(note)")
     } else {
     print("메모가 없습니다")
     }

     // nil 병합 연산자 사용
     let displayNote = service.getNote(for: videoFile) ?? "메모 없음"
     ```
     */
    /// @brief Get note for video file
    /// @param videoFile VideoFile to get note for
    /// @return Note text or nil if no note
    func getNote(for videoFile: VideoFile) -> String? {
        let notes = loadNotes()  // UserDefaults에서 Dictionary 불러오기
        return notes[videoFile.id.uuidString]  // Dictionary 조회 (없으면 nil)
    }

    /*
     【메모 설정 메서드】

     비디오 파일에 메모를 저장하거나 삭제합니다.

     매개변수:
     - videoFile: 대상 VideoFile 객체
     - note: 저장할 메모 텍스트 (nil이면 메모 삭제)

     동작 순서:
     1. loadNotes()로 현재 메모 Dictionary 불러오기
     2. note가 있고 비어있지 않으면 Dictionary에 추가
     3. note가 nil이거나 비어있으면 Dictionary에서 제거
     4. saveNotes()로 변경된 Dictionary를 UserDefaults에 저장

     빈 문자열 체크:
     - isEmpty: 길이가 0인지 확인
     - 공백만 있는 경우는 isEmpty = false
     - 공백 제거: note.trimmingCharacters(in: .whitespacesAndNewlines)

     사용 예시:
     ```swift
     // 메모 추가
     service.setNote(for: videoFile, note: "고속도로 사고 영상")

     // 메모 삭제 (nil)
     service.setNote(for: videoFile, note: nil)

     // 메모 삭제 (빈 문자열)
     service.setNote(for: videoFile, note: "")

     // 사용자 입력으로 메모 설정
     let userInput = textField.stringValue
     service.setNote(for: videoFile, note: userInput.isEmpty ? nil : userInput)
     ```
     */
    /// @brief Set note for video file
    /// @param videoFile VideoFile to set note for
    /// @param note Note text or nil to remove
    func setNote(for videoFile: VideoFile, note: String?) {
        var notes = loadNotes()  // 현재 메모 Dictionary 불러오기

        if let note = note, !note.isEmpty {
            // 메모가 있고 비어있지 않으면 Dictionary에 추가
            notes[videoFile.id.uuidString] = note
        } else {
            // 메모가 nil이거나 빈 문자열이면 Dictionary에서 제거
            notes.removeValue(forKey: videoFile.id.uuidString)
        }

        saveNotes(notes)  // 변경된 Dictionary를 UserDefaults에 저장
    }

    /*
     【모든 메모 조회 메서드】

     저장된 모든 비디오 파일의 메모를 반환합니다.

     반환값:
     - [String: String]: UUID → 메모 텍스트 Dictionary

     사용 예시:
     ```swift
     let allNotes = service.getAllNotes()
     print("총 메모 개수: \(allNotes.count)")

     // 모든 메모 순회
     for (uuid, note) in allNotes {
     print("파일 \(uuid): \(note)")
     }

     // 특정 UUID의 메모 확인
     if let note = allNotes["some-uuid-string"] {
     print("메모: \(note)")
     }
     ```

     사용 사례:
     - 메모가 있는 파일 필터링
     - 메모 검색 기능
     - 통계 표시 (메모가 있는 파일 개수)
     */
    /// @brief Get all notes
    /// @return Dictionary of video file UUID to note
    func getAllNotes() -> [String: String] {
        return loadNotes()  // UserDefaults에서 Dictionary 불러오기
    }

    /*
     【모든 메모 삭제 메서드】

     저장된 모든 메모를 삭제합니다.

     동작:
     - UserDefaults에서 notesKey에 해당하는 데이터 제거
     - 디스크에서도 완전히 삭제됨

     사용 예시:
     ```swift
     // 확인 다이얼로그 후 삭제
     let alert = NSAlert()
     alert.messageText = "모든 메모를 삭제하시겠습니까?"
     alert.addButton(withTitle: "삭제")
     alert.addButton(withTitle: "취소")

     if alert.runModal() == .alertFirstButtonReturn {
     service.clearAllNotes()
     print("메모가 모두 삭제되었습니다")
     }
     ```

     주의:
     - 복구 불가능한 작업
     - 사용자에게 확인 받는 것이 좋음
     - 앱 재설치나 데이터 초기화 기능에 유용
     */
    /// @brief Clear all notes
    func clearAllNotes() {
        userDefaults.removeObject(forKey: notesKey)  // UserDefaults에서 키 제거
    }

    // MARK: - File Operations

    /*
     【파일 삭제 메서드】

     비디오 파일의 모든 채널을 디스크에서 삭제하고, 관련 메타데이터(즐겨찾기, 메모)도 제거합니다.

     매개변수:
     - videoFile: 삭제할 VideoFile 객체

     예외:
     - Error: 파일 삭제 실패 시 throw

     동작 순서:
     1. FileManager 인스턴스 획득
     2. 모든 채널 파일 순회
     3. 각 파일 존재 확인 후 삭제
     4. 즐겨찾기에서 제거
     5. 메모 제거

     채널 파일 예시:
     ```
     videoFile.channels = [
     ChannelInfo(filePath: "/videos/20250115_100000_F.mp4"),  // 전방
     ChannelInfo(filePath: "/videos/20250115_100000_R.mp4"),  // 후방
     ]
     ```

     에러 처리:
     ```swift
     do {
     try service.deleteVideoFile(videoFile)
     print("파일이 삭제되었습니다")
     } catch {
     print("삭제 실패: \(error.localizedDescription)")
     }
     ```

     FileManager.removeItem(atPath:):
     - 파일 또는 디렉토리 삭제
     - 파일이 없으면 에러 발생
     - 디렉토리인 경우 내용물도 모두 삭제
     */
    /// @brief Delete video file and all its channels
    /// @param videoFile VideoFile to delete
    /// @throws Error if deletion fails
    func deleteVideoFile(_ videoFile: VideoFile) throws {
        let fileManager = FileManager.default  // 파일 시스템 연산을 위한 FileManager

        // Delete all channel files
        // 모든 채널 파일을 순회하며 삭제
        for channel in videoFile.channels {
            let filePath = channel.filePath  // 채널 파일 경로 추출

            // 파일 존재 여부 확인
            if fileManager.fileExists(atPath: filePath) {
                // 파일이 존재하면 삭제 (에러 발생 시 throw)
                try fileManager.removeItem(atPath: filePath)
            }
        }

        // Remove from favorites and notes
        // 즐겨찾기와 메모에서도 제거
        setFavorite(videoFile, isFavorite: false)  // 즐겨찾기 해제
        setNote(for: videoFile, note: nil)  // 메모 삭제
    }

    /*
     【파일 이동 메서드】

     비디오 파일의 모든 채널을 다른 디렉토리로 이동하고, 새 경로로 업데이트된 VideoFile을 반환합니다.

     매개변수:
     - videoFile: 이동할 VideoFile 객체
     - destinationURL: 대상 디렉토리 URL

     반환값:
     - VideoFile: 새 경로로 업데이트된 VideoFile 객체

     예외:
     - Error: 파일 이동 실패 시 throw

     동작 순서:
     1. 대상 디렉토리가 없으면 생성
     2. 각 채널 파일을 새 위치로 이동
     3. 새 경로로 ChannelInfo 객체 생성
     4. 새 채널 배열로 VideoFile 객체 생성
     5. 업데이트된 VideoFile 반환

     사용 예시:
     ```swift
     let sourceFile = VideoFile(basePath: "/videos/event/")
     let destination = URL(fileURLWithPath: "/videos/archive/")

     do {
     let movedFile = try service.moveVideoFile(sourceFile, to: destination)
     print("파일이 이동되었습니다: \(movedFile.basePath)")
     } catch {
     print("이동 실패: \(error.localizedDescription)")
     }
     ```

     이동 vs 복사:
     - moveItem(): 원본 삭제, 빠름
     - copyItem(): 원본 유지, 느림

     디렉토리 생성:
     - createDirectory(withIntermediateDirectories: true)
     - 중간 디렉토리도 자동 생성 (/a/b/c 생성 시 /a, /a/b도 생성)
     */
    /// @brief Move video file to different directory
    /// @param videoFile VideoFile to move
    /// @param destinationURL Destination directory URL
    /// @return Updated VideoFile with new paths
    /// @throws Error if move fails
    func moveVideoFile(_ videoFile: VideoFile, to destinationURL: URL) throws -> VideoFile {
        let fileManager = FileManager.default  // 파일 시스템 연산을 위한 FileManager

        // Create destination directory if needed
        // 대상 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: true  // 중간 경로도 자동 생성
            )
        }

        // Move all channel files
        // 모든 채널 파일을 새 위치로 이동하고, 새 ChannelInfo 배열 생성
        var newChannels: [ChannelInfo] = []

        for channel in videoFile.channels {
            let sourceURL = URL(fileURLWithPath: channel.filePath)  // 현재 파일 경로
            let filename = sourceURL.lastPathComponent  // 파일명 추출 (예: "20250115_100000_F.mp4")
            let destinationFileURL = destinationURL.appendingPathComponent(filename)  // 새 경로 생성

            // Move file
            // 파일을 새 위치로 이동 (원본은 삭제됨)
            try fileManager.moveItem(at: sourceURL, to: destinationFileURL)

            // Create new ChannelInfo with updated path
            // 새 경로로 ChannelInfo 객체 생성
            let newChannel = ChannelInfo(
                id: channel.id,
                position: channel.position,
                filePath: destinationFileURL.path,  // 업데이트된 파일 경로
                width: channel.width,
                height: channel.height,
                frameRate: channel.frameRate,
                bitrate: channel.bitrate,
                codec: channel.codec,
                audioCodec: channel.audioCodec,
                isEnabled: channel.isEnabled,
                fileSize: channel.fileSize,
                duration: channel.duration
            )

            newChannels.append(newChannel)  // 새 채널 배열에 추가
        }

        // Create new VideoFile with updated paths
        // 새 채널 배열로 VideoFile 객체 생성하여 반환
        return VideoFile(
            id: videoFile.id,
            timestamp: videoFile.timestamp,
            eventType: videoFile.eventType,
            duration: videoFile.duration,
            channels: newChannels,  // 업데이트된 채널 배열
            metadata: videoFile.metadata,
            basePath: destinationURL.path,  // 업데이트된 기본 경로
            isFavorite: videoFile.isFavorite,
            notes: videoFile.notes,
            isCorrupted: videoFile.isCorrupted
        )
    }

    /*
     【파일 내보내기 메서드】

     비디오 파일의 모든 채널을 외부 위치로 복사합니다.
     원본 파일은 그대로 유지됩니다.

     매개변수:
     - videoFile: 내보낼 VideoFile 객체
     - destinationURL: 대상 디렉토리 URL

     예외:
     - Error: 파일 복사 실패 시 throw

     동작 순서:
     1. 대상 디렉토리가 없으면 생성
     2. 각 채널 파일을 새 위치로 복사
     3. 원본 파일은 그대로 유지

     사용 예시:
     ```swift
     let videoFile = VideoFile(...)
     let exportPath = URL(fileURLWithPath: "/Users/user/Desktop/export/")

     do {
     try service.exportVideoFile(videoFile, to: exportPath)
     print("파일이 내보내기되었습니다")
     } catch {
     print("내보내기 실패: \(error.localizedDescription)")
     }
     ```

     이동(move) vs 내보내기(export):
     - move: 원본 삭제, 빠름, 같은 볼륨 내에서만 가능
     - export: 원본 유지, 느림, 다른 볼륨으로도 가능

     진행 상황 표시:
     ```swift
     let totalFiles = videoFile.channels.count
     var completedFiles = 0

     for channel in videoFile.channels {
     // 복사 작업...
     completedFiles += 1
     let progress = Double(completedFiles) / Double(totalFiles)
     print("진행률: \(Int(progress * 100))%")
     }
     ```
     */
    /// @brief Export video file to external location
    /// @param videoFile VideoFile to export
    /// @param destinationURL Export destination URL
    /// @throws Error if export fails
    func exportVideoFile(_ videoFile: VideoFile, to destinationURL: URL) throws {
        let fileManager = FileManager.default  // 파일 시스템 연산을 위한 FileManager

        // Create destination directory if needed
        // 대상 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: true  // 중간 경로도 자동 생성
            )
        }

        // Copy all channel files
        // 모든 채널 파일을 새 위치로 복사 (원본 유지)
        for channel in videoFile.channels {
            let sourceURL = URL(fileURLWithPath: channel.filePath)  // 원본 파일 경로
            let filename = sourceURL.lastPathComponent  // 파일명 추출
            let destinationFileURL = destinationURL.appendingPathComponent(filename)  // 대상 파일 경로

            // Copy file
            // 파일 복사 (원본은 그대로 유지)
            try fileManager.copyItem(at: sourceURL, to: destinationFileURL)
        }
    }

    /*
     【총 파일 크기 계산 메서드】

     여러 비디오 파일의 총 크기를 바이트 단위로 계산합니다.

     매개변수:
     - videoFiles: VideoFile 객체 배열

     반환값:
     - UInt64: 총 파일 크기 (바이트)

     동작:
     - reduce() 함수로 모든 파일의 totalFileSize를 합산

     reduce() 함수 설명:
     ```swift
     let numbers = [1, 2, 3, 4, 5]
     let sum = numbers.reduce(0) { total, number in
     return total + number
     }
     // sum = 15
     ```

     사용 예시:
     ```swift
     let files = [videoFile1, videoFile2, videoFile3]
     let totalSize = service.getTotalSize(of: files)

     // 바이트를 사람이 읽기 쉬운 형식으로 변환
     let formatter = ByteCountFormatter()
     formatter.countStyle = .file
     let readableSize = formatter.string(fromByteCount: Int64(totalSize))
     print("총 크기: \(readableSize)")  // "총 크기: 1.5 GB"
     ```

     UInt64란?
     - 64비트 부호 없는 정수 (0 ~ 18,446,744,073,709,551,615)
     - 최대 18 엑사바이트 (18,000,000 테라바이트) 표현 가능
     - 파일 크기 표현에 적합
     */
    /// @brief Get total size of all video files
    /// @param videoFiles Array of video files
    /// @return Total size in bytes
    func getTotalSize(of videoFiles: [VideoFile]) -> UInt64 {
        return videoFiles.reduce(0) { total, file in
            total + file.totalFileSize  // 각 파일의 크기를 누적 합산
        }
    }

    /*
     【사용 가능한 디스크 공간 조회 메서드】

     지정된 경로의 볼륨에서 사용 가능한 디스크 공간을 조회합니다.

     매개변수:
     - path: 확인할 경로 (파일 또는 디렉토리)

     반환값:
     - UInt64?: 사용 가능한 공간 (바이트) 또는 nil (실패 시)

     동작 순서:
     1. 경로를 URL로 변환
     2. resourceValues(forKeys:)로 볼륨 정보 조회
     3. volumeAvailableCapacityKey로 사용 가능 공간 추출
     4. Int를 UInt64로 변환하여 반환

     사용 예시:
     ```swift
     if let availableSpace = service.getAvailableDiskSpace(at: "/videos") {
     let formatter = ByteCountFormatter()
     formatter.countStyle = .file
     let readable = formatter.string(fromByteCount: Int64(availableSpace))
     print("사용 가능: \(readable)")

     // 공간 부족 확인
     let requiredSpace: UInt64 = 1_000_000_000  // 1 GB
     if availableSpace < requiredSpace {
     print("경고: 디스크 공간이 부족합니다")
     }
     } else {
     print("디스크 공간을 확인할 수 없습니다")
     }
     ```

     resourceValues(forKeys:)란?
     - URL의 메타데이터를 조회하는 메서드
     - 파일 크기, 생성 날짜, 볼륨 정보 등
     - throws 키워드로 에러 발생 가능

     volumeAvailableCapacityKey:
     - 사용자가 실제로 사용할 수 있는 공간
     - 시스템 예약 공간 제외
     - macOS: 일반적으로 전체 용량의 80-90%
     */
    /// @brief Get available disk space at path
    /// @param path Path to check
    /// @return Available space in bytes or nil if cannot determine
    func getAvailableDiskSpace(at path: String) -> UInt64? {
        do {
            let url = URL(fileURLWithPath: path)  // 경로를 URL로 변환

            // 볼륨 정보 조회
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])

            // 사용 가능 공간 추출 및 UInt64로 변환
            return values.volumeAvailableCapacity.map { UInt64($0) }
        } catch {
            // 에러 발생 시 nil 반환
            return nil
        }
    }

    // MARK: - Batch Operations

    /*
     【일괄 즐겨찾기 설정 메서드】

     여러 비디오 파일에 대해 즐겨찾기 상태를 일괄 설정합니다.

     매개변수:
     - videoFiles: VideoFile 객체 배열
     - isFavorite: 설정할 즐겨찾기 상태

     동작 순서:
     1. 현재 즐겨찾기 Set 불러오기
     2. 모든 파일을 순회하며 Set에 추가/제거
     3. 한 번에 saveFavorites() 호출

     성능 최적화:
     - 개별 호출 방식:
     ```swift
     for file in files {
     service.setFavorite(file, isFavorite: true)  // 매번 저장
     }
     // UserDefaults 저장: 1000번 (파일 1000개인 경우)
     ```

     - 일괄 호출 방식:
     ```swift
     service.setFavorite(for: files, isFavorite: true)
     // UserDefaults 저장: 1번
     ```

     사용 예시:
     ```swift
     let selectedFiles = [videoFile1, videoFile2, videoFile3]

     // 선택한 파일들을 모두 즐겨찾기에 추가
     service.setFavorite(for: selectedFiles, isFavorite: true)
     print("\(selectedFiles.count)개 파일이 즐겨찾기에 추가되었습니다")

     // 선택한 파일들을 모두 즐겨찾기에서 제거
     service.setFavorite(for: selectedFiles, isFavorite: false)
     ```
     */
    /// @brief Apply favorite status to multiple files
    /// @param videoFiles Array of video files
    /// @param isFavorite Favorite status to apply
    func setFavorite(for videoFiles: [VideoFile], isFavorite: Bool) {
        var favorites = loadFavorites()  // 현재 즐겨찾기 Set 불러오기

        // 모든 파일을 순회하며 Set에 추가 또는 제거
        for videoFile in videoFiles {
            if isFavorite {
                favorites.insert(videoFile.id.uuidString)  // 즐겨찾기 추가
            } else {
                favorites.remove(videoFile.id.uuidString)  // 즐겨찾기 제거
            }
        }

        saveFavorites(favorites)  // 한 번에 UserDefaults에 저장 (성능 최적화)
    }

    /*
     【일괄 파일 삭제 메서드】

     여러 비디오 파일을 삭제하고, 발생한 에러들을 수집하여 반환합니다.

     매개변수:
     - videoFiles: 삭제할 VideoFile 객체 배열

     반환값:
     - [Error]: 발생한 에러 배열 (비어있으면 모두 성공)

     동작 순서:
     1. 에러 배열 초기화
     2. 각 파일에 대해 deleteVideoFile() 호출
     3. 에러 발생 시 배열에 추가
     4. 모든 파일 처리 후 에러 배열 반환

     사용 예시:
     ```swift
     let selectedFiles = [videoFile1, videoFile2, videoFile3]
     let errors = service.deleteVideoFiles(selectedFiles)

     if errors.isEmpty {
     print("\(selectedFiles.count)개 파일이 모두 삭제되었습니다")
     } else {
     print("삭제 완료: \(selectedFiles.count - errors.count)개")
     print("실패: \(errors.count)개")

     for error in errors {
     print("에러: \(error.localizedDescription)")
     }
     }
     ```

     에러 처리 전략:
     - 하나의 파일 삭제 실패해도 나머지 파일 계속 삭제
     - 모든 에러를 수집하여 사용자에게 알림
     - 부분 성공 허용 (일부만 삭제 성공)

     try-catch vs do-catch:
     ```swift
     // 개별 에러 처리 (현재 방식)
     for file in files {
     do {
     try deleteVideoFile(file)
     } catch {
     errors.append(error)  // 에러 수집 후 계속 진행
     }
     }

     // 전체 에러 처리 (사용하지 않음)
     do {
     for file in files {
     try deleteVideoFile(file)  // 하나 실패 시 중단
     }
     } catch {
     // 첫 번째 에러만 처리
     }
     ```
     */
    /// @brief Delete multiple video files
    /// @param videoFiles Array of video files to delete
    /// @return Array of errors (empty if all successful)
    func deleteVideoFiles(_ videoFiles: [VideoFile]) -> [Error] {
        var errors: [Error] = []  // 발생한 에러를 저장할 배열

        // 모든 파일을 순회하며 삭제 시도
        for videoFile in videoFiles {
            do {
                try deleteVideoFile(videoFile)  // 파일 삭제
            } catch {
                errors.append(error)  // 에러 발생 시 배열에 추가하고 계속 진행
            }
        }

        return errors  // 발생한 모든 에러 반환 (비어있으면 모두 성공)
    }

    // MARK: - Private Methods

    /*
     【즐겨찾기 불러오기 (Private)】

     UserDefaults에서 즐겨찾기 Set을 불러옵니다.

     반환값:
     - Set<String>: 즐겨찾기된 비디오 파일 UUID Set (없으면 빈 Set)

     동작 순서:
     1. userDefaults.array(forKey:)로 배열 조회
     2. [String] 타입으로 캐스팅 시도
     3. 성공하면 Set으로 변환하여 반환
     4. 실패하면 빈 Set 반환

     UserDefaults 저장 형식:
     - Set은 직접 저장 불가능
     - Array로 변환하여 저장: Array(favorites)
     - 불러올 때 다시 Set으로 변환: Set(array)

     as? [String] 캐스팅:
     - 타입 안전성 보장
     - 잘못된 타입이면 nil 반환
     - nil이면 기본값(빈 Set) 사용

     왜 private인가?
     - 내부 구현 세부사항 (UserDefaults 사용)
     - 외부에서는 getAllFavorites() 사용
     - 캡슐화: 구현 변경 시 public API 영향 없음
     */
    private func loadFavorites() -> Set<String> {
        // UserDefaults에서 배열로 불러온 후 Set으로 변환
        if let array = userDefaults.array(forKey: favoritesKey) as? [String] {
            return Set(array)  // 배열을 Set으로 변환
        }
        return []  // 데이터가 없으면 빈 Set 반환
    }

    /*
     【즐겨찾기 저장 (Private)】

     즐겨찾기 Set을 UserDefaults에 저장합니다.

     매개변수:
     - favorites: 저장할 즐겨찾기 Set<String>

     동작:
     1. Set을 Array로 변환: Array(favorites)
     2. userDefaults.set()으로 저장
     3. 자동으로 디스크에 동기화됨

     Set → Array 변환 이유:
     - UserDefaults는 Property List 타입만 저장 가능
     - Property List 타입: Array, Dictionary, String, Number, Date, Data
     - Set은 Property List 타입이 아님
     - 따라서 Array로 변환 필요

     자동 동기화:
     - UserDefaults는 변경 사항을 자동으로 디스크에 저장
     - synchronize() 호출 불필요 (iOS 7 이후)
     - 앱 종료 시 자동으로 저장됨
     */
    private func saveFavorites(_ favorites: Set<String>) {
        // Set을 Array로 변환하여 UserDefaults에 저장
        userDefaults.set(Array(favorites), forKey: favoritesKey)
    }

    /*
     【메모 불러오기 (Private)】

     UserDefaults에서 메모 Dictionary를 불러옵니다.

     반환값:
     - [String: String]: UUID → 메모 텍스트 Dictionary (없으면 빈 Dictionary)

     동작 순서:
     1. userDefaults.dictionary(forKey:)로 Dictionary 조회
     2. [String: String] 타입으로 캐스팅 시도
     3. 성공하면 반환
     4. 실패하면 빈 Dictionary 반환

     dictionary(forKey:) vs object(forKey:):
     - dictionary(forKey:): [String: Any] 반환
     - object(forKey:): Any? 반환
     - dictionary는 타입이 보장되어 더 안전

     as? [String: String] 캐스팅:
     - Dictionary의 모든 값이 String인지 확인
     - 하나라도 다른 타입이면 nil 반환
     - 타입 안전성 보장
     */
    private func loadNotes() -> [String: String] {
        // UserDefaults에서 Dictionary 불러오기
        if let dictionary = userDefaults.dictionary(forKey: notesKey) as? [String: String] {
            return dictionary  // Dictionary 반환
        }
        return [:]  // 데이터가 없으면 빈 Dictionary 반환
    }

    /*
     【메모 저장 (Private)】

     메모 Dictionary를 UserDefaults에 저장합니다.

     매개변수:
     - notes: 저장할 메모 Dictionary [UUID: 메모텍스트]

     동작:
     - userDefaults.set()으로 Dictionary 저장
     - 자동으로 디스크에 동기화됨

     Dictionary 저장:
     - Dictionary는 Property List 타입
     - [String: String]은 직접 저장 가능
     - 변환 없이 바로 저장

     빈 Dictionary 저장:
     - 모든 메모를 삭제해도 빈 Dictionary 저장됨
     - 완전히 제거하려면 removeObject(forKey:) 사용
     - 하지만 빈 Dictionary도 문제없음 (작은 크기)
     */
    private func saveNotes(_ notes: [String: String]) {
        // Dictionary를 UserDefaults에 저장
        userDefaults.set(notes, forKey: notesKey)
    }

    // MARK: - File Cache

    /*
     【캐시된 파일 정보 조회 메서드】

     메모리 캐시에서 파일 정보를 조회합니다.

     매개변수:
     - filePath: 파일 경로 (캐시 키로 사용)

     반환값:
     - VideoFile?: 캐시된 VideoFile (없거나 만료되면 nil)

     동작 순서:
     1. NSLock으로 캐시 잠금
     2. defer로 unlock() 보장
     3. filePath로 캐시 조회
     4. 캐시가 있으면 만료 여부 확인
     5. 만료되지 않았으면 VideoFile 반환
     6. 만료되었거나 없으면 nil 반환

     캐시 만료 확인:
     ```swift
     let cachedAt = Date(timeIntervalSince1970: 1641974400)  // 2022-01-12 10:00:00
     let now = Date(timeIntervalSince1970: 1641974700)       // 2022-01-12 10:05:00
     let age = now.timeIntervalSince(cachedAt)               // 300초 (5분)

     if age < maxCacheAge {  // 300 < 300 (false)
     // 만료됨, 캐시 제거
     }
     ```

     사용 예시:
     ```swift
     if let cachedVideo = service.getCachedFileInfo(for: "/videos/file.mp4") {
     print("캐시 히트! 파일 정보: \(cachedVideo.timestamp)")
     } else {
     print("캐시 미스. 파일을 다시 읽어야 합니다")
     }
     ```

     스레드 안전성:
     - NSLock으로 보호됨
     - 여러 스레드에서 동시 호출 가능
     - defer로 unlock() 보장 (return 시에도)
     */
    /// @brief Get cached file information
    /// @param filePath Path to file
    /// @return Cached file info or nil if not cached or expired
    func getCachedFileInfo(for filePath: String) -> VideoFile? {
        cacheLock.lock()  // 캐시 잠금 (다른 스레드 대기)
        defer { cacheLock.unlock() }  // 함수 종료 시 자동으로 잠금 해제

        // 캐시에서 파일 정보 조회
        guard let cached = fileCache[filePath] else {
            return nil  // 캐시에 없으면 nil 반환
        }

        // Check if cache is still valid
        // 캐시 만료 여부 확인
        let age = Date().timeIntervalSince(cached.cachedAt)  // 캐시 나이 계산 (초)
        guard age < maxCacheAge else {
            // Cache expired, remove it
            // 캐시가 만료되었으면 제거하고 nil 반환
            fileCache.removeValue(forKey: filePath)
            return nil
        }

        return cached.videoFile  // 유효한 캐시 반환
    }

    /*
     【파일 정보 캐싱 메서드】

     VideoFile 정보를 메모리 캐시에 저장합니다.

     매개변수:
     - videoFile: 캐시할 VideoFile 객체
     - filePath: 캐시 키로 사용할 파일 경로

     동작 순서:
     1. NSLock으로 캐시 잠금
     2. defer로 unlock() 보장
     3. 캐시 크기 제한 확인 (1000개)
     4. 제한 초과 시 가장 오래된 20% 제거
     5. 새 항목 추가

     LRU 캐시 전략 (Least Recently Used):
     ```
     캐시 상태: 1000개 (제한 도달)

     1. cachedAt 기준으로 정렬
     oldest ──────────────────────────▶ newest
     [file1, file2, file3, ..., file1000]

     2. 가장 오래된 20% (200개) 제거
     [file201, file202, ..., file1000]  // 800개

     3. 새 항목 추가
     [file201, file202, ..., file1000, newFile]  // 801개
     ```

     왜 20%를 제거하는가?
     - 한 번에 많이 제거하여 제거 빈도 감소
     - 오버헤드 최소화 (정렬 비용)
     - 메모리 여유 확보

     사용 예시:
     ```swift
     // 파일을 읽고 캐시에 저장
     let videoFile = try metadataExtractor.extractMetadata(from: filePath)
     service.cacheFileInfo(videoFile, for: filePath)

     // 다음 번 호출 시 캐시에서 즉시 반환
     let cached = service.getCachedFileInfo(for: filePath)
     ```

     성능:
     - 캐시 추가: O(1) (제거 없을 때)
     - 캐시 제거: O(n log n) (정렬 비용, n=1000)
     - 제거 빈도: 대략 801번 추가마다 1번
     */
    /// @brief Cache file information
    /// @param videoFile VideoFile to cache
    /// @param filePath File path to use as cache key
    func cacheFileInfo(_ videoFile: VideoFile, for filePath: String) {
        cacheLock.lock()  // 캐시 잠금 (다른 스레드 대기)
        defer { cacheLock.unlock() }  // 함수 종료 시 자동으로 잠금 해제

        // Check cache size limit
        // 캐시 크기 제한 확인
        if fileCache.count >= maxCacheSize {
            // Remove oldest entries
            // 가장 오래된 항목들 제거

            // cachedAt 기준으로 키 정렬 (오래된 순)
            let sortedKeys = fileCache.keys.sorted { key1, key2 in
                fileCache[key1]!.cachedAt < fileCache[key2]!.cachedAt
            }

            // Remove oldest 20% of cache
            // 캐시의 20% (200개) 제거
            let removeCount = maxCacheSize / 5  // 1000 / 5 = 200
            for key in sortedKeys.prefix(removeCount) {  // 처음 200개
                fileCache.removeValue(forKey: key)
            }
        }

        // Add to cache
        // 캐시에 새 항목 추가
        fileCache[filePath] = CachedFileInfo(
            videoFile: videoFile,
            cachedAt: Date()  // 현재 시간 기록
        )
    }

    /*
     【캐시 무효화 메서드】

     특정 파일의 캐시를 제거합니다.

     매개변수:
     - filePath: 무효화할 파일 경로

     사용 예시:
     ```swift
     // 파일이 수정되었을 때 캐시 무효화
     try service.moveVideoFile(videoFile, to: newPath)
     service.invalidateCache(for: oldPath)

     // 파일을 삭제했을 때 캐시 무효화
     try service.deleteVideoFile(videoFile)
     service.invalidateCache(for: videoFile.channels[0].filePath)
     ```

     왜 필요한가?
     - 파일이 이동/삭제/수정되면 캐시가 부정확해짐
     - 부정확한 캐시는 버그 원인
     - 명시적으로 무효화하여 다음 번 읽기 시 최신 정보 로드
     */
    /// @brief Invalidate cache for specific file
    /// @param filePath File path to invalidate
    func invalidateCache(for filePath: String) {
        cacheLock.lock()  // 캐시 잠금
        defer { cacheLock.unlock() }  // 함수 종료 시 자동 해제

        fileCache.removeValue(forKey: filePath)  // 캐시에서 제거
    }

    /*
     【전체 캐시 삭제 메서드】

     메모리 캐시를 완전히 비웁니다.

     사용 예시:
     ```swift
     // 메모리 압박 시 캐시 정리
     if lowMemoryWarning {
     service.clearCache()
     print("캐시가 정리되었습니다")
     }

     // 새로운 폴더 로드 시 캐시 정리
     service.clearCache()  // 이전 폴더의 캐시 제거
     fileScanner.scanVideoFiles(at: newFolderPath)
     ```

     메모리 해제:
     - removeAll()은 Dictionary의 모든 항목 제거
     - 메모리 즉시 해제됨
     - ARC(Automatic Reference Counting)에 의해 자동 관리
     */
    /// @brief Clear entire file cache
    func clearCache() {
        cacheLock.lock()  // 캐시 잠금
        defer { cacheLock.unlock() }  // 함수 종료 시 자동 해제

        fileCache.removeAll()  // 모든 캐시 항목 제거
    }

    /*
     【캐시 통계 조회 메서드】

     현재 캐시 상태의 통계를 반환합니다.

     반환값:
     - count: 캐시된 파일 개수
     - oldestAge: 가장 오래된 캐시의 나이 (초 단위, 없으면 nil)

     동작:
     1. 캐시 개수 계산
     2. 모든 캐시 항목의 나이 계산
     3. 최대값(가장 오래된 것) 찾기

     사용 예시:
     ```swift
     let (count, oldestAge) = service.getCacheStats()
     print("캐시 항목: \(count)개")

     if let age = oldestAge {
     let minutes = Int(age / 60)
     print("가장 오래된 캐시: \(minutes)분 전")

     if age > 240 {  // 4분 초과
     print("곧 만료될 캐시가 있습니다")
     }
     }

     // UI에 표시
     cacheCountLabel.stringValue = "\(count) files cached"
     ```

     map() 함수:
     ```swift
     let values = [1, 2, 3]
     let doubled = values.map { $0 * 2 }  // [2, 4, 6]

     // 여기서는:
     let ages = fileCache.values.map { Date().timeIntervalSince($0.cachedAt) }
     // CachedFileInfo → TimeInterval 변환
     ```

     max() 함수:
     - 배열에서 최대값 찾기
     - 빈 배열이면 nil 반환
     - 가장 오래된 캐시 = 나이가 가장 큰 캐시
     */
    /// @brief Get cache statistics
    /// @return Tuple of (cached files count, oldest cache age)
    func getCacheStats() -> (count: Int, oldestAge: TimeInterval?) {
        cacheLock.lock()  // 캐시 잠금
        defer { cacheLock.unlock() }  // 함수 종료 시 자동 해제

        let count = fileCache.count  // 캐시된 파일 개수

        // 모든 캐시 항목의 나이를 계산하고 최대값 찾기
        let oldestAge = fileCache.values.map { Date().timeIntervalSince($0.cachedAt) }.max()

        return (count, oldestAge)  // 튜플로 반환
    }

    /*
     【만료된 캐시 정리 메서드】

     5분이 지난 만료된 캐시 항목들을 제거합니다.

     동작 순서:
     1. 현재 시간 기록
     2. 모든 캐시 항목을 순회하며 만료 여부 확인
     3. 만료된 항목의 키 수집
     4. 수집된 키로 캐시에서 제거

     filter() 함수:
     ```swift
     let numbers = [1, 2, 3, 4, 5]
     let evens = numbers.filter { $0 % 2 == 0 }  // [2, 4]

     // 여기서는:
     let expired = fileCache.filter { key, value in
     now.timeIntervalSince(value.cachedAt) >= maxCacheAge
     }
     // 만료된 항목만 필터링
     ```

     map() 함수:
     ```swift
     let expired = [("key1", info1), ("key2", info2)]
     let keys = expired.map { $0.key }  // ["key1", "key2"]
     ```

     사용 예시:
     ```swift
     // 백그라운드 타이머로 주기적 정리
     Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
     service.cleanupExpiredCache()
     print("만료된 캐시를 정리했습니다")
     }

     // 앱이 백그라운드로 갈 때
     NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification) {
     service.cleanupExpiredCache()
     }
     ```

     자동 정리 vs 수동 정리:
     - getCachedFileInfo()는 조회 시 만료 확인 (자동)
     - cleanupExpiredCache()는 명시적 정리 (수동)
     - 주기적으로 호출하여 메모리 낭비 방지
     */
    /// @brief Cleanup expired cache entries
    func cleanupExpiredCache() {
        cacheLock.lock()  // 캐시 잠금
        defer { cacheLock.unlock() }  // 함수 종료 시 자동 해제

        let now = Date()  // 현재 시간

        // 만료된 캐시 항목의 키 수집
        let expiredKeys = fileCache.filter { _, value in
            now.timeIntervalSince(value.cachedAt) >= maxCacheAge  // 5분 이상 경과
        }.map { $0.key }  // 키만 추출

        // 만료된 항목들 제거
        for key in expiredKeys {
            fileCache.removeValue(forKey: key)
        }
    }
}

// MARK: - VideoFile Extension

/*
 【VideoFile 확장 (Extension)】

 Extension은 기존 타입에 새로운 기능을 추가하는 Swift의 강력한 기능입니다.

 왜 Extension을 사용하는가?
 1. 코드 분리: VideoFile 정의와 FileManagerService 관련 기능 분리
 2. 편의성: videoFile.withUpdatedMetadata(from:) 형태로 호출 가능
 3. 수정 없이 확장: VideoFile의 원본 코드를 수정하지 않고 기능 추가

 Extension vs 서브클래싱:
 - Extension: 기존 타입에 기능 추가 (저장 프로퍼티 추가 불가)
 - Subclass: 새로운 타입 생성 (저장 프로퍼티 추가 가능)

 사용 예시:
 ```swift
 let videoFile = VideoFile(...)

 // Extension 메서드 호출
 let updated = videoFile.withUpdatedMetadata(from: service)

 // 체이닝
 let files = scanner.scanFiles()
 .map { $0.withUpdatedMetadata(from: service) }
 .filter { $0.isFavorite }
 ```
 */
extension VideoFile {
    /*
     【메타데이터 업데이트 메서드】

     FileManagerService에서 즐겨찾기와 메모 정보를 가져와
     새로운 VideoFile 인스턴스를 생성합니다.

     매개변수:
     - service: FileManagerService 인스턴스

     반환값:
     - VideoFile: 업데이트된 메타데이터를 가진 새 VideoFile

     불변성 (Immutability):
     - Swift의 값 타입(struct)은 불변성 권장
     - 기존 객체를 수정하지 않고 새 객체 생성
     - 안전하고 예측 가능한 코드

     동작 순서:
     1. service에서 즐겨찾기 상태 조회
     2. service에서 메모 조회
     3. 조회한 정보로 새 VideoFile 생성
     4. 다른 프로퍼티는 기존 값 유지

     사용 예시:
     ```swift
     // 파일 스캔 후 메타데이터 업데이트
     let scannedFiles = fileScanner.scanVideoFiles(at: "/videos")
     let updatedFiles = scannedFiles.map { file in
     file.withUpdatedMetadata(from: fileManagerService)
     }

     // 개별 파일 업데이트
     let videoFile = VideoFile(isFavorite: false, notes: nil, ...)
     let updated = videoFile.withUpdatedMetadata(from: service)
     // updated.isFavorite = service에 저장된 실제 값
     // updated.notes = service에 저장된 실제 메모
     ```

     왜 이 패턴을 사용하는가?
     - FileScanner는 파일 시스템에서 VideoFile 생성
     - 이 시점에는 즐겨찾기/메모 정보 없음 (UserDefaults에 있음)
     - 생성 후 이 메서드로 메타데이터 주입
     - 관심사 분리: 파일 스캔 ≠ 메타데이터 관리
     */
    /// @brief Create updated VideoFile with favorite status
    /// @param service FileManagerService to use
    /// @return Updated VideoFile
    func withUpdatedMetadata(from service: FileManagerService) -> VideoFile {
        // service에서 즐겨찾기와 메모 조회
        let isFavorite = service.isFavorite(self)
        let notes = service.getNote(for: self)

        // 업데이트된 정보로 새 VideoFile 생성
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,  // 업데이트된 즐겨찾기 상태
            notes: notes,  // 업데이트된 메모
            isCorrupted: isCorrupted
        )
    }
}

// MARK: - Supporting Types

/*
 【CachedFileInfo 구조체】

 캐시에 저장되는 VideoFile과 캐시 시간을 담는 래퍼(Wrapper) 구조체입니다.

 프로퍼티:
 - videoFile: 캐시할 VideoFile 객체
 - cachedAt: 캐시된 시간 (만료 확인에 사용)

 왜 VideoFile만 저장하지 않는가?
 - 캐시 만료 확인을 위해 저장 시간 필요
 - TimeInterval age = Date().timeIntervalSince(cachedAt)
 - age >= maxCacheAge 이면 만료

 private 접근 제어:
 - FileManagerService 내부에서만 사용
 - 외부에 노출할 필요 없음
 - 캡슐화: 구현 세부사항 숨김

 구조:
 ┌─────────────────────────────────────────────┐
 │  fileCache: [String: CachedFileInfo]        │
 │  ┌───────────────────────────────────────┐  │
 │  │ Key: "/videos/20250115_100000_F.mp4"  │  │
 │  │ Value: CachedFileInfo {               │  │
 │  │   videoFile: VideoFile(...),          │  │
 │  │   cachedAt: 2025-01-15 10:00:00       │  │
 │  │ }                                     │  │
 │  └───────────────────────────────────────┘  │
 └─────────────────────────────────────────────┘

 사용 예시:
 ```swift
 // 캐시에 저장
 let cached = CachedFileInfo(
 videoFile: videoFile,
 cachedAt: Date()
 )
 fileCache[filePath] = cached

 // 캐시에서 조회
 if let cached = fileCache[filePath] {
 let age = Date().timeIntervalSince(cached.cachedAt)
 if age < 300 {  // 5분 이내
 return cached.videoFile
 }
 }
 ```
 */
/// @struct CachedFileInfo
/// @brief Cached file information with timestamp
private struct CachedFileInfo {
    /// @var videoFile
    /// @brief Cached VideoFile object
    let videoFile: VideoFile
    /// @var cachedAt
    /// @brief Timestamp when cached (for expiration check)
    let cachedAt: Date
}
