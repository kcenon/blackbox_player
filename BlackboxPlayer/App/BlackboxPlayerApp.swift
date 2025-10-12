/**
 * @file BlackboxPlayerApp.swift
 * @brief macOS용 블랙박스 비디오 플레이어 애플리케이션의 진입점
 * @author BlackboxPlayer Team
 * @details
 * BlackboxPlayer 앱의 진입점(Entry Point)이자 최상위 구조를 정의하는 파일입니다.
 * SwiftUI의 App 프로토콜을 채택하여 앱의 생명주기를 관리하고, 메인 윈도우 및
 * 메뉴 시스템을 구성합니다.
 *
 * @section app_structure 앱 구조
 * - @main 어노테이션으로 프로그램 진입점 지정
 * - WindowGroup을 통한 메인 윈도우 구성
 * - Commands modifier를 통한 메뉴 커스터마이징
 * - 키보드 단축키 정의
 *
 * @section ui_components UI 구성요소
 * - hiddenTitleBar 스타일로 타이틀 바 숨김
 * - File, View, Playback, Help 메뉴 커스터마이징
 * - 다중 윈도우 지원 (Cmd+N)
 *
 * @section keyboard_shortcuts 주요 키보드 단축키
 * - ⌘O: 폴더 열기
 * - ⌘R: 파일 목록 새로고침
 * - ⌘1/2/3: 오버레이 토글
 * - Space: 재생/일시정지
 * - ⌘←/→: 프레임 단위 이동
 * - ⌘[/]: 재생 속도 조절
 *
 * @note SwiftUI의 App 프로토콜을 채택하여 선언적 방식으로 앱 구조를 정의합니다.
 * @note UIKit의 AppDelegate/SceneDelegate 구조를 단일 파일로 통합한 현대적 접근 방식입니다.
 *
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║                        BlackboxPlayer App Entry Point                        ║
 * ║                    SwiftUI 앱의 진입점 및 생명주기 관리                          ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝

 📚 이 파일의 목적
 ════════════════════════════════════════════════════════════════════════════════
 BlackboxPlayer 앱의 진입점(Entry Point)이자 최상위 구조를 정의하는 파일입니다.

 SwiftUI의 App 프로토콜을 채택하여 앱의 생명주기를 관리하고, 메인 윈도우 및
 메뉴 시스템을 구성합니다.

 📌 주요 역할:
    1) 앱 시작점 정의 (@main 어노테이션)
    2) 메인 윈도우 구성 (WindowGroup)
    3) 메뉴 커스터마이징 (Commands)
    4) 키보드 단축키 정의


 🚀 @main 어노테이션이란?
 ════════════════════════════════════════════════════════════════════════════════
 Swift의 @main 어노테이션은 프로그램의 진입점(Entry Point)을 표시합니다.

 📌 기본 개념:
    모든 실행 가능한 프로그램은 시작점이 필요합니다.
    C/C++의 main() 함수처럼, Swift도 어디서 시작할지 지정해야 합니다.

 📌 @main의 역할:
    • 이 타입을 앱의 시작점으로 지정
    • 시스템이 앱을 실행하면 이 타입의 인스턴스를 생성
    • App 프로토콜을 채택한 타입에만 사용 가능
    • 프로젝트 전체에 단 하나만 존재해야 함

 📌 UIKit과의 비교:
    UIKit 시대 (복잡):
    - AppDelegate.swift (앱 생명주기)
    - SceneDelegate.swift (화면 생명주기)
    - main.swift 또는 @UIApplicationMain
    → 3개 파일로 분산된 구조

    SwiftUI 시대 (단순):
    - @main 어노테이션 하나로 통합
    - 선언적(Declarative) 방식
    → 1개 파일로 완결


 📱 App 프로토콜이란?
 ════════════════════════════════════════════════════════════════════════════════
 SwiftUI의 App 프로토콜은 앱의 구조와 동작을 정의합니다.

 📌 필수 요구사항:
    protocol App {
        associatedtype Body: Scene
        var body: Self.Body { get }
    }

    • body 프로퍼티 구현 필수
    • body는 Scene 타입을 반환 (View가 아님!)
    • Scene은 앱의 UI 계층 구조를 나타냄

 📌 App vs View:
    App (최상위):
    - 앱 전체의 구조 정의
    - Scene들의 컨테이너
    - 생명주기 관리

    Scene (중간):
    - WindowGroup, DocumentGroup 등
    - 플랫폼별 창/화면 단위

    View (하위):
    - UI 컴포넌트
    - Button, Text, ContentView 등


 🪟 Scene과 WindowGroup이란?
 ════════════════════════════════════════════════════════════════════════════════
 Scene은 앱의 사용자 인터페이스 인스턴스를 나타냅니다.

 📌 Scene의 종류:
    1) WindowGroup
       - 하나 이상의 윈도우를 관리
       - macOS: 여러 윈도우 인스턴스 가능 (Cmd+N으로 새 윈도우)
       - iOS/iPadOS: 멀티 윈도우 지원 (iPadOS)

    2) DocumentGroup
       - 문서 기반 앱 (예: Pages, Keynote)
       - 파일 시스템 통합

    3) Settings (macOS only)
       - 설정 윈도우 전용

 📌 WindowGroup의 특징:
    • 동일한 View 계층을 여러 윈도우로 표시
    • macOS: Cmd+N으로 새 윈도우 생성 가능
    • 각 윈도우는 독립적인 상태 유지 가능
    • 자동으로 Window 메뉴 항목 추가

 📌 이 프로젝트의 WindowGroup:
    WindowGroup { ContentView() }
    → ContentView를 루트로 하는 윈도우 생성
    → 사용자가 여러 블랙박스 영상을 동시에 볼 수 있도록 다중 윈도우 지원


 🎨 windowStyle Modifier란?
 ════════════════════════════════════════════════════════════════════════════════
 windowStyle은 윈도우의 외형을 커스터마이징하는 modifier입니다.

 📌 .hiddenTitleBar:
    • 타이틀 바(제목 표시줄)를 숨김
    • 더 넓은 콘텐츠 영역 확보
    • 현대적이고 미니멀한 디자인
    • 닫기/최소화/최대화 버튼은 유지

 📌 다른 windowStyle 옵션:
    • .automatic: 기본 스타일 (타이틀 바 표시)
    • .titleBar: 명시적으로 타이틀 바 표시
    • .hiddenTitleBar: 타이틀 바 숨김

 📌 왜 hiddenTitleBar를 사용하나요?
    블랙박스 영상 플레이어는 영상 콘텐츠가 주요 초점이므로
    타이틀 바를 숨겨 화면 공간을 최대한 활용합니다.
    (YouTube, Netflix 같은 비디오 플레이어와 유사한 UX)


 ⌨️ Commands 시스템이란?
 ════════════════════════════════════════════════════════════════════════════════
 Commands는 macOS 메뉴 바의 메뉴 항목을 커스터마이징하는 시스템입니다.

 📌 기본 개념:
    SwiftUI는 기본 메뉴를 자동으로 생성하지만, Commands를 통해
    메뉴를 추가/수정/대체할 수 있습니다.

 📌 Commands의 종류:

    1) CommandGroup(replacing:)
       - 기존 메뉴 그룹을 완전히 대체
       - .newItem, .appInfo 등 표준 그룹 대체 가능

    2) CommandGroup(after:) / CommandGroup(before:)
       - 기존 메뉴 그룹 앞/뒤에 새 항목 추가
       - .sidebar, .toolbar 등 기준점 지정

    3) CommandMenu("이름")
       - 완전히 새로운 메뉴 생성
       - 메뉴 바에 새 탭 추가

 📌 표준 CommandGroupPlacement:
    • .newItem: File > New
    • .saveItem: File > Save
    • .sidebar: View > Sidebar 관련
    • .toolbar: View > Toolbar 관련
    • .appInfo: App > About


 🎮 이 프로젝트의 메뉴 구조
 ════════════════════════════════════════════════════════════════════════════════

 1. File 메뉴 (CommandGroup replacing .newItem)
    - Open Folder... (⌘O): 블랙박스 영상 폴더 열기
    - Refresh File List (⌘R): 파일 목록 새로고침

 2. View 메뉴 (CommandGroup after .sidebar)
    - Toggle Sidebar (⌥⌘S): 사이드바 표시/숨김
    - Toggle Metadata Overlay (⌘1): 메타데이터 오버레이
    - Toggle Map Overlay (⌘2): GPS 지도 오버레이
    - Toggle Graph Overlay (⌘3): G-센서 그래프 오버레이

 3. Playback 메뉴 (새로운 CommandMenu)
    - Play/Pause (Space): 재생/일시정지
    - Step Forward (⌘→): 프레임 단위 앞으로
    - Step Backward (⌘←): 프레임 단위 뒤로
    - Increase Speed (⌘]): 재생 속도 증가
    - Decrease Speed (⌘[): 재생 속도 감소
    - Normal Speed (⌘0): 정상 속도로 복귀

 4. Help 메뉴 (CommandGroup replacing .appInfo)
    - About BlackboxPlayer: 앱 정보 표시
    - BlackboxPlayer Help (⌘?): 도움말 표시


 ⌨️ keyboardShortcut Modifier란?
 ════════════════════════════════════════════════════════════════════════════════
 키보드 단축키를 Button이나 메뉴 항목에 할당하는 modifier입니다.

 📌 사용 방법:
    .keyboardShortcut(key, modifiers: [modifiers])

    • key: KeyEquivalent 타입 (문자, 화살표 등)
    • modifiers: EventModifiers (command, option, shift, control)

 📌 KeyEquivalent 종류:
    1) 문자: "o", "r", "s", "0", "1", "2", "3"
    2) 기호: "[", "]", "?", "/"
    3) 특수키: .space, .escape, .return, .delete
    4) 화살표: .leftArrow, .rightArrow, .upArrow, .downArrow

 📌 EventModifiers 조합:
    • .command (⌘): Command 키
    • .option (⌥): Option(Alt) 키
    • .shift (⇧): Shift 키
    • .control (⌃): Control 키
    • 배열로 조합 가능: [.command, .option]

 📌 이 프로젝트의 단축키 철학:
    • ⌘O: Open (표준 macOS 관례)
    • ⌘R: Refresh (표준 macOS 관례)
    • ⌘1/2/3: 오버레이 토글 (숫자 키로 빠른 전환)
    • Space: 재생/일시정지 (비디오 플레이어 표준)
    • ⌘←/→: 프레임 이동 (타임라인 탐색)
    • ⌘[/]: 속도 조절 (대괄호로 증감)


 💡 TODO 항목에 대하여
 ════════════════════════════════════════════════════════════════════════════════
 현재 모든 버튼 액션에 TODO 주석이 있습니다.

 📌 TODO의 의미:
    이 파일은 앱의 구조(Structure)를 정의하는 역할만 합니다.
    실제 기능 구현은 별도의 ViewModel이나 Service에서 처리됩니다.

 📌 향후 구현 방향:
    1) ViewModel 또는 AppState 생성
       @StateObject var appState = AppState()

    2) 환경 객체로 전달
       .environmentObject(appState)

    3) 버튼 액션에서 호출
       Button("Open Folder...") {
           appState.openFolderPicker()
       }

 📌 SwiftUI 아키텍처 패턴:
    App (구조 정의)
      → Scene (윈도우 관리)
        → View (UI 표현)
          → ViewModel (비즈니스 로직)
            → Service (데이터/기능)

    이 파일은 최상위 "구조 정의" 역할만 수행하며,
    세부 기능은 하위 계층에서 구현됩니다.


 ═══════════════════════════════════════════════════════════════════════════════
 */

