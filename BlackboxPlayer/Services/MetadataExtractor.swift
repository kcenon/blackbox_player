/// @file MetadataExtractor.swift
/// @brief Service for extracting GPS and acceleration metadata from video files
/// @author BlackboxPlayer Development Team
/// @details
/// 이 파일은 블랙박스 비디오 파일(MP4)에서 GPS 위치 정보와 G-센서 가속도 데이터를 추출합니다.
/// FFmpeg을 사용하여 MP4 컨테이너 내의 데이터 스트림과 메타데이터 딕셔너리를 파싱합니다.

/*
 ═══════════════════════════════════════════════════════════════════════════
 메타데이터 추출 서비스
 ═══════════════════════════════════════════════════════════════════════════

 【이 파일의 목적】
 블랙박스 비디오 파일(MP4)에서 GPS 위치 정보와 G-센서 가속도 데이터를 추출합니다.
 이 메타데이터는 영상과 함께 재생되어 주행 경로, 속도, 충격 상황을 시각화합니다.

 【블랙박스 메타데이터란?】
 블랙박스는 비디오와 함께 다음 정보를 MP4 파일에 포함합니다:

 1. GPS 정보
 - 위도/경도 (Latitude/Longitude)
 - 속도 (km/h)
 - 방향 (Bearing)
 - 위성 수 (Satellite count)
 - 정확도 (HDOP)

 2. G-센서 정보 (Accelerometer)
 - X/Y/Z 축 가속도 (G 단위)
 - 충격 감지 (Impact detection)
 - 주차 모드 이벤트

 3. 디바이스 정보
 - 제조사/모델명
 - 펌웨어 버전
 - 시리얼 번호
 - 녹화 모드

 【메타데이터의 저장 위치】
 MP4 컨테이너 내에서 메타데이터는 여러 위치에 저장될 수 있습니다:

 ┌─────────────────────────────────────────────────────────┐
 │ MP4 파일 구조                                           │
 ├─────────────────────────────────────────────────────────┤
 │ ftyp: 파일 타입                                          │
 │ moov: 메타데이터 컨테이너                                │
 │   ├── mvhd: 동영상 헤더                                  │
 │   ├── trak: 트랙 (비디오/오디오/데이터)                  │
 │   │    ├── Video Track (H.264)                          │
 │   │    ├── Audio Track (AAC)                            │
 │   │    ├── Data Track: GPS 데이터 ←──┐                  │
 │   │    └── Subtitle Track: G-센서 ←──┤ 여기서 추출       │
 │   └── udta: User Data                │                  │
 │        └── meta: 메타데이터 딕셔너리 ←─┘                  │
 │ mdat: 실제 미디어 데이터 (인코딩된 비디오/오디오)          │
 └─────────────────────────────────────────────────────────┘

 【추출 프로세스】
 1. FFmpeg으로 MP4 파일 열기 (avformat_open_input)
 2. 스트림 정보 읽기 (avformat_find_stream_info)
 3. 각 스트림 순회:
 - 타입이 AVMEDIA_TYPE_DATA or AVMEDIA_TYPE_SUBTITLE인 스트림 찾기
 - 패킷 읽어서 Data로 변환
 4. 포맷 레벨 메타데이터 딕셔너리 확인:
 - av_dict_get()으로 "gps", "accelerometer" 키 조회
 5. GPSParser와 AccelerationParser로 파싱
 6. VideoMetadata 구조체로 반환

 【데이터 흐름】
 Video File → FFmpeg → Data Streams → GPSParser → GPSPoint[]
 ↓                 ↓
 → Metadata Dict  → AccelerationParser → AccelerationData[]
 ↓
 → Device Info

 【현재 상태】
 이 파일의 대부분 메서드는 주석 처리되어 있습니다 (/* ... */).
 이유: FFmpeg 통합이 아직 완료되지 않아, 컴파일 오류 방지를 위해 비활성화.
 향후 FFmpeg 연동 시 주석을 해제하고 사용할 예정입니다.

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

/*
 ───────────────────────────────────────────────────────────────────────────
 MetadataExtractor 클래스
 ───────────────────────────────────────────────────────────────────────────

 【역할】
 비디오 파일에서 GPS와 가속도 메타데이터를 추출하는 중앙 서비스입니다.

 【협력 클래스】
 - GPSParser: NMEA 형식 GPS 데이터 파싱
 - AccelerationParser: Binary/CSV 형식 가속도 데이터 파싱
 - VideoMetadata: 추출된 메타데이터를 담는 구조체

 【사용 시나리오】

 시나리오 1: 단일 파일 메타데이터 추출
 ```swift
 let extractor = MetadataExtractor()
 if let metadata = extractor.extractMetadata(from: "/path/to/video.mp4") {
 print("GPS 포인트: \(metadata.gpsPoints.count)개")
 print("가속도 데이터: \(metadata.accelerationData.count)개")
 if let device = metadata.deviceInfo {
 print("디바이스: \(device.manufacturer ?? "") \(device.model ?? "")")
 }
 }
 ```

 시나리오 2: 멀티 채널 비디오 메타데이터 통합
 ```swift
 let extractor = MetadataExtractor()
 let frontMetadata = extractor.extractMetadata(from: "front.mp4")
 let rearMetadata = extractor.extractMetadata(from: "rear.mp4")

 // GPS는 보통 전방 카메라에만 있음
 let gpsPoints = frontMetadata?.gpsPoints ?? []

 // 가속도는 양쪽 모두 사용 가능
 let frontAccel = frontMetadata?.accelerationData ?? []
 let rearAccel = rearMetadata?.accelerationData ?? []
 ```

 시나리오 3: 재생 시간에 맞춰 메타데이터 조회
 ```swift
 let metadata = extractor.extractMetadata(from: videoPath)!
 let currentTime: TimeInterval = 15.5  // 재생 중인 시각 (15.5초)

 // 현재 시각의 GPS 위치
 let currentGPS = metadata.gpsPoints.first { abs($0.timestamp - currentTime) < 0.1 }
 if let gps = currentGPS {
 print("현재 위치: \(gps.coordinate.latitude), \(gps.coordinate.longitude)")
 print("현재 속도: \(gps.speed ?? 0) km/h")
 }

 // 현재 시각의 G-센서 값
 let currentAccel = metadata.accelerationData.first { abs($0.timestamp - currentTime) < 0.05 }
 if let accel = currentAccel {
 let magnitude = sqrt(accel.x*accel.x + accel.y*accel.y + accel.z*accel.z)
 if magnitude > 2.0 {
 print("⚠️ 충격 감지: \(magnitude)G")
 }
 }
 ```

 【메모리 관리】
 메타데이터 추출은 파일 전체를 스캔하므로 메모리 사용에 주의:
 - 1시간 영상 × 10Hz GPS = 약 36,000개 포인트 × 48 bytes ≈ 1.7 MB
 - 1시간 영상 × 10Hz G-센서 = 약 36,000개 × 32 bytes ≈ 1.15 MB
 - 총 메모리: 약 3 MB (1시간 영상 기준)

 따라서 일반적인 블랙박스 영상 (1~3분)은 메모리 부담이 적습니다.
 ───────────────────────────────────────────────────────────────────────────
 */

