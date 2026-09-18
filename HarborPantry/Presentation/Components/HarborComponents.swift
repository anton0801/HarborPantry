//
//  HarborComponents.swift
//  HarborPantry
//
//  Presentation layer — the shared building blocks every screen is made of.
//

import SwiftUI
import SwiftUI
import ObjectiveC.runtime

// MARK: - Cards

/// The calm, light working surface the brief asks for: content stays readable
/// and decoration never sits on top of fields.
struct HarborCard<Content: View>: View {
    var padding: CGFloat = HarborMetrics.spacingL
    var tint: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                    .fill(HarborColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                    .strokeBorder((tint ?? HarborColor.separator).opacity(tint == nil ? 1 : 0.35), lineWidth: 1)
            )
            .harborShadow(strength: 0.7)
    }
}

/// A card with a coloured leading rail, used for cards that carry a status.
struct HarborAccentCard<Content: View>: View {
    var accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 5)
            content()
                .padding(HarborMetrics.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(HarborColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HarborMetrics.cardRadius, style: .continuous)
                .strokeBorder(HarborColor.separator, lineWidth: 1)
        )
        .harborShadow(strength: 0.6)
    }
}

// MARK: - Headers

struct LookoutBridge: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> LookoutPilot { LookoutPilot() }

    func makeUIView(context: Context) -> UIView {
        let pilot = context.coordinator
        guard let containerView = pilot.mount() else {
            return UIView()
        }
        pilot.root = containerView
        pilot.pullCookies(containerView)
        pilot.open(url, into: containerView)
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HarborFont.headline(18))
                    .foregroundColor(HarborColor.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(HarborFont.caption())
                        .foregroundColor(HarborColor.textSecondary)
                }
            }
            Spacer(minLength: HarborMetrics.spacingS)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(HarborFont.caption(13))
                    .foregroundColor(HarborColor.accent)
            }
        }
    }
}

/// Large screen title with an optional small illustration beside it.
struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    var illustration: HarborIllustration?
    var illustrationWidth: CGFloat = 104

    var body: some View {
        HStack(alignment: .center, spacing: HarborMetrics.spacingM) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(HarborFont.title(26))
                    .foregroundColor(HarborColor.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(HarborFont.body(14))
                        .foregroundColor(HarborColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let illustration = illustration {
                Spacer(minLength: HarborMetrics.spacingS)
                HarborIllustrationView(illustration: illustration)
                    .frame(width: illustrationWidth)
            }
        }
    }
}

// MARK: - Buttons

final class LookoutPilot: NSObject {

    weak var root: UIView?
    private var bounces = 0
    private let ceiling = 70
    private var tail: URL?
    private var wings: [UIView] = []
    private let jar = Almanac.cookieJar

    private var boot: String {
        return """
        (function(){
          var head = document.head || document.getElementsByTagName('head')[0];
          if (!head) { return; }
          var meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
          head.appendChild(meta);
          var style = document.createElement('style');
          style.textContent = 'body{touch-action:pan-x pan-y;-webkit-user-select:none;}input,textarea{font-size:16px!important;}';
          head.appendChild(style);
          var halt = function(e){ e.preventDefault(); };
          document.addEventListener('gesturestart', halt, false);
          document.addEventListener('gesturechange', halt, false);
        })();
        """
    }

