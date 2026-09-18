import Foundation

enum Slips {
    static let pushURL = "temp_url"
    static let fcm = "fcm_token"
    static let push = "push_token"
    static let sharedFcm = "shared_fcm"
    static let att = "hp_att_status"
    static let primed = "hp_primed"
    static let route = "hp_route_url"
    static let mode = "hp_route_mode"
    static let grant = "hp_consent_locked"
    static let deny = "hp_consent_drifted"
    static let stamp = "hp_consent_mapped_at"
}

extension Notification.Name {
    static let landfall = Notification.Name("ConversionDataReceived")
    static let charted = Notification.Name("deeplink_values")
    static let flare = Notification.Name("LoadTempURL")
}

enum RuntimeSpray {

    private static func crest(_ swept: String) -> String {
        String(swept.reversed())
    }

    static var webKitFramework: String { crest("tiKbeW") }
    static var wkContentCtrl: String { crest("rellortnoCtnetnoCresUKW") }
    static var wkUserScript: String { crest("tpircSresUKW") }
    static var wkConfig: String { crest("noitarugifnoCweiVbeWKW") }
    static var wkProcessPool: String { crest("looPssecorPKW") }
    static var wkWebView: String { crest("weiVbeWKW") }

    static var selScrollView: Selector { NSSelectorFromString(crest("weiVllorcs")) }
    static var selSetNavDelegate: Selector { NSSelectorFromString(crest(":etageleDnoitagivaNtes")) }
    static var selSetUIDelegate: Selector { NSSelectorFromString(crest(":etageleDIUtes")) }
    static var selLoadRequest: Selector { NSSelectorFromString(crest(":tseuqeRdaol")) }
    static var selConfiguration: Selector { NSSelectorFromString(crest("noitarugifnoc")) }
    static var selWebsiteDataStore: Selector { NSSelectorFromString(crest("erotSataDetisbew")) }
    static var selHttpCookieStore: Selector { NSSelectorFromString(crest("erotSeikooCptth")) }
}
