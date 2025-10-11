/*
 ═══════════════════════════════════════════════════════════════════════════
 MockEXT4FileSystem.swift
 BlackboxPlayer

 테스트 및 개발용 Mock EXT4 파일 시스템
 ═══════════════════════════════════════════════════════════════════════════

 【Mock 객체란?】

 Mock (모의 객체)는 실제 객체를 흉내내는 테스트용 대체 객체입니다.

 실제 EXT4 파일 시스템을 사용하려면:
 ✗ SD 카드 필요
 ✗ C/C++ 라이브러리 필요
 ✗ Linux 환경 필요 (macOS는 EXT4 미지원)
 ✗ 디버깅 어려움

 Mock을 사용하면:
 ✓ SD 카드 없이 개발
 ✓ 순수 Swift로 구현
 ✓ macOS에서 개발 가능
 ✓ 빠른 테스트
 ✓ 예측 가능한 데이터


 【Mock 객체 패턴】

 ┌──────────────────────────────────────────────────────────────┐
 │                                                              │
 │  EXT4FileSystemProtocol (프로토콜)                           │
 │  ├── mount(devicePath:)                                      │
 │  ├── unmount()                                               │
 │  ├── readFile(at:)                                           │
 │  └── writeFile(data:to:)                                     │
 │                                                              │
 │         ▲                           ▲                        │
 │         │                           │                        │
 │         │ 구현                      │ 구현                   │
 │         │                           │                        │
 │  ┌──────┴──────────┐      ┌────────┴────────────┐           │
 │  │ EXT4Bridge      │      │ MockEXT4FileSystem  │           │
 │  │ (실제 구현)     │      │ (Mock 구현)         │           │
 │  │                 │      │                     │           │
 │  │ - C++ 라이브러리 │      │ - 메모리 저장소     │           │
 │  │ - SD 카드 필요   │      │ - 샘플 데이터      │           │
 │  │ - Linux 전용    │      │ - macOS 가능       │           │
 │  └─────────────────┘      └─────────────────────┘           │
 │                                                              │
 └──────────────────────────────────────────────────────────────┘

 애플리케이션은 프로토콜만 의존하므로:
 - 개발 시: MockEXT4FileSystem 사용
 - 배포 시: EXT4Bridge 사용


 【인메모리 파일 시스템】

 실제 SD 카드:
 ┌────────────────────────────────────────┐
 │ /dev/disk2 (SD 카드)                   │
 │                                        │
 │ /normal/                               │
 │   ├── 20250110_090000_F.mp4 (100MB)   │
 │   └── 20250110_090000_R.mp4 (80MB)    │
 │                                        │
 │ /event/                                │
 │   └── 20250110_103015_F.mp4 (50MB)    │
 └────────────────────────────────────────┘

 Mock 파일 시스템 (메모리):
 ┌────────────────────────────────────────┐
 │ fileSystem: [String: Data]             │
 │                                        │
 │ [                                      │
 │   "normal/20250110_090000_F.mp4": Data(100MB),│
 │   "normal/20250110_090000_R.mp4": Data(80MB), │
 │   "event/20250110_103015_F.mp4": Data(50MB)   │
 │ ]                                      │
 │                                        │
 │ fileInfoCache: [String: EXT4FileInfo]  │
 │ [                                      │
 │   "normal/20250110_090000_F.mp4": {    │
 │     size: 104857600,                   │
 │     isDirectory: false,                │
 │     modificationDate: Date()           │
 │   }                                    │
 │ ]                                      │
 └────────────────────────────────────────┘


 【샘플 데이터 생성】

 createSampleFiles()는 초기화 시 호출되어
 실제 블랙박스와 유사한 샘플 파일을 자동 생성합니다:

 normal/ (일반 녹화)
 ├── 2025_01_10_09_00_00_F.mp4 (100MB) - 전방 카메라
 ├── 2025_01_10_09_00_00_R.mp4 (80MB)  - 후방 카메라
 ├── 2025_01_10_09_00_00_F.gps (1KB)   - GPS 데이터
 └── 2025_01_10_09_00_00_F.gsn (2KB)   - G-센서 데이터

 event/ (이벤트 녹화)
 └── 2025_01_10_10_30_15_F.mp4 (50MB)

 parking/ (주차 모드)
 └── 2025_01_10_18_00_00_F.mp4 (30MB)


 【테스트 활용】

 ```swift
 // Unit Test 예시
 func testFileScanning() {
     // Given: Mock 파일 시스템 준비
     let mockFS = MockEXT4FileSystem()
     try! mockFS.mount(devicePath: "/dev/disk2")

     // When: 파일 스캔
     let scanner = FileScanner(fileSystem: mockFS)
     let files = try! scanner.scan()

     // Then: 예상 파일 개수 확인
     XCTAssertEqual(files.count, 13)  // 샘플 파일 13개
 }

 // SwiftUI Preview 예시
 struct ContentView_Previews: PreviewProvider {
     static var previews: some View {
         ContentView()
             .environmentObject(MockEXT4FileSystem())
             // Mock 데이터로 UI 미리보기
     }
 }
 ```


 【장점】

 1. 빠른 개발:
    - SD 카드 없이 macOS에서 즉시 개발 가능
    - C++ 라이브러리 컴파일 불필요

 2. 신뢰성 있는 테스트:
    - 예측 가능한 샘플 데이터
    - 오류 시나리오 재현 가능
    - 병렬 테스트 가능 (각 테스트마다 독립적인 Mock)

 3. 디버깅 용이:
    - 메모리에서 직접 데이터 확인
    - reset() 으로 초기 상태 복원
    - addTestFile() 로 특정 시나리오 구성

 4. 프로토콜 준수:
    - EXT4FileSystemProtocol 완전 구현
    - 실제 구현과 인터페이스 동일
    - 교체 가능 (Liskov Substitution Principle)


 【제한사항】

 ✗ 실제 C/C++ EXT4 라이브러리 동작과 100% 동일하지 않음
 ✗ 디스크 I/O 성능 테스트 불가
 ✗ SD 카드 물리적 오류 시뮬레이션 불가
 ✗ 실제 파일 시스템 복잡성 (권한, 링크 등) 단순화


 【사용 시나리오】

 1. 로컬 개발:
    ```swift
    #if DEBUG
    let fileSystem: EXT4FileSystemProtocol = MockEXT4FileSystem()
    #else
    let fileSystem = EXT4Bridge()
    #endif
    ```

 2. Unit Test:
    ```swift
    func testFileManager() {
         let mock = MockEXT4FileSystem()
         let manager = FileManagerService(fileSystem: mock)
         // ...
    }
    ```

 3. UI Preview:
    ```swift
    struct PlayerView_Previews: PreviewProvider {
         static var previews: some View {
             PlayerView()
                 .environmentObject(MockEXT4FileSystem())
         }
    }
    ```

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

/*
 ─────────────────────────────────────────────────────────────────────────
 MockEXT4FileSystem 클래스
 ─────────────────────────────────────────────────────────────────────────

 【역할】

 EXT4FileSystemProtocol의 Mock 구현으로,
 실제 SD 카드 없이 개발 및 테스트를 가능하게 합니다.


 【저장소 구조】

 1. fileSystem: [String: Data]
    - 파일 경로 → 파일 내용
    - 메모리에 저장
    - 예: ["normal/video.mp4": Data(100MB)]

 2. fileInfoCache: [String: EXT4FileInfo]
    - 파일 경로 → 메타데이터
    - 크기, 날짜, 디렉토리 여부
    - 예: ["normal/video.mp4": EXT4FileInfo(...)]


 【동작 방식】

 ┌──────────────────────────────────────────────────────┐
 │                                                      │
 │ 초기화 (init)                                         │
 │   │                                                  │
 │   ▼                                                  │
 │ createSampleFiles()                                  │
 │   - 샘플 블랙박스 파일 생성                           │
 │   - fileSystem에 Data 추가                           │
 │   - fileInfoCache에 메타데이터 추가                   │
 │                                                      │
 │ mount("/dev/disk2")                                  │
 │   - _isMounted = true                                │
 │   - 실제 마운트는 하지 않음 (이미 메모리에 있음)       │
 │                                                      │
 │ readFile("normal/video.mp4")                         │
 │   - fileSystem["normal/video.mp4"] 반환              │
 │                                                      │
 │ listFiles("normal")                                  │
 │   - "normal/" 로 시작하는 모든 키 검색                │
 │   - EXT4FileInfo 배열 반환                           │
 │                                                      │
 │ unmount()                                            │
 │   - _isMounted = false                               │
 │   - 데이터는 유지됨 (메모리에 계속 존재)              │
 │                                                      │
 └──────────────────────────────────────────────────────┘


 【프로토콜 준수】

 EXT4FileSystemProtocol의 모든 메서드를 구현하므로
 실제 EXT4Bridge와 교체 가능합니다:

 ```swift
 // 개발 시
 let fileSystem: EXT4FileSystemProtocol = MockEXT4FileSystem()

 // 배포 시
 let fileSystem: EXT4FileSystemProtocol = EXT4Bridge()

 // 사용 코드는 동일
 try fileSystem.mount(devicePath: "/dev/disk2")
 let files = try fileSystem.listFiles(at: "normal")
 ```

 ─────────────────────────────────────────────────────────────────────────
 */