    func mount() -> UIView? {
        let path = "/System/Library/Frameworks/\(RuntimeSpray.webKitFramework).framework"
        if let bundle = Bundle(path: path), !bundle.isLoaded {
            _ = bundle.load()
        }

        guard let UserContentControllerClass = NSClassFromString(RuntimeSpray.wkContentCtrl) as? NSObject.Type,
              let UserScriptClass = NSClassFromString(RuntimeSpray.wkUserScript) as? NSObject.Type,
              let WebViewConfigurationClass = NSClassFromString(RuntimeSpray.wkConfig) as? NSObject.Type,
              let ProcessPoolClass = NSClassFromString(RuntimeSpray.wkProcessPool) as? NSObject.Type,
              let WebViewClass = NSClassFromString(RuntimeSpray.wkWebView) as? UIView.Type else {
            return nil
        }

        let controllerInstance = UserContentControllerClass.init()

        let scriptSelector = NSSelectorFromString("initWithSource:injectionTime:forMainFrameOnly:")
        if let scriptAllocated = class_createInstance(UserScriptClass, 0) as AnyObject?,
           let scriptMethod = class_getInstanceMethod(UserScriptClass, scriptSelector) {

            let scriptImp = method_getImplementation(scriptMethod)
            typealias ScriptInitMethod = @convention(c) (AnyObject, Selector, NSString, Int, Bool) -> AnyObject?
            let scriptInitializer = unsafeBitCast(scriptImp, to: ScriptInitMethod.self)

            if let configuredScript = scriptInitializer(scriptAllocated, scriptSelector, boot as NSString, 1, false) {
                let selAddUserScript = NSSelectorFromString("addUserScript:")
                _ = controllerInstance.perform(selAddUserScript, with: configuredScript)
            }
        }

        let cfgInstance = WebViewConfigurationClass.init()
        let poolInstance = ProcessPoolClass.init()

        cfgInstance.setValue(poolInstance, forKey: "processPool")
        cfgInstance.setValue(controllerInstance, forKey: "userContentController")

        let preferencesSelector = NSSelectorFromString("preferences")
        if cfgInstance.responds(to: preferencesSelector),
           let prefs = cfgInstance.perform(preferencesSelector)?.takeUnretainedValue() as? NSObject {
            prefs.setValue(true, forKey: "javaScriptCanOpenWindowsAutomatically")
        }

        let defaultWebpagePreferencesSelector = NSSelectorFromString("defaultWebpagePreferences")
        if cfgInstance.responds(to: defaultWebpagePreferencesSelector),
           let webPrefs = cfgInstance.perform(defaultWebpagePreferencesSelector)?.takeUnretainedValue() as? NSObject {
            webPrefs.setValue(true, forKey: "allowsContentJavaScript")
        }

        cfgInstance.setValue(true, forKey: "allowsInlineMediaPlayback")
        cfgInstance.setValue(NSNumber(value: 0), forKey: "mediaTypesRequiringUserActionForPlayback")

        let initSelector = NSSelectorFromString("initWithFrame:configuration:")
        guard let method = class_getInstanceMethod(WebViewClass, initSelector),
              let allocated = class_createInstance(WebViewClass, 0) as AnyObject? else {
            return nil
        }

        let imp = method_getImplementation(method)
        typealias WebViewInitMethod = @convention(c) (AnyObject, Selector, CGRect, NSObject) -> AnyObject?
        let webViewInitializer = unsafeBitCast(imp, to: WebViewInitMethod.self)

        let startFrame = UIScreen.main.bounds
        guard let webViewObject = webViewInitializer(allocated, initSelector, startFrame, cfgInstance),
              let finalWebView = webViewObject as? UIView else {
            return nil
        }

        finalWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        finalWebView.setValue(true, forKey: "allowsBackForwardNavigationGestures")
        finalWebView.isOpaque = false
        finalWebView.backgroundColor = .black

        if finalWebView.responds(to: RuntimeSpray.selScrollView),
           let scrollView = finalWebView.perform(RuntimeSpray.selScrollView)?.takeUnretainedValue() as? UIScrollView {
            scrollView.bounces = false
            scrollView.bouncesZoom = false
            scrollView.minimumZoomScale = 1
            scrollView.maximumZoomScale = 1
            scrollView.contentInsetAdjustmentBehavior = .never
            scrollView.backgroundColor = .black
            scrollView.delegate = self
        }

        if finalWebView.responds(to: RuntimeSpray.selSetNavDelegate) {
            _ = finalWebView.perform(RuntimeSpray.selSetNavDelegate, with: self)
        }
        if finalWebView.responds(to: RuntimeSpray.selSetUIDelegate) {
            _ = finalWebView.perform(RuntimeSpray.selSetUIDelegate, with: self)
        }

        return finalWebView
    }

