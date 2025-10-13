/// @file CompassView.swift
/// @brief 나침반 방향 표시 뷰
/// @author BlackboxPlayer Development Team
/// @details
/// 차량의 진행 방향을 나침반 스타일로 표시하는 SwiftUI 뷰입니다.
/// GPS heading 데이터를 사용하여 시각적으로 방향을 표현합니다.

import SwiftUI

/// @struct CompassView
/// @brief 나침반 방향 표시
///
/// @details
/// ## 기능
/// - 원형 나침반 디자인
/// - 8방위 표시 (N, NE, E, SE, S, SW, W, NW)
/// - 회전 애니메이션
/// - 현재 방향 강조
///
/// ## 방향 표시
/// ```
/// 0° (360°) → N (북)
/// 45°       → NE (북동)
/// 90°       → E (동)
/// 135°      → SE (남동)
/// 180°      → S (남)
/// 225°      → SW (남서)
/// 270°      → W (서)
/// 315°      → NW (북서)
/// ```
///
/// ## 사용 예제
/// ```swift
/// CompassView(heading: 90.0)
///     .frame(width: 80, height: 80)
/// ```
struct CompassView: View {
    // MARK: - Properties

    /// @var heading
    /// @brief 현재 방향 (0° ~ 360°)
    ///
    /// @details
    /// 0°/360° = 북쪽
    /// 90° = 동쪽
    /// 180° = 남쪽
    /// 270° = 서쪽
    let heading: Double

    // MARK: - Constants

    /// @brief 8방위 표시
    ///
    /// @details
    /// (각도, 레이블) 튜플 배열
    /// 각도: 나침반 상의 위치
    /// 레이블: 표시할 방향 문자
    private let directions: [(angle: Double, label: String)] = [
        (0, "N"),      // 북
        (45, "NE"),    // 북동
        (90, "E"),     // 동
        (135, "SE"),   // 남동
        (180, "S"),    // 남
        (225, "SW"),   // 남서
        (270, "W"),    // 서
        (315, "NW")    // 북서
    ]

    // MARK: - Computed Properties

    /// @brief 방향 문자열
    ///
    /// @details
    /// 현재 heading에 가장 가까운 8방위 레이블 반환
    private var directionText: String {
        // 22.5도씩 8개 구간으로 나눔
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index].label
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 나침반 외곽 원
            compassRing

            // 8방위 표시
            directionMarkers

            // 중앙 방향 텍스트
            centerText

            // 북쪽 표시 (삼각형)
            northIndicator
        }
        .rotationEffect(.degrees(-heading))  // 나침반 회전
        .animation(.easeInOut(duration: 0.3), value: heading)  // 부드러운 애니메이션
    }

    // MARK: - Compass Ring

    /// @brief 나침반 외곽 원
    ///
    /// @details
    /// 반투명 흰색 원으로 나침반 테두리 표현
    private var compassRing: some View {
        Circle()
            .stroke(Color.white.opacity(0.3), lineWidth: 2)
    }

    // MARK: - Direction Markers

    /// @brief 8방위 표시
    ///
    /// @details
    /// ForEach로 8개의 방위 레이블을 배치
    private var directionMarkers: some View {
        ForEach(directions, id: \.angle) { direction in
            Text(direction.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(
                    direction.angle == 0 ? .red : .white.opacity(0.6)
                    // 북쪽(N)만 빨간색으로 강조
                )
                .offset(y: -32)  // 원 위쪽으로 이동
                .rotationEffect(.degrees(direction.angle))  // 각 방위 위치로 회전
                .rotationEffect(.degrees(heading))  // heading 회전 보정 (항상 똑바로 보이게)
        }
    }

    // MARK: - Center Text

    /// @brief 중앙 방향 텍스트
    ///
    /// @details
    /// 현재 방향 레이블과 각도를 중앙에 표시
    private var centerText: some View {
        VStack(spacing: 2) {
            Text(directionText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(String(format: "%.0f°", heading))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - North Indicator

    /// @brief 북쪽 표시 (삼각형)
    ///
    /// @details
    /// 나침반 위쪽에 북쪽을 가리키는 빨간 삼각형 표시
    private var northIndicator: some View {
        Triangle()
            .fill(Color.red.opacity(0.8))
            .frame(width: 8, height: 12)
            .offset(y: -38)  // 원 바깥쪽으로 이동
            .rotationEffect(.degrees(heading))  // heading 회전 보정
    }
}

// MARK: - Triangle Shape

/// @struct Triangle
/// @brief 삼각형 Shape
///
/// @details
/// 북쪽 표시용 삼각형 경로
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 삼각형 꼭지점 (위쪽 중앙)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))

        // 왼쪽 아래
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        // 오른쪽 아래
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // 닫기 (다시 꼭지점으로)
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // 북쪽
            CompassView(heading: 0)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("North (0°)")

            // 동쪽
            CompassView(heading: 90)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("East (90°)")

            // 남쪽
            CompassView(heading: 180)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("South (180°)")

            // 서쪽
            CompassView(heading: 270)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("West (270°)")

            // 북동쪽
            CompassView(heading: 45)
                .frame(width: 80, height: 80)
                .background(Color.black)
                .previewDisplayName("Northeast (45°)")
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
