/*
 ═══════════════════════════════════════════════════════════════════════════
 EXT4Bridge.swift
 BlackboxPlayer

 C/C++ EXT4 라이브러리 통합 브릿지
 ═══════════════════════════════════════════════════════════════════════════

 【이 파일의 역할】

 이 파일은 현재 **Stub (골격) 구현**으로,
 실제 C/C++ EXT4 라이브러리가 준비되면 구현될 예정입니다.


 【왜 C/C++ 라이브러리가 필요한가요?】

 macOS는 EXT4 파일 시스템을 기본 지원하지 않습니다:

 지원하는 파일 시스템:
 ✓ HFS+ (macOS 기본)
 ✓ APFS (최신 macOS)
 ✓ FAT32 (USB 드라이브)
 ✓ exFAT (외장 하드)

 지원하지 않는 파일 시스템:
 ✗ EXT4 (Linux 기본)
 ✗ BTRFS (Linux)
 ✗ ZFS (솔라리스)

 블랙박스 SD 카드는 대부분 Linux 장치에서 포맷되므로
 EXT4 파일 시스템을 사용합니다.

 해결 방법:
 1. OSXFUSE + ext4fuse (느리고 불안정)
 2. 가상 머신 (복잡)
 3. C/C++ EXT4 라이브러리 직접 통합 ← 이 방법 선택


 【Swift ↔ C 통합 구조】

 ┌─────────────────────────────────────────────────────────────┐
 │                                                             │
 │  Swift 코드                                                  │
 │  ┌────────────────────────────────────────────────────┐     │
 │  │ EXT4Bridge.swift                                   │     │
 │  │ - mount(devicePath:)                               │     │
 │  │ - readFile(at:)                                    │     │
 │  └────────────────┬───────────────────────────────────┘     │
 │                   │                                         │
 │                   │ Swift 함수 호출                          │
 │                   ▼                                         │
 │  ┌────────────────────────────────────────────────────┐     │
 │  │ BridgingHeader.h                                   │     │
 │  │ #import "ext4.h"                                   │     │
 │  │ #import "ext4_blockdev.h"                          │     │
 │  └────────────────┬───────────────────────────────────┘     │
 │                   │                                         │
 │                   │ C 헤더 노출                             │
 │                   ▼                                         │
 │  ─────────────────────────────────────────────────────      │
 │  C/C++ 코드                                                 │
 │  ┌────────────────────────────────────────────────────┐     │
 │  │ ext4.c / ext4_blockdev.c                           │     │
 │  │ - ext4_mount()                                     │     │
 │  │ - ext4_fopen()                                     │     │
 │  │ - ext4_fread()                                     │     │
 │  └────────────────┬───────────────────────────────────┘     │
 │                   │                                         │
 │                   │ 파일 시스템 연산                         │
 │                   ▼                                         │
 │  ┌────────────────────────────────────────────────────┐     │
 │  │ SD 카드 (EXT4 파일 시스템)                          │     │
 │  │ /dev/disk2s1                                       │     │
 │  └────────────────────────────────────────────────────┘     │
 │                                                             │
 └─────────────────────────────────────────────────────────────┘


 【Bridging Header란?】

 Swift와 C 코드를 연결하는 헤더 파일입니다.

 BlackboxPlayer-BridgingHeader.h:
 ```c
 #ifndef BlackboxPlayer_BridgingHeader_h
 #define BlackboxPlayer_BridgingHeader_h

 // EXT4 라이브러리 헤더
 #import "ext4.h"
 #import "ext4_blockdev.h"
 #import "ext4_fs.h"
 #import "ext4_dir.h"

 #endif
 ```

 이 헤더에 선언된 C 함수와 타입은
 Swift 코드에서 직접 호출 가능합니다.


 【주요 C 함수 매핑】

 Swift 메서드          C 라이브러리 함수
 ────────────────────────────────────────────────────
 mount()           →  ext4_blockdev_init()
                      ext4_device_register()
                      ext4_mount()

 unmount()         →  ext4_umount()
                      ext4_device_unregister()

 readFile()        →  ext4_fopen()
                      ext4_fread()
                      ext4_fclose()

 writeFile()       →  ext4_fopen()
                      ext4_fwrite()
                      ext4_fclose()

 listFiles()       →  ext4_dir_open()
                      ext4_dir_entry_next()
                      ext4_dir_close()

 getDeviceInfo()   →  ext4_mount_point_stats()

 deleteFile()      →  ext4_fremove()

 createDirectory() →  ext4_dir_mk()


 【에러 처리】

 C 라이브러리는 정수 에러 코드를 반환:

 C 에러 코드:
 - EOK (0): 성공
 - ENOENT: 파일 없음
 - EACCES: 권한 없음
 - EIO: 입출력 오류
 - ENOMEM: 메모리 부족

 Swift Error 변환:
 ```swift
 let result = ext4_mount(...)
 if result != EOK {
     switch result {
     case ENOENT:
         throw EXT4Error.deviceNotFound
     case EACCES:
         throw EXT4Error.permissionDenied
     case EIO:
         throw EXT4Error.ioError
     default:
         throw EXT4Error.unknownError(code: result)
     }
 }
 ```


 【메모리 관리】

 Swift와 C 간 메모리 관리:

 1. OpaquePointer:
    - C 포인터를 Swift에서 안전하게 래핑
    - 예: ext4_file*, ext4_dir*

 2. UnsafeMutablePointer:
    - C 함수에 버퍼 전달 시 사용
    - withUnsafeMutableBytes로 안전하게 접근

 3. String(cString:):
    - C 문자열 (char*) → Swift String 변환

 4. defer:
    - C 리소스 해제 보장
    - ext4_fclose(), ext4_dir_close()


 【통합 순서】

 1. C 라이브러리 준비:
    - lwext4 라이브러리 다운로드
    - Xcode 프로젝트에 추가
    - BridgingHeader.h 생성

 2. 빌드 설정:
    - HEADER_SEARCH_PATHS 설정
    - OTHER_CFLAGS 추가

 3. Stub 구현 제거:
    - throw EXT4Error.unsupportedOperation 제거
    - 실제 C 함수 호출 코드 작성

 4. 테스트:
    - 단위 테스트 작성
    - 실제 SD 카드로 통합 테스트

 5. 최적화:
    - 성능 프로파일링
    - 메모리 누수 확인


 【현재 상태】

 ⚠️ 이 파일은 Stub 구현입니다.

 모든 메서드가 EXT4Error.unsupportedOperation을 던집니다.

 개발 중에는 MockEXT4FileSystem을 사용하세요:

 ```swift
 #if DEBUG
 let fileSystem: EXT4FileSystemProtocol = MockEXT4FileSystem()
 #else
 let fileSystem = EXT4Bridge()  // 통합 완료 후 사용
 #endif
 ```


 【참고 자료】

 1. lwext4 라이브러리:
    https://github.com/gkostka/lwext4

 2. Swift C Interop:
    https://developer.apple.com/documentation/swift/imported-c-and-objective-c-apis

 3. Bridging Header:
    https://developer.apple.com/documentation/swift/importing-objective-c-into-swift

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

/*
 ─────────────────────────────────────────────────────────────────────────
 EXT4Bridge 클래스
 ─────────────────────────────────────────────────────────────────────────

 【역할】

 C/C++ EXT4 라이브러리와 Swift 코드를 연결하는 브릿지입니다.


 【아키텍처】

 ┌──────────────────────────────────────────────────────┐
 │ BlackboxPlayer (Swift)                               │
 │                                                      │
 │ FileManagerService                                   │
 │       │                                              │
 │       ▼                                              │
 │ EXT4FileSystemProtocol (프로토콜)                     │
 │       │                                              │
 │       ├─────────────────┬────────────────────────┐   │
 │       │                 │                        │   │
 │       ▼                 ▼                        ▼   │
 │ MockEXT4FileSystem  EXT4Bridge ←─ 이 클래스      │   │
 │ (개발/테스트)       (배포)                        │   │
 │                         │                            │
 │                         │ Swift → C 호출             │
 │                         ▼                            │
 │                    ┌─────────────────────┐           │
 │                    │ Bridging Header     │           │
 │                    │ ext4.h              │           │
 │                    │ ext4_blockdev.h     │           │
 │                    └─────────┬───────────┘           │
 │                              │                       │
 └──────────────────────────────┼───────────────────────┘
                                │ C 함수 호출
                                ▼
                    ┌─────────────────────┐
                    │ lwext4 라이브러리    │
                    │ (C 구현)            │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │ SD 카드 (EXT4)      │
                    │ /dev/disk2s1        │
                    └─────────────────────┘


 【프로토콜 준수】

 EXT4FileSystemProtocol을 구현하므로
 MockEXT4FileSystem과 완전히 교체 가능합니다.


 【Stub 패턴】

 현재는 모든 메서드가 구현되지 않았습니다:

 ```swift
 func mount(devicePath: String) throws {
     // TODO: 실제 구현
     throw EXT4Error.unsupportedOperation
 }
 ```

 C 라이브러리 통합 시 TODO 부분을 실제 코드로 교체합니다.

 ─────────────────────────────────────────────────────────────────────────
 */

