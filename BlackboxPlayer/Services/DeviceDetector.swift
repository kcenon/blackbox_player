/// @file DeviceDetector.swift
/// @brief Service for detecting USB devices and SD card connections
/// @author BlackboxPlayer Development Team
/// @details Service using IOKit and NSWorkspace for detecting SD card connection/disconnection.

/*
 
 Device Detection Service
 

 [Purpose of this File]
 Uses macOS IOKit and NSWorkspace to detect SD card connection/disconnection in real-time.

 [Key Features]
 1. Retrieve list of SD card devices (detectSDCards)
 2. Real-time device connection/disconnection monitoring (monitorDeviceChanges)

 [Technologies Used]
 - FileManager: Query mounted volumes
 - URL Resource Values: Check volume attributes (isRemovable, isEjectable)
 - NSWorkspace Notifications: Detect mount/unmount events

 [Integration Points]
 - ContentViewModel: automatic file loading on SD card connection
 - SettingsView: display list of connected devices

 
 */

import Foundation
import AppKit

// MARK: - Device Detector

/*
 
 DeviceDetector Class
 

 [Role]
 Monitors the connection status of removable storage devices such as SD cards.

 [Detection Mechanism]
 1. FileManager.mountedVolumeURLs: query all currently mounted volumes
 2. URL.resourceValues: check volume attributes
 -.volumeIsRemovableKey: whether removable device
 -.volumeIsEjectableKey: whether ejectable
 3. NSWorkspace.didMountNotification: new volume mount event
 4. NSWorkspace.didUnmountNotification: volume unmount event

 [SD Card Identification Criteria]
 - isRemovable = true: removable media
 - isEjectable = true: za has
 - satisfies both conditions device = SD card also USB drive

 [Device Types]
 macOS removable device:
 - SD card
 - USB drive
 - ha drive
 - iPhone/iPad (remove)

 remove:
 - internal disk (isRemovable = false)
 - network drive (isEjectable = false)
 - Time Machine volume

 [Thread Safety]
 - detectSDCards(): before (FileManager only )
 - monitorDeviceChanges(): main queue 
 
 */

/// @class DeviceDetector
/// @brief SD card USB Device Detection Service
///
/// Detects removable storage devices using FileManager and NSWorkspace
/// and monitors connection/disconnection events in real-time.
class DeviceDetector {
 // MARK: - Properties

 /// @var observers
 /// @brief Array of notification observer references
 ///
 /// monitorDeviceChanges() etc.registerone observer ha
 /// for later cleanup.
 ///
 /// Prevent memory leaks:
 /// ```swift
 /// deinit {
 /// for observer in observers {
 /// NotificationCenter.default.removeObserver(observer)
 /// }
 /// }
 /// ```
 private var observers: [NSObjectProtocol] = []

 // MARK: - Initialization

 /// @brief DeviceDetector Initialization
 init() {
 // Initialization no
 }

 // MARK: - Deinitialization

 /*
 
 deinit
 

 [Purpose]
 Cleanup notification observers when instance is deallocated

 [Importance]
 If observers are not removed:
 - Memory leak occurs
 - Crash when notification delivered to deallocated object

 [Cleanup Method]
 ```swift
 NotificationCenter.default.removeObserver(observer)
 ```
 
 */

 /// @brief Cleanup observers when instance is deallocated
 deinit {
 // Remove all observers
 for observer in observers {
 NotificationCenter.default.removeObserver(observer)
 }
 }

 // MARK: - Public Methods

 /*
 
 Method 1: detectSDCards
 

 [Purpose]
 Retrieve all currently mounted removable storage devices (SD cards)

 [Algorithm]
 1. FileManager.mountedVolumeURLs Retrieve all mounted volumes
 2. Read resource values of each volume
 3. Check isRemovable && isEjectable condition
 4. Add to array if condition satisfied
 5. Return URL array

 [Resource Values]
 ```swift
 let resourceValues = try url.resourceValues(
 forKeys: [.volumeIsRemovableKey,.volumeIsEjectableKey]
 )
 ```

 [Return Example]
 ```
 [
 file:///Volumes/BLACKBOX_SD/,
 file:///Volumes/USB_DRIVE/
 ]
 ```

 [Performance]
 - Time complexity: O(N) - N mounted volume 
 - 3-5 also ()

 [Usage Scenarios]
 1. when when sec 
 2. Refresh 
 3. automatic ()
 
 */

