/// @file FileRow.swift
/// @brief 비디오 파일 목록 행 컴포넌트
/// @author BlackboxPlayer Development Team
/// @details
/// 비디오 파일 목록에서 개별 행을 표시하는 재사용 가능한 UI 컴포넌트입니다.
/// 이벤트 타입 배지, 파일 정보, 메타데이터, 상태 인디케이터를 표시합니다.

/*
 【FileRow 개요】

 이 파일은 비디오 파일 목록에서 개별 행(Row)을 표시하는 재사용 가능한 UI 컴포넌트를 구현합니다.


 ┌─────────────────────────────────────────────────────────────────────┐
 │ [IMPACT] 2024_03_15_14_23_45_F.mp4           14:23:45 PM   ▶       │
 │          2:34 mins  │  1.2 GB  │  2 channels  │  📍  ⚠️  ⭐         │
 └─────────────────────────────────────────────────────────────────────┘
  ~~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~~~~
  이벤트       파일 정보                 메타데이터             재생
  배지         (이름, 시간)              (시간, 크기, 채널)     버튼


 【주요 기능】

 1. 이벤트 타입 배지
    - NORMAL (녹화)
    - IMPACT (충격)
    - PARKING (주차)
    - MANUAL (수동)
    - EMERGENCY (비상)

 2. 파일 정보
    - 파일명 (모노스페이스 폰트)
    - 타임스탬프 (날짜 및 시간)

 3. 메타데이터
    - 재생 시간 (Duration)
    - 파일 크기 (File size)
    - 채널 수 (Channel count)

 4. 상태 인디케이터
    - 📍 GPS: GPS 데이터 포함
    - ⚠️ Impact: 충격 이벤트 포함
    - ⭐ Favorite: 즐겨찾기 표시
    - ❌ Corrupted: 파일 손상

 5. 선택 상태 표시
    - 선택되지 않음: 투명 배경
    - 선택됨: 강조 색상 배경 + 테두리


 【사용 예시】

 ```swift
 // 1. List에서 사용
 List(videoFiles) { file in
     FileRow(videoFile: file, isSelected: selectedFile?.id == file.id)
         .onTapGesture {
             selectedFile = file
         }
 }

 // 2. ForEach에서 사용
 ForEach(videoFiles) { file in
     FileRow(videoFile: file, isSelected: false)
 }

 // 3. 단독으로 사용
 FileRow(videoFile: .normal5Channel, isSelected: true)
     .padding()
 ```


 【SwiftUI 개념】

 이 파일에서 배울 수 있는 주요 SwiftUI 개념들:

 1. 재사용 가능한 컴포넌트
    - 여러 곳에서 사용 가능한 독립적인 View
    - 데이터 주입 방식 (let properties)

 2. 조건부 렌더링 (Conditional Rendering)
    - if문으로 특정 조건에서만 View 표시
    - Optional chaining

 3. Layout Containers
    - HStack: 좌우 배치
    - VStack: 상하 배치
    - Spacer: 공간 분배

 4. Label 컴포넌트
    - 아이콘 + 텍스트 조합
    - SF Symbols 통합

 5. Shape와 Modifiers
    - RoundedRectangle
    - .background(), .overlay()
    - .stroke(), .fill()

 6. 선택 상태 표현
    - 삼항 연산자 (isSelected ? A : B)
    - 동적 스타일링


 【디자인 패턴】

 **재사용 가능한 컴포넌트 (Reusable Component):**

 FileRow는 다음 원칙을 따릅니다:

 ✓ 단일 책임 (Single Responsibility)
   → 비디오 파일 정보를 표시하는 것만 담당

 ✓ 독립성 (Independence)
   → 외부 상태에 의존하지 않음
   → 필요한 데이터만 주입받음

 ✓ 구성 (Composition)
   → 작은 서브뷰(EventBadge)로 분리
   → 각 부분을 독립적으로 관리

 ✓ 선언적 (Declarative)
   → "어떻게"가 아닌 "무엇"을 선언
   → SwiftUI가 렌더링 처리


 【관련 파일】

 - VideoFile.swift: 비디오 파일 데이터 모델
 - EventType.swift: 이벤트 타입 enum
 - FileListView.swift: FileRow를 사용하는 리스트 뷰

 */

import SwiftUI

/// @struct FileRow
/// @brief 비디오 파일 목록 행 컴포넌트
///
/// @details
/// 비디오 파일 목록에서 개별 행을 표시하는 재사용 가능한 컴포넌트입니다.
///
/// **주요 기능:**
/// - 이벤트 타입 배지 (색상 코딩)
/// - 파일 정보 (이름, 타임스탬프)
/// - 메타데이터 (시간, 크기, 채널)
/// - 상태 인디케이터 (GPS, 충격, 즐겨찾기, 손상)
/// - 선택 상태 표시
///
/// **사용 예시:**
/// ```swift
/// List(videoFiles) { file in
///     FileRow(videoFile: file, isSelected: selectedFile?.id == file.id)
///         .onTapGesture {
///             selectedFile = file
///         }
/// }
/// ```
///
/// **연관 타입:**
/// - `VideoFile`: 비디오 파일 데이터
/// - `EventType`: 이벤트 타입 enum
///
struct FileRow: View {
    // MARK: - Properties