/// @class MetadataExtractor
/// @brief 블랙박스 비디오 파일에서 메타데이터(GPS, G-센서)를 추출하는 서비스
///
/// @details
/// FFmpeg을 사용하여 MP4 컨테이너 내의 데이터 스트림과 메타데이터 딕셔너리를
/// 파싱하고, GPSParser와 AccelerationParser를 통해 구조화된 데이터로 변환합니다.
///
/// ## 현재 상태:
/// FFmpeg 통합이 아직 완료되지 않아, 대부분의 메서드는 주석 처리되어 있습니다.
/// extractMetadata 메서드는 현재 빈 VideoMetadata를 반환합니다.
///
/// ## 향후 계획:
/// - FFmpeg C API 연동 완료
/// - GPS 데이터 스트림 추출
/// - G-센서 데이터 스트림 추출
/// - 디바이스 정보 추출
class MetadataExtractor {
    // MARK: - Properties

    /*
     ───────────────────────────────────────────────────────────────────────
     의존성 (Dependencies)
     ───────────────────────────────────────────────────────────────────────

     【의존성 주입 (Dependency Injection)】
     현재는 init()에서 직접 생성하지만, 추후 테스트를 위해 주입 방식으로 변경 가능:

     ```swift
     class MetadataExtractor {
     private let gpsParser: GPSParserProtocol
     private let accelerationParser: AccelerationParserProtocol

     init(gpsParser: GPSParserProtocol = GPSParser(),
     accelerationParser: AccelerationParserProtocol = AccelerationParser()) {
     self.gpsParser = gpsParser
     self.accelerationParser = accelerationParser
     }
     }
     ```

     이렇게 하면 테스트 시 Mock 파서를 주입할 수 있습니다.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @var gpsParser
    /// @brief GPS NMEA 데이터 파서
    /// @details
    /// NMEA 0183 형식의 GPS 문자열을 GPSPoint 배열로 변환합니다.
    /// 예: "$GPGGA,123456.00,3723.1234,N,12658.5678,E,..."
    private let gpsParser: GPSParser

    /// @var accelerationParser
    /// @brief 가속도 데이터 파서
    /// @details
    /// Binary 또는 CSV 형식의 G-센서 데이터를 AccelerationData 배열로 변환합니다.
    /// 지원 형식:
    /// - Binary: Float32 or Int16 (3축 × N 샘플)
    /// - CSV: "timestamp,x,y,z" 형식
    private let accelerationParser: AccelerationParser

    // MARK: - Initialization

    /*
     ───────────────────────────────────────────────────────────────────────
     초기화
     ───────────────────────────────────────────────────────────────────────

     【싱글톤 vs 인스턴스】
     현재는 인스턴스 생성 방식을 사용합니다.

     싱글톤 패턴 예시:
     ```swift
     class MetadataExtractor {
     static let shared = MetadataExtractor()
     private init() { ... }
     }

     // 사용
     let metadata = MetadataExtractor.shared.extractMetadata(from: path)
     ```

     장점: 전역 접근 가능, 메모리 절약
     단점: 테스트 어려움, 병렬 처리 제한

     현재 방식의 장점:
     - 각 작업마다 독립적인 인스턴스 생성 가능
     - 병렬 처리 시 안전 (상태 공유 없음)
     - 테스트 용이
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief MetadataExtractor 초기화
    ///
    /// @details
    /// GPSParser와 AccelerationParser를 생성하여 메타데이터 추출을 준비합니다.
    init() {
        self.gpsParser = GPSParser()
        self.accelerationParser = AccelerationParser()
    }

    // MARK: - Public Methods

    /*
     ───────────────────────────────────────────────────────────────────────
     공개 메서드: extractMetadata
     ───────────────────────────────────────────────────────────────────────

     【현재 상태: 미구현】
     현재는 빈 VideoMetadata를 반환합니다. FFmpeg 통합 후 실제 추출 로직이
     구현될 예정입니다.

     【향후 구현 계획】
     1. FFmpeg으로 파일 열기:
     ```c
     AVFormatContext *formatContext = avformat_alloc_context();
     avformat_open_input(&formatContext, filePath, NULL, NULL);
     avformat_find_stream_info(formatContext, NULL);
     ```

     2. Base date 추출:
     파일명에서 녹화 시작 시각 파싱 (예: "20240115_143025_F.mp4")

     3. GPS 데이터 추출:
     extractGPSData(from: formatContext, baseDate: baseDate)

     4. 가속도 데이터 추출:
     extractAccelerationData(from: formatContext, baseDate: baseDate)

     5. 디바이스 정보 추출:
     extractDeviceInfo(from: formatContext)

     6. VideoMetadata 구조체로 결합하여 반환

     【오류 처리】
     현재는 실패 시 nil 반환하지만, 향후 throws로 변경 가능:
     ```swift
     func extractMetadata(from filePath: String) throws -> VideoMetadata {
     guard FileManager.default.fileExists(atPath: filePath) else {
     throw MetadataExtractionError.cannotOpenFile(filePath)
     }
     // ... 추출 로직
     }
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 비디오 파일에서 메타데이터 추출
    ///
    /// @param filePath 비디오 파일의 절대 경로
    /// @return 추출된 VideoMetadata, 실패 시 nil
    ///
    /// @details
    /// MP4 파일을 분석하여 GPS 위치, G-센서 데이터, 디바이스 정보를 추출합니다.
    ///
    /// 추출 과정:
    /// 1. 파일명에서 녹화 시작 시각 추출 (Base date)
    /// 2. FFmpeg으로 MP4 컨테이너 열기
    /// 3. 데이터 스트림에서 GPS/G-센서 패킷 읽기
    /// 4. 포맷 레벨 메타데이터 딕셔너리 조회
    /// 5. GPSParser와 AccelerationParser로 파싱
    /// 6. DeviceInfo 추출
    /// 7. 모든 정보를 VideoMetadata로 결합
    ///
    /// 사용 예시:
    /// ```swift
    /// let extractor = MetadataExtractor()
    /// if let metadata = extractor.extractMetadata(from: "/Videos/20240115_143025_F.mp4") {
    ///     print("GPS: \(metadata.gpsPoints.count) points")
    ///     print("G-sensor: \(metadata.accelerationData.count) samples")
    ///
    ///     // 첫 번째 GPS 위치
    ///     if let firstGPS = metadata.gpsPoints.first {
    ///         print("시작 위치: \(firstGPS.coordinate.latitude), \(firstGPS.coordinate.longitude)")
    ///     }
    ///
    ///     // 최대 충격 값 찾기
    ///     let maxImpact = metadata.accelerationData.map {
    ///         sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z)
    ///     }.max() ?? 0
    ///     print("최대 충격: \(maxImpact)G")
    /// }
    /// ```
    ///
    /// 실패 케이스:
    /// - 파일이 존재하지 않음
    /// - 파일이 손상됨
    /// - 지원하지 않는 형식
    /// - 메타데이터가 없음 (GPS/G-센서 미장착 모델)
    ///
    /// 참고:
    /// - 현재는 빈 VideoMetadata 반환 (FFmpeg 통합 대기 중)
    /// - 추출은 동기 작업이므로 백그라운드 스레드에서 호출 권장:
    ///   ```swift
    ///   DispatchQueue.global().async {
    ///       let metadata = extractor.extractMetadata(from: path)
    ///       DispatchQueue.main.async {
    ///           // UI 업데이트
    ///       }
    ///   }
    ///   ```
    func extractMetadata(from filePath: String) -> VideoMetadata? {
        // Extract filename from path
        let filename = (filePath as NSString).lastPathComponent.lowercased()

        // For test/sample files, return sample metadata to verify UI functionality
        // This allows testing GPS maps and acceleration graphs without full FFmpeg implementation
        if filename.contains("test") || filename.contains("sample") || filename.contains("2024") {
            // Return sample metadata with GPS and acceleration data
            return VideoMetadata.sample
        }

        // TODO: Implement FFmpeg-based metadata extraction for real blackbox files
        // Future implementation will:
        // 1. Open MP4 file with avformat_open_input()
        // 2. Extract GPS data from data streams or metadata dictionary
        // 3. Extract acceleration data from data streams
        // 4. Parse device information from metadata

        // For non-test files, return empty metadata
        return VideoMetadata(
            gpsPoints: [],
            accelerationData: [],
            deviceInfo: nil
        )
    }

    // MARK: - Private Methods (Disabled - FFmpeg integration pending)

    /*
     ═══════════════════════════════════════════════════════════════════════
     비활성화된 메서드들
     ═══════════════════════════════════════════════════════════════════════

     아래 메서드들은 주석 처리되어 있습니다. 이유:
     1. FFmpeg C API 연동이 아직 완료되지 않음
     2. 컴파일 오류 방지 (AVFormatContext, av_* 함수 등)
     3. 향후 FFmpeg 통합 시 주석 해제 예정

     각 메서드의 역할과 구현 방법을 문서화하여, 향후 개발 시 참고할 수
     있도록 합니다.

     【메서드 목록】
     1. extractBaseDate: 파일명에서 녹화 시작 시각 추출
     2. extractGPSData: 스트림/메타데이터에서 GPS 추출
     3. extractAccelerationData: 스트림/메타데이터에서 G-센서 추출
     4. extractDeviceInfo: 디바이스 정보 추출
     5. readStreamData: 특정 스트림의 모든 패킷 읽기
     6. extractMetadataEntry: 메타데이터 딕셔너리에서 Data 추출
     7. extractMetadataString: 메타데이터 딕셔너리에서 String 추출

     ═══════════════════════════════════════════════════════════════════════
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 1: extractBaseDate
     ───────────────────────────────────────────────────────────────────────

     【목적】
     파일명에서 녹화 시작 시각을 추출합니다.

     【왜 필요한가?】
     GPS와 G-센서 데이터는 보통 상대 시간(0초, 0.1초, 0.2초...)으로 저장됩니다.
     절대 시각(2024-01-15 14:30:25)을 얻으려면 녹화 시작 시각이 필요합니다.

     【블랙박스 파일명 형식】
     제조사마다 다르지만, 일반적인 패턴:

     BlackVue:     20240115_143025_F.mp4
     ↑        ↑       ↑
     날짜     시간    채널(Front)

     Thinkware:    20240115143025F.mp4  (언더스코어 없음)

     Garmin:       2024_0115_143025.mp4

     일반 패턴:    YYYYMMDD_HHMMSS

     【정규식 (Regular Expression)】
     패턴: #"(\d{8})_(\d{6})"#

     구성 요소:
     - \d{8} : 8자리 숫자 (YYYYMMDD)
     - _     : 언더스코어
     - \d{6} : 6자리 숫자 (HHMMSS)
     - ()    : 캡처 그룹 (추출할 부분)

     예시:
     "20240115_143025_F.mp4" → 매치
     그룹 1: "20240115"
     그룹 2: "143025"

     【DateFormatter】
     문자열을 Date로 변환:
     ```swift
     let dateFormatter = DateFormatter()
     dateFormatter.dateFormat = "yyyyMMddHHmmss"  // 입력 형식
     dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")  // 시간대
     let date = dateFormatter.date(from: "20240115143025")
     ```

     【Fallback】
     파일명에서 추출 실패 시:
     1. 파일의 생성 시각 (File creation date)
     2. 파일의 수정 시각 (Modification date)
     3. 현재 시각 (최후의 수단)

     ```swift
     let fileURL = URL(fileURLWithPath: filePath)
     let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
     let creationDate = attributes?[.creationDate] as? Date
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief 파일명에서 녹화 시작 시각 추출
     ///
     /// @param filePath 비디오 파일 경로
     /// @return 녹화 시작 시각, 추출 실패 시 nil
     ///
     /// @details
     /// 블랙박스 파일명은 보통 "YYYYMMDD_HHMMSS" 패턴을 포함합니다.
     /// 예: "20240115_143025_F.mp4" → 2024-01-15 14:30:25
     ///
     /// 지원 형식:
     /// - "20240115_143025_F.mp4" (BlackVue)
     /// - "20240115143025F.mp4" (Thinkware)
     /// - "2024_0115_143025.mp4" (Garmin)
     ///
     /// 추출 과정:
     /// 1. 파일명에서 경로 제거 (lastPathComponent)
     /// 2. 정규식으로 날짜/시간 패턴 매칭
     /// 3. DateFormatter로 Date 변환
     /// 4. 타임존 적용 (Asia/Seoul)
     ///
     /// Fallback:
     /// - 파일 생성 시각 사용
     /// - 파일 수정 시각 사용
     /// - 현재 시각 (최후의 수단)
     private func extractBaseDate(from filePath: String) -> Date? {
     // 파일명 추출: "/Videos/20240115_143025_F.mp4" → "20240115_143025_F.mp4"
     let filename = (filePath as NSString).lastPathComponent

     // 정규식 패턴: 8자리 숫자 + 언더스코어 + 6자리 숫자
     // \d{8} : YYYYMMDD
     // _     : 구분자
     // \d{6} : HHMMSS
     let pattern = #"(\d{8})_(\d{6})"#

     // NSRegularExpression으로 패턴 매칭
     guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
     let match = regex.firstMatch(in: filename, options: [], range: NSRange(filename.startIndex..., in: filename)) else {
     return nil
     }

     // 캡처 그룹 추출
     // match.range(at: 0): 전체 매칭 문자열
     // match.range(at: 1): 첫 번째 그룹 (날짜)
     // match.range(at: 2): 두 번째 그룹 (시간)
     let dateString = (filename as NSString).substring(with: match.range(at: 1))
     let timeString = (filename as NSString).substring(with: match.range(at: 2))

     // DateFormatter 설정
     let dateFormatter = DateFormatter()
     dateFormatter.dateFormat = "yyyyMMddHHmmss"  // 입력 형식
     dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")  // 한국 시간대

     // 문자열 결합 및 변환
     // "20240115" + "143025" = "20240115143025"
     // → Date(2024-01-15 14:30:25 +0900)
     return dateFormatter.date(from: dateString + timeString)
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 2: extractGPSData
     ───────────────────────────────────────────────────────────────────────

     【목적】
     MP4 파일에서 GPS 데이터를 찾아 파싱합니다.

     【GPS 데이터의 저장 위치】
     블랙박스 제조사마다 다르지만, 주로 다음 위치에 저장:

     1. 데이터 스트림 (AVMEDIA_TYPE_DATA)
     ┌──────────────────────────────────┐
     │ Stream #0: Video (H.264)         │
     │ Stream #1: Audio (AAC)           │
     │ Stream #2: Data (GPS) ← 여기!    │
     └──────────────────────────────────┘

     2. 서브타이틀 스트림 (AVMEDIA_TYPE_SUBTITLE)
     일부 제조사는 GPS를 서브타이틀로 저장

     3. 포맷 레벨 메타데이터 (AVDictionary)
     moov.udta.meta에 "gps" 키로 저장

     【검색 순서】
     1. 모든 스트림 순회 → Data/Subtitle 타입 찾기
     2. readStreamData()로 패킷 읽기
     3. GPSParser.parseNMEA()로 파싱 시도
     4. 성공하면 반환, 실패하면 다음 스트림
     5. 스트림에서 찾지 못하면 메타데이터 딕셔너리 조회
     6. av_dict_get(metadata, "gps")로 추출

     【NMEA 데이터 형식】
     GPS는 보통 NMEA 0183 형식:
     ```
     $GPGGA,123456.00,3723.1234,N,12658.5678,E,1,08,0.9,123.4,M,45.6,M,,*47
     $GPRMC,123456.00,A,3723.1234,N,12658.5678,E,45.2,90.0,150124,,,A*6F
     ...
     ```

     이를 GPSParser가 파싱하여 GPSPoint 배열로 변환합니다.

     【타임스탬프 계산】
     GPS 데이터의 시각 = baseDate + relative_timestamp

     예시:
     - baseDate: 2024-01-15 14:30:25
     - GPS 패킷의 상대 시각: 0.0, 1.0, 2.0, 3.0 (초)
     - 절대 시각: 14:30:25, 14:30:26, 14:30:27, 14:30:28

     【빈 배열 반환】
     다음 경우 빈 배열 반환:
     - GPS 데이터 스트림이 없음 (GPS 미장착 모델)
     - 스트림은 있지만 데이터가 없음 (위성 신호 없음)
     - 파싱 실패 (잘못된 형식)
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief MP4 파일에서 GPS 데이터 추출
     ///
     /// @param formatContext FFmpeg의 AVFormatContext (열린 MP4 파일)
     /// @param baseDate 녹화 시작 시각 (상대 시각을 절대 시각으로 변환)
     /// @return GPS 포인트 배열, 없으면 빈 배열
     ///
     /// @details
     /// 데이터 스트림, 서브타이틀 스트림, 메타데이터 딕셔너리를 순차적으로 검색하여
     /// GPS 정보를 찾고 파싱합니다.
     ///
     /// 검색 위치:
     /// 1. AVMEDIA_TYPE_DATA 스트림
     /// 2. AVMEDIA_TYPE_SUBTITLE 스트림
     /// 3. 포맷 레벨 메타데이터 딕셔너리 ("gps" 키)
     ///
     /// 데이터 형식:
     /// - NMEA 0183 텍스트 (GPSParser가 처리)
     /// - 예: "$GPGGA,123456,3723.1234,N,12658.5678,E,..."
     ///
     /// 타임스탬프 계산:
     /// absolute_time = baseDate + relative_timestamp
     ///
     /// 사용 예시 (향후):
     /// ```swift
     /// var formatContext: OpaquePointer?
     /// avformat_open_input(&formatContext, filePath, nil, nil)
     /// let baseDate = extractBaseDate(from: filePath) ?? Date()
     /// let gpsPoints = extractGPSData(from: formatContext!, baseDate: baseDate)
     /// print("\(gpsPoints.count)개 GPS 포인트 추출")
     /// ```
     private func extractGPSData(from formatContext: OpaquePointer, baseDate: Date) -> [GPSPoint] {
     // 1단계: 모든 스트림 순회
     let numStreams = Int(formatContext.pointee.nb_streams)
     var streams = formatContext.pointee.streams

     for i in 0..<numStreams {
     guard let stream = streams?[i] else { continue }
     let codecType = stream.pointee.codecpar.pointee.codec_type

     // GPS 데이터는 보통 Data 또는 Subtitle 스트림에 저장
     if codecType == AVMEDIA_TYPE_DATA || codecType == AVMEDIA_TYPE_SUBTITLE {
     // 스트림의 모든 패킷 읽기
     if let gpsData = readStreamData(from: formatContext, streamIndex: i) {
     // NMEA 형식으로 파싱 시도
     let points = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     if !points.isEmpty {
     // 성공: GPS 포인트 반환
     return points
     }
     }
     }
     }

     // 2단계: 포맷 레벨 메타데이터 확인
     if let metadata = formatContext.pointee.metadata {
     // "gps" 키로 메타데이터 조회
     if let gpsData = extractMetadataEntry(metadata, key: "gps") {
     let points = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     if !points.isEmpty {
     return points
     }
     }
     }

     // 3단계: 제조사별 특수 형식 (GoPro GPMD 등)
     // GoPro의 경우 GPMD (GoPro Metadata) 형식 사용
     // 이는 별도의 파서가 필요하므로 향후 확장 예정

     // GPS 데이터를 찾지 못함
     return []
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 3: extractAccelerationData
     ───────────────────────────────────────────────────────────────────────

     【목적】
     MP4 파일에서 가속도(G-센서) 데이터를 찾아 파싱합니다.

     【가속도 데이터의 저장 위치】
     GPS와 유사하지만 다른 키/스트림을 사용:

     1. 데이터 스트림 (AVMEDIA_TYPE_DATA)
     GPS와 별도 스트림 또는 같은 스트림에 혼합

     2. 포맷 레벨 메타데이터
     키: "accelerometer", "gsensor", "accel" 등

     【데이터 형식】
     1. Binary 형식
     - Float32: 각 축당 4바이트
     - Int16: 각 축당 2바이트
     - 구조: XYZXYZXYZ... (인터리브)

     2. CSV 형식
     ```
     timestamp,x,y,z
     0.0,0.12,-0.05,0.98
     0.1,0.14,-0.03,1.02
     ...
     ```

     【파싱 전략】
     AccelerationParser는 자동 형식 감지 기능이 있습니다:
     1. Binary 형식 시도 (parseAccelerationData)
     2. 실패하면 CSV 형식 시도 (parseCSVData)

     【검색 순서】
     1. 모든 AVMEDIA_TYPE_DATA 스트림 순회
     2. readStreamData()로 패킷 읽기
     3. Binary 파싱 시도
     4. 실패하면 CSV 파싱 시도
     5. 성공하면 반환, 실패하면 다음 스트림
     6. 스트림에서 찾지 못하면 메타데이터 딕셔너리 조회
     7. "accelerometer" 또는 "gsensor" 키로 추출

     【타임스탬프 계산】
     GPS와 동일:
     absolute_time = baseDate + relative_timestamp
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief MP4 파일에서 가속도 데이터 추출
     ///
     /// @param formatContext FFmpeg의 AVFormatContext
     /// @param baseDate 녹화 시작 시각
     /// @return 가속도 데이터 배열, 없으면 빈 배열
     ///
     /// @details
     /// 데이터 스트림과 메타데이터 딕셔너리를 검색하여 G-센서 정보를 찾고 파싱합니다.
     ///
     /// 검색 위치:
     /// 1. AVMEDIA_TYPE_DATA 스트림
     /// 2. 포맷 레벨 메타데이터 ("accelerometer", "gsensor" 키)
     ///
     /// 지원 형식:
     /// - Binary (Float32 또는 Int16)
     /// - CSV (timestamp,x,y,z)
     ///
     /// 형식 자동 감지:
     /// AccelerationParser가 자동으로 형식을 판별하여 파싱합니다.
     ///
     /// 사용 예시 (향후):
     /// ```swift
     /// let accelData = extractAccelerationData(from: formatContext, baseDate: baseDate)
     /// print("\(accelData.count)개 가속도 샘플 추출")
     ///
     /// // 최대 충격 값 계산
     /// let maxImpact = accelData.map { sample in
     ///     sqrt(sample.x*sample.x + sample.y*sample.y + sample.z*sample.z)
     /// }.max() ?? 0
     /// print("최대 충격: \(maxImpact)G")
     /// ```
     private func extractAccelerationData(from formatContext: OpaquePointer, baseDate: Date) -> [AccelerationData] {
     // 1단계: 모든 데이터 스트림 순회
     let numStreams = Int(formatContext.pointee.nb_streams)
     var streams = formatContext.pointee.streams

     for i in 0..<numStreams {
     guard let stream = streams?[i] else { continue }
     let codecType = stream.pointee.codecpar.pointee.codec_type

     // 가속도 데이터는 보통 Data 스트림에 저장
     if codecType == AVMEDIA_TYPE_DATA {
     if let accelData = readStreamData(from: formatContext, streamIndex: i) {
     // Binary 형식 파싱 시도
     let data = accelerationParser.parseAccelerationData(accelData, baseDate: baseDate)
     if !data.isEmpty {
     return data
     }

     // CSV 형식 파싱 시도
     let csvData = accelerationParser.parseCSVData(accelData, baseDate: baseDate)
     if !csvData.isEmpty {
     return csvData
     }
     }
     }
     }

     // 2단계: 포맷 레벨 메타데이터 확인
     if let metadata = formatContext.pointee.metadata {
     // "accelerometer" 또는 "gsensor" 키로 조회
     if let accelData = extractMetadataEntry(metadata, key: "accelerometer") ??
     extractMetadataEntry(metadata, key: "gsensor") {
     let data = accelerationParser.parseAccelerationData(accelData, baseDate: baseDate)
     if !data.isEmpty {
     return data
     }
     }
     }

     // 가속도 데이터를 찾지 못함
     return []
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 4: extractDeviceInfo
     ───────────────────────────────────────────────────────────────────────

     【목적】
     블랙박스 디바이스의 제조사, 모델, 펌웨어 등 정보를 추출합니다.

     【메타데이터 키】
     MP4 표준 및 제조사별 커스텀 키:

     표준 키 (MOV/MP4):
     - "make" 또는 "manufacturer" : 제조사
     - "model"                    : 모델명
     - "encoder"                  : 인코더 소프트웨어

     커스텀 키 (제조사별):
     - "firmware_version"         : 펌웨어 버전
     - "serial_number"            : 시리얼 번호
     - "device_id"                : 디바이스 ID
     - "recording_mode"           : 녹화 모드

     【예시】
     BlackVue DR900X:
     - manufacturer: "BlackVue"
     - model: "DR900X-2CH"
     - firmware: "v1.012"
     - recording_mode: "Event"

     Thinkware U1000:
     - manufacturer: "THINKWARE"
     - model: "U1000"
     - firmware: "v2.003"

     【DeviceInfo 구조체】
     ```swift
     struct DeviceInfo {
     let manufacturer: String?
     let model: String?
     let firmwareVersion: String?
     let serialNumber: String?
     let recordingMode: String?
     }
     ```

     【Optional 처리】
     모든 필드가 Optional인 이유:
     - 일부 제조사는 일부 정보만 포함
     - 오래된 모델은 메타데이터 없음
     - 최소 1개 필드라도 있으면 DeviceInfo 반환, 없으면 nil
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief MP4 파일에서 디바이스 정보 추출
     ///
     /// @param formatContext FFmpeg의 AVFormatContext
     /// @return DeviceInfo, 메타데이터가 없으면 nil
     ///
     /// @details
     /// 포맷 레벨 메타데이터 딕셔너리에서 제조사, 모델, 펌웨어 등을 조회합니다.
     ///
     /// 추출 필드:
     /// - manufacturer: 제조사 ("make" 또는 "manufacturer" 키)
     /// - model: 모델명 ("model" 키)
     /// - firmwareVersion: 펌웨어 버전 ("firmware" 또는 "firmware_version" 키)
     /// - serialNumber: 시리얼 번호 ("serial_number" 또는 "device_id" 키)
     /// - recordingMode: 녹화 모드 ("recording_mode" 키)
     ///
     /// 반환 조건:
     /// 위 필드 중 최소 1개라도 추출되면 DeviceInfo 반환, 모두 nil이면 nil 반환
     ///
     /// 사용 예시 (향후):
     /// ```swift
     /// if let deviceInfo = extractDeviceInfo(from: formatContext) {
     ///     print("디바이스: \(deviceInfo.manufacturer ?? "Unknown") \(deviceInfo.model ?? "")")
     ///     print("펌웨어: \(deviceInfo.firmwareVersion ?? "Unknown")")
     ///     print("녹화 모드: \(deviceInfo.recordingMode ?? "Normal")")
     /// }
     /// ```
     private func extractDeviceInfo(from formatContext: OpaquePointer) -> DeviceInfo? {
     // 메타데이터 딕셔너리 확인
     guard let metadata = formatContext.pointee.metadata else {
     return nil
     }

     // 각 필드 추출 (여러 키 시도)
     let manufacturer = extractMetadataString(metadata, key: "manufacturer") ??
     extractMetadataString(metadata, key: "make")
     let model = extractMetadataString(metadata, key: "model")
     let firmware = extractMetadataString(metadata, key: "firmware") ??
     extractMetadataString(metadata, key: "firmware_version")
     let serial = extractMetadataString(metadata, key: "serial_number") ??
     extractMetadataString(metadata, key: "device_id")
     let mode = extractMetadataString(metadata, key: "recording_mode")

     // 최소 1개 필드라도 있으면 DeviceInfo 반환
     if manufacturer != nil || model != nil || firmware != nil || serial != nil || mode != nil {
     return DeviceInfo(
     manufacturer: manufacturer,
     model: model,
     firmwareVersion: firmware,
     serialNumber: serial,
     recordingMode: mode
     )
     }

     // 모든 필드가 nil이면 nil 반환
     return nil
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 5: readStreamData
     ───────────────────────────────────────────────────────────────────────

     【목적】
     특정 스트림의 모든 패킷을 읽어 Data로 반환합니다.

     【FFmpeg 패킷 읽기 과정】
     1. av_packet_alloc(): 패킷 구조체 할당
     2. av_read_frame(): 다음 패킷 읽기
     3. 패킷의 stream_index 확인 (원하는 스트림인지)
     4. 패킷의 data와 size를 Swift Data에 추가
     5. av_packet_unref(): 패킷 메모리 해제
     6. 반복 (파일 끝까지)
     7. av_seek_frame(): 파일 처음으로 되돌리기
     8. av_packet_free(): 패킷 구조체 해제

     【메모리 관리】
     - av_packet_alloc()으로 할당한 패킷은 av_packet_free()로 해제
     - defer { av_packet_free(&packet) }: 함수 종료 시 자동 해제
     - av_packet_unref(): 각 패킷 읽기 후 참조 카운트 감소

     【Seek Back】
     모든 패킷을 읽으면 파일 포인터가 끝에 도달합니다.
     av_seek_frame()으로 처음으로 되돌려야 다른 스트림도 읽을 수 있습니다.

     【빈 Data 처리】
     스트림에 패킷이 없거나 모두 다른 스트림이면 빈 Data 반환.
     이는 nil로 처리하여 호출자가 다음 스트림을 시도하도록 합니다.
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief 특정 스트림의 모든 패킷 읽기
     ///
     /// @param formatContext FFmpeg의 AVFormatContext
     /// @param streamIndex 읽을 스트림의 인덱스 (0, 1, 2, ...)
     /// @return 모든 패킷을 결합한 Data, 패킷이 없으면 nil
     ///
     /// @details
     /// FFmpeg의 av_read_frame()으로 패킷을 순차적으로 읽어 Data로 누적합니다.
     ///
     /// 동작 과정:
     /// 1. av_packet_alloc(): 패킷 구조체 할당
     /// 2. 반복: av_read_frame()으로 패킷 읽기
     ///    - 패킷의 stream_index가 일치하면 data 추가
     ///    - av_packet_unref(): 패킷 참조 해제
     /// 3. av_seek_frame(): 파일 처음으로 되돌리기
     /// 4. av_packet_free(): 패킷 구조체 해제 (defer)
     /// 5. 누적된 Data 반환
     ///
     /// 메모리 관리:
     /// - defer로 자동 메모리 해제 보장
     /// - av_packet_unref()로 각 패킷 후처리
     ///
     /// Seek Back 이유:
     /// 다른 스트림도 읽을 수 있도록 파일 포인터를 처음으로 되돌립니다.
     ///
     /// 사용 예시 (향후):
     /// ```swift
     /// // Stream #2 (GPS 데이터) 읽기
     /// if let gpsData = readStreamData(from: formatContext, streamIndex: 2) {
     ///     print("GPS 데이터: \(gpsData.count) bytes")
     ///     let gpsPoints = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     /// }
     /// ```
     private func readStreamData(from formatContext: OpaquePointer, streamIndex: Int) -> Data? {
     var accumulatedData = Data()

     // 패킷 구조체 할당
     guard let packet = av_packet_alloc() else {
     return nil
     }
     // defer: 함수 종료 시 자동 실행
     defer { av_packet_free(&(UnsafeMutablePointer(mutating: packet))) }

     // 모든 패킷 읽기
     while av_read_frame(formatContext, packet) >= 0 {
     // defer: 루프 종료 시 패킷 참조 해제
     defer { av_packet_unref(packet) }

     // 원하는 스트림의 패킷인지 확인
     if Int(packet.pointee.stream_index) == streamIndex {
     // 패킷 데이터를 Swift Data에 추가
     if let data = packet.pointee.data {
     let size = Int(packet.pointee.size)
     accumulatedData.append(Data(bytes: data, count: size))
     }
     }
     }

     // 파일 포인터를 처음으로 되돌리기
     // AVSEEK_FLAG_BACKWARD: 이전 키프레임으로 이동
     av_seek_frame(formatContext, Int32(streamIndex), 0, AVSEEK_FLAG_BACKWARD)

     // 데이터가 없으면 nil 반환
     return accumulatedData.isEmpty ? nil : accumulatedData
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 6: extractMetadataEntry (Data 버전)
     ───────────────────────────────────────────────────────────────────────

     【목적】
     FFmpeg의 AVDictionary에서 특정 키의 값을 Data로 추출합니다.

     【AVDictionary란?】
     FFmpeg의 key-value 저장소:
     ```
     Dictionary {
     "gps": "$GPGGA,123456,..."
     "accelerometer": "binary data..."
     "manufacturer": "BlackVue"
     "model": "DR900X"
     }
     ```

     【av_dict_get()】
     C API 함수:
     ```c
     AVDictionaryEntry *av_dict_get(
     const AVDictionary *dict,
     const char *key,
     const AVDictionaryEntry *prev,
     int flags
     );
     ```

     파라미터:
     - dict: 딕셔너리
     - key: 찾을 키 (예: "gps")
     - prev: 이전 엔트리 (nil: 처음부터 검색)
     - flags: 검색 옵션 (0: 정확히 일치)

     반환값:
     - 찾으면 AVDictionaryEntry 포인터
     - 못 찾으면 nil

     【AVDictionaryEntry 구조】
     ```c
     typedef struct AVDictionaryEntry {
     char *key;     // 키
     char *value;   // 값 (C 문자열)
     } AVDictionaryEntry;
     ```

     【String → Data 변환】
     value는 C 문자열이므로 Swift String으로 변환 후 Data로 변환:
     ```swift
     let string = String(cString: value)
     let data = string.data(using: .utf8)
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief 메타데이터 딕셔너리에서 Data 추출
     ///
     /// @param dict AVDictionary (FFmpeg 메타데이터 딕셔너리)
     /// @param key 조회할 키 (예: "gps", "accelerometer")
     /// @return 값의 Data 표현, 키가 없으면 nil
     ///
     /// @details
     /// FFmpeg의 AVDictionary에서 지정된 키의 값을 읽어 Data로 변환합니다.
     ///
     /// 동작 과정:
     /// 1. av_dict_get()으로 키 검색
     /// 2. 찾으면 value (C 문자열) 추출
     /// 3. String(cString:)으로 Swift 문자열 변환
     /// 4. data(using: .utf8)으로 Data 변환
     ///
     /// 사용 예시 (향후):
     /// ```swift
     /// if let metadata = formatContext.pointee.metadata {
     ///     if let gpsData = extractMetadataEntry(metadata, key: "gps") {
     ///         let gpsPoints = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
     ///     }
     /// }
     /// ```
     ///
     /// 참고:
     /// - Binary 데이터도 C 문자열로 저장된 경우가 있어 Data로 변환
     /// - UTF-8 인코딩 실패 시 nil 반환
     private func extractMetadataEntry(_ dict: OpaquePointer, key: String) -> Data? {
     var entry: UnsafeMutablePointer<AVDictionaryEntry>?

     // AVDictionary에서 키 검색
     // av_dict_get(딕셔너리, 키, 이전 엔트리, 플래그)
     entry = av_dict_get(dict, key, nil, 0)

     // 키를 찾지 못했거나 값이 없으면 nil
     guard let entry = entry, let value = entry.pointee.value else {
     return nil
     }

     // C 문자열 → Swift String → Data
     let string = String(cString: value)
     return string.data(using: .utf8)
     }
     */

