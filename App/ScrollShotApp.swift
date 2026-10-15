import SwiftUI
@main
struct ScrollShotApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup { HomeView().environmentObject(model).tint(Color(red: 0.05,green: 0.48,blue: 0.78)) }
    }
}