/// @class EXT4Bridge
/// @brief Bridge class for integrating C/C++ EXT4 library
/// @details This class wraps the C library and conforms to EXT4FileSystemProtocol
///
/// **Integration Instructions:**
/// When the C/C++ EXT4 library is available, follow these steps:
///
/// 1. Add C library files to the project:
///    - Copy C/C++ source files to: BlackboxPlayer/Utilities/EXT4/
///    - Add headers to BridgingHeader.h:
///      ```c
///      #import "ext4.h"
///      #import "ext4_blockdev.h"
///      #import "ext4_fs.h"
///      ```
///
/// 2. Update project.yml build settings:
///    ```yaml
///    HEADER_SEARCH_PATHS:
///      - BlackboxPlayer/Utilities/EXT4
///    OTHER_CFLAGS: -DCONFIG_HAVE_OWN_ERRNO=1
///    ```
///
/// 3. Implement the methods below using C library functions:
///    - mount() → ext4_mount()
///    - unmount() → ext4_umount()
///    - readFile() → ext4_fopen(), ext4_fread()
///    - writeFile() → ext4_fwrite()
///    - listFiles() → ext4_dir_open(), ext4_dir_entry_next()
///
/// 4. Handle C error codes and convert to EXT4Error:
///    ```swift
///    let result = ext4_mount(...)
///    if result != EOK {
///        throw EXT4Error.mountFailed(reason: String(cString: strerror(result)))
///    }
///    ```
///
class EXT4Bridge: EXT4FileSystemProtocol {

    // MARK: - Properties

    /*
     ─────────────────────────────────────────────────────────────────────
     속성
     ─────────────────────────────────────────────────────────────────────

     【_isMounted】

     마운트 상태 플래그.


     【mountPoint】

     마운트 지점 경로 (예: "/mnt/ext4")

     Linux/macOS에서 파일 시스템을 마운트하면
     특정 디렉토리에 연결됩니다.

     예:
     - 장치: /dev/disk2s1 (SD 카드)
     - 마운트 지점: /mnt/ext4
     - 파일 접근: /mnt/ext4/normal/video.mp4


     【deviceHandle】

     C 라이브러리의 장치 핸들 포인터.

     타입: OpaquePointer
     - C 포인터를 Swift에서 안전하게 래핑
     - 실제 타입은 ext4_blockdev* 또는 ext4_file*
     - Swift에서는 불투명한 포인터로 처리

     사용 예:
     ```c
     // C 코드
     ext4_blockdev *dev = ...;
     ```

     ```swift
     // Swift 코드
     var deviceHandle: OpaquePointer? = ...
     ```

     ─────────────────────────────────────────────────────────────────────
     */

