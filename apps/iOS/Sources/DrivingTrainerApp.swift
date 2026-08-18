import SwiftUI

@main
struct DrivingTrainerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(model)
                .task { await model.load() }
        }
    }
}