 /// @brief Retrieve list of currently mounted SD cards
 ///
 /// Uses FileManager.mountedVolumeURLs to retrieve all mounted volumes
 /// and filters only removable/ejectable devices.
 ///
 /// @return SD card volume URL 
 ///
 /// Usage example:
 /// ```swift
 /// let detector = DeviceDetector()
 /// let sdCards = detector.detectSDCards()
 ///
 /// if sdCards.isEmpty {
 /// print("SD card connectionnot found")
 /// } else {
 /// for sdCard in sdCards {
 /// print(": \(sdCard.path)")
 /// }
 /// }
 /// ```
 ///
 ///:
 /// - isRemovable = true (removable media)
 /// - isEjectable = true (ejectable)
 ///
 /// Note:
 /// - Internal disks excluded
 /// - Network drives excluded
 /// - USB drives also included (same characteristics)
 func detectSDCards() -> [URL] {
 var mountedSDCards: [URL] = []

 // 1step: Retrieve all mounted volumes
 // includingResourceValuesForKeys: properties to preload (performance improvement)
 // options:.skipHiddenVolumes - exclude hidden volumes
 guard let urls = FileManager.default.mountedVolumeURLs(
 includingResourceValuesForKeys: [.volumeIsRemovableKey,.volumeIsEjectableKey],
 options: [.skipHiddenVolumes]
 ) else {
 return []
 }

 // Step 2: Check attributes of each volume
 for url in urls {
 do {
 // Read resource values
 let resourceValues = try url.resourceValues(forKeys: [.volumeIsRemovableKey,.volumeIsEjectableKey])

 // removable && ejectableone device only Filtering
 if let isRemovable = resourceValues.volumeIsRemovable,
 let isEjectable = resourceValues.volumeIsEjectable,
 isRemovable && isEjectable {
 mountedSDCards.append(url)
 }
 } catch {
 // Skip if attribute reading fails (permission issues etc.)
 print("Error checking volume properties for \(url): \(error)")
 }
 }

 return mountedSDCards
 }

 /*
 
 Method 2: monitorDeviceChanges
 

 [Purpose]
 Detect SD card connection/disconnection events in real-time

 [Using Notifications]
 NSWorkspace volume mount/unmount when notification:
 - NSWorkspace.didMountNotification: new volume mount
 - NSWorkspace.didUnmountNotification: volume unmount

 [userInfo Structure]
 ```swift
 notification.userInfo = [
 NSWorkspace.volumeURLUserInfoKey: URL // volume URL
 ]
 ```

 [Callback Execution Queue]
 queue:.main UI updates possible:
 ```swift
 NotificationCenter.default.addObserver(
 forName: NSWorkspace.didMountNotification,
 object: nil,
 queue:.main // main thread 
 ) { notification in
 // UI updates possible
 }
 ```

 [Observer Management]
 observer stores objects for later removal:
 ```swift
 let observer = NotificationCenter.default.addObserver(...)
 observers.append(observer)
 ```

 [Memory Management]
 - closure self ha [weak self] 
 - retain cycle 

 [Usage Pattern]
 ```swift
 detector.monitorDeviceChanges(
 onConnect: { url in
 print("SD card connection: \(url)")
 // file load when
 },
 onDisconnect: { url in
 print("SD card: \(url)")
 // file list Initialization
 }
 )
 ```
 
 */

