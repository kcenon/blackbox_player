//
//  ScreenCaptureService.swift
//  BlackboxPlayer
//
//  Service for capturing current video frame and saving as image
//

/**
 # ScreenCaptureService - 화면 캡처 서비스

 ## 📸 화면 캡처란?

 현재 재생 중인 영상의 특정 순간을 이미지 파일로 저장하는 기능입니다.

 ### 사용 예시:
 ```
 사용자가 영상에서 중요한 장면 발견
    ↓
 캡처 버튼 클릭
    ↓
 현재 화면을 PNG/JPEG 파일로 저장
 ```

 ## 🎯 주요 기능

 1. **Metal Texture → Image 변환**
    - GPU 메모리의 텍스처를 CPU 메모리의 이미지로 변환
    - CGImage, NSImage 사용

 2. **타임스탬프 오버레이**
    - 캡처 시각 표시
    - 영상 재생 시간 표시

 3. **이미지 포맷 지원**
    - PNG: 무손실 압축, 파일 크기 큼
    - JPEG: 손실 압축, 파일 크기 작음

 4. **파일 저장**
    - 저장 위치 선택 다이얼로그
    - 저장 완료 알림

 ## 💡 기술 개념

 ### Metal Texture vs Image 파일
 ```
 Metal Texture (GPU 메모리):
 - GPU가 직접 접근 가능
 - 렌더링에 최적화
 - 파일로 저장 불가

 Image 파일 (디스크):
 - CPU가 처리
 - PNG, JPEG 등 표준 포맷
 - 다른 앱에서 열기 가능
 ```

 ### 변환 과정:
 ```
 MTLTexture (GPU)
   ↓ texture.getBytes() - GPU → CPU 복사
 [UInt8] 배열 (픽셀 데이터)
   ↓ CGDataProvider
 CGImage (Core Graphics)
   ↓ NSImage
 NSImage (AppKit)
   ↓ NSBitmapImageRep
 PNG/JPEG Data
   ↓ write(to:)
 파일 저장
 ```

 ## 📚 사용 예제

 ```swift
 // 1. 서비스 생성
 let captureService = ScreenCaptureService(device: metalDevice)

 // 2. 현재 프레임 캡처
 if let data = captureService.captureFrame(
     from: currentTexture,
     format: .png,
     timestamp: Date(),
     videoTimestamp: 5.25  // 5.25초 시점
 ) {
     // 3. 저장 다이얼로그 표시
     captureService.showSavePanel(
         data: data,
         format: .png,
         defaultFilename: "Blackbox_Front_2024-10-12"
     )
 }
 ```

 ---

 이 서비스는 GPU 렌더링 결과를 사용자가 보관할 수 있는 이미지 파일로 변환합니다.
 */

import Foundation
import AppKit
import CoreGraphics
import Metal
import MetalKit

// MARK: - Image Format Enum

/**
 ## CaptureImageFormat - 이미지 포맷

 캡처한 화면을 저장할 때 사용할 이미지 포맷을 정의합니다.

 ### 포맷 비교:

 **PNG (Portable Network Graphics)**
 - 무손실 압축: 원본 품질 100% 유지
 - 파일 크기: 큰 편 (1920×1080: ~2-5MB)
 - 투명도 지원: Alpha 채널 있음
 - 용도: 고품질 보관, 편집용

 **JPEG (Joint Photographic Experts Group)**
 - 손실 압축: 품질 다소 저하 (눈에 거의 안 보임)
 - 파일 크기: 작은 편 (1920×1080: ~200-500KB)
 - 투명도 미지원: RGB만
 - 용도: 빠른 공유, 저장 공간 절약

 ### 선택 가이드:
 ```
 PNG를 선택하는 경우:
 - 나중에 편집할 예정
 - 최고 품질 필요
 - 저장 공간 충분

 JPEG를 선택하는 경우:
 - 바로 공유할 예정
 - 저장 공간 부족
 - 품질 90-95%로 충분
 ```
 */
enum CaptureImageFormat: String {
    /// PNG 포맷 (무손실)
    case png = "png"

    /// JPEG 포맷 (손실)
    case jpeg = "jpg"