    /// @var _isMounted
    /// @brief 마운트 상태 플래그
    private var _isMounted: Bool = false

    /// @var mountPoint
    /// @brief 마운트 지점 경로
    private var mountPoint: String?

    /// @var deviceHandle
    /// @brief C 라이브러리 장치 핸들
    /// @details ext4_blockdev* 또는 ext4_file*를 OpaquePointer로 래핑
    private var deviceHandle: OpaquePointer?  // Will hold C library handle

    /*
     ─────────────────────────────────────────────────────────────────────
     isMounted: 마운트 상태 (읽기 전용)
     ─────────────────────────────────────────────────────────────────────

     프로토콜 요구사항으로, 외부에서 마운트 상태를 확인할 수 있습니다.

     ─────────────────────────────────────────────────────────────────────
     */

    var isMounted: Bool {
        return _isMounted
    }

    // MARK: - Device Management

    /*
     ═════════════════════════════════════════════════════════════════════
     mount(devicePath:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     EXT4 파일 시스템을 마운트합니다.


     【C 라이브러리 통합 단계】

     Step 1: 블록 장치 초기화
     ```c
     ext4_blockdev blockdev;
     int result = ext4_blockdev_init(&blockdev, devicePath, 512, 0);
     //                                           │        │    │
     //                                           │        │    └─ 캐시 활성화
     //                                           │        └───── 블록 크기 (512 bytes)
     //                                           └──────────── 장치 경로
     ```

     Step 2: 장치 등록
     ```c
     result = ext4_device_register(&blockdev, "ext4");
     //                                        └──── 장치 이름 (식별자)
     ```

     Step 3: 파일 시스템 마운트
     ```c
     result = ext4_mount("ext4", "/mnt/ext4", false);
     //                   │       │            └────── 읽기 전용 모드
     //                   │       └────────────────── 마운트 지점
     //                   └────────────────────────── 등록된 장치 이름
     ```


     【Swift 변환 예시】

     ```swift
     func mount(devicePath: String) throws {
         guard !_isMounted else {
             throw EXT4Error.alreadyMounted
         }

         // Step 1: 블록 장치 초기화
         var blockdev = ext4_blockdev()
         let bdResult = ext4_blockdev_init(&blockdev, devicePath, 512, 0)
         guard bdResult == EOK else {
             throw EXT4Error.deviceNotFound
         }

         // Step 2: 장치 등록
         let regResult = ext4_device_register(&blockdev, "ext4")
         guard regResult == EOK else {
             throw EXT4Error.mountFailed(reason: "Failed to register device")
         }

         // Step 3: 마운트
         let mountPoint = "/mnt/ext4"
         let mountResult = ext4_mount("ext4", mountPoint, false)
         guard mountResult == EOK else {
             let errorMsg = String(cString: strerror(mountResult))
             throw EXT4Error.mountFailed(reason: errorMsg)
         }

         // Swift 상태 업데이트
         self.mountPoint = mountPoint
         self._isMounted = true
     }
     ```


     【에러 코드】

     C 라이브러리 에러 코드 (errno.h):

     EOK (0):       성공
     ENOENT (2):    파일/장치 없음
     EACCES (13):   권한 없음
     EEXIST (17):   이미 존재
     EIO (5):       입출력 오류
     ENOMEM (12):   메모리 부족


     【메모리 안전성】

     OpaquePointer 사용:
     - C 포인터를 Swift에서 안전하게 관리
     - ARC가 관리하지 않음 (수동 해제 필요)
     - unmount() 시 ext4_umount() 호출 필수


     【테스트】

     ```swift
     let bridge = EXT4Bridge()

     // 1. 마운트
     do {
         try bridge.mount(devicePath: "/dev/disk2s1")
         print("마운트 성공")
     } catch {
         print("마운트 실패: \(error)")
     }

     // 2. 파일 작업
     let files = try bridge.listFiles(at: "normal")
     print("파일 개수: \(files.count)")

     // 3. 언마운트
     try bridge.unmount()
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func mount(devicePath: String) throws {
        // Step 1: 이중 마운트 방지
        guard !_isMounted else {
            throw EXT4Error.alreadyMounted
        }

        // TODO: Integrate C library
        // Example implementation when C library is available:
        /*
        var blockdev: ext4_blockdev = ext4_blockdev()
        var mountPoint = "/mnt/ext4"

        // Initialize block device
        // 블록 장치 초기화
        // - devicePath: SD 카드 경로 (예: /dev/disk2s1)
        // - 512: 블록 크기 (일반적으로 512 또는 4096 bytes)
        // - 0: 캐시 활성화 플래그
        let bdResult = ext4_blockdev_init(&blockdev, devicePath, 512, 0)
        guard bdResult == EOK else {
            throw EXT4Error.deviceNotFound
        }

        // Register block device
        // 장치를 "ext4" 이름으로 등록
        // 이후 이 이름으로 마운트 및 접근
        let regResult = ext4_device_register(&blockdev, "ext4")
        guard regResult == EOK else {
            throw EXT4Error.mountFailed(reason: "Failed to register device")
        }

        // Mount the filesystem
        // 파일 시스템 마운트
        // - "ext4": 등록된 장치 이름
        // - mountPoint: 마운트할 디렉토리
        // - false: 읽기/쓰기 모드 (true = 읽기 전용)
        let mountResult = ext4_mount("ext4", mountPoint, false)
        guard mountResult == EOK else {
            // C 에러 메시지를 Swift String으로 변환
            let errorMsg = String(cString: strerror(mountResult))
            throw EXT4Error.mountFailed(reason: errorMsg)
        }

        // 성공: Swift 상태 업데이트
        self.deviceHandle = ...  // 필요시 장치 핸들 저장
        self.mountPoint = mountPoint
        self._isMounted = true
        */

