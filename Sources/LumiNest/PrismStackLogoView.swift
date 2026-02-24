import SwiftUI

struct PrismStackLogoView: View {
    var size: CGFloat = 160

    var body: some View {
        let scale = size / 160

        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.11, green: 0.23, blue: 0.23).opacity(0.18))
                .frame(width: 88 * scale, height: 108 * scale)
                .offset(x: -14 * scale, y: -2 * scale)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.09, green: 0.64, blue: 0.60).opacity(0.85))
                .frame(width: 88 * scale, height: 108 * scale)
                .offset(x: -4 * scale, y: -10 * scale)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 1.0, green: 0.52, blue: 0.32))
                .frame(width: 88 * scale, height: 108 * scale)
                .offset(x: 8 * scale, y: 0)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.13, green: 0.16, blue: 0.19))
                .frame(width: 26 * scale, height: 108 * scale)
                .offset(x: 35 * scale, y: 0)

            VStack(spacing: 8 * scale) {
                ForEach(0..<6, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 3.8 * scale, height: 3.8 * scale)
                }
            }
            .offset(x: 35 * scale, y: 0)

            Path { path in
                path.move(to: CGPoint(x: 84 * scale, y: 116 * scale))
                path.addLine(to: CGPoint(x: 100 * scale, y: 96 * scale))
                path.addLine(to: CGPoint(x: 112 * scale, y: 109 * scale))
                path.addLine(to: CGPoint(x: 126 * scale, y: 92 * scale))
                path.addLine(to: CGPoint(x: 140 * scale, y: 116 * scale))
            }
            .stroke(Color(red: 1.0, green: 0.91, blue: 0.85), lineWidth: 5 * scale)
            .offset(x: -26 * scale, y: -30 * scale)
        }
        .frame(width: size, height: size)
    }
}
