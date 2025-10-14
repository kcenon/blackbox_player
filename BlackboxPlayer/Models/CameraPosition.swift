/// @file CameraPosition.swift
/// @brief 블랙박스 카메라 위치/채널 식별 열거형
/// @author BlackboxPlayer Development Team
///
/// Enum for camera position/channel identification

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                    CameraPosition Enum 개요                              │
 │                                                                          │
 │  멀티 카메라 블랙박스 시스템에서 각 카메라의 위치/채널을 식별합니다.     │
 │                                                                          │
 │  【카메라 위치】                                                         │
 │                                                                          │
 │  1. front (전방 카메라)                                                  │
 │     - 코드: F                                                            │
 │     - 인덱스: 0                                                          │
 │     - 우선순위: 1 (최우선 표시)                                          │
 │                                                                          │
 │  2. rear (후방 카메라)                                                   │
 │     - 코드: R                                                            │
 │     - 인덱스: 1                                                          │
 │     - 우선순위: 2                                                        │
 │                                                                          │
 │  3. left (좌측 카메라)                                                   │
 │     - 코드: L                                                            │
 │     - 인덱스: 2                                                          │
 │     - 우선순위: 3                                                        │
 │                                                                          │
 │  4. right (우측 카메라)                                                  │
 │     - 코드: Ri                                                           │
 │     - 인덱스: 3                                                          │
 │     - 우선순위: 4                                                        │
 │                                                                          │
 │  5. interior (실내 카메라)                                               │
 │     - 코드: I                                                            │
 │     - 인덱스: 4                                                          │
 │     - 우선순위: 5                                                        │
 │                                                                          │
 │  6. unknown (알 수 없음)                                                 │
 │     - 코드: U                                                            │
 │     - 인덱스: -1 (무효)                                                  │
 │     - 우선순위: 99 (최하위)                                              │
 │                                                                          │
 │  【멀티 카메라 시스템 배치】                                             │
 │                                                                          │
 │                    L (Left)                                              │
 │                      │                                                   │
 │             ┌────────┼────────┐                                          │
 │             │                 │                                          │
 │             │    F (Front)    │                                          │
 │             │        ▲        │                                          │
 │             │        │        │                                          │
 │             │  I (Interior)   │                                          │
 │             │        │        │                                          │
 │             │        ▼        │                                          │
 │             │    R (Rear)     │                                          │
 │             │                 │                                          │
 │             └────────┼────────┘                                          │
 │                      │                                                   │
 │                 Ri (Right)                                               │
 │                                                                          │
 │  【파일명 패턴】                                                         │
 │                                                                          │
 │  블랙박스 파일명에서 카메라 위치를 자동 감지합니다.                      │
 │                                                                          │
 │  형식: YYYY_MM_DD_HH_MM_SS_[Position].mp4                                │
 │                                                                          │
 │  예시:                                                                   │
 │  - 2025_01_10_09_00_00_F.mp4  → .front                                  │
 │  - 2025_01_10_09_00_00_R.mp4  → .rear                                   │
 │  - 2025_01_10_09_00_00_L.mp4  → .left                                   │
 │  - 2025_01_10_09_00_00_Ri.mp4 → .right                                  │
 │  - 2025_01_10_09_00_00_I.mp4  → .interior                               │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【멀티 카메라 블랙박스란?】

 여러 대의 카메라를 동시에 사용하는 블랙박스 시스템입니다.

 일반적인 구성:
 - 2채널: 전방 + 후방
 - 3채널: 전방 + 후방 + 실내
 - 4채널: 전방 + 후방 + 좌측 + 우측
 - 5채널: 전방 + 후방 + 좌측 + 우측 + 실내

 각 카메라의 역할:
 - Front (전방): 주 카메라, 전방 사고 기록
 - Rear (후방): 후방 추돌 기록
 - Left/Right (좌우): 측면 접촉 사고 기록
 - Interior (실내): 운전자 모습, 택시/차량 공유

 파일 동기화:
 - 모든 카메라가 동시에 녹화
 - 같은 타임스탬프로 파일 생성
 - 예:
 2025_01_10_09_00_00_F.mp4  (전방)
 2025_01_10_09_00_00_R.mp4  (후방)
 → 같은 시각의 전방/후방 영상

 【Raw Value 코드】

 각 카메라 위치를 짧은 문자로 표현합니다.

 코드 선택 이유:
 - F (Front): 전방의 첫 글자
 - R (Rear): 후방의 첫 글자
 - L (Left): 좌측의 첫 글자
 - Ri (Right): 'R'이 Rear와 겹쳐서 'Ri' 사용
 - I (Interior): 실내의 첫 글자
 - U (Unknown): 알 수 없음

 파일명에서 사용:
 - 짧은 코드로 파일명 간결화
 - 2025_01_10_09_00_00_F.mp4 (짧음)
 - vs 2025_01_10_09_00_00_Front.mp4 (김)

 【Channel Index란?】

 각 카메라를 배열 인덱스로 관리합니다.

 배열 구조:
 ```swift
 channels: [ChannelInfo]
 // [0]: Front
 // [1]: Rear
 // [2]: Left
 // [3]: Right
 // [4]: Interior
 ```

 사용 예시:
 ```swift
 let frontChannel = channels[0]  // 전방 카메라
 let rearChannel = channels[1]   // 후방 카메라

 // 또는
 let frontIndex = CameraPosition.front.channelIndex  // 0
 let frontChannel = channels[frontIndex]
 ```

 왜 배열 인덱스가 필요한가?
 - 여러 채널을 배열로 관리
 - 빠른 접근 (O(1))
 - 순회 처리 용이
 */