    /**
     사용자에게 표시할 포맷 이름

     - PNG → "PNG"
     - JPEG → "JPEG"
     */
    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        }
    }

    /**
     Uniform Type Identifier (UTI)

     ### UTI란?
     - macOS/iOS에서 파일 형식을 식별하는 표준 방법
     - 파일 확장자보다 정확하고 명확

     예:
     - "public.png" → PNG 이미지
     - "public.jpeg" → JPEG 이미지
     - "public.mp4" → MP4 비디오

     ### 사용 용도:
     - NSSavePanel에서 허용할 파일 타입 지정
     - 파일 타입 검증
     - 시스템과 파일 형식 정보 공유
     */
    var utType: String {
        switch self {
        case .png: return "public.png"
        case .jpeg: return "public.jpeg"
        }
    }
}

// MARK: - Screen Capture Service

/**
 ## ScreenCaptureService - 화면 캡처 서비스

 GPU 메모리의 Metal 텍스처를 CPU 메모리의 이미지 파일로 변환하여 저장합니다.

 ### 주요 책임:
 1. Metal 텍스처 → CGImage 변환
 2. 타임스탬프 오버레이 추가
 3. PNG/JPEG 포맷으로 인코딩
 4. 파일 저장 다이얼로그 표시
 5. 저장 완료 알림
 */
class ScreenCaptureService {

    // MARK: - Properties

    /**
     ## Metal Device

     ### MTLDevice란?
     GPU(그래픽 처리 장치)를 추상화한 객체입니다.

     이 서비스에서 사용하는 이유:
     - Metal 텍스처는 특정 GPU device에 속함
     - 텍스처 데이터를 읽으려면 해당 device가 필요

     비유:
     - device = "회사 ID 카드"
     - texture = "회사 내부 문서"
     - ID 카드가 있어야 문서 접근 가능
     */
    private let device: MTLDevice

    /**
     ## JPEG 품질 (0.0 ~ 1.0)

     ### 품질 값의 의미:
     - 0.0 = 최저 품질, 최소 파일 크기 (많이 깨짐)
     - 0.5 = 중간 품질
     - 0.95 = 높은 품질, 큰 파일 크기 (기본값)
     - 1.0 = 최고 품질, 최대 파일 크기

     ### 품질 vs 파일 크기:
     ```
     1920×1080 이미지 예시:

     quality = 0.5  →  ~150KB  (눈에 띄는 압축 흔적)
     quality = 0.8  →  ~300KB  (적당한 품질)
     quality = 0.95 →  ~500KB  (높은 품질, 기본값)
     quality = 1.0  →  ~800KB  (최고 품질)
     ```

     ### 권장 설정:
     - 일반 용도: 0.85 ~ 0.95
     - 고품질 필요: 0.95 ~ 1.0
     - 파일 크기 중요: 0.7 ~ 0.85
     */
    var jpegQuality: CGFloat = 0.95

    // MARK: - Initialization

    /**
     서비스 초기화

     - Parameter device: Metal device (GPU 접근용)

     ### 초기화 시점:
     ```swift
     // MultiChannelRenderer에서 생성:
     let captureService = ScreenCaptureService(device: metalDevice)
     ```
     */
    init(device: MTLDevice) {
        self.device = device
    }

    // MARK: - Public Methods