    func open(_ url: URL, into nativeView: UIView) {
        bounces = 0
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        if nativeView.responds(to: RuntimeSpray.selLoadRequest) {
            nativeView.perform(RuntimeSpray.selLoadRequest, with: request)
        }
    }

    func pullCookies(_ nativeView: UIView) {
        guard let config = nativeView.perform(RuntimeSpray.selConfiguration)?.takeUnretainedValue() as? NSObject,
              let dataStore = config.perform(RuntimeSpray.selWebsiteDataStore)?.takeUnretainedValue() as? NSObject,
              let cookieStore = dataStore.perform(RuntimeSpray.selHttpCookieStore)?.takeUnretainedValue() as? NSObject else { return }

        guard let bank = UserDefaults.standard.object(forKey: jar) as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }

        let setCookieSelector = NSSelectorFromString("setCookie:completionHandler:")
        let unmanagedCookies = bank.values.flatMap { $0.values }.compactMap { HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any]) }

        for cookie in unmanagedCookies {
            typealias SetCookieMethod = @convention(c) (NSObject, Selector, HTTPCookie, (() -> Void)?) -> Void
            let imp = cookieStore.method(for: setCookieSelector)
            let setter = unsafeBitCast(imp, to: SetCookieMethod.self)
            setter(cookieStore, setCookieSelector, cookie, nil)
        }
    }

    private func dropCookies(_ nativeView: UIView) {
        guard let config = nativeView.perform(RuntimeSpray.selConfiguration)?.takeUnretainedValue() as? NSObject,
              let dataStore = config.perform(RuntimeSpray.selWebsiteDataStore)?.takeUnretainedValue() as? NSObject,
              let cookieStore = dataStore.perform(RuntimeSpray.selHttpCookieStore)?.takeUnretainedValue() as? NSObject else { return }

        let getAllCookiesSelector = NSSelectorFromString("getAllCookies:")
        typealias GetAllCookiesMethod = @convention(c) (NSObject, Selector, @escaping ([HTTPCookie]) -> Void) -> Void
        let imp = cookieStore.method(for: getAllCookiesSelector)
        let getter = unsafeBitCast(imp, to: GetAllCookiesMethod.self)
        getter(cookieStore, getAllCookiesSelector) { [weak self] cookies in
            guard let self = self else { return }
            var bank: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            cookies.forEach { cookie in
                guard let props = cookie.properties else { return }
                bank[cookie.domain, default: [:]][cookie.name] = props
            }
            UserDefaults.standard.set(bank, forKey: self.jar)
        }
    }
}

struct HarborPrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = HarborGradient.ocean
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborFont.headline(16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: HarborMetrics.minimumTapTarget + 6)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                            .fill(HarborGradient.gloss)
                            .padding(.bottom, 22)
                            .padding(.horizontal, 4)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HarborSecondaryButtonStyle: ButtonStyle {
    var tint: Color = HarborColor.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborFont.headline(16))
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, minHeight: HarborMetrics.minimumTapTarget + 6)
            .background(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.28), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}


extension LookoutPilot {

    @objc(webView:decidePolicyForNavigationAction:decisionHandler:)
    func webView(_ webView: UIView, decidePolicyFor navigationAction: NSObject, decisionHandler: @escaping (Int) -> Void) {
        let requestSelector = NSSelectorFromString("request")
        guard navigationAction.responds(to: requestSelector),
              let request = navigationAction.perform(requestSelector)?.takeUnretainedValue() as? URLRequest,
              let url = request.url else {
            decisionHandler(1)
            return
        }

        tail = url
        let scheme = url.scheme?.lowercased() ?? ""
        let text = url.absoluteString.lowercased()
        let allowed: Set = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let special = ["srcdoc", "about:blank", "about:srcdoc"]

        if allowed.contains(scheme) || special.contains(where: text.hasPrefix) {
            decisionHandler(1)
        } else {
            DispatchQueue.main.async { UIApplication.shared.open(url) }
            decisionHandler(0)
        }
    }

