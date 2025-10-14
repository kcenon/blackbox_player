/// @file FileListView.swift
/// @brief 블랙박스 비디오 파일 목록 표시 및 관리 View
/// @author BlackboxPlayer Development Team
/// @details
/// 블랙박스 비디오 파일 목록을 표시하고 검색/필터링/선택 기능을 제공하는 메인 리스트 View입니다.
///
/// ## 주요 기능
/// - **검색**: 파일명, 타임스탬프로 실시간 검색 (대소문자 무시)
/// - **이벤트 필터**: Normal, Parking, Event 등 이벤트 타입별 필터링
/// - **정렬**: 최신순 (timestamp 내림차순) 자동 정렬
/// - **선택**: 파일 선택 시 부모 View에 양방향 바인딩으로 전달
/// - **상태 표시**: "X of Y videos" 카운터로 필터 결과 요약
///
/// ## 레이아웃 구조
/// ```
/// ┌──────────────────────────────────┐
/// │  🔍 [Search videos...]      [X]  │ ← 검색바 (searchText)
/// ├──────────────────────────────────┤
/// │  [All] [Normal] [Parking] [Event]│ ← 필터 버튼 (가로 스크롤)
/// ├──────────────────────────────────┤
/// │  ┌────────────────────────────┐  │
/// │  │ 📹 파일1  2024-01-15 14:30 │  │ ← FileRow (선택 가능)
/// │  ├────────────────────────────┤  │
/// │  │ 📹 파일2  2024-01-15 13:15 │  │
/// │  ├────────────────────────────┤  │
/// │  │ 📹 파일3  2024-01-15 12:00 │  │
/// │  └────────────────────────────┘  │
/// ├──────────────────────────────────┤
/// │  3 of 100 videos                 │ ← 상태바
/// └──────────────────────────────────┘
/// ```
///
/// ## SwiftUI 핵심 개념
/// ### 1. @Binding으로 부모 View와 데이터 동기화
/// @Binding은 부모 View의 @State를 참조하여 양방향으로 데이터를 동기화합니다.
///
/// **동작 원리:**
/// ```
/// 부모 View (ContentView)          자식 View (FileListView)
/// ┌──────────────────────┐         ┌──────────────────────┐
/// │ @State var files = []│────────>│ @Binding var files   │
/// │ @State var selected  │<────────│ @Binding var selected│
/// └──────────────────────┘         └──────────────────────┘
///         ↓                                    ↓
///    원본 데이터 소유                      참조만 보유
///    (Source of Truth)                   (읽기/쓰기 가능)
/// ```
///
/// **사용 예시:**
/// ```swift
/// // 부모 View
/// struct ParentView: View {
///     @State private var files: [VideoFile] = []
///     @State private var selected: VideoFile?
///
///     var body: some View {
///         FileListView(videoFiles: $files,     // $ 붙여서 Binding 전달
///                      selectedFile: $selected)
///     }
/// }
///
/// // 자식 View
/// struct FileListView: View {
///     @Binding var videoFiles: [VideoFile]    // 부모의 files 참조
///     @Binding var selectedFile: VideoFile?   // 부모의 selected 참조
///
///     var body: some View {
///         // selectedFile을 변경하면 부모의 selected도 자동 변경됨
///         List(videoFiles, selection: $selectedFile) { ... }
///     }
/// }
/// ```
///
/// ### 2. Computed Property로 실시간 필터링
/// Computed Property는 의존하는 @State 값이 변경될 때마다 자동으로 재계산됩니다.
///
/// **filteredFiles의 재계산 시점:**
/// ```
/// searchText 변경 ──┐
///                   ├──> filteredFiles 재계산 ──> body 재렌더링
/// selectedEventType ┘
/// ```
///
/// **계산 흐름:**
/// ```swift
/// // 1. searchText = "2024"
/// videoFiles: [파일1, 파일2, 파일3, 파일4] (100개)
///      ↓ filter { baseFilename.contains("2024") }
/// files: [파일1, 파일3, 파일4] (50개)
///
/// // 2. selectedEventType = .event
/// files: [파일1, 파일3, 파일4] (50개)
///      ↓ filter { eventType == .event }
/// files: [파일3] (5개)
///
/// // 3. sorted { timestamp > ... }
/// files: [파일3] (최신순 정렬)
///      ↓
/// return [파일3] ──> List에 표시
/// ```
///
/// ### 3. List selection 바인딩
/// List의 selection 파라미터에 @Binding을 전달하면 선택된 항목이 자동으로 동기화됩니다.
///
/// **동작 원리:**
/// ```swift
/// List(filteredFiles, selection: $selectedFile) { file in
///     FileRow(videoFile: file)
///         .tag(file)  // tag()로 선택 시 반환될 값 지정
/// }
/// ```
///
/// **선택 흐름:**
/// ```
/// 1. 사용자가 FileRow 클릭
///      ↓
/// 2. .tag(file)에 지정된 VideoFile 객체를 가져옴
///      ↓
/// 3. $selectedFile에 할당 (Binding 업데이트)
///      ↓
/// 4. 부모 View의 @State selected도 자동 업데이트
///      ↓
/// 5. 부모 View에서 선택된 파일로 영상 재생 시작
/// ```
///
/// ### 4. 조건부 View 렌더링
/// if-else로 다른 View를 렌더링하여 상태에 따라 UI를 전환합니다.
///
/// **예시:**
/// ```swift
/// if filteredFiles.isEmpty {
///     EmptyStateView()        // 검색 결과 없을 때
/// } else {
///     List(filteredFiles) { ... }  // 검색 결과 있을 때
/// }
/// ```
///
/// **전환 흐름:**
/// ```
/// searchText = "존재하지않는단어"
///      ↓
/// filteredFiles.isEmpty == true
///      ↓
/// List 사라짐 ──> EmptyStateView 표시
///      ↓
/// searchText = "" (초기화)
///      ↓
/// filteredFiles.isEmpty == false
///      ↓
/// EmptyStateView 사라짐 ──> List 표시
/// ```
///
/// ## 사용 예시
/// ```swift
/// // 1. ContentView에서 FileListView 사용
/// struct ContentView: View {
///     @State private var files: [VideoFile] = []
///     @State private var selectedFile: VideoFile?
///
///     var body: some View {
///         HSplitView {
///             // 좌측: 파일 리스트
///             FileListView(videoFiles: $files,
///                          selectedFile: $selectedFile)
///                 .frame(minWidth: 300)
///
///             // 우측: 선택된 파일 재생
///             if let file = selectedFile {
///                 VideoPlayerView(videoFile: file)
///             }
///         }
///     }
/// }
///
/// // 2. 검색 기능 사용
/// // searchText = "2024-01-15" 입력
/// //   → baseFilename에 "2024-01-15" 포함된 파일만 표시
///
/// // 3. 필터 기능 사용
/// // [Event] 버튼 클릭
/// //   → selectedEventType = .event
/// //   → eventType == .event인 파일만 표시
///
/// // 4. 파일 선택
/// // FileRow 클릭
/// //   → selectedFile = 클릭한 VideoFile 객체
/// //   → ContentView의 selectedFile도 자동 업데이트
/// //   → VideoPlayerView에서 해당 파일 재생 시작
/// ```
///
/// ## 실제 사용 시나리오
/// **시나리오 1: 특정 날짜 영상 검색**
/// ```
/// 1. 검색바에 "2024-01-15" 입력
///      ↓
/// 2. filteredFiles가 자동 재계산
///      ↓ baseFilename.contains("2024-01-15")
/// 3. 해당 날짜 파일 10개만 리스트에 표시
///      ↓
/// 4. 상태바에 "10 of 100 videos" 표시
/// ```
///
/// **시나리오 2: 이벤트 영상만 필터링**
/// ```
/// 1. [Event] 필터 버튼 클릭
///      ↓
/// 2. selectedEventType = .event 설정
///      ↓
/// 3. filteredFiles가 자동 재계산
///      ↓ eventType == .event
/// 4. 이벤트 영상 5개만 리스트에 표시
///      ↓
/// 5. 상태바에 "5 of 100 videos" 표시
/// ```
///
/// **시나리오 3: 검색 + 필터 조합**
/// ```
/// 1. 검색바에 "2024-01" 입력
///      ↓ baseFilename.contains("2024-01")
/// 2. 1월 영상 30개로 필터링
///      ↓
/// 3. [Parking] 필터 버튼 클릭
///      ↓ eventType == .parking
/// 4. 1월 + 주차 영상 3개만 표시
///      ↓
/// 5. 상태바에 "3 of 100 videos" 표시
/// ```
//
//  FileListView.swift
//  BlackboxPlayer
//
//  Main view for displaying list of dashcam video files
//