import SwiftUI

// MARK: - App Entry Point

/**
 * @class BlackboxPlayerApp
 * @brief BlackboxPlayer 앱의 메인 진입점 구조체
 * @details
 * SwiftUI의 App 프로토콜을 채택하여 앱의 생명주기와 메인 UI를 관리합니다.
 *
 * @note @main 어노테이션
 * - 이 타입을 프로그램의 시작점으로 지정
 * - 시스템이 BlackboxPlayerApp 인스턴스를 생성
 * - body 프로퍼티를 평가하여 Scene 구성
 * - Scene에 정의된 WindowGroup으로 메인 윈도우 표시
 * - 전체 프로젝트에 @main은 단 하나만 존재해야 함
 *
 * @par 실행 순서:
 * 1. 시스템이 BlackboxPlayerApp 인스턴스 생성
 * 2. body 프로퍼티 평가
 * 3. WindowGroup으로 메인 윈도우 표시
 *
 * 📌 초보자를 위한 @main 설명
 * ─────────────────────────────────────────────────────────────────
 * @main 어노테이션은 이 타입을 프로그램의 시작점으로 지정합니다.
 *
 * 앱이 실행되면:
 * 1) 시스템이 BlackboxPlayerApp의 인스턴스를 생성
 * 2) body 프로퍼티를 평가하여 Scene 구성
 * 3) Scene에 정의된 WindowGroup으로 메인 윈도우 표시
 *
 * 전체 프로젝트에 @main은 단 하나만 있어야 합니다.
 */