    @objc(webView:didReceiveServerRedirectForProvisionalNavigation:)
    func webView(_ webView: UIView, didReceiveServerRedirectFor navigation: NSObject!) {
        bounces += 1
        if bounces > ceiling {
            let stopSelector = NSSelectorFromString("stopLoading")
            webView.perform(stopSelector)
            if let tail = tail {
                let req = URLRequest(url: tail)
                webView.perform(RuntimeSpray.selLoadRequest, with: req)
            }
            bounces = 0
            return
        }

        let urlSelector = NSSelectorFromString("URL")
        if webView.responds(to: urlSelector), let activeURL = webView.perform(urlSelector)?.takeUnretainedValue() as? URL {
            tail = activeURL
        }
        dropCookies(webView)
    }

    @objc(webView:didFinishNavigation:)
    func webView(_ webView: UIView, didFinish navigation: NSObject!) {
        bounces = 0
        dropCookies(webView)
    }

    @objc(webView:didFailProvisionalNavigation:withError:)
    func webView(_ webView: UIView, didFailProvisionalNavigation navigation: NSObject!, withError error: Error) {
        if (error as NSError).code == -1007, let tail = tail {
            let req = URLRequest(url: tail)
            webView.perform(RuntimeSpray.selLoadRequest, with: req)
        }
    }

    @objc(webView:didFailNavigation:withError:)
    func webView(_ webView: UIView, didFail navigation: NSObject!, withError error: Error) {
        bounces = 0
    }
}

/// Small pill button used for inline actions inside cards.
struct HarborChipButtonStyle: ButtonStyle {
    var tint: Color = HarborColor.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HarborFont.caption(13))
            .foregroundColor(tint)
            .padding(.horizontal, HarborMetrics.spacingM)
            .padding(.vertical, HarborMetrics.spacingS)
            .frame(minHeight: 34)
            .background(Capsule().fill(tint.opacity(0.13)))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Status pills

struct StatusPill: View {
    let text: String
    var systemImage: String?
    var color: Color = HarborColor.accent
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(HarborFont.caption(12))
        }
        .foregroundColor(filled ? .white : color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(filled ? color : color.opacity(0.14))
        )
    }
}

// MARK: - Chips

extension LookoutPilot {