    /// @var videoFile
    /// @brief 표시할 비디오 파일 데이터
    ///
    /// **let을 사용하는 이유:**
    ///
    /// FileRow는 데이터를 수정하지 않고 표시만 합니다:
    ///   - 불변성 보장 (immutability)
    ///   - 의도 명확화 ("이 데이터는 읽기 전용")
    ///   - 버그 방지 (실수로 수정 불가)
    ///
    /// **VideoFile의 주요 프로퍼티:**
    /// ```swift
    /// struct VideoFile {
    ///     let baseFilename: String         // "2024_03_15_14_23_45_F.mp4"
    ///     let eventType: EventType         // .impact
    ///     let timestampString: String      // "March 15, 2024 at 2:23 PM"
    ///     let durationString: String       // "2:34"
    ///     let totalFileSizeString: String  // "1.2 GB"
    ///     let channelCount: Int            // 2
    ///     let hasGPSData: Bool             // true
    ///     let hasImpactEvents: Bool        // true
    ///     let isFavorite: Bool             // false
    ///     let isCorrupted: Bool            // false
    ///     let isPlayable: Bool             // true
    /// }
    /// ```
    ///
    let videoFile: VideoFile

    /// @var isSelected
    /// @brief 행 선택 상태 여부
    ///
    /// **왜 외부에서 주입받는가?**
    ///
    /// 선택 상태는 부모 View가 관리합니다:
    ///
    /// ```swift
    /// // 부모 View
    /// @State private var selectedFile: VideoFile?
    ///
    /// List(videoFiles) { file in
    ///     FileRow(
    ///         videoFile: file,
    ///         isSelected: selectedFile?.id == file.id  // 외부에서 결정
    ///     )
    /// }
    /// ```
    ///
    /// 이 방식의 장점:
    ///   - 부모가 선택 로직 제어
    ///   - FileRow는 표시만 담당 (단일 책임)
    ///   - 다중 선택, 단일 선택 등 다양한 패턴 지원
    ///
    let isSelected: Bool

    // MARK: - Body

