/// @file GPSPoint.swift
/// @brief 블랙박스 GPS 위치 데이터 모델
/// @author BlackboxPlayer Development Team
/// @details 블랙박스 비디오에 임베드된 GPS 위치 데이터를 표현하는 구조체입니다.
///          위도, 경도, 고도, 속도, 방향 등의 정보를 포함하며, CoreLocation과의 호환성을 제공합니다.

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                          GPSPoint 모델 개요                              │
 │                                                                          │
 │  블랙박스 비디오에 임베드된 GPS 위치 데이터를 표현하는 구조체입니다.     │
 │                                                                          │
 │  【주요 속성】                                                           │
 │  1. timestamp: 측정 시각                                                 │
 │  2. latitude/longitude: 위도/경도 (십진법)                               │
 │  3. altitude: 고도 (미터)                                                │
 │  4. speed: 속도 (km/h)                                                   │
 │  5. heading: 방향/진행각 (0-360도)                                       │
 │  6. horizontalAccuracy: 수평 정확도 (미터)                               │
 │  7. satelliteCount: 위성 개수                                            │
 │                                                                          │
 │  【좌표 시스템】                                                         │
 │                                                                          │
 │  위도 (Latitude):                                                        │
 │    -90° (남극) ◀─────── 0° (적도) ────────▶ +90° (북극)                 │
 │                                                                          │
 │  경도 (Longitude):                                                       │
 │    -180° (서쪽) ◀────── 0° (본초 자오선) ──────▶ +180° (동쪽)           │
 │                                                                          │
 │  방향 (Heading):                                                         │
 │              0° (북쪽)                                                   │
 │               │                                                          │
 │        270° ──┼── 90° (동쪽)                                            │
 │               │                                                          │
 │             180° (남쪽)                                                  │
 │                                                                          │
 │  【데이터 소스】                                                         │
 │                                                                          │
 │  블랙박스 SD 카드                                                        │
 │      │                                                                   │
 │      ├─ 20250115_100000_F.mp4 (비디오)                                  │
 │      └─ 20250115_100000.gps (GPS 데이터)                                │
 │           │                                                              │
 │           ├─ $GPRMC (위치, 속도, 방향)                                  │
 │           └─ $GPGGA (고도, 위성, 정확도)                                │
 │                │                                                         │
 │                ▼                                                         │
 │           GPSParser                                                      │
 │                │                                                         │
 │                ▼                                                         │
 │           GPSPoint (이 구조체)                                           │
 │                │                                                         │
 │                ▼                                                         │
 │           MapKit / CoreLocation                                          │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【Struct vs Class 선택 기준】

 이 모델은 struct로 정의되었습니다. 그 이유는:

 1. 값 타입 (Value Type):
 - GPS 데이터는 불변(immutable)이어야 함
 - 복사 시 완전히 독립적인 사본 생성
 - 참조 추적 불필요

 2. 스택 메모리:
 - 힙(heap)이 아닌 스택(stack)에 할당
 - 더 빠른 생성/해제
 - ARC(Automatic Reference Counting) 오버헤드 없음

 3. 스레드 안전:
 - 여러 스레드에서 동시 접근해도 안전
 - 각 스레드가 독립적인 복사본 보유
 - 동기화 메커니즘 불필요

 예시:
 ```swift
 var point1 = GPSPoint(timestamp: Date(), latitude: 37.5, longitude: 127.0)
 var point2 = point1  // 완전한 복사본 생성

 point2.latitude = 38.0  // ❌ 컴파일 에러! (let 속성이므로 불변)
 // struct는 값 타입이므로 point1은 영향 받지 않음
 ```

 【Codable 프로토콜이란?】

 Codable = Encodable + Decodable

 Swift 객체를 JSON, Property List 등의 외부 표현으로 변환하거나
 그 반대로 변환할 수 있게 해주는 프로토콜입니다.

 JSON ↔ GPSPoint 변환 예시:
 ```swift
 // GPSPoint → JSON (Encoding)
 let point = GPSPoint(timestamp: Date(), latitude: 37.5, longitude: 127.0)
 let encoder = JSONEncoder()
 let jsonData = try encoder.encode(point)

 // JSON:
 // {
 //   "timestamp": 1641974400.0,
 //   "latitude": 37.5,
 //   "longitude": 127.0,
 //   "altitude": null,
 //   "speed": null
 // }

 // JSON → GPSPoint (Decoding)
 let decoder = JSONDecoder()
 let decoded = try decoder.decode(GPSPoint.self, from: jsonData)
 ```

 사용 사례:
 - GPS 데이터 파일 저장/로딩
 - 네트워크 통신
 - UserDefaults 저장
 - CloudKit 동기화

 【Equatable & Hashable 프로토콜】

 Equatable:
 - 두 GPSPoint가 같은지 비교 (==, !=)
 - 자동 생성: 모든 속성이 같으면 같은 것으로 간주

 Hashable:
 - Set, Dictionary의 키로 사용 가능
 - hash() 함수 자동 생성
 - 같은 값은 항상 같은 해시값

 예시:
 ```swift
 let point1 = GPSPoint(timestamp: date1, latitude: 37.5, longitude: 127.0)
 let point2 = GPSPoint(timestamp: date1, latitude: 37.5, longitude: 127.0)

 // Equatable
 if point1 == point2 {
 print("같은 위치입니다")
 }

 // Hashable
 var uniqueLocations: Set<GPSPoint> = []
 uniqueLocations.insert(point1)
 uniqueLocations.insert(point2)  // 중복이면 무시됨
 print("고유 위치 개수: \(uniqueLocations.count)")

 // Dictionary 키로 사용
 var pointData: [GPSPoint: String] = [:]
 pointData[point1] = "서울시청"
 ```
 */

import Foundation
import CoreLocation

/*
 【GPSPoint 구조체】

 블랙박스 녹화 중 수집된 GPS 위치 데이터 포인트입니다.

 데이터 구조:
 - 값 타입 (struct) - 불변성과 스레드 안전성
 - Codable - JSON 직렬화/역직렬화
 - Equatable - 비교 연산 (==, !=)
 - Hashable - Set, Dictionary 키로 사용 가능
 - Identifiable - SwiftUI List에서 사용

 사용 예시:
 ```swift
 // 1. GPS 데이터 파싱
 let parser = GPSParser()
 let points = try parser.parseGPSData(from: gpsFileURL)

 // 2. 지도에 표시
 for point in points {
 let annotation = MKPointAnnotation()
 annotation.coordinate = point.coordinate
 mapView.addAnnotation(annotation)
 }

 // 3. 경로 분석
 let totalDistance = points.adjacentPairs()
 .map { $0.distance(to: $1) }
 .reduce(0, +)
 print("총 이동 거리: \(totalDistance)m")
 ```
 */