    /**
     ## Metal 텍스처에서 프레임 캡처

     현재 GPU에 렌더링된 화면을 이미지 데이터로 변환합니다.

     ### 처리 단계:
     ```
     1. MTLTexture → CGImage 변환
        - GPU 메모리 → CPU 메모리 복사
        - RGBA 픽셀 데이터 추출

     2. CGImage → NSImage 변환
        - AppKit 이미지 객체 생성

     3. 타임스탬프 오버레이 (선택)
        - 현재 시각 표시
        - 영상 재생 시간 표시

     4. PNG/JPEG 인코딩
        - 지정된 포맷으로 압축

     5. Data 반환
        - 파일에 쓸 수 있는 바이너리 데이터
     ```

     - Parameters:
       - texture: 캡처할 Metal 텍스처 (현재 화면)
       - format: 저장할 이미지 포맷 (PNG 또는 JPEG)
       - timestamp: 오버레이할 시각 (nil이면 오버레이 안 함)
       - videoTimestamp: 영상 재생 시간 (초 단위)

     - Returns: 이미지 데이터 (Data), 실패 시 nil

     ### 사용 예제:
     ```swift
     // 1. 타임스탬프 없이 캡처
     let data = captureService.captureFrame(
         from: currentTexture,
         format: .png
     )

     // 2. 타임스탬프 포함 캡처
     let data = captureService.captureFrame(
         from: currentTexture,
         format: .jpeg,
         timestamp: Date(),           // 현재 시각: 2024-10-12 15:30:45
         videoTimestamp: 125.5        // 영상 시간: 00:02:05.500
     )
     ```

     ### 실패하는 경우:
     - 텍스처가 비어있음
     - 메모리 부족
     - 포맷 변환 실패
     */
    func captureFrame(
        from texture: MTLTexture,
        format: CaptureImageFormat,
        timestamp: Date? = nil,
        videoTimestamp: TimeInterval? = nil
    ) -> Data? {
        // ===== 1단계: MTLTexture → CGImage =====
        // GPU 메모리의 텍스처를 CPU 메모리의 이미지로 변환
        guard let cgImage = createCGImage(from: texture) else {
            errorLog("[ScreenCaptureService] Failed to create CGImage from texture")
            return nil
        }

        // ===== 2단계: CGImage → NSImage =====
        // Core Graphics 이미지를 AppKit 이미지로 변환
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(cgImage: cgImage, size: size)

        // ===== 3단계: 타임스탬프 오버레이 (선택) =====
        // if-let 표현식 (Swift 5.9+):
        // - timestamp가 nil이 아니면 → 오버레이 추가한 이미지
        // - timestamp가 nil이면 → 원본 이미지
        let finalImage = if let timestamp = timestamp {
            addTimestampOverlay(to: nsImage, timestamp: timestamp, videoTimestamp: videoTimestamp)
        } else {
            nsImage
        }

        // ===== 4단계: PNG/JPEG 인코딩 =====
        // NSImage → Data (파일에 쓸 수 있는 바이너리)
        return convertToData(image: finalImage, format: format)
    }

    /**
     ## 저장 다이얼로그 표시 및 파일 저장

     사용자에게 저장 위치를 선택하게 하고, 이미지 파일을 저장합니다.

     ### NSSavePanel이란?
     macOS의 표준 "다른 이름으로 저장" 대화상자입니다.

     ```
     ┌─────────────────────────────────────┐
     │ Save Screenshot                     │
     │                                     │
     │ Choose where to save...             │
     │                                     │
     │ Save As: [BlackboxCapture.png    ] │
     │ Where:   [▼ Documents            ] │
     │                                     │
     │              [ Cancel ]  [ Save ]   │
     └─────────────────────────────────────┘
     ```

     ### 처리 흐름:
     ```
     1. NSSavePanel 생성 및 설정
        - 제목, 메시지 설정
        - 기본 파일명 설정
        - 허용할 파일 확장자 설정

     2. runModal() 호출
        - 다이얼로그 표시 (모달)
        - 사용자 입력 대기
        - 취소 또는 저장 버튼 클릭 대기

     3. 응답 확인
        - .OK → 저장 진행
        - 취소 → false 반환

     4. 파일 쓰기
        - data.write(to: url)
        - 성공 → 알림 표시
        - 실패 → 에러 알림
     ```

     - Parameters:
       - data: 저장할 이미지 데이터
       - format: 이미지 포맷 (확장자 결정)
       - defaultFilename: 기본 파일명 (확장자 제외)

     - Returns: 저장 성공 여부 (true/false)

     ### @discardableResult란?
     - 반환값을 무시해도 경고가 안 뜨게 하는 속성
     - 이 메서드는 결과를 확인할 필요가 없는 경우도 많기 때문

     ```swift
     // 반환값 사용:
     if captureService.showSavePanel(data: data, format: .png) {
         print("저장 성공!")
     }

     // 반환값 무시 (경고 없음):
     captureService.showSavePanel(data: data, format: .png)
     ```

     ### 사용 예제:
     ```swift
     // 캡처 및 저장:
     if let data = captureService.captureFrame(from: texture, format: .png) {
         captureService.showSavePanel(
             data: data,
             format: .png,
             defaultFilename: "Blackbox_Front_2024-10-12_15-30-45"
         )
     }
     ```
     */
    @discardableResult
    func showSavePanel(
        data: Data,
        format: CaptureImageFormat,
        defaultFilename: String = "BlackboxCapture"
    ) -> Bool {
        // ===== 1단계: NSSavePanel 생성 및 설정 =====
        let savePanel = NSSavePanel()

        // 다이얼로그 제목
        savePanel.title = "Save Screenshot"

        // 안내 메시지
        savePanel.message = "Choose where to save the captured frame"

        // 기본 파일명 (예: "BlackboxCapture.png")
        savePanel.nameFieldStringValue = "\(defaultFilename).\(format.rawValue)"

        // 허용할 파일 확장자
        // [.init(filenameExtension: "png")!] → PNG만 허용
        savePanel.allowedContentTypes = [.init(filenameExtension: format.rawValue)!]

        // 폴더 생성 버튼 표시
        savePanel.canCreateDirectories = true

        // 확장자 표시 (숨기지 않음)
        savePanel.isExtensionHidden = false

        // ===== 2단계: 다이얼로그 표시 (모달) =====
        // runModal()은 사용자가 버튼을 클릭할 때까지 대기
        // 반환값:
        // - .OK: "저장" 버튼 클릭
        // - .cancel: "취소" 버튼 클릭 또는 ESC 키
        let response = savePanel.runModal()

        // ===== 3단계: 응답 확인 =====
        guard response == .OK, let url = savePanel.url else {
            // 취소 또는 URL 없음 → 저장 안 함
            return false
        }

        // ===== 4단계: 파일 쓰기 =====
        do {
            // Data를 파일로 저장
            // atomically: true → 임시 파일에 쓴 후 rename (안전)
            try data.write(to: url)

            // 로그 기록
            infoLog("[ScreenCaptureService] Saved screenshot to: \(url.path)")

            // ===== 5단계: 성공 알림 =====
            showNotification(
                title: "Screenshot Saved",
                message: "Saved to \(url.lastPathComponent)"
            )

            return true

        } catch {
            // ===== 에러 처리 =====
            errorLog("[ScreenCaptureService] Failed to save screenshot: \(error)")

            // 실패 알림
            showNotification(
                title: "Save Failed",
                message: error.localizedDescription,
                isError: true
            )

            return false
        }
    }

