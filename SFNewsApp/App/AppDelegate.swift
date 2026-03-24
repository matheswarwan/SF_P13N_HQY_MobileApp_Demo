import UIKit
import SFMCSDK
import Cdp
import Personalization

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        initializeSDK()
        return true
    }

    // MARK: - SDK Initialization

    private func initializeSDK() {
        #if DEBUG
        SFMCSdk.setLogger(logLevel: .debug, logOutputter: LogOutputter())
        #endif

        // Build the Personalization module config.
        // dataspace defaults to "default" if your org uses the default data space.
        let personalizationConfig = PersonalizationConfigBuilder()
            .build()

        // Build the CDP (Data Cloud) module config.
        let cdpConfig = CdpConfigBuilder(
            appId: SDKConfig.dataCloudAppId,
            endpoint: SDKConfig.dataCloudEndpoint
        )
        .trackScreens(true)
        .trackLifecycle(true)
        .sessionTimeout(600)
        .build()

        SFMCSdk.initializeSdk(
            ConfigBuilder()
                .setCdp(config: cdpConfig)
                .setPersonalization(config: personalizationConfig)
                .build()
        ) { moduleStatuses in
            for status in moduleStatuses {
                print("[SFNewsApp] Module '\(status.moduleName)' init status: \(status.initStatus)")
                if status.initStatus == .success {
                    Task { @MainActor in
                        PersonalizationService.shared.markSDKReady()
                    }
                }
            }

            // Set implicit consent opt-in so events flow to Data Cloud.
            if SDKConfig.consentOptIn {
                SFMCSdk.cdp.setConsent(consent: .optIn)
                print("[SFNewsApp] CDP consent set to optIn")
            }
        }
    }
}