import Foundation

/*
 【CameraPosition 열거형】

 멀티 카메라 블랙박스 시스템에서 카메라 위치/채널을 식별합니다.

 프로토콜:
 - String: Raw Value로 카메라 코드 사용 (F, R, L, Ri, I, U)
 - Codable: JSON 직렬화/역직렬화
 - CaseIterable: allCases 배열 제공
 - Comparable: 표시 우선순위 기반 정렬

 사용 예시:
 ```swift
 // 1. 파일명에서 자동 감지
 let filename = "2025_01_10_09_00_00_F.mp4"
 let position = CameraPosition.detect(from: filename)  // .front

 // 2. UI 표시
 let displayName = position.displayName  // "Front"
 let shortName = position.shortName  // "F"
 let fullName = position.fullName  // "Front Camera"

 // 3. 배열 인덱싱
 let index = position.channelIndex  // 0
 let channel = channels[index]

 // 4. 정렬 (표시 우선순위)
 let positions = [CameraPosition.rear, .front, .interior]
 let sorted = positions.sorted()  // [.front, .rear, .interior]
 ```
 */
/// @enum CameraPosition
/// @brief 멀티 카메라 블랙박스 시스템의 카메라 위치/채널
///
/// Camera position/channel in a multi-camera dashcam system
enum CameraPosition: String, Codable, CaseIterable {
    /*
     【front - 전방 카메라】

     차량 전방을 촬영하는 주(main) 카메라입니다.

     특징:
     - 블랙박스의 기본 카메라
     - 가장 중요한 영상 (사고 대부분 전방)
     - 고해상도 (Full HD 이상)
     - 넓은 시야각 (120-140도)

     파일명 코드: F
     - 예: 2025_01_10_09_00_00_F.mp4

     채널 인덱스: 0
     - channels[0] = 전방 카메라

     표시 우선순위: 1 (최우선)
     - UI에서 가장 먼저 표시
     - 멀티뷰에서 큰 화면 할당

     용도:
     - 전방 추돌 사고
     - 신호 위반 단속
     - 차선 이탈
     - 보행자 사고
     */
    /// @brief 전방 카메라 (주 카메라)
    ///
    /// Front-facing camera (main camera)
    case front = "F"

    /*
     【rear - 후방 카메라】

     차량 후방을 촬영하는 카메라입니다.

     특징:
     - 2채널 블랙박스의 기본 구성
     - 후방 추돌 대비
     - 주차 시 유용
     - 전방보다 낮은 해상도 (HD)

     파일명 코드: R
     - 예: 2025_01_10_09_00_00_R.mp4

     채널 인덱스: 1
     - channels[1] = 후방 카메라

     표시 우선순위: 2
     - 전방 다음으로 중요
     - 멀티뷰에서 두 번째 화면

     용도:
     - 후방 추돌 사고
     - 주차장 접촉 사고
     - 역주행 차량
     - 후진 사고
     */
    /// @brief 후방 카메라
    ///
    /// Rear-facing camera
    case rear = "R"