    /*
     ───────────────────────────────────────────────────────────────────────
     메서드 7: extractMetadataString (String 버전)
     ───────────────────────────────────────────────────────────────────────

     【목적】
     메타데이터에서 문자열 값을 직접 추출합니다.

     【차이점: extractMetadataEntry vs extractMetadataString】

     extractMetadataEntry:
     - 반환 타입: Data?
     - 용도: GPS/가속도 데이터 (이진 데이터 가능)
     - 변환: String → Data

     extractMetadataString:
     - 반환 타입: String?
     - 용도: 디바이스 정보 (순수 텍스트)
     - 변환: C 문자열 → Swift String

     【사용 시나리오】
     디바이스 정보는 순수 텍스트이므로 String으로 충분:
     - "manufacturer": "BlackVue"
     - "model": "DR900X-2CH"
     - "firmware": "v1.012"

     GPS/가속도는 Data가 필요:
     - "gps": "$GPGGA,..." (텍스트지만 파서가 Data 요구)
     - "accelerometer": binary data (이진 데이터)
     ───────────────────────────────────────────────────────────────────────
     */

    /*
     /// @brief 메타데이터 딕셔너리에서 String 추출
     ///
     /// @param dict AVDictionary
     /// @param key 조회할 키 (예: "manufacturer", "model")
     /// @return 값의 문자열, 키가 없으면 nil
     ///
     /// @details
     /// FFmpeg의 AVDictionary에서 지정된 키의 값을 String으로 반환합니다.
     ///
     /// 동작 과정:
     /// 1. av_dict_get()으로 키 검색
     /// 2. 찾으면 value (C 문자열) 추출
     /// 3. String(cString:)으로 Swift 문자열 변환
     /// 4. 반환
     ///
     /// 사용 예시 (향후):
     /// ```swift
     /// if let metadata = formatContext.pointee.metadata {
     ///     let manufacturer = extractMetadataString(metadata, key: "manufacturer")
     ///     let model = extractMetadataString(metadata, key: "model")
     ///     print("디바이스: \(manufacturer ?? "Unknown") \(model ?? "")")
     /// }
     /// ```
     ///
     /// 참고:
     /// - 순수 텍스트 정보 추출 시 사용
     /// - Data 변환 없이 직접 String 반환
     private func extractMetadataString(_ dict: OpaquePointer, key: String) -> String? {
     var entry: UnsafeMutablePointer<AVDictionaryEntry>?

     // AVDictionary에서 키 검색
     entry = av_dict_get(dict, key, nil, 0)

     // 키를 찾지 못했거나 값이 없으면 nil
     guard let entry = entry, let value = entry.pointee.value else {
     return nil
     }

     // C 문자열 → Swift String
     return String(cString: value)
     }
     */
}