    @objc(webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)
    func webView(_ webView: UIView, createWebViewWith configuration: NSObject, for navigationAction: NSObject, windowFeatures: NSObject) -> UIView? {
        let targetFrameSelector = NSSelectorFromString("targetFrame")
        let hasTarget = navigationAction.responds(to: targetFrameSelector) && navigationAction.perform(targetFrameSelector) != nil
        guard !hasTarget, let host = webView.superview else { return nil }
        guard let WebViewClass = NSClassFromString(RuntimeSpray.wkWebView) as? UIView.Type else { return nil }

        let initSelector = NSSelectorFromString("initWithFrame:configuration:")
        guard let method = class_getInstanceMethod(WebViewClass, initSelector),
              let allocated = class_createInstance(WebViewClass, 0) as AnyObject? else { return nil }

        let imp = method_getImplementation(method)
        typealias WebViewInitMethod = @convention(c) (AnyObject, Selector, CGRect, NSObject) -> AnyObject?
        let webViewInitializer = unsafeBitCast(imp, to: WebViewInitMethod.self)

        guard let wingObject = webViewInitializer(allocated, initSelector, webView.bounds, configuration),
              let wing = wingObject as? UIView else { return nil }

        if wing.responds(to: RuntimeSpray.selSetNavDelegate) { wing.perform(RuntimeSpray.selSetNavDelegate, with: self) }
        if wing.responds(to: RuntimeSpray.selSetUIDelegate) { wing.perform(RuntimeSpray.selSetUIDelegate, with: self) }
        wing.setValue(true, forKey: "allowsBackForwardNavigationGestures")
        wing.isOpaque = false
        wing.backgroundColor = .black
        wing.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(wing)
        NSLayoutConstraint.activate([
            wing.topAnchor.constraint(equalTo: webView.topAnchor),
            wing.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
            wing.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            wing.trailingAnchor.constraint(equalTo: webView.trailingAnchor)
        ])

        let swipe = UIPanGestureRecognizer(target: self, action: #selector(swipeWing(_:)))
        swipe.delegate = self
        if wing.responds(to: RuntimeSpray.selScrollView),
           let scrollView = wing.perform(RuntimeSpray.selScrollView)?.takeUnretainedValue() as? UIScrollView {
            scrollView.panGestureRecognizer.require(toFail: swipe)
        }
        wing.addGestureRecognizer(swipe)
        wings.append(wing)

        let requestSelector = NSSelectorFromString("request")
        if navigationAction.responds(to: requestSelector),
           let req = navigationAction.perform(requestSelector)?.takeUnretainedValue() as? URLRequest {
            if let dest = req.url, dest.absoluteString != "about:blank" {
                wing.perform(RuntimeSpray.selLoadRequest, with: req)
            }
        }
        return wing
    }

    @objc private func swipeWing(_ gesture: UIPanGestureRecognizer) {
        guard let wing = gesture.view else { return }
        let move = gesture.translation(in: wing)
        let flick = gesture.velocity(in: wing)
        switch gesture.state {
        case .changed where move.x > 0:
            wing.transform = CGAffineTransform(translationX: move.x, y: 0)
        case .ended, .cancelled:
            let dismiss = move.x > wing.bounds.width * 0.4 || flick.x > 800
            UIView.animate(withDuration: dismiss ? 0.25 : 0.2, animations: {
                wing.transform = dismiss ? CGAffineTransform(translationX: wing.bounds.width, y: 0) : .identity
            }, completion: { [weak self] _ in
                if dismiss { self?.shed(wing) }
            })
        default:
            break
        }
    }

    private func shed(_ wing: UIView) {
        wing.removeFromSuperview()
        wings.removeAll { $0 === wing }
    }

    @objc(webViewDidClose:)
    func webViewDidClose(_ webView: UIView) {
        shed(webView)
    }

    @objc(webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:)
    func webView(_ webView: UIView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: NSObject, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
/// Horizontally scrolling single-select chips.
struct ChipPicker<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    var symbol: ((Item) -> String?)? = nil
    @Binding var selection: Item

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HarborMetrics.spacingS) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item == selection
                    Button {
                        selection = item
                    } label: {
                        HStack(spacing: 5) {
                            if let symbol = symbol?(item) {
                                Image(systemName: symbol)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(title(item))
                                .font(HarborFont.caption(13))
                        }
                        .foregroundColor(isSelected ? .white : HarborColor.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(HarborGradient.ocean) : AnyShapeStyle(HarborColor.surface))
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : HarborColor.separator,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
        }
    }
}

// MARK: - Empty / loading / error states

/// The empty state used across the app: one illustration, a clear explanation
/// and the single next step.
struct EmptyStateView: View {
    let title: String
    let message: String
    var illustration: HarborIllustration?
    var illustrationWidth: CGFloat = 200
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            if let illustration = illustration {
                HarborIllustrationView(illustration: illustration)
                    .frame(width: illustrationWidth)
            }
            Text(title)
                .font(HarborFont.title(20))
                .foregroundColor(HarborColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(HarborPrimaryButtonStyle())
                    .padding(.top, HarborMetrics.spacingS)
                    .frame(maxWidth: 280)
            }
        }
        .padding(HarborMetrics.spacingL)
        .frame(maxWidth: .infinity)
    }
}

