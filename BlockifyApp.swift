import SwiftUI
import WebKit

// MARK: - App Entry
@main
struct BlockifyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Models

struct SocialApp: Identifiable, Hashable {
    let id: String
    let name: String
    let iconName: String
    let gradient: [Color]
    let url: String
    let features: [Feature]
}

struct Feature: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
}

// MARK: - Settings

class AppSettings: ObservableObject {
    @Published var blockedFeatures: [String: Set<String>] = [:]
    @Published var hasSeenOnboarding: Bool

    init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        loadSettings()
    }

    func isFeatureBlocked(appId: String, featureId: String) -> Bool {
        blockedFeatures[appId]?.contains(featureId) ?? false
    }

    func toggleFeature(appId: String, featureId: String) {
        if blockedFeatures[appId] == nil { blockedFeatures[appId] = Set() }
        if blockedFeatures[appId]!.contains(featureId) {
            blockedFeatures[appId]!.remove(featureId)
        } else {
            blockedFeatures[appId]!.insert(featureId)
        }
        saveSettings()
    }

    func getBlockedCount(appId: String) -> Int {
        blockedFeatures[appId]?.count ?? 0
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    }

    private func saveSettings() {
        let dict = blockedFeatures.mapValues { Array($0) }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: "blockedFeatures")
        }
    }

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "blockedFeatures"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            blockedFeatures = decoded.mapValues { Set($0) }
        }
    }
}

// MARK: - Social Apps

let socialApps: [SocialApp] = [
    SocialApp(
        id: "instagram",
        name: "Instagram",
        iconName: "camera.fill",
        gradient: [Color(red: 0.62, green: 0.31, blue: 0.89), Color(red: 0.91, green: 0.31, blue: 0.62)],
        url: "https://www.instagram.com",
        features: [
            Feature(id: "reels", name: "Hide Reels", description: "Remove Reels tab & feed"),
            Feature(id: "stories", name: "Hide Stories", description: "Remove Stories UI"),
            Feature(id: "directMessages", name: "Hide DMs", description: "Remove DM access"),
            Feature(id: "fullBlock", name: "Block Site", description: "Show blocked page")
        ]
    ),
    SocialApp(
        id: "tiktok",
        name: "TikTok",
        iconName: "music.note",
        gradient: [Color.black, Color(red: 0.8, green: 0.2, blue: 0.4)],
        url: "https://www.tiktok.com",
        features: [
            Feature(id: "forYouPage", name: "Hide For You", description: "Block For You feed"),
            Feature(id: "following", name: "Hide Following", description: "Remove Following feed"),
            Feature(id: "discover", name: "Hide Discover", description: "Block Discover tab"),
            Feature(id: "fullBlock", name: "Block Site", description: "Show blocked page")
        ]
    ),
    SocialApp(
        id: "facebook",
        name: "Facebook",
        iconName: "f.square.fill",
        gradient: [Color(red: 0.23, green: 0.35, blue: 0.6), Color(red: 0.3, green: 0.5, blue: 0.8)],
        url: "https://www.facebook.com",
        features: [
            Feature(id: "feed", name: "Hide Feed", description: "Remove main feed"),
            Feature(id: "stories", name: "Hide Stories", description: "Block Stories UI"),
            Feature(id: "directMessages", name: "Hide Messaging", description: "Block Messenger access"),
            Feature(id: "fullBlock", name: "Block Site", description: "Show blocked page")
        ]
    )
]

// MARK: - JS Mutation Observer Helper

