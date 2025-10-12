/// @file DebugLogView.swift
/// @brief 디버그 로그 뷰어 오버레이
/// @author BlackboxPlayer Development Team
/// @details
/// 애플리케이션의 디버그 로그를 실시간으로 표시하는 오버레이 UI를 구현합니다.
/// 실시간 로그 스트리밍, 자동 스크롤, 로그 레벨별 색상 구분 기능을 제공합니다.

/*
 【DebugLogView 개요】

 이 파일은 애플리케이션의 디버그 로그를 실시간으로 표시하는 오버레이 UI를 구현합니다.


 ┌─────────────────────────────────────┐
 │  Debug Log         [Auto-scroll] 🗑️ │ ← 헤더 (제목 + 컨트롤)
 ├─────────────────────────────────────┤
 │ 14:23:01 [INFO] App started         │
 │ 14:23:05 [DEBUG] Loading video...   │
 │ 14:23:10 [WARNING] Low buffer       │ ← 로그 리스트
 │ 14:23:15 [ERROR] Decode failed      │   (자동 스크롤)
 │                                     │
 └─────────────────────────────────────┘


 【주요 기능】

 1. 실시간 로그 표시
    - LogManager 싱글톤으로부터 로그 수신
    - 새 로그 추가 시 자동으로 UI 업데이트

 2. 자동 스크롤
    - 새 로그가 추가되면 자동으로 맨 아래로 스크롤
    - 토글 버튼으로 On/Off 가능

 3. 로그 레벨별 색상
    - Debug: 회색 (상세 디버그 정보)
    - Info: 흰색 (일반 정보)
    - Warning: 노란색 (경고)
    - Error: 빨간색 (오류)

 4. 로그 관리
    - Clear 버튼으로 모든 로그 삭제
    - 텍스트 선택 가능 (복사를 위해)


 【사용 예시】

 ```swift
 // 1. 오버레이로 표시
 ZStack {
     // 메인 콘텐츠
     ContentView()

     // 하단에 디버그 로그 오버레이
     VStack {
         Spacer()
         DebugLogView()
             .padding()
     }
 }

 // 2. 로그 기록
 LogManager.shared.log("Video loaded", level: .info)
 LogManager.shared.log("Frame dropped", level: .warning)
 ```


 【SwiftUI 개념】

 이 파일에서 배울 수 있는 주요 SwiftUI 개념들:

 1. @ObservedObject
    - 외부 객체의 변경사항 관찰
    - 객체가 변경되면 View 자동 재렌더링

 2. @State
    - View 내부 상태 저장
    - 상태 변경 시 View 재렌더링

 3. ScrollViewReader
    - 프로그래밍 방식으로 스크롤 위치 제어
    - scrollTo() 메서드로 특정 항목으로 이동

 4. LazyVStack
    - 화면에 보이는 항목만 렌더링 (성능 최적화)
    - 많은 로그 항목이 있을 때 효율적

 5. onChange 모디파이어
    - 특정 값의 변경 감지
    - 변경 시 추가 작업 수행

 6. Private struct
    - View를 작은 서브뷰로 분리
    - 코드 재사용성과 가독성 향상


 【디버그 로그 뷰어의 중요성】

 디버그 로그 뷰어는 개발 및 테스팅 중 문제를 진단하는 데 필수적입니다:

 ✓ 실시간 피드백
   → 애플리케이션이 무엇을 하고 있는지 즉시 확인

 ✓ 문제 추적
   → 오류 발생 전후의 이벤트 순서 파악

 ✓ 성능 분석
   → 특정 작업에 걸리는 시간 측정

 ✓ 사용자 테스팅
   → QA 팀이나 베타 테스터가 문제 리포트 시 로그 제공


 【관련 파일】

 - LogManager.swift: 로그를 관리하고 저장하는 싱글톤 클래스
 - LogEntry.swift: 개별 로그 엔트리의 데이터 모델

 */

import SwiftUI

/// @struct DebugLogView
/// @brief 디버그 로그 뷰어 오버레이
///
/// @details
/// 디버그 로그를 실시간으로 표시하는 오버레이 뷰입니다.
///
/// **주요 기능:**
/// - 실시간 로그 스트리밍
/// - 자동 스크롤 (토글 가능)
/// - 로그 레벨별 색상 구분
/// - 로그 클리어 기능
///
/// **사용 예시:**
/// ```swift
/// ZStack {
///     ContentView()
///     VStack {
///         Spacer()
///         DebugLogView()
///             .padding()
///     }
/// }
/// ```
///
/// **연관 타입:**
/// - `LogManager`: 로그 데이터 제공자
/// - `LogEntry`: 개별 로그 엔트리
///
struct DebugLogView: View {
    // MARK: - Properties