/// @struct GPSPoint
/// @brief 블랙박스 GPS 위치 데이터 포인트
/// @details 블랙박스 녹화 중 수집된 GPS 위치 데이터를 표현하는 구조체입니다.
///          값 타입(struct)으로 불변성과 스레드 안전성을 보장하며,
///          Codable, Equatable, Hashable 프로토콜을 준수합니다.
struct GPSPoint: Codable, Equatable, Hashable {
    /*
     【타임스탬프 (Timestamp)】

     이 GPS 측정이 이루어진 시각입니다.

     타입: Date
     - Swift의 표준 날짜/시간 타입
     - UTC 기준 (협정 세계시)
     - TimeInterval: 1970-01-01 00:00:00 UTC 이후 경과 초

     예시:
     ```swift
     let point = GPSPoint(timestamp: Date(), ...)

     // 포맷팅
     let formatter = DateFormatter()
     formatter.dateStyle = .medium
     formatter.timeStyle = .long
     print(formatter.string(from: point.timestamp))
     // "2025년 1월 15일 오전 10:30:45 GMT+9"

     // 비디오 시간과 동기화
     let videoStart = Date(timeIntervalSince1970: 1641974400)
     let offset = point.timestamp.timeIntervalSince(videoStart)
     print("비디오 재생 시각: \(offset)초")
     ```

     용도:
     - 비디오 프레임과 GPS 데이터 동기화
     - 시간 기반 필터링 (특정 시간대 경로만 표시)
     - 속도 계산 (거리 / 시간 차이)
     */
    /// @var timestamp
    /// @brief GPS 측정 시각
    let timestamp: Date

    /*
     【위도 (Latitude)】

     북위/남위를 나타내는 좌표입니다.

     범위: -90° ~ +90°
     - +90°: 북극
     - 0°: 적도
     - -90°: 남극

     십진법 (Decimal Degrees):
     - 37.5665° = 북위 37.5665도
     - 소수점 6자리 ≈ 0.1미터 정밀도

     예시 (대한민국):
     - 서울: 37.5665° (북위)
     - 부산: 35.1796° (북위)
     - 제주: 33.4996° (북위)

     변환:
     ```swift
     // 십진법 → 도분초(DMS)
     let dms = point.dmsString
     // "37°33'59.4\"N"

     // 십진법 → 지도 좌표
     let coordinate = point.coordinate
     mapView.centerCoordinate = coordinate
     ```

     주의사항:
     - 범위 검증 필수 (isValid 속성 사용)
     - Double 타입으로 충분한 정밀도 (약 1mm)
     */
    /// @var latitude
    /// @brief 위도 (-90° ~ +90°)
    let latitude: Double

    /*
     【경도 (Longitude)】

     동경/서경을 나타내는 좌표입니다.

     범위: -180° ~ +180°
     - 0°: 본초 자오선 (영국 그리니치 천문대)
     - +180°: 동쪽 (국제 날짜 변경선)
     - -180°: 서쪽 (국제 날짜 변경선)

     십진법 (Decimal Degrees):
     - 126.9780° = 동경 126.9780도
     - 소수점 6자리 ≈ 0.1미터 정밀도

     예시 (대한민국):
     - 서울: 126.9780° (동경)
     - 부산: 129.0756° (동경)
     - 제주: 126.5312° (동경)

     경도의 특징:
     - 위도와 달리 거리가 위치에 따라 변함
     - 적도에서: 경도 1° ≈ 111km
     - 북위 37°에서: 경도 1° ≈ 89km
     - 극지방에서: 경도 1° ≈ 0km

     계산 예시:
     ```swift
     let seoul = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     let busan = GPSPoint(latitude: 35.1796, longitude: 129.0756, ...)

     let distance = seoul.distance(to: busan)
     print("서울-부산 거리: \(distance / 1000)km")  // 약 325km
     ```
     */
    /// @var longitude
    /// @brief 경도 (-180° ~ +180°)
    let longitude: Double

    /*
     【고도 (Altitude)】

     해발 고도를 미터 단위로 나타냅니다.

     타입: Double? (Optional)
     - GPS 신호가 약하면 고도 정보 없을 수 있음
     - GPGGA 문장에만 포함 (GPRMC에는 없음)

     범위:
     - 음수: 해수면 아래 (예: 사해 -430m)
     - 0: 해수면
     - 양수: 해수면 위

     정확도:
     - 수평 정확도보다 낮음 (약 2배)
     - 건물 사이, 터널에서는 부정확

     예시 (대한민국):
     - 서울 시청: 15m
     - 남산타워: 243m
     - 인천공항: 7m
     - 백두산: 2744m

     사용 예시:
     ```swift
     if let altitude = point.altitude {
     print("현재 고도: \(Int(altitude))m")

     // 고도 변화율 계산 (등반/하강)
     let previousAltitude = previousPoint.altitude ?? 0
     let elevationChange = altitude - previousAltitude
     if elevationChange > 0 {
     print("등반 중: +\(elevationChange)m")
     }
     } else {
     print("고도 정보 없음")
     }
     ```
     */
    /// @var altitude
    /// @brief 고도 (미터, 옵셔널)
    let altitude: Double?

    /*
     【속도 (Speed)】

     이동 속도를 km/h 단위로 나타냅니다.

     타입: Double? (Optional)
     - GPS 신호가 약하거나 정지 중일 때 nil

     단위 변환:
     - GPS: m/s (초속)
     - 블랙박스: km/h (시속)
     - 변환: km/h = m/s × 3.6

     NMEA에서의 속도:
     - GPRMC 문장에서 knots(노트) 단위로 제공
     - 1 knot = 1.852 km/h
     - 변환: km/h = knots × 1.852

     정확도:
     - 정지 중일 때 작은 값 (0.5~2 km/h) 나올 수 있음
     - 이동 중: ±5% 오차
     - 고속 이동: 더 정확

     예시:
     ```swift
     if let speed = point.speed {
     print("현재 속도: \(Int(speed)) km/h")

     // 과속 감지
     if speed > 100 {
     print("⚠️ 과속 경고!")
     }

     // 속도 등급 분류
     switch speed {
     case 0..<5: print("정지")
     case 5..<30: print("저속")
     case 30..<80: print("일반 도로")
     case 80...: print("고속 도로")
     default: break
     }
     }

     // 평균 속도 계산
     let avgSpeed = points.compactMap { $0.speed }.reduce(0, +) / Double(points.count)
     print("평균 속도: \(Int(avgSpeed)) km/h")
     ```
     */
    /// @var speed
    /// @brief 속도 (km/h, 옵셔널)
    let speed: Double?

