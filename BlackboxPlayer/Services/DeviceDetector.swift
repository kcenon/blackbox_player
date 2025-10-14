/// @file DeviceDetector.swift
/// @brief Service for detecting USB devices and SD card connections
/// @author BlackboxPlayer Development Team
/// @details IOKit과 NSWorkspace를 사용하여 SD 카드 연결/분리를 감지하는 서비스입니다.

/*
 ═══════════════════════════════════════════════════════════════════════════
 장치 감지 서비스
 ═══════════════════════════════════════════════════════════════════════════

 【이 파일의 목적】
 macOS의 IOKit과 NSWorkspace를 사용하여 SD 카드의 연결/분리를 실시간으로 감지합니다.

 【주요 기능】
 1. SD 카드 장치 목록 조회 (detectSDCards)
 2. 실시간 장치 연결/분리 모니터링 (monitorDeviceChanges)

 【사용 기술】
 - FileManager: 마운트된 볼륨 조회
 - URL Resource Values: 볼륨 속성 확인 (isRemovable, isEjectable)
 - NSWorkspace Notifications: 마운트/언마운트 이벤트 감지

 【통합 위치】
 - ContentViewModel: SD 카드 연결 시 자동 파일 로드
 - SettingsView: 연결된 장치 목록 표시

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation
import AppKit

// MARK: - Device Detector

/*
 ───────────────────────────────────────────────────────────────────────────
 DeviceDetector 클래스
 ───────────────────────────────────────────────────────────────────────────

 【역할】
 SD 카드와 같은 이동식 저장 장치의 연결 상태를 모니터링합니다.

 【감지 메커니즘】
 1. FileManager.mountedVolumeURLs: 현재 마운트된 모든 볼륨 조회
 2. URL.resourceValues: 볼륨 속성 확인
    - .volumeIsRemovableKey: 이동식 장치 여부
    - .volumeIsEjectableKey: 꺼내기 가능 여부
 3. NSWorkspace.didMountNotification: 새 볼륨 마운트 이벤트
 4. NSWorkspace.didUnmountNotification: 볼륨 언마운트 이벤트

 【SD 카드 판별 기준】
 - isRemovable = true: 이동식 미디어
 - isEjectable = true: 사용자가 꺼낼 수 있음
 - 두 조건을 모두 만족하는 장치 = SD 카드 또는 USB 드라이브

 【장치 타입】
 macOS에서 이동식 장치로 인식되는 것들:
 - SD 카드
 - USB 드라이브
 - 외장 하드 드라이브
 - iPhone/iPad (제한적)

 제외되는 것들:
 - 내장 디스크 (isRemovable = false)
 - 네트워크 드라이브 (isEjectable = false)
 - Time Machine 백업 볼륨

 【스레드 안전성】
 - detectSDCards(): 스레드 안전 (FileManager 읽기만 수행)
 - monitorDeviceChanges(): 콜백은 main 큐에서 실행
 ───────────────────────────────────────────────────────────────────────────
 */

/// @class DeviceDetector
/// @brief SD 카드 및 USB 장치 감지 서비스
///
/// FileManager와 NSWorkspace를 사용하여 이동식 저장 장치를 감지하고
/// 실시간으로 연결/분리 이벤트를 모니터링합니다.
class DeviceDetector {
    // MARK: - Properties

    /// @var observers
    /// @brief Notification observer 참조 배열
    ///
    /// monitorDeviceChanges()로 등록한 observer를 추적하여
    /// 나중에 정리할 수 있도록 합니다.
    ///
    /// 메모리 누수 방지:
    /// ```swift
    /// deinit {
    ///     for observer in observers {
    ///         NotificationCenter.default.removeObserver(observer)
    ///     }
    /// }
    /// ```
    private var observers: [NSObjectProtocol] = []

    // MARK: - Initialization

    /// @brief DeviceDetector 초기화
    init() {
        // 추가 초기화 작업 없음
    }

    // MARK: - Deinitialization