class WebViewBlockingHelper {
    static func generateMutationObserverJS(appId: String, blockedFeatures: Set<String>) -> String {
        var functionBodies: [String] = []
        var calls: [String] = []

        func safe(_ code: String) -> String { "try { \(code) } catch(e){}" }

        // Instagram blocking
        if appId == "instagram" {
            if blockedFeatures.contains("reels") {
                functionBodies.append("""
                function blockReels() {
                    try {
                        // Reels in feed
                        document.querySelectorAll('a[href*="/reels/"]').forEach(e => e.remove());
                        // Reels section tiles
                        document.querySelectorAll('div[role="button"]').forEach(e => {
                            if(e.innerText && e.innerText.toLowerCase().includes('reel')) e.remove();
                        });
                        // Reels links in stories bar
                        document.querySelectorAll('a').forEach(a => {
                            if(a.href && a.href.includes('/reels/')) a.remove();
                        });
                    } catch(e) {}
                }
                """)
                calls.append("blockReels();")
            }

            if blockedFeatures.contains("stories") {
                functionBodies.append("""
                function blockStories() {
                    try {
                        document.querySelectorAll('div[aria-label*="Story"]').forEach(e => e.remove());
                        document.querySelectorAll('section').forEach(section => {
                            if(section.getAttribute('aria-label') && section.getAttribute('aria-label').toLowerCase().includes('story')) section.remove();
                        });
                    } catch(e) {}
                }
                """)
                calls.append("blockStories();")
            }

            if blockedFeatures.contains("directMessages") {
                functionBodies.append("""
                function blockDMs() {
                    try {
                        document.querySelectorAll('a[href*="/direct/"]').forEach(e => e.remove());
                        document.querySelectorAll('[aria-label*="Direct"]').forEach(e => e.remove());
                    } catch(e) {}
                }
                """)
                calls.append("blockDMs();")
            }

            // Ensure MutationObserver applies repeatedly
            calls.append("""
            const instaObserver = new MutationObserver(() => {
                blockReels();
                blockStories();
                blockDMs();
            });
            instaObserver.observe(document.body, {childList: true, subtree: true});
            """)
        }


        // Facebook
        if appId == "facebook" {
            if blockedFeatures.contains("feed") {
                functionBodies.append("""
                function blockFBFeed() {
                    \(safe("Array.from(document.querySelectorAll('[role=\"feed\"]')).forEach(e=>e.remove());"))
                }
                """)
                calls.append("blockFBFeed();")
            }
            if blockedFeatures.contains("stories") {
                functionBodies.append("""
                function blockFBStories() {
                    \(safe("Array.from(document.querySelectorAll('[aria-label*=\"Stories\"]')).forEach(e=>e.remove());"))
                }
                """)
                calls.append("blockFBStories();")
            }
            if blockedFeatures.contains("directMessages") {
                functionBodies.append("""
                function blockFBDMs() {
                    \(safe("Array.from(document.querySelectorAll('a[href*=\"messenger\"]')).forEach(e=>e.remove());"))
                }
                """)
                calls.append("blockFBDMs();")
            }
            if blockedFeatures.contains("fullBlock") {
                functionBodies.append("""
                function blockFBFull() {
                    document.documentElement.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;height:100vh;background:#000;color:#fff;font-family:system-ui;"><div style="text-align:center;"><h1>Access Blocked</h1><p>This site is blocked by Blockify.</p></div></div>';
                }
                """)
                calls.append("blockFBFull();")
            }
        }

        let functionsJS = functionBodies.joined(separator: "\n")
        let callsJS = calls.joined(separator: "\n")

        if calls.isEmpty { return "" }

        return """
        (function() {
            try { \(functionsJS) } catch(e){}
            try {
                const applyAll = function() { try { \(callsJS) } catch(e){} };
                setTimeout(applyAll, 300);
                const observer = new MutationObserver(() => applyAll());
                observer.observe(document.documentElement || document.body, { childList:true, subtree:true, attributes:true });
                setInterval(applyAll, 1500);
            } catch(e){ try { \(callsJS) } catch(e){} }
        })();
        """
    }
}

// MARK: - Root View & Onboarding