import SwiftUI

/// @struct FileListView
/// @brief 블랙박스 비디오 파일 목록 표시 및 관리 View
///
/// @details
/// 블랙박스 비디오 파일 목록을 표시하고 검색/필터링 기능을 제공하는 메인 View입니다.
/// 검색, 이벤트 타입 필터링, 정렬 기능을 지원하며 부모 View와 양방향 바인딩으로 연결됩니다.
struct FileListView: View {
    /// @var videoFiles
    /// @brief 부모 View로부터 전달받은 비디오 파일 배열 (양방향 바인딩)
    ///
    /// ## @Binding이 필요한 이유
    /// - 부모 View(ContentView)가 파일 목록의 원본 데이터를 소유
    /// - FileListView는 이 데이터를 읽고 표시만 함
    /// - 하지만 정렬이나 업데이트 시 부모에게 알려야 하므로 @Binding 사용
    ///
    /// **예시:**
    /// ```swift
    /// // ContentView (부모)
    /// @State private var files: [VideoFile] = loadFiles()
    ///
    /// // FileListView (자식)
    /// FileListView(videoFiles: $files, ...)  // $ 붙여서 Binding 전달
    /// ```
    @Binding var videoFiles: [VideoFile]

    /// @var selectedFile
    /// @brief 현재 선택된 비디오 파일 (양방향 바인딩)
    ///
    /// ## 선택 동기화 동작
    /// 1. 사용자가 List에서 파일 클릭
    ///      ↓
    /// 2. selectedFile에 해당 VideoFile 할당
    ///      ↓
    /// 3. @Binding으로 부모 View의 @State도 자동 업데이트
    ///      ↓
    /// 4. 부모 View에서 선택된 파일로 VideoPlayerView 업데이트
    ///
    /// **예시:**
    /// ```swift
    /// // 파일 선택 전
    /// selectedFile = nil
    ///
    /// // List에서 파일1 클릭
    /// selectedFile = 파일1
    ///
    /// // 부모 View도 자동 업데이트
    /// ContentView.selectedFile = 파일1  // VideoPlayerView에 반영됨
    /// ```
    @Binding var selectedFile: VideoFile?

    /// @var searchText
    /// @brief 검색창 입력 텍스트 (로컬 상태)
    ///
    /// ## @State vs @Binding 선택 기준
    /// - searchText는 FileListView 내부에서만 사용 → @State 사용
    /// - 부모 View는 검색어를 알 필요 없음
    /// - TextField와 양방향 바인딩하여 실시간 검색 가능
    ///
    /// **동작:**
    /// ```swift
    /// // 사용자가 "2024" 입력
    /// searchText = "2024"
    ///      ↓ TextField($searchText)로 양방향 바인딩
    /// TextField에 "2024" 표시됨
    ///      ↓ searchText 변경 → filteredFiles 재계산
    /// List가 자동으로 필터링된 파일로 업데이트
    /// ```
    @State private var searchText = ""

    /// @var selectedEventType
    /// @brief 선택된 이벤트 타입 필터 (로컬 상태)
    ///
    /// ## Optional 타입인 이유
    /// - nil: "All" 필터 (모든 이벤트 타입 표시)
    /// - .normal: Normal 이벤트만 표시
    /// - .parking: Parking 이벤트만 표시
    /// - .event: Event 이벤트만 표시
    ///
    /// **예시:**
    /// ```swift
    /// // 초기 상태: 모든 타입 표시
    /// selectedEventType = nil
    ///
    /// // [Event] 버튼 클릭
    /// selectedEventType = .event
    ///      ↓
    /// filteredFiles에서 eventType == .event인 파일만 필터링
    /// ```
    @State private var selectedEventType: EventType?