    var body: some View {
        // **HStack - 좌우 레이아웃:**
        //
        // HStack은 자식 View들을 가로(horizontal) 방향으로 배치합니다.
        //
        // 이 행의 레이아웃:
        // ```
        // [배지] [파일정보]           [재생버튼]
        // ~~~~~~ ~~~~~~~~~~~~~~~~~~~ ~~~~~~~~~~
        // 80pt   가변 크기 (Spacer)   고정 크기
        // ```
        //
        // **spacing: 12**
        //   - 각 요소 사이에 12pt 간격
        //   - 너무 촘촘하지 않고 적당히 분리
        //
        HStack(spacing: 12) {
            // MARK: Event Type Badge

            // Event type badge
            //
            // 이벤트 타입을 색상 배지로 표시합니다.
            //
            // **EventBadge 서브 컴포넌트:**
            //
            // EventBadge는 이 파일 하단에 정의된 별도의 View입니다:
            //   - 이벤트 타입을 받아서
            //   - 색상 배경에 텍스트 표시
            //   - 재사용 가능
            //
            // 예시:
            // ```
            // IMPACT: 빨간색 배경에 "IMPACT"
            // NORMAL: 녹색 배경에 "NORMAL"
            // ```
            //
            EventBadge(eventType: videoFile.eventType)
                // **.frame(width: 80):**
                //
                // 배지의 너비를 80pt로 고정합니다.
                //
                // 고정 너비를 사용하는 이유:
                //   - 모든 행에서 배지 위치가 일정
                //   - 세로 정렬이 깔끔하게 맞음
                //   - 텍스트 길이가 달라도 일관성 유지
                //
                // 너비 비교:
                // ```
                // 고정 너비 (80pt):
                // [NORMAL    ] File 1
                // [IMPACT    ] File 2
                // [EMERGENCY ] File 3
                // ~~~~~~~~~~~~ ← 모두 같은 위치에서 시작
                //
                // 가변 너비:
                // [NORMAL] File 1
                // [IMPACT] File 2
                // [EMERGENCY] File 3
                // ~~~~~~~~~~~ ← 시작 위치가 다름
                // ```
                //
                .frame(width: 80)

            // MARK: File Information

            // File information
            //
            // 파일의 상세 정보를 표시하는 섹션입니다.
            //
            // **VStack - 상하 레이아웃:**
            //
            // VStack은 자식 View들을 세로(vertical) 방향으로 배치합니다.
            //
            // 구조:
            // ```
            // ┌─────────────────────────┐
            // │ 2024_03_15_14_23_45.mp4 │ ← 파일명
            // ├─────────────────────────┤
            // │ March 15, 2024 at 2:23  │ ← 타임스탬프
            // ├─────────────────────────┤
            // │ 🕐 2:34 │ 📄 1.2GB │... │ ← 메타데이터
            // └─────────────────────────┘
            // ```
            //
            // **alignment: .leading**
            //   - 모든 항목을 왼쪽 정렬
            //   - 텍스트가 자연스럽게 읽힘
            //
            // **spacing: 4**
            //   - 각 항목 사이 4pt 간격
            //   - 촘촘하지만 구분 가능
            //
            VStack(alignment: .leading, spacing: 4) {
                // MARK: Filename

                // Filename
                //
                // 파일의 기본 이름을 표시합니다.
                //
                // videoFile.baseFilename:
                //   - 예: "2024_03_15_14_23_45_F.mp4"
                //   - 전체 경로가 아닌 파일명만
                //
                Text(videoFile.baseFilename)
                    // **.font(.system(.body, design: .monospaced)):**
                    //
                    // 시스템 폰트를 사용하되, 몇 가지 설정을 추가합니다.
                    //
                    // **.body:**
                    //   - 본문 텍스트 크기 (일반적으로 17pt)
                    //   - 가장 흔히 사용되는 크기
                    //
                    // **design: .monospaced:**
                    //   - 고정폭 폰트 (Monospaced)
                    //   - 모든 문자가 같은 너비
                    //   - 파일명은 종종 코드처럼 보여야 함
                    //
                    // **왜 파일명에 Monospaced 폰트를 사용하는가?**
                    //
                    // 파일명은 특정 형식을 따릅니다:
                    // ```
                    // YYYY_MM_DD_HH_MM_SS_Position.mp4
                    // 2024_03_15_14_23_45_F.mp4
                    // 2024_03_15_14_23_45_R.mp4
                    // ~~~~ ~~ ~~ ~~ ~~ ~~ ~
                    // 고정폭 폰트로 정렬이 깔끔하게 맞음
                    // ```
                    //
                    .font(.system(.body, design: .monospaced))

                    // **.fontWeight(.medium):**
                    //
                    // 폰트 두께를 medium으로 설정합니다.
                    //
                    // 두께 옵션:
                    //   - .ultraLight (가장 얇음)
                    //   - .thin
                    //   - .light
                    //   - .regular (기본)
                    //   - .medium ← 현재 사용
                    //   - .semibold
                    //   - .bold
                    //   - .heavy
                    //   - .black (가장 두꺼움)
                    //
                    // Medium을 사용하는 이유:
                    //   - Regular보다 약간 강조
                    //   - Bold만큼 무겁지 않음
                    //   - 파일명이 primary 정보이므로 적절히 돋보이게
                    //
                    .fontWeight(.medium)

                    // **.lineLimit(1):**
                    //
                    // 텍스트를 최대 1줄로 제한합니다.
                    //
                    // 긴 파일명 처리:
                    // ```
                    // 제한 없이:
                    // very_very_very_long_filename_that_
                    // wraps_to_multiple_lines.mp4
                    //
                    // lineLimit(1):
                    // very_very_very_long_filenam...
                    // ```
                    //
                    // 1줄로 제한하는 이유:
                    //   - 리스트의 행 높이를 일정하게 유지
                    //   - 레이아웃 깨짐 방지
                    //   - 더 많은 항목을 화면에 표시
                    //
                    .lineLimit(1)

                // MARK: Timestamp

                // Timestamp
                //
                // 파일이 생성된 날짜와 시간을 표시합니다.
                //
                // videoFile.timestampString:
                //   - 예: "March 15, 2024 at 2:23 PM"
                //   - DateFormatter를 통해 포맷팅된 문자열
                //
                Text(videoFile.timestampString)
                    // **.font(.caption):**
                    //
                    // Caption은 보조 정보를 위한 작은 텍스트 스타일입니다.
                    //
                    // 텍스트 스타일 계층:
                    // ```
                    // .largeTitle  (가장 크고 중요)
                    // .title
                    // .title2
                    // .title3
                    // .headline
                    // .body        (일반 텍스트)
                    // .callout
                    // .subheadline
                    // .footnote
                    // .caption     (가장 작고 부차적) ← 현재 사용
                    // .caption2
                    // ```
                    //
                    // Caption을 사용하는 이유:
                    //   - 타임스탬프는 부차적 정보
                    //   - 파일명보다 덜 중요
                    //   - 시각적 계층 구조 표현
                    //
                    .font(.caption)

                    // **.foregroundColor(.secondary):**
                    //
                    // 텍스트 색상을 보조 색상(secondary)으로 설정합니다.
                    //
                    // **시스템 색상(Semantic Colors):**
                    //
                    // SwiftUI는 의미론적 색상을 제공합니다:
                    //
                    // .primary:
                    //   - 주요 텍스트
                    //   - 라이트 모드: 검은색
                    //   - 다크 모드: 흰색
                    //
                    // .secondary: ← 현재 사용
                    //   - 부차적 텍스트
                    //   - 라이트 모드: 회색
                    //   - 다크 모드: 밝은 회색
                    //
                    // .tertiary:
                    //   - 3차 텍스트
                    //   - 더 연한 회색
                    //
                    // **시스템 색상의 장점:**
                    //
                    // ✓ 자동 다크 모드 지원
                    //   → 개발자가 따로 처리할 필요 없음
                    //
                    // ✓ 접근성 (Accessibility)
                    //   → 시스템이 대비(contrast)를 자동 조정
                    //
                    // ✓ 일관성 (Consistency)
                    //   → macOS 전체 앱에서 동일한 느낌
                    //
                    .foregroundColor(.secondary)

                // MARK: Metadata Info

                // Metadata info
                //
                // 파일의 메타데이터를 아이콘과 함께 표시합니다.
                //
                // HStack으로 좌우 배치:
                // [🕐 2:34] [📄 1.2GB] [🎥 2 channels] [📍] [⚠️] [⭐]
                //
                HStack(spacing: 12) {
                    // MARK: Duration

                    // Duration
                    //
                    // 비디오의 재생 시간을 표시합니다.
                    //
                    // **Label 컴포넌트:**
                    //
                    // Label은 아이콘과 텍스트를 결합한 SwiftUI 컴포넌트입니다.
                    //
                    // 기본 구조:
                    // ```swift
                    // Label("Text", systemImage: "icon.name")
                    // //    ~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~
                    // //    텍스트   SF Symbols 아이콘 이름
                    // ```
                    //
                    // 렌더링 결과:
                    // ```
                    // 🕐 2:34
                    // ~~ ~~~~~
                    // 아이콘 텍스트
                    // ```
                    //
                    // **Label의 장점:**
                    //
                    // ✓ 자동 정렬
                    //   → 아이콘과 텍스트가 자동으로 중앙 정렬
                    //
                    // ✓ 스타일 일관성
                    //   → 시스템 표준 스타일 적용
                    //
                    // ✓ 접근성
                    //   → VoiceOver가 자동으로 처리
                    //
                    // videoFile.durationString:
                    //   - 예: "2:34" (2분 34초)
                    //   - 또는 "1:23:45" (1시간 23분 45초)
                    //
                    // systemImage: "clock":
                    //   - SF Symbols의 시계 아이콘
                    //   - 재생 시간을 직관적으로 표현
                    //
                    Label(videoFile.durationString, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // MARK: File Size

                    // File size
                    //
                    // 파일의 크기를 표시합니다.
                    //
                    // videoFile.totalFileSizeString:
                    //   - 예: "1.2 GB", "567 MB"
                    //   - ByteCountFormatter를 통해 포맷팅
                    //   - 사람이 읽기 쉬운 형식
                    //
                    // systemImage: "doc":
                    //   - 문서/파일 아이콘
                    //   - 파일 크기를 나타냄
                    //
                    Label(videoFile.totalFileSizeString, systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // MARK: Channel Count

                    // Channel count
                    //
                    // 비디오 채널(카메라) 수를 표시합니다.
                    //
                    // "\(videoFile.channelCount) channels":
                    //   - String interpolation (\(...))
                    //   - 예: "2 channels", "5 channels"
                    //
                    // **다중 카메라 시스템:**
                    //
                    // 블랙박스는 여러 카메라를 동시에 사용합니다:
                    //   - 1채널: 전방만
                    //   - 2채널: 전방 + 후방
                    //   - 4채널: 전방 + 후방 + 좌측 + 우측
                    //   - 5채널: 4채널 + 실내
                    //
                    // systemImage: "video":
                    //   - 비디오 카메라 아이콘
                    //   - 채널/카메라 수를 나타냄
                    //
                    Label("\(videoFile.channelCount) channels", systemImage: "video")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // MARK: Status Indicators

                    // GPS indicator
                    //
                    // GPS 데이터가 포함된 경우에만 표시합니다.
                    //
                    // **조건부 렌더링 (Conditional Rendering):**
                    //
                    // SwiftUI에서 if문을 사용하면 조건에 따라 View를 표시하거나 숨길 수 있습니다.
                    //
                    // ```swift
                    // if condition {
                    //     SomeView()  // 조건이 true일 때만 렌더링
                    // }
                    // ```
                    //
                    // **작동 원리:**
                    //
                    // videoFile.hasGPSData가 true일 때:
                    // ```
                    // 🕐 2:34 │ 📄 1.2GB │ 🎥 2 channels │ 📍
                    // //                                    ~~
                    // //                                    GPS 아이콘 표시
                    // ```
                    //
                    // videoFile.hasGPSData가 false일 때:
                    // ```
                    // 🕐 2:34 │ 📄 1.2GB │ 🎥 2 channels
                    // //                                    GPS 아이콘 없음
                    // ```
                    //
                    // **왜 조건부로 표시하는가?**
                    //
                    // ✓ 정보의 간결성
                    //   → GPS 데이터가 없는데 아이콘을 표시하면 혼란
                    //
                    // ✓ 시각적 명확성
                    //   → 아이콘이 있으면 "GPS 있음"을 의미
                    //   → 아이콘이 없으면 "GPS 없음"을 의미
                    //
                    // ✓ 공간 효율
                    //   → 필요한 아이콘만 표시
                    //
                    if videoFile.hasGPSData {
                        // **SF Symbols - location.fill:**
                        //
                        // "location.fill"은 채워진 위치 핀 아이콘입니다.
                        //
                        // SF Symbols 네이밍 규칙:
                        //   - 기본 이름: location (윤곽선만)
                        //   - .fill: location.fill (채워진 형태)
                        //   - .circle: location.circle (원 안에)
                        //   - .slash: location.slash (슬래시 추가)
                        //
                        // 왜 .fill을 사용하는가?
                        //   - 더 눈에 잘 띔
                        //   - 작은 크기(.caption)에서도 명확
                        //   - "활성" 상태를 나타냄
                        //
                        Image(systemName: "location.fill")
                            .font(.caption)
                            // 파란색: GPS/위치를 연상시킴 (구글맵, 애플맵 등)
                            .foregroundColor(.blue)
                    }

                    // Impact indicator
                    //
                    // 충격 이벤트가 포함된 경우에만 표시합니다.
                    //
                    // videoFile.hasImpactEvents:
                    //   - VideoMetadata에서 가속도 데이터 분석
                    //   - 2.5G 이상의 충격이 있으면 true
                    //
                    if videoFile.hasImpactEvents {
                        // **SF Symbols - exclamationmark.triangle.fill:**
                        //
                        // 경고 삼각형 아이콘입니다.
                        //
                        // 표준 경고 심볼:
                        //   - 도로 표지판 (⚠️)
                        //   - 소프트웨어 경고 메시지
                        //   - 위험 경고
                        //
                        // 왜 이 아이콘을 사용하는가?
                        //   - 보편적으로 인식됨
                        //   - 주의가 필요함을 직관적으로 전달
                        //   - 충격/위험을 나타냄
                        //
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            // 주황색: 경고/주의를 나타냄 (노란색과 빨간색의 중간)
                            .foregroundColor(.orange)
                    }

                    // Favorite indicator
                    //
                    // 즐겨찾기로 표시된 경우에만 표시합니다.
                    //
                    // videoFile.isFavorite:
                    //   - 사용자가 수동으로 즐겨찾기 표시
                    //   - 중요한 영상을 빠르게 찾기 위해
                    //
                    if videoFile.isFavorite {
                        // **SF Symbols - star.fill:**
                        //
                        // 채워진 별 아이콘입니다.
                        //
                        // 별 아이콘의 보편적 의미:
                        //   - 즐겨찾기 (Favorites)
                        //   - 북마크 (Bookmarks)
                        //   - 중요 항목 (Important)
                        //   - 평가/등급 (Rating)
                        //
                        // 대부분의 앱에서 사용:
                        //   - Safari: 북마크
                        //   - Mail: VIP 메일
                        //   - Files: 즐겨찾기 폴더
                        //
                        Image(systemName: "star.fill")
                            .font(.caption)
                            // 노란색: 금별/트로피를 연상 (긍정적, 가치 있음)
                            .foregroundColor(.yellow)
                    }

                    // Corrupted indicator
                    //
                    // 파일이 손상된 경우에만 표시합니다.
                    //
                    // videoFile.isCorrupted:
                    //   - 파일 읽기 실패
                    //   - 메타데이터 누락
                    //   - 비정상적인 파일 구조
                    //
                    if videoFile.isCorrupted {
                        // **SF Symbols - xmark.circle.fill:**
                        //
                        // 채워진 원 안에 X 표시 아이콘입니다.
                        //
                        // X 마크의 의미:
                        //   - 오류 (Error)
                        //   - 실패 (Failure)
                        //   - 불가능 (Unavailable)
                        //   - 손상됨 (Corrupted)
                        //
                        // .circle.fill을 사용하는 이유:
                        //   - 단순 X보다 눈에 잘 띔
                        //   - 원형 배경이 아이콘을 강조
                        //   - "정지" 또는 "금지" 느낌
                        //
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            // 빨간색: 오류/위험을 나타냄 (보편적 경고 색상)
                            .foregroundColor(.red)
                    }
                }
            }

            // MARK: Spacer

            // Spacer pushes playback button to the right
            //
            // Spacer는 가능한 모든 공간을 차지하여 요소들을 양 끝으로 밀어냅니다.
            //
            // HStack에서 Spacer의 역할:
            // ```
            // [배지] [파일정보] [====== Spacer ======] [재생버튼]
            // ```
            //
            // Spacer 없이:
            // ```
            // [배지] [파일정보] [재생버튼]
            // //                ~~~~~~~~~~ 파일정보 바로 옆에 붙음
            // ```
            //
            // Spacer 있으면:
            // ```
            // [배지] [파일정보]                      [재생버튼]
            // //                                      ~~~~~~~~~~ 오른쪽 끝으로
            // ```
            //
            Spacer()

            // MARK: Playback Button

            // Playback button
            //
            // 파일이 재생 가능한 경우에만 재생 버튼을 표시합니다.
            //
            // **조건부 버튼 표시:**
            //
            // videoFile.isPlayable:
            //   - 파일이 손상되지 않음
            //   - 모든 필수 데이터가 있음
            //   - 지원되는 코덱
            //
            // 재생 불가능한 경우 버튼을 숨기는 이유:
            //   - 클릭해도 아무 일도 안 일어나면 혼란
            //   - 명확한 사용자 피드백
            //   - 불필요한 UI 요소 제거
            //
            if videoFile.isPlayable {
                Button(action: {
                    // TODO: Play video
                    //
                    // 실제 구현에서는:
                    //   1. 비디오 플레이어 뷰 열기
                    //   2. VideoPlayerViewModel에 파일 로드
                    //   3. 재생 시작
                    //
                    // 예시:
                    // ```swift
                    // playerViewModel.load(videoFile)
                    // showPlayer = true
                    // ```
                }) {
                    // **SF Symbols - play.circle.fill:**
                    //
                    // 채워진 원 안에 재생 아이콘입니다.
                    //
                    // 재생 아이콘의 표준:
                    //   - 삼각형 (▶️)
                    //   - 오른쪽을 가리킴
                    //   - 보편적으로 인식됨
                    //
                    // .circle.fill을 사용하는 이유:
                    //   - 버튼임을 명확히 표현
                    //   - 클릭 가능한 영역이 넓어 보임
                    //   - 시각적으로 더 돋보임
                    //
                    Image(systemName: "play.circle.fill")
                        // **.font(.title2):**
                        //
                        // 아이콘 크기를 title2로 설정합니다.
                        //
                        // 크기 비교:
                        //   - .caption (작음)
                        //   - .body (중간)
                        //   - .title3 (크게)
                        //   - .title2 (더 크게) ← 현재 사용
                        //   - .title (가장 크게)
                        //
                        // title2를 사용하는 이유:
                        //   - 버튼은 쉽게 클릭할 수 있어야 함
                        //   - 주요 액션이므로 눈에 띄어야 함
                        //   - 너무 크면 레이아웃 차지
                        //
                        .font(.title2)

                        // **.foregroundColor(.accentColor):**
                        //
                        // 앱의 강조 색상(accent color)을 사용합니다.
                        //
                        // **Accent Color란?**
                        //
                        // 앱 전체에서 일관되게 사용되는 브랜드 색상입니다:
                        //   - Assets.xcassets에서 정의
                        //   - 버튼, 링크, 선택 항목 등에 사용
                        //   - 사용자가 상호작용 가능한 요소를 표시
                        //
                        // 예시:
                        //   - iOS: 파란색 (기본)
                        //   - 사용자 정의: 회사 브랜드 색상
                        //
                        // 장점:
                        //   ✓ 일관성 - 앱 전체에서 같은 색상
                        //   ✓ 변경 용이 - 한 곳만 수정하면 전체 앱 색상 변경
                        //   ✓ 브랜딩 - 앱의 정체성 표현
                        //
                        .foregroundColor(.accentColor)
                }
                // **.buttonStyle(.plain):**
                //
                // 버튼의 기본 스타일을 제거합니다.
                //
                // macOS 버튼 스타일:
                //   - 기본: 파란색 배경, 둥근 모서리
                //   - .plain: 배경 없음, 콘텐츠만 표시
                //
                // Plain을 사용하는 이유:
                //   - 이미 play.circle.fill 아이콘이 버튼처럼 보임
                //   - 추가 배경이 불필요
                //   - 깔끔한 디자인
                //
                .buttonStyle(.plain)
            }
        }
        // **.padding(.vertical, 8):**
        //
        // 상하(vertical) 여백을 8pt 추가합니다.
        //
        // 여백:
        // ```
        // ┌───────────────────────┐
        // │    ← 8pt padding      │
        // │ [Row Content]         │
        // │    ← 8pt padding      │
        // └───────────────────────┘
        // ```
        //
        .padding(.vertical, 8)
        // **.padding(.horizontal, 12):**
        //
        // 좌우(horizontal) 여백을 12pt 추가합니다.
        //
        // 여백:
        // ```
        // ┌────────────────────────┐
        // │ 12pt  [Row Content] 12pt│
        // └────────────────────────┘
        // ```
        //
        .padding(.horizontal, 12)

        // MARK: Selection Style

        // **.background(...):**
        //
        // 행의 배경을 설정합니다.
        //
        // **선택 상태에 따른 배경:**
        //
        .background(
            RoundedRectangle(cornerRadius: 8)
                // **삼항 연산자 (Ternary Operator):**
                //
                // ```swift
                // condition ? valueIfTrue : valueIfFalse
                // ```
                //
                // isSelected ? Color.accentColor.opacity(0.1) : Color.clear
                // ~~~~~~~~~~   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   ~~~~~~~~~~~
                // 조건         선택됨 (강조 색상 10% 투명도)    선택 안 됨 (투명)
                //
                // **opacity(0.1)이란?**
                //
                // 색상의 투명도를 설정합니다:
                //   - 0.0 = 완전 투명 (보이지 않음)
                //   - 0.1 = 90% 투명 (거의 보이지 않음) ← 현재 사용
                //   - 0.5 = 50% 투명 (반투명)
                //   - 1.0 = 불투명 (완전히 보임)
                //
                // 왜 0.1처럼 낮은 투명도를 사용하는가?
                //   - 너무 강한 배경은 텍스트 가독성 저하
                //   - 미묘한 하이라이트로 선택 상태 표시
                //   - 깔끔하고 세련된 디자인
                //
                // 선택 상태 비교:
                // ```
                // 선택 안 됨:
                // ┌─────────────────────────────┐
                // │ [Row Content]               │ ← 투명 배경
                // └─────────────────────────────┘
                //
                // 선택됨:
                // ┌─────────────────────────────┐
                // │ [Row Content]               │ ← 연한 파란색 배경
                // └─────────────────────────────┘
                // ```
                //
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )

        // **.overlay(...):**
        //
        // 행의 위에 테두리를 오버레이합니다.
        //
        // **배경 vs 오버레이:**
        //
        // .background:
        //   - View 뒤에 렌더링
        //   - 콘텐츠 아래 레이어
        //
        // .overlay:
        //   - View 앞에 렌더링
        //   - 콘텐츠 위 레이어
        //
        // 레이어 순서:
        // ```
        // Overlay (테두리) ← 가장 앞
        //     ↓
        // Content (텍스트, 아이콘 등)
        //     ↓
        // Background (배경 색상) ← 가장 뒤
        // ```
        //
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                // **.stroke(...):**
                //
                // 도형의 윤곽선만 그립니다 (채우기 없음).
                //
                // .fill vs .stroke:
                // ```
                // .fill (채우기):
                // ┌──────┐
                // │██████│ ← 내부를 색상으로 채움
                // └──────┘
                //
                // .stroke (윤곽선):
                // ┌──────┐
                // │      │ ← 테두리만 그림
                // └──────┘
                // ```
                //
                // **선택 상태에 따른 테두리:**
                //
                // isSelected ? Color.accentColor : Color.clear
                // ~~~~~~~~~~   ~~~~~~~~~~~~~~~~~~   ~~~~~~~~~~~
                // 조건         선택됨 (강조 색상)    선택 안 됨 (투명)
                //
                // lineWidth: 2
                //   - 테두리 두께를 2pt로 설정
                //   - 너무 얇으면 안 보임
                //   - 너무 두꺼우면 시끄러움
                //
                // **배경 + 테두리의 조합 효과:**
                //
                // 선택된 행:
                // ```
                // ┌─────────────────────────────┐ ← 파란 테두리 (2pt)
                // │                             │
                // │ [Row Content]               │ ← 연한 파란 배경 (10%)
                // │                             │
                // └─────────────────────────────┘
                // ```
                //
                // 두 가지를 모두 사용하는 이유:
                //   ✓ 배경만: 너무 미묘해서 놓칠 수 있음
                //   ✓ 테두리만: 배경과 대비가 약할 수 있음
                //   ✓ 배경 + 테두리: 명확하고 시각적으로 강조됨
                //
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Event Badge

/// @struct EventBadge
/// @brief 이벤트 타입 색상 배지 컴포넌트
///
/// @details
/// 이벤트 타입을 색상 배지로 표시하는 컴포넌트입니다.
///
/// **사용 예시:**
/// ```swift
/// EventBadge(eventType: .impact)  // 빨간색 "IMPACT" 배지
/// EventBadge(eventType: .normal)  // 녹색 "NORMAL" 배지
/// ```
///
/// **연관 타입:**
/// - `EventType`: 이벤트 타입 enum
///
struct EventBadge: View {
    // MARK: - Properties

    /// Event type
    ///
    /// 표시할 이벤트 타입입니다.
    ///
    /// **EventType enum:**
    /// ```swift
    /// enum EventType {
    ///     case normal     // 일반 녹화 - Green
    ///     case impact     // 충격 이벤트 - Red
    ///     case parking    // 주차 모드 - Blue
    ///     case manual     // 수동 녹화 - Orange
    ///     case emergency  // 비상 녹화 - Purple
    ///     case unknown    // 알 수 없음 - Gray
    ///
    ///     var displayName: String { ... }
    ///     var colorHex: String { ... }
    /// }
    /// ```
    ///
    let eventType: EventType

    // MARK: - Body

    var body: some View {
        // **배지 텍스트:**
        //
        // eventType.displayName.uppercased()
        //   - displayName: 이벤트 타입의 표시 이름 ("Impact", "Normal" 등)
        //   - uppercased(): 모두 대문자로 변환 ("IMPACT", "NORMAL")
        //
        // **왜 대문자를 사용하는가?**
        //
        // ✓ 시각적 강조
        //   → 대문자는 더 강하고 명확하게 보임
        //
        // ✓ 표준 배지 스타일
        //   → 상태 배지는 일반적으로 대문자 사용
        //   → GitHub, Slack 등의 UI 패턴
        //
        // ✓ 일관성
        //   → 모든 배지가 같은 스타일
        //
        // 예시:
        // ```
        // 소문자: impact  ← 덜 눈에 띔
        // 대문자: IMPACT  ← 더 강조됨
        // ```
        //
        Text(eventType.displayName.uppercased())
            // **.font(.caption):**
            //
            // 작은 텍스트 크기를 사용합니다.
            //
            // 배지는 부차적 정보이므로:
            //   - 너무 크면 주객전도
            //   - 적당히 작아야 배지처럼 보임
            //
            .font(.caption)

            // **.fontWeight(.bold):**
            //
            // 폰트를 굵게 표시합니다.
            //
            // Bold를 사용하는 이유:
            //   - 작은 크기(.caption)에서도 선명하게 보임
            //   - 배지의 중요성을 강조
            //   - 색상 배경과의 대비 향상
            //
            .fontWeight(.bold)

            // **.foregroundColor(.white):**
            //
            // 텍스트를 흰색으로 표시합니다.
            //
            // 흰색을 사용하는 이유:
            //   - 색상 배경 위에서 가독성 최고
            //   - 모든 배경 색상과 잘 어울림 (녹색, 빨간색, 파란색 등)
            //   - 접근성 (Accessibility) - 충분한 대비
            //
            // 색상 대비 예시:
            // ```
            // 빨간 배경 + 흰 텍스트:   IMPACT  ✓ 잘 보임
            // 빨간 배경 + 검은 텍스트: IMPACT  ✗ 안 보임
            // ```
            //
            .foregroundColor(.white)

            // **.padding(.horizontal, 8):**
            //
            // 텍스트 좌우에 8pt 여백을 추가합니다.
            //
            // 여백:
            // ```
            // ┌──────────────┐
            // │ 8pt│IMPACT│8pt│
            // └──────────────┘
            // ```
            //
            // 여백이 필요한 이유:
            //   - 텍스트가 배경 가장자리에 붙어있으면 답답해 보임
            //   - 클릭 가능한 영역 확대
            //   - 시각적 균형
            //
            .padding(.horizontal, 8)

            // **.padding(.vertical, 4):**
            //
            // 텍스트 상하에 4pt 여백을 추가합니다.
            //
            // 여백:
            // ```
            // ┌──────────┐
            // │   4pt    │
            // │ IMPACT   │
            // │   4pt    │
            // └──────────┘
            // ```
            //
            // 상하 여백이 좌우보다 작은 이유:
            //   - 좌우: 8pt (더 넓게)
            //   - 상하: 4pt (더 좁게)
            //   - 결과: 가로로 긴 배지 형태 (전형적인 배지 모양)
            //
            .padding(.vertical, 4)

            // **.background(...):**
            //
            // 배지의 배경을 설정합니다.
            //
            .background(
                RoundedRectangle(cornerRadius: 4)
                    // **.fill(Color(hex: eventType.colorHex)):**
                    //
                    // 이벤트 타입에 따른 색상으로 배경을 채웁니다.
                    //
                    // **Color(hex:) 커스텀 이니셜라이저:**
                    //
                    // Swift의 Color는 기본적으로 hex 색상을 지원하지 않습니다.
                    // 이 프로젝트에서는 커스텀 익스텐션을 추가한 것으로 보입니다:
                    //
                    // ```swift
                    // extension Color {
                    //     init(hex: String) {
                    //         // "#FF0000" → Red
                    //         // "#00FF00" → Green
                    //         // ...
                    //     }
                    // }
                    // ```
                    //
                    // **eventType.colorHex:**
                    //
                    // 각 이벤트 타입은 고유한 hex 색상 코드를 가집니다:
                    //
                    // ```
                    // .normal     → "#4CAF50" (녹색)
                    // .impact     → "#F44336" (빨간색)
                    // .parking    → "#2196F3" (파란색)
                    // .manual     → "#FF9800" (주황색)
                    // .emergency  → "#9C27B0" (보라색)
                    // .unknown    → "#9E9E9E" (회색)
                    // ```
                    //
                    // **Material Design 색상:**
                    //
                    // 이 색상들은 Google의 Material Design 팔레트에서 가져온 것으로 보입니다:
                    //   ✓ 시각적으로 균형잡힘
                    //   ✓ 접근성 고려 (충분한 대비)
                    //   ✓ 현대적인 디자인
                    //
                    // **cornerRadius: 4:**
                    //
                    // 모서리를 4pt 둥글게 만듭니다.
                    //
                    // 둥근 모서리 효과:
                    // ```
                    // cornerRadius: 0 (각진 모서리):
                    // ┌──────────┐
                    // │ IMPACT   │
                    // └──────────┘
                    //
                    // cornerRadius: 4 (약간 둥근):
                    // ╭──────────╮
                    // │ IMPACT   │
                    // ╰──────────╯
                    //
                    // cornerRadius: 20 (매우 둥근, 캡슐 형태):
                    // ╭─────────╮
                    // │ IMPACT  │
                    // ╰─────────╯
                    // ```
                    //
                    // 4pt를 사용하는 이유:
                    //   - 너무 각지지 않음 (부드러운 느낌)
                    //   - 너무 둥글지 않음 (버블 느낌 방지)
                    //   - 전형적인 배지/태그 스타일
                    //
                    .fill(Color(hex: eventType.colorHex))
            )
    }
}

// MARK: - Preview

/// SwiftUI Preview
///
/// Xcode의 Canvas에서 FileRow를 미리 볼 수 있게 해주는 프리뷰입니다.
///
/// **이 Preview의 구성:**
///
/// 5가지 다른 VideoFile 샘플을 표시하여 다양한 상태를 확인합니다:
///
/// 1. **normal5Channel**: 일반 녹화, 5채널
///    - 선택 안 됨
///    - 녹색 "NORMAL" 배지
///
/// 2. **impact2Channel**: 충격 이벤트, 2채널
///    - 선택됨 (파란 배경 + 테두리)
///    - 빨간색 "IMPACT" 배지
///    - 충격 인디케이터 표시
///
/// 3. **parking1Channel**: 주차 모드, 1채널
///    - 선택 안 됨
///    - 파란색 "PARKING" 배지
///
/// 4. **favoriteRecording**: 즐겨찾기 표시
///    - 선택 안 됨
///    - 노란 별 인디케이터 표시
///
/// 5. **corruptedFile**: 손상된 파일
///    - 선택 안 됨
///    - 빨간 X 인디케이터 표시
///    - 재생 버튼 없음 (재생 불가)
///
/// **VStack(spacing: 8):**
///
/// 각 행을 8pt 간격으로 세로 배치합니다:
/// ```
/// ┌─────────────────┐
/// │ Row 1           │
/// ├─────────────────┤ ← 8pt 간격
/// │ Row 2 (선택됨)  │
/// ├─────────────────┤ ← 8pt 간격
/// │ Row 3           │
/// └─────────────────┘
/// ```
///
/// **.previewLayout(.sizeThatFits):**
///
/// 프리뷰를 콘텐츠 크기에 맞게 조정합니다.
///
/// 레이아웃 옵션:
///   - .device: 실제 기기 크기 (iPhone, iPad 등)
///   - .fixed(width:height:): 고정 크기
///   - .sizeThatFits: 콘텐츠에 맞게 자동 조정 ← 현재 사용
///
/// sizeThatFits를 사용하는 이유:
///   - 불필요한 빈 공간 제거
///   - 컴포넌트에 집중
///   - 빠른 미리보기 로딩
///
struct FileRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            FileRow(videoFile: .normal5Channel, isSelected: false)
            FileRow(videoFile: .impact2Channel, isSelected: true)
            FileRow(videoFile: .parking1Channel, isSelected: false)
            FileRow(videoFile: .favoriteRecording, isSelected: false)
            FileRow(videoFile: .corruptedFile, isSelected: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