    /*
     ───────────────────────────────────────────────────────────────────────
     deinit
     ───────────────────────────────────────────────────────────────────────

     【목적】
     인스턴스 해제 시 notification observer 정리

     【중요성】
     observer를 제거하지 않으면:
     - 메모리 누수 발생
     - 해제된 객체에 notification 전달 시 크래시

     【정리 방법】
     ```swift
     NotificationCenter.default.removeObserver(observer)
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 인스턴스 해제 시 observer 정리
    deinit {
        // 모든 observer 제거
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 1: detectSDCards
     ───────────────────────────────────────────────────────────────────────

     【목적】
     현재 마운트된 모든 이동식 저장 장치(SD 카드) 조회

     【알고리즘】
     1. FileManager.mountedVolumeURLs로 모든 마운트된 볼륨 조회
     2. 각 볼륨의 resource values 읽기
     3. isRemovable && isEjectable 조건 확인
     4. 조건 만족 시 배열에 추가
     5. URL 배열 반환

     【Resource Values】
     ```swift
     let resourceValues = try url.resourceValues(
         forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey]
     )
     ```

     【반환 예시】
     ```
     [
         file:///Volumes/BLACKBOX_SD/,
         file:///Volumes/USB_DRIVE/
     ]
     ```

     【성능】
     - 시간 복잡도: O(N) - N은 마운트된 볼륨 수
     - 일반적으로 3-5개 정도 (빠름)

     【사용 시나리오】
     1. 앱 시작 시 초기 스캔
     2. 수동 새로고침 버튼
     3. 자동 재스캔 (주기적)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 현재 마운트된 SD 카드 목록 조회
    ///
    /// FileManager.mountedVolumeURLs를 사용하여 모든 마운트된 볼륨을 조회하고,
    /// 이동식/꺼내기 가능한 장치만 필터링합니다.
    ///
    /// @return SD 카드 볼륨 URL 배열
    ///
    /// 사용 예시:
    /// ```swift
    /// let detector = DeviceDetector()
    /// let sdCards = detector.detectSDCards()
    ///
    /// if sdCards.isEmpty {
    ///     print("SD 카드가 연결되지 않았습니다")
    /// } else {
    ///     for sdCard in sdCards {
    ///         print("발견: \(sdCard.path)")
    ///     }
    /// }
    /// ```
    ///
    /// 판별 기준:
    /// - isRemovable = true (이동식 미디어)
    /// - isEjectable = true (꺼내기 가능)
    ///
    /// 참고:
    /// - 내장 디스크는 제외됨
    /// - 네트워크 드라이브는 제외됨
    /// - USB 드라이브도 포함됨 (동일한 특성)
    func detectSDCards() -> [URL] {
        var mountedSDCards: [URL] = []

        // 1단계: 모든 마운트된 볼륨 조회
        // includingResourceValuesForKeys: 미리 로드할 속성 지정 (성능 향상)
        // options: .skipHiddenVolumes - 숨김 볼륨 제외
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey],
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        // 2단계: 각 볼륨의 속성 확인
        for url in urls {
            do {
                // Resource values 읽기
                let resourceValues = try url.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])

                // 이동식 && 꺼내기 가능한 장치만 필터링
                if let isRemovable = resourceValues.volumeIsRemovable,
                   let isEjectable = resourceValues.volumeIsEjectable,
                   isRemovable && isEjectable {
                    mountedSDCards.append(url)
                }
            } catch {
                // 속성 읽기 실패 시 스킵 (권한 문제 등)
                print("Error checking volume properties for \(url): \(error)")
            }
        }

        return mountedSDCards
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 2: monitorDeviceChanges
     ───────────────────────────────────────────────────────────────────────

     【목적】
     SD 카드 연결/분리 이벤트를 실시간으로 감지

     【Notification 사용】
     NSWorkspace는 볼륨 마운트/언마운트 시 notification 발송:
     - NSWorkspace.didMountNotification: 새 볼륨 마운트
     - NSWorkspace.didUnmountNotification: 볼륨 언마운트

     【userInfo 구조】
     ```swift
     notification.userInfo = [
         NSWorkspace.volumeURLUserInfoKey: URL  // 볼륨 URL
     ]
     ```

     【콜백 실행 큐】
     queue: .main으로 지정하여 UI 업데이트 가능:
     ```swift
     NotificationCenter.default.addObserver(
         forName: NSWorkspace.didMountNotification,
         object: nil,
         queue: .main  // 메인 스레드에서 실행
     ) { notification in
         // UI 업데이트 가능
     }
     ```

     【Observer 관리】
     반환된 observer 객체를 저장하여 나중에 제거:
     ```swift
     let observer = NotificationCenter.default.addObserver(...)
     observers.append(observer)
     ```

     【메모리 관리】
     - 클로저가 self를 캡처하므로 [weak self] 사용
     - retain cycle 방지

     【사용 패턴】
     ```swift
     detector.monitorDeviceChanges(
         onConnect: { url in
             print("SD 카드 연결: \(url)")
             // 파일 로드 시작
         },
         onDisconnect: { url in
             print("SD 카드 분리: \(url)")
             // 파일 목록 초기화
         }
     )
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief SD 카드 연결/분리 이벤트 모니터링
    ///
    /// NSWorkspace.didMountNotification과 didUnmountNotification을 사용하여
    /// 볼륨 마운트/언마운트 이벤트를 감지하고 콜백을 호출합니다.
    ///
    /// @param onConnect 볼륨 마운트 시 호출될 콜백 (메인 스레드)
    /// @param onDisconnect 볼륨 언마운트 시 호출될 콜백 (메인 스레드)
    ///
    /// 사용 예시:
    /// ```swift
    /// let detector = DeviceDetector()
    ///
    /// detector.monitorDeviceChanges(
    ///     onConnect: { [weak self] volumeURL in
    ///         print("SD 카드 연결: \(volumeURL.path)")
    ///         self?.loadFilesFrom(volumeURL)
    ///     },
    ///     onDisconnect: { [weak self] volumeURL in
    ///         print("SD 카드 분리: \(volumeURL.path)")
    ///         self?.clearFileList()
    ///     }
    /// )
    /// ```
    ///
    /// 참고:
    /// - 콜백은 메인 스레드에서 실행됨 (UI 업데이트 가능)
    /// - 인스턴스 해제 시 observer 자동 정리 (deinit)
    /// - 모든 볼륨 마운트/언마운트가 감지됨 (SD 카드뿐만 아니라)
    func monitorDeviceChanges(onConnect: @escaping (URL) -> Void, onDisconnect: @escaping (URL) -> Void) {
        /*
         ───────────────────────────────────────────────────────────────────
         마운트 이벤트 모니터링
         ───────────────────────────────────────────────────────────────────

         【NSWorkspace.didMountNotification】
         새 볼륨이 마운트될 때 발송되는 notification:
         - SD 카드 삽입
         - USB 드라이브 연결
         - 네트워크 드라이브 마운트
         - DMG 파일 마운트

         【userInfo】
         volumeURLUserInfoKey로 볼륨 URL 추출:
         ```swift
         if let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
             // 볼륨 URL 사용
         }
         ```

         【queue: .main】
         콜백을 메인 스레드에서 실행:
         - SwiftUI/AppKit UI 업데이트 가능
         - @MainActor 함수 호출 가능
         ───────────────────────────────────────────────────────────────────
         */