    /*
     【방향/진행각 (Heading)】

     이동 방향을 나타내는 각도입니다.

     타입: Double? (Optional)
     - 정지 중이거나 GPS 신호 약할 때 nil

     범위: 0° ~ 360°
     - 0° (또는 360°): 북쪽 (N)
     - 90°: 동쪽 (E)
     - 180°: 남쪽 (S)
     - 270°: 서쪽 (W)

     예시 (8방위):
     - 0°: 북 (N)
     - 45°: 북동 (NE)
     - 90°: 동 (E)
     - 135°: 남동 (SE)
     - 180°: 남 (S)
     - 225°: 남서 (SW)
     - 270°: 서 (W)
     - 315°: 북서 (NW)

     계산 방법:
     - 이전 위치와 현재 위치를 연결한 선의 방향
     - bearing(to:) 메서드로 계산 가능

     사용 예시:
     ```swift
     if let heading = point.heading {
     // 방향 문자열로 변환
     let direction: String
     switch heading {
     case 0..<22.5, 337.5...360: direction = "북"
     case 22.5..<67.5: direction = "북동"
     case 67.5..<112.5: direction = "동"
     case 112.5..<157.5: direction = "남동"
     case 157.5..<202.5: direction = "남"
     case 202.5..<247.5: direction = "남서"
     case 247.5..<292.5: direction = "서"
     case 292.5..<337.5: direction = "북서"
     default: direction = "알 수 없음"
     }
     print("진행 방향: \(direction)")

     // 화살표 아이콘 회전 (지도 UI)
     arrowImageView.transform = CGAffineTransform(rotationAngle: heading * .pi / 180)
     }
     ```

     CoreLocation 용어:
     - course: heading과 동일한 의미
     - bearing: 두 지점 사이의 방향 (계산으로 구함)
     */
    /// @var heading
    /// @brief 방향/진행각 (0° ~ 360°, 북쪽이 0°, 옵셔널)
    let heading: Double?

    /*
     【수평 정확도 (Horizontal Accuracy)】

     GPS 위치의 오차 범위를 미터 단위로 나타냅니다.

     타입: Double? (Optional)
     - GPS 신호가 없으면 nil

     의미:
     - 실제 위치가 이 반경 내에 있을 확률 68% (1σ)
     - 예: 5m → 실제 위치가 5m 반경 내에 있을 확률 68%

     정확도 등급:
     - < 5m: 매우 정확 (건물 식별 가능)
     - 5-10m: 정확 (도로 식별 가능)
     - 10-50m: 보통 (블록/구역 식별)
     - > 50m: 부정확 (GPS 신호 약함)

     영향 요인:
     1. 위성 개수 (많을수록 정확)
     2. 건물/지형 (하늘이 열려있을수록 정확)
     3. 날씨 (맑을수록 정확)
     4. 전리층 상태

     NMEA에서:
     - GPGGA 문장의 HDOP (Horizontal Dilution of Precision)
     - horizontalAccuracy ≈ HDOP × 10 (대략적 변환)

     사용 예시:
     ```swift
     if let accuracy = point.horizontalAccuracy {
     print("위치 정확도: ±\(Int(accuracy))m")

     // 정확도 필터링
     if accuracy > 50 {
     print("⚠️ GPS 신호 약함. 위치 부정확할 수 있음")
     // 이 데이터 포인트 무시 또는 표시 방법 변경
     }

     // 지도에 정확도 원 표시
     let circle = MKCircle(center: point.coordinate, radius: accuracy)
     mapView.addOverlay(circle)
     }

     // 정확한 포인트만 필터링
     let accuratePoints = allPoints.filter {
     guard let acc = $0.horizontalAccuracy else { return false }
     return acc < 20  // 20m 이내만
     }
     ```

     CoreLocation:
     - CLLocation.horizontalAccuracy와 동일
     - -1은 유효하지 않은 값을 의미
     */
    /// @var horizontalAccuracy
    /// @brief 수평 정확도 (미터, 옵셔널)
    let horizontalAccuracy: Double?

    /*
     【위성 개수 (Satellite Count)】

     위치 계산에 사용된 GPS 위성의 개수입니다.

     타입: Int? (Optional)
     - NMEA 데이터에 포함되지 않을 수 있음

     최소 요구사항:
     - 3D 위치 (위도, 경도, 고도): 최소 4개 위성
     - 2D 위치 (위도, 경도만): 최소 3개 위성

     위성 개수와 정확도:
     - 4개: 최소 요구사항 (정확도 낮음)
     - 6-8개: 일반적 (정확도 보통)
     - 8-12개: 좋음 (정확도 높음)
     - 12개 이상: 매우 좋음 (정확도 매우 높음)

     위성 종류:
     - GPS (미국): 24-32개 운영 중
     - GLONASS (러시아)
     - Galileo (유럽)
     - BeiDou (중국)
     - 최신 수신기는 여러 시스템 동시 사용

     사용 예시:
     ```swift
     if let satellites = point.satelliteCount {
     print("사용 중인 위성: \(satellites)개")

     // 신호 강도 표시
     let signalBars: Int
     switch satellites {
     case 0..<4: signalBars = 1  // 약함
     case 4..<6: signalBars = 2  // 보통
     case 6..<8: signalBars = 3  // 좋음
     case 8...: signalBars = 4   // 매우 좋음
     default: signalBars = 0
     }
     print("신호: \(String(repeating: "█", count: signalBars))")

     // 터널 진입 감지
     if satellites < 4 {
     print("⚠️ GPS 신호 약함 (터널/지하일 수 있음)")
     }
     }
     ```

     NMEA에서:
     - GPGGA 문장에 포함
     - 예: $GPGGA,...,08,...  → 8개 위성 사용
     */
    /// @var satelliteCount
    /// @brief 사용된 위성 개수 (옵셔널)
    let satelliteCount: Int?

    // MARK: - Initialization

