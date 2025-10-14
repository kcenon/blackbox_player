/// @file LogManager.swift
/// @brief Centralized logging manager for debugging
/// @author BlackboxPlayer Development Team
/// @details
/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                         LogManager - 중앙 집중식 로그 시스템                    ║
 ║                                                                              ║
 ║  목적:                                                                        ║
 ║    앱 전체의 로그 메시지를 중앙에서 관리하고 UI에 실시간 표시합니다.               ║
 ║    디버깅, 문제 추적, 성능 모니터링에 필수적인 컴포넌트입니다.                    ║
 ║                                                                              ║
 ║  핵심 기능:                                                                   ║
 ║    • 타임스탬프가 포함된 로그 메시지 저장                                        ║
 ║    • 로그 레벨 분류 (DEBUG, INFO, WARNING, ERROR)                             ║
 ║    • 스레드 안전한 로그 저장                                                   ║
 ║    • 최대 500개 로그 유지 (순환 버퍼)                                          ║
 ║    • SwiftUI에서 실시간 관찰 가능                                              ║
 ║                                                                              ║
 ║  설계 패턴:                                                                   ║
 ║    • Singleton 패턴: 앱 전체에서 하나의 인스턴스만 사용                          ║
 ║    • Observer 패턴: SwiftUI 뷰가 로그 변경사항 자동 감지                        ║
 ║    • Thread-Safe: NSLock으로 멀티스레드 환경에서 안전하게 동작                   ║
 ║                                                                              ║
 ║  사용 예:                                                                     ║
 ║    ```swift                                                                  ║
 ║    // 간단한 로그                                                             ║
 ║    debugLog("Video decoding started")                                        ║
 ║    infoLog("File loaded successfully")                                       ║
 ║    warningLog("Low memory warning")                                          ║
 ║    errorLog("Failed to open file")                                           ║
 ║                                                                              ║
 ║    // SwiftUI에서 로그 표시                                                   ║
 ║    struct DebugView: View {                                                  ║
 ║        @ObservedObject var logger = LogManager.shared                        ║
 ║                                                                              ║
 ║        var body: some View {                                                 ║
 ║            List(logger.logs) { log in                                        ║
 ║                Text(log.formattedMessage)                                    ║
 ║            }                                                                 ║
 ║        }                                                                     ║
 ║    }                                                                         ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ 로깅 시스템이란? 왜 필요한가?                                                   │
 └──────────────────────────────────────────────────────────────────────────────┘

 로깅(Logging)은 프로그램 실행 중 발생하는 이벤트를 기록하는 것입니다.

 ┌───────────────────────────────────────────────────────────────────────────┐
 │ print() vs LogManager                                                     │
 ├───────────────────────────────────────────────────────────────────────────┤
 │                                                                           │
 │ print()의 문제점:                                                          │
 │   • 로그가 콘솔에만 출력됨 → 사용자가 볼 수 없음                              │
 │   • 타임스탬프 없음 → 언제 발생했는지 모름                                   │
 │   • 레벨 구분 없음 → 중요도 판단 불가                                        │
 │   • 검색/필터링 불가 → 원하는 로그 찾기 어려움                                │
 │   • 멀티스레드 환경에서 메시지 섞임                                           │
 │                                                                           │
 │ LogManager의 장점:                                                         │
 │   • UI에 실시간 표시 → 사용자/개발자 모두 확인 가능                            │
 │   • 정확한 타임스탬프 → 시간순 추적 가능                                      │
 │   • 로그 레벨 → 중요도별 필터링 가능                                          │
 │   • 메모리에 저장 → 검색/분석 가능                                           │
 │   • 스레드 안전 → 메시지 순서 보장                                           │
 │                                                                           │
 └───────────────────────────────────────────────────────────────────────────┘


 실제 사용 시나리오:

 1. 디버깅 (Debugging)
 문제 발생 시 어디서 왜 발생했는지 추적
 예: "Video decoding failed at frame 1523"

 2. 성능 모니터링
 각 단계의 실행 시간 측정
 예: "File scan completed in 2.3 seconds"

 3. 사용자 지원
 사용자가 문제 발생 시 로그를 공유하여 원격 지원
 예: 사용자가 "재생 안 됨" 보고 → 로그 확인 → "Codec not supported" 발견

 4. 감사 로그 (Audit Log)
 중요한 작업 기록
 예: "User deleted 10 files at 14:32:15"


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ 로그 레벨 (Log Level) 분류                                                     │
 └──────────────────────────────────────────────────────────────────────────────┘

 로그는 중요도에 따라 4단계로 분류됩니다:

 1. DEBUG (디버그)
 • 가장 상세한 정보
 • 개발 중에만 사용
 • 프로덕션에서는 비활성화
 • 예: "Entered function parseGPSData()"

 2. INFO (정보)
 • 일반적인 정보 메시지
 • 정상 동작 확인용
 • 프로덕션에서도 활성화
 • 예: "Video file loaded successfully"

 3. WARNING (경고)
 • 잠재적 문제
 • 동작은 계속되지만 주의 필요
 • 예: "Low memory warning: 90% used"

 4. ERROR (오류)
 • 심각한 문제
 • 기능 동작 실패
 • 즉시 해결 필요
 • 예: "Failed to initialize decoder: file not found"


 실제 사용 예:
 ```swift
 func loadVideoFile(_ path: String) throws {
 debugLog("loadVideoFile() called with path: \(path)")

 guard FileManager.default.fileExists(atPath: path) else {
 errorLog("File not found: \(path)")
 throw FileError.notFound
 }

 infoLog("File found, starting to load...")

 if memoryUsage > 0.9 {
 warningLog("High memory usage: \(memoryUsage * 100)%")
 }

 // ... 로딩 로직 ...

 infoLog("Video file loaded successfully")
 }
 ```
 */

import Foundation
import Combine

// MARK: - LogEntry 구조체

/// @struct LogEntry
/// @brief 개별 로그 항목 (타임스탬프 + 메시지 + 레벨)
///
/// 이 구조체는 하나의 로그 메시지를 나타냅니다.
///
/// - Note: Identifiable 프로토콜
///   SwiftUI의 List나 ForEach에서 각 항목을 고유하게 식별하기 위해 필요합니다.
///   id 프로퍼티가 자동으로 UUID를 생성하여 각 로그를 구분합니다.
///
/// - Important: 구조체를 사용하는 이유
///   • Value Type: 복사 시 독립적인 값 생성 → 스레드 안전
///   • 불변성: 한번 생성된 로그는 변경 불가 → 데이터 무결성
///   • 가벼움: 클래스보다 메모리 효율적
///
/// 사용 예:
/// ```swift
/// let entry = LogEntry(
///     timestamp: Date(),
///     message: "Video started",
///     level: .info
/// )
///
/// // SwiftUI에서 사용
/// List(logs) { entry in  // id 자동 사용
///     Text(entry.formattedMessage)
/// }
/// ```
///
/// - SeeAlso: `LogManager`, `LogLevel`
struct LogEntry: Identifiable {
    // MARK: 프로퍼티

