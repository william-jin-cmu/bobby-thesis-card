import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var preset: Chip? = nil
    @State private var topIndex = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ChipRow(onTap: { preset = $0 })
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "交易热点").padding(.horizontal, 20)
                        HotTradeStack(trades: store.hotTrades, top: $topIndex) { trade in
                            store.path.append(Route.chat(trade.id))
                        }
                        .padding(.horizontal, 16)
                    }

                    ThesesStrip()

                    DailyBrief()
                        .padding(.horizontal, 16)

                    Color.clear.frame(height: 150)
                }
            }
            .scrollIndicators(.hidden)

            Composer(placeholder: "问问 Bobby…")
        }
        .navigationTitle("")
        .task {
            guard store.tour, store.path.isEmpty, store.banner == nil else { return }
            try? await Task.sleep(for: .seconds(1.8))
            for _ in 0..<3 {
                withAnimation(.spring(duration: 0.55)) { topIndex = (topIndex + 1) % store.hotTrades.count }
                try? await Task.sleep(for: .seconds(1.3))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image(systemName: "line.3.horizontal").font(.system(size: 15, weight: .semibold))
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    BobbyMark(size: 20)
                    Text("Bobby AI").font(.system(size: 17, weight: .semibold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "square.and.pencil").font(.system(size: 15, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $preset) { chip in
            PresetSheet(chip: chip) { _ in
                preset = nil
                if chip == .theses { store.path.append(Route.theses) }
                else if let first = store.hotTrades.first { store.path.append(Route.chat(first.id)) }
            }
            .presentationDetents([.height(chip == .theses ? 250 : 300)])
            .presentationCornerRadius(30)
        }
    }
}

// MARK: - Chips

enum Chip: String, CaseIterable, Identifiable {
    case theses, trending, picks, portfolio, earnings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .theses: "我的观点"
        case .trending: "交易热点"
        case .picks: "智能选股"
        case .portfolio: "持仓分析"
        case .earnings: "财报"
        }
    }
    var icon: String {
        switch self {
        case .theses: "scope"
        case .trending: "chart.line.uptrend.xyaxis"
        case .picks: "bolt"
        case .portfolio: "chart.pie"
        case .earnings: "chart.bar"
        }
    }
    var prompts: [String] {
        switch self {
        case .theses: ["今天哪些观点需要我关注？", "我最近的判断准吗？"]
        case .trending: ["看看今天市场在聊什么", "本周市场最关注的事件有哪些？", "今天有哪些股票异动值得关注？"]
        case .picks: ["帮我挑一只值得买的股票", "帮我对比几只股票，看哪只更值得买", "暂无想法，了解最近热门股票"]
        case .portfolio: ["我现在的持仓风险大吗？", "我该减仓还是加仓？", "我这周的持仓表现怎么样？"]
        case .earnings: ["本周有哪些公司发财报？", "拆解最新一份超预期财报", "哪些财报会影响我的持仓？"]
        }
    }
}

struct ChipRow: View {
    var onTap: (Chip) -> Void
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Chip.allCases) { chip in
                    Button { onTap(chip) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: chip.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(chip == .theses ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Theme.ink))
                            Text(chip.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 14).frame(height: 40)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

struct PresetSheet: View {
    let chip: Chip
    var onPick: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: chip.icon).font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.black.opacity(0.05)))
                Text(chip.title).font(.system(size: 17, weight: .semibold))
            }
            .padding(.bottom, 8)
            ForEach(Array(chip.prompts.enumerated()), id: \.offset) { i, p in
                Button { onPick(p) } label: {
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.mono(12)).foregroundStyle(Theme.ink3)
                            .frame(width: 22, height: 22).background(Circle().fill(Color.black.opacity(0.04)))
                        Text(p).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink3)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                if i < chip.prompts.count - 1 { Divider().opacity(0.5) }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

// MARK: - Hot trades card stack

struct HotTradeStack: View {
    let trades: [HotTrade]
    @Binding var top: Int
    var onAnalyze: (HotTrade) -> Void
    @State private var drag: CGSize = .zero