    /*
     【초기화 메서드】

     GPSPoint 인스턴스를 생성합니다.

     필수 매개변수:
     - timestamp: 측정 시각
     - latitude: 위도 (-90 ~ 90)
     - longitude: 경도 (-180 ~ 180)

     선택적 매개변수 (기본값 nil):
     - altitude: 고도
     - speed: 속도
     - heading: 방향
     - horizontalAccuracy: 정확도
     - satelliteCount: 위성 개수

     기본값 패턴:
     ```swift
     func foo(required: Int, optional: String? = nil) { }

     foo(required: 1)  // optional은 nil
     foo(required: 1, optional: "value")  // optional은 "value"
     ```

     사용 예시:
     ```swift
     // 최소 정보만 (위도/경도)
     let point1 = GPSPoint(
     timestamp: Date(),
     latitude: 37.5665,
     longitude: 126.9780
     )

     // 전체 정보 포함
     let point2 = GPSPoint(
     timestamp: Date(),
     latitude: 37.5665,
     longitude: 126.9780,
     altitude: 15.0,
     speed: 45.0,
     heading: 90.0,
     horizontalAccuracy: 5.0,
     satelliteCount: 8
     )

     // 파싱 중 생성 (NMEA 데이터에서)
     let point3 = GPSPoint(
     timestamp: baseDate.addingTimeInterval(timeOffset),
     latitude: parsedLat,
     longitude: parsedLon,
     altitude: gpgga?.altitude,  // GPGGA에만 있음
     speed: gprmc?.speed,  // GPRMC에만 있음
     heading: gprmc?.heading,
     horizontalAccuracy: gpgga?.horizontalAccuracy,
     satelliteCount: gpgga?.satelliteCount
     )
     ```

     Struct 초기화 특징:
     - Memberwise initializer 자동 생성
     - 모든 속성을 매개변수로 받음
     - 기본값 지정 가능
     */
    /// @brief GPSPoint 인스턴스 초기화
    /// @param timestamp GPS 측정 시각
    /// @param latitude 위도 (-90 ~ 90)
    /// @param longitude 경도 (-180 ~ 180)
    /// @param altitude 고도 (미터, 기본값: nil)
    /// @param speed 속도 (km/h, 기본값: nil)
    /// @param heading 방향 (0-360도, 기본값: nil)
    /// @param horizontalAccuracy 수평 정확도 (미터, 기본값: nil)
    /// @param satelliteCount 위성 개수 (기본값: nil)
    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        speed: Double? = nil,
        heading: Double? = nil,
        horizontalAccuracy: Double? = nil,
        satelliteCount: Int? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
        self.heading = heading
        self.horizontalAccuracy = horizontalAccuracy
        self.satelliteCount = satelliteCount
    }

    // MARK: - CoreLocation Interop

    /*
     【CoreLocation 호환 - 좌표 변환】

     GPSPoint를 Apple의 CoreLocation 프레임워크 타입으로 변환합니다.

     CLLocationCoordinate2D:
     - MapKit에서 사용하는 기본 좌표 타입
     - 위도/경도만 포함 (고도, 속도 등 없음)
     - 가벼운 구조체 (16 bytes)

     사용 예시:
     ```swift
     let point = GPSPoint(timestamp: Date(), latitude: 37.5, longitude: 127.0)

     // 지도 중심 이동
     let coordinate = point.coordinate
     mapView.centerCoordinate = coordinate

     // 애노테이션 추가
     let annotation = MKPointAnnotation()
     annotation.coordinate = point.coordinate
     annotation.title = "사고 발생 지점"
     mapView.addAnnotation(annotation)

     // 폴리라인 (경로) 그리기
     let coordinates = gpsPoints.map { $0.coordinate }
     let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
     mapView.addOverlay(polyline)
     ```

     타입 정의:
     ```swift
     struct CLLocationCoordinate2D {
     var latitude: CLLocationDegrees  // Double의 typealias
     var longitude: CLLocationDegrees
     }
     ```
     */
    /// @brief MapKit용 CLLocationCoordinate2D 좌표로 변환
    /// @return CLLocationCoordinate2D 좌표 객체
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /*
     【CoreLocation 호환 - 완전한 위치 정보】

     GPSPoint를 CLLocation으로 변환합니다.

     CLLocation:
     - CoreLocation의 주요 위치 타입
     - 위도/경도뿐 아니라 고도, 속도, 정확도 등 모든 정보 포함
     - 거리 계산 메서드 제공 (distance(from:))

     변환 세부사항:
     1. altitude: nil이면 0으로 설정
     2. horizontalAccuracy: nil이면 -1 (유효하지 않음)
     3. verticalAccuracy: -1 (고도 정확도 정보 없음)
     4. course: heading 값 사용, nil이면 -1
     5. speed: km/h → m/s 변환 (÷ 3.6)

     사용 예시:
     ```swift
     let point = GPSPoint(...)
     let location = point.clLocation

     // 거리 계산
     let distance = location.distance(from: previousLocation)
     print("이동 거리: \(distance)m")

     // 위치 업데이트 시뮬레이션 (테스트용)
     locationManager.delegate?.locationManager?(
     locationManager,
     didUpdateLocations: [location]
     )

     // 지오코딩 (주소 변환)
     let geocoder = CLGeocoder()
     geocoder.reverseGeocodeLocation(location) { placemarks, error in
     if let placemark = placemarks?.first {
     print("주소: \(placemark.name ?? "")")
     print("도시: \(placemark.locality ?? "")")
     }
     }
     ```

     속도 단위 변환:
     - GPSPoint: km/h (시속)
     - CLLocation: m/s (초속)
     - 변환: m/s = km/h ÷ 3.6

     예시:
     - 90 km/h ÷ 3.6 = 25 m/s
     - 36 km/h ÷ 3.6 = 10 m/s
     */
    /// @brief 전체 위치 정보를 포함한 CLLocation 객체로 변환
    /// @return CLLocation 위치 객체
    var clLocation: CLLocation {
        return CLLocation(
            coordinate: coordinate,  // CLLocationCoordinate2D
            altitude: altitude ?? 0,  // 고도 정보 없으면 0 (해수면)
            horizontalAccuracy: horizontalAccuracy ?? -1,  // -1은 유효하지 않음
            verticalAccuracy: -1,  // 고도 정확도 정보 없음 (수직 정확도)
            course: heading ?? -1,  // 진행 방향, -1은 유효하지 않음
            speed: (speed ?? 0) / 3.6,  // km/h → m/s 변환
            timestamp: timestamp  // 측정 시각
        )
    }

    /*
     【CLLocation으로부터 생성】

     CoreLocation의 CLLocation 객체로부터 GPSPoint를 생성합니다.

     변환 세부사항:
     1. speed: m/s → km/h 변환 (× 3.6)
     2. course: -1이면 nil (유효하지 않음)
     3. horizontalAccuracy: -1이면 nil
     4. satelliteCount: CLLocation에는 이 정보 없음 → nil

     사용 사례:
     ```swift
     // 1. 실시간 위치 추적
     func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
     guard let location = locations.last else { return }

     let point = GPSPoint.from(location)
     self.gpsPoints.append(point)
     print("현재 위치: \(point.decimalString)")
     }

     // 2. 시뮬레이션 데이터 생성
     let simulatedLocation = CLLocation(
     latitude: 37.5665,
     longitude: 126.9780
     )
     let point = GPSPoint.from(simulatedLocation)

     // 3. 테스트 데이터 변환
     let testLocations = [CLLocation(...), CLLocation(...)]
     let gpsPoints = testLocations.map { GPSPoint.from($0) }
     ```

     course vs heading:
     - course: CLLocation의 용어
     - heading: GPSPoint의 용어
     - 같은 개념 (진행 방향 각도)

     매개변수:
     - location: CoreLocation의 CLLocation 객체

     반환값:
     - GPSPoint: 변환된 GPS 포인트
     */
    /// @brief CLLocation으로부터 GPSPoint 생성
    /// @param location CoreLocation의 CLLocation 객체
    /// @return GPSPoint 인스턴스
    static func from(_ location: CLLocation) -> GPSPoint {
        return GPSPoint(
            timestamp: location.timestamp,  // 측정 시각
            latitude: location.coordinate.latitude,  // 위도
            longitude: location.coordinate.longitude,  // 경도
            altitude: location.altitude,  // 고도 (항상 제공됨, 0일 수 있음)
            speed: location.speed * 3.6,  // m/s → km/h 변환
            heading: location.course >= 0 ? location.course : nil,  // -1이면 nil
            horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,  // -1이면 nil
            satelliteCount: nil  // CLLocation에는 위성 개수 정보 없음
        )
    }

    // MARK: - Validation

    /*
     【좌표 유효성 검증】

     위도/경도 값이 유효한 범위 내에 있는지 확인합니다.

     유효 범위:
     - 위도: -90° ~ +90°
     - 경도: -180° ~ +180°

     유효하지 않은 값 예시:
     - 위도 91°: 북극을 벗어남
     - 경도 -181°: 범위 초과
     - 위도 NaN: 계산 오류

     사용 예시:
     ```swift
     let points = try parser.parseGPSData(from: fileURL)

     // 유효한 포인트만 필터링
     let validPoints = points.filter { $0.isValid }
     print("전체: \(points.count), 유효: \(validPoints.count)")

     // 유효성 검사 후 처리
     for point in points {
     guard point.isValid else {
     print("⚠️ 유효하지 않은 GPS 데이터: \(point)")
     continue
     }

     // 지도에 표시
     addAnnotation(for: point)
     }

     // 유효하지 않은 데이터 로깅
     let invalidPoints = points.filter { !$0.isValid }
     if !invalidPoints.isEmpty {
     print("⚠️ \(invalidPoints.count)개의 유효하지 않은 GPS 포인트 발견")
     for point in invalidPoints {
     print("  - Lat: \(point.latitude), Lon: \(point.longitude)")
     }
     }
     ```

     왜 필요한가?
     - NMEA 파싱 오류로 잘못된 값 생성 가능
     - 손상된 GPS 파일
     - 초기화되지 않은 값 (0, 0)
     - 계산 오류 (NaN, Infinity)
     */
    /// @brief 좌표 유효성 검증
    /// @return 좌표가 유효 범위 내에 있으면 true
    var isValid: Bool {
        return latitude >= -90 && latitude <= 90 &&  // 위도 범위 확인
            longitude >= -180 && longitude <= 180  // 경도 범위 확인
    }

    /*
     【GPS 신호 강도 확인】

     위치 정확도와 위성 개수를 기반으로 GPS 신호가 강한지 판단합니다.

     판단 기준:
     1. horizontalAccuracy > 50m → 신호 약함
     2. satelliteCount < 4개 → 신호 약함
     3. 둘 다 통과 → 신호 강함

     정확도 임계값 (50m):
     - < 50m: 도로 수준 정확도 (신호 양호)
     - > 50m: 블록 수준 정확도 (신호 약함)

     위성 개수 임계값 (4개):
     - < 4개: 3D 위치 불가능
     - >= 4개: 3D 위치 가능 (위도, 경도, 고도)

     사용 예시:
     ```swift
     // 신호 강도 필터링
     let strongSignalPoints = allPoints.filter { $0.hasStrongSignal }
     print("강한 신호: \(strongSignalPoints.count) / \(allPoints.count)")

     // UI 표시
     for point in allPoints {
     let color: NSColor = point.hasStrongSignal ? .systemGreen : .systemRed
     let annotation = ColoredAnnotation(coordinate: point.coordinate, color: color)
     mapView.addAnnotation(annotation)
     }

     // 경고 메시지
     if !point.hasStrongSignal {
     statusLabel.stringValue = "⚠️ GPS 신호 약함"
     statusLabel.textColor = .systemOrange

     // 신호 약한 이유 표시
     var reasons: [String] = []
     if let acc = point.horizontalAccuracy, acc > 50 {
     reasons.append("정확도 낮음 (±\(Int(acc))m)")
     }
     if let sats = point.satelliteCount, sats < 4 {
     reasons.append("위성 부족 (\(sats)개)")
     }
     print("신호 약한 이유: \(reasons.joined(separator: ", "))")
     }

     // 터널 진입/이탈 감지
     if previousPoint.hasStrongSignal && !currentPoint.hasStrongSignal {
     print("터널 진입 감지")
     tunnelEntered = true
     } else if !previousPoint.hasStrongSignal && currentPoint.hasStrongSignal {
     print("터널 이탈 감지")
     tunnelEntered = false
     }
     ```

     nil 처리:
     - accuracy나 satelliteCount가 nil이면 해당 조건 무시
     - 하나라도 있으면 그 기준으로 판단
     - 둘 다 nil이면 true 반환 (보수적 접근)
     */
    /// @brief GPS 신호 강도 확인
    /// @return 정확도와 위성 개수 기반으로 신호가 강하면 true
    var hasStrongSignal: Bool {
        // 정확도 확인 (50m 이하여야 함)
        if let accuracy = horizontalAccuracy, accuracy > 50 {
            return false  // 정확도 낮음 → 신호 약함
        }
        // 위성 개수 확인 (4개 이상이어야 함)
        if let satellites = satelliteCount, satellites < 4 {
            return false  // 위성 부족 → 신호 약함
        }
        return true  // 모든 조건 통과 → 신호 강함
    }

    // MARK: - Calculations

    /*
     【거리 계산】

     다른 GPS 포인트까지의 직선 거리를 미터 단위로 계산합니다.

     계산 방법:
     - CoreLocation의 distance(from:) 메서드 사용
     - Haversine 공식 기반 (구면 거리)
     - 지구를 완전한 구로 가정

     Haversine 공식:
     ```
     a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
     c = 2 × atan2(√a, √(1−a))
     d = R × c
     ```
     where:
     - R = 지구 반경 (6,371km)
     - Δlat = lat2 - lat1
     - Δlon = lon2 - lon1

     정확도:
     - 단거리 (< 100km): 매우 정확
     - 장거리 (> 1000km): 약간의 오차 (지구가 완전한 구가 아님)
     - 오차: < 0.3% (충분히 실용적)

     사용 예시:
     ```swift
     let seoul = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     let busan = GPSPoint(latitude: 35.1796, longitude: 129.0756, ...)

     // 거리 계산
     let distance = seoul.distance(to: busan)
     print("서울-부산: \(Int(distance / 1000))km")  // 약 325km

     // 경로 총 거리 계산
     var totalDistance = 0.0
     for i in 0..<(gpsPoints.count - 1) {
     let current = gpsPoints[i]
     let next = gpsPoints[i + 1]
     totalDistance += current.distance(to: next)
     }
     print("총 이동 거리: \(Int(totalDistance / 1000))km")

     // 근처 포인트 찾기
     let nearbyPoints = allPoints.filter { point in
     point.distance(to: currentPoint) < 100  // 100m 이내
     }

     // 속도 검증
     let timeDiff = next.timestamp.timeIntervalSince(current.timestamp)
     let distance = current.distance(to: next)
     let calculatedSpeed = (distance / timeDiff) * 3.6  // m/s → km/h
     if let gpsSpeed = next.speed {
     let speedDiff = abs(calculatedSpeed - gpsSpeed)
     if speedDiff > 10 {
     print("⚠️ 속도 불일치: GPS=\(gpsSpeed), 계산=\(calculatedSpeed)")
     }
     }
     ```

     매개변수:
     - other: 목적지 GPS 포인트

     반환값:
     - Double: 거리 (미터 단위)
     */
    /// @brief 다른 GPS 포인트까지의 거리 계산
    /// @param other 목적지 GPS 포인트
    /// @return 거리 (미터)
    func distance(to other: GPSPoint) -> Double {
        let location1 = clLocation  // CLLocation으로 변환
        let location2 = other.clLocation  // CLLocation으로 변환
        return location1.distance(from: location2)  // CoreLocation의 거리 계산 메서드 사용
    }

    /*
     【방위각 계산】

     다른 GPS 포인트를 향한 방위각을 계산합니다.

     방위각 (Bearing):
     - 현재 위치에서 목적지를 바라보는 방향
     - 북쪽을 0°로 하여 시계방향으로 측정
     - 범위: 0° ~ 360°

     계산 공식:
     ```
     y = sin(Δlon) × cos(lat2)
     x = cos(lat1) × sin(lat2) - sin(lat1) × cos(lat2) × cos(Δlon)
     bearing = atan2(y, x)
     ```

     atan2 함수:
     - 역탄젠트 함수의 4사분면 버전
     - atan2(y, x) = 점 (x, y)의 각도
     - 범위: -π ~ +π (라디안)
     - 음수 값을 360° 더해서 0° ~ 360° 범위로 변환

     예시 (서울에서):
     - 부산: 약 115° (남동쪽)
     - 인천: 약 270° (서쪽)
     - 강릉: 약 85° (동쪽)

     사용 예시:
     ```swift
     let current = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     let destination = GPSPoint(latitude: 35.1796, longitude: 129.0756, ...)

     // 방위각 계산
     let bearing = current.bearing(to: destination)
     print("부산 방향: \(Int(bearing))° (남동)")

     // 방향 문자열 변환
     func directionString(from bearing: Double) -> String {
     switch bearing {
     case 0..<22.5, 337.5...360: return "북"
     case 22.5..<67.5: return "북동"
     case 67.5..<112.5: return "동"
     case 112.5..<157.5: return "남동"
     case 157.5..<202.5: return "남"
     case 202.5..<247.5: return "남서"
     case 247.5..<292.5: return "서"
     case 292.5..<337.5: return "북서"
     default: return "?"
     }
     }
     print("방향: \(directionString(from: bearing))")

     // UI 화살표 회전 (목적지 가리키기)
     let angle = bearing * .pi / 180  // 도 → 라디안
     arrowImageView.transform = CGAffineTransform(rotationAngle: angle)

     // 경로 편차 확인 (내비게이션)
     if let currentHeading = current.heading {
     let deviation = bearing - currentHeading
     if abs(deviation) > 15 {
     print("경로 이탈! 방향 수정 필요: \(Int(deviation))°")
     }
     }

     // 회전 방향 안내
     if let currentHeading = current.heading {
     let turnAngle = bearing - currentHeading
     if turnAngle > 10 {
     print("우회전 권장")
     } else if turnAngle < -10 {
     print("좌회전 권장")
     } else {
     print("직진")
     }
     }
     ```

     라디안 ↔ 도 변환:
     - 라디안 → 도: × 180 / π
     - 도 → 라디안: × π / 180

     truncatingRemainder(dividingBy:):
     - 나머지 연산자 (modulo)
     - (bearing + 360) % 360
     - 음수를 양수 범위(0~360)로 변환
     */
    /// @brief 다른 GPS 포인트를 향한 방위각 계산
    /// @param other 목적지 GPS 포인트
    /// @return 방위각 (0-360도)
    func bearing(to other: GPSPoint) -> Double {
        // 위도/경도를 라디안으로 변환
        let lat1 = latitude * .pi / 180  // 현재 위도 (라디안)
        let lon1 = longitude * .pi / 180  // 현재 경도 (라디안)
        let lat2 = other.latitude * .pi / 180  // 목적지 위도 (라디안)
        let lon2 = other.longitude * .pi / 180  // 목적지 경도 (라디안)

        let dLon = lon2 - lon1  // 경도 차이

        // 방위각 계산 (Haversine 공식)
        let y = sin(dLon) * cos(lat2)  // y 좌표
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)  // x 좌표

        let bearing = atan2(y, x) * 180 / .pi  // atan2로 각도 계산, 라디안 → 도 변환
        return (bearing + 360).truncatingRemainder(dividingBy: 360)  // -180~180 → 0~360 변환
    }

    // MARK: - Formatting

    /*
     【DMS 형식 문자열】

     위도/경도를 도·분·초(Degrees, Minutes, Seconds) 형식으로 변환합니다.

     DMS 형식:
     - 도(Degrees): 0° ~ 90° (위도), 0° ~ 180° (경도)
     - 분(Minutes): 0' ~ 59'
     - 초(Seconds): 0" ~ 59.9"

     변환 방법:
     ```
     십진법: 37.5665°

     1. 도 = 정수 부분 = 37°
     2. 분의 십진법 = (0.5665 × 60) = 33.99
     3. 분 = 정수 부분 = 33'
     4. 초 = (0.99 × 60) = 59.4"

     결과: 37°33'59.4"N
     ```

     방향 표시:
     - 북위 (N): latitude >= 0
     - 남위 (S): latitude < 0
     - 동경 (E): longitude >= 0
     - 서경 (W): longitude < 0

     사용 예시:
     ```swift
     let seoul = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     print(seoul.dmsString)
     // "37°33'59.4\"N, 126°58'40.8\"E"

     // UI 표시
     coordinateLabel.stringValue = point.dmsString

     // 지도 애노테이션 레이블
     annotation.subtitle = point.dmsString

     // 복사 가능한 형식
     let copyText = "위치: \(point.dmsString)"
     NSPasteboard.general.clearContents()
     NSPasteboard.general.setString(copyText, forType: .string)
     ```

     용도:
     - 사용자에게 친숙한 형식
     - 항해/항공에서 표준 표기법
     - Google Maps 등에서 사용

     십진법 vs DMS:
     - 십진법: 37.5665° (계산 편리)
     - DMS: 37°33'59.4\"N (읽기 편리)
     */
    /// @brief 위도/경도를 도·분·초(DMS) 형식으로 변환
    /// @return DMS 형식 문자열
    var dmsString: String {
        // 방향 결정
        let latDirection = latitude >= 0 ? "N" : "S"  // 북위/남위
        let lonDirection = longitude >= 0 ? "E" : "W"  // 동경/서경

        // 절대값으로 변환 (방향은 문자로 표시)
        let latDMS = Self.toDMS(abs(latitude))  // 위도를 DMS로 변환
        let lonDMS = Self.toDMS(abs(longitude))  // 경도를 DMS로 변환

        // "37°33'59.4"N, 126°58'40.8"E" 형식
        return "\(latDMS)\(latDirection), \(lonDMS)\(lonDirection)"
    }

    /*
     【십진법 문자열】

     위도/경도를 십진법(Decimal Degrees) 형식으로 변환합니다.

     십진법:
     - 위도/경도를 소수로 표현
     - 예: 37.566500, 126.978000

     정밀도:
     - 소수점 6자리: 약 0.1m (11cm) 정밀도
     - 소수점 5자리: 약 1m 정밀도
     - 소수점 4자리: 약 11m 정밀도

     사용 예시:
     ```swift
     let point = GPSPoint(latitude: 37.5665, longitude: 126.9780, ...)
     print(point.decimalString)
     // "37.566500, 126.978000"

     // Google Maps URL 생성
     let url = "https://maps.google.com/maps?q=\(point.decimalString)"
     NSWorkspace.shared.open(URL(string: url)!)

     // CSV 파일 출력
     let csvLine = "\(point.timestamp),\(point.decimalString),\(point.altitude ?? 0)"

     // 클립보드 복사
     NSPasteboard.general.setString(point.decimalString, forType: .string)
     ```

     형식:
     - "%6f": 소수점 6자리
     - 예: 37.566500 (소수점 6자리)
     */
    /// @brief 십진법 좌표 문자열로 변환
    /// @return 십진법 형식 문자열 (소수점 6자리)
    var decimalString: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    /*
     【속도 문자열】

     속도를 "45.0 km/h" 형식의 문자열로 변환합니다.

     반환값:
     - String?: 속도가 있으면 "XXX.X km/h", 없으면 nil

     형식:
     - "%.1f": 소수점 1자리
     - 예: "45.0 km/h", "120.5 km/h"

     사용 예시:
     ```swift
     let point = GPSPoint(..., speed: 45.0, ...)

     // 속도 표시
     if let speedStr = point.speedString {
     speedLabel.stringValue = speedStr
     } else {
     speedLabel.stringValue = "속도 정보 없음"
     }

     // nil 병합 연산자 사용
     speedLabel.stringValue = point.speedString ?? "N/A"

     // 여러 포인트의 속도 출력
     for point in gpsPoints {
     if let speedStr = point.speedString {
     print("\(point.timestamp): \(speedStr)")
     }
     }
     ```
     */
    /// @brief 속도를 단위 포함 문자열로 변환
    /// @return 속도 문자열 (예: "45.0 km/h"), 없으면 nil
    var speedString: String? {
        guard let speed = speed else { return nil }  // 속도 없으면 nil
        return String(format: "%.1f km/h", speed)  // "45.0 km/h" 형식
    }

    // MARK: - Private Helpers

    /*
     【십진법 → DMS 변환 (Private)】

     십진법 좌표를 도·분·초(DMS) 형식으로 변환합니다.

     매개변수:
     - decimal: 십진법 좌표 (예: 37.5665)

     반환값:
     - String: DMS 형식 문자열 (예: "37°33'59.4\"")

     계산 과정:
     ```
     입력: 37.5665

     1. 도 (Degrees):
     Int(37.5665) = 37

     2. 분의 십진법:
     (37.5665 - 37.0) × 60 = 0.5665 × 60 = 33.99

     3. 분 (Minutes):
     Int(33.99) = 33

     4. 초 (Seconds):
     (33.99 - 33.0) × 60 = 0.99 × 60 = 59.4

     출력: "37°33'59.4\""
     ```

     형식:
     - "%d°%d'%.1f\"": 도°분'초"
     - 예: "37°33'59.4\""

     왜 private인가?
     - 내부 구현 세부사항
     - 외부에서는 dmsString 속성 사용
     - 캡슐화: 구현 변경 가능
     */
    /// @brief 십진법 좌표를 DMS 형식으로 변환 (내부 헬퍼)
    /// @param decimal 십진법 좌표값
    /// @return DMS 형식 문자열
    private static func toDMS(_ decimal: Double) -> String {
        let degrees = Int(decimal)  // 도 (정수 부분)
        let minutesDecimal = (decimal - Double(degrees)) * 60  // 분의 십진법
        let minutes = Int(minutesDecimal)  // 분 (정수 부분)
        let seconds = (minutesDecimal - Double(minutes)) * 60  // 초 (나머지 × 60)

        return String(format: "%d°%d'%.1f\"", degrees, minutes, seconds)
    }
}