    /// @var id
    /// @brief 고유 식별자 (SwiftUI List용)
    ///
    /// UUID: 범용 고유 식별자 (Universally Unique Identifier)
    /// - 128비트 숫자
    /// - 중복 확률: 1/(2^128) ≈ 0% (사실상 불가능)
    /// - 예: "550e8400-e29b-41d4-a716-446655440000"
    ///
    /// 왜 UUID를 사용하나?
    /// - timestamp만으로는 같은 밀리초에 생성된 로그 구분 불가
    /// - 배열 인덱스는 삭제 시 변경됨
    /// - UUID는 절대 변하지 않는 영구 식별자
    let id = UUID()

    /// @var timestamp
    /// @brief 로그 생성 시각
    ///
    /// Date 타입:
    /// - 특정 시점을 나타내는 값
    /// - 내부적으로 2001-01-01 00:00:00 UTC부터의 초 단위 시간차
    /// - 타임존 정보 포함 (자동 변환 가능)
    ///
    /// 사용 예:
    /// ```swift
    /// let now = Date()  // 현재 시각
    /// let formatter = DateFormatter()
    /// formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    /// print(formatter.string(from: now))  // "2025-01-10 14:30:25"
    /// ```
    let timestamp: Date

    /// @var message
    /// @brief 로그 메시지 내용
    ///
    /// 로그 메시지 작성 가이드:
    /// 1. 명확하고 구체적으로
    ///    나쁜 예: "Error occurred"
    ///    좋은 예: "Failed to decode video frame 1523: codec not supported"
    ///
    /// 2. 컨텍스트 포함
    ///    나쁜 예: "File loaded"
    ///    좋은 예: "Loaded video.mp4 (1920x1080, 60fps, 5 channels)"
    ///
    /// 3. 중요한 값 포함
    ///    예: "Memory usage: 85% (1.2GB / 1.4GB)"
    let message: String