    /// 검색어와 이벤트 타입으로 필터링된 파일 배열 (Computed Property)
    ///
    /// ## Computed Property란?
    /// - 저장하지 않고 매번 계산하는 속성 (저장 공간 없음)
    /// - 의존하는 값(searchText, selectedEventType, videoFiles)이 변경되면 자동 재계산
    /// - SwiftUI가 자동으로 감지하여 body 재렌더링
    ///
    /// ## 필터링 알고리즘 단계
    /// ```
    /// 1. videoFiles 복사
    ///      ↓
    /// 2. searchText로 필터링 (파일명 + 타임스탬프)
    ///      ↓
    /// 3. selectedEventType으로 필터링 (이벤트 타입)
    ///      ↓
    /// 4. timestamp 내림차순 정렬 (최신순)
    ///      ↓
    /// 5. return 정렬된 배열
    /// ```
    ///
    /// ## 필터링 예시
    /// **초기 상태:**
    /// ```swift
    /// videoFiles = [파일1(normal), 파일2(event), 파일3(parking), 파일4(event)]
    /// searchText = ""
    /// selectedEventType = nil
    ///      ↓
    /// filteredFiles = [파일4, 파일3, 파일2, 파일1] (최신순 정렬)
    /// ```
    ///
    /// **검색 후:**
    /// ```swift
    /// searchText = "2024-01-15"
    ///      ↓ filter { baseFilename.contains("2024-01-15") }
    /// filteredFiles = [파일2, 파일1] (2024-01-15가 포함된 파일만)
    /// ```
    ///
    /// **필터 후:**
    /// ```swift
    /// selectedEventType = .event
    ///      ↓ filter { eventType == .event }
    /// filteredFiles = [파일2] (event 타입만)
    /// ```
    ///
    /// ## 성능 최적화
    /// - Computed Property는 접근할 때마다 계산
    /// - body에서 여러 번 접근하면 여러 번 계산됨
    /// - 하지만 SwiftUI의 View 업데이트는 효율적으로 최적화되어 있음
    /// - 필요시 @State로 캐싱 가능:
    ///   ```swift
    ///   @State private var cachedFilteredFiles: [VideoFile] = []
    ///   .onChange(of: searchText) { cachedFilteredFiles = calculateFiltered() }
    ///   ```
    private var filteredFiles: [VideoFile] {
        /// 1단계: videoFiles 배열을 복사하여 시작
        var files = videoFiles

        /// 2단계: 검색어로 필터링
        ///
        /// ## localizedCaseInsensitiveContains란?
        /// - 대소문자 구분 없이 문자열 포함 여부 확인
        /// - 로케일(언어) 설정을 고려하여 비교 (한글, 일본어 등 지원)
        ///
        /// **비교 예시:**
        /// ```swift
        /// "ABC".contains("abc")                           // false (대소문자 구분)
        /// "ABC".localizedCaseInsensitiveContains("abc")  // true  (대소문자 무시)
        ///
        /// "Hello".contains("lo")                          // true
        /// "Hello".localizedCaseInsensitiveContains("LO") // true
        /// ```
        ///
        /// ## 필터링 조건
        /// - baseFilename에 검색어 포함 OR
        /// - timestampString에 검색어 포함
        ///
        /// **예시:**
        /// ```swift
        /// searchText = "2024"
        ///
        /// 파일1: baseFilename = "2024-01-15_14-30.mp4"  → 포함 ✅
        /// 파일2: baseFilename = "video.mp4", timestampString = "2024-01-15" → 포함 ✅
        /// 파일3: baseFilename = "old_video.mp4", timestampString = "2023-12-01" → 제외 ❌
        /// ```
        if !searchText.isEmpty {
            files = files.filter { file in
                file.baseFilename.localizedCaseInsensitiveContains(searchText) ||
                    file.timestampString.localizedCaseInsensitiveContains(searchText)
            }
        }

        /// 3단계: 이벤트 타입으로 필터링
        ///
        /// ## Optional Binding으로 안전하게 처리
        /// ```swift
        /// if let eventType = selectedEventType {
        ///     // selectedEventType이 nil이 아닐 때만 실행
        ///     // eventType 변수에 unwrapped 값 할당됨
        /// }
        /// ```
        ///
        /// **예시:**
        /// ```swift
        /// selectedEventType = nil          → 이 블록 실행 안 됨 (모든 파일 유지)
        /// selectedEventType = .event       → eventType == .event인 파일만 유지
        ///
        /// 필터링 전: [파일1(normal), 파일2(event), 파일3(parking)]
        ///      ↓
        /// 필터링 후: [파일2(event)]
        /// ```
        if let eventType = selectedEventType {
            files = files.filter { $0.eventType == eventType }
        }

        /// 4단계: 타임스탬프 내림차순 정렬 (최신순)
        ///
        /// ## sorted 메서드
        /// - 클로저로 정렬 기준 지정
        /// - { $0.timestamp > $1.timestamp }: 타임스탬프가 큰 것이 앞으로
        /// - 원본 배열은 변경되지 않고 새 배열 반환
        ///
        /// **정렬 예시:**
        /// ```swift
        /// // 정렬 전
        /// files = [
        ///     VideoFile(timestamp: Date("2024-01-15 14:30")),
        ///     VideoFile(timestamp: Date("2024-01-15 12:00")),
        ///     VideoFile(timestamp: Date("2024-01-15 16:45"))
        /// ]
        ///
        /// // sorted { $0.timestamp > $1.timestamp }
        /// //     ↓
        /// // 16:45 > 14:30? → 16:45를 앞으로
        /// // 14:30 > 12:00? → 14:30을 앞으로
        ///
        /// // 정렬 후 (최신순)
        /// files = [
        ///     VideoFile(timestamp: Date("2024-01-15 16:45")),  // 1위
        ///     VideoFile(timestamp: Date("2024-01-15 14:30")),  // 2위
        ///     VideoFile(timestamp: Date("2024-01-15 12:00"))   // 3위
        /// ]
        /// ```
        ///
        /// ## 다른 정렬 예시
        /// ```swift
        /// // 오래된 순 (오름차순)
        /// files.sorted { $0.timestamp < $1.timestamp }
        ///
        /// // 파일명 알파벳 순
        /// files.sorted { $0.baseFilename < $1.baseFilename }
        ///
        /// // 파일 크기 큰 순
        /// files.sorted { $0.totalFileSize > $1.totalFileSize }
        /// ```
        return files.sorted { $0.timestamp > $1.timestamp }
    }

    /// FileListView의 메인 레이아웃
    ///
    /// ## VStack(spacing: 0) 구조
    /// spacing: 0으로 설정하여 컴포넌트 사이 기본 간격을 제거합니다.
    /// 각 컴포넌트가 자신의 padding을 직접 관리하여 더 정확한 레이아웃 제어 가능.
    ///
    /// **레이아웃 구성 요소:**
    /// ```
    /// ┌────────────────────────┐
    /// │  검색바                │ ← HStack (TextField + 버튼)
    /// ├────────────────────────┤
    /// │  필터 버튼 (가로 스크롤)│ ← ScrollView(.horizontal)
    /// ├────────────────────────┤ ← Divider()
    /// │                        │
    /// │   파일 리스트          │ ← List 또는 EmptyStateView
    /// │                        │
    /// ├────────────────────────┤ ← Divider()
    /// │  상태바                │ ← StatusBar
    /// └────────────────────────┘
    /// ```
    var body: some View {
        VStack(spacing: 0) {
            /// 검색바 (Search bar)
            ///
            /// ## HStack 레이아웃
            /// [🔍] [        Search videos...        ] [(X)]
            ///  ↑              ↑                        ↑
            /// 아이콘       TextField                 Clear 버튼
            ///
            /// ## 조건부 버튼 렌더링
            /// - searchText.isEmpty == false일 때만 Clear 버튼 표시
            /// - 버튼 클릭 시 searchText = "" 초기화
            ///
            /// **동작 흐름:**
            /// ```
            /// 1. 사용자가 "2024" 입력
            ///      ↓
            /// 2. searchText = "2024"
            ///      ↓ TextField($searchText)로 양방향 바인딩
            /// 3. TextField에 "2024" 표시됨
            ///      ↓ searchText 변경 감지
            /// 4. filteredFiles 자동 재계산
            ///      ↓
            /// 5. List 업데이트 (필터링된 파일만 표시)
            ///      ↓
            /// 6. [X] 버튼 나타남 (!searchText.isEmpty)
            ///      ↓ 버튼 클릭
            /// 7. searchText = "" 초기화
            ///      ↓
            /// 8. filteredFiles 재계산 (모든 파일 표시)
            ///      ↓
            /// 9. [X] 버튼 사라짐
            /// ```
            HStack {
                /// 검색 아이콘
                ///
                /// ## SF Symbols
                /// - "magnifyingglass": macOS/iOS 기본 제공 아이콘
                /// - .foregroundColor(.secondary): 회색 계열 색상 (시스템 테마 따름)
                ///
                /// **색상 예시:**
                /// ```swift
                /// .foregroundColor(.primary)    // 기본 텍스트 색상 (검정/흰색)
                /// .foregroundColor(.secondary)  // 보조 텍스트 색상 (회색)
                /// .foregroundColor(.blue)       // 파랑
                /// ```
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                /// 검색 입력 필드
                ///
                /// ## TextField 파라미터
                /// - "Search videos...": placeholder 텍스트 (입력 전 표시)
                /// - text: $searchText: 양방향 바인딩 ($는 Binding으로 변환)
                ///
                /// ## .textFieldStyle(.plain)
                /// - macOS 기본 TextField 스타일 제거 (테두리, 배경 제거)
                /// - 커스텀 배경(.background)과 함께 사용하여 일관된 디자인
                ///
                /// **TextField 바인딩 동작:**
                /// ```swift
                /// // 사용자가 "A" 입력
                /// TextField 내부: "A" 표시
                ///      ↓
                /// searchText = "A" 업데이트
                ///      ↓
                /// SwiftUI가 변경 감지
                ///      ↓
                /// body 재실행 → filteredFiles 재계산
                ///      ↓
                /// List 업데이트
                /// ```
                TextField("Search videos...", text: $searchText)
                    .textFieldStyle(.plain)

                /// Clear 버튼 (조건부 렌더링)
                ///
                /// ## if 조건부 View
                /// - searchText가 비어있지 않을 때만 버튼 표시
                /// - 버튼 클릭 시 searchText 초기화
                ///
                /// **조건부 렌더링 동작:**
                /// ```swift
                /// searchText = ""     → if false → 버튼 없음
                /// searchText = "abc"  → if true  → 버튼 표시
                /// 버튼 클릭           → searchText = "" → 버튼 사라짐
                /// ```
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)  // 버튼 기본 스타일 제거
                }
            }
            .padding(8)  // HStack 내부 여백
            .background(Color(nsColor: .controlBackgroundColor))  // macOS 시스템 배경색
            .cornerRadius(6)  // 모서리 둥글게
            .padding()  // HStack 외부 여백

