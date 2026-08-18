import SwiftUI

@main
struct DrivingTrainerWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchHomeView() }
    }
}

private struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "steeringwheel")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("驾考训练").font(.headline)
            Text("等待 iPhone 开始训练")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