    /// @var level
    /// @brief 로그 레벨 (DEBUG, INFO, WARNING, ERROR)
    ///
    /// 이 값으로 로그의 중요도를 판단합니다.
    /// - DEBUG: 개발자용 상세 정보
    /// - INFO: 일반 정보
    /// - WARNING: 주의 필요
    /// - ERROR: 심각한 문제
    ///
    /// 사용 예:
    /// ```swift
    /// switch entry.level {
    /// case .debug:
    ///     color = .gray
    /// case .info:
    ///     color = .blue
    /// case .warning:
    ///     color = .orange
    /// case .error:
    ///     color = .red
    /// }
    /// ```
    let level: LogLevel

    // MARK: 계산 프로퍼티

    /// @var formattedMessage
    /// @brief 포맷팅된 로그 메시지 문자열
    ///
    /// 출력 형식: "[HH:mm:ss.SSS] [LEVEL] message"
    /// 예: "[14:30:25.123] [INFO] Video file loaded"
    ///
    /// - Returns: 타임스탬프, 레벨, 메시지가 포함된 완전한 로그 문자열
    ///
    /// - Note: 계산 프로퍼티
    ///   저장되지 않고 호출될 때마다 다시 계산됩니다.
    ///   매번 DateFormatter를 생성하므로 성능이 중요한 경우 캐싱 고려.
    ///
    /// DateFormatter 설명:
    /// ```swift
    /// let formatter = DateFormatter()
    /// formatter.dateFormat = "HH:mm:ss.SSS"
    /// // HH: 24시간 형식 시간 (00-23)
    /// // mm: 분 (00-59)
    /// // ss: 초 (00-59)
    /// // SSS: 밀리초 (000-999)
    ///
    /// let now = Date()
    /// formatter.string(from: now)  // "14:30:25.123"
    /// ```
    ///
    /// 다양한 날짜 포맷 예제:
    /// - "yyyy-MM-dd" → "2025-01-10"
    /// - "yyyy년 MM월 dd일" → "2025년 01월 10일"
    /// - "HH:mm:ss" → "14:30:25"
    /// - "a hh:mm:ss" → "오후 02:30:25"
    var formattedMessage: String {
        // DateFormatter 생성
        // - Date를 String으로 변환하는 도구
        // - 로케일(지역), 타임존 등을 고려한 포맷팅
        let formatter = DateFormatter()

        // 날짜 포맷 지정
        // HH:mm:ss.SSS = 14:30:25.123 형식
        formatter.dateFormat = "HH:mm:ss.SSS"

        // Date → String 변환
        let timeString = formatter.string(from: timestamp)

        // 최종 포맷: [시간] [레벨] 메시지
        // 예: "[14:30:25.123] [INFO] Video loaded"
        return "[\(timeString)] [\(level.displayName)] \(message)"
    }
}