            /// 이벤트 타입 필터 버튼 (Event type filter)
            ///
            /// ## ScrollView(.horizontal)
            /// - 가로 방향 스크롤 가능
            /// - showsIndicators: false로 스크롤바 숨김
            /// - 필터 버튼이 많아도 가로 스크롤로 모두 접근 가능
            ///
            /// ## HStack 레이아웃
            /// ```
            /// [All] [Normal] [Parking] [Event] ...
            ///   ↑      ↑        ↑        ↑
            ///  선택됨  미선택    미선택    미선택
            /// ```
            ///
            /// **스크롤 동작:**
            /// ```
            /// 화면 너비: 400px
            /// 버튼 4개 너비: 500px
            ///      ↓
            /// 가로 스크롤 자동 활성화
            ///
            /// [All] [Normal] [Parking] [Ev...] →
            ///                            스크롤 →
            /// ```
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    /// "All" 필터 버튼
                    ///
                    /// ## isSelected 조건
                    /// - selectedEventType == nil: 모든 이벤트 타입 표시
                    /// - 버튼 클릭 시 selectedEventType = nil로 초기화
                    ///
                    /// **선택 상태 변화:**
                    /// ```swift
                    /// // 초기 상태
                    /// selectedEventType = nil
                    /// isSelected = true (All 버튼 선택됨)
                    ///
                    /// // [Event] 버튼 클릭
                    /// selectedEventType = .event
                    /// isSelected = false (All 버튼 선택 해제)
                    ///
                    /// // [All] 버튼 클릭
                    /// selectedEventType = nil
                    /// isSelected = true (All 버튼 다시 선택)
                    /// ```
                    FilterButton(
                        title: "All",
                        isSelected: selectedEventType == nil,
                        action: { selectedEventType = nil }
                    )

                    /// 각 이벤트 타입별 필터 버튼
                    ///
                    /// ## ForEach로 동적 버튼 생성
                    /// - EventType.allCases: [.normal, .parking, .event, ...]
                    /// - id: \.self: 각 EventType을 고유 식별자로 사용
                    ///
                    /// ## 버튼 속성
                    /// - title: eventType.displayName (예: "Normal", "Parking")
                    /// - color: 이벤트 타입별 색상 (hex 코드에서 변환)
                    /// - isSelected: 현재 선택된 타입인지 확인
                    /// - action: 버튼 클릭 시 selectedEventType 업데이트
                    ///
                    /// **ForEach 생성 예시:**
                    /// ```swift
                    /// EventType.allCases = [.normal, .parking, .event]
                    ///
                    /// // ForEach가 생성하는 View
                    /// FilterButton(title: "Normal", color: .green, isSelected: false, ...)
                    /// FilterButton(title: "Parking", color: .blue, isSelected: false, ...)
                    /// FilterButton(title: "Event", color: .red, isSelected: false, ...)
                    /// ```
                    ///
                    /// **버튼 클릭 흐름:**
                    /// ```
                    /// 1. [Event] 버튼 클릭
                    ///      ↓
                    /// 2. action: { selectedEventType = .event } 실행
                    ///      ↓
                    /// 3. selectedEventType = .event 할당
                    ///      ↓
                    /// 4. SwiftUI가 변경 감지
                    ///      ↓
                    /// 5. body 재실행 → filteredFiles 재계산
                    ///      ↓
                    /// 6. [Event] 버튼 isSelected = true로 스타일 변경
                    ///      ↓
                    /// 7. List에 event 타입 파일만 표시
                    /// ```
                    ForEach(EventType.allCases, id: \.self) { eventType in
                        FilterButton(
                            title: eventType.displayName,
                            color: Color(hex: eventType.colorHex),
                            isSelected: selectedEventType == eventType,
                            action: { selectedEventType = eventType }
                        )
                    }
                }
                .padding(.horizontal)  // HStack 좌우 여백
            }
            .padding(.bottom, 8)  // ScrollView 하단 여백

            /// 구분선
            ///
            /// ## Divider()
            /// - 수평선으로 UI 영역 구분
            /// - 시스템 테마에 따라 자동으로 색상 조정
            Divider()

            /// 파일 리스트 또는 빈 상태 View
            ///
            /// ## 조건부 View 렌더링
            /// - filteredFiles.isEmpty: 필터링 결과 없을 때 EmptyStateView 표시
            /// - 그 외: List로 파일 목록 표시
            ///
            /// **렌더링 흐름:**
            /// ```
            /// // 초기 상태 (파일 100개)
            /// filteredFiles = [파일1, 파일2, ..., 파일100]
            /// isEmpty = false → List 렌더링
            ///
            /// // 검색어 입력: "존재하지않는파일"
            /// filteredFiles = []
            /// isEmpty = true → EmptyStateView 렌더링
            ///
            /// // 검색어 초기화
            /// filteredFiles = [파일1, 파일2, ..., 파일100]
            /// isEmpty = false → List 렌더링
            /// ```
            if filteredFiles.isEmpty {
                /// 빈 상태 View
                ///
                /// ## EmptyStateView 표시 시점
                /// - 검색 결과 없음
                /// - 필터링 결과 없음
                /// - 원본 videoFiles 배열이 비어있음
                ///
                /// **표시 내용:**
                /// - 🎥 아이콘 (video.slash)
                /// - "No Videos Found" 메시지
                /// - "Try adjusting your search or filters" 안내
                EmptyStateView()
            } else {
                /// 파일 리스트
                ///
                /// ## List(_, selection:)
                /// - filteredFiles: 표시할 데이터 배열
                /// - selection: $selectedFile: 선택된 항목을 양방향 바인딩
                ///
                /// ## selection 바인딩 동작
                /// ```
                /// 1. 사용자가 FileRow 클릭
                ///      ↓
                /// 2. .tag(file)에 지정된 VideoFile 가져옴
                ///      ↓
                /// 3. $selectedFile에 할당
                ///      ↓
                /// 4. @Binding으로 부모 View의 @State도 업데이트
                ///      ↓
                /// 5. 부모 View에서 selectedFile 감지 → VideoPlayerView 업데이트
                /// ```
                ///
                /// ## .tag() modifier
                /// - List의 각 항목에 고유 값 지정
                /// - selection에 바인딩될 때 이 값이 사용됨
                ///
                /// **tag 동작 예시:**
                /// ```swift
                /// List([파일1, 파일2, 파일3], selection: $selectedFile) { file in
                ///     Text(file.name).tag(file)
                ///     //              ↑ 클릭 시 file 객체를 selectedFile에 할당
                /// }
                ///
                /// // 파일2 클릭
                /// selectedFile = 파일2  // .tag(파일2)의 값이 할당됨
                /// ```
                ///
                /// ## .listRowInsets
                /// - List 각 행의 내부 여백 커스터마이징
                /// - EdgeInsets(top:, leading:, bottom:, trailing:)
                ///
                /// **여백 예시:**
                /// ```
                /// 기본 여백:
                /// ┌────────────────────────┐
                /// │  [     FileRow      ]  │ ← top: 8, leading: 16
                /// └────────────────────────┘
                ///
                /// 커스텀 여백 (top: 4, leading: 8, bottom: 4, trailing: 8):
                /// ┌────────────────────────┐
                /// │ [      FileRow      ]  │ ← 여백 줄어듦
                /// └────────────────────────┘
                /// ```
                ///
                /// ## .listStyle(.plain)
                /// - List 기본 스타일 제거 (배경, 구분선 등)
                /// - FileRow가 자체 스타일을 완전히 제어 가능
                List(filteredFiles, selection: $selectedFile) { file in
                    FileRow(videoFile: file, isSelected: selectedFile?.id == file.id)
                        .tag(file)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
                .listStyle(.plain)
            }

            /// 구분선
            Divider()

            /// 상태바
            ///
            /// ## StatusBar 표시 내용
            /// - fileCount: filteredFiles.count (필터링 후 파일 개수)
            /// - totalCount: videoFiles.count (전체 파일 개수)
            ///
            /// **표시 예시:**
            /// ```
            /// // 초기 상태
            /// "100 of 100 videos"
            ///
            /// // 검색 후
            /// "10 of 100 videos"
            ///
            /// // 필터 후
            /// "5 of 100 videos"
            /// ```
            StatusBar(fileCount: filteredFiles.count, totalCount: videoFiles.count)
        }
    }
}

