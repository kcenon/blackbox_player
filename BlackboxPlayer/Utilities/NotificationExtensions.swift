/**
 * @file NotificationExtensions.swift
 * @brief NotificationCenter 커스텀 알림 이름 확장
 * @author BlackboxPlayer Development Team
 * @details
 * 앱 전체에서 사용하는 커스텀 Notification.Name을 정의합니다.
 * 메뉴 액션과 UI 컴포넌트 간의 느슨한 결합(Loose Coupling)을 위한
 * Pub-Sub 패턴의 이벤트 채널입니다.
 *
 * @section pattern 설계 패턴
 * **Observer Pattern (관찰자 패턴)**
 * - Publisher: 메뉴 버튼 → NotificationCenter.post()
 * - Subscriber: View/ViewModel → NotificationCenter.addObserver()
 * - 장점: 직접 참조 없이 이벤트 전달 (느슨한 결합)
 *
 * @section usage 사용 예시
 * ```swift
 * // Publisher (발행자) - 메뉴 버튼
 * Button("Open Folder...") {
 *     NotificationCenter.default.post(name: .openFolderRequested, object: nil)
 * }
 *
 * // Subscriber (구독자) - ViewModel
 * init() {
 *     NotificationCenter.default.addObserver(
 *         self,
 *         selector: #selector(handleOpenFolder),
 *         name: .openFolderRequested,
 *         object: nil
 *     )
 * }
 * ```
 *
 * @note 이 패턴은 SwiftUI의 선언적 특성과 UIKit의 명령적 특성을 연결하는 브리지 역할
 */

import Foundation

// MARK: - Notification Name Extensions

/**
 * @extension Notification.Name
 * @brief 커스텀 알림 이름 정의
 *
 * @details
 * BlackboxPlayer 앱 전역에서 사용하는 Notification.Name 상수들을 정의합니다.
 *
 * ## 알림 카테고리
 *
 * ### 1. 파일 관리 (File Management)
 * - `openFolderRequested`: 폴더 선택 다이얼로그 열기
 * - `refreshFileListRequested`: 파일 목록 새로고침
 *
 * ### 2. UI 토글 (UI Toggles)
 * - `toggleSidebarRequested`: 사이드바 표시/숨김
 * - `toggleMetadataOverlayRequested`: 메타데이터 오버레이 토글
 * - `toggleMapOverlayRequested`: GPS 지도 오버레이 토글
 * - `toggleGraphOverlayRequested`: G-센서 그래프 오버레이 토글
 *
 * ### 3. 재생 제어 (Playback Control)
 * - `playPauseRequested`: 재생/일시정지 토글
 * - `stepForwardRequested`: 한 프레임 앞으로
 * - `stepBackwardRequested`: 한 프레임 뒤로
 * - `increaseSpeedRequested`: 재생 속도 증가
 * - `decreaseSpeedRequested`: 재생 속도 감소
 * - `normalSpeedRequested`: 정상 속도(1.0x) 복귀
 *
 * ### 4. 도움말 (Help & Info)
 * - `showAboutRequested`: About 창 표시
 * - `showHelpRequested`: 도움말 표시
 *
 * @note 모든 알림 이름은 일관된 네이밍 컨벤션을 따름: `<action><Target>Requested`
 */
extension Notification.Name {

    // MARK: - File Management

    /// @var openFolderRequested
    /// @brief 폴더 열기 요청 알림
    /// @details
    /// 사용자가 File > Open Folder... 메뉴를 선택했을 때 발행됩니다.
    /// NSOpenPanel을 통한 폴더 선택 다이얼로그를 표시하도록 요청합니다.
    ///
    /// **트리거:** Command+O (⌘O) 또는 File 메뉴 클릭
    /// **구독자:** FileManagerService, ContentView
    static let openFolderRequested = Notification.Name("openFolderRequested")

    /// @var refreshFileListRequested
    /// @brief 파일 목록 새로고침 요청 알림
    /// @details
    /// 현재 열린 폴더의 비디오 파일 목록을 다시 스캔하도록 요청합니다.
    ///
    /// **트리거:** Command+R (⌘R) 또는 File 메뉴 클릭
    /// **구독자:** FileManagerService
    static let refreshFileListRequested = Notification.Name("refreshFileListRequested")

    // MARK: - UI Toggles

    /// @var toggleSidebarRequested
    /// @brief 사이드바 토글 요청 알림
    /// @details
    /// NavigationSplitView의 사이드바(파일 목록) 표시/숨김을 전환합니다.
    ///
    /// **트리거:** Option+Command+S (⌥⌘S) 또는 View 메뉴 클릭
    /// **구독자:** ContentView
    static let toggleSidebarRequested = Notification.Name("toggleSidebarRequested")

    /// @var toggleMetadataOverlayRequested
    /// @brief 메타데이터 오버레이 토글 요청 알림
    /// @details
    /// 영상 위에 표시되는 메타데이터 정보(시간, 속도, GPS 등)를 토글합니다.
    ///
    /// **표시 정보:**
    /// - 현재 재생 시간
    /// - GPS 좌표 (위도/경도)
    /// - 주행 속도 (km/h)
    /// - G-센서 값 (X, Y, Z축)
    ///
    /// **트리거:** Command+1 (⌘1) 또는 View 메뉴 클릭
    /// **구독자:** VideoPlayerView
    static let toggleMetadataOverlayRequested = Notification.Name("toggleMetadataOverlayRequested")