// MARK: - LogLevel 열거형

/// @enum LogLevel
/// @brief 로그 레벨 열거형
///
/// 로그 메시지의 중요도를 4단계로 분류합니다.
///
/// - Note: String rawValue
///   각 case에 대응하는 문자열 값을 가집니다.
///   예: LogLevel.debug.rawValue → "DEBUG"
///
/// - Important: 열거형을 사용하는 이유
///   1. 타입 안전성: 오타 방지 (예: "DEBG" 불가)
///   2. 자동완성: Xcode가 가능한 값 제안
///   3. switch 완전성: 모든 case 처리 강제
///   4. 확장 용이: 새로운 레벨 추가 쉬움
///
/// 사용 예:
/// ```swift
/// // 타입 안전
/// log("Message", level: .info)  // ✓ 올바름
/// log("Message", level: "info")  // ✗ 컴파일 에러
///
/// // switch 완전성 검사
/// switch level {
/// case .debug: ...
/// case .info: ...
/// case .warning: ...
/// case .error: ...
/// // 모든 case를 처리하지 않으면 컴파일 에러
/// }
/// ```
enum LogLevel: String {
    /// @brief DEBUG 레벨: 상세한 디버깅 정보
    ///
    /// 사용 시기:
    /// - 함수 진입/종료 추적
    /// - 변수 값 출력
    /// - 내부 상태 확인
    /// - 개발 중에만 활성화
    ///
    /// 예:
    /// ```swift
    /// debugLog("Entering parseGPSData()")
    /// debugLog("GPS points count: \(points.count)")
    /// debugLog("Current state: \(state)")
    /// ```
    case debug = "DEBUG"

    /// @brief INFO 레벨: 일반 정보 메시지
    ///
    /// 사용 시기:
    /// - 주요 작업 완료
    /// - 정상 동작 확인
    /// - 사용자 액션 기록
    /// - 프로덕션에서도 활성화
    ///
    /// 예:
    /// ```swift
    /// infoLog("Application started")
    /// infoLog("Video file loaded: video.mp4")
    /// infoLog("User opened settings")
    /// ```
    case info = "INFO"

    /// @brief WARNING 레벨: 잠재적 문제 경고
    ///
    /// 사용 시기:
    /// - 비정상이지만 치명적이지 않은 상황
    /// - 성능 저하 가능성
    /// - 리소스 부족 경고
    /// - 권장하지 않는 사용 패턴
    ///
    /// 예:
    /// ```swift
    /// warningLog("Low memory: 90% used")
    /// warningLog("Deprecated API used")
    /// warningLog("Network latency high: 500ms")
    /// ```
    case warning = "WARNING"

    /// @brief ERROR 레벨: 심각한 오류
    ///
    /// 사용 시기:
    /// - 기능 동작 실패
    /// - 예외 발생
    /// - 복구 불가능한 상황
    /// - 즉시 조치 필요
    ///
    /// 예:
    /// ```swift
    /// errorLog("Failed to open file: \(error)")
    /// errorLog("Database connection lost")
    /// errorLog("Out of memory")
    /// ```
    case error = "ERROR"