// MARK: - Filter Button

/// @struct FilterButton
/// @brief 이벤트 타입 필터 토글 버튼 컴포넌트
///
/// @details
/// 이벤트 타입 필터를 위한 토글 버튼입니다.
/// 선택 상태에 따라 배경색과 폰트 두께가 변경됩니다.
///
/// ## 주요 기능
/// - **선택 상태 시각화**: isSelected에 따라 배경색, 폰트 두께 변경
/// - **커스텀 색상**: 이벤트 타입별로 다른 색상 지정 가능
/// - **액션 처리**: 버튼 클릭 시 콜백 함수 실행
///
/// ## 선택/비선택 스타일 차이
/// ```
/// 선택됨:                     비선택:
/// ┌───────────────┐          ┌───────────────┐
/// │ Event (Bold)  │          │ Event         │
/// │ 배경: 빨강     │          │ 배경: 회색     │
/// │ 텍스트: 흰색   │          │ 텍스트: 빨강   │
/// └───────────────┘          └───────────────┘
/// ```
///
/// ## 사용 예시
/// ```swift
/// // "All" 버튼 (색상 없음)
/// FilterButton(title: "All",
///              isSelected: true,
///              action: { print("All clicked") })
///
/// // "Event" 버튼 (빨간색)
/// FilterButton(title: "Event",
///              color: .red,
///              isSelected: false,
///              action: { selectedEventType = .event })
/// ```
struct FilterButton: View {
    /// 버튼 제목 (예: "All", "Normal", "Parking", "Event")
    let title: String

    /// 버튼 색상 (Optional)
    ///
    /// ## nil일 때
    /// - 선택됨: .accentColor (시스템 강조색, 보통 파랑)
    /// - 비선택: .primary (기본 텍스트 색상)
    ///
    /// ## 값이 있을 때 (예: .red)
    /// - 선택됨: .red 배경 + 흰색 텍스트
    /// - 비선택: .red 텍스트 + 회색 배경
    var color: Color?

    /// 선택 상태 여부
    ///
    /// ## 선택 상태 판별
    /// ```swift
    /// // "All" 버튼
    /// isSelected = (selectedEventType == nil)
    ///
    /// // "Event" 버튼
    /// isSelected = (selectedEventType == .event)
    /// ```
    let isSelected: Bool

    /// 버튼 클릭 시 실행할 액션
    ///
    /// ## 클로저 타입
    /// () -> Void: 파라미터 없고 반환값 없는 함수
    ///
    /// **액션 예시:**
    /// ```swift
    /// action: { selectedEventType = nil }        // "All" 버튼
    /// action: { selectedEventType = .event }     // "Event" 버튼
    /// action: { print("Button clicked") }        // 로그 출력
    /// ```
    let action: () -> Void

    /// FilterButton의 메인 레이아웃
    ///
    /// ## 버튼 스타일 결정 로직
    /// ```
    /// isSelected == true:
    ///   - 배경: color ?? .accentColor (색상 우선, 없으면 시스템 강조색)
    ///   - 텍스트: .white (선택 상태는 항상 흰색)
    ///   - 폰트: .bold (선택 상태는 굵게)
    ///
    /// isSelected == false:
    ///   - 배경: .controlBackgroundColor (회색 계열)
    ///   - 텍스트: color ?? .primary (색상 우선, 없으면 기본 텍스트 색상)
    ///   - 폰트: .regular (일반 두께)
    /// ```
    var body: some View {
        Button(action: action) {
            Text(title)
                /// ## .font(.caption)
                /// - caption: 작은 크기 폰트 (보통 12pt)
                /// - 버튼이 많이 배치되므로 작은 폰트 사용
                .font(.caption)

                /// ## 선택 상태에 따른 폰트 두께
                /// ```swift
                /// isSelected ? .bold : .regular
                /// //   true  → .bold    (굵게)
                /// //   false → .regular (일반)
                /// ```
                .fontWeight(isSelected ? .bold : .regular)

                /// ## 선택 상태에 따른 텍스트 색상
                /// ```swift
                /// isSelected ? .white : (color ?? .primary)
                /// //   true  → .white (선택 상태는 항상 흰색)
                /// //   false → color가 있으면 color, 없으면 .primary
                /// ```
                ///
                /// **색상 예시:**
                /// ```swift
                /// // "All" 버튼 (color = nil)
                /// isSelected = true  → .white
                /// isSelected = false → .primary (검정/흰색)
                ///
                /// // "Event" 버튼 (color = .red)
                /// isSelected = true  → .white
                /// isSelected = false → .red
                /// ```
                .foregroundColor(isSelected ? .white : (color ?? .primary))
                .padding(.horizontal, 12)  // 좌우 여백
                .padding(.vertical, 6)     // 상하 여백

                /// ## 선택 상태에 따른 배경색
                /// - RoundedRectangle: 둥근 모서리 사각형 (cornerRadius: 12)
                /// - .fill(): 배경색으로 채우기
                ///
                /// **배경색 결정:**
                /// ```swift
                /// isSelected ? (color ?? .accentColor) : .controlBackgroundColor
                /// //   true  → color가 있으면 color, 없으면 .accentColor
                /// //   false → .controlBackgroundColor (회색)
                /// ```
                ///
                /// **배경 예시:**
                /// ```
                /// // "All" 버튼 (color = nil)
                /// isSelected = true:  ┌──────────┐
                ///                     │   All    │ 배경: 파랑 (.accentColor)
                ///                     └──────────┘
                ///
                /// isSelected = false: ┌──────────┐
                ///                     │   All    │ 배경: 회색
                ///                     └──────────┘
                ///
                /// // "Event" 버튼 (color = .red)
                /// isSelected = true:  ┌──────────┐
                ///                     │  Event   │ 배경: 빨강
                ///                     └──────────┘
                ///
                /// isSelected = false: ┌──────────┐
                ///                     │  Event   │ 배경: 회색, 텍스트: 빨강
                ///                     └──────────┘
                /// ```
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? (color ?? Color.accentColor) : Color(nsColor: .controlBackgroundColor))
                )
        }
        /// ## .buttonStyle(.plain)
        /// - Button 기본 스타일 제거 (기본 배경, 호버 효과 등)
        /// - 커스텀 배경(.background)이 정확하게 적용되도록 함
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

