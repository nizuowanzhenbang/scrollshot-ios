import SwiftUI
@main
struct ScrollShotApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("appearance") private var appearance=0
    var body: some Scene {
        WindowGroup { HomeView().environmentObject(model).tint(Color(red: 0.05,green: 0.48,blue: 0.78)).preferredColorScheme(appearance==0 ? nil:(appearance==1 ? .light:.dark)) }
    }
}
