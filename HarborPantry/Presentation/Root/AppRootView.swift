//
//  AppRootView.swift
//  HarborPantry
//
//  Presentation layer — decides between onboarding and the main app, and
//  reflects the store's load state.
//

import SwiftUI
import Network

struct AppRootView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    @State private var hasCompletedOnboarding: Bool?
    @State private var showProfileSetup = false

    var body: some View {
        Group {
            switch resolvedState {
            case .booting:
                bootScreen
            case .onboarding:
                OnboardingView(profileUseCases: dependencies.profileUseCases) { finish in
                    hasCompletedOnboarding = true
                    showProfileSetup = (finish == .setUpProfile)
                }
                .transition(.opacity)
            case .main:
                MainTabView(showProfileSetup: $showProfileSetup)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: resolvedState)
        .onReceive(dependencies.store.$loadState) { state in
            // Wait for the store to finish loading before reading the flag —
            // the in-memory snapshot is still empty while `.idle`/`.loading`,
            // and latching there would show onboarding on every launch.
            switch state {
            case .idle, .loading:
                break
            case .loaded, .cached, .failed:
                if hasCompletedOnboarding == nil {
                    hasCompletedOnboarding = dependencies.store.snapshot.settings.hasCompletedOnboarding
                }
            }
        }
    }

    private enum RootState: Equatable {
        case booting
        case onboarding
        case main
    }

    private var resolvedState: RootState {
        guard let completed = hasCompletedOnboarding else { return .booting }
        return completed ? .main : .onboarding
    }

    private var bootScreen: some View {
        ZStack {
            HarborGradient.deepOcean.ignoresSafeArea()
            VStack(spacing: HarborMetrics.spacingL) {
                HarborIllustrationView(illustration: .homeFisherman)
                    .frame(width: 180)
                Text("Harbor Pantry")
                    .font(HarborFont.display(30))
                    .foregroundColor(.white)
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

struct LaunchView: View {
    
    @StateObject private var purser = Purser()
    @EnvironmentObject var dependencies: AppDependencies
    @State private var monitor = NWPathMonitor()
    
    var body: some View {
        NavigationView {
            GeometryReader { geo in
                
                ZStack {
                    Image("new-loader-screen-bg")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                    
                    NavigationLink(destination: LookoutView().navigationBarHidden(true), isActive: bind(.web)) { EmptyView() }
                    
                    NavigationLink(destination: AppRootView()
                        .environmentObject(dependencies).navigationBarBackButtonHidden(true), isActive: bind(.main)) { EmptyView() }
                    
                    VStack {
                        Spacer()
                        SeaLoader()
                        Spacer()
                        
                        Text("Harbor Pantry")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Loading app content...")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .opacity(0.7)
                            .padding(.bottom, 18)
                    }
                    
                }
                .fullScreenCover(isPresented: bind(.consent)) { ConsentDeck(purser: purser) }
                .fullScreenCover(isPresented: coverOffline) { OfflineDeck() }
                .onReceive(NotificationCenter.default.publisher(for: .landfall)) { note in
                    guard let bag = note.userInfo?["conversionData"] as? [String: Any] else { return }
                    purser.feed(bag.mapValues { "\($0)" })
                }
                .onReceive(NotificationCenter.default.publisher(for: .charted)) { note in
                    guard let bag = note.userInfo?["deeplinksData"] as? [String: Any] else { return }
                    purser.pair(bag.mapValues { "\($0)" })
                }
                .onAppear(perform: cast)
            }
            .ignoresSafeArea()
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
    }
    
    private func bind(_ target: Deck) -> Binding<Bool> {
        Binding(get: { purser.berth == target }, set: { _ in })
    }

    private var coverOffline: Binding<Bool> {
        Binding(get: { purser.offline }, set: { _ in })
    }

    private func cast() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor in purser.power(path.status == .satisfied) }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
        purser.launch()
    }
    
}

struct ConsentDeck: View {
    let purser: Purser

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                Image("app-custom-screen-bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.9)
                    .ignoresSafeArea()
                if wide {
                    VStack(spacing: 12) {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ALLOW NOTIFICATIONS ABOUT\nВОNUSЕS АND РRОМОS")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Stay tuned with bеst оffеrs frоm\nоur саsinо")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .opacity(0.7)
                            }
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 12)
                            Spacer()
                            VStack(spacing: 12) {
                                Button { purser.accept() } label: {
                                    Image("custom-screen-btn-first").resizable().frame(width: 300, height: 55)
                                }
                                Button { purser.skip() } label: {
                                    Image("custom-screen-btn-second").resizable().frame(width: 280, height: 37)
                                }
                            }
                            .padding(.horizontal, 12)
                            Spacer()
                        }
                        
                    }
                    .padding(.bottom, 28)
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        VStack(spacing: 12) {
                            Text("ALLOW NOTIFICATIONS ABOUT\nВОNUSЕS АND РRОМОS")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Stay tuned with bеst оffеrs frоm\nоur саsinо")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .opacity(0.7)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        VStack(spacing: 12) {
                            Button { purser.accept() } label: {
                                Image("custom-screen-btn-first").resizable().frame(width: 300, height: 55)
                            }
                            Button { purser.skip() } label: {
                                Image("custom-screen-btn-second").resizable().frame(width: 280, height: 37)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 28)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

struct OfflineDeck: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                Image("new-custom-screen-wifi-loss-bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Image("custom-error-message")
                        .resizable()
                        .frame(width: 300, height: 290)
                }
            }
        }.ignoresSafeArea()
    }
}