    /*
     【left - 좌측 카메라】

     차량 좌측을 촬영하는 카메라입니다.

     특징:
     - 3-4채널 블랙박스에 포함
     - 좌측 사각지대 커버
     - 차선 변경 사고 대비
     - 보통 사이드미러 근처 장착

     파일명 코드: L
     - 예: 2025_01_10_09_00_00_L.mp4

     채널 인덱스: 2
     - channels[2] = 좌측 카메라

     표시 우선순위: 3
     - 전방, 후방 다음
     - 선택적 표시

     용도:
     - 좌측 접촉 사고
     - 차선 변경 사고
     - 사각지대 감시
     - 옆차와의 충돌
     */
    /// @brief 좌측 카메라
    ///
    /// Left side camera
    case left = "L"

    /*
     【right - 우측 카메라】

     차량 우측을 촬영하는 카메라입니다.

     특징:
     - 4채널 블랙박스에 포함
     - 우측 사각지대 커버
     - 운전석 반대편 감시
     - 보통 사이드미러 근처 장착

     파일명 코드: Ri (R은 Rear와 중복)
     - 예: 2025_01_10_09_00_00_Ri.mp4

     채널 인덱스: 3
     - channels[3] = 우측 카메라

     표시 우선순위: 4
     - 좌측 다음
     - 선택적 표시

     용도:
     - 우측 접촉 사고
     - 우회전 사고
     - 사각지대 감시
     - 보행자 사고 (오른쪽)

     왜 "Ri"인가?:
     - "R"은 이미 Rear(후방)에서 사용
     - "Right"의 첫 두 글자 사용
     - 충돌 방지 위한 고유 코드
     */
    /// @brief 우측 카메라
    ///
    /// Right side camera
    case right = "Ri"

    /*
     【interior - 실내 카메라】

     차량 실내(운전석)를 촬영하는 카메라입니다.

     특징:
     - 운전자 얼굴 촬영
     - 야간 촬영 가능 (IR LED)
     - 프라이버시 이슈 가능
     - 택시/화물차에 필수

     파일명 코드: I
     - 예: 2025_01_10_09_00_00_I.mp4

     채널 인덱스: 4
     - channels[4] = 실내 카메라

     표시 우선순위: 5 (최하위)
     - 선택적 표시
     - 프라이버시 고려

     용도:
     - 운전자 상태 확인
     - 졸음운전 감지
     - 차량 공유 서비스
     - 택시 기사 보호
     - 분쟁 해결

     프라이버시:
     - 개인 차량에서는 선택 사항
     - 일부 국가에서는 동의 필요
     - 실내 녹화 경고 표시
     */
    /// @brief 실내 카메라 (차량 내부)
    ///
    /// Interior camera (cabin view)
    case interior = "I"

    /*
     【unknown - 알 수 없는 위치】

     파일명에서 카메라 위치를 판별할 수 없을 때 사용합니다.

     발생 원인:
     - 비표준 파일명
     - 손상된 파일명
     - 알 수 없는 블랙박스 모델
     - 사용자 정의 파일명

     파일명 코드: U
     - 예: 2025_01_10_09_00_00_U.mp4

     채널 인덱스: -1 (무효)
     - 배열 인덱싱에 사용 불가
     - 별도 처리 필요

     표시 우선순위: 99 (최하위)
     - 정렬 시 맨 아래
     - 수동 분류 필요

     처리 방법:
     ```swift
     if position == .unknown {
     // 사용자에게 카메라 위치 선택 요청
     showCameraPositionSelector()
     }
     ```
     */
    /// @brief 알 수 없는 위치
    ///
    /// Unknown or unrecognized position
    case unknown = "U"

    // MARK: - Display Properties