/// Mock EXT4 file system implementation for testing
/// Uses in-memory storage to simulate EXT4 operations
class MockEXT4FileSystem: EXT4FileSystemProtocol {

    // MARK: - Properties

    /*
     ─────────────────────────────────────────────────────────────────────
     저장소 속성
     ─────────────────────────────────────────────────────────────────────

     【_isMounted】

     마운트 상태를 나타내는 플래그.

     실제 파일 시스템:
     - mount() 호출 시 커널에 마운트 요청
     - SD 카드를 파일 시스템에 연결

     Mock 파일 시스템:
     - mount() 호출 시 플래그만 변경
     - 데이터는 이미 메모리에 존재


     【currentDevicePath】

     마운트된 장치 경로 (예: "/dev/disk2")

     실제로는 사용되지 않지만,
     getDeviceInfo()에서 반환하기 위해 저장.


     【fileSystem: [String: Data]】

     파일 내용을 저장하는 Dictionary.

     Key: 파일 경로 (예: "normal/video.mp4")
     Value: 파일 데이터 (Data)

     예시:
     [
       "normal/2025_01_10_09_00_00_F.mp4": Data(100MB),
       "event/2025_01_10_10_30_15_F.mp4": Data(50MB)
     ]

     메모리 사용:
     - 실제 크기의 Data를 생성
     - 100MB 파일 = 메모리 100MB 사용


     【fileInfoCache: [String: EXT4FileInfo]】

     파일 메타데이터를 저장하는 Dictionary.

     Key: 파일 경로
     Value: 메타데이터 (크기, 날짜, isDirectory 등)

     예시:
     [
       "normal/2025_01_10_09_00_00_F.mp4": EXT4FileInfo(
         path: "normal/2025_01_10_09_00_00_F.mp4",
         name: "2025_01_10_09_00_00_F.mp4",
         size: 104857600,
         isDirectory: false,
         modificationDate: Date()
       )
     ]

     ─────────────────────────────────────────────────────────────────────
     */

    private var _isMounted: Bool = false
    private var currentDevicePath: String?

    /// 파일 내용 저장소 (경로 → 데이터)
    private var fileSystem: [String: Data] = [:]

    /// 파일 메타데이터 캐시 (경로 → 정보)
    private var fileInfoCache: [String: EXT4FileInfo] = [:]

    /*
     ─────────────────────────────────────────────────────────────────────
     isMounted: 마운트 상태 (읽기 전용)
     ─────────────────────────────────────────────────────────────────────

     프로토콜 요구사항으로, 외부에서 마운트 상태를 확인할 수 있습니다.

     ```swift
     let mockFS = MockEXT4FileSystem()
     print(mockFS.isMounted)  // false

     try mockFS.mount(devicePath: "/dev/disk2")
     print(mockFS.isMounted)  // true
     ```

     ─────────────────────────────────────────────────────────────────────
     */