        // Stub implementation for now
        // 현재는 Stub: 실제 구현 전까지 unsupportedOperation 에러
        throw EXT4Error.unsupportedOperation
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     unmount()
     ═════════════════════════════════════════════════════════════════════

     【기능】

     마운트를 해제하고 리소스를 정리합니다.


     【C 라이브러리 호출】

     Step 1: 파일 시스템 언마운트
     ```c
     int result = ext4_umount(mountPoint);
     ```

     Step 2: 장치 등록 해제
     ```c
     ext4_device_unregister("ext4");
     ```


     【Swift 구현 예시】

     ```swift
     func unmount() throws {
         guard _isMounted else {
             throw EXT4Error.notMounted
         }

         guard let mp = mountPoint else {
             throw EXT4Error.notMounted
         }

         // Step 1: 언마운트
         let result = ext4_umount(mp)
         guard result == EOK else {
             let errorMsg = String(cString: strerror(result))
             throw EXT4Error.unmountFailed(reason: errorMsg)
         }

         // Step 2: 장치 등록 해제
         ext4_device_unregister("ext4")

         // Swift 상태 정리
         self.mountPoint = nil
         self.deviceHandle = nil
         self._isMounted = false
     }
     ```


     【주의사항】

     1. 파일 닫기:
        - unmount 전에 열린 파일은 모두 닫아야 함
        - ext4_fclose() 호출 필수

     2. 버퍼 플러시:
        - ext4_umount()가 자동으로 플러시
        - 쓰기 작업이 완료될 때까지 대기

     3. 리소스 누수:
        - OpaquePointer는 ARC가 관리하지 않음
        - 수동으로 nil 설정 필요

     ═════════════════════════════════════════════════════════════════════
     */