    /// @var displayName
    /// @brief 화면 표시용 레벨 이름
    ///
    /// rawValue를 그대로 반환합니다.
    /// 필요 시 한글 변환 가능:
    /// ```swift
    /// var displayName: String {
    ///     switch self {
    ///     case .debug: return "디버그"
    ///     case .info: return "정보"
    ///     case .warning: return "경고"
    ///     case .error: return "오류"
    ///     }
    /// }
    /// ```
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - LogManager 클래스

/// @class LogManager
/// @brief 중앙 집중식 로그 관리자
///
/// 앱 전체에서 하나의 인스턴스만 사용하는 Singleton 패턴을 적용했습니다.
///
/// - Note: ObservableObject
///   SwiftUI와 Combine 프레임워크의 핵심 프로토콜입니다.
///   @Published 프로퍼티가 변경되면 자동으로 UI를 업데이트합니다.
///
/// - Important: 클래스를 사용하는 이유
///   • Reference Type: 앱 전체에서 같은 인스턴스 공유
///   • ObservableObject: 구조체는 ObservableObject 불가
///   • Singleton: 여러 인스턴스 생성 방지
///
/// ┌─────────────────────────────────────────────────────────────────────────┐
/// │ Singleton 패턴이란?                                                      │
/// ├─────────────────────────────────────────────────────────────────────────┤
/// │                                                                         │
/// │ 클래스의 인스턴스를 딱 하나만 생성하도록 보장하는 디자인 패턴              │
/// │                                                                         │
/// │ 구현 방법:                                                               │
/// │   static let shared = LogManager()  // 유일한 인스턴스                   │
/// │   private init() {}                 // 외부 생성 방지                    │
/// │                                                                         │
/// │ 사용 방법:                                                               │
/// │   LogManager.shared.log("message")  // 항상 같은 인스턴스 사용           │
/// │   let logger = LogManager()         // ✗ 컴파일 에러 (init private)     │
/// │                                                                         │
/// │ 왜 Singleton을 사용하나?                                                 │
/// │   1. 전역 접근: 어디서든 로그 기록 가능                                   │
/// │   2. 메모리 절약: 하나의 로그 배열만 유지                                 │
/// │   3. 일관성: 모든 로그를 한 곳에서 관리                                   │
/// │   4. 스레드 안전: 중앙 집중식 동기화                                      │
/// │                                                                         │
/// └─────────────────────────────────────────────────────────────────────────┘
///
/// SwiftUI에서 사용:
/// ```swift
/// struct DebugView: View {
///     @ObservedObject var logger = LogManager.shared
///
///     var body: some View {
///         List(logger.logs) { log in
///             Text(log.formattedMessage)
///                 .foregroundColor(colorForLevel(log.level))
///         }
///     }
/// }
/// ```
///
/// - SeeAlso: `LogEntry`, `LogLevel`
class LogManager: ObservableObject {

    // MARK: - Singleton 인스턴스

    /// @var shared
    /// @brief 공유 인스턴스 (Singleton)
    ///
    /// static: 타입 레벨 프로퍼티 (클래스에 속함, 인스턴스와 무관)
    /// let: 상수 (한번 초기화 후 변경 불가)
    ///
    /// 사용 예:
    /// ```swift
    /// LogManager.shared.log("Hello")  // 어디서든 사용 가능
    ///
    /// // 잘못된 사용
    /// let logger1 = LogManager()  // ✗ init이 private이므로 불가능
    /// ```
    static let shared = LogManager()

    // MARK: - Published 프로퍼티

    /// @var logs
    /// @brief 로그 항목 배열 (UI에 실시간 반영)
    ///
    /// @Published:
    /// - Combine 프레임워크의 Property Wrapper
    /// - 값이 변경될 때마다 자동으로 알림 발행
    /// - SwiftUI가 이 알림을 받아 자동으로 UI 업데이트
    ///
    /// private(set):
    /// - 읽기는 public, 쓰기는 private
    /// - 외부에서는 조회만 가능, 수정은 이 클래스 내부에서만
    /// - 데이터 무결성 보장
    ///
    /// 동작 원리:
    /// ```
    /// logs.append(entry)  →  @Published가 감지
    ///                    ↓
    ///            objectWillChange 이벤트 발행
    ///                    ↓
    ///          SwiftUI가 이벤트 수신
    ///                    ↓
    ///            body를 다시 실행 (재렌더링)
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// // 읽기 (어디서든 가능)
    /// let count = LogManager.shared.logs.count  // ✓
    ///
    /// // 쓰기 (외부에서 불가능)
    /// LogManager.shared.logs.append(...)  // ✗ 컴파일 에러
    ///
    /// // 쓰기는 메서드를 통해서만
    /// LogManager.shared.log("message")  // ✓
    /// ```
    @Published private(set) var logs: [LogEntry] = []