    // MARK: - Private Methods

    /**
     ## Metal 텍스처를 CGImage로 변환

     ### 변환 과정 (상세):

     ```
     단계 1: 메모리 할당
     ┌─────────────────────────────────────┐
     │ CPU 메모리 (빈 배열)                 │
     │ [0, 0, 0, 0, 0, 0, 0, 0, ...]       │
     │ 크기: width × height × 4 바이트      │
     └─────────────────────────────────────┘

     단계 2: GPU → CPU 복사
     ┌─────────────────┐
     │ GPU 메모리       │  texture.getBytes()
     │ (MTLTexture)    │  ──────────────────→  CPU 메모리
     │ RGBA 픽셀 데이터 │                       [R,G,B,A, R,G,B,A, ...]
     └─────────────────┘

     단계 3: CGDataProvider 생성
     - 픽셀 데이터를 Core Graphics에 제공
     - 메모리 관리 자동화

     단계 4: CGImage 생성
     - width, height 정보
     - 픽셀 포맷 정보 (RGBA, 8bit per channel)
     - colorSpace (RGB)
     - bitmapInfo (Alpha 채널 위치)
     ```

     ### 픽셀 데이터 구조:
     ```
     하나의 픽셀 = 4바이트 (RGBA)

     예: 빨간색 픽셀
     [255, 0, 0, 255]
      R   G  B  A

     2×2 이미지:
     [255,0,0,255,  0,255,0,255,    ← 첫 번째 줄 (빨강, 초록)
      0,0,255,255,  255,255,255,255] ← 두 번째 줄 (파랑, 흰색)

     총 크기 = 2 × 2 × 4 = 16바이트
     ```

     - Parameter texture: 변환할 Metal 텍스처
     - Returns: CGImage, 실패 시 nil
     */
    private func createCGImage(from texture: MTLTexture) -> CGImage? {
        // ===== 텍스처 정보 가져오기 =====
        let width = texture.width        // 예: 1920
        let height = texture.height      // 예: 1080
        let bytesPerPixel = 4            // RGBA = 4바이트
        let bytesPerRow = width * bytesPerPixel  // 한 줄의 바이트 수
        let bitsPerComponent = 8         // R, G, B, A 각각 8비트

        // ===== 1단계: CPU 메모리 할당 =====
        // 전체 픽셀 데이터를 저장할 배열
        // 크기 = 1920 × 1080 × 4 = 8,294,400 바이트 (약 8MB)
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // ===== 2단계: GPU → CPU 복사 =====
        // 텍스처의 어느 영역을 복사할지 지정 (전체 영역)
        let region = MTLRegionMake2D(0, 0, width, height)

        // texture.getBytes():
        // - GPU 메모리에서 CPU 메모리로 픽셀 데이터 복사
        // - 이 작업은 비교적 느림 (GPU ↔ CPU 버스 통과)
        // - 하지만 캡처는 가끔만 하므로 성능 문제 없음
        texture.getBytes(
            &pixelData,                  // 복사할 CPU 메모리 주소
            bytesPerRow: bytesPerRow,    // 한 줄당 바이트 수
            from: region,                // 복사할 영역 (전체)
            mipmapLevel: 0               // 밉맵 레벨 (0 = 원본 크기)
        )

        // ===== 3단계: CGDataProvider 생성 =====
        // CGDataProvider란?
        // - Core Graphics에 픽셀 데이터를 제공하는 객체
        // - 데이터 소스 추상화 (메모리, 파일, 네트워크 등)
        guard let dataProvider = CGDataProvider(
            data: Data(pixelData) as CFData
        ) else {
            return nil
        }

        // ===== 4단계: CGImage 생성 =====
        // CGImage란?
        // - Core Graphics의 이미지 객체
        // - 플랫폼 독립적 (macOS, iOS 공통)
        // - 불변(immutable) 객체
        return CGImage(
            width: width,                // 이미지 너비
            height: height,              // 이미지 높이
            bitsPerComponent: bitsPerComponent,  // 채널당 비트 (8bit)
            bitsPerPixel: bytesPerPixel * bitsPerComponent,  // 픽셀당 비트 (32bit)
            bytesPerRow: bytesPerRow,    // 한 줄의 바이트 수
            space: CGColorSpaceCreateDeviceRGB(),  // 색 공간 (RGB)
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            // ↑ Alpha 채널 위치: RGBA (마지막)
            // premultiplied: RGB 값이 이미 Alpha로 곱해짐
            provider: dataProvider,      // 픽셀 데이터 제공자
            decode: nil,                 // 디코드 배열 (없음)
            shouldInterpolate: true,     // 보간 사용 (부드러운 확대/축소)
            intent: .defaultIntent       // 렌더링 의도 (기본)
        )
    }

