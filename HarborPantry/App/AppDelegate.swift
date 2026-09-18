import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

final class AppDelegate: UIResponder, UIApplicationDelegate {

    private var hull: [AnyHashable: Any] = [:]
    private var deck: [AnyHashable: Any] = [:]
    private var timer: Task<Void, Never>?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        let sdk = AppsFlyerLib.shared()
        sdk.appsFlyerDevKey = Almanac.relayKey
        sdk.appleAppID = Almanac.appCode
        sdk.delegate = self
        sdk.deepLinkDelegate = self
        sdk.isDebug = false

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        if let cold = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            sift(cold)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(surfaced), name: UIApplication.didBecomeActiveNotification, object: nil)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc private func surfaced() {
        guard #available(iOS 14, *) else { return AppsFlyerLib.shared().start() }
        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                AppsFlyerLib.shared().start()
                UserDefaults.standard.set(status.rawValue, forKey: Slips.att)
            }
        }
    }

    private func moor() {
        timer?.cancel()
        timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard Task.isCancelled == false else { return }
            await MainActor.run { self?.splice() }
        }
    }

    private func splice() {
        timer?.cancel()
        timer = nil
        var load = hull
        for (key, value) in deck {
            let tag = "\(key)".starts(with: "deep") ? "\(key)" : "deep_\(key)"
            if load[tag] == nil { load[tag] = value }
        }
        NotificationCenter.default.post(name: .landfall, object: nil, userInfo: ["conversionData": load])
    }

    private func sift(_ payload: [AnyHashable: Any]) {
        var found: String?
        if let direct = payload["url"] as? String, direct.isEmpty == false {
            found = direct
        } else if let data = payload["data"] as? [AnyHashable: Any], let url = data["url"] as? String, url.isEmpty == false {
            found = url
        } else if let aps = payload["aps"] as? [AnyHashable: Any],
                  let data = aps["data"] as? [AnyHashable: Any],
                  let url = data["url"] as? String, url.isEmpty == false {
            found = url
        } else if let custom = payload["custom"] as? [AnyHashable: Any], let url = custom["url"] as? String, url.isEmpty == false {
            found = url
        }
        guard let link = found else { return }

        UserDefaults.standard.set(link, forKey: Slips.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NotificationCenter.default.post(name: .flare, object: nil, userInfo: ["temp_url": link])
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: Slips.fcm)
            UserDefaults.standard.set(token, forKey: Slips.push)
            UserDefaults(suiteName: Almanac.suite)?.set(token, forKey: Slips.sharedFcm)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        sift(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        sift(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        sift(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        hull = conversionInfo
        moor()
        if deck.isEmpty == false { splice() }
    }

    func onConversionDataFail(_ error: Error) {
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let deepLink = result.deepLink else { return }
        guard UserDefaults.standard.bool(forKey: Slips.primed) == false else { return }
        deck = deepLink.clickEvent
        NotificationCenter.default.post(name: .charted, object: nil, userInfo: ["deeplinksData": deepLink.clickEvent])
        timer?.cancel()
        timer = nil
        if hull.isEmpty == false { splice() }
    }
}