    // MARK: - Private 프로퍼티

    /// @var maxLogs
    /// @brief 최대 로그 개수 (순환 버퍼)
    ///
    /// 왜 제한이 필요한가?
    /// - 무제한 저장 시 메모리 부족 발생 가능
    /// - 오래된 로그는 중요도가 낮음
    /// - UI 렌더링 성능 저하 방지
    ///
    /// 순환 버퍼 (Circular Buffer):
    /// ```
    /// 최대 3개 저장 가능한 경우:
    ///
    /// [A]           → A 추가
    /// [A, B]        → B 추가
    /// [A, B, C]     → C 추가 (가득 참)
    /// [B, C, D]     → D 추가 (A 삭제, 가장 오래된 것)
    /// [C, D, E]     → E 추가 (B 삭제)
    /// ```
    ///
    /// 500개 선택 이유:
    /// - 일반적인 디버깅 세션에 충분
    /// - 메모리 사용량: ~100KB (로그당 200바이트 가정)
    /// - UI 렌더링 부담 적음
    private let maxLogs = 500

    /// @var lock
    /// @brief 스레드 안전 보장을 위한 잠금 장치
    ///
    /// NSLock:
    /// - 멀티스레드 환경에서 공유 리소스 보호
    /// - 한 번에 하나의 스레드만 접근 허용
    /// - 데이터 경합(Data Race) 방지
    ///
    /// ┌─────────────────────────────────────────────────────────────────────┐
    /// │ 데이터 경합 (Data Race) 예시                                         │
    /// ├─────────────────────────────────────────────────────────────────────┤
    /// │                                                                     │
    /// │ NSLock 없을 때:                                                      │
    /// │                                                                     │
    /// │ 스레드 A: logs.append(entry1)                                        │
    /// │           └─ logs 크기 확인: 499개                                   │
    /// │           └─ 500번째 위치에 entry1 추가 시작...                       │
    /// │                                                                     │
    /// │ 스레드 B: logs.append(entry2)  (동시에!)                             │
    /// │           └─ logs 크기 확인: 499개  (A가 아직 완료 안 함)             │
    /// │           └─ 500번째 위치에 entry2 추가 시작...                       │
    /// │                                                                     │
    /// │ 결과: 💥 충돌! entry1 또는 entry2 중 하나 손실!                        │
    /// │                                                                     │
    /// │ ────────────────────────────────────────────────────────────────── │
    /// │                                                                     │
    /// │ NSLock 사용 시:                                                      │
    /// │                                                                     │
    /// │ 스레드 A: lock.lock()     // 🔒 잠금                                  │
    /// │           logs.append(entry1)                                        │
    /// │           lock.unlock()   // 🔓 해제                                 │
    /// │                                                                     │
    /// │ 스레드 B: lock.lock()     // ⏳ A가 끝날 때까지 대기...               │
    /// │           logs.append(entry2)  // A 완료 후 실행                     │
    /// │           lock.unlock()                                              │
    /// │                                                                     │
    /// │ 결과: ✓ 안전! 순서대로 처리됨                                         │
    /// │                                                                     │
    /// └─────────────────────────────────────────────────────────────────────┘
    ///
    /// 사용 패턴:
    /// ```swift
    /// lock.lock()        // 잠금 획득
    /// defer {
    ///     lock.unlock()  // 함수 종료 시 자동 해제
    /// }
    /// // 보호할 코드
    /// logs.append(entry)
    /// ```
    private let lock = NSLock()

    // MARK: - 초기화

    /// @brief Private 초기화 메서드 (Singleton 패턴)
    ///
    /// private:
    /// - 외부에서 생성 불가능
    /// - LogManager()로 새 인스턴스 생성 시도 시 컴파일 에러
    /// - 오직 shared 인스턴스만 사용 가능
    ///
    /// 왜 빈 init인가?
    /// - 프로퍼티들이 모두 초기값을 가지고 있음
    /// - logs = [] (빈 배열)
    /// - maxLogs = 500 (상수)
    /// - lock = NSLock() (자동 초기화)
    /// - 추가 초기화 로직 불필요
    private init() {}