    /// @var logManager
    /// @brief 로그 관리자 싱글톤 인스턴스
    ///
    /// **@ObservedObject란?**
    ///
    /// @ObservedObject는 외부에서 생성된 ObservableObject를 관찰하는 프로퍼티 래퍼입니다.
    ///
    /// **작동 원리:**
    /// ```
    /// 1. LogManager에서 로그 추가
    ///    ↓
    /// 2. @Published var logs 변경
    ///    ↓
    /// 3. DebugLogView 자동 재렌더링
    ///    ↓
    /// 4. 새 로그가 화면에 표시됨
    /// ```
    ///
    /// **@ObservedObject vs @State:**
    ///
    /// | @ObservedObject                | @State                      |
    /// |--------------------------------|-----------------------------|
    /// | 외부 객체 관찰                 | View 내부 상태 저장          |
    /// | 여러 View에서 공유 가능        | 해당 View에서만 사용         |
    /// | 참조 타입 (class)              | 값 타입 (struct/enum/기본형) |
    /// | 싱글톤 패턴에 적합             | 간단한 UI 상태에 적합        |
    ///
    /// **왜 shared 싱글톤을 사용할까?**
    ///
    /// LogManager는 앱 전체에서 하나의 인스턴스만 존재해야 합니다:
    /// - 모든 코드가 동일한 로그 저장소에 접근
    /// - 여러 View에서 동일한 로그 목록 표시
    /// - 메모리 효율성 (중복 인스턴스 방지)
    ///
    @ObservedObject var logManager = LogManager.shared