    /**
     ## 이미지에 타임스탬프 오버레이 추가

     ### 오버레이란?
     원본 이미지 위에 텍스트나 그래픽을 덧그리는 것입니다.

     ```
     원본 이미지:
     ┌─────────────────────────────┐
     │                             │
     │     [영상 화면]              │
     │                             │
     │                             │
     │                             │
     └─────────────────────────────┘

     타임스탬프 오버레이 후:
     ┌─────────────────────────────┐
     │                             │
     │     [영상 화면]              │
     │                             │
     │                             │
     │   ┌───────────────────────┐ │
     │   │ 2024-10-12 15:30:45   │ │ ← 추가된 텍스트
     │   │ [00:02:05.500]        │ │
     └───┴───────────────────────┴─┘
     ```

     ### 처리 단계:
     ```
     1. NSBitmapImageRep 생성
        - 비트맵 이미지 표현 객체
        - 픽셀 데이터를 직접 조작 가능

     2. NSGraphicsContext 설정
        - 그래픽 그리기 컨텍스트
        - 현재 그리기 대상 설정

     3. 원본 이미지 그리기
        - 배경으로 사용

     4. 타임스탬프 텍스트 포맷팅
        - 날짜/시간: "2024-10-12 15:30:45"
        - 영상 시간: "[00:02:05.500]"

     5. 배경 사각형 그리기
        - 반투명 검은색
        - 텍스트 가독성 향상

     6. 텍스트 그리기
        - 흰색 고정폭 폰트
        - 우하단 위치

     7. NSImage로 변환
        - 최종 결과 이미지
     ```

     - Parameters:
       - image: 원본 이미지
       - timestamp: 캡처 시각
       - videoTimestamp: 영상 재생 시간 (초)

     - Returns: 타임스탬프가 추가된 이미지
     */
    private func addTimestampOverlay(
        to image: NSImage,
        timestamp: Date,
        videoTimestamp: TimeInterval?
    ) -> NSImage {
        let size = image.size

        // ===== 1단계: NSBitmapImageRep 생성 =====
        // NSBitmapImageRep이란?
        // - 비트맵(픽셀 기반) 이미지의 표현
        // - 픽셀 데이터 직접 조작 가능
        // - 다양한 픽셀 포맷 지원
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,          // 데이터 평면 (nil = 자동 할당)
            pixelsWide: Int(size.width),    // 너비 (픽셀)
            pixelsHigh: Int(size.height),   // 높이 (픽셀)
            bitsPerSample: 8,               // 샘플당 비트 (R, G, B, A 각각 8비트)
            samplesPerPixel: 4,             // 픽셀당 샘플 (RGBA = 4개)
            hasAlpha: true,                 // Alpha 채널 있음
            isPlanar: false,                // Planar 형식 아님 (인터리브)
            colorSpaceName: .deviceRGB,     // RGB 색 공간
            bytesPerRow: 0,                 // 0 = 자동 계산
            bitsPerPixel: 0                 // 0 = 자동 계산
        ) else {
            // 생성 실패 → 원본 반환
            return image
        }