    // MARK: - Public 메서드

    /// @brief 로그 메시지를 기록합니다
    ///
    /// 이 메서드는 스레드 안전하게 구현되어 있습니다.
    /// 여러 스레드에서 동시에 호출해도 안전합니다.
    ///
    /// @param message 기록할 로그 메시지
    /// @param level 로그 레벨 (기본값: .info)
    ///
    /// - Note: 디폴트 매개변수
    ///   level = .info 부분이 디폴트 매개변수입니다.
    ///   생략 시 자동으로 .info가 사용됩니다.
    ///   ```swift
    ///   log("Hello")              // level은 .info
    ///   log("Error", level: .error)  // level은 .error
    ///   ```
    ///
    /// - Important: 동작 순서
    ///   1. LogEntry 생성 (현재 시각 기록)
    ///   2. 잠금 획득 (다른 스레드 차단)
    ///   3. logs 배열에 추가
    ///   4. 500개 초과 시 가장 오래된 로그 삭제
    ///   5. 잠금 해제 (다른 스레드 허용)
    ///   6. 콘솔에 출력 (디버깅용)
    ///
    /// 사용 예:
    /// ```swift
    /// // 기본 사용 (INFO 레벨)
    /// LogManager.shared.log("Video loaded")
    ///
    /// // 명시적 레벨 지정
    /// LogManager.shared.log("Low memory", level: .warning)
    /// LogManager.shared.log("File not found", level: .error)
    ///
    /// // 편의 함수 사용 (권장)
    /// infoLog("Video loaded")
    /// warningLog("Low memory")
    /// errorLog("File not found")
    /// ```
    func log(_ message: String, level: LogLevel = .info) {
        // 1. LogEntry 생성
        // - 현재 시각 자동 기록
        // - 메시지와 레벨 저장
        let entry = LogEntry(timestamp: Date(), message: message, level: level)

        // 2. 스레드 안전 영역 시작
        lock.lock()

        // 3. 로그 추가
        // - @Published이므로 SwiftUI가 자동 감지
        // - UI가 자동으로 업데이트됨
        logs.append(entry)

        // 4. 순환 버퍼 유지 (최대 500개)
        // 500개 초과 시 가장 오래된 로그 삭제
        if logs.count > maxLogs {
            // removeFirst: 배열 앞부분 삭제
            // logs.count - maxLogs: 초과된 개수만큼 삭제
            // 예: 505개 → 5개 삭제 → 500개 유지
            logs.removeFirst(logs.count - maxLogs)
        }

        // 5. 스레드 안전 영역 종료
        lock.unlock()

        // 6. 콘솔 출력 (추가 디버깅용)
        // - Xcode 콘솔에 즉시 표시
        // - UI와 별도로 빠른 디버깅 가능
        // - 프로덕션에서는 조건부로 비활성화 고려
        print("[\(level.displayName)] \(message)")
    }