/// @struct EmptyStateView
/// @brief 검색/필터링 결과 없음 표시 View
///
/// @details
/// 검색 또는 필터링 결과가 없을 때 표시되는 빈 상태 View입니다.
///
/// ## 표시 시점
/// - filteredFiles.isEmpty == true
/// - 검색어로 파일을 찾지 못함
/// - 필터 조건에 맞는 파일이 없음
/// - 원본 videoFiles 배열이 비어있음
///
/// ## UI 구성
/// ```
/// ┌────────────────────────────┐
/// │                            │
/// │         🎥 (48pt)          │ ← SF Symbol: video.slash
/// │                            │
/// │    No Videos Found         │ ← 제목 (.title2, bold)
/// │                            │
/// │  Try adjusting your search │ ← 안내 메시지 (.caption)
/// │     or filters             │
/// │                            │
/// └────────────────────────────┘
/// ```
///
/// ## 사용자 경험 개선
/// - 빈 화면 대신 명확한 안내 제공
/// - 문제 해결 방법 제시 ("조정해보세요")
/// - 시각적 아이콘으로 상태 명확화
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            /// 비디오 없음 아이콘
            ///
            /// ## SF Symbol: video.slash
            /// - 비디오 아이콘에 슬래시가 그어진 모양
            /// - "비디오 없음" 상태를 직관적으로 표현
            ///
            /// **아이콘 예시:**
            /// ```
            /// video.slash:  📹/  (비디오에 슬래시)
            /// video.fill:   📹   (일반 비디오)
            /// photo.slash:  🖼️/  (사진에 슬래시)
            /// ```
            Image(systemName: "video.slash")
                .font(.system(size: 48))        // 큰 아이콘 (48pt)
                .foregroundColor(.secondary)    // 회색 계열

            /// 제목 텍스트
            ///
            /// ## .title2
            /// - 큰 제목 폰트 (보통 22pt)
            /// - 메인 메시지로 사용
            Text("No Videos Found")
                .font(.title2)
                .fontWeight(.medium)  // 중간 두께

            /// 안내 메시지
            ///
            /// ## .caption
            /// - 작은 폰트 (보통 12pt)
            /// - 보조 설명으로 사용
            ///
            /// **메시지 의도:**
            /// - "검색어를 바꿔보세요"
            /// - "필터를 조정해보세요"
            /// - 문제 해결 방법 제시
            Text("Try adjusting your search or filters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        /// ## .frame(maxWidth:, maxHeight:)
        /// - .infinity: 부모 View의 전체 공간 차지
        /// - VStack이 화면 중앙에 배치됨
        ///
        /// **레이아웃 예시:**
        /// ```
        /// 부모 View (List 영역):
        /// ┌────────────────────────────┐
        /// │                            │ ← .infinity로 전체 공간 차지
        /// │                            │
        /// │        VStack 중앙         │ ← VStack이 자동으로 중앙 정렬
        /// │                            │
        /// │                            │
        /// └────────────────────────────┘
        /// ```
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Status Bar

/// @struct StatusBar
/// @brief 파일 리스트 하단 상태바
///
/// @details
/// 파일 리스트 하단에 표시되는 상태바로, 필터링 결과를 요약합니다.
///
/// ## 표시 내용
/// - "X of Y videos": 필터링된 파일 개수 / 전체 파일 개수
///
/// ## UI 구성
/// ```
/// ┌────────────────────────────────┐
/// │ 10 of 100 videos        [TODO] │ ← 좌측: 카운터, 우측: 추가 정보 (미구현)
/// └────────────────────────────────┘
/// ```
///
/// ## 사용 예시
/// ```swift
/// // 초기 상태 (필터 없음)
/// StatusBar(fileCount: 100, totalCount: 100)
/// // 표시: "100 of 100 videos"
///
/// // 검색 후
/// StatusBar(fileCount: 10, totalCount: 100)
/// // 표시: "10 of 100 videos"
///
/// // 필터 + 검색
/// StatusBar(fileCount: 3, totalCount: 100)
/// // 표시: "3 of 100 videos"
/// ```
struct StatusBar: View {
    /// 필터링 후 파일 개수
    ///
    /// ## 값 예시
    /// - 초기 상태 (필터 없음): fileCount == totalCount
    /// - 검색 후: fileCount < totalCount
    /// - 검색 결과 없음: fileCount == 0
    let fileCount: Int

    /// 전체 파일 개수 (필터링 전)
    ///
    /// ## 값 예시
    /// - videoFiles.count (변하지 않음)
    let totalCount: Int

    var body: some View {
        HStack {
            /// 파일 카운터 텍스트
            ///
            /// ## String Interpolation
            /// "\(fileCount) of \(totalCount) videos"
            /// - \(변수): 변수 값을 문자열에 삽입
            ///
            /// **예시:**
            /// ```swift
            /// fileCount = 10, totalCount = 100
            /// "\(fileCount) of \(totalCount) videos"
            /// → "10 of 100 videos"
            ///
            /// fileCount = 0, totalCount = 100
            /// "\(fileCount) of \(totalCount) videos"
            /// → "0 of 100 videos"
            /// ```
            Text("\(fileCount) of \(totalCount) videos")
                .font(.caption)              // 작은 폰트
                .foregroundColor(.secondary)  // 회색 계열

            /// ## Spacer()
            /// - 남은 공간을 모두 차지
            /// - 왼쪽 텍스트를 좌측 정렬, 오른쪽 컨텐츠를 우측 정렬
            ///
            /// **레이아웃 효과:**
            /// ```
            /// Spacer 없음:
            /// [10 of 100 videos][TODO]
            ///
            /// Spacer 있음:
            /// [10 of 100 videos]           [TODO]
            ///                   ↑ Spacer가 공간 차지
            /// ```
            Spacer()

            /// TODO: 추가 상태 정보
            ///
            /// ## 향후 추가 가능한 정보
            /// - 총 파일 크기: "Total: 10.5 GB"
            /// - 총 재생 시간: "Duration: 2h 30m"
            /// - 마지막 업데이트: "Updated: 2024-01-15"
            ///
            /// **구현 예시:**
            /// ```swift
            /// Text("Total: \(totalSize)")
            ///     .font(.caption)
            ///     .foregroundColor(.secondary)
            /// ```
        }
        .padding(.horizontal)  // 좌우 여백
        .padding(.vertical, 8)  // 상하 여백
        .background(Color(nsColor: .controlBackgroundColor))  // macOS 시스템 배경색
    }
}

// MARK: - Placeholder Views

/// PlaceholderView 구조체
/// 비디오 파일이 선택되지 않았을 때 표시되는 플레이스홀더 View입니다.
///
/// ## 표시 시점
/// - selectedFile == nil (선택된 파일 없음)
/// - 앱 첫 실행 시
/// - 선택 해제 후
///
/// ## UI 구성
/// ```
/// ┌────────────────────────────┐
/// │                            │
/// │         📹 (64pt)          │ ← SF Symbol: video.fill
/// │                            │
/// │  Select a video to view    │ ← 안내 메시지 (.title2, bold)
/// │       details              │
/// │                            │
/// └────────────────────────────┘
/// ```
///
/// ## 사용 예시
/// ```swift
/// // ContentView에서 조건부 렌더링
/// if let file = selectedFile {
///     VideoPlayerView(videoFile: file)  // 선택된 파일 재생
/// } else {
///     PlaceholderView()  // 선택 안내 표시
/// }
/// ```
struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            /// 비디오 아이콘
            ///
            /// ## SF Symbol: video.fill
            /// - 채워진 비디오 아이콘
            /// - 비디오 관련 UI임을 명확히 표현
            Image(systemName: "video.fill")
                .font(.system(size: 64))        // 큰 아이콘 (64pt)
                .foregroundColor(.secondary)    // 회색 계열

            /// 안내 메시지
            ///
            /// ## 메시지 의도
            /// - "비디오를 선택하세요"
            /// - 사용자에게 다음 행동 안내
            Text("Select a video to view details")
                .font(.title2)               // 큰 폰트
                .fontWeight(.medium)         // 중간 두께
                .foregroundColor(.secondary) // 회색 계열
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 화면 전체 차지
    }
}