 /// @brief Monitor SD card connection/disconnection events
 ///
 /// Uses NSWorkspace.didMountNotification and didUnmountNotification
 /// to detect volume mount/unmount events and invoke callbacks.
 ///
 /// @param onConnect Callback to invoke on volume mount (main thread)
 /// @param onDisconnect Callback to invoke on volume unmount (main thread)
 ///
 /// Usage example:
 /// ```swift
 /// let detector = DeviceDetector()
 ///
 /// detector.monitorDeviceChanges(
 /// onConnect: { [weak self] volumeURL in
 /// print("SD card connection: \(volumeURL.path)")
 /// self?.loadFilesFrom(volumeURL)
 /// },
 /// onDisconnect: { [weak self] volumeURL in
 /// print("SD card: \(volumeURL.path)")
 /// self?.clearFileList()
 /// }
 /// )
 /// ```
 ///
 /// Note:
 /// - main thread (UI updates possible)
 /// - Automatic observer cleanup when instance deallocated (deinit)
 /// - All volume mounts/unmounts detected (not just SD cards)
 func monitorDeviceChanges(onConnect: @escaping (URL) -> Void, onDisconnect: @escaping (URL) -> Void) {
 /*
 
 Mount event monitoring
 

 [NSWorkspace.didMountNotification]
 Notification sent when new volume is mounted:
 - SD card insertion
 - USB drive connection
 - Network drive mount
 - DMG file mount

 [userInfo]
 Extract volume URL with volumeURLUserInfoKey:
 ```swift
 if let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
 // Use volume URL
 }
 ```

 [queue:.main]
 main thread:
 - SwiftUI/AppKit UI updates possible
 - @MainActor function calls possible
 
 */

 // mount event observer etc.register
 let mountObserver = NotificationCenter.default.addObserver(
 forName: NSWorkspace.didMountNotification,
 object: nil,
 queue:.main
 ) { notification in
 // Extract volume URL from userInfo
 if let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
 onConnect(volume)
 }
 }
 observers.append(mountObserver)

 /*
 
 Mount event monitoring
 

 [NSWorkspace.didUnmountNotification]
 Notification sent when volume is unmounted:
 - SD card ejection
 - USB drive disconnection
 - Network drive disconnection
 - DMG file ejection

 [Precautions]
 Cannot access path after unmount:
 - file 
 - directory does not exist
 - FileSystemError.deviceNotFound

 Therefore in callback:
 1. UI update (file list Initialization)
 2. Cancel ongoing operations
 3. Cleanup resources
 
 */

 // unmount event observer etc.register
 let unmountObserver = NotificationCenter.default.addObserver(
 forName: NSWorkspace.didUnmountNotification,
 object: nil,
 queue:.main
 ) { notification in
 // Extract volume URL from userInfo
 if let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
 onDisconnect(volume)
 }
 }
 observers.append(unmountObserver)
 }

 /*
 
 Method 3: stopMonitoring (Optional Implementation)
 

 [Purpose]
 Manually stop monitoring

 [Usage Scenarios]
 - When specific view disappears
 - When app transitions to background
 - resource approximately to 

 [Current Implementation]
 No separate method needed as automatically cleaned up in deinit.
 Can implement additionally if needed:

 ```swift
 func stopMonitoring() {
 for observer in observers {
 NotificationCenter.default.removeObserver(observer)
 }
 observers.removeAll()
 }
 ```
 
 */
}

