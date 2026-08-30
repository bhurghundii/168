import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "timer") }
            SetupView()
                .tabItem { Label("Setup", systemImage: "slider.horizontal.3") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar") }
        }
        .tint(Color("AccentBurn"))
    }
}