/// FileDetailView 구조체
/// 선택된 비디오 파일의 상세 정보를 표시하는 View입니다.
///
/// ## 표시 정보
/// - **기본 정보**: 파일명, 이벤트 타입, 타임스탬프, 재생 시간, 파일 크기, 채널 개수
/// - **채널 목록**: 각 채널의 카메라 위치, 해상도, 프레임율
/// - **메타데이터**: GPS 이동 거리, 평균/최고 속도, 충격 이벤트 개수, 최대 G-Force
/// - **노트**: 사용자 메모
///
/// ## UI 구조
/// ```
/// ┌────────────────────────────────┐
/// │ 📹 video_20240115_1430.mp4     │ ← 파일명 (.title, bold)
/// │ [Event] 2024-01-15 14:30       │ ← 이벤트 배지 + 타임스탬프
/// ├────────────────────────────────┤ ← Divider
/// │ File Information               │ ← 섹션 제목 (.headline)
/// │ Duration      00:01:30         │ ← DetailRow
/// │ Size          512 MB           │
/// │ Channels      4                │
/// ├────────────────────────────────┤
/// │ Channels                       │
/// │ [📹 Front  1920x1080  30fps]   │ ← ChannelRow
/// │ [📹 Rear   1920x1080  30fps]   │
/// ├────────────────────────────────┤
/// │ Metadata                       │
/// │ Distance      5.2 km           │
/// │ Avg Speed     45 km/h          │
/// │ Max Speed     80 km/h          │
/// │ Impact Events 2                │
/// │ Max G-Force   3.5 G            │
/// ├────────────────────────────────┤
/// │ Notes                          │
/// │ 고속도로 주행 중 급정거         │ ← 사용자 메모
/// └────────────────────────────────┘
/// ```
///
/// ## 조건부 섹션 렌더링
/// - Channels: videoFile.channels.isEmpty == false일 때만 표시
/// - Metadata: videoFile.hasGPSData || videoFile.hasAccelerationData일 때만 표시
/// - Notes: videoFile.notes != nil일 때만 표시
struct FileDetailView: View {
    /// 표시할 비디오 파일 정보
    let videoFile: VideoFile

    var body: some View {
        /// ## ScrollView
        /// - 내용이 화면을 넘어갈 때 스크롤 가능
        /// - 파일 정보가 많을 때 대응
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                /// 기본 정보 섹션
                VStack(alignment: .leading, spacing: 8) {
                    /// 파일명
                    ///
                    /// ## videoFile.baseFilename
                    /// - 예: "video_20240115_1430.mp4"
                    /// - 경로 없이 파일명만 표시
                    Text(videoFile.baseFilename)
                        .font(.title)        // 큰 폰트
                        .fontWeight(.bold)   // 굵게

                    HStack {
                        /// 이벤트 타입 배지
                        ///
                        /// ## EventBadge
                        /// - 색상 있는 배지로 이벤트 타입 표시
                        /// - 예: [Normal], [Parking], [Event]
                        EventBadge(eventType: videoFile.eventType)

                        /// 타임스탬프
                        ///
                        /// ## videoFile.timestampString
                        /// - 예: "2024-01-15 14:30:15"
                        /// - 파일 촬영 시각
                        Text(videoFile.timestampString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                /// 파일 정보 섹션
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Information")
                        .font(.headline)  // 섹션 제목

                    /// 재생 시간
                    ///
                    /// ## DetailRow
                    /// - 레이블-값 쌍을 표시하는 컴포넌트
                    /// - HStack으로 레이블 좌측, 값 우측 정렬
                    ///
                    /// **표시 예시:**
                    /// ```
                    /// Duration      00:01:30
                    /// ↑ 레이블      ↑ 값 (우측 정렬)
                    /// ```
                    DetailRow(label: "Duration", value: videoFile.durationString)
                    DetailRow(label: "Size", value: videoFile.totalFileSizeString)
                    DetailRow(label: "Channels", value: "\(videoFile.channelCount)")
                }

                /// 채널 목록 섹션 (조건부 렌더링)
                ///
                /// ## 표시 조건
                /// - videoFile.channels.isEmpty == false
                /// - 채널이 하나라도 있을 때만 표시
                if !videoFile.channels.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Channels")
                            .font(.headline)

                        /// 각 채널을 ChannelRow로 표시
                        ///
                        /// ## ForEach
                        /// - videoFile.channels 배열 순회
                        /// - 각 ChannelInfo를 ChannelRow로 렌더링
                        ///
                        /// **렌더링 예시:**
                        /// ```swift
                        /// channels = [
                        ///     ChannelInfo(position: .front, ...),
                        ///     ChannelInfo(position: .rear, ...)
                        /// ]
                        ///
                        /// // ForEach가 생성하는 View
                        /// ChannelRow(channel: ChannelInfo(position: .front, ...))
                        /// ChannelRow(channel: ChannelInfo(position: .rear, ...))
                        /// ```
                        ForEach(videoFile.channels) { channel in
                            ChannelRow(channel: channel)
                        }
                    }
                }

                /// 메타데이터 요약 섹션 (조건부 렌더링)
                ///
                /// ## 표시 조건
                /// - videoFile.hasGPSData: GPS 데이터가 있을 때
                /// - videoFile.hasAccelerationData: 가속도 데이터가 있을 때
                /// - 둘 중 하나라도 true이면 표시
                if videoFile.hasGPSData || videoFile.hasAccelerationData {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadata")
                            .font(.headline)

                        /// metadata.summary에서 통계 가져오기
                        ///
                        /// ## VideoMetadata.Summary
                        /// - GPS 데이터: 이동 거리, 평균/최고 속도
                        /// - 가속도 데이터: 충격 이벤트 개수, 최대 G-Force
                        let summary = videoFile.metadata.summary

                        /// GPS 데이터 표시 (조건부)
                        if videoFile.hasGPSData {
                            DetailRow(label: "Distance", value: summary.distanceString)

                            /// Optional Binding으로 안전하게 표시
                            ///
                            /// ## if let
                            /// - summary.averageSpeedString이 nil이 아닐 때만 실행
                            /// - avgSpeed 변수에 unwrapped 값 할당
                            if let avgSpeed = summary.averageSpeedString {
                                DetailRow(label: "Avg Speed", value: avgSpeed)
                            }
                            if let maxSpeed = summary.maximumSpeedString {
                                DetailRow(label: "Max Speed", value: maxSpeed)
                            }
                        }

                        /// 가속도 데이터 표시 (조건부)
                        if videoFile.hasAccelerationData {
                            DetailRow(label: "Impact Events", value: "\(summary.impactEventCount)")
                            if let maxGForce = summary.maximumGForceString {
                                DetailRow(label: "Max G-Force", value: maxGForce)
                            }
                        }
                    }
                }

