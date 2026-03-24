import SwiftUI

@main
struct SFNewsAppApp: App {

    // Bridge to UIKit AppDelegate — ensures SFMCSdk.initializeSdk() fires
    // before any SwiftUI view body is evaluated.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Single shared ViewModel injected into the environment for all child views.
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(homeViewModel)
        }
    }
}