    /// @var toggleMapOverlayRequested
    /// @brief GPS 지도 오버레이 토글 요청 알림
    /// @details
    /// GPS 데이터 기반 지도 오버레이의 표시/숨김을 전환합니다.
    ///
    /// **표시 정보:**
    /// - 이동 경로 (Path)
    /// - 현재 위치 마커
    /// - 방향 인디케이터
    ///
    /// **트리거:** Command+2 (⌘2) 또는 View 메뉴 클릭
    /// **구독자:** VideoPlayerView
    static let toggleMapOverlayRequested = Notification.Name("toggleMapOverlayRequested")

    /// @var toggleGraphOverlayRequested
    /// @brief G-센서 그래프 오버레이 토글 요청 알림
    /// @details
    /// G-센서(가속도계) 데이터 그래프의 표시/숨김을 전환합니다.
    ///
    /// **표시 정보:**
    /// - X, Y, Z축 가속도 그래프
    /// - 충격 이벤트 마커
    /// - 실시간 동기화
    ///
    /// **트리거:** Command+3 (⌘3) 또는 View 메뉴 클릭
    /// **구독자:** VideoPlayerView
    static let toggleGraphOverlayRequested = Notification.Name("toggleGraphOverlayRequested")

    // MARK: - Playback Control

    /// @var playPauseRequested
    /// @brief 재생/일시정지 토글 요청 알림
    /// @details
    /// 비디오 재생 상태를 전환합니다 (재생 중 → 일시정지, 일시정지 → 재생).
    ///
    /// **트리거:** Space 키 또는 Playback 메뉴 클릭
    /// **구독자:** VideoPlayerViewModel
    static let playPauseRequested = Notification.Name("playPauseRequested")

    /// @var stepForwardRequested
    /// @brief 한 프레임 앞으로 이동 요청 알림
    /// @details
    /// 현재 재생 위치에서 정확히 1프레임(1/30초 또는 1/60초) 앞으로 이동합니다.
    /// 충격 순간의 정밀 분석에 유용합니다.
    ///
    /// **트리거:** Command+→ (⌘→) 또는 Playback 메뉴 클릭
    /// **구독자:** VideoPlayerViewModel
    static let stepForwardRequested = Notification.Name("stepForwardRequested")

    /// @var stepBackwardRequested
    /// @brief 한 프레임 뒤로 이동 요청 알림
    /// @details
    /// 현재 재생 위치에서 정확히 1프레임 뒤로 이동합니다.
    ///
    /// **트리거:** Command+← (⌘←) 또는 Playback 메뉴 클릭
    /// **구독자:** VideoPlayerViewModel
    static let stepBackwardRequested = Notification.Name("stepBackwardRequested")

    /// @var increaseSpeedRequested
    /// @brief 재생 속도 증가 요청 알림
    /// @details
    /// 재생 속도를 한 단계 증가시킵니다.
    ///
    /// **속도 단계:** 0.25x → 0.5x → 1.0x → 1.5x → 2.0x → 4.0x
    ///
    /// **트리거:** Command+] (⌘]) 또는 Playback 메뉴 클릭
    /// **구독자:** VideoPlayerViewModel
    static let increaseSpeedRequested = Notification.Name("increaseSpeedRequested")

    /// @var decreaseSpeedRequested
    /// @brief 재생 속도 감소 요청 알림
    /// @details
    /// 재생 속도를 한 단계 감소시킵니다.
    ///
    /// **속도 단계:** 4.0x → 2.0x → 1.5x → 1.0x → 0.5x → 0.25x
    ///
    /// **트리거:** Command+[ (⌘[) 또는 Playback 메뉴 클릭
    /// **구독자:** VideoPlayerViewModel
    static let decreaseSpeedRequested = Notification.Name("decreaseSpeedRequested")

    /// @var normalSpeedRequested
    /// @brief 정상 속도 복귀 요청 알림
    /// @details
    /// 재생 속도를 1.0x (정상 속도)로 즉시 복귀합니다.
    ///
    /// **트리거:** Command+0 (⌘0) 또는 Playback 메뉴 클릭
    /// **구독자:** VideoPlayerViewModel
    static let normalSpeedRequested = Notification.Name("normalSpeedRequested")

    // MARK: - Help & Info

    /// @var showAboutRequested
    /// @brief About 창 표시 요청 알림
    /// @details
    /// 앱 정보, 버전, 저작권, 라이선스 정보를 표시하는 About 창을 엽니다.
    ///
    /// **트리거:** BlackboxPlayer > About BlackboxPlayer 메뉴 클릭
    /// **구독자:** ContentView
    static let showAboutRequested = Notification.Name("showAboutRequested")

    /// @var showHelpRequested
    /// @brief 도움말 표시 요청 알림
    /// @details
    /// 앱 사용법 도움말을 표시합니다 (HelpView 또는 외부 문서 링크).
    ///
    /// **트리거:** Command+? (⌘?) 또는 Help 메뉴 클릭
    /// **구독자:** ContentView
    static let showHelpRequested = Notification.Name("showHelpRequested")
}