// MARK: - Identifiable

/*
 【Identifiable 프로토콜 확장】

 SwiftUI의 List, ForEach 등에서 사용할 수 있도록 고유 식별자를 제공합니다.

 Identifiable 프로토콜:
 - SwiftUI에서 리스트 항목의 고유성 보장
 - id 속성 필요 (Hashable 타입)
 - 여기서는 timestamp를 id로 사용

 왜 timestamp를 id로 사용하는가?
 - GPS 포인트는 시간 순서대로 기록됨
 - 같은 시간에 두 개의 측정값 없음
 - Date는 Hashable (고유 식별 가능)

 사용 예시:
 ```swift
 // SwiftUI List
 List(gpsPoints) { point in
 HStack {
 Text(point.decimalString)
 Spacer()
 if let speed = point.speedString {
 Text(speed)
 }
 }
 }
 // id 지정 불필요 (Identifiable 프로토콜로 자동 처리)

 // ForEach
 ForEach(gpsPoints) { point in
 MapAnnotation(coordinate: point.coordinate) {
 Image(systemName: "mappin")
 }
 }

 // 수동 id 지정 (Identifiable 없을 때)
 // List(gpsPoints, id: \.timestamp) { point in ... }
 ```

 Identifiable vs id 매개변수:
 ```swift
 // Identifiable 사용 (권장)
 struct GPSPoint: Identifiable {
 var id: Date { timestamp }
 }
 List(points) { point in ... }

 // id 매개변수 사용
 List(points, id: \.timestamp) { point in ... }
 ```
 */
