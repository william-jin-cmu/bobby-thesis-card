import SwiftUI

@main
struct BobbyProtoApp: App {
    @State private var store = AppStore()
    init() { FontLoader.register() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ZStack(alignment: .top) {
            NavigationStack(path: $store.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .chat(let id): ChatView(trade: store.hotTrade(id)!)
                        case .thesis(let id): ThesisDetailView(thesis: store.thesis(id)!)
                        case .review(let id): ReviewView(thesis: store.thesis(id)!)
                        case .theses: ThesesListView()
                        }
                    }
            }
            .tint(Theme.ink)
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-demo"), i + 1 < args.count {
                    try? await Task.sleep(for: .milliseconds(300))
                    store.boot(args[i + 1])
                }
            }

            if let b = store.banner {
                BannerView(banner: b) {
                    if let r = b.route { store.path.append(r) }
                    withAnimation { store.banner = nil }
                }
                .padding(.horizontal, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }
}

/// Simulated push notification, styled like an iOS banner.
struct BannerView: View {
    let banner: Banner
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                BobbyMark(size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("BOBBY").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.ink2)
                        Spacer()
                        Text("现在").font(.system(size: 11)).foregroundStyle(Theme.ink3)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: banner.icon).foregroundStyle(banner.tint).font(.system(size: 12, weight: .bold))
                        Text(banner.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    Text(banner.body).font(.system(size: 14)).foregroundStyle(Theme.ink.opacity(0.8))
                        .multilineTextAlignment(.leading).lineLimit(3)
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        }
        .buttonStyle(PressStyle())
    }
}