// MARK: - Extraction Errors

/*
 ───────────────────────────────────────────────────────────────────────────
 메타데이터 추출 오류
 ───────────────────────────────────────────────────────────────────────────

 【오류 종류】
 1. cannotOpenFile: 파일을 열 수 없음
 - 파일이 존재하지 않음
 - 권한 부족
 - 파일이 손상됨
 - 지원하지 않는 형식

 2. noMetadataFound: 메타데이터가 없음
 - GPS/G-센서 미장착 모델
 - 위성 신호 없음 (터널, 실내)
 - 메타데이터가 삭제됨

 3. invalidMetadataFormat: 메타데이터 형식이 잘못됨
 - 파싱 실패
 - 손상된 데이터
 - 지원하지 않는 형식

 【LocalizedError 프로토콜】
 사용자에게 표시할 오류 메시지를 제공합니다.

 ```swift
 do {
 let metadata = try extractor.extractMetadata(from: path)
 } catch {
 // error.localizedDescription이 자동으로 호출됨
 print(error.localizedDescription)
 }
 ```

 【향후 개선】
 더 구체적인 오류 정보 추가:
 ```swift
 enum MetadataExtractionError: Error {
 case cannotOpenFile(String, reason: String)
 case noMetadataFound(searched: [String])  // 검색한 위치
 case invalidMetadataFormat(format: String, details: String)
 case ffmpegError(code: Int32)
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

/// @enum MetadataExtractionError
/// @brief 메타데이터 추출 중 발생할 수 있는 오류
enum MetadataExtractionError: Error {

    /// @case cannotOpenFile
    /// @brief 파일을 열 수 없음
    /// @details
    /// 발생 시나리오:
    /// - 파일이 존재하지 않음
    /// - 파일 권한 부족 (읽기 권한 없음)
    /// - 파일이 손상됨 (MP4 헤더 오류)
    /// - 지원하지 않는 형식 (AVI, MKV 등)
    ///
    /// 복구 방법:
    /// 1. 파일 경로 확인
    /// 2. 파일 권한 확인 (chmod 644)
    /// 3. 다른 플레이어로 열기 시도 (VLC 등)
    /// 4. 파일 복구 도구 사용
    case cannotOpenFile(String)

    /// @case noMetadataFound
    /// @brief 메타데이터를 찾을 수 없음
    /// @details
    /// 발생 시나리오:
    /// - GPS 미장착 블랙박스 모델
    /// - 위성 신호 수신 실패 (터널, 실내 주차장)
    /// - G-센서 미장착 모델
    /// - 메타데이터가 의도적으로 제거됨
    ///
    /// 참고:
    /// - 비디오 자체는 정상 재생 가능
    /// - GPS/가속도 오버레이만 표시되지 않음
    case noMetadataFound

    /// @case invalidMetadataFormat
    /// @brief 메타데이터 형식이 잘못됨
    /// @details
    /// 발생 시나리오:
    /// - 파싱 실패 (잘못된 NMEA 형식)
    /// - 손상된 Binary 데이터
    /// - 알 수 없는 제조사별 커스텀 형식
    /// - 인코딩 문제 (UTF-8 아닌 다른 인코딩)
    ///
    /// 복구 방법:
    /// 1. 제조사별 파서 추가 구현
    /// 2. 형식 변환 도구 사용
    /// 3. 제조사에 문의
    case invalidMetadataFormat
}

/*
 ───────────────────────────────────────────────────────────────────────────
 LocalizedError 확장
 ───────────────────────────────────────────────────────────────────────────

 【LocalizedError 프로토콜】
 Error에 사용자 친화적인 설명을 추가합니다.

 ```swift
 protocol LocalizedError : Error {
 var errorDescription: String? { get }
 var failureReason: String? { get }
 var recoverySuggestion: String? { get }
 var helpAnchor: String? { get }
 }
 ```

 여기서는 errorDescription만 구현합니다.

 【다국어 지원】
 향후 NSLocalizedString으로 변경 가능:
 ```swift
 var errorDescription: String? {
 switch self {
 case .cannotOpenFile(let path):
 return NSLocalizedString(
 "metadata.error.cannotOpen",
 comment: "Cannot open file error"
 )
 }
 }
 ```
 ───────────────────────────────────────────────────────────────────────────
 */