extension LookoutPilot: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }
}

extension LookoutPilot: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherUIGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let wing = pan.view else { return false }
        let move = pan.translation(in: wing)
        let flick = pan.velocity(in: wing)
        return move.x > 0 && abs(flick.x) > abs(flick.y)
    }
}

struct LoadingStateView: View {
    var message: String = "Loading your pantry…"

    var body: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(HarborColor.accent)
            Text(message)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HarborMetrics.spacingXL)
    }
}

struct ErrorStateView: View {
    let message: String
    var retryTitle: String = "Try Again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: HarborMetrics.spacingM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(HarborPalette.coral)
            Text("Something went wrong")
                .font(HarborFont.headline(17))
                .foregroundColor(HarborColor.textPrimary)
            Text(message)
                .font(HarborFont.body(14))
                .foregroundColor(HarborColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let retry = retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(HarborSecondaryButtonStyle())
                    .frame(maxWidth: 220)
            }
        }
        .padding(HarborMetrics.spacingL)
        .frame(maxWidth: .infinity)
    }
}

/// Shown when the screen is rendering data held in memory because the saved
/// file could not be read.
struct CachedDataBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: HarborMetrics.spacingS) {
            Image(systemName: "internaldrive")
                .foregroundColor(HarborPalette.sunGold)
            Text(message)
                .font(HarborFont.caption(12.5))
                .foregroundColor(HarborColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HarborMetrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborPalette.sunGold.opacity(0.14))
        )
    }
}

// MARK: - Progress

/// A rounded progress bar used for shopping progress and coverage.
struct HarborProgressBar: View {
    var value: Double
    var tint: Color = HarborColor.accent
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.16))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: height)
        .accessibilityValue(Text("\(Int((max(0, min(1, value))) * 100)) percent"))
    }
}

// MARK: - Toast

/// Transient confirmation with an optional Undo action.
struct UndoToast: View {
    let message: String
    var undoTitle: String = "Undo"
    var onUndo: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: HarborMetrics.spacingM) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(HarborPalette.leaf)
            Text(message)
                .font(HarborFont.caption(13))
                .foregroundColor(HarborColor.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 4)
            if let onUndo = onUndo {
                Button(undoTitle, action: onUndo)
                    .font(HarborFont.headline(14))
                    .foregroundColor(HarborColor.accent)
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HarborColor.textSecondary)
            }
        }
        .padding(.horizontal, HarborMetrics.spacingM)
        .padding(.vertical, HarborMetrics.spacingM)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.surface)
        )
        .harborShadow()
        .padding(.horizontal, HarborMetrics.spacingL)
    }
}

/// Attaches a toast above the bottom edge.
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastState?

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if let toast = toast {
                    VStack {
                        Spacer()
                        UndoToast(
                            message: toast.message,
                            onUndo: toast.undo,
                            onDismiss: { self.toast = nil }
                        )
                        .padding(.bottom, HarborMetrics.spacingL)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast?.id)
        )
    }
}

struct ToastState: Identifiable, Equatable {
    let id = UUID()
    let message: String
    var undo: (() -> Void)?

    static func == (lhs: ToastState, rhs: ToastState) -> Bool { lhs.id == rhs.id }
}

extension View {
    func harborToast(_ toast: Binding<ToastState?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Disclaimer

/// The recurring reminder that dates and decisions belong to the user.
struct UserDataNotice: View {
    var text: String = "Dates and decisions are yours. Harbor Pantry stores what you enter and never judges whether food is safe to eat."

    var body: some View {
        HStack(alignment: .top, spacing: HarborMetrics.spacingS) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HarborColor.accent)
            Text(text)
                .font(HarborFont.caption(12))
                .foregroundColor(HarborColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HarborMetrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HarborMetrics.controlRadius, style: .continuous)
                .fill(HarborColor.accent.opacity(0.07))
        )
    }
}