extension GPSPoint: Identifiable {
    var id: Date { timestamp }  // timestamp를 고유 식별자로 사용
}

// MARK: - Sample Data

/*
 【샘플 데이터 확장】

 테스트와 SwiftUI 프리뷰를 위한 샘플 GPS 데이터를 제공합니다.

 사용 목적:
 1. 단위 테스트 (Unit Tests)
 2. SwiftUI 프리뷰 (Canvas)
 3. 개발 중 빠른 테스트
 4. 문서화 예시

 샘플 위치: 서울시청
 - 위도: 37.5665°N
 - 경도: 126.9780°E
 - 서울 중심부, 인지도 높은 위치
 */
extension GPSPoint {
    /*
     【단일 샘플 GPS 포인트】

     서울시청 위치의 샘플 GPS 포인트입니다.

     데이터:
     - 위치: 서울시청 (37.5665°N, 126.9780°E)
     - 고도: 15m (해수면 기준)
     - 속도: 45 km/h
     - 방향: 90° (동쪽)
     - 정확도: ±5m (매우 정확)
     - 위성: 8개 (양호한 신호)

     사용 예시:
     ```swift
     // 단위 테스트
     func testDistanceCalculation() {
     let point1 = GPSPoint.sample
     let point2 = GPSPoint(
     timestamp: Date(),
     latitude: 37.5667,
     longitude: 126.9782
     )
     let distance = point1.distance(to: point2)
     XCTAssertEqual(distance, 25, accuracy: 5)  // 약 25m ±5m
     }

     // SwiftUI 프리뷰
     struct MapView_Previews: PreviewProvider {
     static var previews: some View {
     MapView(location: GPSPoint.sample)
     }
     }

     // 개발 테스트
     let testPoint = GPSPoint.sample
     print("샘플 위치: \(testPoint.dmsString)")
     mapView.centerCoordinate = testPoint.coordinate
     ```
     */
    /// Sample GPS point for testing (Seoul City Hall)
    static let sample = GPSPoint(
        timestamp: Date(),  // 현재 시각
        latitude: 37.5665,  // 서울시청 위도
        longitude: 126.9780,  // 서울시청 경도
        altitude: 15.0,  // 고도 15m
        speed: 45.0,  // 속도 45 km/h
        heading: 90.0,  // 방향 동쪽
        horizontalAccuracy: 5.0,  // 정확도 ±5m
        satelliteCount: 8  // 위성 8개
    )