struct RootView: View {
    @StateObject private var settings = AppSettings()
    var body: some View {
        Group {
            if !settings.hasSeenOnboarding {
                OnboardingView().environmentObject(settings)
            } else {
                MainAppView().environmentObject(settings)
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.05, green: 0.08, blue: 0.15)],
                           startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack {
                TabView(selection: $currentPage) {
                    OnboardingScreen(title: "Welcome to Blockify", subtitle: "Take control of your social media and eliminate distractions", icon: "sparkles").tag(0)
                    OnboardingScreen(title: "Choose What to Block", subtitle: "Select any app and customize which features you want to hide", icon: "slider.horizontal.3").tag(1)
                    OnboardingScreen(title: "Browse Distraction-Free", subtitle: "Open apps through Blockify to hide Reels, Stories, Messaging, etc.", icon: "eye.slash.fill", showButton: true) {
                        settings.completeOnboarding()
                    }.tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)

                HStack {
                    Spacer()
                    Button(action: {
                        if currentPage < 2 { currentPage += 1 } else { settings.completeOnboarding() }
                    }) {
                        Text(currentPage < 2 ? "Next" : "Get Started")
                            .foregroundColor(.white).padding().background(Color.blue).cornerRadius(12)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct OnboardingScreen: View {
    let title: String
    let subtitle: String
    let icon: String
    var showButton: Bool = false
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Circle().fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 120)
                .overlay(Image(systemName: icon).font(.system(size: 60)).foregroundColor(.white))
            Text(title).font(.system(size: 34, weight: .bold)).foregroundColor(.white).multilineTextAlignment(.center)
            Text(subtitle).font(.system(size: 17)).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
            if showButton, let action = buttonAction {
                Button(action: action) {
                    Text("Get Started").foregroundColor(.white).padding().frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16).padding(.horizontal, 40)
                }
            }
        }
    }
}

// MARK: - Main App View

struct MainAppView: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        NavigationStack {
            HomeView().environmentObject(settings)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.05, green: 0.08, blue: 0.15)],
                           startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(socialApps) { app in
                        NavigationLink(value: app) {
                            AppCard(app: app)
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 40)
            }
        }
        .navigationDestination(for: SocialApp.self) { app in
            DetailView(app: app).environmentObject(settings)
        }
    }
}

struct AppCard: View {
    let app: SocialApp
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                LinearGradient(colors: app.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 64, height: 64).cornerRadius(16)
                Image(systemName: app.iconName).font(.system(size: 32)).foregroundColor(.white)
            }
            VStack(alignment: .leading) {
                Text(app.name).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                Text("Customize your \(app.name)").font(.system(size: 13)).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(20)
        .background(LinearGradient(colors: app.gradient.map { $0.opacity(0.18) }, startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 4)
    }
}

// MARK: - Detail View

struct DetailView: View {
    let app: SocialApp
    @EnvironmentObject var settings: AppSettings
    @State private var showTimer = false
    @State private var showWeb = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.05, green: 0.08, blue: 0.15)], startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {
                Text("Customize \(app.name)").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding(.top, 28)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(app.features) { feature in
                            FeatureToggle(app: app, feature: feature).environmentObject(settings)
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 24)
                }

                Spacer()
                Button(action: { showTimer = true }) {
                    Text("Open \(app.name)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(LinearGradient(colors: app.gradient, startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14).padding(.horizontal, 20)
                }
                .padding(.bottom, 36)
                .fullScreenCover(isPresented: $showTimer) {
                    TimerScreen {
                        showTimer = false
                        showWeb = true
                    }
                }
                .fullScreenCover(isPresented: $showWeb) {
                    BlockedWebViewView(urlString: app.url, appId: app.id)
                        .environmentObject(settings)
                }
            }
        }
        .navigationTitle(app.name)
    }
}

struct FeatureToggle: View {
    let app: SocialApp
    let feature: Feature
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Button(action: { settings.toggleFeature(appId: app.id, featureId: feature.id) }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(feature.name).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                    Text(feature.description).font(.system(size: 13)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: settings.isFeatureBlocked(appId: app.id, featureId: feature.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(settings.isFeatureBlocked(appId: app.id, featureId: feature.id) ? .green : .gray).font(.system(size: 22))
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .padding(.horizontal, 8)
        }.buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Timer Screen

struct TimerScreen: View {
    let onFinish: () -> Void
    @State private var counter = 30
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                Text("Please wait").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                Text("\(counter) seconds").font(.system(size: 24)).foregroundColor(.gray)
            }
        }.onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if counter > 0 { counter -= 1 }
                else { timer?.invalidate(); onFinish() }
            }
        }.onDisappear { timer?.invalidate() }
    }
}

// MARK: - WebView with JS Injection

struct BlockedWebViewView: UIViewRepresentable {
    let urlString: String
    let appId: String
    @EnvironmentObject var settings: AppSettings

    func makeUIView(context: Context) -> WKWebView {
        let webConfig = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webConfig.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.navigationDelegate = context.coordinator

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(appId: appId, settings: settings)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let appId: String
        let settings: AppSettings

        init(appId: String, settings: AppSettings) {
            self.appId = appId
            self.settings = settings
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let blocked = settings.blockedFeatures[appId] else { return }
            let js = WebViewBlockingHelper.generateMutationObserverJS(appId: appId, blockedFeatures: blocked)
            if !js.isEmpty {
                webView.evaluateJavaScript(js)
            }
        }
    }
}