@main
struct BlackboxPlayerApp: App {

    // MARK: Scene Configuration

    /**
     * @var body
     * @brief 앱의 Scene 구성을 정의하는 프로퍼티
     * @return WindowGroup과 Commands로 구성된 Scene
     * @details
     * App 프로토콜의 필수 요구사항인 body 프로퍼티입니다.
     *
     * @par Scene 구조:
     * - WindowGroup: 메인 윈도우 그룹 정의
     *   - ContentView()를 루트 뷰로 사용
     *   - macOS에서 여러 윈도우 인스턴스 생성 가능 (Cmd+N)
     * - .windowStyle(.hiddenTitleBar): 타이틀 바 숨김
     *   - 영상 콘텐츠에 집중할 수 있도록 화면 공간 최대화
     *   - 닫기/최소화/최대화 버튼은 유지
     * - .commands: 메뉴 커스터마이징
     *   - File, View, Playback, Help 메뉴 정의
     *   - 키보드 단축키 할당
     *
     * @note body는 "some Scene" 타입을 반환
     * @note some은 Swift 5.1+ Opaque Type
     * @note Scene은 앱의 UI 계층 구조를 나타내는 프로토콜
     */
    /// 앱의 Scene 구성
    ///
    /// 📌 초보자를 위한 body 설명
    /// ─────────────────────────────────────────────────────────────────
    /// App 프로토콜의 필수 요구사항인 body 프로퍼티입니다.
    ///
    /// body는 "some Scene" 타입을 반환합니다:
    /// • some: Opaque Type (Swift 5.1+)
    /// • Scene: 앱의 UI 계층 구조를 나타내는 프로토콜
    ///
    /// WindowGroup, DocumentGroup 등이 Scene을 채택합니다.
    ///
    ///
    /// 🏗️ Scene 구조 설명
    /// ─────────────────────────────────────────────────────────────────
    /// 1) WindowGroup: 메인 윈도우 그룹 정의
    ///    - ContentView()를 루트 뷰로 사용
    ///    - macOS에서 여러 윈도우 인스턴스 생성 가능 (Cmd+N)
    ///
    /// 2) .windowStyle(.hiddenTitleBar): 타이틀 바 숨김
    ///    - 영상 콘텐츠에 집중할 수 있도록 화면 공간 최대화
    ///    - 닫기/최소화/최대화 버튼은 유지
    ///
    /// 3) .commands: 메뉴 커스터마이징
    ///    - macOS 메뉴 바의 메뉴 항목 추가/수정
    ///    - File, View, Playback, Help 메뉴 정의
    ///
    var body: some Scene {
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // WindowGroup: 메인 윈도우 정의
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // 📌 WindowGroup이란?
        //    SwiftUI의 Scene 타입 중 하나로, 하나 이상의 윈도우를 관리합니다.
        //
        // 📌 동작 방식:
        //    macOS에서 사용자가 File > New Window (Cmd+N)을 선택하면
        //    WindowGroup이 ContentView()의 새 인스턴스를 가진 윈도우를 생성합니다.
        //
        // 📌 ContentView():
        //    앱의 메인 UI를 정의하는 루트 뷰입니다.
        //    이 뷰가 전체 UI 계층 구조의 시작점이 됩니다.
        //
        // 📌 왜 클로저(trailing closure) 문법을 사용하나요?
        //    WindowGroup의 생성자는 @ViewBuilder를 받습니다:
        //    WindowGroup(@ViewBuilder content: () -> Content)
        //
        //    클로저 내부에서 View를 선언적으로 구성할 수 있습니다.
        //
        WindowGroup {
            ContentView()
        }
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Window Style: 타이틀 바 숨김
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // 📌 .hiddenTitleBar의 효과:
        //    • 윈도우 상단의 타이틀 바 제거
        //    • 콘텐츠 영역이 윈도우 전체를 차지
        //    • 트래픽 라이트 버튼(닫기/최소화/최대화)은 유지
        //
        // 📌 사용 이유:
        //    블랙박스 영상 플레이어는 영상이 주요 콘텐츠이므로
        //    타이틀 바 영역을 콘텐츠에 할애하여 몰입감 증대
        //
        // 📌 대안:
        //    .windowStyle(.titleBar) → 타이틀 바 표시 (기본값)
        //    .windowStyle(.automatic) → 시스템 기본 스타일
        //
        .windowStyle(.hiddenTitleBar)

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Commands: 메뉴 커스터마이징
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // 📌 .commands modifier란?
        //    macOS 메뉴 바의 메뉴 항목을 커스터마이징하는 modifier입니다.
        //
        // 📌 @CommandsBuilder:
        //    .commands { } 클로저는 @CommandsBuilder를 받습니다.
        //    여러 CommandGroup과 CommandMenu를 선언적으로 구성할 수 있습니다.
        //
        // 📌 메뉴 구성 방식:
        //    1) CommandGroup(replacing:) - 기존 메뉴 대체
        //    2) CommandGroup(after/before:) - 기존 메뉴에 항목 추가
        //    3) CommandMenu("이름") - 새 메뉴 생성
        //
        .commands {

            // ═══════════════════════════════════════════════════════════════
            // File 메뉴 커스터마이징
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandGroup(replacing: .newItem):
            //    기본 "File > New" 메뉴 그룹을 완전히 대체합니다.
            //
            // 📌 왜 대체하나요?
            //    블랙박스 플레이어는 "새 문서" 개념이 없으므로
            //    대신 "폴더 열기"와 "새로고침" 기능을 제공합니다.
            //
            // 📌 .newItem이란?
            //    CommandGroupPlacement.newItem은 표준 macOS 메뉴 위치입니다.
            //    보통 File 메뉴의 첫 번째 그룹에 위치합니다.
            //
            CommandGroup(replacing: .newItem) {

                // ───────────────────────────────────────────────────────────
                // Open Folder 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Open Folder..."):
                //    메뉴 항목으로 표시될 버튼입니다.
                //    "..." 표기는 macOS 관례로, "추가 대화상자가 열림"을 의미합니다.
                //
                // 📌 TODO: Open folder picker
                //    향후 NSOpenPanel을 사용하여 폴더 선택 대화상자를 구현할 예정
                //
                // 📌 구현 예시 (향후):
                //    let panel = NSOpenPanel()
                //    panel.canChooseFiles = false
                //    panel.canChooseDirectories = true
                //    panel.begin { response in ... }
                //
                Button("Open Folder...") {
                    // TODO: Open folder picker
                    // 폴더 선택 대화상자(NSOpenPanel)를 표시하여
                    // 사용자가 블랙박스 영상 폴더를 선택할 수 있도록 구현 예정
                }
                // 📌 .keyboardShortcut("o", modifiers: .command):
                //    Command+O (⌘O) 단축키 할당
                //
                //    "o"는 KeyEquivalent 타입으로, 문자 "o"를 나타냅니다.
                //    .command는 EventModifiers로, Command(⌘) 키를 의미합니다.
                //
                //    ⌘O는 macOS 표준 "Open" 단축키입니다.
                //    (Finder, Safari, TextEdit 등 모든 앱에서 사용)
                //
                .keyboardShortcut("o", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Divider: 메뉴 구분선
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Divider():
                //    메뉴 항목 사이에 시각적 구분선을 추가합니다.
                //    관련 항목을 그룹화하여 가독성을 높입니다.
                //
                // 📌 macOS 메뉴 디자인 가이드라인:
                //    의미상 다른 기능은 Divider로 구분하는 것이 권장됩니다.
                //    (Open과 Refresh는 다른 작업이므로 구분선 사용)
                //
                Divider()

                // ───────────────────────────────────────────────────────────
                // Refresh File List 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Refresh File List"):
                //    현재 열린 폴더의 파일 목록을 새로고침합니다.
                //
                // 📌 TODO: Refresh files
                //    FileSystemService를 호출하여 파일 목록을 다시 스캔할 예정
                //
                // 📌 구현 예시 (향후):
                //    await fileSystemService.refreshFiles()
                //    await videoLibrary.reload()
                //
                Button("Refresh File List") {
                    // TODO: Refresh files
                    // 파일 시스템 서비스를 통해 블랙박스 영상 목록을
                    // 다시 스캔하여 UI를 업데이트할 예정
                }
                // 📌 .keyboardShortcut("r", modifiers: .command):
                //    Command+R (⌘R) 단축키 할당
                //
                //    ⌘R은 macOS에서 "Refresh/Reload"의 표준 단축키입니다.
                //    (Safari 새로고침, Xcode 빌드 등에서 사용)
                //
                .keyboardShortcut("r", modifiers: .command)
            }

            // ═══════════════════════════════════════════════════════════════
            // View 메뉴 항목 추가
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandGroup(after: .sidebar):
            //    기본 "View > Sidebar" 그룹 뒤에 새 항목들을 추가합니다.
            //
            // 📌 .sidebar란?
            //    CommandGroupPlacement.sidebar는 View 메뉴의 사이드바 관련
            //    항목이 위치하는 표준 위치입니다.
            //
            // 📌 왜 after를 사용하나요?
            //    기존 "Hide/Show Sidebar" 항목을 유지하면서
            //    블랙박스 플레이어 전용 뷰 옵션을 추가로 제공합니다.
            //
            CommandGroup(after: .sidebar) {

                // ───────────────────────────────────────────────────────────
                // Toggle Sidebar 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Sidebar"):
                //    사이드바(파일 목록)의 표시/숨김을 전환합니다.
                //
                // 📌 TODO: Toggle sidebar
                //    NavigationSplitView의 columnVisibility를 토글할 예정
                //
                // 📌 구현 예시 (향후):
                //    @State var sidebarVisibility: NavigationSplitViewVisibility
                //    sidebarVisibility = sidebarVisibility == .all ? .detailOnly : .all
                //
                Button("Toggle Sidebar") {
                    // TODO: Toggle sidebar
                    // NavigationSplitView의 사이드바 가시성을 토글하여
                    // 파일 목록 패널을 표시하거나 숨길 예정
                }
                // 📌 .keyboardShortcut("s", modifiers: [.command, .option]):
                //    Option+Command+S (⌥⌘S) 단축키 할당
                //
                //    modifiers 배열에 여러 modifier를 조합할 수 있습니다.
                //    [.command, .option]은 두 키를 동시에 누르는 것을 의미합니다.
                //
                //    ⌥⌘S는 많은 macOS 앱에서 사이드바 토글에 사용됩니다.
                //    (Xcode, Finder 등)
                //
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                // ───────────────────────────────────────────────────────────
                // Toggle Metadata Overlay 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Metadata Overlay"):
                //    영상 위에 메타데이터 오버레이를 표시/숨김합니다.
                //
                // 📌 메타데이터 오버레이란?
                //    영상 재생 중 다음 정보를 화면에 표시:
                //    - 현재 시간
                //    - GPS 좌표
                //    - 속도
                //    - G-센서 값
                //
                // 📌 TODO: Toggle metadata
                //    @State var showMetadata: Bool 변수를 토글할 예정
                //
                Button("Toggle Metadata Overlay") {
                    // TODO: Toggle metadata
                    // 영상 플레이어 위에 메타데이터 정보
                    // (시간, GPS, 속도, G-센서)를 오버레이로 표시/숨김
                }
                // 📌 .keyboardShortcut("1", modifiers: .command):
                //    Command+1 (⌘1) 단축키 할당
                //
                //    숫자 키(1, 2, 3)를 사용하여 다양한 오버레이를 빠르게 전환합니다.
                //    숫자 순서가 우선순위를 나타냅니다 (1=메타데이터, 2=지도, 3=그래프)
                //
                .keyboardShortcut("1", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Toggle Map Overlay 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Map Overlay"):
                //    GPS 데이터를 기반으로 한 지도 오버레이를 표시/숨김합니다.
                //
                // 📌 지도 오버레이란?
                //    영상 재생 중 현재 위치를 지도에 표시:
                //    - 이동 경로 (path)
                //    - 현재 위치 마커
                //    - 축적 및 방향
                //
                // 📌 TODO: Toggle map
                //    MapKit 뷰를 표시/숨김하는 기능 구현 예정
                //
                Button("Toggle Map Overlay") {
                    // TODO: Toggle map
                    // GPS 데이터를 시각화하는 MapKit 뷰를
                    // 영상 위에 오버레이로 표시/숨김
                }
                .keyboardShortcut("2", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Toggle Graph Overlay 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Graph Overlay"):
                //    G-센서 데이터를 그래프로 표시/숨김합니다.
                //
                // 📌 그래프 오버레이란?
                //    G-센서(가속도) 데이터를 시간별로 시각화:
                //    - X, Y, Z축 가속도 그래프
                //    - 충격 이벤트 표시
                //    - 실시간 동기화
                //
                // 📌 TODO: Toggle graph
                //    Charts 프레임워크를 사용한 그래프 뷰 표시/숨김 예정
                //
                Button("Toggle Graph Overlay") {
                    // TODO: Toggle graph
                    // G-센서 데이터를 시각화하는 Charts 뷰를
                    // 영상 위에 오버레이로 표시/숨김
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            // ═══════════════════════════════════════════════════════════════
            // Playback 메뉴 생성 (새 메뉴)
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandMenu("Playback"):
            //    "Playback"이라는 이름의 새 메뉴를 메뉴 바에 추가합니다.
            //
            // 📌 위치:
            //    메뉴 바에서 Help 메뉴 바로 앞에 위치합니다.
            //    (App, File, Edit, View, Playback, Window, Help 순서)
            //
            // 📌 왜 새 메뉴를 만들었나요?
            //    영상 재생 관련 기능은 블랙박스 플레이어의 핵심 기능이므로
            //    별도 메뉴로 분리하여 접근성을 높였습니다.
            //
            CommandMenu("Playback") {

                // ───────────────────────────────────────────────────────────
                // Play/Pause 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Play/Pause"):
                //    영상 재생/일시정지를 토글합니다.
                //
                // 📌 TODO: Play/pause
                //    VideoPlayerService의 togglePlayPause() 메서드 호출 예정
                //
                // 📌 구현 예시 (향후):
                //    if videoPlayer.isPlaying {
                //        videoPlayer.pause()
                //    } else {
                //        videoPlayer.play()
                //    }
                //
                Button("Play/Pause") {
                    // TODO: Play/pause
                    // 비디오 플레이어의 재생/일시정지 상태를 토글
                }
                // 📌 .keyboardShortcut(.space):
                //    Space 키 단축키 할당
                //
                //    .space는 KeyEquivalent.space의 축약형입니다.
                //    modifier 없이 Space 키만으로 동작합니다.
                //
                //    Space는 모든 비디오 플레이어의 표준 재생/일시정지 단축키입니다.
                //    (YouTube, QuickTime, VLC 등)
                //
                .keyboardShortcut(.space)

                Divider()

                // ───────────────────────────────────────────────────────────
                // Step Forward 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Step Forward"):
                //    영상을 한 프레임씩 앞으로 이동합니다.
                //
                // 📌 프레임 단위 이동이란?
                //    1/30초 또는 1/60초 단위로 정밀하게 영상을 탐색합니다.
                //    충격 순간을 정확히 분석하는 데 유용합니다.
                //
                // 📌 TODO: Step forward
                //    현재 재생 위치에서 정확히 1프레임 앞으로 이동할 예정
                //
                Button("Step Forward") {
                    // TODO: Step forward
                    // 현재 재생 위치에서 1프레임(1/frameRate 초) 앞으로 이동
                }
                // 📌 .keyboardShortcut(.rightArrow, modifiers: .command):
                //    Command+→ (⌘→) 단축키 할당
                //
                //    .rightArrow는 KeyEquivalent.rightArrow입니다.
                //    오른쪽 화살표 키와 Command를 함께 누릅니다.
                //
                //    화살표 키를 사용한 탐색은 비디오 편집 도구의 표준입니다.
                //    (Final Cut Pro, Adobe Premiere 등)
                //
                .keyboardShortcut(.rightArrow, modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Step Backward 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Step Backward"):
                //    영상을 한 프레임씩 뒤로 이동합니다.
                //
                // 📌 TODO: Step backward
                //    현재 재생 위치에서 정확히 1프레임 뒤로 이동할 예정
                //
                Button("Step Backward") {
                    // TODO: Step backward
                    // 현재 재생 위치에서 1프레임(1/frameRate 초) 뒤로 이동
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                // ───────────────────────────────────────────────────────────
                // Increase Speed 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Increase Speed"):
                //    재생 속도를 증가시킵니다 (예: 1x → 1.5x → 2x → 4x).
                //
                // 📌 재생 속도 조절의 용도:
                //    긴 주행 영상을 빠르게 검토하거나
                //    특정 구간을 느리게 분석하는 데 사용됩니다.
                //
                // 📌 TODO: Increase speed
                //    videoPlayer.rate를 증가시킬 예정 (0.5x ~ 4x 범위)
                //
                Button("Increase Speed") {
                    // TODO: Increase speed
                    // 재생 속도를 단계적으로 증가 (예: 1.0x → 1.5x → 2.0x)
                }
                // 📌 .keyboardShortcut("]", modifiers: .command):
                //    Command+] (⌘]) 단축키 할당
                //
                //    "]" (닫는 대괄호)는 "증가"를 나타냅니다.
                //    "[" (여는 대괄호)와 쌍을 이루는 직관적인 인터페이스입니다.
                //
                //    많은 비디오 앱에서 대괄호로 속도를 조절합니다.
                //    (VLC, IINA 등)
                //
                .keyboardShortcut("]", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Decrease Speed 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Decrease Speed"):
                //    재생 속도를 감소시킵니다 (예: 2x → 1.5x → 1x → 0.5x).
                //
                // 📌 TODO: Decrease speed
                //    videoPlayer.rate를 감소시킬 예정 (0.5x ~ 4x 범위)
                //
                Button("Decrease Speed") {
                    // TODO: Decrease speed
                    // 재생 속도를 단계적으로 감소 (예: 2.0x → 1.5x → 1.0x)
                }
                .keyboardShortcut("[", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Normal Speed 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Normal Speed"):
                //    재생 속도를 정상(1.0x)으로 복귀합니다.
                //
                // 📌 TODO: Normal speed
                //    videoPlayer.rate = 1.0으로 설정할 예정
                //
                Button("Normal Speed") {
                    // TODO: Normal speed
                    // 재생 속도를 1.0x (정상 속도)로 복원
                }
                // 📌 .keyboardShortcut("0", modifiers: .command):
                //    Command+0 (⌘0) 단축키 할당
                //
                //    "0"은 "기본값으로 복원"을 의미합니다.
                //    Xcode에서 ⌘0이 "실제 크기"를 의미하는 것과 유사합니다.
                //
                .keyboardShortcut("0", modifiers: .command)
            }

            // ═══════════════════════════════════════════════════════════════
            // Help 메뉴 커스터마이징
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandGroup(replacing: .appInfo):
            //    기본 "About App" 메뉴 항목을 대체합니다.
            //
            // 📌 .appInfo란?
            //    CommandGroupPlacement.appInfo는 앱 정보를 표시하는 표준 위치입니다.
            //    보통 App 메뉴의 첫 번째 항목입니다.
            //
            // 📌 왜 대체하나요?
            //    기본 About 창 대신 커스텀 About 창을 표시하기 위해
            //    직접 버튼 액션을 정의합니다.
            //
            CommandGroup(replacing: .appInfo) {

                // ───────────────────────────────────────────────────────────
                // About BlackboxPlayer 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("About BlackboxPlayer"):
                //    앱 정보(버전, 저작권, 라이선스 등)를 표시하는 창을 엽니다.
                //
                // 📌 TODO: Show about window
                //    커스텀 About 창(Sheet 또는 Window)을 표시할 예정
                //
                // 📌 구현 예시 (향후):
                //    @State var showAbout = false
                //    .sheet(isPresented: $showAbout) {
                //        AboutView()
                //    }
                //
                Button("About BlackboxPlayer") {
                    // TODO: Show about window
                    // 앱 버전, 개발자 정보, 오픈소스 라이선스 등을
                    // 표시하는 About 창을 Sheet 또는 별도 윈도우로 표시
                }

                Divider()

                // ───────────────────────────────────────────────────────────
                // BlackboxPlayer Help 버튼
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("BlackboxPlayer Help"):
                //    앱 사용법 도움말을 표시합니다.
                //
                // 📌 TODO: Show help
                //    도움말 뷰 또는 외부 문서 링크를 열 예정
                //
                // 📌 구현 예시 (향후):
                //    NSWorkspace.shared.open(helpURL)
                //    또는 커스텀 HelpView() 표시
                //
                Button("BlackboxPlayer Help") {
                    // TODO: Show help
                    // 사용자 가이드, 단축키 목록, FAQ 등을 포함한
                    // 도움말 뷰를 표시하거나 외부 문서 링크를 열기
                }
                // 📌 .keyboardShortcut("?", modifiers: .command):
                //    Command+? (⌘?) 단축키 할당
                //
                //    Shift+Command+/와 동일합니다 (?는 Shift+/ 키)
                //    ⌘?는 macOS의 표준 "도움말" 단축키입니다.
                //
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