        // 마운트 이벤트 observer 등록
        let mountObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { notification in
            // userInfo에서 볼륨 URL 추출
            if let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                onConnect(volume)
            }
        }
        observers.append(mountObserver)

        /*
         ───────────────────────────────────────────────────────────────────
         언마운트 이벤트 모니터링
         ───────────────────────────────────────────────────────────────────

         【NSWorkspace.didUnmountNotification】
         볼륨이 언마운트될 때 발송되는 notification:
         - SD 카드 꺼내기
         - USB 드라이브 분리
         - 네트워크 드라이브 끊기
         - DMG 파일 배출

         【주의사항】
         언마운트 후에는 해당 경로에 접근 불가:
         - 파일 읽기 실패
         - 디렉토리 존재하지 않음
         - FileSystemError.deviceNotFound

         따라서 콜백에서:
         1. UI 업데이트 (파일 목록 초기화)
         2. 진행 중인 작업 취소
         3. 리소스 정리
         ───────────────────────────────────────────────────────────────────
         */

        // 언마운트 이벤트 observer 등록
        let unmountObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { notification in
            // userInfo에서 볼륨 URL 추출
            if let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                onDisconnect(volume)
            }
        }
        observers.append(unmountObserver)
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 3: stopMonitoring (선택적 구현)
     ───────────────────────────────────────────────────────────────────────

     【목적】
     모니터링을 수동으로 중지

     【사용 시나리오】
     - 특정 뷰가 사라질 때
     - 앱이 백그라운드로 전환될 때
     - 리소스 절약이 필요할 때

     【현재 구현】
     deinit에서 자동으로 정리되므로 별도 메서드 불필요.
     필요시 추가 구현 가능:

     ```swift
     func stopMonitoring() {
         for observer in observers {
             NotificationCenter.default.removeObserver(observer)
         }
         observers.removeAll()
     }
     ```
     ───────────────────────────────────────────────────────────────────────
     */
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 가이드
 ═══════════════════════════════════════════════════════════════════════════

 【1. 기본 사용법】

 ```swift
 class ContentViewModel: ObservableObject {
     @Published var connectedSDCards: [URL] = []

     private let deviceDetector = DeviceDetector()

     init() {
         // 초기 스캔
         connectedSDCards = deviceDetector.detectSDCards()

         // 실시간 모니터링 시작
         deviceDetector.monitorDeviceChanges(
             onConnect: { [weak self] volumeURL in
                 print("SD 카드 연결: \(volumeURL.path)")
                 self?.handleSDCardConnected(volumeURL)
             },
             onDisconnect: { [weak self] volumeURL in
                 print("SD 카드 분리: \(volumeURL.path)")
                 self?.handleSDCardDisconnected(volumeURL)
             }
         )
     }

     private func handleSDCardConnected(_ volumeURL: URL) {
         // 연결된 SD 카드를 목록에 추가
         if !connectedSDCards.contains(volumeURL) {
             connectedSDCards.append(volumeURL)
         }

         // FileSystemService로 파일 로드
         Task {
             do {
                 let fileSystemService = FileSystemService()
                 let videoFiles = try fileSystemService.listVideoFiles(at: volumeURL)
                 print("비디오 파일 \(videoFiles.count)개 발견")
             } catch {
                 print("파일 로드 실패: \(error)")
             }
         }
     }

     private func handleSDCardDisconnected(_ volumeURL: URL) {
         // 목록에서 제거
         connectedSDCards.removeAll { $0 == volumeURL }

         // 관련 파일 정리
         // ...
     }
 }
 ```

 【2. SwiftUI 통합】

 ```swift
 struct ContentView: View {
     @StateObject private var viewModel = ContentViewModel()

     var body: some View {
         VStack {
             if viewModel.connectedSDCards.isEmpty {
                 Text("SD 카드를 연결해주세요")
                     .foregroundColor(.secondary)
             } else {
                 List(viewModel.connectedSDCards, id: \.self) { sdCard in
                     HStack {
                         Image(systemName: "sdcard.fill")
                         Text(sdCard.lastPathComponent)
                         Spacer()
                         Button("열기") {
                             viewModel.openSDCard(sdCard)
                         }
                     }
                 }
             }
         }
     }
 }
 ```

 【3. 자동 파일 로드】

 ```swift
 class FileListViewModel: ObservableObject {
     @Published var videoFiles: [URL] = []

     private let deviceDetector = DeviceDetector()
     private let fileSystemService = FileSystemService()

     func startAutoDetection() {
         // 현재 연결된 SD 카드 스캔
         let sdCards = deviceDetector.detectSDCards()
         if let firstCard = sdCards.first {
             loadFiles(from: firstCard)
         }

         // 새 SD 카드 연결 시 자동 로드
         deviceDetector.monitorDeviceChanges(
             onConnect: { [weak self] volumeURL in
                 self?.loadFiles(from: volumeURL)
             },
             onDisconnect: { [weak self] _ in
                 self?.videoFiles = []
             }
         )
     }

     private func loadFiles(from volumeURL: URL) {
         Task { @MainActor in
             do {
                 let files = try fileSystemService.listVideoFiles(at: volumeURL)
                 self.videoFiles = files
             } catch {
                 print("파일 로드 실패: \(error)")
             }
         }
     }
 }
 ```

 【4. 수동 스캔 버튼】

 ```swift
 struct DeviceListView: View {
     @State private var sdCards: [URL] = []

     private let deviceDetector = DeviceDetector()

     var body: some View {
         VStack {
             List(sdCards, id: \.self) { sdCard in
                 Text(sdCard.lastPathComponent)
             }

             Button("새로고침") {
                 refreshDevices()
             }
         }
         .onAppear {
             refreshDevices()
         }
     }

     private func refreshDevices() {
         sdCards = deviceDetector.detectSDCards()
     }
 }
 ```

 【5. 필터링 예시】

 ```swift
 class SmartDeviceDetector {
     private let deviceDetector = DeviceDetector()
     private let fileSystemService = FileSystemService()

     /// 블랙박스 SD 카드만 필터링 (비디오 파일이 있는 경우)
     func detectBlackboxSDCards() -> [URL] {
         let allSDCards = deviceDetector.detectSDCards()

         return allSDCards.filter { url in
             do {
                 let videoFiles = try fileSystemService.listVideoFiles(at: url)
                 return !videoFiles.isEmpty
             } catch {
                 return false
             }
         }
     }

     /// 특정 디렉토리 구조를 가진 SD 카드 찾기
     func detectBlackboxWithStructure() -> URL? {
         let sdCards = deviceDetector.detectSDCards()

         for sdCard in sdCards {
             // Normal, Event, Parking 디렉토리가 있는지 확인
             let normalDir = sdCard.appendingPathComponent("Normal")
             let eventDir = sdCard.appendingPathComponent("Event")

             if FileManager.default.fileExists(atPath: normalDir.path) &&
                FileManager.default.fileExists(atPath: eventDir.path) {
                 return sdCard
             }
         }

         return nil
     }
 }
 ```

 【6. 에러 처리】

 ```swift
 class RobustDeviceDetector: ObservableObject {
     @Published var errorMessage: String?

     private let deviceDetector = DeviceDetector()

     func startMonitoring() {
         deviceDetector.monitorDeviceChanges(
             onConnect: { [weak self] volumeURL in
                 self?.handleConnect(volumeURL)
             },
             onDisconnect: { [weak self] volumeURL in
                 self?.handleDisconnect(volumeURL)
             }
         )
     }

     private func handleConnect(_ volumeURL: URL) {
         // 접근 권한 확인
         guard FileManager.default.isReadableFile(atPath: volumeURL.path) else {
             errorMessage = "SD 카드 접근 권한이 없습니다"
             return
         }

         // 파일 시스템 타입 확인 (선택적)
         do {
             let resourceValues = try volumeURL.resourceValues(forKeys: [.volumeNameKey])
             if let volumeName = resourceValues.volumeName {
                 print("볼륨 이름: \(volumeName)")
             }
         } catch {
             errorMessage = "볼륨 정보를 읽을 수 없습니다"
         }
     }

     private func handleDisconnect(_ volumeURL: URL) {
         // 진행 중인 작업 취소
         // 파일 핸들 정리
         // UI 업데이트
     }
 }
 ```

 【7. 테스트 시나리오】

 ```swift
 // 1. SD 카드 연결 전
 let detector = DeviceDetector()
 let cards = detector.detectSDCards()
 print("연결된 SD 카드: \(cards.count)개")  // 0개

 // 2. SD 카드 연결 (물리적으로 삽입 또는 DMG 마운트)
 // → didMountNotification 발송
 // → onConnect 콜백 호출

 // 3. SD 카드 꺼내기
 // → didUnmountNotification 발송
 // → onDisconnect 콜백 호출

 // 4. 테스트용 DMG 생성
 /*
 # 100MB DMG 파일 생성
 hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" test_sd.dmg

 # 마운트
 hdiutil attach test_sd.dmg

 # 언마운트
 hdiutil detach /Volumes/TEST_SD
 */
 ```

 ═══════════════════════════════════════════════════════════════════════════
 */