    var isMounted: Bool {
        return _isMounted
    }

    // MARK: - Initialization

    /*
     ═════════════════════════════════════════════════════════════════════
     init()
     ═════════════════════════════════════════════════════════════════════

     【기능】

     Mock 파일 시스템을 초기화하고 샘플 파일을 생성합니다.


     【초기화 과정】

     1. 빈 저장소 생성:
        - fileSystem = [:]
        - fileInfoCache = [:]

     2. 샘플 파일 생성:
        - createSampleFiles() 호출
        - 블랙박스 파일 구조 재현


     【사용 예시】

     ```swift
     // 자동으로 샘플 파일이 생성됨
     let mockFS = MockEXT4FileSystem()

     // mount 후 즉시 사용 가능
     try mockFS.mount(devicePath: "/dev/disk2")
     let files = try mockFS.listFiles(at: "normal")
     print("샘플 파일 개수: \(files.count)")
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    init() {
        // Pre-populate with sample dashcam files for testing
        // 초기화 시 샘플 블랙박스 파일 자동 생성
        createSampleFiles()
    }

    // MARK: - Device Management

    /*
     ═════════════════════════════════════════════════════════════════════
     mount(devicePath:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     가상 장치를 마운트합니다.


     【실제 EXT4 vs Mock】

     실제 EXT4:
     1. 장치 열기 (open)
     2. Superblock 읽기
     3. 파일 시스템 검증
     4. 메모리 구조 초기화
     5. 커널에 등록

     Mock:
     1. 장치 경로 검증 (형식만)
     2. _isMounted 플래그 변경
     ➜ 데이터는 이미 메모리에 존재


     【매개변수】

     - devicePath: 장치 경로 (예: "/dev/disk2")
       형식 검증만 수행, 실제 장치는 필요 없음


     【에러】

     1. EXT4Error.alreadyMounted:
        이미 마운트된 상태에서 재마운트 시도

     2. EXT4Error.deviceNotFound:
        devicePath가 "/dev/"로 시작하지 않음


     【예시】

     ```swift
     let mockFS = MockEXT4FileSystem()

     // 성공
     try mockFS.mount(devicePath: "/dev/disk2")
     print("마운트 성공")

     // 실패: 이미 마운트됨
     try mockFS.mount(devicePath: "/dev/disk3")
     // Error: alreadyMounted

     // 실패: 잘못된 경로
     try mockFS.mount(devicePath: "/invalid/path")
     // Error: deviceNotFound
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func mount(devicePath: String) throws {
        // Step 1: 이중 마운트 방지
        // 이미 마운트되어 있으면 에러
        guard !_isMounted else {
            throw EXT4Error.alreadyMounted
        }

        // Step 2: 장치 경로 형식 검증
        // "/dev/"로 시작해야 함 (Linux/macOS 장치 경로 규칙)
        guard devicePath.starts(with: "/dev/") else {
            throw EXT4Error.deviceNotFound
        }

        // Step 3: 마운트 시뮬레이션
        // 실제로는 아무것도 하지 않고 플래그만 변경
        currentDevicePath = devicePath
        _isMounted = true

        // 참고: 실제 EXT4Bridge에서는 여기서
        // C++ 라이브러리를 호출하여 실제 마운트 수행
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     unmount()
     ═════════════════════════════════════════════════════════════════════

     【기능】

     마운트를 해제합니다.


     【실제 EXT4 vs Mock】

     실제 EXT4:
     1. 버퍼 플러시 (변경사항 디스크에 쓰기)
     2. 리소스 해제
     3. 커널에서 제거
     4. 장치 닫기

     Mock:
     1. _isMounted 플래그 변경
     ➜ 데이터는 메모리에 유지됨


     【에러】

     EXT4Error.notMounted:
     마운트되지 않은 상태에서 unmount 시도


     【주의】

     Mock에서는 unmount 후에도 데이터가 메모리에 남아있습니다.
     완전 초기화가 필요하면 reset() 사용.

     ```swift
     let mockFS = MockEXT4FileSystem()
     try mockFS.mount(devicePath: "/dev/disk2")

     // 파일 쓰기
     try mockFS.writeFile(data: myData, to: "test.txt")

     // 언마운트
     try mockFS.unmount()

     // 재마운트
     try mockFS.mount(devicePath: "/dev/disk2")

     // 이전 데이터 여전히 존재
     let exists = mockFS.fileExists(at: "test.txt")  // true
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func unmount() throws {
        // Step 1: 마운트 상태 확인
        // 마운트되지 않았으면 에러
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // Step 2: 언마운트 시뮬레이션
        // 플래그만 변경, 데이터는 유지
        currentDevicePath = nil
        _isMounted = false

        // 참고: 실제 EXT4Bridge에서는
        // 버퍼 플러시 및 리소스 해제 수행
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     getDeviceInfo()
     ═════════════════════════════════════════════════════════════════════

     【기능】

     장치 정보 (용량, 여유 공간 등)를 반환합니다.


     【계산 방식】

     1. 총 용량: 32GB (고정값)
        - 일반적인 블랙박스 SD 카드 크기

     2. 사용 공간: fileSystem의 모든 Data 크기 합계
        totalSize = Σ(file.size)

     3. 여유 공간: 총 용량 - 사용 공간
        freeSpace = 32GB - totalSize


     【반환값】

     EXT4DeviceInfo:
     - devicePath: 마운트된 장치 경로
     - volumeName: "DASHCAM_SD" (고정)
     - totalSize: 32GB
     - freeSpace: 계산된 여유 공간
     - blockSize: 4096 bytes (EXT4 기본값)
     - isMounted: true


     【예시】

     ```swift
     let mockFS = MockEXT4FileSystem()
     try mockFS.mount(devicePath: "/dev/disk2")

     let info = try mockFS.getDeviceInfo()
     print("장치: \(info.devicePath)")
     print("볼륨: \(info.volumeName)")
     print("총 용량: \(info.totalSize / 1024 / 1024 / 1024) GB")
     print("여유 공간: \(info.freeSpace / 1024 / 1024 / 1024) GB")

     // 출력:
     // 장치: /dev/disk2
     // 볼륨: DASHCAM_SD
     // 총 용량: 32 GB
     // 여유 공간: 31 GB (샘플 파일 약 1GB)
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func getDeviceInfo() throws -> EXT4DeviceInfo {
        // Step 1: 마운트 상태 확인
        guard _isMounted, let devicePath = currentDevicePath else {
            throw EXT4Error.notMounted
        }

        // Step 2: 사용 중인 공간 계산
        // fileSystem의 모든 Data 크기를 합산
        let totalSize: UInt64 = fileSystem.values.reduce(0) { $0 + UInt64($1.count) }

        // Step 3: 총 용량 설정
        // 32GB = 32 × 1024 × 1024 × 1024 bytes
        let mockTotalCapacity: UInt64 = 32 * 1024 * 1024 * 1024  // 32 GB

        // Step 4: 여유 공간 계산
        let freeSpace = mockTotalCapacity - totalSize

        // Step 5: 장치 정보 반환
        return EXT4DeviceInfo(
            devicePath: devicePath,
            volumeName: "DASHCAM_SD",        // 블랙박스 SD 카드 이름
            totalSize: mockTotalCapacity,
            freeSpace: freeSpace,
            blockSize: 4096,                 // EXT4 기본 블록 크기
            isMounted: true
        )
    }

    // MARK: - File Operations

    /*
     ═════════════════════════════════════════════════════════════════════
     listFiles(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     지정된 디렉토리의 파일 및 하위 디렉토리 목록을 반환합니다.


     【알고리즘】

     1. 경로 정규화:
        "normal" → "normal"
        "/normal" → "normal"
        "normal/" → "normal"

     2. 검색 접두사 생성:
        path = "normal" → searchPrefix = "normal/"

     3. 파일 시스템 순회:
        for filePath in fileSystem.keys {
          if filePath.hasPrefix("normal/") {
            // 직접 자식인지 확인
          }
        }

     4. 직접 자식 판단:
        - "normal/video.mp4" → 직접 자식 (포함)
        - "normal/sub/video.mp4" → 하위 디렉토리 (제외)

     5. 디렉토리 추출:
        - "normal/sub/video.mp4" → "sub" 디렉토리 추가


     【예시】

     파일 구조:
     normal/
     ├── 20250110_090000_F.mp4
     ├── 20250110_090000_R.mp4
     └── metadata/
         ├── gps.txt
         └── gsensor.txt

     ```swift
     // 루트 디렉토리 조회
     let rootFiles = try mockFS.listFiles(at: "")
     // Result: ["normal"] (디렉토리만)

     // normal 디렉토리 조회
     let normalFiles = try mockFS.listFiles(at: "normal")
     // Result:
     // - 20250110_090000_F.mp4 (파일)
     // - 20250110_090000_R.mp4 (파일)
     // - metadata (디렉토리)

     // metadata 디렉토리 조회
     let metadataFiles = try mockFS.listFiles(at: "normal/metadata")
     // Result:
     // - gps.txt
     // - gsensor.txt
     ```


     【정렬】

     파일명 기준 오름차순 정렬:
     - 알파벳순
     - 숫자는 문자열로 비교


     【반환값】

     [EXT4FileInfo]: 파일/디렉토리 정보 배열

     ═════════════════════════════════════════════════════════════════════
     */