    /*
     【샘플 경로 (배열)】

     서울시청 주변을 이동하는 5개의 GPS 포인트로 구성된 경로입니다.

     경로 특징:
     - 북동쪽으로 이동
     - 1초 간격
     - 속도 증가 (30 → 50 km/h)
     - 방향 약간 변경 (45° → 50°)
     - 고도 약간 증가 (15m → 17m)

     거리:
     - 각 구간: 약 25-30m
     - 총 거리: 약 100-120m

     사용 예시:
     ```swift
     // 경로 테스트
     func testRouteDistance() {
     var totalDistance = 0.0
     for i in 0..<(GPSPoint.sampleRoute.count - 1) {
     let current = GPSPoint.sampleRoute[i]
     let next = GPSPoint.sampleRoute[i + 1]
     totalDistance += current.distance(to: next)
     }
     XCTAssertGreaterThan(totalDistance, 100)
     }

     // 지도에 경로 그리기
     let coordinates = GPSPoint.sampleRoute.map { $0.coordinate }
     let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
     mapView.addOverlay(polyline)

     // SwiftUI List 프리뷰
     struct GPSListView_Previews: PreviewProvider {
     static var previews: some View {
     List(GPSPoint.sampleRoute) { point in
     HStack {
     Text(point.decimalString)
     Spacer()
     Text(point.speedString ?? "N/A")
     }
     }
     }
     }

     // 애니메이션 시뮬레이션
     for (index, point) in GPSPoint.sampleRoute.enumerated() {
     DispatchQueue.main.asyncAfter(deadline: .now() + Double(index)) {
     mapView.centerCoordinate = point.coordinate
     }
     }
     ```

     좌표 변화:
     - Point 0: 37.5665, 126.9780
     - Point 1: 37.5667, 126.9782 (+0.0002, +0.0002)
     - Point 2: 37.5669, 126.9784 (+0.0002, +0.0002)
     - Point 3: 37.5671, 126.9786 (+0.0002, +0.0002)
     - Point 4: 37.5673, 126.9788 (+0.0002, +0.0002)

     속도 변화:
     - Point 0: 30 km/h
     - Point 1: 35 km/h (+5)
     - Point 2: 40 km/h (+5)
     - Point 3: 45 km/h (+5)
     - Point 4: 50 km/h (+5)
     */
    /// Array of sample GPS points forming a route
    static let sampleRoute: [GPSPoint] = [
        GPSPoint(timestamp: Date(), latitude: 37.5665, longitude: 126.9780, altitude: 15, speed: 30, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(1), latitude: 37.5667, longitude: 126.9782, altitude: 15, speed: 35, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(2), latitude: 37.5669, longitude: 126.9784, altitude: 16, speed: 40, heading: 45),
        GPSPoint(timestamp: Date().addingTimeInterval(3), latitude: 37.5671, longitude: 126.9786, altitude: 16, speed: 45, heading: 50),
        GPSPoint(timestamp: Date().addingTimeInterval(4), latitude: 37.5673, longitude: 126.9788, altitude: 17, speed: 50, heading: 50)
    ]
}