    /*
     【표시 이름 (Display Name)】

     UI에 표시할 간단한 이름을 반환합니다.

     반환값:
     - String: 카메라 위치의 영문 이름

     사용 예시:
     ```swift
     let position = CameraPosition.front
     let name = position.displayName  // "Front"

     // UI 레이블
     cameraLabel.stringValue = position.displayName

     // 탭 제목
     TabView {
     VideoView()
     .tabItem { Text(position.displayName) }
     }

     // 리스트 아이템
     List(positions) { position in
     Text(position.displayName)
     }
     ```

     짧은 형식:
     - "Front", "Rear", "Left", "Right"
     - 공간 제약이 있는 UI에 적합
     - 아이콘과 함께 표시
     */
    /// @brief 사람이 읽을 수 있는 표시 이름
    /// @return 카메라 위치의 영문 이름
    ///
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .front:
            return "Front"  // 전방
        case .rear:
            return "Rear"  // 후방
        case .left:
            return "Left"  // 좌측
        case .right:
            return "Right"  // 우측
        case .interior:
            return "Interior"  // 실내
        case .unknown:
            return "Unknown"  // 알 수 없음
        }
    }

    /*
     【짧은 이름 (Short Name)】

     가장 짧은 형식의 이름을 반환합니다 (rawValue와 동일).

     반환값:
     - String: 카메라 코드 (F, R, L, Ri, I, U)

     사용 예시:
     ```swift
     let position = CameraPosition.front
     let short = position.shortName  // "F"

     // 아이콘 오버레이
     Text(position.shortName)
     .font(.caption)
     .foregroundColor(.white)
     .padding(4)
     .background(Color.blue)

     // 작은 배지
     Circle()
     .fill(Color.blue)
     .overlay(Text(position.shortName))
     .frame(width: 30, height: 30)

     // 파일명 생성
     let filename = "\(timestamp)_\(position.shortName).mp4"
     // "2025_01_10_09_00_00_F.mp4"
     ```

     언제 사용하는가?:
     - 공간이 매우 제한적일 때
     - 아이콘 라벨
     - 파일명 생성
     - 로그 출력
     */
    /// @brief UI 표시용 짧은 이름
    /// @return 카메라 코드 (F, R, L, Ri, I, U)
    ///
    /// Short name for UI display
    var shortName: String {
        return rawValue  // F, R, L, Ri, I, U
    }

    /*
     【전체 이름 (Full Name)】

     가장 자세한 형식의 이름을 반환합니다.

     반환값:
     - String: "Camera" 포함된 전체 이름

     사용 예시:
     ```swift
     let position = CameraPosition.front
     let full = position.fullName  // "Front Camera"

     // 상세 정보 표시
     detailLabel.stringValue = position.fullName

     // 설정 화면
     Picker(position.fullName, selection: $selectedPosition) {
     ForEach(CameraPosition.allCases, id: \.self) { pos in
     Text(pos.fullName).tag(pos)
     }
     }

     // 툴팁
     Button(action: {}) {
     Image(systemName: "video")
     }
     .help(position.fullName)  // "Front Camera" 툴팁 표시
     ```

     비교:
     - shortName: "F" (가장 짧음)
     - displayName: "Front" (중간)
     - fullName: "Front Camera" (가장 길고 명확)
     */
    /// @brief 전체 설명 이름
    /// @return "Camera" 포함된 전체 이름
    ///
    /// Full descriptive name
    var fullName: String {
        switch self {
        case .front:
            return "Front Camera"  // 전방 카메라
        case .rear:
            return "Rear Camera"  // 후방 카메라
        case .left:
            return "Left Side Camera"  // 좌측 카메라
        case .right:
            return "Right Side Camera"  // 우측 카메라
        case .interior:
            return "Interior Camera"  // 실내 카메라
        case .unknown:
            return "Unknown Camera"  // 알 수 없는 카메라
        }
    }

    /*
     【채널 인덱스 (Channel Index)】

     배열 인덱싱을 위한 0-based 인덱스를 반환합니다.

     반환값:
     - Int: 0-4 (유효), -1 (unknown)

     채널 배열 구조:
     ```swift
     channels: [ChannelInfo]
     // index 0: Front
     // index 1: Rear
     // index 2: Left
     // index 3: Right
     // index 4: Interior
     ```

     사용 예시:
     ```swift
     // 1. 특정 채널 접근
     let frontIndex = CameraPosition.front.channelIndex  // 0
     let frontChannel = videoFile.channels[frontIndex]

     // 2. 안전한 접근 (unknown 체크)
     if position.channelIndex >= 0 && position.channelIndex < channels.count {
     let channel = channels[position.channelIndex]
     } else {
     print("⚠️ 유효하지 않은 채널 인덱스")
     }

     // 3. 채널 순회
     for position in CameraPosition.allCases {
     guard position != .unknown else { continue }
     let index = position.channelIndex
     if index < channels.count {
     let channel = channels[index]
     print("\(position.displayName): \(channel.filePath)")
     }
     }

     // 4. 인덱스로 Position 찾기
     if let position = CameraPosition.from(channelIndex: 1) {
     print(position.displayName)  // "Rear"
     }
     ```

     왜 -1인가? (unknown):
     - 유효하지 않은 인덱스 표시
     - 배열 접근 방지
     - 에러 체크 용이
     */
    /// @brief 배열 인덱싱을 위한 채널 인덱스 (0-based)
    /// @return 0-4 (유효), -1 (unknown)
    ///
    /// Channel index (0-based) for array indexing
    var channelIndex: Int {
        switch self {
        case .front:
            return 0  // 전방 카메라
        case .rear:
            return 1  // 후방 카메라
        case .left:
            return 2  // 좌측 카메라
        case .right:
            return 3  // 우측 카메라
        case .interior:
            return 4  // 실내 카메라
        case .unknown:
            return -1  // 유효하지 않음
        }
    }

    /*
     【표시 우선순위 (Display Priority)】

     UI에서 카메라를 표시할 순서를 나타내는 우선순위입니다.

     범위: 1-99
     - 1: front (최우선)
     - 2: rear
     - 3: left
     - 4: right
     - 5: interior
     - 99: unknown (최하위)

     사용 목적:
     1. 멀티뷰 레이아웃: 중요한 카메라 큰 화면
     2. 탭 순서: 전방부터 순서대로
     3. 자동 정렬: 우선순위 기준
     4. 기본 표시: 우선순위 높은 것만

     사용 예시:
     ```swift
     // 1. 정렬 (우선순위 순)
     let positions = [CameraPosition.interior, .front, .rear]
     let sorted = positions.sorted()  // [.front, .rear, .interior]

     // 2. 멀티뷰 레이아웃
     let mainCamera = positions.min()  // .front (우선순위 1)
     let subCameras = positions.filter { $0 != mainCamera }

     // 3. 탭 순서
     TabView {
     ForEach(CameraPosition.allCases.sorted(), id: \.self) { position in
     VideoView(position: position)
     .tabItem { Text(position.displayName) }
     }
     }

     // 4. 우선순위 필터링 (메인 카메라만)
     let mainCameras = positions.filter { $0.displayPriority <= 2 }
     // [.front, .rear]
     ```

     왜 이 순서인가?:
     - Front (1): 가장 중요, 사고 대부분 전방
     - Rear (2): 후방 추돌 대비, 두 번째로 중요
     - Left/Right (3-4): 선택적, 사각지대
     - Interior (5): 프라이버시, 선택적
     - Unknown (99): 분류 필요
     */
    /// @brief 표시 순서 우선순위
    /// @return 1-99 (1: 최우선, 99: 최하위)
    ///
    /// Priority for display ordering
    var displayPriority: Int {
        switch self {
        case .front:
            return 1  // 최우선 - 전방 카메라
        case .rear:
            return 2  // 후방 카메라
        case .left:
            return 3  // 좌측 카메라
        case .right:
            return 4  // 우측 카메라
        case .interior:
            return 5  // 실내 카메라
        case .unknown:
            return 99  // 최하위 - 알 수 없음
        }
    }

    // MARK: - Detection

    /*
     【파일명에서 카메라 위치 감지】

     블랙박스 파일명을 분석하여 카메라 위치를 자동으로 판별합니다.

     매개변수:
     - filename: 분석할 파일명 (예: "2025_01_10_09_00_00_F.mp4")

     반환값:
     - CameraPosition: 감지된 카메라 위치

     파일명 형식:
     ```
     YYYY_MM_DD_HH_MM_SS_[Position].mp4
     └── F, R, L, Ri, I
     ```

     감지 알고리즘:
     1. "_"로 파일명 분리
     2. 마지막 컴포넌트 추출
     3. 확장자 제거
     4. 정확한 매칭 시도 (F, R, L, Ri, I, U)
     5. 부분 매칭 시도 (F, R, L, Ri, I 포함)
     6. 모두 실패 시 unknown 반환

     사용 예시:
     ```swift
     // 1. 표준 파일명
     let filename1 = "2025_01_10_09_00_00_F.mp4"
     let position1 = CameraPosition.detect(from: filename1)  // .front

     let filename2 = "2025_01_10_09_00_00_R.mp4"
     let position2 = CameraPosition.detect(from: filename2)  // .rear

     // 2. 변형 파일명
     let filename3 = "video_F.mp4"
     let position3 = CameraPosition.detect(from: filename3)  // .front

     let filename4 = "dashcam_Ri_001.mp4"
     let position4 = CameraPosition.detect(from: filename4)  // .right

     // 3. 파일 스캔 시 자동 분류
     let files = ["20250110_090000_F.mp4", "20250110_090000_R.mp4"]
     for filename in files {
     let position = CameraPosition.detect(from: filename)
     print("\(filename): \(position.displayName)")
     }
     // 출력:
     // 20250110_090000_F.mp4: Front
     // 20250110_090000_R.mp4: Rear

     // 4. ChannelInfo 생성 시
     let channelInfo = ChannelInfo(
     position: CameraPosition.detect(from: filename),
     filePath: fullPath,
     // ...
     )
     ```

     Ri vs R 구분:
     - "Ri" 체크를 먼저 수행
     - "R" && !contains("Ri") 조건
     - Rear와 Right 정확히 구분

     fallback:
     - 모든 패턴 매칭 실패 시 .unknown
     - 사용자에게 수동 선택 요청
     */
    /// @brief 파일명에서 카메라 위치 자동 감지
    /// @param filename 분석할 파일명 (예: "2025_01_10_09_00_00_F.mp4")
    /// @return 감지된 카메라 위치
    ///
    /// Detect camera position from filename
    /// - Parameter filename: Filename to analyze (e.g., "2025_01_10_09_00_00_F.mp4")
    /// - Returns: Detected camera position
    static func detect(from filename: String) -> CameraPosition {
        // Extract the camera identifier (usually before the extension)
        // Format: YYYY_MM_DD_HH_MM_SS_[Position].mp4
        let components = filename.components(separatedBy: "_")  // "_"로 분리

        // Check last component before extension
        // 마지막 컴포넌트 (확장자 제거)
        if let lastComponent = components.last {
            let withoutExtension = lastComponent.components(separatedBy: ".").first ?? ""

            // Try exact match first
            // 1. 정확한 매칭 시도
            for position in CameraPosition.allCases {
                if withoutExtension == position.rawValue {
                    return position
                }
            }

            // Try partial match
            // 2. 부분 매칭 시도
            if withoutExtension.contains("F") {
                return .front  // "F" 포함 → 전방
            } else if withoutExtension.contains("R") && !withoutExtension.contains("Ri") {
                return .rear  // "R" 포함하지만 "Ri"는 아님 → 후방
            } else if withoutExtension.contains("L") {
                return .left  // "L" 포함 → 좌측
            } else if withoutExtension.contains("Ri") {
                return .right  // "Ri" 포함 → 우측
            } else if withoutExtension.contains("I") {
                return .interior  // "I" 포함 → 실내
            }
        }

        // 3. 모든 매칭 실패 → unknown
        return .unknown
    }

    /*
     【채널 인덱스로부터 Position 생성】

     배열 인덱스로부터 CameraPosition을 찾습니다.

     매개변수:
     - index: 채널 인덱스 (0-4)

     반환값:
     - CameraPosition?: 찾은 Position (없으면 nil)

     사용 예시:
     ```swift
     // 1. 인덱스로 Position 찾기
     if let position = CameraPosition.from(channelIndex: 0) {
     print(position.displayName)  // "Front"
     }

     if let position = CameraPosition.from(channelIndex: 1) {
     print(position.displayName)  // "Rear"
     }

     // 2. 유효하지 않은 인덱스
     if let position = CameraPosition.from(channelIndex: 10) {
     print(position.displayName)
     } else {
     print("유효하지 않은 인덱스")  // 이것 출력
     }

     // 3. 채널 배열 순회
     for index in 0..<channels.count {
     if let position = CameraPosition.from(channelIndex: index) {
     let channel = channels[index]
     print("\(position.displayName): \(channel.filePath)")
     }
     }

     // 4. 안전한 배열 접근
     func getChannel(at index: Int) -> ChannelInfo? {
     guard let position = CameraPosition.from(channelIndex: index),
     index >= 0 && index < channels.count else {
     return nil
     }
     return channels[index]
     }
     ```

     구현:
     - allCases를 순회하며 channelIndex 일치 찾기
     - first() 사용으로 첫 번째 매칭만 반환
     - 없으면 nil 반환

     왜 Optional인가?:
     - -1 (unknown) 같은 무효 인덱스 처리
     - 범위 초과 인덱스 (5, 6, ...) 처리
     - 안전한 nil 반환
     */
    /// @brief 채널 인덱스로부터 CameraPosition 생성
    /// @param index 채널 인덱스 (0-4)
    /// @return 찾은 Position 또는 nil
    ///
    /// Create camera position from channel index
    /// - Parameter index: Channel index (0-4)
    /// - Returns: Camera position or nil if invalid
    static func from(channelIndex index: Int) -> CameraPosition? {
        // allCases를 순회하며 channelIndex가 일치하는 첫 번째 Position 반환
        return CameraPosition.allCases.first { $0.channelIndex == index }
    }
}