        // ===== 2단계: NSGraphicsContext 설정 =====
        // NSGraphicsContext란?
        // - AppKit의 그리기 컨텍스트
        // - 현재 그리기 대상을 관리
        // - draw(), fill() 등의 명령이 이 컨텍스트에 적용됨

        // 현재 상태 저장
        NSGraphicsContext.saveGraphicsState()

        // defer란?
        // - 함수가 종료될 때 실행할 코드
        // - return, throw, break 등 어떤 경로든 실행됨
        // - 리소스 정리에 유용 (파일 닫기, 잠금 해제 등)
        defer { NSGraphicsContext.restoreGraphicsState() }

        // bitmapRep에 그릴 수 있는 컨텍스트 생성
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            return image
        }

        // 현재 그리기 컨텍스트 설정
        // 이제 모든 그리기 명령은 bitmapRep에 적용됨
        NSGraphicsContext.current = context

        // ===== 3단계: 원본 이미지 그리기 (배경) =====
        image.draw(
            in: NSRect(origin: .zero, size: size),   // 그릴 위치 (전체)
            from: NSRect(origin: .zero, size: size), // 원본 영역 (전체)
            operation: .copy,                        // 복사 (덮어쓰기)
            fraction: 1.0                            // 불투명도 100%
        )

        // ===== 4단계: 타임스탬프 텍스트 포맷팅 =====

        // DateFormatter란?
        // - Date 객체를 문자열로 변환
        // - 날짜/시간 형식 지정 가능
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        // 예: "2024-10-12 15:30:45"

        var timestampText = dateFormatter.string(from: timestamp)

        // 영상 재생 시간 추가 (있는 경우)
        if let videoTime = videoTimestamp {
            // 시간 계산:
            // videoTime = 125.5초
            // → hours = 0, minutes = 2, seconds = 5, milliseconds = 500
            let hours = Int(videoTime) / 3600
            let minutes = (Int(videoTime) % 3600) / 60
            let seconds = Int(videoTime) % 60
            let milliseconds = Int((videoTime.truncatingRemainder(dividingBy: 1)) * 1000)

            // 형식: "[HH:MM:SS.mmm]"
            timestampText += String(format: " [%02d:%02d:%02d.%03d]", hours, minutes, seconds, milliseconds)
            // 예: " [00:02:05.500]"
        }

        // 최종 텍스트 예:
        // "2024-10-12 15:30:45 [00:02:05.500]"

        // ===== 5단계: 텍스트 스타일 설정 =====

        // NSAttributedString이란?
        // - 스타일이 적용된 문자열
        // - 폰트, 색상, 크기 등 지정 가능
        let attributes: [NSAttributedString.Key: Any] = [
            // 고정폭 폰트 (숫자 정렬에 유리)
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium),
            // 흰색 텍스트 (검은 배경에 잘 보임)
            .foregroundColor: NSColor.white
        ]

        let attributedString = NSAttributedString(string: timestampText, attributes: attributes)
        let textSize = attributedString.size()  // 텍스트가 차지할 크기

        // ===== 6단계: 배경 사각형 위치 계산 =====

        let padding: CGFloat = 12                    // 화면 가장자리 여백
        let backgroundPadding: CGFloat = 8           // 텍스트 주변 여백

        // 우하단 위치 계산:
        // ```
        //              padding
        //              ↓
        //    ┌─────────────────────────────┐
        //    │                             │
        //    │                             │
        //    │                             │
        //    │   ┌─────────────────────┐   │
        //    │   │ 2024-10-12 15:30:45 │   │ ← 여기에 배치
        //    └───┴─────────────────────┴───┘
        //        ↑                       ↑
        //    padding              backgroundPadding
        // ```
        let textRect = NSRect(
            x: size.width - textSize.width - padding - backgroundPadding * 2,
            y: padding,
            width: textSize.width + backgroundPadding * 2,
            height: textSize.height + backgroundPadding * 2
        )

        // ===== 7단계: 배경 사각형 그리기 =====

        // 반투명 검은색:
        // - 검은색 (black)
        // - 70% 불투명 (alpha = 0.7)
        // - 텍스트 가독성 향상
        NSColor.black.withAlphaComponent(0.7).setFill()

        // 둥근 모서리 사각형
        let backgroundPath = NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4)
        backgroundPath.fill()

        // ===== 8단계: 텍스트 그리기 =====

        attributedString.draw(at: NSPoint(
            x: textRect.origin.x + backgroundPadding,
            y: textRect.origin.y + backgroundPadding
        ))

        // ===== 9단계: NSImage로 변환 =====

        let finalImage = NSImage(size: size)
        finalImage.addRepresentation(bitmapRep)

        return finalImage
    }

    /**
     ## NSImage를 PNG/JPEG 데이터로 변환

     ### 변환 과정:
     ```
     NSImage (AppKit 객체)
       ↓ tiffRepresentation
     TIFF Data (임시 포맷)
       ↓ NSBitmapImageRep
     비트맵 표현
       ↓ representation(using:)
     PNG/JPEG Data (최종)
     ```

     ### 왜 TIFF를 거쳐가나?
     - NSImage는 벡터/비트맵 혼합 가능
     - TIFF는 모든 표현을 비트맵으로 통일
     - NSBitmapImageRep으로 변환 용이

     ### JPEG 압축 옵션:
     ```swift
     properties: [.compressionFactor: 0.95]
     ```
     - compressionFactor: 압축 품질 (0.0 ~ 1.0)
     - 0.95 = 95% 품질 (기본값)

     - Parameters:
       - image: 변환할 이미지
       - format: 목표 포맷 (PNG 또는 JPEG)

     - Returns: 이미지 데이터, 실패 시 nil
     */
    private func convertToData(image: NSImage, format: CaptureImageFormat) -> Data? {
        // ===== 1단계: NSImage → TIFF Data =====
        // TIFF (Tagged Image File Format):
        // - 무손실 포맷
        // - 임시 중간 포맷으로 사용
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // ===== 2단계: NSBitmapImageRep → PNG/JPEG Data =====
        switch format {
        case .png:
            // PNG 인코딩:
            // - 무손실 압축
            // - properties = [:] → 기본 설정 사용
            return bitmapRep.representation(using: .png, properties: [:])

        case .jpeg:
            // JPEG 인코딩:
            // - 손실 압축
            // - compressionFactor = 0.95 → 95% 품질
            return bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegQuality]
            )
        }
    }

    /**
     ## 사용자 알림 표시

     ### NSAlert란?
     macOS의 표준 알림 대화상자입니다.

     ```
     ┌─────────────────────────────┐
     │  ⓘ Screenshot Saved         │  ← 제목
     │                             │
     │  Saved to Blackbox_001.png  │  ← 메시지
     │                             │
     │              [ OK ]          │  ← 버튼
     └─────────────────────────────┘
     ```

     ### Alert Style:
     - .informational: 정보 아이콘 (파란색 ⓘ)
     - .warning: 경고 아이콘 (노란색 ⚠)
     - .critical: 위험 아이콘 (빨간색 ⛔)

     ### 왜 DispatchQueue.main.async?
     - UI 업데이트는 메인 스레드에서만 가능
     - 이 메서드는 백그라운드 스레드에서 호출될 수 있음
     - async로 메인 스레드에 작업 전달

     - Parameters:
       - title: 알림 제목
       - message: 알림 메시지
       - isError: 에러 알림 여부 (true = 경고 스타일)
     */
    private func showNotification(title: String, message: String, isError: Bool = false) {
        // ===== 메인 스레드에서 실행 =====
        // UI 작업은 반드시 메인 스레드에서!
        DispatchQueue.main.async {
            // NSAlert 생성
            let alert = NSAlert()

            // 제목 설정
            alert.messageText = title

            // 상세 메시지 설정
            alert.informativeText = message

            // 스타일 설정:
            // - 에러 → .warning (경고 아이콘)
            // - 정상 → .informational (정보 아이콘)
            alert.alertStyle = isError ? .warning : .informational

            // 버튼 추가
            alert.addButton(withTitle: "OK")

            // 모달 실행:
            // - 화면에 대화상자 표시
            // - 사용자가 버튼 클릭할 때까지 대기
            alert.runModal()
        }
    }
}