    func unmount() throws {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library
        // Example:
        /*
        guard let mp = mountPoint else {
            throw EXT4Error.notMounted
        }

        // Step 1: 언마운트
        // 모든 버퍼를 플러시하고 파일 시스템 닫기
        let result = ext4_umount(mp)
        guard result == EOK else {
            // 에러 메시지 변환
            let errorMsg = String(cString: strerror(result))
            throw EXT4Error.unmountFailed(reason: errorMsg)
        }

        // Step 2: 장치 등록 해제
        // 메모리 정리
        ext4_device_unregister("ext4")

        // Step 3: Swift 상태 정리
        self.mountPoint = nil
        self.deviceHandle = nil
        self._isMounted = false
        */

        // Stub implementation
        throw EXT4Error.unsupportedOperation
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     getDeviceInfo()
     ═════════════════════════════════════════════════════════════════════

     【기능】

     장치 및 파일 시스템 정보를 조회합니다.


     【C 라이브러리 호출】

     ```c
     ext4_mount_stats stats;
     int result = ext4_mount_point_stats(mountPoint, &stats);
     ```

     stats 구조체:
     - volume_name: 볼륨 이름
     - block_count: 총 블록 수
     - free_blocks_count: 여유 블록 수
     - block_size: 블록 크기 (bytes)


     【Swift 구현 예시】

     ```swift
     func getDeviceInfo() throws -> EXT4DeviceInfo {
         guard _isMounted, let mp = mountPoint else {
             throw EXT4Error.notMounted
         }

         // Step 1: C 구조체 초기화
         var stats = ext4_mount_stats()

         // Step 2: 통계 조회
         let result = ext4_mount_point_stats(mp, &stats)
         guard result == EOK else {
             throw EXT4Error.unknownError(code: result)
         }

         // Step 3: C 문자열 → Swift String
         let volumeName = String(cString: stats.volume_name)

         // Step 4: 크기 계산
         let totalSize = stats.block_count * UInt64(stats.block_size)
         let freeSpace = stats.free_blocks_count * UInt64(stats.block_size)

         // Step 5: Swift 객체로 변환
         return EXT4DeviceInfo(
             devicePath: devicePath,
             volumeName: volumeName,
             totalSize: totalSize,
             freeSpace: freeSpace,
             blockSize: stats.block_size,
             isMounted: true
         )
     }
     ```


     【Unsafe Pointer 사용】

     C 구조체를 Swift에서 사용:

     ```swift
     var stats = ext4_mount_stats()  // Swift가 메모리 할당
     ext4_mount_point_stats(mp, &stats)  // C 함수가 값 채움
     //                         └─ inout parameter (&)
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func getDeviceInfo() throws -> EXT4DeviceInfo {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library
        // Example:
        /*
        guard let mp = mountPoint else {
            throw EXT4Error.notMounted
        }

        // Step 1: C 구조체 초기화
        // Swift가 스택에 메모리 할당
        var stats: ext4_mount_stats = ext4_mount_stats()

        // Step 2: C 함수 호출
        // &stats: C에서 구조체 포인터 필요 시 사용
        let result = ext4_mount_point_stats(mp, &stats)
        guard result == EOK else {
            throw EXT4Error.unknownError(code: result)
        }

        // Step 3: C 데이터 → Swift 데이터 변환
        // C 문자열 배열 → Swift String
        let volumeName = String(cString: stats.volume_name)

        // 블록 수 × 블록 크기 = 총 용량
        let totalSize = stats.block_count * UInt64(stats.block_size)
        let freeSpace = stats.free_blocks_count * UInt64(stats.block_size)

        // Step 4: Swift 객체 생성
        return EXT4DeviceInfo(
            devicePath: devicePath,  // 저장된 장치 경로
            volumeName: volumeName,
            totalSize: totalSize,
            freeSpace: freeSpace,
            blockSize: stats.block_size,
            isMounted: true
        )
        */

        throw EXT4Error.unsupportedOperation
    }

    // MARK: - File Operations

    /*
     ═════════════════════════════════════════════════════════════════════
     listFiles(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     디렉토리 내 파일 목록을 조회합니다.


     【C 라이브러리 호출 순서】

     1. 디렉토리 열기:
        ```c
        ext4_dir dir;
        ext4_dir_open(&dir, fullPath);
        ```

     2. 엔트리 순회:
        ```c
        const ext4_direntry *entry;
        while (ext4_dir_entry_next(&dir, &entry) == EOK) {
            // entry 처리
        }
        ```

     3. 디렉토리 닫기:
        ```c
        ext4_dir_close(&dir);
        ```


     【Swift 구현 예시】

     ```swift
     func listFiles(at path: String) throws -> [EXT4FileInfo] {
         guard _isMounted, let mp = mountPoint else {
             throw EXT4Error.notMounted
         }

         // Step 1: 전체 경로 생성
         let fullPath = mp + "/" + normalizePath(path)

         // Step 2: 디렉토리 열기
         var dir = ext4_dir()
         let openResult = ext4_dir_open(&dir, fullPath)
         guard openResult == EOK else {
             throw EXT4Error.invalidPath
         }

         // Step 3: 자동 정리 (defer)
         defer {
             ext4_dir_close(&dir)  // 함수 종료 시 자동 호출
         }

         // Step 4: 엔트리 순회
         var files: [EXT4FileInfo] = []
         var entry: UnsafePointer<ext4_direntry>? = nil

         while ext4_dir_entry_next(&dir, &entry) == EOK {
             guard let e = entry else { break }

             // C 구조체 → Swift 객체 변환
             let name = String(cString: e.pointee.name)
             let isDir = e.pointee.inode_type == EXT4_DE_DIR

             files.append(EXT4FileInfo(
                 path: path + "/" + name,
                 name: name,
                 size: UInt64(e.pointee.inode),
                 isDirectory: isDir
             ))
         }

         return files
     }
     ```


     【Unsafe Pointer 패턴】

     C 구조체 포인터 다루기:

     ```swift
     var entry: UnsafePointer<ext4_direntry>? = nil
     //         └─────────┬─────────────┘
     //                   C 구조체 포인터

     ext4_dir_entry_next(&dir, &entry)
     //                        └─ inout: C 함수가 포인터 값 설정

     guard let e = entry else { break }
     //           └─ Optional unwrap

     let name = String(cString: e.pointee.name)
     //                         └──┬───┘
     //                            포인터가 가리키는 값 접근
     ```


     【defer를 사용한 리소스 정리】

     ```swift
     func listFiles(...) throws -> [...] {
         var dir = ext4_dir()
         ext4_dir_open(&dir, path)

         defer {
             // 함수 종료 시 자동 실행
             // 정상 반환이든, 에러 발생이든 항상 실행됨
             ext4_dir_close(&dir)
         }

         // 파일 처리...
         // 에러 발생 시에도 ext4_dir_close() 호출 보장
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func listFiles(at path: String) throws -> [EXT4FileInfo] {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library
        // Example:
        /*
        guard let mp = mountPoint else {
            throw EXT4Error.notMounted
        }

        // Step 1: 전체 경로 생성
        // 마운트 지점 + 상대 경로
        // 예: "/mnt/ext4" + "normal" = "/mnt/ext4/normal"
        let fullPath = mp + "/" + normalizePath(path)

        // Step 2: 디렉토리 열기
        var dir: ext4_dir = ext4_dir()
        let openResult = ext4_dir_open(&dir, fullPath)
        guard openResult == EOK else {
            throw EXT4Error.invalidPath
        }

        // Step 3: 자동 정리 설정
        // 함수 종료 시 (정상/에러 무관) 디렉토리 닫기
        defer { ext4_dir_close(&dir) }

        // Step 4: 엔트리 순회
        var files: [EXT4FileInfo] = []
        var entry: UnsafePointer<ext4_direntry>? = nil

        // 디렉토리 엔트리를 하나씩 읽기
        while ext4_dir_entry_next(&dir, &entry) == EOK {
            guard let e = entry else { break }

            // C 구조체 필드 접근
            // e.pointee: 포인터가 가리키는 실제 구조체
            let name = String(cString: e.pointee.name)
            let isDir = e.pointee.inode_type == EXT4_DE_DIR

            // Swift 객체로 변환
            files.append(EXT4FileInfo(
                path: path + "/" + name,
                name: name,
                size: UInt64(e.pointee.inode),
                isDirectory: isDir,
                modificationDate: Date()  // C 라이브러리에서 타임스탬프 가져오기
            ))
        }

        return files
        */

        throw EXT4Error.unsupportedOperation
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     readFile(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     파일을 읽어 Data로 반환합니다.


     【C 라이브러리 호출 순서】

     1. 파일 열기:
        ```c
        ext4_file file;
        ext4_fopen(&file, path, "rb");  // "rb" = read binary
        ```

     2. 파일 크기 확인:
        ```c
        uint64_t size;
        ext4_fsize(&file, &size);
        ```

     3. 데이터 읽기:
        ```c
        char *buffer = malloc(size);
        size_t bytesRead;
        ext4_fread(&file, buffer, size, &bytesRead);
        ```

     4. 파일 닫기:
        ```c
        ext4_fclose(&file);
        ```


     【Swift 구현 예시】

     ```swift
     func readFile(at path: String) throws -> Data {
         guard _isMounted, let mp = mountPoint else {
             throw EXT4Error.notMounted
         }

         let fullPath = mp + "/" + normalizePath(path)

         // Step 1: 파일 열기
         var file = ext4_file()
         let openResult = ext4_fopen(&file, fullPath, "rb")
         guard openResult == EOK else {
             throw EXT4Error.fileNotFound(path: path)
         }
         defer { ext4_fclose(&file) }

         // Step 2: 파일 크기 확인
         var size: uint64_t = 0
         ext4_fsize(&file, &size)

         // Step 3: 버퍼 할당
         var buffer = Data(count: Int(size))
         var bytesRead: size_t = 0

         // Step 4: 데이터 읽기
         buffer.withUnsafeMutableBytes { ptr in
             ext4_fread(&file, ptr.baseAddress, size, &bytesRead)
         }

         // Step 5: 읽은 크기 확인
         guard bytesRead == size else {
             throw EXT4Error.ioError
         }

         return buffer
     }
     ```


     【withUnsafeMutableBytes 패턴】

     Swift Data를 C 함수에 전달:

     ```swift
     var buffer = Data(count: 1024)  // Swift Data
     buffer.withUnsafeMutableBytes { ptr in
         // ptr: UnsafeMutableRawBufferPointer
         // C 함수에 버퍼 주소 전달 가능
         ext4_fread(&file, ptr.baseAddress, size, &bytesRead)
         //                └────┬───────┘
         //                     버퍼 시작 주소 (void*)
     }
     // 블록 종료 후 버퍼 접근 금지 (Unsafe!)
     ```


     【대용량 파일 처리】

     100MB 이상 파일:
     - 한 번에 전체 읽기 시 메모리 부족 가능
     - 청크 단위로 읽기 권장

     ```swift
     let chunkSize = 1024 * 1024  // 1MB
     var totalData = Data()

     while bytesRead < size {
         var chunk = Data(count: chunkSize)
         // chunk 읽기...
         totalData.append(chunk)
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func readFile(at path: String) throws -> Data {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library
        // Example:
        /*
        guard let mp = mountPoint else {
            throw EXT4Error.notMounted
        }

        // Step 1: 전체 경로 생성
        let fullPath = mp + "/" + normalizePath(path)

        // Step 2: 파일 열기
        var file: ext4_file = ext4_file()
        let openResult = ext4_fopen(&file, fullPath, "rb")
        //                                           └─ "rb" = read binary
        guard openResult == EOK else {
            throw EXT4Error.fileNotFound(path: path)
        }

        // Step 3: 자동 닫기 설정
        defer { ext4_fclose(&file) }

        // Step 4: 파일 크기 확인
        var size: uint64_t = 0
        ext4_fsize(&file, &size)

        // Step 5: Swift Data 버퍼 할당
        // 0으로 초기화된 Data 생성
        var buffer = Data(count: Int(size))
        var bytesRead: size_t = 0

        // Step 6: C 함수로 데이터 읽기
        // withUnsafeMutableBytes: Swift Data → C 버퍼 포인터
        buffer.withUnsafeMutableBytes { ptr in
            // ptr.baseAddress: void* (C 버퍼 주소)
            ext4_fread(&file, ptr.baseAddress, size, &bytesRead)
        }

        // Step 7: 읽은 크기 검증
        guard bytesRead == size else {
            throw EXT4Error.ioError
        }

        return buffer
        */

        throw EXT4Error.unsupportedOperation
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     writeFile(data:to:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     데이터를 파일로 씁니다.


     【C 라이브러리 호출】

     readFile과 유사하나 "wb" (write binary) 모드 사용:

     ```swift
     func writeFile(data: Data, to path: String) throws {
         let fullPath = mountPoint! + "/" + normalizePath(path)

         // Step 1: 파일 열기 (쓰기 모드)
         var file = ext4_file()
         let openResult = ext4_fopen(&file, fullPath, "wb")
         //                                           └─ "wb" = write binary
         guard openResult == EOK else {
             throw EXT4Error.ioError
         }
         defer { ext4_fclose(&file) }

         // Step 2: 데이터 쓰기
         var bytesWritten: size_t = 0
         data.withUnsafeBytes { ptr in
             ext4_fwrite(&file, ptr.baseAddress, data.count, &bytesWritten)
         }

         // Step 3: 쓴 크기 확인
         guard bytesWritten == data.count else {
             throw EXT4Error.ioError
         }
     }
     ```


     【withUnsafeBytes vs withUnsafeMutableBytes】

     withUnsafeBytes:
     - 읽기 전용 버퍼
     - const void* 전달
     - ext4_fwrite()에 사용

     withUnsafeMutableBytes:
     - 쓰기 가능 버퍼
     - void* 전달
     - ext4_fread()에 사용

     ═════════════════════════════════════════════════════════════════════
     */

    func writeFile(data: Data, to path: String) throws {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library
        // Similar pattern as readFile but using ext4_fwrite
        // readFile과 유사하나 ext4_fwrite 사용

        throw EXT4Error.unsupportedOperation
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     fileExists(at:)
     ═════════════════════════════════════════════════════════════════════

     【C 라이브러리 호출】

     파일 존재 확인:

     ```swift
     func fileExists(at path: String) -> Bool {
         guard _isMounted, let mp = mountPoint else {
             return false
         }

         let fullPath = mp + "/" + normalizePath(path)

         // ext4_dir_entry_get: 파일 엔트리 조회
         var entry = ext4_direntry()
         let result = ext4_dir_entry_get(&entry, fullPath)

         return result == EOK
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func fileExists(at path: String) -> Bool {
        // 마운트되지 않으면 false
        guard _isMounted else {
            return false
        }

        // TODO: Integrate C library
        // Use ext4_dir_entry_get or similar function

        return false
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     getFileInfo(at:)
     ═════════════════════════════════════════════════════════════════════

     【C 라이브러리 호출】

     파일 정보 조회:

     ```swift
     func getFileInfo(at path: String) throws -> EXT4FileInfo {
         let fullPath = mountPoint! + "/" + normalizePath(path)

         var entry = ext4_direntry()
         let result = ext4_dir_entry_get(&entry, fullPath)
         guard result == EOK else {
             throw EXT4Error.fileNotFound(path: path)
         }

         return EXT4FileInfo(
             path: path,
             name: String(cString: entry.name),
             size: UInt64(entry.inode),
             isDirectory: entry.inode_type == EXT4_DE_DIR
         )
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func getFileInfo(at path: String) throws -> EXT4FileInfo {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library

        throw EXT4Error.unsupportedOperation
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     deleteFile(at:)
     ═════════════════════════════════════════════════════════════════════

     【C 라이브러리 호출】

     파일 삭제:

     ```swift
     func deleteFile(at path: String) throws {
         let fullPath = mountPoint! + "/" + normalizePath(path)

         // ext4_fremove: 파일 삭제
         let result = ext4_fremove(fullPath)
         guard result == EOK else {
             throw EXT4Error.ioError
         }
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func deleteFile(at path: String) throws {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library
        // Use ext4_fremove()

        throw EXT4Error.unsupportedOperation
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     createDirectory(at:)
     ═════════════════════════════════════════════════════════════════════

     【C 라이브러리 호출】

     디렉토리 생성:

     ```swift
     func createDirectory(at path: String) throws {
         let fullPath = mountPoint! + "/" + normalizePath(path)

         // ext4_dir_mk: 디렉토리 생성
         let result = ext4_dir_mk(fullPath)
         guard result == EOK else {
             throw EXT4Error.ioError
         }
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func createDirectory(at path: String) throws {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // TODO: Integrate C library
        // Use ext4_dir_mk()

        throw EXT4Error.unsupportedOperation
    }
}

// MARK: - C Library Integration Checklist

/*
 ═════════════════════════════════════════════════════════════════════════
 C/C++ 라이브러리 통합 체크리스트
 ═════════════════════════════════════════════════════════════════════════

 【1. 라이브러리 준비】

 ✓ lwext4 라이브러리 다운로드
   https://github.com/gkostka/lwext4

 ✓ 소스 파일 추가
   BlackboxPlayer/Utilities/EXT4/
   ├── ext4.c
   ├── ext4_blockdev.c
   ├── ext4_fs.c
   ├── ext4_dir.c
   └── 기타 필요한 파일들

 ✓ 헤더 파일 추가
   BlackboxPlayer/Utilities/EXT4/include/
   ├── ext4.h
   ├── ext4_blockdev.h
   ├── ext4_fs.h
   └── ext4_dir.h


 【2. Bridging Header 생성】

 파일: BlackboxPlayer-BridgingHeader.h

 ```c
 #ifndef BlackboxPlayer_BridgingHeader_h
 #define BlackboxPlayer_BridgingHeader_h

 // EXT4 라이브러리 헤더
 #import "ext4.h"
 #import "ext4_blockdev.h"
 #import "ext4_fs.h"
 #import "ext4_dir.h"

 #endif
 ```


 【3. 빌드 설정 (project.yml)】

 ```yaml
 targets:
   BlackboxPlayer:
     settings:
       # 헤더 검색 경로
       HEADER_SEARCH_PATHS:
         - $(PROJECT_DIR)/BlackboxPlayer/Utilities/EXT4/include

       # C 컴파일러 플래그
       OTHER_CFLAGS:
         - -DCONFIG_HAVE_OWN_ERRNO=1
         - -DCONFIG_DEBUG_PRINTF=0

       # Bridging Header 경로
       SWIFT_OBJC_BRIDGING_HEADER:
         $(PROJECT_DIR)/BlackboxPlayer/BlackboxPlayer-BridgingHeader.h
 ```


 【4. Stub 구현 제거】

 각 메서드에서:

 Before:
 ```swift
 func mount(devicePath: String) throws {
     guard !_isMounted else {
         throw EXT4Error.alreadyMounted
     }
     throw EXT4Error.unsupportedOperation  // ← 제거
 }
 ```

 After:
 ```swift
 func mount(devicePath: String) throws {
     guard !_isMounted else {
         throw EXT4Error.alreadyMounted
     }

     // 실제 C 라이브러리 호출
     var blockdev = ext4_blockdev()
     let bdResult = ext4_blockdev_init(&blockdev, devicePath, 512, 0)
     // ...
 }
 ```


 【5. 에러 코드 매핑】

 C 에러 코드 → Swift Error 변환 함수 추가:

 ```swift
 extension EXT4Bridge {
     private func convertError(_ code: Int32) -> EXT4Error {
         switch code {
         case EOK:
             fatalError("EOK should not be converted to error")
         case ENOENT:
             return .deviceNotFound
         case EACCES:
             return .permissionDenied
         case EIO:
             return .ioError
         case ENOMEM:
             return .insufficientSpace
         default:
             return .unknownError(code: Int(code))
         }
     }
 }
 ```


 【6. 테스트 체크리스트】

 ✓ 단위 테스트:
   1. mount/unmount 반복 테스트
   2. 작은 파일 읽기/쓰기 (< 1MB)
   3. 큰 파일 읽기/쓰기 (> 100MB)
   4. 디렉토리 목록 조회
   5. 파일 삭제 및 생성
   6. 디렉토리 생성

 ✓ 통합 테스트:
   1. 실제 SD 카드로 테스트
   2. 블랙박스 파일 구조 읽기
   3. 여러 파일 동시 읽기
   4. 장치 연결/해제 테스트

 ✓ 에러 시나리오:
   1. 장치 없음
   2. 손상된 파일 시스템
   3. 권한 부족
   4. 디스크 공간 부족
   5. 장치 갑작스런 제거

 ✓ 성능 테스트:
   1. 100MB 파일 읽기 속도
   2. 1000개 파일 목록 조회 속도
   3. 메모리 사용량
   4. CPU 사용률

 ✓ 메모리 누수:
   1. Instruments로 Leaks 확인
   2. 장시간 실행 테스트
   3. 반복 mount/unmount


 【7. 에러 로깅】

 디버깅을 위한 로그 추가:

 ```swift
 func mount(devicePath: String) throws {
     print("[EXT4] Mounting device: \(devicePath)")

     let result = ext4_mount(...)
     if result != EOK {
         let errorMsg = String(cString: strerror(result))
         print("[EXT4] Mount failed: \(errorMsg) (code: \(result))")
         throw EXT4Error.mountFailed(reason: errorMsg)
     }

     print("[EXT4] Mount successful")
 }
 ```


 【8. 성능 최적화】

 ✓ 버퍼링:
   - 작은 파일은 한 번에 읽기
   - 큰 파일은 청크 단위 읽기

 ✓ 캐싱:
   - 자주 접근하는 파일 정보 캐싱
   - LRU 캐시 구현

 ✓ 비동기 처리:
   - DispatchQueue.global()로 백그라운드 실행
   - UI 블로킹 방지

 ✓ 메모리 관리:
   - autoreleasepool 사용
   - 대용량 파일 처리 시 메모리 해제


 【9. 안전성】

 ✓ 경로 검증:
   - 상대 경로 변환
   - "..", "." 처리
   - 특수 문자 필터링

 ✓ 타임아웃:
   - 장시간 I/O 작업 타임아웃
   - DispatchWorkItem.cancel()

 ✓ 인터럽트 처리:
   - 사용자 취소 지원
   - 부분 읽기 복구


 【10. 배포 전 최종 확인】

 ✓ 실제 블랙박스 SD 카드 테스트
 ✓ 다양한 블랙박스 모델 호환성 확인
 ✓ 에러 메시지 사용자 친화적으로 변경
 ✓ 메모리 프로파일링 완료
 ✓ 성능 벤치마크 달성
 ✓ 문서화 업데이트

 ═════════════════════════════════════════════════════════════════════════
 */

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 가이드 예시
 ═══════════════════════════════════════════════════════════════════════════

 【전체 통합 프로세스】

 ┌─────────────────────────────────────────────────────────────┐
 │                                                             │
 │ 1. 라이브러리 준비                                           │
 │    ├── lwext4 소스 다운로드                                  │
 │    ├── 프로젝트에 추가                                       │
 │    └── 헤더 경로 설정                                        │
 │                                                             │
 │ 2. Bridging Header 작성                                     │
 │    ├── BlackboxPlayer-BridgingHeader.h 생성                 │
 │    └── #import "ext4.h" 추가                                │
 │                                                             │
 │ 3. 빌드 설정                                                │
 │    ├── HEADER_SEARCH_PATHS 설정                             │
 │    ├── OTHER_CFLAGS 추가                                    │
 │    └── Bridging Header 경로 지정                            │
 │                                                             │
 │ 4. Stub 구현 제거                                            │
 │    ├── EXT4Bridge.swift 열기                                │
 │    ├── TODO 주석 확인                                        │
 │    └── 실제 C 함수 호출 코드 작성                            │
 │                                                             │
 │ 5. 컴파일 및 테스트                                          │
 │    ├── Xcode 빌드 (Cmd+B)                                   │
 │    ├── 에러 수정                                            │
 │    └── 단위 테스트 실행                                      │
 │                                                             │
 │ 6. 통합 테스트                                               │
 │    ├── 실제 SD 카드로 테스트                                 │
 │    ├── 블랙박스 파일 읽기                                    │
 │    └── 성능 확인                                            │
 │                                                             │
 │ 7. 최적화                                                   │
 │    ├── Instruments 프로파일링                                │
 │    ├── 메모리 누수 확인                                      │
 │    └── 성능 개선                                            │
 │                                                             │
 │ 8. 배포                                                     │
 │    ├── 최종 테스트                                           │
 │    ├── 문서 업데이트                                         │
 │    └── 릴리스                                               │
 │                                                             │
 └─────────────────────────────────────────────────────────────┘


 【실제 사용 예시】

 ```swift
 import Foundation

 // 1. EXT4Bridge 인스턴스 생성
 let bridge = EXT4Bridge()

 do {
     // 2. SD 카드 마운트
     print("마운트 중...")
     try bridge.mount(devicePath: "/dev/disk2s1")
     print("마운트 성공!")

     // 3. 장치 정보 확인
     let info = try bridge.getDeviceInfo()
     print("볼륨: \(info.volumeName)")
     print("용량: \(info.totalSize / 1024 / 1024 / 1024) GB")
     print("여유: \(info.freeSpace / 1024 / 1024 / 1024) GB")

     // 4. 파일 목록 조회
     let files = try bridge.listFiles(at: "normal")
     print("\n파일 목록:")
     for file in files {
         let sizeInMB = file.size / 1024 / 1024
         print("  - \(file.name) (\(sizeInMB) MB)")
     }

     // 5. 비디오 파일 읽기
     print("\n비디오 파일 읽기 중...")
     let videoPath = "normal/2025_01_10_09_00_00_F.mp4"
     let videoData = try bridge.readFile(at: videoPath)
     print("읽기 완료: \(videoData.count) bytes")

     // 6. 언마운트
     print("\n언마운트 중...")
     try bridge.unmount()
     print("언마운트 완료!")

 } catch {
     print("에러 발생: \(error)")
 }
 ```


 【출력 예시】

 마운트 중...
 [EXT4] Mounting device: /dev/disk2s1
 [EXT4] Block device initialized
 [EXT4] Device registered
 [EXT4] Filesystem mounted
 마운트 성공!
 볼륨: DASHCAM_SD
 용량: 32 GB
 여유: 28 GB

 파일 목록:
   - 2025_01_10_09_00_00_F.mp4 (100 MB)
   - 2025_01_10_09_00_00_R.mp4 (80 MB)
   - 2025_01_10_09_01_00_F.mp4 (100 MB)
   - 2025_01_10_09_01_00_R.mp4 (80 MB)

 비디오 파일 읽기 중...
 [EXT4] Opening file: /mnt/ext4/normal/2025_01_10_09_00_00_F.mp4
 [EXT4] File size: 104857600 bytes
 [EXT4] Reading data...
 읽기 완료: 104857600 bytes

 언마운트 중...
 [EXT4] Unmounting filesystem
 [EXT4] Device unregistered
 언마운트 완료!

 ═══════════════════════════════════════════════════════════════════════════
 */
