import SwiftUI
struct VinylView: View {
    let color: String; var spin: Bool = false
    @State private var angle: Double = 0
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "#0D0D0D"))
            ForEach([0.90,0.78,0.67,0.56,0.46], id: \.self) { s in
                Circle().stroke(Color.white.opacity(0.05), lineWidth: 0.8).scaleEffect(s)
            }
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).scaleEffect(0.97)
            Circle().fill(Color(hex: color).opacity(0.90)).scaleEffect(0.28)
            ForEach([30.0,90.0,150.0], id: \.self) { d in
                Capsule().fill(Color.black.opacity(0.20))
                    .frame(width: 1.5, height: 18).offset(y: -4)
                    .rotationEffect(.degrees(d)).scaleEffect(0.28)
            }
            Circle().fill(Color.black).scaleEffect(0.055)
        }
        .rotationEffect(.degrees(angle))
        .onAppear {
            guard spin else { return }
            withAnimation(.linear(duration: 3.6).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