// MARK: - Comparable

/*
 【Comparable 프로토콜 확장】

 CameraPosition을 표시 우선순위 기준으로 정렬할 수 있게 합니다.

 Comparable 프로토콜:
 - <, <=, >, >= 연산자 제공
 - sorted() 함수 사용 가능
 - Equatable을 자동으로 포함

 구현:
 - displayPriority 속성을 기준으로 비교
 - 낮은 priority가 "작음"으로 간주

 사용 예시:
 ```swift
 // 1. 비교 연산
 let front = CameraPosition.front  // priority = 1
 let rear = CameraPosition.rear    // priority = 2

 if front < rear {  // true (1 < 2)
 print("front가 우선순위 높음")
 }

 // 2. 배열 정렬 (오름차순 = 우선순위 높은 순)
 let positions = [CameraPosition.interior, .front, .rear, .left]
 let sorted = positions.sorted()
 // [.front, .rear, .left, .interior]

 // 3. 최소/최대값
 let minPosition = positions.min()  // .front (우선순위 1)
 let maxPosition = positions.max()  // .interior (우선순위 5)

 // 4. 멀티뷰 레이아웃
 let mainCamera = availablePositions.min()  // 가장 우선순위 높은 것
 let subCameras = availablePositions.filter { $0 != mainCamera }

 // 5. 탭 순서
 ForEach(CameraPosition.allCases.sorted(), id: \.self) { position in
 VideoPlayerView(position: position)
 .tabItem { Text(position.displayName) }
 }
 ```

 왜 < 연산자만 구현하는가?:
 - Swift가 나머지 연산자 자동 생성
 - < 정의하면 >, <=, >= 자동으로 사용 가능
 - Comparable 프로토콜의 요구사항
 */
extension CameraPosition: Comparable {
    /*
     【< 연산자 구현】

     두 CameraPosition을 표시 우선순위로 비교합니다.

     매개변수:
     - lhs: Left Hand Side (왼쪽 피연산자)
     - rhs: Right Hand Side (오른쪽 피연산자)

     반환값:
     - Bool: lhs의 표시 우선순위가 rhs보다 높으면 true (숫자가 작으면 우선순위 높음)

     예시:
     ```swift
     CameraPosition.front < CameraPosition.rear  // true (1 < 2)
     CameraPosition.rear < CameraPosition.front  // false (2 < 1은 false)
     CameraPosition.interior < CameraPosition.unknown  // true (5 < 99)
     ```

     주의:
     - displayPriority가 낮을수록 우선순위 높음
     - front (1) < rear (2): front가 우선
     */
    static func < (lhs: CameraPosition, rhs: CameraPosition) -> Bool {
        return lhs.displayPriority < rhs.displayPriority  // 우선순위 숫자로 비교
    }
}