    var body: some View {
        ZStack {
            ForEach(Array(trades.enumerated().reversed()), id: \.element.id) { i, trade in
                let depth = (i - top + trades.count) % trades.count
                HotTradeCard(trade: trade, onAnalyze: { onAnalyze(trade) })
                    .scaleEffect(1 - CGFloat(depth) * 0.05, anchor: .top)
                    .offset(y: CGFloat(depth) * -14)
                    .offset(x: depth == 0 ? drag.width : 0)
                    .rotationEffect(.degrees(depth == 0 ? Double(drag.width / 25) : 0))
                    .opacity(depth > 2 ? 0 : 1)
                    .zIndex(Double(trades.count - depth))
                    .gesture(depth == 0 ? DragGesture()
                        .onChanged { drag = $0.translation }
                        .onEnded { v in
                            if abs(v.translation.width) > 90 {
                                withAnimation(.spring(duration: 0.4)) { top = (top + 1) % trades.count; drag = .zero }
                            } else {
                                withAnimation(.spring) { drag = .zero }
                            }
                        } : nil)
            }
        }
        .padding(.top, 28)
        .frame(height: 400)
    }
}

struct HotTradeCard: View {
    let trade: HotTrade
    var onAnalyze: () -> Void
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            NebulaBackground(seed: trade.seed)
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(trade.tag).font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.16)))
                    Text("\(trade.minutesAgo) 分钟前").font(.system(size: 11)).opacity(0.6)
                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                Text(trade.headline)
                    .font(.serif(25))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                TickerPill(ticker: trade.ticker, change: trade.change, dark: true)
                Button(action: onAnalyze) {
                    Text("生成交易观点").font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 14)
    }
}

// MARK: - Theses strip (new)

struct ThesesStrip: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "我的观点")
                Spacer()
                Button("全部") { store.path.append(Route.theses) }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(store.theses) { t in
                        Button { store.path.append(Route.thesis(t.id)) } label: { ThesisMiniCard(thesis: t) }
                            .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct ThesisMiniCard: View {
    let thesis: Thesis
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(thesis.ticker).font(.system(size: 15, weight: .bold))
                Spacer()
                StatusBadge(status: thesis.status)
            }
            Text(thesis.claim).font(.serif(14)).foregroundStyle(Theme.ink)
                .lineLimit(2).multilineTextAlignment(.leading)
                .frame(height: 38, alignment: .top)
            StopMeter(thesis: thesis)
            HStack {
                if let cp = thesis.nextCheckpoint {
                    Label(cp.date, systemImage: "calendar").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.ink2)
                }
                Spacer()
                if let u = thesis.unrealized {
                    Text((u >= 0 ? "+" : "−") + abs(u).usd0)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(u >= 0 ? Theme.up : Theme.down)
                }
            }
        }
        .padding(14)
        .frame(width: 250)
        .card(20)
    }
}

/// Visual distance between price and the user's invalidation line.
struct StopMeter: View {
    let thesis: Thesis
    var body: some View {
        let d = max(0, min(thesis.distanceToStop / 0.15, 1))
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.06))
                    Capsule().fill(d < 0.12 ? Theme.amber : Theme.up).frame(width: max(8, geo.size.width * d))
                }
            }
            .frame(height: 5)
            Text(String(format: "距失效线还有 %.1f%%", thesis.distanceToStop * 100))
                .font(.system(size: 11)).foregroundStyle(Theme.ink2)
        }
    }
}

// MARK: - Daily brief

struct DailyBrief: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "每日简报")
            VStack(alignment: .leading, spacing: 12) {
                BriefRow(ticker: "PANW", text: "业绩超预期并上调指引；45 亿美元全股票收购 Applied Compute。")
                Divider().opacity(0.5)
                BriefRow(ticker: "MU", text: "你的观点离失效线还有 9.9%，无需操作。")
                Divider().opacity(0.5)
                BriefRow(ticker: "FED", text: "沃勒为 12 月降息 50 个基点打开大门。")
            }
            .padding(16)
            .card(20)
        }
    }
}

struct BriefRow: View {
    let ticker: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(ticker).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.ink2)
                .frame(width: 44, height: 22).background(Capsule().fill(Color.black.opacity(0.05)))
            Text(text).font(.system(size: 14)).foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Composer

struct Composer: View {
    var placeholder: String
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flask").font(.system(size: 11, weight: .semibold))
                Text("模拟账户 · $1,000,000").font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.up").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.violet)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .glassEffect(.regular.tint(Theme.violet.opacity(0.06)), in: .capsule)
            .padding(.leading, 4)

            HStack(spacing: 10) {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .padding(.leading, 6)
                Image(systemName: "mic").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink2)
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(text.isEmpty ? Theme.ink3 : Theme.ink))
            }
            .padding(.leading, 14).padding(.trailing, 7).frame(height: 54)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal, 14).padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg.opacity(0.92), Theme.bg], startPoint: .top, endPoint: .bottom)
                .padding(.top, -36)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }
}