                /// 노트 섹션 (조건부 렌더링)
                ///
                /// ## 표시 조건
                /// - videoFile.notes != nil
                /// - 사용자가 작성한 메모가 있을 때만 표시
                ///
                /// ## Optional Binding
                /// ```swift
                /// if let notes = videoFile.notes {
                ///     // notes가 nil이 아닐 때만 실행
                ///     // notes 변수는 String 타입 (Optional 아님)
                /// }
                /// ```
                if let notes = videoFile.notes {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)

                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()  // VStack 외부 여백
        }
    }
}

/// DetailRow 구조체
/// 레이블-값 쌍을 표시하는 간단한 행 컴포넌트입니다.
///
/// ## UI 레이아웃
/// ```
/// ┌────────────────────────────────┐
/// │ Duration            00:01:30   │ ← HStack
/// │ ↑ 레이블 (좌측)      ↑ 값 (우측)│
/// └────────────────────────────────┘
/// ```
///
/// ## 사용 예시
/// ```swift
/// DetailRow(label: "Duration", value: "00:01:30")
/// DetailRow(label: "Size", value: "512 MB")
/// DetailRow(label: "Channels", value: "4")
/// ```
struct DetailRow: View {
    /// 레이블 텍스트 (왼쪽)
    let label: String

    /// 값 텍스트 (오른쪽)
    let value: String

    var body: some View {
        HStack {
            /// 레이블
            ///
            /// ## .foregroundColor(.secondary)
            /// - 회색 계열 색상
            /// - 레이블은 보조 정보이므로 덜 강조
            Text(label)
                .foregroundColor(.secondary)

            /// ## Spacer()
            /// - 레이블과 값 사이 공간 확보
            /// - 레이블 좌측 정렬, 값 우측 정렬
            Spacer()

            /// 값
            ///
            /// ## .fontWeight(.medium)
            /// - 중간 두께 폰트
            /// - 값은 주요 정보이므로 더 강조
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)  // 약간 작은 폰트
    }
}

/// ChannelRow 구조체
/// 비디오 채널 정보를 표시하는 행 컴포넌트입니다.
///
/// ## 표시 정보
/// - 카메라 위치: Front, Rear, Left, Right
/// - 해상도: 1920x1080, 1280x720 등
/// - 프레임율: 30fps, 60fps 등
///
/// ## UI 레이아웃
/// ```
/// ┌────────────────────────────────┐
/// │ 📹 Front    1920x1080    30fps │ ← HStack (회색 배경)
/// │ ↑   ↑          ↑           ↑   │
/// │ 아이콘 위치    해상도     FPS  │
/// └────────────────────────────────┘
/// ```
///
/// ## 사용 예시
/// ```swift
/// let channel = ChannelInfo(
///     position: .front,
///     resolutionName: "1920x1080",
///     frameRateString: "30fps"
/// )
/// ChannelRow(channel: channel)
/// ```
struct ChannelRow: View {
    /// 채널 정보 (카메라 위치, 해상도, 프레임율 등)
    let channel: ChannelInfo

    var body: some View {
        HStack {
            /// 비디오 아이콘
            Image(systemName: "video.fill")
                .foregroundColor(.secondary)

            /// 카메라 위치
            ///
            /// ## channel.position.displayName
            /// - CameraPosition enum의 표시 이름
            /// - 예: "Front", "Rear", "Left", "Right"
            ///
            /// **예시:**
            /// ```swift
            /// CameraPosition.front.displayName  → "Front"
            /// CameraPosition.rear.displayName   → "Rear"
            /// ```
            Text(channel.position.displayName)
                .fontWeight(.medium)  // 위치는 더 강조

            Spacer()

            /// 해상도
            ///
            /// ## channel.resolutionName
            /// - 예: "1920x1080", "1280x720", "3840x2160" (4K)
            Text(channel.resolutionName)
                .font(.caption)
                .foregroundColor(.secondary)

            /// 프레임율
            ///
            /// ## channel.frameRateString
            /// - 예: "30fps", "60fps", "120fps"
            Text(channel.frameRateString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)  // 기본 폰트 크기
        .padding(.vertical, 4)     // 상하 여백
        .padding(.horizontal, 8)   // 좌우 여백
        .background(Color(nsColor: .controlBackgroundColor))  // 회색 배경
        .cornerRadius(6)  // 모서리 둥글게
    }
}

// MARK: - Preview

/// SwiftUI Preview
///
/// ## PreviewProvider란?
/// - Xcode의 Canvas에서 View를 미리 볼 수 있게 해주는 프로토콜
/// - 실제 앱 빌드 없이 UI 확인 가능
/// - 다양한 조건(디바이스, 다크모드 등)에서 테스트 가능
///
/// ## 사용 방법
/// 1. Xcode Canvas 활성화 (⌘ + Option + Enter)
/// 2. Canvas에서 자동으로 previews 렌더링
/// 3. 코드 수정 시 실시간으로 Preview 업데이트
///
/// ## 주의사항
/// - PreviewProvider는 Debug 빌드에서만 컴파일됨
/// - Release 빌드에서는 자동으로 제외됨 (앱 크기 절약)
struct FileListView_Previews: PreviewProvider {
    static var previews: some View {
        FileListViewPreviewWrapper()
    }
}

/// FileListView Preview Wrapper
///
/// ## @State가 필요한 이유
/// FileListView는 @Binding을 받으므로, Preview에서 @State로 원본 데이터를 제공해야 합니다.
///
/// **Preview 구조:**
/// ```
/// FileListViewPreviewWrapper (Wrapper)
/// └─ @State var videoFiles        ← 원본 데이터 소유
/// └─ @State var selectedFile
///     ↓ $ 붙여서 Binding 전달
/// FileListView (실제 View)
/// └─ @Binding var videoFiles      ← 참조만 보유
/// └─ @Binding var selectedFile
/// ```
///
/// ## VideoFile.allSamples
/// - 테스트용 샘플 데이터
/// - 다양한 이벤트 타입, 메타데이터를 가진 가짜 VideoFile 배열
///
/// **샘플 데이터 예시:**
/// ```swift
/// VideoFile.allSamples = [
///     VideoFile(baseFilename: "video1.mp4", eventType: .normal, ...),
///     VideoFile(baseFilename: "video2.mp4", eventType: .event, ...),
///     VideoFile(baseFilename: "video3.mp4", eventType: .parking, ...)
/// ]
/// ```
private struct FileListViewPreviewWrapper: View {
    /// Preview용 비디오 파일 배열
    ///
    /// ## VideoFile.allSamples
    /// - Models/VideoFile.swift에 정의된 샘플 데이터
    /// - Preview에서 다양한 시나리오 테스트 가능
    @State private var videoFiles: [VideoFile] = VideoFile.allSamples

    /// Preview용 선택된 파일
    ///
    /// ## nil로 초기화
    /// - 초기에는 선택된 파일 없음
    /// - Preview에서 파일 클릭 시 자동으로 업데이트
    @State private var selectedFile: VideoFile?

    var body: some View {
        /// FileListView를 400x600 크기로 Preview
        ///
        /// ## .frame(width:, height:)
        /// - Preview 창 크기 고정
        /// - 실제 사용 시 크기 확인 가능
        FileListView(videoFiles: $videoFiles, selectedFile: $selectedFile)
            .frame(width: 400, height: 600)
    }
}
