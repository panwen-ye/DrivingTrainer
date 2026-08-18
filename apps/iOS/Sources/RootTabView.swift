import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            NavigationStack { TrainingHomeView() }
                .tabItem { Label("训练", systemImage: "steeringwheel") }

            NavigationStack { RoutesView() }
                .tabItem { Label("路线", systemImage: "map") }

            NavigationStack { RecordsView() }
                .tabItem { Label("记录", systemImage: "clock.arrow.circlepath") }
        }
        .alert("提示", isPresented: errorIsPresented) {
            Button("知道了") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
