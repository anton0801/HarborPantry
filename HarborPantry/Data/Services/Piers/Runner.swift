import Foundation
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging

final class Runner: Caller {

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 30
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    func send(_ body: [String: String]) async -> Verdict {
        let request = await forge(body)
        let gaps = Almanac.gaps
        for (idx, gap) in gaps.enumerated() {
            do {
                return .open(try await once(request))
            } catch let squall as Squall {
                if squall.sealed { return .shut }
                if case .throttle(let cool) = squall {
                    try? await Task.sleep(nanoseconds: UInt64(cool * 1_000_000_000))
                    continue
                }
                if idx < gaps.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
                }
            } catch {
                if idx < gaps.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
                }
            }
        }
        return .shut
    }

    private func once(_ request: URLRequest) async throws -> String {
        let (data, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw Squall.pipe }
        if http.statusCode == 404 { throw Squall.gone404 }
        if http.statusCode == 429 {
            throw Squall.throttle(TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60)
        }
        guard (200..<300).contains(http.statusCode) else { throw Squall.pipe }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Squall.garble }
        guard let ok = json["ok"] as? Bool else { throw Squall.garble }
        guard ok else { throw Squall.shut }
        guard let url = json["url"] as? String, url.isEmpty == false else { throw Squall.garble }
        return url
    }

    @MainActor
    private func forge(_ body: [String: String]) -> URLRequest {
        var payload: [String: Any] = body
        payload["os"] = "iOS"
        payload["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        payload["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        payload["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        payload["store_id"] = Almanac.store
        payload["push_token"] = UserDefaults.standard.string(forKey: Slips.push) ?? Messaging.messaging().fcmToken
        payload["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"

        var request = URLRequest(url: URL(string: Almanac.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        return request
    }
}