    /// @brief 모든 로그를 삭제합니다
    ///
    /// UI의 "로그 지우기" 버튼에서 호출됩니다.
    ///
    /// - Note: 스레드 안전
    ///   lock으로 보호되어 있어 로그 기록 중에 clear() 호출해도 안전합니다.
    ///
    /// - Important: @Published 동작
    ///   logs.removeAll() 호출 시 @Published가 변경 감지
    ///   → SwiftUI가 자동으로 UI 업데이트 (로그 목록 비워짐)
    ///
    /// 사용 예:
    /// ```swift
    /// // SwiftUI 버튼
    /// Button("로그 지우기") {
    ///     LogManager.shared.clear()
    /// }
    ///
    /// // 테스트 전 초기화
    /// override func setUpWithError() throws {
    ///     LogManager.shared.clear()  // 이전 테스트 로그 삭제
    /// }
    /// ```
    func clear() {
        // 스레드 안전 영역
        lock.lock()

        // 모든 로그 삭제
        // - removeAll()은 배열을 빈 배열로 만듦
        // - 메모리 즉시 해제
        logs.removeAll()

        lock.unlock()
    }
}

// MARK: - 편의 함수 (Convenience Functions)

/*
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ 전역 편의 함수                                                                 │
 └──────────────────────────────────────────────────────────────────────────────┘

 LogManager.shared.log("message", level: .debug) 대신
 debugLog("message")로 간단하게 사용할 수 있습니다.

 장점:
 1. 타이핑 간편 (4줄 → 1줄)
 2. 가독성 향상
 3. 리팩토링 용이 (내부 구현 변경해도 사용 코드 영향 없음)

 비교:
 ```swift
 // 기본 방식 (장황함)
 LogManager.shared.log("Starting process", level: .debug)
 LogManager.shared.log("Process complete", level: .info)
 LogManager.shared.log("Low memory", level: .warning)
 LogManager.shared.log("Failed", level: .error)

 // 편의 함수 (간결함)
 debugLog("Starting process")
 infoLog("Process complete")
 warningLog("Low memory")
 errorLog("Failed")
 ```
 */

/// @brief DEBUG 레벨 로그 기록
///
/// 개발 중 상세한 디버깅 정보를 기록합니다.
/// 프로덕션에서는 비활성화하는 것이 좋습니다.
///
/// @param message 로그 메시지
///
/// 사용 예:
/// ```swift
/// func parseGPSData(_ data: Data) {
///     debugLog("Entering parseGPSData, data size: \(data.count)")
///
///     let points = extractPoints(data)
///     debugLog("Extracted \(points.count) GPS points")
///
///     debugLog("Exiting parseGPSData")
/// }
/// ```
func debugLog(_ message: String) {
    LogManager.shared.log(message, level: .debug)
}

/// @brief INFO 레벨 로그 기록
///
/// 일반적인 정보 메시지를 기록합니다.
/// 프로덕션에서도 활성화하여 정상 동작을 확인합니다.
///
/// @param message 로그 메시지
///
/// 사용 예:
/// ```swift
/// func loadVideoFile(_ path: String) throws {
///     infoLog("Loading video file: \(path)")
///
///     let file = try load(path)
///     infoLog("Video loaded: \(file.duration)s, \(file.channelCount) channels")
/// }
/// ```
func infoLog(_ message: String) {
    LogManager.shared.log(message, level: .info)
}

/// @brief WARNING 레벨 로그 기록
///
/// 잠재적 문제나 주의가 필요한 상황을 기록합니다.
/// 동작은 계속되지만 조치가 필요할 수 있습니다.
///
/// @param message 로그 메시지
///
/// 사용 예:
/// ```swift
/// func allocateBuffer() {
///     let memoryUsage = getMemoryUsage()
///     if memoryUsage > 0.9 {
///         warningLog("High memory usage: \(memoryUsage * 100)%")
///     }
///
///     if bufferSize > recommendedSize {
///         warningLog("Buffer size exceeds recommended: \(bufferSize)MB")
///     }
/// }
/// ```
func warningLog(_ message: String) {
    LogManager.shared.log(message, level: .warning)
}

/// @brief ERROR 레벨 로그 기록
///
/// 심각한 오류나 실패 상황을 기록합니다.
/// 즉시 조치가 필요한 문제입니다.
///
/// @param message 로그 메시지
///
/// 사용 예:
/// ```swift
/// func initializeDecoder() throws {
///     do {
///         try decoder.initialize()
///     } catch {
///         errorLog("Failed to initialize decoder: \(error.localizedDescription)")
///         throw error
///     }
/// }
/// ```
func errorLog(_ message: String) {
    LogManager.shared.log(message, level: .error)
}
