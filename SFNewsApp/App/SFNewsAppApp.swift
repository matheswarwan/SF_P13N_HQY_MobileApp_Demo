import SwiftUI

@main
struct SFNewsAppApp: App {

    // Bridge to UIKit AppDelegate — ensures SFMCSdk.initializeSdk() fires
    // before any SwiftUI view body is evaluated.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Auth state — root of the auth EnvironmentObject tree
    @StateObject private var authViewModel = AuthViewModel()

    // Home state — only active once the user is logged in
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                HomeView()
                    .environmentObject(homeViewModel)
                    .environmentObject(authViewModel)
                    // Re-fetch personalized content whenever the logged-in user changes
                    .task(id: authViewModel.currentUser?.id) {
                        await homeViewModel.loadContent()
                    }
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