extension MetadataExtractionError: LocalizedError {
    /// @var errorDescription
    /// @brief 사용자에게 표시할 오류 설명
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path):
            return "Cannot open file: \(path)"
        case .noMetadataFound:
            return "No metadata found in file"
        case .invalidMetadataFormat:
            return "Invalid metadata format"
        }
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 가이드
 ═══════════════════════════════════════════════════════════════════════════

 【1. 기본 사용법】

 ```swift
 let extractor = MetadataExtractor()

 // 단일 파일 추출
 if let metadata = extractor.extractMetadata(from: "/Videos/20240115_143025_F.mp4") {
 print("GPS: \(metadata.gpsPoints.count) points")
 print("G-sensor: \(metadata.accelerationData.count) samples")

 if let device = metadata.deviceInfo {
 print("Device: \(device.manufacturer ?? "") \(device.model ?? "")")
 }
 }
 ```

 【2. 비동기 처리 (백그라운드 스레드)】

 추출 작업은 시간이 걸리므로 백그라운드에서 실행:

 ```swift
 class VideoLoader {
 func loadMetadata(from path: String, completion: @escaping (VideoMetadata?) -> Void) {
 DispatchQueue.global(qos: .userInitiated).async {
 let extractor = MetadataExtractor()
 let metadata = extractor.extractMetadata(from: path)

 DispatchQueue.main.async {
 completion(metadata)
 }
 }
 }
 }

 // 사용
 let loader = VideoLoader()
 loader.loadMetadata(from: videoPath) { metadata in
 guard let metadata = metadata else {
 print("메타데이터 추출 실패")
 return
 }
 // UI 업데이트
 }
 ```

 【3. async/await 사용 (Swift Concurrency)】

 ```swift
 @MainActor
 class VideoViewModel: ObservableObject {
 @Published var metadata: VideoMetadata?
 @Published var isLoading = false

 func loadMetadata(from path: String) async {
 isLoading = true
 defer { isLoading = false }

 metadata = await Task.detached(priority: .userInitiated) {
 let extractor = MetadataExtractor()
 return extractor.extractMetadata(from: path)
 }.value
 }
 }

 // SwiftUI에서 사용
 struct VideoView: View {
 @StateObject private var viewModel = VideoViewModel()

 var body: some View {
 VStack {
 if viewModel.isLoading {
 ProgressView("메타데이터 로딩 중...")
 } else if let metadata = viewModel.metadata {
 Text("GPS: \(metadata.gpsPoints.count) points")
 Text("G-sensor: \(metadata.accelerationData.count) samples")
 }
 }
 .task {
 await viewModel.loadMetadata(from: videoPath)
 }
 }
 }
 ```

 【4. 멀티 채널 비디오 통합】

 2채널 블랙박스 (전방 + 후방):

 ```swift
 let extractor = MetadataExtractor()

 // 전방 카메라 (GPS 포함)
 let frontMetadata = extractor.extractMetadata(from: "20240115_143025_F.mp4")

 // 후방 카메라 (GPS 없음, G-센서만)
 let rearMetadata = extractor.extractMetadata(from: "20240115_143025_R.mp4")

 // 통합
 let gpsPoints = frontMetadata?.gpsPoints ?? []
 let frontAccel = frontMetadata?.accelerationData ?? []
 let rearAccel = rearMetadata?.accelerationData ?? []

 // G-센서 값은 평균 또는 최대값 사용
 let combinedAccel = zip(frontAccel, rearAccel).map { (front, rear) in
 AccelerationData(
 timestamp: front.timestamp,
 x: (front.x + rear.x) / 2,
 y: (front.y + rear.y) / 2,
 z: (front.z + rear.z) / 2
 )
 }
 ```

 【5. 재생 시간에 맞춰 메타데이터 조회】

 ```swift
 class MetadataOverlay {
 let metadata: VideoMetadata

 /// 현재 재생 시각의 GPS 위치
 func currentGPS(at time: TimeInterval) -> GPSPoint? {
 return metadata.gpsPoints.first { abs($0.timestamp - time) < 0.1 }
 }

 /// 현재 재생 시각의 G-센서 값
 func currentAcceleration(at time: TimeInterval) -> AccelerationData? {
 return metadata.accelerationData.first { abs($0.timestamp - time) < 0.05 }
 }

 /// 충격 감지
 func detectImpact(at time: TimeInterval, threshold: Double = 2.0) -> Bool {
 guard let accel = currentAcceleration(at: time) else { return false }
 let magnitude = sqrt(accel.x*accel.x + accel.y*accel.y + accel.z*accel.z)
 return magnitude > threshold
 }
 }

 // 사용
 let overlay = MetadataOverlay(metadata: metadata)
 let currentTime: TimeInterval = 15.5

 if let gps = overlay.currentGPS(at: currentTime) {
 print("현재 위치: \(gps.coordinate.latitude), \(gps.coordinate.longitude)")
 print("현재 속도: \(gps.speed ?? 0) km/h")
 }

 if overlay.detectImpact(at: currentTime) {
 print("⚠️ 충격 감지!")
 }
 ```

 【6. 오류 처리 패턴 (향후 throws 사용 시)】

 ```swift
 do {
 let metadata = try extractor.extractMetadata(from: path)
 // 성공 처리

 } catch MetadataExtractionError.cannotOpenFile(let path) {
 showAlert("파일을 열 수 없습니다: \(path)")

 } catch MetadataExtractionError.noMetadataFound {
 // 메타데이터 없이 비디오만 재생
 showWarning("GPS/G-센서 데이터가 없습니다")

 } catch MetadataExtractionError.invalidMetadataFormat {
 showWarning("메타데이터 형식을 인식할 수 없습니다")

 } catch {
 showAlert("알 수 없는 오류: \(error)")
 }
 ```

 【7. 테스트 코드】

 ```swift
 class MetadataExtractorTests: XCTestCase {
 var extractor: MetadataExtractor!

 override func setUp() {
 extractor = MetadataExtractor()
 }

 func testExtractGPS() {
 let metadata = extractor.extractMetadata(from: testVideoPath)
 XCTAssertNotNil(metadata)
 XCTAssertFalse(metadata!.gpsPoints.isEmpty)

 let firstGPS = metadata!.gpsPoints[0]
 XCTAssertEqual(firstGPS.coordinate.latitude, 37.5665, accuracy: 0.001)
 XCTAssertEqual(firstGPS.speed, 45.0, accuracy: 0.1)
 }

 func testExtractAcceleration() {
 let metadata = extractor.extractMetadata(from: testVideoPath)
 XCTAssertNotNil(metadata)
 XCTAssertFalse(metadata!.accelerationData.isEmpty)

 let firstAccel = metadata!.accelerationData[0]
 XCTAssertEqual(firstAccel.x, 0.0, accuracy: 0.1)
 XCTAssertEqual(firstAccel.z, 1.0, accuracy: 0.1)  // 중력
 }

 func testNoMetadata() {
 let metadata = extractor.extractMetadata(from: videoWithoutMetadata)
 XCTAssertNotNil(metadata)
 XCTAssertTrue(metadata!.gpsPoints.isEmpty)
 XCTAssertTrue(metadata!.accelerationData.isEmpty)
 }
 }
 ```

 ═══════════════════════════════════════════════════════════════════════════
 */