/*
 
 
 

 [1. Basic Usage]

 ```swift
 class ContentViewModel: ObservableObject {
 @Published var connectedSDCards: [URL] = []

 private let deviceDetector = DeviceDetector()

 init() {
 // sec 
 connectedSDCards = deviceDetector.detectSDCards()

 // whenmonitoring when
 deviceDetector.monitorDeviceChanges(
 onConnect: { [weak self] volumeURL in
 print("SD card connection: \(volumeURL.path)")
 self?.handleSDCardConnected(volumeURL)
 },
 onDisconnect: { [weak self] volumeURL in
 print("SD card: \(volumeURL.path)")
 self?.handleSDCardDisconnected(volumeURL)
 }
 )
 }

 private func handleSDCardConnected(_ volumeURL: URL) {
 // Add connected SD card to list
 if !connectedSDCards.contains(volumeURL) {
 connectedSDCards.append(volumeURL)
 }

 // Load files with FileSystemService
 Task {
 do {
 let fileSystemService = FileSystemService()
 let videoFiles = try fileSystemService.listVideoFiles(at: volumeURL)
 print("video files \(videoFiles.count) ")
 } catch {
 print("Failed to load files: \(error)")
 }
 }
 }

 private func handleSDCardDisconnected(_ volumeURL: URL) {
 // Remove from list
 connectedSDCards.removeAll { $0 == volumeURL }

 // Cleanup related files
 //...
 }
 }
 ```

 2. SwiftUI 

 ```swift
 struct ContentView: View {
 @StateObject private var viewModel = ContentViewModel()

 var body: some View {
 VStack {
 if viewModel.connectedSDCards.isEmpty {
 Text("Please insert SD card")
.foregroundColor(.secondary)
 } else {
 List(viewModel.connectedSDCards, id: \.self) { sdCard in
 HStack {
 Image(systemName: "sdcard.fill")
 Text(sdCard.lastPathComponent)
 Spacer()
 Button("Open") {
 viewModel.openSDCard(sdCard)
 }
 }
 }
 }
 }
 }
 }
 ```

 3. automatic file load

 ```swift
 class FileListViewModel: ObservableObject {
 @Published var videoFiles: [URL] = []

 private let deviceDetector = DeviceDetector()
 private let fileSystemService = FileSystemService()

 func startAutoDetection() {
 // Scan currently connected SD cards
 let sdCards = deviceDetector.detectSDCards()
 if let firstCard = sdCards.first {
 loadFiles(from: firstCard)
 }

 // Auto-load on new SD card connection
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
 print("Failed to load files: \(error)")
 }
 }
 }
 }
 ```

 4. 

 ```swift
 struct DeviceListView: View {
 @State private var sdCards: [URL] = []

 private let deviceDetector = DeviceDetector()

 var body: some View {
 VStack {
 List(sdCards, id: \.self) { sdCard in
 Text(sdCard.lastPathComponent)
 }

 Button("Refresh") {
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

 5. Filtering when

 ```swift
 class SmartDeviceDetector {
 private let deviceDetector = DeviceDetector()
 private let fileSystemService = FileSystemService()

 /// SD card only Filtering (video files has )
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

 /// Find SD card with specific directory structure
 func detectBlackboxWithStructure() -> URL? {
 let sdCards = deviceDetector.detectSDCards()

 for sdCard in sdCards {
 // Normal, Event, Parking Check if directories exist
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

 6. handling

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
 // Check permissions
 guard FileManager.default.isReadableFile(atPath: volumeURL.path) else {
 errorMessage = "No permission to access SD card"
 return
 }

 // Check file system type (optional)
 do {
 let resourceValues = try volumeURL.resourceValues(forKeys: [.volumeNameKey])
 if let volumeName = resourceValues.volumeName {
 print("Volume name: \(volumeName)")
 }
 } catch {
 errorMessage = "Cannot read volume information"
 }
 }

 private func handleDisconnect(_ volumeURL: URL) {
 // Cancel ongoing operations
 // Cleanup file handles
 // UI update
 }
 }
 ```

 7. whennario

 ```swift
 // 1. SD card connection before
 let detector = DeviceDetector()
 let cards = detector.detectSDCards()
 print("Connected SD cards: \(cards.count) ") // 0 

 // 2. SD card connection (physical insertion or DMG mount)
 // didMountNotification sent
 // onConnect callback invoked

 // 3. SD card ejection
 // didUnmountNotification sent
 // onDisconnect callback invoked

 // 4. DMG 
 /*
 # Create 100MB DMG file
 hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" test_sd.dmg

 # Mount
 hdiutil attach test_sd.dmg

 # Unmount
 hdiutil detach /Volumes/TEST_SD
 */
 ```

 
 */