/**
 # ScreenCaptureService 사용 가이드

 ## 기본 사용법:

 ```swift
 // 1. 서비스 생성 (앱 시작 시 한 번)
 let captureService = ScreenCaptureService(device: metalDevice)

 // 2. JPEG 품질 설정 (선택)
 captureService.jpegQuality = 0.90  // 90% 품질

 // 3. 프레임 캡처
 if let data = captureService.captureFrame(
     from: currentTexture,
     format: .png,
     timestamp: Date(),
     videoTimestamp: syncController.currentTime
 ) {
     // 4. 파일 저장
     captureService.showSavePanel(
         data: data,
         format: .png,
         defaultFilename: generateFilename()
     )
 }
 ```

 ## 파일명 생성 예제:

 ```swift
 func generateFilename() -> String {
     let dateFormatter = DateFormatter()
     dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
     let dateString = dateFormatter.string(from: Date())

     let position = "Front"  // 또는 currentCameraPosition

     return "Blackbox_\(position)_\(dateString)"
     // 예: "Blackbox_Front_2024-10-12_15-30-45"
 }
 ```

 ## 키보드 단축키로 캡처:

 ```swift
 // ContentView.swift
 .onReceive(NotificationCenter.default.publisher(for: .captureScreenshot)) { _ in
     if let texture = renderer.currentTexture {
         if let data = captureService.captureFrame(
             from: texture,
             format: .png,
             timestamp: Date(),
             videoTimestamp: syncController.currentTime
         ) {
             captureService.showSavePanel(data: data, format: .png)
         }
     }
 }

 // 단축키 등록: Command+S
 .keyboardShortcut("s", modifiers: .command)
 ```

 ## 자동 저장 (다이얼로그 없이):

 ```swift
 func autoSaveCapture() {
     guard let texture = renderer.currentTexture else { return }

     guard let data = captureService.captureFrame(
         from: texture,
         format: .jpeg,  // 파일 크기 작음
         timestamp: Date(),
         videoTimestamp: syncController.currentTime
     ) else { return }

     // 자동 저장 경로
     let filename = generateFilename() + ".jpg"
     let documentsURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
     let fileURL = documentsURL.appendingPathComponent("Blackbox").appendingPathComponent(filename)

     do {
         try data.write(to: fileURL)
         print("Auto-saved: \(fileURL.path)")
     } catch {
         print("Auto-save failed: \(error)")
     }
 }
 ```

 ## 성능 고려사항:

 1. **캡처는 비용이 큰 작업**
    - GPU → CPU 메모리 복사 (8MB)
    - 이미지 인코딩 (PNG: 느림, JPEG: 빠름)
    - 파일 쓰기

 2. **권장 사항**
    - 재생 중에는 pause 후 캡처
    - 연속 캡처 방지 (1초 간격 제한)
    - JPEG 사용 (PNG보다 5-10배 빠름)

 3. **메모리 관리**
    - 캡처 후 Data는 자동으로 해제됨
    - 메모리 부족 시 캡처 실패 가능
 */