    /// @var autoScroll
    /// @brief 자동 스크롤 토글 상태
    ///
    /// **@State란?**
    ///
    /// @State는 View 내부에서만 사용하는 간단한 상태를 저장하는 프로퍼티 래퍼입니다.
    ///
    /// **작동 원리:**
    /// ```swift
    /// // 1. 초기값 설정
    /// @State private var autoScroll = true  // true로 시작
    ///
    /// // 2. Toggle이 상태 변경
    /// Toggle("Auto-scroll", isOn: $autoScroll)  // $로 바인딩
    ///
    /// // 3. 상태가 false로 변경되면...
    /// //    → SwiftUI가 View를 재렌더링
    /// //    → onChange에서 if autoScroll 체크
    /// ```
    ///
    /// **private을 사용하는 이유:**
    ///
    /// autoScroll은 DebugLogView 내부에서만 사용되므로:
    /// - 캡슐화 (encapsulation) - 외부에서 접근 불가
    /// - 명확한 의도 표현 - "이 상태는 내부 전용"
    /// - 코드 안전성 - 실수로 외부에서 수정 방지
    ///
    /// **기본값이 true인 이유:**
    ///
    /// 대부분의 경우 새 로그가 추가되면 자동으로 스크롤하는 것이 유용합니다:
    /// - 개발 중: 최신 로그를 즉시 확인
    /// - 디버깅: 실시간으로 이벤트 추적
    /// - 사용자는 원하면 토글로 끌 수 있음
    ///
    @State private var autoScroll = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            //
            // 헤더 섹션: 제목 + 자동 스크롤 토글 + 클리어 버튼
            //
            // HStack을 사용하여 좌우로 배치:
            // [제목]                    [토글] [버튼]
            HStack {
                // Title
                //
                // "Debug Log" 제목을 표시합니다.
                //
                // .font(.headline):
                //   - 헤드라인 스타일 (일반적으로 17pt, Bold)
                //   - 시스템 Dynamic Type 지원 (사용자가 설정한 폰트 크기에 따라 자동 조정)
                //
                // .foregroundColor(.white):
                //   - 텍스트 색상을 흰색으로 설정
                //   - 검은 배경(opacity 0.9)에서 잘 보이도록
                Text("Debug Log")
                    .font(.headline)
                    .foregroundColor(.white)

                // Spacer pushes controls to the right
                //
                // Spacer는 가능한 모든 공간을 차지합니다.
                //
                // HStack에서 Spacer의 역할:
                // [Text] [======= Spacer =======] [Toggle] [Button]
                //
                // 결과: Toggle과 Button이 오른쪽 끝으로 밀려남
                Spacer()

                // Auto-scroll toggle
                //
                // 자동 스크롤 기능을 On/Off 할 수 있는 토글 버튼입니다.
                //
                // **Toggle의 작동 원리:**
                //
                // ```swift
                // Toggle("Auto-scroll", isOn: $autoScroll)
                // //      ~~~~~~~~~~~~         ~~~~~~~~~~~
                // //      레이블 텍스트        바인딩된 상태
                // ```
                //
                // **$ 기호의 의미 (Binding):**
                //
                // $autoScroll은 autoScroll 변수에 대한 "바인딩"을 생성합니다.
                //
                // 바인딩(Binding)이란?
                //   - 양방향 연결 (Two-way binding)
                //   - Toggle이 값을 읽고 쓸 수 있음
                //   - 값이 변경되면 자동으로 동기화
                //
                // 데이터 흐름:
                // ```
                // Toggle 스위치 클릭
                //       ↓
                // $autoScroll을 통해 값 변경 (true → false)
                //       ↓
                // @State가 변경 감지
                //       ↓
                // SwiftUI가 View 재렌더링
                //       ↓
                // 새로운 상태로 UI 업데이트
                // ```
                //
                // **.toggleStyle(.switch):**
                //   - macOS의 스위치 스타일 (iOS와 유사한 On/Off 스위치)
                //   - 다른 스타일: .checkbox (체크박스), .button (버튼)
                //
                // **.controlSize(.mini):**
                //   - 컨트롤 크기를 mini로 설정
                //   - 크기 옵션: .mini < .small < .regular < .large
                //   - 헤더에 들어가므로 작게 표시
                //
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .foregroundColor(.white)

                // Clear button
                //
                // 모든 로그를 삭제하는 버튼입니다.
                //
                // **Button의 구조:**
                //
                // ```swift
                // Button(action: { /* 실행할 코드 */ }) {
                //     /* 버튼의 외형 */
                // }
                // ```
                //
                // **action 클로저:**
                //
                // { logManager.clear() }
                //   - 버튼 클릭 시 실행되는 코드
                //   - LogManager의 clear() 메서드 호출
                //   - 모든 로그 엔트리를 배열에서 제거
                //
                // **SF Symbols:**
                //
                // Image(systemName: "trash")
                //   - Apple의 SF Symbols 아이콘 사용
                //   - "trash" = 휴지통 아이콘
                //   - 30,000개 이상의 아이콘 제공
                //   - 벡터 기반이라 모든 크기에서 선명함
                //
                // **버튼 스타일링:**
                //
                // .buttonStyle(.plain)
                //   - 기본 버튼 스타일 제거
                //   - macOS의 버튼은 기본적으로 파란색 배경이 있음
                //   - plain 스타일로 투명한 버튼 만들기
                //
                // .help("Clear logs")
                //   - 마우스 호버 시 툴팁 표시
                //   - 사용자에게 버튼 기능 설명
                //
                Button(action: { logManager.clear() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Clear logs")
            }
            .padding()
            .background(Color.black.opacity(0.9))

            // Header/Body separator
            //
            // 헤더와 로그 리스트 사이의 구분선입니다.
            //
            // Divider는:
            //   - 얇은 수평선 (HStack 내에서는 수직선)
            //   - 시스템 색상 사용 (자동으로 라이트/다크 모드 대응)
            //   - 시각적 구분을 위해 사용
            Divider()

            // Log list with auto-scroll
            //
            // 로그 항목들을 스크롤 가능한 리스트로 표시합니다.
            //
            // **ScrollViewReader란?**
            //
            // ScrollViewReader는 프로그래밍 방식으로 스크롤 위치를 제어할 수 있게 해주는 컨테이너입니다.
            //
            // 기본 구조:
            // ```swift
            // ScrollViewReader { proxy in
            //     ScrollView {
            //         // 콘텐츠...
            //     }
            //     .onChange(...) {
            //         proxy.scrollTo(targetID)  // 특정 항목으로 스크롤
            //     }
            // }
            // ```
            //
            // **proxy란?**
            //
            // proxy는 ScrollViewProxy 타입의 객체입니다:
            //   - scrollTo() 메서드 제공
            //   - 특정 ID를 가진 View로 스크롤
            //   - 애니메이션 포함 가능
            //
            // **왜 필요한가?**
            //
            // 일반 ScrollView는 사용자가 수동으로만 스크롤할 수 있습니다.
            // ScrollViewReader를 사용하면:
            //   - 새 로그 추가 시 자동으로 맨 아래로 스크롤
            //   - 특정 로그로 점프
            //   - 검색 결과로 스크롤
            //
            ScrollViewReader { proxy in
                ScrollView {
                    // **LazyVStack vs VStack:**
                    //
                    // LazyVStack:
                    //   - 화면에 보이는 항목만 렌더링 (Lazy loading)
                    //   - 수천 개의 로그가 있어도 성능 유지
                    //   - 스크롤 시 필요할 때만 View 생성
                    //
                    // VStack:
                    //   - 모든 항목을 즉시 렌더링
                    //   - 항목이 많으면 느려짐
                    //   - 항목이 적고 고정적일 때 사용
                    //
                    // 성능 비교:
                    // ```
                    // 10,000개 로그 기준
                    //
                    // VStack:
                    //   - 초기 렌더링: 10,000개 모두 생성
                    //   - 메모리: 높음
                    //   - 스크롤 성능: 느림
                    //
                    // LazyVStack:
                    //   - 초기 렌더링: 화면에 보이는 ~20개만 생성
                    //   - 메모리: 낮음
                    //   - 스크롤 성능: 빠름
                    // ```
                    //
                    // **alignment: .leading:**
                    //   - 모든 항목을 왼쪽 정렬
                    //   - 로그 텍스트는 일반적으로 왼쪽 정렬
                    //
                    // **spacing: 4:**
                    //   - 항목 간 4pt 간격
                    //   - 너무 촘촘하지 않고 너무 넓지 않게
                    //
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // **ForEach로 로그 항목 렌더링:**
                        //
                        // ForEach는 컬렉션의 각 항목에 대해 View를 생성합니다.
                        //
                        // 기본 구조:
                        // ```swift
                        // ForEach(collection) { item in
                        //     // item을 사용한 View
                        // }
                        // ```
                        //
                        // **Identifiable 프로토콜:**
                        //
                        // LogEntry가 Identifiable을 채택하면:
                        //   - ForEach가 각 항목을 고유하게 식별
                        //   - id 프로퍼티 자동 사용
                        //   - SwiftUI가 효율적으로 업데이트 추적
                        //
                        // LogEntry 예시:
                        // ```swift
                        // struct LogEntry: Identifiable {
                        //     let id = UUID()  // 고유 ID
                        //     let message: String
                        //     let timestamp: Date
                        //     let level: LogLevel
                        // }
                        // ```
                        //
                        // **왜 ID가 중요한가?**
                        //
                        // ID 없이:
                        // ```
                        // 로그 10개 → 1개 추가 → 전체 11개 재렌더링 ❌
                        // ```
                        //
                        // ID 있으면:
                        // ```
                        // 로그 10개 → 1개 추가 → 새 항목 1개만 렌더링 ✓
                        // ```
                        //
                        ForEach(logManager.logs) { entry in
                            // **LogEntryRow 서브뷰:**
                            //
                            // 각 로그 엔트리를 표시하는 재사용 가능한 서브뷰입니다.
                            //
                            // 서브뷰로 분리하는 이유:
                            //   1. 코드 재사용성 (다른 곳에서도 사용 가능)
                            //   2. 가독성 향상 (각 부분이 명확히 구분)
                            //   3. 유지보수 용이 (한 곳에서만 수정)
                            //   4. 성능 최적화 (SwiftUI가 더 작은 단위로 업데이트)
                            //
                            LogEntryRow(entry: entry)
                                // **.id(entry.id):**
                                //
                                // View에 명시적으로 ID를 할당합니다.
                                //
                                // 이미 ForEach가 ID를 사용하는데 왜 또 필요한가?
                                //   - ScrollViewProxy.scrollTo()에서 사용하기 위해
                                //   - 특정 로그로 스크롤할 때 타겟 지정
                                //
                                // 예시:
                                // ```swift
                                // proxy.scrollTo(lastLog.id)
                                // //             ~~~~~~~~~~
                                // //             이 ID를 가진 View로 스크롤
                                // ```
                                //
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.8))
                // **onChange 모디파이어:**
                //
                // 특정 값의 변경을 감지하고 반응하는 모디파이어입니다.
                //
                // 기본 구조:
                // ```swift
                // .onChange(of: 관찰할_값) { 새_값 in
                //     // 값이 변경되었을 때 실행할 코드
                // }
                // ```
                //
                // **이 코드의 onChange:**
                //
                // ```swift
                // .onChange(of: logManager.logs.count) { _ in
                //     // 로그 개수가 변경되면 실행
                // }
                // ```
                //
                // **언제 실행되는가?**
                //
                // 로그 추가:
                // ```
                // 로그 5개 → LogManager.log() 호출 → 로그 6개
                //              ↓
                //         logs.count 변경 (5 → 6)
                //              ↓
                //         onChange 클로저 실행
                //              ↓
                //         자동 스크롤 수행
                // ```
                //
                // 로그 삭제:
                // ```
                // 로그 10개 → LogManager.clear() 호출 → 로그 0개
                //              ↓
                //         logs.count 변경 (10 → 0)
                //              ↓
                //         onChange 클로저 실행 (하지만 lastLog가 nil이므로 스크롤 안 함)
                // ```
                //
                // **자동 스크롤 로직:**
                //
                .onChange(of: logManager.logs.count) { _ in
                    // **조건 체크: if autoScroll, let lastLog = ...**
                    //
                    // 이 한 줄에 두 가지 조건이 있습니다:
                    //
                    // 1. autoScroll이 true인가?
                    //    - 사용자가 자동 스크롤을 켰을 때만
                    //    - false면 스크롤 안 함
                    //
                    // 2. lastLog = logManager.logs.last
                    //    - logs 배열의 마지막 항목을 가져옴
                    //    - Optional Binding (옵셔널 언래핑)
                    //    - 로그가 없으면 (빈 배열) nil이므로 if 블록 실행 안 함
                    //
                    // **Optional Binding이란?**
                    //
                    // logs.last는 Optional<LogEntry>를 반환합니다:
                    //   - 배열이 비어있으면 nil
                    //   - 항목이 있으면 Optional(마지막_항목)
                    //
                    // if let을 사용하면:
                    //   - nil이 아닐 때만 블록 실행
                    //   - lastLog는 언래핑된 값 (LogEntry 타입)
                    //
                    // 예시:
                    // ```swift
                    // // 로그가 있는 경우
                    // logs = [log1, log2, log3]
                    // logs.last = Optional(log3)
                    // if let lastLog = logs.last {  // 성공, lastLog = log3
                    //     // 이 블록 실행
                    // }
                    //
                    // // 로그가 없는 경우
                    // logs = []
                    // logs.last = nil
                    // if let lastLog = logs.last {  // 실패
                    //     // 이 블록 실행 안 됨
                    // }
                    // ```
                    //
                    if autoScroll, let lastLog = logManager.logs.last {
                        // **withAnimation으로 부드러운 스크롤:**
                        //
                        // withAnimation은 블록 내의 상태 변경을 애니메이션 처리합니다.
                        //
                        // withAnimation 없이:
                        // ```
                        // proxy.scrollTo(lastLog.id)
                        // // 즉시 점프 (딱딱한 움직임)
                        // ```
                        //
                        // withAnimation 있으면:
                        // ```
                        // withAnimation {
                        //     proxy.scrollTo(lastLog.id)
                        // }
                        // // 부드럽게 스크롤 (자연스러운 움직임)
                        // ```
                        //
                        // **scrollTo 메서드:**
                        //
                        // ```swift
                        // proxy.scrollTo(lastLog.id, anchor: .bottom)
                        // //             ~~~~~~~~~~~  ~~~~~~~~~~~~~
                        // //             타겟 ID      정렬 위치
                        // ```
                        //
                        // **anchor: .bottom의 의미:**
                        //
                        // anchor는 스크롤할 항목을 화면의 어디에 위치시킬지 결정합니다:
                        //
                        // .top: 항목을 화면 맨 위에 위치
                        // ```
                        // ┌──────────────┐
                        // │ [타겟 항목]  │ ← 여기에 위치
                        // │              │
                        // │              │
                        // └──────────────┘
                        // ```
                        //
                        // .bottom: 항목을 화면 맨 아래에 위치
                        // ```
                        // ┌──────────────┐
                        // │              │
                        // │              │
                        // │ [타겟 항목]  │ ← 여기에 위치
                        // └──────────────┘
                        // ```
                        //
                        // .center: 항목을 화면 중앙에 위치
                        // ```
                        // ┌──────────────┐
                        // │              │
                        // │ [타겟 항목]  │ ← 여기에 위치
                        // │              │
                        // └──────────────┘
                        // ```
                        //
                        // 로그 뷰어에서는 .bottom을 사용하는 이유:
                        //   - 채팅 앱처럼 새 항목이 아래에 추가됨
                        //   - 최신 로그가 항상 화면 아래쪽에 보임
                        //   - 자연스러운 읽기 흐름 (위→아래)
                        //
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .cornerRadius(8)
        .shadow(radius: 10)
    }
}

// MARK: - Log Entry Row

/// @struct LogEntryRow
/// @brief 개별 로그 엔트리 행 표시 컴포넌트
///
/// @details
/// 개별 로그 엔트리를 표시하는 서브뷰입니다.
///
/// **private struct를 사용하는 이유:**
///
/// ```swift
/// private struct LogEntryRow: View { ... }
/// //~~~~~~
/// ```
///
/// private 키워드는 이 struct가 현재 파일에서만 사용 가능함을 의미합니다:
///
/// ✓ 캡슐화 (Encapsulation)
///   → 외부 파일에서 접근 불가
///   → 내부 구현 세부사항 숨김
///
/// ✓ 네임스페이스 관리
///   → 다른 파일에 같은 이름의 struct가 있어도 충돌 안 함
///   → 명확한 사용 범위
///
/// ✓ 컴파일 최적화
///   → 컴파일러가 더 공격적으로 최적화 가능
///   → private이면 외부 사용이 없다는 것을 알기 때문
///
/// **언제 private struct를 만드는가?**
///
/// - 해당 View에서만 사용되는 서브뷰
/// - 다른 파일에서 재사용할 필요가 없을 때
/// - View를 작은 조각으로 분리하고 싶을 때
///
/// **예시:**
/// ```swift
/// // 파일 A
/// struct DebugLogView: View {
///     var body: some View {
///         LogEntryRow(entry: someEntry)  // ✓ 사용 가능
///     }
/// }
///
/// private struct LogEntryRow: View { ... }
///
/// // 파일 B
/// struct OtherView: View {
///     var body: some View {
///         LogEntryRow(entry: someEntry)  // ❌ 사용 불가 (private)
///     }
/// }
/// ```
///
private struct LogEntryRow: View {
    // MARK: - Properties

    /// @var entry
    /// @brief 표시할 로그 엔트리 데이터
    ///
    /// **let vs var:**
    ///
    /// let을 사용하는 이유:
    ///   - LogEntry는 한 번 받으면 변경되지 않음
    ///   - 불변성 (immutability) 보장
    ///   - 의도를 명확히 표현 ("이 값은 변하지 않는다")
    ///
    /// **LogEntry 구조:**
    /// ```swift
    /// struct LogEntry: Identifiable {
    ///     let id: UUID
    ///     let timestamp: Date
    ///     let level: LogLevel  // .debug, .info, .warning, .error
    ///     let message: String
    ///
    ///     var formattedMessage: String {
    ///         // "[14:23:05] [INFO] Application started"
    ///         return "[\(timeString)] [\(level)] \(message)"
    ///     }
    /// }
    /// ```
    ///
    let entry: LogEntry

    // MARK: - Body

    var body: some View {
        // **Text View:**
        //
        // 로그 메시지를 표시하는 텍스트 뷰입니다.
        //
        // entry.formattedMessage:
        //   - LogEntry의 computed property
        //   - 타임스탬프 + 레벨 + 메시지를 포맷팅
        //   - 예: "[14:23:05] [INFO] Application started"
        //
        Text(entry.formattedMessage)
            // **.font(.system(size:design:)):**
            //
            // 시스템 폰트의 세부 설정을 지정합니다.
            //
            // **size: 11**
            //   - 작은 폰트 크기 (기본은 ~17pt)
            //   - 로그는 많은 정보를 표시해야 하므로 작게
            //   - 너무 작으면 가독성 저하
            //
            // **design: .monospaced**
            //   - 고정폭 폰트 (Monospaced font)
            //   - 모든 문자가 같은 너비
            //   - 로그 정렬이 깔끔하게 맞음
            //
            // **Monospaced vs Proportional 비교:**
            //
            // Proportional (일반 폰트):
            // ```
            // [14:23:05] [INFO   ] Message 1
            // [14:23:06] [WARNING] Message 2
            // [14:23:07] [ERROR  ] Message 3
            // //        ~~~~~~~~~ 정렬 안 맞음
            // ```
            //
            // Monospaced (고정폭 폰트):
            // ```
            // [14:23:05] [INFO   ] Message 1
            // [14:23:06] [WARNING] Message 2
            // [14:23:07] [ERROR  ] Message 3
            // //        ~~~~~~~~~ 정렬 맞음
            // ```
            //
            // **왜 로그에 Monospaced 폰트를 사용하는가?**
            //
            // ✓ 정렬 (Alignment)
            //   → 타임스탬프, 레벨, 메시지가 세로로 깔끔하게 정렬
            //
            // ✓ 가독성 (Readability)
            //   → 패턴을 쉽게 인식 가능
            //   → 숫자, 코드가 명확하게 보임
            //
            // ✓ 개발자 친화적
            //   → 대부분의 IDE와 터미널에서 사용
            //   → 익숙한 스타일
            //
            .font(.system(size: 11, design: .monospaced))

            // **.foregroundColor(textColor):**
            //
            // 텍스트 색상을 로그 레벨에 따라 설정합니다.
            //
            // textColor는 아래의 computed property에서 결정됩니다.
            //
            .foregroundColor(textColor)

            // **.textSelection(.enabled):**
            //
            // 사용자가 텍스트를 선택(복사)할 수 있게 합니다.
            //
            // **왜 필요한가?**
            //
            // 로그를 복사해야 하는 경우가 많습니다:
            //   - 버그 리포트에 붙여넣기
            //   - Slack/이메일로 공유
            //   - 외부 도구로 분석
            //
            // .enabled 없이:
            //   - 텍스트를 드래그해도 선택 안 됨
            //   - 복사 불가능
            //
            // .enabled 있으면:
            //   - 마우스 드래그로 선택 가능
            //   - Cmd+C로 복사 가능
            //
            .textSelection(.enabled)
    }

    // MARK: - Computed Properties

    /// Text color based on log level
    ///
    /// 로그 레벨에 따른 텍스트 색상을 반환합니다.
    ///
    /// **Computed Property란?**
    ///
    /// ```swift
    /// private var textColor: Color {
    ///     // 저장하지 않고 계산만 함
    ///     return someColor
    /// }
    /// ```
    ///
    /// Computed property는 값을 저장하지 않고, 요청될 때마다 계산합니다.
    ///
    /// **Stored Property vs Computed Property:**
    ///
    /// Stored Property:
    /// ```swift
    /// let entry: LogEntry  // 메모리에 저장됨
    /// ```
    ///
    /// Computed Property:
    /// ```swift
    /// var textColor: Color {  // 매번 계산됨
    ///     switch entry.level { ... }
    /// }
    /// ```
    ///
    /// **왜 Computed Property를 사용하는가?**
    ///
    /// ✓ 중복 저장 방지
    ///   → entry.level에서 이미 정보 있음
    ///   → 색상을 따로 저장할 필요 없음
    ///
    /// ✓ 동기화 보장
    ///   → entry.level이 변경되면 색상도 자동으로 변경
    ///   → 불일치 문제 없음
    ///
    /// ✓ 메모리 효율
    ///   → 색상 값을 저장하지 않음
    ///   → 계산 비용이 낮음 (단순 switch문)
    ///
    /// **로그 레벨별 색상 디자인:**
    ///
    /// 색상은 정보의 중요도와 긴급성을 시각적으로 전달합니다:
    ///
    /// .debug → .gray (회색)
    ///   - 상세한 디버그 정보
    ///   - 덜 중요함
    ///   - 배경에 섞이도록
    ///
    /// .info → .white (흰색)
    ///   - 일반적인 정보성 메시지
    ///   - 중간 중요도
    ///   - 명확하게 보임
    ///
    /// .warning → .yellow (노란색)
    ///   - 경고 메시지
    ///   - 주의 필요
    ///   - 눈에 띄지만 긴급하지는 않음
    ///
    /// .error → .red (빨간색)
    ///   - 오류 메시지
    ///   - 즉시 확인 필요
    ///   - 강하게 눈에 띔
    ///
    /// **색상 선택의 원칙:**
    ///
    /// 1. 직관성 (Intuitiveness)
    ///    - 빨강 = 위험, 노랑 = 주의 (보편적 인식)
    ///
    /// 2. 대비 (Contrast)
    ///    - 검은 배경에서 잘 보이는 색상
    ///
    /// 3. 구분성 (Distinctiveness)
    ///    - 각 색상이 명확히 구별됨
    ///
    /// 4. 접근성 (Accessibility)
    ///    - 색맹 사용자도 구분 가능 (밝기 차이)
    ///
    private var textColor: Color {
        switch entry.level {
        case .debug:
            return .gray
        case .info:
            return .white
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

/// SwiftUI Preview
///
/// Xcode의 Canvas에서 DebugLogView를 미리 볼 수 있게 해주는 프리뷰입니다.
///
/// **PreviewProvider란?**
///
/// PreviewProvider는 SwiftUI의 프리뷰 기능을 제공하는 프로토콜입니다.
///
/// 프리뷰의 장점:
///   ✓ 실시간 미리보기 - 코드 변경 시 즉시 반영
///   ✓ 빠른 반복 - 앱 전체를 빌드하지 않아도 UI 확인
///   ✓ 다양한 환경 테스트 - 다크 모드, 다른 기기 크기 등
///
/// **Preview 작동 방식:**
///
/// ```
/// 1. Xcode가 코드 감지
///    ↓
/// 2. PreviewProvider의 previews 프로퍼티 실행
///    ↓
/// 3. 반환된 View를 Canvas에 렌더링
///    ↓
/// 4. 코드 변경 감지하면 자동 재렌더링
/// ```
///
/// **이 Preview의 구성:**
///
/// ```
/// ZStack {
///     Color.blue          ← 배경 (파란색, 앱의 메인 UI 시뮬레이션)
///     VStack {
///         Spacer()        ← 위쪽 공간 (DebugLogView를 아래로 밀기)
///         DebugLogView()  ← 테스트할 View
///     }
/// }
/// ```
///
/// **ZStack의 역할:**
///
/// ZStack은 View를 Z축(깊이)으로 쌓습니다:
/// ```
/// Z축 (앞 ← 뒤)
/// DebugLogView (앞)
///     ↓
/// Color.blue (뒤)
/// ```
///
/// 실제 사용 환경을 시뮬레이션:
///   - 파란색 배경 = 메인 앱 화면
///   - DebugLogView = 그 위에 오버레이
///
/// **VStack + Spacer의 역할:**
///
/// VStack 내부:
/// ```
/// ┌──────────────────┐
/// │                  │
/// │     Spacer()     │ ← 가능한 모든 공간 차지
/// │                  │
/// ├──────────────────┤
/// │  DebugLogView()  │ ← 맨 아래에 위치
/// └──────────────────┘
/// ```
///
/// 결과: DebugLogView가 화면 하단에 고정됨
///
/// **onAppear 모디파이어:**
///
/// onAppear는 View가 화면에 나타날 때 실행되는 클로저입니다.
///
/// ```swift
/// .onAppear {
///     // View가 나타나면 실행
/// }
/// ```
///
/// **이 Preview에서 onAppear를 사용하는 이유:**
///
/// LogManager에 샘플 로그를 추가하기 위해:
///   - 프리뷰가 로드되면
///   - 자동으로 4개의 샘플 로그 추가
///   - DebugLogView에 로그가 표시됨
///
/// 샘플 로그가 없으면:
///   - 빈 화면만 보임
///   - UI가 제대로 작동하는지 확인 불가
///
/// 샘플 로그가 있으면:
///   - 각 로그 레벨의 색상 확인
///   - 레이아웃 확인
///   - 스크롤 기능 테스트
///
/// **4개의 샘플 로그:**
///
/// 1. .info - "Application started"
///    → 흰색, 일반 시작 메시지
///
/// 2. .debug - "Loading video file: test.mp4"
///    → 회색, 디버그 정보
///
/// 3. .warning - "Warning: Low buffer detected"
///    → 노란색, 경고 메시지
///
/// 4. .error - "Error: Failed to decode frame"
///    → 빨간색, 오류 메시지
///
/// 이렇게 모든 레벨을 포함하면 색상 구분이 잘 되는지 확인 가능합니다.
///
struct DebugLogView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue
            VStack {
                Spacer()
                DebugLogView()
                    .padding()
            }
        }
        .onAppear {
            LogManager.shared.log("Application started", level: .info)
            LogManager.shared.log("Loading video file: test.mp4", level: .debug)
            LogManager.shared.log("Warning: Low buffer detected", level: .warning)
            LogManager.shared.log("Error: Failed to decode frame", level: .error)
        }
    }
}