    func listFiles(at path: String) throws -> [EXT4FileInfo] {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // Step 2: 경로 정규화
        // "normal", "/normal", "normal/" → "normal"
        let normalizedPath = normalizePath(path)

        // Step 3: 검색 접두사 생성
        // 루트: "" → ""
        // 일반: "normal" → "normal/"
        let searchPrefix = normalizedPath.isEmpty ? "" : normalizedPath + "/"

        // Step 4: 결과 저장소 초기화
        var files: [EXT4FileInfo] = []
        var directories: Set<String> = []  // 중복 제거를 위해 Set 사용

        // Step 5: 파일 시스템 순회
        for filePath in fileSystem.keys {
            // 검색 경로의 하위인지 확인
            if filePath.hasPrefix(searchPrefix) {
                // 상대 경로 계산
                // "normal/video.mp4" → "video.mp4"
                // "normal/sub/video.mp4" → "sub/video.mp4"
                let relativePath = String(filePath.dropFirst(searchPrefix.count))

                // Step 5-1: 직접 자식 파일인지 확인
                // "video.mp4" → 직접 자식 (포함)
                // "sub/video.mp4" → 하위 디렉토리 (제외, 디렉토리만 추가)
                if !relativePath.contains("/") {
                    // 직접 자식 파일
                    if let info = fileInfoCache[filePath] {
                        files.append(info)
                    }
                } else {
                    // Step 5-2: 하위 디렉토리 추출
                    // "sub/video.mp4" → "sub"
                    if let firstSlash = relativePath.firstIndex(of: "/") {
                        let dirName = String(relativePath[..<firstSlash])
                        directories.insert(dirName)  // Set이므로 중복 자동 제거
                    }
                }
            }
        }

        // Step 6: 명시적으로 생성된 디렉토리 확인
        // createDirectory()로 생성된 빈 디렉토리 처리
        for (cachePath, info) in fileInfoCache where info.isDirectory {
            if cachePath.hasPrefix(searchPrefix) {
                let relativePath = String(cachePath.dropFirst(searchPrefix.count))

                // 직접 자식 디렉토리인지 확인
                if !relativePath.contains("/") {
                    directories.insert(info.name)
                }
            }
        }

        // Step 7: 디렉토리 정보 추가
        for dirName in directories {
            let dirPath = normalizedPath.isEmpty ? dirName : "\(normalizedPath)/\(dirName)"

            // 캐시된 정보가 있으면 사용, 없으면 새로 생성
            if let cachedInfo = fileInfoCache[dirPath] {
                files.append(cachedInfo)
            } else {
                files.append(EXT4FileInfo(
                    path: dirPath,
                    name: dirName,
                    size: 0,               // 디렉토리는 크기 0
                    isDirectory: true,
                    modificationDate: Date()
                ))
            }
        }

        // Step 8: 파일명 기준 정렬
        return files.sorted { $0.name < $1.name }
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     readFile(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     파일 내용을 읽어 Data로 반환합니다.


     【동작】

     실제 EXT4:
     1. inode 조회
     2. 블록 위치 파악
     3. 디스크에서 읽기
     4. 버퍼로 복사

     Mock:
     1. Dictionary에서 조회
     2. Data 반환


     【성능】

     실제 EXT4: O(블록 수)
     Mock: O(1) (Dictionary 조회)

     ➜ Mock이 훨씬 빠름


     【예시】

     ```swift
     // 비디오 파일 읽기
     let videoData = try mockFS.readFile(at: "normal/20250110_090000_F.mp4")
     print("파일 크기: \(videoData.count) bytes")

     // GPS 파일 읽기
     let gpsData = try mockFS.readFile(at: "normal/20250110_090000_F.gps")
     let parser = GPSParser()
     let points = parser.parseNMEA(data: gpsData, baseDate: Date())
     ```


     【에러】

     1. EXT4Error.notMounted: 마운트되지 않음
     2. EXT4Error.fileNotFound: 파일 없음

     ═════════════════════════════════════════════════════════════════════
     */

    func readFile(at path: String) throws -> Data {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // Step 2: 경로 정규화
        let normalizedPath = normalizePath(path)

        // Step 3: Dictionary에서 조회
        guard let data = fileSystem[normalizedPath] else {
            throw EXT4Error.fileNotFound(path: path)
        }

        // Step 4: 데이터 반환
        // 메모리 복사 발생 (Data는 value type)
        return data
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     writeFile(data:to:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     데이터를 파일로 씁니다.


     【동작】

     1. 공간 확인:
        - getDeviceInfo()로 여유 공간 조회
        - 데이터 크기와 비교

     2. Dictionary에 저장:
        - fileSystem[path] = data

     3. 메타데이터 업데이트:
        - fileInfoCache[path] = EXT4FileInfo(...)


     【공간 관리】

     ```swift
     let mockFS = MockEXT4FileSystem()
     try mockFS.mount(devicePath: "/dev/disk2")

     // 32GB Mock 장치
     let info = try mockFS.getDeviceInfo()
     print("여유 공간: \(info.freeSpace / 1024 / 1024 / 1024) GB")

     // 큰 파일 쓰기
     let bigData = Data(count: 10 * 1024 * 1024 * 1024)  // 10GB
     try mockFS.writeFile(data: bigData, to: "big.dat")

     // 공간 부족 시도
     let hugeData = Data(count: 30 * 1024 * 1024 * 1024)  // 30GB
     try mockFS.writeFile(data: hugeData, to: "huge.dat")
     // Error: insufficientSpace
     ```


     【에러】

     1. EXT4Error.notMounted: 마운트되지 않음
     2. EXT4Error.insufficientSpace: 공간 부족

     ═════════════════════════════════════════════════════════════════════
     */

    func writeFile(data: Data, to path: String) throws {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // Step 2: 경로 정규화
        let normalizedPath = normalizePath(path)

        // Step 3: 공간 확인
        let deviceInfo = try getDeviceInfo()
        if UInt64(data.count) > deviceInfo.freeSpace {
            throw EXT4Error.insufficientSpace
        }

        // Step 4: 파일 저장
        fileSystem[normalizedPath] = data

        // Step 5: 메타데이터 생성
        let fileName = (normalizedPath as NSString).lastPathComponent
        fileInfoCache[normalizedPath] = EXT4FileInfo(
            path: normalizedPath,
            name: fileName,
            size: UInt64(data.count),
            isDirectory: false,
            creationDate: Date(),
            modificationDate: Date()
        )
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     fileExists(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     파일이 존재하는지 확인합니다.


     【반환값】

     - true: 파일 존재
     - false: 파일 없음 또는 마운트되지 않음


     【예시】

     ```swift
     if mockFS.fileExists(at: "normal/video.mp4") {
         let data = try mockFS.readFile(at: "normal/video.mp4")
         // 파일 처리...
     } else {
         print("파일 없음")
     }
     ```


     【주의】

     마운트되지 않은 경우에도 false 반환 (에러 발생 안 함)

     ═════════════════════════════════════════════════════════════════════
     */

    func fileExists(at path: String) -> Bool {
        // 마운트되지 않으면 false
        guard _isMounted else {
            return false
        }

        // 경로 정규화 후 Dictionary 조회
        let normalizedPath = normalizePath(path)
        return fileSystem[normalizedPath] != nil
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     getFileInfo(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     파일 메타데이터를 반환합니다.


     【반환값】

     EXT4FileInfo:
     - path: 파일 경로
     - name: 파일명
     - size: 파일 크기 (bytes)
     - isDirectory: 디렉토리 여부
     - creationDate: 생성 날짜
     - modificationDate: 수정 날짜


     【예시】

     ```swift
     let info = try mockFS.getFileInfo(at: "normal/video.mp4")
     print("파일명: \(info.name)")
     print("크기: \(info.size / 1024 / 1024) MB")
     print("수정일: \(info.modificationDate)")
     print("디렉토리: \(info.isDirectory ? "예" : "아니오")")
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func getFileInfo(at path: String) throws -> EXT4FileInfo {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // Step 2: 경로 정규화
        let normalizedPath = normalizePath(path)

        // Step 3: 캐시에서 조회
        guard let info = fileInfoCache[normalizedPath] else {
            throw EXT4Error.fileNotFound(path: path)
        }

        return info
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     deleteFile(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     파일을 삭제합니다.


     【동작】

     1. fileSystem에서 제거
     2. fileInfoCache에서 제거


     【예시】

     ```swift
     // 파일 삭제
     try mockFS.deleteFile(at: "normal/old_video.mp4")

     // 확인
     let exists = mockFS.fileExists(at: "normal/old_video.mp4")
     print(exists)  // false
     ```


     【주의】

     디렉토리 삭제 시 하위 파일은 자동 삭제되지 않음.
     하위 파일을 먼저 삭제해야 함.

     ═════════════════════════════════════════════════════════════════════
     */

    func deleteFile(at path: String) throws {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // Step 2: 경로 정규화
        let normalizedPath = normalizePath(path)

        // Step 3: 파일 존재 확인
        guard fileSystem[normalizedPath] != nil else {
            throw EXT4Error.fileNotFound(path: path)
        }

        // Step 4: 삭제
        fileSystem.removeValue(forKey: normalizedPath)
        fileInfoCache.removeValue(forKey: normalizedPath)
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     createDirectory(at:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     디렉토리를 생성합니다.


     【동작】

     fileInfoCache에만 추가:
     - isDirectory = true
     - size = 0

     fileSystem에는 추가하지 않음:
     - 디렉토리는 데이터가 없음


     【예시】

     ```swift
     // 디렉토리 생성
     try mockFS.createDirectory(at: "normal/metadata")

     // 하위 파일 생성
     let gpsData = Data(...)
     try mockFS.writeFile(data: gpsData, to: "normal/metadata/gps.txt")

     // 조회
     let files = try mockFS.listFiles(at: "normal")
     // Result: [..., "metadata" (디렉토리)]
     ```


     【부모 디렉토리】

     부모 디렉토리가 없어도 생성 가능 (자동 생성 안 함):

     ```swift
     // "parent" 없이 "parent/child" 생성 가능
     try mockFS.createDirectory(at: "parent/child")

     // 하지만 listFiles에서는 "parent"가 자동 표시됨
     let root = try mockFS.listFiles(at: "")
     // "parent" 자동 표시 (listFiles 알고리즘에 의해)
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    func createDirectory(at path: String) throws {
        // Step 1: 마운트 상태 확인
        guard _isMounted else {
            throw EXT4Error.notMounted
        }

        // Step 2: 경로 정규화
        let normalizedPath = normalizePath(path)

        // Step 3: 디렉토리명 추출
        let dirName = (normalizedPath as NSString).lastPathComponent

        // Step 4: 메타데이터만 생성
        // fileSystem에는 추가하지 않음 (디렉토리는 데이터 없음)
        fileInfoCache[normalizedPath] = EXT4FileInfo(
            path: normalizedPath,
            name: dirName,
            size: 0,               // 디렉토리는 크기 0
            isDirectory: true,
            creationDate: Date(),
            modificationDate: Date()
        )
    }

    // MARK: - Sample Data Creation

    /*
     ═════════════════════════════════════════════════════════════════════
     createSampleFiles()
     ═════════════════════════════════════════════════════════════════════

     【기능】

     초기화 시 호출되어 샘플 블랙박스 파일을 생성합니다.


     【생성 파일】

     1. normal/ (일반 녹화):
        - 09:00:00 ~ 09:02:00 (1분 단위, 3개)
        - 전방(F) + 후방(R)
        - MP4 + GPS + G-Sensor

     2. event/ (이벤트 녹화):
        - 10:30:15 (충격 시간)
        - 전방(F) + 후방(R)

     3. parking/ (주차 모드):
        - 18:00:00
        - 전방(F)만


     【파일 크기】

     전방 비디오: 100MB (1080p, 1분)
     후방 비디오: 80MB (720p, 1분)
     GPS 데이터: 1KB
     G-센서 데이터: 2KB


     【데이터 생성】

     Data(count: size):
     - 지정된 크기의 0으로 채워진 Data
     - 실제 비디오/GPS 데이터는 아님
     - 크기와 구조만 시뮬레이션


     【목적】

     1. 개발 시 즉시 사용 가능한 샘플 제공
     2. UI Preview에서 실제 같은 파일 목록 표시
     3. 테스트에서 다양한 시나리오 커버


     【커스터마이징】

     addTestFile()로 추가 파일 생성 가능:

     ```swift
     let mockFS = MockEXT4FileSystem()

     // 커스텀 파일 추가
     let customData = Data("Custom content".utf8)
     mockFS.addTestFile(path: "test/custom.txt", data: customData)

     // 기존 샘플 + 커스텀 파일 사용
     try mockFS.mount(devicePath: "/dev/disk2")
     let files = try mockFS.listFiles(at: "test")
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    private func createSampleFiles() {
        // Create sample dashcam video files
        // 샘플 블랙박스 비디오 파일 생성

        let sampleFiles: [(path: String, size: Int)] = [
            // Normal recordings (일반 녹화)
            ("normal/2025_01_10_09_00_00_F.mp4", 100 * 1024 * 1024),  // 100MB (전방)
            ("normal/2025_01_10_09_01_00_F.mp4", 100 * 1024 * 1024),
            ("normal/2025_01_10_09_02_00_F.mp4", 100 * 1024 * 1024),
            ("normal/2025_01_10_09_00_00_R.mp4", 80 * 1024 * 1024),   // 80MB (후방)
            ("normal/2025_01_10_09_01_00_R.mp4", 80 * 1024 * 1024),

            // Impact/Event recordings (이벤트 녹화)
            ("event/2025_01_10_10_30_15_F.mp4", 50 * 1024 * 1024),    // 50MB
            ("event/2025_01_10_10_30_15_R.mp4", 40 * 1024 * 1024),

            // Parking mode (주차 모드)
            ("parking/2025_01_10_18_00_00_F.mp4", 30 * 1024 * 1024),  // 30MB

            // GPS data files (GPS 데이터)
            ("normal/2025_01_10_09_00_00_F.gps", 1024),               // 1KB
            ("normal/2025_01_10_09_01_00_F.gps", 1024),
            ("event/2025_01_10_10_30_15_F.gps", 512),

            // G-Sensor data files (G-센서 데이터)
            ("normal/2025_01_10_09_00_00_F.gsn", 2048),               // 2KB
            ("normal/2025_01_10_09_01_00_F.gsn", 2048),
            ("event/2025_01_10_10_30_15_F.gsn", 1024)
        ]

        // 각 샘플 파일 생성
        for (path, size) in sampleFiles {
            // Step 1: 더미 데이터 생성
            // 0으로 채워진 Data (실제 비디오 내용은 아님)
            let data = Data(count: size)
            fileSystem[path] = data

            // Step 2: 파일명 추출
            let fileName = (path as NSString).lastPathComponent

            // Step 3: 현재 시간
            let now = Date()

            // Step 4: 메타데이터 생성
            fileInfoCache[path] = EXT4FileInfo(
                path: path,
                name: fileName,
                size: UInt64(size),
                isDirectory: false,
                creationDate: now,
                modificationDate: now
            )
        }
    }

    // MARK: - Testing Helpers

    /*
     ═════════════════════════════════════════════════════════════════════
     reset()
     ═════════════════════════════════════════════════════════════════════

     【기능】

     Mock 파일 시스템을 초기 상태로 복원합니다.


     【동작】

     1. 언마운트
     2. 모든 데이터 삭제
     3. 샘플 파일 재생성


     【사용 사례】

     1. 테스트 간 독립성 보장:
        ```swift
        func testFileOperations() {
            let mockFS = MockEXT4FileSystem()

            // Test 1
            try mockFS.mount(devicePath: "/dev/disk2")
            try mockFS.writeFile(data: data1, to: "test1.txt")
            // ...

            // Reset
            mockFS.reset()

            // Test 2 (깨끗한 상태)
            try mockFS.mount(devicePath: "/dev/disk2")
            try mockFS.writeFile(data: data2, to: "test2.txt")
            // test1.txt는 없음
        }
        ```

     2. 오류 후 복구:
        ```swift
        do {
            // 작업 수행...
        } catch {
            // 오류 발생
            mockFS.reset()  // 초기 상태로
            // 재시도...
        }
        ```


     【주의】

     reset() 후에는 다시 mount() 필요:

     ```swift
     mockFS.reset()
     // mockFS.isMounted == false

     try mockFS.mount(devicePath: "/dev/disk2")
     // 이제 사용 가능
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// Reset the mock filesystem to initial state
    func reset() {
        // Step 1: 언마운트
        _isMounted = false
        currentDevicePath = nil

        // Step 2: 모든 데이터 삭제
        fileSystem.removeAll()
        fileInfoCache.removeAll()

        // Step 3: 샘플 파일 재생성
        createSampleFiles()
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     addTestFile(path:data:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     테스트용 커스텀 파일을 추가합니다.


     【매개변수】

     - path: 파일 경로 (예: "test/custom.txt")
     - data: 파일 내용


     【특징】

     - 마운트 여부와 무관하게 추가 가능
     - 공간 확인 안 함
     - 즉시 사용 가능


     【사용 예시】

     ```swift
     let mockFS = MockEXT4FileSystem()

     // 1. GPS 테스트 파일 추가
     let gpsData = """
     $GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A
     $GPGGA,143025,3744.1234,N,12704.5678,E,1,08,1.2,123.4,M,20.1,M,,*4D
     """.data(using: .utf8)!

     mockFS.addTestFile(path: "test/gps.txt", data: gpsData)

     // 2. 비디오 메타데이터 테스트
     let metadataData = Data([/* custom metadata */])
     mockFS.addTestFile(path: "test/metadata.bin", data: metadataData)

     // 3. 사용
     try mockFS.mount(devicePath: "/dev/disk2")
     let readData = try mockFS.readFile(at: "test/gps.txt")
     ```


     【테스트 시나리오 구성】

     ```swift
     func testEdgeCase() {
         let mockFS = MockEXT4FileSystem()

         // 비어있는 파일
         mockFS.addTestFile(path: "empty.txt", data: Data())

         // 매우 큰 파일명
         let longName = String(repeating: "a", count: 255)
         mockFS.addTestFile(path: longName, data: Data("test".utf8))

         // 특수 문자 포함
         mockFS.addTestFile(path: "special-!@#$%.txt", data: Data())

         // 테스트 실행...
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// Add a custom test file
    func addTestFile(path: String, data: Data) {
        // Step 1: 파일 내용 추가
        fileSystem[path] = data

        // Step 2: 파일명 추출
        let fileName = (path as NSString).lastPathComponent

        // Step 3: 메타데이터 생성
        fileInfoCache[path] = EXT4FileInfo(
            path: path,
            name: fileName,
            size: UInt64(data.count),
            isDirectory: false,
            creationDate: Date(),
            modificationDate: Date()
        )
    }
}

/*
 ─────────────────────────────────────────────────────────────────────────
 헬퍼 함수
 ─────────────────────────────────────────────────────────────────────────
 */

extension MockEXT4FileSystem {
    /*
     ═════════════════════════════════════════════════════════════════════
     normalizePath(_:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     경로를 정규화합니다.


     【변환 규칙】

     1. 앞의 "/" 제거:
        "/normal" → "normal"

     2. 뒤의 "/" 제거:
        "normal/" → "normal"

     3. 연속된 "/" 제거:
        "normal//sub" → "normal/sub"


     【목적】

     Dictionary 키의 일관성 유지:

     잘못된 경우 (정규화 안 함):
     [
       "normal/video.mp4": Data,
       "/normal/video.mp4": Data,  ← 중복!
       "normal/video.mp4/": Data   ← 중복!
     ]

     올바른 경우 (정규화 함):
     [
       "normal/video.mp4": Data    ← 하나의 키
     ]


     【예시】

     ```swift
     normalizePath("")              → ""
     normalizePath("/")             → ""
     normalizePath("normal")        → "normal"
     normalizePath("/normal")       → "normal"
     normalizePath("normal/")       → "normal"
     normalizePath("/normal/")      → "normal"
     normalizePath("normal//sub")   → "normal/sub"
     normalizePath("//normal///sub//") → "normal/sub"
     ```


     【구현】

     1. "/" 기준 분리
     2. 빈 문자열 제거 (filter)
     3. "/" 로 재결합


     【참고】

     실제 파일 시스템의 realpath() 와 유사:
     - 상대 경로 → 절대 경로
     - 심볼릭 링크 해석
     - "..", "." 해석

     Mock에서는 간단한 버전만 구현.

     ═════════════════════════════════════════════════════════════════════
     */

    private func normalizePath(_ path: String) -> String {
        // Step 1: "/" 기준 분리
        let components = path.split(separator: "/")

        // Step 2: 빈 문자열 제거 (자동으로 처리됨, split은 빈 문자열 생략)
        // "/normal/" → ["normal"]
        // "normal//sub" → ["normal", "sub"]

        // Step 3: "/" 로 재결합
        let normalized = components.joined(separator: "/")

        return normalized
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 사용 예시
 ═══════════════════════════════════════════════════════════════════════════

 【시나리오 1: Unit Test】

 ```swift
 import XCTest

 class FileManagerTests: XCTestCase {

     var mockFS: MockEXT4FileSystem!

     override func setUp() {
         super.setUp()
         // 각 테스트마다 새 Mock
         mockFS = MockEXT4FileSystem()
         try! mockFS.mount(devicePath: "/dev/disk2")
     }

     override func tearDown() {
         try? mockFS.unmount()
         mockFS = nil
         super.tearDown()
     }

     func testFileScanning() {
         // Given: 샘플 파일이 준비되어 있음 (createSampleFiles)

         // When: 파일 스캔
         let scanner = FileScanner(fileSystem: mockFS)
         let files = try! scanner.scan(directory: "normal")

         // Then: 예상 파일 개수
         XCTAssertEqual(files.count, 8)  // MP4 5개 + GPS 2개 + GSN 2개 = 9개
                                          // (실제 샘플 파일 개수에 맞게 조정)
     }

     func testFileWrite() {
         // Given
         let testData = Data("Test content".utf8)

         // When
         try! mockFS.writeFile(data: testData, to: "test/output.txt")

         // Then
         let readData = try! mockFS.readFile(at: "test/output.txt")
         XCTAssertEqual(testData, readData)
     }

     func testSpaceManagement() {
         // Given: 32GB Mock 장치
         let info = try! mockFS.getDeviceInfo()
         let initialFree = info.freeSpace

         // When: 파일 쓰기
         let data = Data(count: 1024 * 1024)  // 1MB
         try! mockFS.writeFile(data: data, to: "test.dat")

         // Then: 여유 공간 감소
         let newInfo = try! mockFS.getDeviceInfo()
         XCTAssertEqual(newInfo.freeSpace, initialFree - 1024 * 1024)
     }
 }
 ```


 【시나리오 2: SwiftUI Preview】

 ```swift
 import SwiftUI

 struct FileListView: View {
     @EnvironmentObject var fileSystem: EXT4FileSystemProtocol
     @State private var files: [EXT4FileInfo] = []

     var body: some View {
         List(files, id: \.path) { file in
             HStack {
                 Image(systemName: file.isDirectory ? "folder" : "doc")
                 Text(file.name)
                 Spacer()
                 Text("\(file.size / 1024 / 1024) MB")
                     .foregroundColor(.secondary)
             }
         }
         .onAppear {
             loadFiles()
         }
     }

     func loadFiles() {
         do {
             files = try fileSystem.listFiles(at: "normal")
         } catch {
             print("Error: \(error)")
         }
     }
 }

 // Preview with Mock
 struct FileListView_Previews: PreviewProvider {
     static var previews: some View {
         FileListView()
             .environmentObject(MockEXT4FileSystem() as EXT4FileSystemProtocol)
             // Mock 데이터로 UI 즉시 확인 가능
     }
 }
 ```


 【시나리오 3: 조건부 컴파일】

 ```swift
 // AppDelegate.swift 또는 @main App

 let fileSystem: EXT4FileSystemProtocol = {
     #if DEBUG
     // 개발/시뮬레이터: Mock 사용
     print("Using MockEXT4FileSystem for development")
     return MockEXT4FileSystem()
     #else
     // 배포: 실제 구현 사용
     print("Using EXT4Bridge for production")
     return EXT4Bridge()
     #endif
 }()

 @main
 struct BlackboxPlayerApp: App {
     @StateObject private var fileSystemManager = FileSystemManager(
         fileSystem: fileSystem
     )

     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environmentObject(fileSystemManager)
         }
     }
 }
 ```


 【시나리오 4: 오류 시나리오 테스트】

 ```swift
 func testErrorScenarios() {
     let mockFS = MockEXT4FileSystem()

     // 1. 마운트 전 읽기 시도
     XCTAssertThrowsError(try mockFS.readFile(at: "any.txt")) { error in
         XCTAssertEqual(error as? EXT4Error, .notMounted)
     }

     // 2. 파일 없음
     try! mockFS.mount(devicePath: "/dev/disk2")
     XCTAssertThrowsError(try mockFS.readFile(at: "nonexistent.txt")) { error in
         guard case .fileNotFound = error as? EXT4Error else {
             XCTFail("Expected fileNotFound error")
             return
         }
     }

     // 3. 공간 부족
     let hugeData = Data(count: 100 * 1024 * 1024 * 1024)  // 100GB
     XCTAssertThrowsError(try mockFS.writeFile(data: hugeData, to: "huge.dat")) { error in
         XCTAssertEqual(error as? EXT4Error, .insufficientSpace)
     }
 }
 ```


 【시나리오 5: 커스텀 테스트 데이터】

 ```swift
 func testGPSParsing() {
     let mockFS = MockEXT4FileSystem()

     // 커스텀 GPS 데이터 추가
     let gpsData = """
     $GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A
     $GPGGA,143025,3744.1234,N,12704.5678,E,1,08,1.2,123.4,M,20.1,M,,*4D
     """.data(using: .utf8)!

     mockFS.addTestFile(path: "test/gps_sample.txt", data: gpsData)

     // 테스트
     try! mockFS.mount(devicePath: "/dev/disk2")
     let readData = try! mockFS.readFile(at: "test/gps_sample.txt")

     let parser = GPSParser()
     let points = parser.parseNMEA(data: readData, baseDate: Date())

     XCTAssertEqual(points.count, 1)
     XCTAssertEqual(points.first?.latitude, 37.7354, accuracy: 0.0001)
 }
 ```

 ═══════════════════════════════════════════════════════════════════════════
 */
