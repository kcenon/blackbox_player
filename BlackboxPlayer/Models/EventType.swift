//
//  EventType.swift
//  BlackboxPlayer
//
//  Enum for dashcam recording event types
//

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                       EventType Enum 개요                                │
 │                                                                          │
 │  블랙박스 녹화 이벤트 유형을 분류하는 열거형입니다.                      │
 │                                                                          │
 │  【이벤트 종류】                                                         │
 │                                                                          │
 │  1. normal (일반 녹화)                                                   │
 │     - 지속적인 루프 녹화                                                 │
 │     - 우선순위: 1 (가장 낮음)                                            │
 │     - 색상: Green (#4CAF50)                                              │
 │                                                                          │
 │  2. impact (충격 이벤트)                                                 │
 │     - G-센서로 감지된 충격/충돌                                          │
 │     - 우선순위: 4 (높음)                                                 │
 │     - 색상: Red (#F44336)                                                │
 │                                                                          │
 │  3. parking (주차 모드)                                                  │
 │     - 주차 중 움직임/충격 감지                                           │
 │     - 우선순위: 2                                                        │
 │     - 색상: Blue (#2196F3)                                               │
 │                                                                          │
 │  4. manual (수동 녹화)                                                   │
 │     - 사용자가 버튼으로 직접 트리거                                      │
 │     - 우선순위: 3                                                        │
 │     - 색상: Orange (#FF9800)                                             │
 │                                                                          │
 │  5. emergency (비상 녹화)                                                │
 │     - SOS 버튼 등 비상 상황                                              │
 │     - 우선순위: 5 (가장 높음)                                            │
 │     - 색상: Purple (#9C27B0)                                             │
 │                                                                          │
 │  6. unknown (알 수 없음)                                                 │
 │     - 인식할 수 없는 유형                                                │
 │     - 우선순위: 0 (기본값)                                               │
 │     - 색상: Gray (#9E9E9E)                                               │
 │                                                                          │
 │  【디렉토리 구조에서 자동 감지】                                         │
 │                                                                          │
 │  SD 카드 파일 경로로부터 이벤트 유형을 자동으로 판별합니다.              │
 │                                                                          │
 │  /sdcard/                                                                │
 │    ├── normal/          → EventType.normal                               │
 │    │   ├── 20250115_100000_F.mp4                                         │
 │    │   └── 20250115_100000_R.mp4                                         │
 │    ├── event/           → EventType.impact                               │
 │    │   ├── 20250115_101500_F.mp4                                         │
 │    │   └── 20250115_101500_R.mp4                                         │
 │    ├── parking/         → EventType.parking                              │
 │    │   └── 20250115_200000_F.mp4                                         │
 │    └── manual/          → EventType.manual                               │
 │        └── 20250115_150000_F.mp4                                         │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【Enum (열거형)이란?】

 Enum은 관련된 값들의 그룹을 정의하는 타입입니다.

 장점:
 1. 타입 안전성: 컴파일 타임에 잘못된 값 검출
 2. 자동 완성: Xcode가 가능한 케이스 제시
 3. 코드 가독성: 의미 있는 이름 사용
 4. 패턴 매칭: switch 문에서 강력한 기능

 기본 사용법:
 ```swift
 enum EventType {
     case normal
     case impact
     case parking
 }

 let event: EventType = .impact  // 타입 추론
 ```

 Raw Values (원시 값):
 ```swift
 enum EventType: String {  // String 타입 지정
     case normal = "normal"
     case impact = "impact"
 }

 let event = EventType.normal
 print(event.rawValue)  // "normal"

 let parsed = EventType(rawValue: "impact")  // Optional<EventType>
 ```

 【Codable 프로토콜】

 Enum에 Codable을 적용하면 JSON 직렬화가 자동으로 가능합니다.

 JSON 변환:
 ```swift
 let event = EventType.impact

 // Encoding (Swift → JSON)
 let encoder = JSONEncoder()
 let json = try encoder.encode(event)
 // "impact"

 // Decoding (JSON → Swift)
 let decoder = JSONDecoder()
 let decoded = try decoder.decode(EventType.self, from: json)
 // EventType.impact
 ```

 Raw Value가 있을 때:
 - JSON에서는 rawValue (String)로 표현됨
 - 예: "impact", "normal", "parking"

 【CaseIterable 프로토콜】

 모든 enum case를 배열로 제공합니다.

 사용법:
 ```swift
 enum EventType: String, CaseIterable {
     case normal
     case impact
     case parking
 }

 for eventType in EventType.allCases {
     print(eventType.displayName)
 }

 // UI Picker/Dropdown 생성
 Picker("이벤트 유형", selection: $selectedEvent) {
     ForEach(EventType.allCases, id: \.self) { type in
         Text(type.displayName).tag(type)
     }
 }

 print("총 이벤트 유형: \(EventType.allCases.count)")  // 6
 ```
 */

import Foundation

/*
 【EventType 열거형】

 블랙박스 녹화 이벤트 유형을 분류합니다.

 프로토콜:
 - String: Raw Value로 문자열 사용
 - Codable: JSON 직렬화/역직렬화
 - CaseIterable: allCases 배열 제공
 - Comparable: 우선순위 기반 정렬

 사용 예시:
 ```swift
 // 1. 파일 경로에서 자동 감지
 let path = "/sdcard/event/20250115_100000_F.mp4"
 let type = EventType.detect(from: path)  // .impact

 // 2. UI 표시
 let color = type.colorHex  // "#F44336" (빨강)
 let name = type.displayName  // "Impact"

 // 3. 정렬 (우선순위 높은 순)
 let events = [EventType.normal, .impact, .emergency]
 let sorted = events.sorted(by: >)  // [.emergency, .impact, .normal]

 // 4. 필터링
 let videos = allVideos.filter { $0.eventType == .impact }
 ```
 */
/// Event type classification for dashcam recordings
enum EventType: String, Codable, CaseIterable {
    /*
     【normal - 일반 녹화】

     지속적인 루프 녹화 파일입니다.

     특징:
     - 자동으로 계속 녹화됨
     - 오래된 파일은 자동 삭제 (메모리 공간 확보)
     - 일반적으로 1-3분 단위 파일
     - 가장 많은 비율 차지

     디렉토리: /normal/ 또는 /Normal/

     우선순위: 1 (가장 낮음)
     - 일상적인 녹화이므로 우선순위 낮음
     - 다른 이벤트가 있으면 먼저 표시

     색상: Green (#4CAF50)
     - 정상 상태를 나타내는 초록색
     - UI에서 눈에 덜 띄도록

     예시 파일명:
     - 20250115_100000_F.mp4
     - 20250115_100100_R.mp4
     */
    /// Normal continuous recording
    case normal = "normal"

    /*
     【impact - 충격 이벤트】

     G-센서(가속도 센서)가 감지한 충격/충돌 이벤트입니다.

     트리거 조건:
     - 급제동: 0.5G 이상
     - 충돌: 1.0G 이상
     - 급가속/급회전: 설정에 따라

     특징:
     - 충격 전후 30초 저장 (총 1분)
     - 이벤트 전 10초, 후 20초
     - 자동 삭제 방지 (보호 파일)
     - 중요한 증거 영상

     디렉토리:
     - /event/ 또는 /Event/
     - /impact/ 또는 /Impact/

     우선순위: 4 (높음)
     - 사고 영상이므로 중요
     - emergency 다음으로 높은 우선순위

     색상: Red (#F44336)
     - 위험/주의를 나타내는 빨강
     - 사용자의 즉각적인 주목 필요

     예시:
     - 추돌 사고
     - 급제동
     - 도로 요철 통과
     - 포트홀 충격
     */
    /// Impact/collision event recording (triggered by G-sensor)
    case impact = "impact"

    /*
     【parking - 주차 모드】

     주차 중 움직임이나 충격을 감지한 녹화입니다.

     트리거 조건:
     - 차량 주변 움직임 감지 (모션 센서)
     - 주차 중 충격 (문콕, 접촉사고)
     - 진동 감지

     특징:
     - 배터리 절약 모드 (저전력)
     - 감지 시에만 녹화 (타임랩스)
     - 프레임 레이트 낮음 (1-5 fps)
     - 별도 배터리 필요할 수 있음

     디렉토리:
     - /parking/ 또는 /Parking/
     - /park/ 또는 /Park/

     우선순위: 2
     - 중요하지만 impact보다는 낮음
     - 주차장 접촉사고 증거

     색상: Blue (#2196F3)
     - 주차 모드를 나타내는 파랑
     - 차분하고 안정적인 느낌

     예시:
     - 주차장 문콕
     - 주차 중 접촉사고
     - 도난 시도
     */
    /// Parking mode recording (motion/impact detection while parked)
    case parking = "parking"

    /*
     【manual - 수동 녹화】

     사용자가 버튼을 눌러 직접 시작한 녹화입니다.

     트리거 방법:
     - 블랙박스의 수동 녹화 버튼
     - 스마트폰 앱의 녹화 버튼
     - 음성 명령 ("녹화 시작")

     특징:
     - 사용자가 의도적으로 기록
     - 자동 삭제 방지 (보호 파일)
     - 긴 녹화 시간 (5-10분)
     - 즉시 녹화 시작

     디렉토리: /manual/ 또는 /Manual/

     우선순위: 3
     - impact와 parking 사이
     - 사용자가 중요하다고 판단한 영상

     색상: Orange (#FF9800)
     - 주의를 끄는 주황색
     - 수동 액션을 나타냄

     예시 상황:
     - 경찰 단속
     - 교통 위반 차량 목격
     - 경치 좋은 도로
     - 블랙박스 테스트
     */
    /// Manual recording (user-triggered)
    case manual = "manual"

    /*
     【emergency - 비상 녹화】

     SOS 버튼 등으로 트리거된 비상 상황 녹화입니다.

     트리거 방법:
     - 블랙박스의 SOS/Emergency 버튼
     - 스마트폰 앱의 비상 버튼
     - 자동 감지 (에어백 전개 등)

     특징:
     - 최우선 보호 (절대 삭제 안 됨)
     - 긴 녹화 시간 (10-15분)
     - GPS 위치 자동 저장
     - 비상 연락처에 알림 전송 (일부 모델)

     디렉토리:
     - /emergency/ 또는 /Emergency/
     - /sos/ 또는 /SOS/

     우선순위: 5 (가장 높음)
     - 생명/안전과 직결된 영상
     - 모든 이벤트 중 최우선

     색상: Purple (#9C27B0)
     - 특별한 상황을 나타내는 보라
     - 긴급 상황 강조

     예시 상황:
     - 심각한 교통사고
     - 위급한 의료 상황
     - 범죄 목격
     - 도움 요청 필요 상황
     */
    /// Emergency recording
    case emergency = "emergency"

    /*
     【unknown - 알 수 없음】

     파일 경로나 메타데이터에서 이벤트 유형을 판별할 수 없을 때 사용합니다.

     발생 원인:
     - 비표준 디렉토리 구조
     - 손상된 파일 경로
     - 알 수 없는 블랙박스 모델
     - 사용자 정의 폴더

     특징:
     - 기본값 (fallback)
     - 추후 수동 분류 가능
     - 자동 처리 불가

     디렉토리: 패턴 매칭 실패 시

     우선순위: 0 (기본값)
     - 가장 낮은 우선순위
     - 정렬 시 맨 아래 표시

     색상: Gray (#9E9E9E)
     - 알 수 없음을 나타내는 회색
     - 분류 필요 표시

     처리 방법:
     ```swift
     if eventType == .unknown {
         // 사용자에게 수동 분류 요청
         showEventTypeSelector()
     }
     ```
     */
    /// Unknown or unrecognized event type
    case unknown = "unknown"

    // MARK: - Display Properties

    /*
     【표시 이름 (Display Name)】

     UI에 표시할 사람이 읽기 쉬운 이름을 반환합니다.

     반환값:
     - String: 이벤트 유형의 영문 이름

     사용 예시:
     ```swift
     let event = EventType.impact
     let name = event.displayName  // "Impact"

     // UI 레이블
     eventLabel.stringValue = event.displayName

     // 리스트 아이템
     List(events) { event in
         Text(event.displayName)
     }

     // 필터 버튼
     Button(event.displayName) {
         filterBy(event)
     }
     ```

     다국어화 (Localization):
     현재는 영문만 지원하지만, 추후 다국어 지원 시:
     ```swift
     var displayName: String {
         switch self {
         case .impact:
             return NSLocalizedString("impact", comment: "Impact event")
         // ...
         }
     }
     ```
     */
    /// Human-readable display name for the event type
    var displayName: String {
        switch self {
        case .normal:
            return "Normal"  // 일반 녹화
        case .impact:
            return "Impact"  // 충격 이벤트
        case .parking:
            return "Parking"  // 주차 모드
        case .manual:
            return "Manual"  // 수동 녹화
        case .emergency:
            return "Emergency"  // 비상 녹화
        case .unknown:
            return "Unknown"  // 알 수 없음
        }
    }

    /*
     【색상 코드 (Color Hex)】

     이벤트 유형에 해당하는 Hex 색상 코드를 반환합니다.

     형식: "#RRGGBB"
     - RR: Red (00-FF)
     - GG: Green (00-FF)
     - BB: Blue (00-FF)

     반환값:
     - normal: #4CAF50 (Green) - RGB(76, 175, 80)
     - impact: #F44336 (Red) - RGB(244, 67, 54)
     - parking: #2196F3 (Blue) - RGB(33, 150, 243)
     - manual: #FF9800 (Orange) - RGB(255, 152, 0)
     - emergency: #9C27B0 (Purple) - RGB(156, 39, 176)
     - unknown: #9E9E9E (Gray) - RGB(158, 158, 158)

     사용 예시:
     ```swift
     let event = EventType.impact
     let colorHex = event.colorHex  // "#F44336"

     // macOS: NSColor
     func hexToNSColor(_ hex: String) -> NSColor {
         let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
         var int: UInt64 = 0
         Scanner(string: hex).scanHexInt64(&int)
         let r = CGFloat((int >> 16) & 0xFF) / 255.0
         let g = CGFloat((int >> 8) & 0xFF) / 255.0
         let b = CGFloat(int & 0xFF) / 255.0
         return NSColor(red: r, green: g, blue: b, alpha: 1.0)
     }

     let color = hexToNSColor(event.colorHex)
     eventLabel.textColor = color

     // SwiftUI: Color
     extension Color {
         init(hex: String) {
             let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
             var int: UInt64 = 0
             Scanner(string: hex).scanHexInt64(&int)
             let r = Double((int >> 16) & 0xFF) / 255.0
             let g = Double((int >> 8) & 0xFF) / 255.0
             let b = Double(int & 0xFF) / 255.0
             self.init(red: r, green: g, blue: b)
         }
     }

     Circle()
         .fill(Color(hex: event.colorHex))
         .frame(width: 20, height: 20)
     ```

     색상 선택 이유:
     - Red: 위험/충격 (교통 신호와 일치)
     - Green: 정상/안전
     - Blue: 주차/대기
     - Orange: 주의/수동
     - Purple: 특별/비상
     - Gray: 중립/알 수 없음
     */
    /// Color associated with the event type for UI display
    var colorHex: String {
        switch self {
        case .normal:
            return "#4CAF50"  // Green - 정상/안전
        case .impact:
            return "#F44336"  // Red - 위험/충격
        case .parking:
            return "#2196F3"  // Blue - 주차/대기
        case .manual:
            return "#FF9800"  // Orange - 주의/수동
        case .emergency:
            return "#9C27B0"  // Purple - 특별/비상
        case .unknown:
            return "#9E9E9E"  // Gray - 중립/알 수 없음
        }
    }

    /*
     【우선순위 (Priority)】

     이벤트 유형의 중요도를 나타내는 우선순위를 반환합니다.

     범위: 0 ~ 5
     - 5: emergency (가장 높음)
     - 4: impact
     - 3: manual
     - 2: parking
     - 1: normal
     - 0: unknown (가장 낮음)

     사용 목적:
     1. 정렬: 중요한 영상을 먼저 표시
     2. 필터링: 우선순위 기준으로 필터
     3. 알림: 높은 우선순위만 알림
     4. 백업: 중요한 파일 우선 백업

     사용 예시:
     ```swift
     // 1. 정렬 (우선순위 높은 순)
     let events = [EventType.normal, .impact, .emergency, .parking]
     let sorted = events.sorted { $0.priority > $1.priority }
     // [.emergency, .impact, .parking, .normal]

     // 2. 비디오 정렬
     let sortedVideos = videos.sorted { video1, video2 in
         if video1.eventType.priority != video2.eventType.priority {
             return video1.eventType.priority > video2.eventType.priority
         }
         return video1.timestamp > video2.timestamp  // 같은 우선순위면 최신순
     }

     // 3. 중요 이벤트 필터링
     let importantVideos = videos.filter { $0.eventType.priority >= 3 }

     // 4. 자동 백업 (우선순위 4 이상)
     let backupCandidates = videos.filter { $0.eventType.priority >= 4 }

     // 5. UI 배지 표시
     if event.priority >= 4 {
         showBadge(text: "중요", color: .red)
     }
     ```

     Comparable 프로토콜과 함께 사용:
     ```swift
     let event1 = EventType.normal  // priority = 1
     let event2 = EventType.impact  // priority = 4

     if event1 < event2 {  // true (1 < 4)
         print("event2가 더 중요합니다")
     }

     let events = [EventType.normal, .impact, .emergency]
     let sorted = events.sorted()  // Comparable 프로토콜 사용
     // [.normal, .impact, .emergency]  // 오름차순
     ```
     */
    /// Priority for sorting (higher priority first)
    var priority: Int {
        switch self {
        case .emergency:
            return 5  // 최우선 - 생명/안전 관련
        case .impact:
            return 4  // 높음 - 사고 영상
        case .manual:
            return 3  // 중간 - 사용자가 중요하다고 판단
        case .parking:
            return 2  // 낮음 - 주차 중 이벤트
        case .normal:
            return 1  // 최하위 - 일반 녹화
        case .unknown:
            return 0  // 기본값 - 알 수 없음
        }
    }

    // MARK: - Detection

    /*
     【파일 경로에서 이벤트 유형 감지】

     블랙박스 SD 카드의 파일 경로를 분석하여 이벤트 유형을 자동으로 판별합니다.

     매개변수:
     - path: 분석할 파일 경로 (예: "/sdcard/event/20250115_100000_F.mp4")

     반환값:
     - EventType: 감지된 이벤트 유형

     감지 패턴:
     1. "/normal/" 또는 "normal/" → .normal
     2. "/event/", "/impact/" → .impact
     3. "/parking/", "/park/" → .parking
     4. "/manual/" → .manual
     5. "/emergency/", "/sos/" → .emergency
     6. 매칭 실패 → .unknown

     대소문자 무시:
     - lowercased()로 변환하여 비교
     - "/Event/", "/EVENT/", "/event/" 모두 인식

     경로 패턴:
     - contains(): 중간에 디렉토리명 포함
     - hasPrefix(): 경로 시작 부분에 디렉토리명

     사용 예시:
     ```swift
     // 1. 파일 경로에서 자동 감지
     let path1 = "/sdcard/event/20250115_100000_F.mp4"
     let type1 = EventType.detect(from: path1)  // .impact

     let path2 = "/mnt/sdcard/Normal/20250115_100500_R.mp4"
     let type2 = EventType.detect(from: path2)  // .normal

     let path3 = "emergency/20250115_120000_F.mp4"  // 상대 경로
     let type3 = EventType.detect(from: path3)  // .emergency

     // 2. 파일 스캔 시 자동 분류
     let files = fileManager.contentsOfDirectory(atPath: sdcardPath)
     for file in files {
         let fullPath = sdcardPath + "/" + file
         let eventType = EventType.detect(from: fullPath)
         print("\(file): \(eventType.displayName)")
     }

     // 3. VideoFile 생성 시 자동 설정
     let videoFile = VideoFile(
         path: filePath,
         eventType: EventType.detect(from: filePath),
         // ...
     )

     // 4. 여러 패턴 처리
     let paths = [
         "/normal/file.mp4",        // .normal
         "event/file.mp4",          // .impact
         "/SOS/file.mp4",           // .emergency
         "/unknown_dir/file.mp4"    // .unknown
     ]
     for path in paths {
         print("\(path): \(EventType.detect(from: path))")
     }
     ```

     블랙박스 제조사별 차이:
     - 대부분: "/event/" (충격)
     - 일부: "/impact/" (충격)
     - 일부: "/emer/" (비상)
     - 이 메서드는 여러 패턴 모두 지원

     fallback 처리:
     - 모든 패턴 매칭 실패 시 .unknown 반환
     - 추후 수동 분류 필요
     - 사용자 정의 디렉토리 대응
     */
    /// Detect event type from file path
    /// - Parameter path: File path to analyze
    /// - Returns: Detected event type
    static func detect(from path: String) -> EventType {
        // 대소문자 무시하고 비교
        let lowercasedPath = path.lowercased()

        // 1. Normal 검사
        if lowercasedPath.contains("/normal/") || lowercasedPath.hasPrefix("normal/") {
            return .normal
        }
        // 2. Impact 검사 (event 또는 impact 디렉토리)
        else if lowercasedPath.contains("/event/") || lowercasedPath.hasPrefix("event/") ||
                  lowercasedPath.contains("/impact/") || lowercasedPath.hasPrefix("impact/") {
            return .impact
        }
        // 3. Parking 검사 (parking 또는 park 디렉토리)
        else if lowercasedPath.contains("/parking/") || lowercasedPath.hasPrefix("parking/") ||
                  lowercasedPath.contains("/park/") || lowercasedPath.hasPrefix("park/") {
            return .parking
        }
        // 4. Manual 검사
        else if lowercasedPath.contains("/manual/") || lowercasedPath.hasPrefix("manual/") {
            return .manual
        }
        // 5. Emergency 검사 (emergency 또는 sos 디렉토리)
        else if lowercasedPath.contains("/emergency/") || lowercasedPath.hasPrefix("emergency/") ||
                  lowercasedPath.contains("/sos/") || lowercasedPath.hasPrefix("sos/") {
            return .emergency
        }

        // 6. 매칭 실패 시 unknown 반환
        return .unknown
    }
}

// MARK: - Comparable

/*
 【Comparable 프로토콜 확장】

 EventType을 우선순위 기준으로 정렬할 수 있게 합니다.

 Comparable 프로토콜:
 - <, <=, >, >= 연산자 제공
 - sorted() 함수 사용 가능
 - Equatable을 자동으로 포함

 구현:
 - priority 속성을 기준으로 비교
 - 낮은 priority가 "작음"으로 간주

 사용 예시:
 ```swift
 // 1. 비교 연산
 let normal = EventType.normal  // priority = 1
 let impact = EventType.impact  // priority = 4

 if normal < impact {  // true (1 < 4)
     print("normal이 더 낮은 우선순위")
 }

 if impact > normal {  // true (4 > 1)
     print("impact가 더 높은 우선순위")
 }

 // 2. 배열 정렬 (오름차순)
 let events = [EventType.emergency, .normal, .impact, .parking]
 let ascending = events.sorted()
 // [.normal, .parking, .impact, .emergency]

 // 3. 배열 정렬 (내림차순)
 let descending = events.sorted(by: >)
 // [.emergency, .impact, .parking, .normal]

 // 4. 최소/최대값 찾기
 let minEvent = events.min()  // .normal
 let maxEvent = events.max()  // .emergency

 // 5. 비디오 정렬 (이벤트 우선순위 + 시간)
 let sortedVideos = videos.sorted { video1, video2 in
     if video1.eventType != video2.eventType {
         return video1.eventType > video2.eventType  // 우선순위 높은 순
     }
     return video1.timestamp > video2.timestamp  // 같으면 최신순
 }
 ```

 왜 < 연산자만 구현하는가?
 - Swift가 나머지 연산자 자동 생성
 - < 정의하면 >, <=, >= 자동으로 사용 가능
 - Comparable 프로토콜의 요구사항
 */
extension EventType: Comparable {
    /*
     【< 연산자 구현】

     두 EventType을 우선순위로 비교합니다.

     매개변수:
     - lhs: Left Hand Side (왼쪽 피연산자)
     - rhs: Right Hand Side (오른쪽 피연산자)

     반환값:
     - Bool: lhs의 우선순위가 rhs보다 낮으면 true

     예시:
     ```swift
     EventType.normal < EventType.impact  // true (1 < 4)
     EventType.emergency < EventType.normal  // false (5 < 1은 false)
     ```
     */
    static func < (lhs: EventType, rhs: EventType) -> Bool {
        return lhs.priority < rhs.priority  // 우선순위 숫자로 비교
    }
}
